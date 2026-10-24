--!strict
-- LiveEventBridge: API pública del SDK.
-- Conecta eventos de streaming en vivo (vía MessagingService) con juegos
-- de Roblox. Ver contract/schema-v1.md para el contrato de mensaje.

local RunService = game:GetService("RunService")

local Types = require(script.Types)
local Decoder = require(script.Decoder)
local Dispatcher = require(script.Dispatcher)
local MessagingTransport = require(script.Transport.MessagingTransport)

type Config = Types.Config
type Transport = Types.Transport
type GiftListener = Types.GiftListener
type Unsubscribe = Types.Unsubscribe

local DEFAULT_TOPIC = "live-events"

local LiveEventBridge = {}

local _initialized = false
local _transport: Transport? = nil
local _dispatcher = nil :: any
local _debug = false

-- Init(config): inicializa el SDK. Debe llamarse una sola vez, desde el
-- servidor.
function LiveEventBridge.Init(config: Config?)
	assert(RunService:IsServer(), "LiveEventBridge.Init debe llamarse desde el servidor")
	assert(not _initialized, "LiveEventBridge.Init ya fue llamado")

	local cfg: Config = config or {}
	local topic = cfg.topic or DEFAULT_TOPIC
	_debug = cfg.debug == true

	_dispatcher = Dispatcher.new(cfg.channel)
	_transport = cfg.transport or MessagingTransport.new(topic)

	_transport:Start(function(raw: string)
		local event = Decoder.decode(raw)
		if event == nil then
			return
		end

		if _debug then
			-- La medida de latencia depende de que los relojes del backend
			-- y de Roblox estén sincronizados; es solo una aproximación.
			local latencyMs = DateTime.now().UnixTimestampMillis - event.ts
			print(("LiveEventBridge: latencyMs = %d"):format(latencyMs))
		end

		_dispatcher:Dispatch(event)
	end)

	_initialized = true
end

-- OnGift(callback): registra un listener para eventos de tipo "gift".
-- Devuelve una función para desuscribirse.
function LiveEventBridge.OnGift(callback: GiftListener): Unsubscribe
	assert(_initialized, "LiveEventBridge.Init debe llamarse antes de OnGift")
	return _dispatcher:Subscribe(callback)
end

-- Destroy(): detiene el transporte y limpia todos los listeners.
function LiveEventBridge.Destroy()
	if _transport ~= nil then
		_transport:Stop()
		_transport = nil
	end

	if _dispatcher ~= nil then
		_dispatcher:Clear()
		_dispatcher = nil
	end

	_initialized = false
end

return LiveEventBridge
