# LiveEventBridge

SDK de Luau para recibir eventos de streaming en vivo (TikTok, vía
`live-event-bridge` backend) dentro de un juego de Roblox. MVP: solo eventos
de tipo `gift`. Ver [`contract/schema-v1.md`](../contract/schema-v1.md)
para el contrato de mensaje completo.

## Instalación

Copia el folder `LiveEventBridge/` completo a `ServerScriptService` (u otro
contenedor accesible desde el servidor). No tiene dependencias externas —
no requiere Rojo ni Wally, aunque es compatible con ambos si tu proyecto
ya los usa.

## Uso mínimo

```lua
local ServerScriptService = game:GetService("ServerScriptService")
local LiveEventBridge = require(ServerScriptService.LiveEventBridge)

LiveEventBridge.Init({
	-- topic = "live-events", -- por defecto
	-- channel = "nombre_streamer", -- opcional: filtra por canal
	debug = true, -- imprime latencyMs por cada evento recibido
})

local unsubscribe = LiveEventBridge.OnGift(function(event)
	print(event.sender, "envió", event.gift, "x" .. event.value)
end)

-- unsubscribe() -- deja de escuchar
-- LiveEventBridge.Destroy() -- apaga el SDK por completo
```

Ver [`examples/basic_usage.server.luau`](../examples/basic_usage.server.luau)
para un ejemplo ejecutable.

## Esquema v1 (evento `gift`)

```json
{
	"v": 1,
	"type": "gift",
	"platform": "tiktok",
	"channel": "nombre_streamer",
	"sender": "user123",
	"gift": "Rose",
	"value": 1,
	"ts": 1790000000000
}
```

Mensajes que no cumplan exactamente esta forma se descartan en silencio
(no se lanza ningún error al juego). Detalle completo en
[`contract/schema-v1.md`](../contract/schema-v1.md).

## Pruebas sin servicios de Roblox

Inyecta `Transport/FakeTransport.luau` en `Init` para simular mensajes sin
depender de `MessagingService`:

```lua
local FakeTransport = require(ServerScriptService.LiveEventBridge.Transport.FakeTransport)
local fake = FakeTransport.new()

LiveEventBridge.Init({ transport = fake })

fake:Emit('{"v":1,"type":"gift","platform":"tiktok","channel":"foo","sender":"bar","gift":"Rose","value":1,"ts":1790000000000}')
```
