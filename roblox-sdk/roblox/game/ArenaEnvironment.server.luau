--!strict
-- ArenaEnvironment: construye una arena romana clásica (ladrillo, piedra,
-- piso de arena) sobre el juego existente, sin tocar el Baseplate ni el
-- SpawnLocation originales (el SpawnLocation se reutiliza reposicionado).
--
-- Idempotente: se puede correr varias veces. Al iniciar, borra únicamente
-- la carpeta "ArenaDecor" que este mismo script creó antes, y reconstruye.

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

-- Origen de la arena: centro de la SUPERFICIE de la plataforma. Elevado
-- sobre el Baseplate por defecto (que ocupa Y en [-8, 0]) para que no
-- choquen entre sí.
local ARENA_ORIGIN = Vector3.new(0, 50, 0)

-- Paleta "coliseo romano": piedra, ladrillo, arena y acentos dorados.
local COLOR_SAND = Color3.fromRGB(214, 181, 130) -- piso: "arena" (literal)
local COLOR_STONE_LIGHT = Color3.fromRGB(196, 176, 142) -- columnas, capiteles
local COLOR_STONE_DARK = Color3.fromRGB(112, 90, 64) -- base del muro, sombra
local COLOR_BRICK = Color3.fromRGB(150, 92, 62) -- muro perimetral
local COLOR_GOLD = Color3.fromRGB(198, 156, 66) -- franjas y trim
local COLOR_BANNER = Color3.fromRGB(120, 32, 26) -- estandartes
local COLOR_FIRE_PRIMARY = Color3.fromRGB(255, 140, 40)
local COLOR_FIRE_SECONDARY = Color3.fromRGB(255, 220, 120)
local COLOR_ATMOSPHERE = Color3.fromRGB(255, 214, 170) -- neblina dorada de mediodía
local COLOR_ATMOSPHERE_DECAY = Color3.fromRGB(220, 180, 140)

-- Materiales
local MATERIAL_FLOOR = Enum.Material.Sand
local MATERIAL_WALL = Enum.Material.Brick
local MATERIAL_TRIM = Enum.Material.Marble
local MATERIAL_PILLAR = Enum.Material.Concrete
local MATERIAL_CAPITAL = Enum.Material.Marble

-- Dimensiones de la arena
local PLATFORM_DIAMETER = 80
local PLATFORM_THICKNESS = 4
local PLATFORM_RADIUS = PLATFORM_DIAMETER / 2

local WALL_HEIGHT = 8
local WALL_THICKNESS = 3
local MERLON_EXTRA_HEIGHT = 3 -- almenas alternadas (silueta de fortaleza)
local WALL_SEGMENTS = 32

local PILLAR_COUNT = 8
local PILLAR_HEIGHT = 34
local PILLAR_THICKNESS = 4
local PILLAR_RADIUS = PLATFORM_RADIUS + 14
local CAPITAL_SIZE = Vector3.new(PILLAR_THICKNESS + 2.5, 2, PILLAR_THICKNESS + 2.5)
local FIRE_SIZE = 10

-- Anillos decorativos en el piso (línea de frontera del "arena")
local BOUNDARY_RING_SEGMENTS = 28

-- Partículas ambientales (polvo, no neón)
local DUST_RATE = 3

--============================================================--
-- Limpieza idempotente y carpeta contenedora
--============================================================--

local existingDecor = Workspace:FindFirstChild("ArenaDecor")
if existingDecor then
	existingDecor:Destroy()
end

local decor = Instance.new("Folder")
decor.Name = "ArenaDecor"
decor.Parent = Workspace

--============================================================--
-- Helper: anillo de bloques alrededor de un centro (mirando hacia él)
--============================================================--

local function createRing(
	parentFolder: Folder,
	name: string,
	center: Vector3,
	radius: number,
	segments: number,
	sizeFn: (index: number) -> Vector3,
	yOffsetFn: (index: number) -> number,
	colorFn: (index: number) -> Color3,
	material: Enum.Material,
	canCollide: boolean
): Folder
	local ring = Instance.new("Folder")
	ring.Name = name
	ring.Parent = parentFolder

	for i = 1, segments do
		local angle = (i / segments) * math.pi * 2
		local x = math.cos(angle) * radius
		local z = math.sin(angle) * radius
		local yOffset = yOffsetFn(i)
		local position = center + Vector3.new(x, yOffset, z)
		local lookAt = center + Vector3.new(0, yOffset, 0)

		local segment = Instance.new("Part")
		segment.Name = name .. i
		segment.Anchored = true
		segment.CanCollide = canCollide
		segment.CastShadow = true
		segment.Material = material
		segment.Color = colorFn(i)
		segment.Size = sizeFn(i)
		segment.CFrame = CFrame.new(position, lookAt)
		segment.Parent = ring
	end

	return ring
end

--============================================================--
-- Plataforma central circular: piso de arena
--============================================================--

local platform = Instance.new("Part")
platform.Name = "ArenaPlatform"
platform.Shape = Enum.PartType.Cylinder
platform.Anchored = true
platform.CanCollide = true
platform.Material = MATERIAL_FLOOR
platform.Color = COLOR_SAND
-- El eje del cilindro va en Size.X; se rota 90° en Z para que quede
-- acostado como una plataforma (círculo mirando hacia arriba).
platform.Size = Vector3.new(PLATFORM_THICKNESS, PLATFORM_DIAMETER, PLATFORM_DIAMETER)
platform.CFrame = CFrame.new(ARENA_ORIGIN - Vector3.new(0, PLATFORM_THICKNESS / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
platform.Parent = decor

local floorTopY = 0.05

-- Línea de frontera dorada cerca del borde de la arena (marca el límite
-- de combate, como en un coliseo real)
createRing(
	decor,
	"BoundaryRing",
	ARENA_ORIGIN,
	PLATFORM_RADIUS - 3,
	BOUNDARY_RING_SEGMENTS,
	function(_i)
		return Vector3.new((2 * math.pi * (PLATFORM_RADIUS - 3)) / BOUNDARY_RING_SEGMENTS * 1.05, 0.3, 1.2)
	end,
	function(_i)
		return floorTopY
	end,
	function(_i)
		return COLOR_GOLD
	end,
	MATERIAL_TRIM,
	false
)

--============================================================--
-- Muro perimetral con almenas alternadas (silueta de fortaleza)
--============================================================--

createRing(
	decor,
	"Wall",
	ARENA_ORIGIN,
	PLATFORM_RADIUS,
	WALL_SEGMENTS,
	function(i)
		local height = (i % 2 == 0) and (WALL_HEIGHT + MERLON_EXTRA_HEIGHT) or WALL_HEIGHT
		return Vector3.new((2 * math.pi * PLATFORM_RADIUS) / WALL_SEGMENTS * 1.08, height, WALL_THICKNESS)
	end,
	function(i)
		local height = (i % 2 == 0) and (WALL_HEIGHT + MERLON_EXTRA_HEIGHT) or WALL_HEIGHT
		return height / 2
	end,
	function(i)
		return (i % 2 == 0) and COLOR_STONE_DARK or COLOR_BRICK
	end,
	MATERIAL_WALL,
	true
)

-- Franja dorada que marca la base del muro
createRing(
	decor,
	"WallTrim",
	ARENA_ORIGIN,
	PLATFORM_RADIUS,
	WALL_SEGMENTS,
	function(_i)
		return Vector3.new((2 * math.pi * PLATFORM_RADIUS) / WALL_SEGMENTS * 1.08, 0.8, WALL_THICKNESS + 0.3)
	end,
	function(_i)
		return WALL_HEIGHT - 0.5
	end,
	function(_i)
		return COLOR_GOLD
	end,
	MATERIAL_TRIM,
	false
)

--============================================================--
-- Punto de aparición: reutiliza el SpawnLocation existente
--============================================================--

local existingSpawn = Workspace:FindFirstChildOfClass("SpawnLocation")
if existingSpawn then
	existingSpawn.CFrame = CFrame.new(ARENA_ORIGIN + Vector3.new(0, existingSpawn.Size.Y / 2 + floorTopY, 0))
else
	warn("ArenaEnvironment: no se encontró un SpawnLocation existente para reposicionar; no se creó uno nuevo.")
end

--============================================================--
-- Columnas de piedra con antorchas encendidas
--============================================================--

local pillars = Instance.new("Folder")
pillars.Name = "Pillars"
pillars.Parent = decor

for i = 1, PILLAR_COUNT do
	local angle = (i / PILLAR_COUNT) * math.pi * 2
	local x = math.cos(angle) * PILLAR_RADIUS
	local z = math.sin(angle) * PILLAR_RADIUS
	local base = ARENA_ORIGIN + Vector3.new(x, 0, z)

	local shaft = Instance.new("Part")
	shaft.Name = "PillarShaft" .. i
	shaft.Shape = Enum.PartType.Cylinder
	shaft.Anchored = true
	shaft.CanCollide = false
	shaft.CastShadow = true
	shaft.Material = MATERIAL_PILLAR
	shaft.Color = COLOR_STONE_LIGHT
	shaft.Size = Vector3.new(PILLAR_HEIGHT, PILLAR_THICKNESS, PILLAR_THICKNESS)
	shaft.CFrame = CFrame.new(base + Vector3.new(0, PILLAR_HEIGHT / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	shaft.Parent = pillars

	local capital = Instance.new("Part")
	capital.Name = "PillarCapital" .. i
	capital.Anchored = true
	capital.CanCollide = false
	capital.CastShadow = true
	capital.Material = MATERIAL_CAPITAL
	capital.Color = COLOR_STONE_LIGHT
	capital.Size = CAPITAL_SIZE
	capital.CFrame = CFrame.new(base + Vector3.new(0, PILLAR_HEIGHT, 0))
	capital.Parent = pillars

	local torchBowl = Instance.new("Part")
	torchBowl.Name = "TorchBowl" .. i
	torchBowl.Anchored = true
	torchBowl.CanCollide = false
	torchBowl.CastShadow = false
	torchBowl.Material = MATERIAL_PILLAR
	torchBowl.Color = COLOR_STONE_DARK
	torchBowl.Size = Vector3.new(1.6, 1, 1.6)
	torchBowl.CFrame = CFrame.new(base + Vector3.new(0, PILLAR_HEIGHT + 1.5, 0))
	torchBowl.Parent = pillars

	local fire = Instance.new("Fire")
	fire.Heat = 9
	fire.Size = FIRE_SIZE
	fire.Color = COLOR_FIRE_PRIMARY
	fire.SecondaryColor = COLOR_FIRE_SECONDARY
	fire.Parent = torchBowl

	local light = Instance.new("PointLight")
	light.Color = COLOR_FIRE_PRIMARY
	light.Range = FIRE_SIZE * 2
	light.Brightness = 3
	light.Parent = torchBowl
end

--============================================================--
-- Estandartes rojos colgando del muro (detalle decorativo)
--============================================================--

local banners = Instance.new("Folder")
banners.Name = "Banners"
banners.Parent = decor

local BANNER_COUNT = 8
for i = 1, BANNER_COUNT do
	local angle = ((i - 0.5) / BANNER_COUNT) * math.pi * 2
	local x = math.cos(angle) * (PLATFORM_RADIUS - 0.2)
	local z = math.sin(angle) * (PLATFORM_RADIUS - 0.2)
	local position = ARENA_ORIGIN + Vector3.new(x, WALL_HEIGHT * 0.55, z)
	local lookAt = ARENA_ORIGIN + Vector3.new(0, WALL_HEIGHT * 0.55, 0)

	local banner = Instance.new("Part")
	banner.Name = "Banner" .. i
	banner.Anchored = true
	banner.CanCollide = false
	banner.CastShadow = false
	banner.Material = Enum.Material.Fabric
	banner.Color = COLOR_BANNER
	banner.Size = Vector3.new(3.5, 6, 0.3)
	banner.CFrame = CFrame.new(position, lookAt)
	banner.Parent = banners
end

--============================================================--
-- Partículas ambientales: polvo suave, tasa baja
--============================================================--

local dustAnchor = Instance.new("Part")
dustAnchor.Name = "DustAnchor"
dustAnchor.Anchored = true
dustAnchor.CanCollide = false
dustAnchor.CanQuery = false
dustAnchor.CastShadow = false
dustAnchor.Transparency = 1
dustAnchor.Size = Vector3.new(PLATFORM_DIAMETER * 0.9, 1, PLATFORM_DIAMETER * 0.9)
dustAnchor.CFrame = CFrame.new(ARENA_ORIGIN + Vector3.new(0, 3, 0))
dustAnchor.Parent = decor

local dust = Instance.new("ParticleEmitter")
dust.Name = "AmbientDust"
dust.Shape = Enum.ParticleEmitterShape.Box
dust.Rate = DUST_RATE
dust.Lifetime = NumberRange.new(5, 9)
dust.Speed = NumberRange.new(0.3, 1)
dust.SpreadAngle = Vector2.new(180, 180)
dust.Acceleration = Vector3.new(0, 0.3, 0)
dust.LightInfluence = 1
dust.LightEmission = 0
dust.Color = ColorSequence.new(COLOR_SAND)
dust.Size = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.25),
	NumberSequenceKeypoint.new(1, 0.05),
})
dust.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.6),
	NumberSequenceKeypoint.new(0.8, 0.7),
	NumberSequenceKeypoint.new(1, 1),
})
dust.Parent = dustAnchor

--============================================================--
-- Lighting, Atmosphere, Sky: mediodía soleado y cálido
--============================================================--

-- Valores anteriores (versión "synthwave" que precedió a esta):
-- ClockTime 21, Ambient (70,40,110), OutdoorAmbient (60,35,100),
-- Brightness 3, Atmosphere Density 0.2/Haze 0.8, Bloom Intensity 1.6 /
-- Threshold 1 / Size 30, ColorCorrection Saturation 0.35.

Lighting.ClockTime = 13
Lighting.Ambient = Color3.fromRGB(150, 130, 105)
Lighting.OutdoorAmbient = Color3.fromRGB(170, 150, 120)
Lighting.Brightness = 2.5

local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
if atmosphere then
	atmosphere.Density = 0.15
	atmosphere.Haze = 1.2
	atmosphere.Glare = 0.1
	atmosphere.Color = COLOR_ATMOSPHERE
	atmosphere.Decay = COLOR_ATMOSPHERE_DECAY
end

local sky = Lighting:FindFirstChildOfClass("Sky")
if sky then
	sky.SunAngularSize = 15
	sky.MoonAngularSize = 11
	sky.CelestialBodiesShown = true
end

local bloom = Lighting:FindFirstChild("Bloom")
if bloom and bloom:IsA("BloomEffect") then
	bloom.Intensity = 0.3
	bloom.Threshold = 3
	bloom.Size = 24
end

local colorCorrection = Lighting:FindFirstChild("ArenaColorCorrection")
if not colorCorrection then
	colorCorrection = Instance.new("ColorCorrectionEffect")
	colorCorrection.Name = "ArenaColorCorrection"
	colorCorrection.Parent = Lighting
end
if colorCorrection:IsA("ColorCorrectionEffect") then
	colorCorrection.Saturation = 0.1
	colorCorrection.Contrast = 0.1
	colorCorrection.Brightness = 0
	colorCorrection.TintColor = Color3.fromRGB(255, 244, 225)
end

print("ArenaEnvironment: coliseo romano construido en Workspace.ArenaDecor")
