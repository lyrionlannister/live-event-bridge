--!strict
-- Tipos compartidos del SDK LiveEventBridge.
-- Ver contract/schema-v1.md para el contrato de mensaje completo.

export type LiveEvent = {
	v: number,
	type: "gift",
	platform: string,
	channel: string,
	sender: string,
	gift: string,
	value: number,
	ts: number,
}

-- Contrato de transporte: solo entrega strings crudos. No decodifica,
-- no filtra, no conoce a los listeners del Dispatcher.
export type Transport = {
	Start: (self: Transport, onRaw: (data: string) -> ()) -> (),
	Stop: (self: Transport) -> (),
}

export type Config = {
	-- Topic de MessagingService a escuchar. Por defecto: "live-events".
	topic: string?,
	-- Si está definido, solo se despachan eventos cuyo `channel` coincida.
	channel: string?,
	-- Transporte a usar. Por defecto: MessagingTransport. Se puede
	-- inyectar FakeTransport para pruebas sin servicios de Roblox.
	transport: Transport?,
	-- Si es true, imprime latencyMs por cada evento válido recibido.
	debug: boolean?,
}

export type GiftListener = (event: LiveEvent) -> ()

-- Función de desuscripción devuelta por OnGift.
export type Unsubscribe = () -> ()

return {}
