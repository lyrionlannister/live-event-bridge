--!strict
-- FakeTransport: implementación de Transport para pruebas, sin tocar
-- ningún servicio de Roblox. Expone Emit(raw) para simular mensajes
-- entrantes.

local Types = require(script.Parent.Parent.Types)

type Transport = Types.Transport

export type FakeTransport = Transport & {
	Emit: (self: FakeTransport, raw: string) -> (),
}

local FakeTransport = {}
FakeTransport.__index = FakeTransport

function FakeTransport.new(): FakeTransport
	local self = setmetatable({}, FakeTransport)
	self._onRaw = nil :: ((data: string) -> ())?
	self._started = false
	return (self :: any) :: FakeTransport
end

function FakeTransport:Start(onRaw: (data: string) -> ())
	self._onRaw = onRaw
	self._started = true
end

function FakeTransport:Stop()
	self._onRaw = nil
	self._started = false
end

-- Simula un mensaje entrante crudo, como si viniera de MessagingService.
function FakeTransport:Emit(raw: string)
	if self._started and self._onRaw ~= nil then
		self._onRaw(raw)
	end
end

return FakeTransport
