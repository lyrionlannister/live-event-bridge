--!strict
-- MessagingTransport: único módulo que toca MessagingService.
-- Entrega strings crudos vía onRaw; no decodifica ni filtra.

local MessagingService = game:GetService("MessagingService")

local Types = require(script.Parent.Parent.Types)

type Transport = Types.Transport

export type MessagingTransport = Transport & {
	new: (topic: string) -> MessagingTransport,
}

local MessagingTransport = {}
MessagingTransport.__index = MessagingTransport

function MessagingTransport.new(topic: string): Transport
	local self = setmetatable({}, MessagingTransport)
	self._topic = topic
	self._connection = nil :: RBXScriptConnection?
	return (self :: any) :: Transport
end

function MessagingTransport:Start(onRaw: (data: string) -> ())
	local ok, connectionOrError = pcall(function()
		return MessagingService:SubscribeAsync(self._topic, function(message)
			if type(message.Data) == "string" then
				onRaw(message.Data)
			end
		end)
	end)

	if not ok then
		warn(
			("LiveEventBridge: falló SubscribeAsync en el topic '%s': %s"):format(
				self._topic,
				tostring(connectionOrError)
			)
		)
		return
	end

	self._connection = connectionOrError
end

function MessagingTransport:Stop()
	if self._connection ~= nil then
		self._connection:Disconnect()
		self._connection = nil
	end
end

return MessagingTransport
