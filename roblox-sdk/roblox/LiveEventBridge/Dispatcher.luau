--!strict
-- Dispatcher: mantiene la lista de listeners, filtra por canal y aísla
-- errores entre ellos. Lógica pura: no toca servicios de Roblox.

local Types = require(script.Parent.Types)

type LiveEvent = Types.LiveEvent
type GiftListener = Types.GiftListener
type Unsubscribe = Types.Unsubscribe

export type Dispatcher = {
	Subscribe: (self: Dispatcher, listener: GiftListener) -> Unsubscribe,
	Dispatch: (self: Dispatcher, event: LiveEvent) -> (),
	Clear: (self: Dispatcher) -> (),
}

local Dispatcher = {}
Dispatcher.__index = Dispatcher

function Dispatcher.new(channelFilter: string?): Dispatcher
	local self = setmetatable({}, Dispatcher)
	self._listeners = {} :: { [number]: GiftListener }
	self._nextId = 1
	self._channelFilter = channelFilter
	return (self :: any) :: Dispatcher
end

function Dispatcher:Subscribe(listener: GiftListener): Unsubscribe
	local id = self._nextId
	self._nextId += 1
	self._listeners[id] = listener

	return function()
		self._listeners[id] = nil
	end
end

function Dispatcher:Dispatch(event: LiveEvent)
	if self._channelFilter ~= nil and self._channelFilter ~= event.channel then
		return
	end

	for _, listener in self._listeners do
		task.spawn(listener, event)
	end
end

function Dispatcher:Clear()
	self._listeners = {}
end

return Dispatcher
