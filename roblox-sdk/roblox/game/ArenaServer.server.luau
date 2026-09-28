--!strict
-- ArenaServer: al recibir un regalo (vía LiveEventBridge), deja caer una
-- roca sobre el jugador objetivo. Efecto puramente visual.
--
-- IMPORTANTE (hallazgo de la Fase 0): ServerScriptService.LiveEventBridgeDemo
-- ya llama a Bridge.Init({ debug = true }) con el transporte real
-- (MessagingService). Bridge.Init solo puede llamarse una vez, así que este
-- script NO vuelve a llamarlo: solo se suscribe con Bridge.OnGift.

local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local HttpService = game:GetService("HttpService")

local Bridge = require(ServerScriptService.LiveEventBridge)
local Types = require(ServerScriptService.LiveEventBridge.Types)

type LiveEvent = Types.LiveEvent

--============================================================--
-- Constantes de configuración
--============================================================--

local CHANNEL = "" -- usuario de TikTok que transmite; vacío = sin filtro de canal
local TARGET_USERNAME = "" -- nombre de usuario de Roblox; vacío = jugador aleatorio
local SIMULATE = false
local MAX_ACTIVE_BLOCKS = 40

-- Paleta de roca (debe coincidir con la piedra de ArenaEnvironment.server.luau)
local COLOR_ROCK_1 = Color3.fromRGB(120, 108, 96)
local COLOR_ROCK_2 = Color3.fromRGB(96, 84, 72)
local COLOR_ROCK_3 = Color3.fromRGB(140, 126, 110)
local COLOR_ROCK_4 = Color3.fromRGB(80, 72, 64)
local BLOCK_COLORS = { COLOR_ROCK_1, COLOR_ROCK_2, COLOR_ROCK_3, COLOR_ROCK_4 }
local COLOR_DUST = Color3.fromRGB(196, 172, 132) -- color del impacto (polvo, no neón)

local DROP_HEIGHT = 40
local POP_TWEEN_SECONDS = 0.4
local RING_BURST_SECONDS = 0.6
local BLOCK_LIFETIME_SECONDS = 15
local ROCK_SIZE_VARIANCE = 0.18 -- +/- por eje, para que las rocas no se vean como cubos perfectos

--============================================================--
-- Estado
--============================================================--

local blocksFolder = Workspace:FindFirstChild("ArenaGiftBlocks")
if not blocksFolder then
	blocksFolder = Instance.new("Folder")
	blocksFolder.Name = "ArenaGiftBlocks"
	blocksFolder.Parent = Workspace
end

local function getArenaPlatform(): BasePart?
	local arenaDecor = Workspace:FindFirstChild("ArenaDecor")
	if arenaDecor then
		local platform = arenaDecor:FindFirstChild("ArenaPlatform")
		if platform and platform:IsA("BasePart") then
			return platform
		end
	end
	return nil
end

--============================================================--
-- Selección de jugador objetivo
--============================================================--

local function pickTargetPlayer(): Player?
	if TARGET_USERNAME ~= "" then
		for _, player in Players:GetPlayers() do
			if player.Name == TARGET_USERNAME then
				return player
			end
		end
		return nil
	end

	local candidates = Players:GetPlayers()
	if #candidates == 0 then
		return nil
	end

	return candidates[math.random(1, #candidates)]
end

--============================================================--
-- Efecto de impacto: burst de partículas + anillo que se expande
--============================================================--

local function spawnImpactEffect(position: Vector3)
	local burstAnchor = Instance.new("Part")
	burstAnchor.Name = "ImpactBurst"
	burstAnchor.Anchored = true
	burstAnchor.CanCollide = false
	burstAnchor.CanQuery = false
	burstAnchor.CastShadow = false
	burstAnchor.Transparency = 1
	burstAnchor.Size = Vector3.new(1, 1, 1)
	burstAnchor.CFrame = CFrame.new(position)
	burstAnchor.Parent = Workspace

	-- Nube de polvo (no chispas de neón): sin emisión de luz aditiva,
	-- afectada por la iluminación normal de la escena.
	local burst = Instance.new("ParticleEmitter")
	burst.Name = "DustBurst"
	burst.Enabled = false
	burst.Rate = 0
	burst.Lifetime = NumberRange.new(0.5, 0.9)
	burst.Speed = NumberRange.new(4, 10)
	burst.SpreadAngle = Vector2.new(180, 180)
	burst.Acceleration = Vector3.new(0, -2, 0)
	burst.LightEmission = 0
	burst.LightInfluence = 1
	burst.Color = ColorSequence.new(COLOR_DUST)
	burst.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.9),
		NumberSequenceKeypoint.new(1, 1.8),
	})
	burst.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	burst.Parent = burstAnchor
	burst:Emit(18)

	Debris:AddItem(burstAnchor, 2)

	-- Anillo de polvo que se expande sobre el piso (no neón)
	local ring = Instance.new("Part")
	ring.Name = "ImpactRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Sand
	ring.Color = COLOR_DUST
	ring.Transparency = 0.3
	ring.Size = Vector3.new(0.3, 2, 2)
	ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = Workspace

	local ringGoal = {
		Size = Vector3.new(0.3, 16, 16),
		Transparency = 1,
	}
	local ringTween = TweenService:Create(ring, TweenInfo.new(RING_BURST_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), ringGoal)
	ringTween:Play()

	Debris:AddItem(ring, RING_BURST_SECONDS + 0.5)
end

--============================================================--
-- Crea el bloque de regalo: pop -> caída -> impacto -> Debris
--============================================================--

local function createGiftBlock(event: LiveEvent, targetPosition: Vector3)
	if #blocksFolder:GetChildren() >= MAX_ACTIVE_BLOCKS then
		return -- límite de bloques activos alcanzado: se ignora el evento nuevo
	end

	local side = math.clamp(2 + event.value * 0.5, 2, 12)
	local color = BLOCK_COLORS[math.random(1, #BLOCK_COLORS)]
	local spawnPosition = targetPosition + Vector3.new(0, DROP_HEIGHT, 0)

	-- Tamaño final con variación por eje, para que se vea como una roca
	-- irregular en vez de un cubo perfecto.
	local function jitteredSide(): number
		return side * (1 + (math.random() * 2 - 1) * ROCK_SIZE_VARIANCE)
	end
	local finalSize = Vector3.new(jitteredSide(), jitteredSide(), jitteredSide())

	local block = Instance.new("Part")
	block.Name = "GiftBlock"
	block.Anchored = true -- se libera a la física tras el "pop"
	block.CanCollide = false
	block.Material = Enum.Material.Rock
	block.Color = color
	block.Size = Vector3.new(0.01, 0.01, 0.01) -- arranca "en 0" para el efecto pop
	block.CFrame = CFrame.new(spawnPosition) * CFrame.Angles(math.random() * math.pi, math.random() * math.pi, math.random() * math.pi)
	block.Parent = blocksFolder

	local label = Instance.new("BillboardGui")
	label.Name = "GiftLabel"
	label.Size = UDim2.new(0, 160, 0, 44)
	label.StudsOffset = Vector3.new(0, 2, 0)
	label.AlwaysOnTop = true
	label.Parent = block

	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.Size = UDim2.new(1, 0, 1, 0)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0.2
	text.TextStrokeColor3 = Color3.new(0, 0, 0)
	text.Text = string.format("%s\n%s", event.sender, event.gift)
	text.Parent = label

	Debris:AddItem(block, BLOCK_LIFETIME_SECONDS)

	-- "Pop": crece desde 0 con Back antes de empezar a caer
	local popGoal = { Size = finalSize }
	local popTween = TweenService:Create(block, TweenInfo.new(POP_TWEEN_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out), popGoal)

	popTween.Completed:Connect(function()
		if block.Parent == nil then
			return -- ya fue destruido (Debris) antes de terminar el pop
		end

		block.Anchored = false
		block.CanCollide = true

		local arenaPlatform = getArenaPlatform()
		local touchedConnection: RBXScriptConnection? = nil

		local function onTouched(hit: BasePart)
			if arenaPlatform ~= nil and hit ~= arenaPlatform then
				return -- solo el primer contacto con la plataforma cuenta como "tocar el suelo"
			end

			if touchedConnection ~= nil then
				touchedConnection:Disconnect()
				touchedConnection = nil
			end

			spawnImpactEffect(block.Position)
		end

		touchedConnection = block.Touched:Connect(onTouched)
	end)

	popTween:Play()
end

--============================================================--
-- Manejo de un evento de regalo ya decodificado
--============================================================--

local function handleGiftEvent(event: LiveEvent)
	local target = pickTargetPlayer()
	if target == nil then
		return -- sin jugadores en el servidor: se ignora el evento
	end

	local character = target.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not (rootPart and rootPart:IsA("BasePart")) then
		return -- el jugador objetivo no tiene personaje cargado todavía
	end

	createGiftBlock(event, rootPart.Position)
end

--============================================================--
-- Arranque: SIMULATE = true/false
--============================================================--

if SIMULATE then
	-- Alternativa mínima sin tocar la librería: como Bridge.Init ya fue
	-- llamado por LiveEventBridgeDemo con el transporte real, no podemos
	-- inyectarle un FakeTransport (Bridge.Init solo se puede llamar una
	-- vez). En vez de eso, usamos el Decoder puro de la librería
	-- directamente (no requiere Init) para simular regalos válidos según
	-- el contrato y los pasamos al mismo manejador de efectos.
	local Decoder = require(ServerScriptService.LiveEventBridge.Decoder)

	local SAMPLE_SENDERS = { "user123", "coco_fan", "neon_lover", "arena_vip" }
	local SAMPLE_GIFTS = { "Rose", "Corazón", "Galaxia", "León", "TikTok Universe" }

	task.spawn(function()
		while true do
			task.wait(3)

			local payload = HttpService:JSONEncode({
				v = 1,
				type = "gift",
				platform = "tiktok",
				channel = "arena-sim",
				sender = SAMPLE_SENDERS[math.random(1, #SAMPLE_SENDERS)],
				gift = SAMPLE_GIFTS[math.random(1, #SAMPLE_GIFTS)],
				value = math.random(1, 20),
				ts = DateTime.now().UnixTimestampMillis,
			})

			local event = Decoder.decode(payload)
			if event ~= nil then
				handleGiftEvent(event)
			end
		end
	end)

	print("ArenaServer: SIMULATE = true, generando regalos falsos cada 3s (sin tocar LiveEventBridge.Init)")
else
	-- Espera (con reintentos) a que Bridge.Init haya sido llamado por
	-- LiveEventBridgeDemo antes de suscribirse; el orden de ejecución
	-- entre Scripts hermanos de ServerScriptService no está garantizado.
	task.spawn(function()
		local subscribed = false
		while not subscribed do
			local ok = pcall(function()
				Bridge.OnGift(function(event: LiveEvent)
					if CHANNEL ~= "" and event.channel ~= CHANNEL then
						return
					end
					handleGiftEvent(event)
				end)
			end)

			if ok then
				subscribed = true
			else
				task.wait(0.2)
			end
		end

		print("ArenaServer: suscrito a Bridge.OnGift (transporte real)")
	end)
end
