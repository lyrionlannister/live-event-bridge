# Contrato de mensaje — schema v1

Este documento define el contrato compartido entre el backend (Python,
`app/`) y el SDK de Roblox (`roblox/LiveEventBridge/`). Cualquier cambio a
este esquema debe versionarse (`v: 2`, etc.) y coordinarse en ambos lados.

## Transporte

- Canal: Roblox `MessagingService` (Open Cloud `PublishUniverseMessage` del
  lado del backend, `MessagingService:SubscribeAsync` del lado del juego).
- Topic por defecto: `"live-events"`.
- El payload publicado es el mensaje JSON serializado como **string plano**
  (no un objeto Lua/tabla). Roblox lo entrega en `message.Data` tal cual.

## Forma del mensaje (tipo `gift`)

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

| Campo      | Tipo               | Descripción                                                        |
|------------|---------------------|---------------------------------------------------------------------|
| `v`        | entero              | Versión del esquema. En este documento: `1`.                       |
| `type`     | string              | Tipo de evento. En el MVP, únicamente `"gift"`.                    |
| `platform` | string              | Plataforma de origen del evento (ej. `"tiktok"`).                  |
| `channel`  | string              | Usuario que transmite (canal de origen del evento).                |
| `sender`   | string              | Usuario que envió el regalo.                                       |
| `gift`     | string              | Nombre del regalo.                                                 |
| `value`    | número (`>= 0`)     | Valor numérico del regalo.                                         |
| `ts`       | entero              | Timestamp Unix en **milisegundos**, generado por el backend.       |

## Restricciones

- **Tamaño máximo del mensaje serializado:** 1024 caracteres (límite duro de
  `MessagingService`: 1 KiB por mensaje).
- **Topic:** máximo 80 caracteres (límite de `MessagingService`); el valor
  por defecto usado por este contrato es `"live-events"`.
- `ts` debe estar en milisegundos, no segundos, para ser comparable
  directamente con `DateTime.now().UnixTimestampMillis` del lado de Roblox.
- Mensajes que no cumplan esta forma exacta (campo faltante, tipo
  incorrecto, `v ~= 1`, o `type ~= "gift"`) deben descartarse silenciosamente
  del lado de Roblox (ver `Decoder.luau`); no se lanza ningún error visible
  al desarrollador que integra el SDK.

## Notas de sincronización de reloj

`ts` lo genera el backend con su propio reloj. La métrica de latencia que
expone el SDK (`config.debug = true`) solo es significativa si el reloj del
backend y el reloj de los servidores de Roblox están razonablemente
sincronizados (ambos NTP-sincronizados es la expectativa normal, pero no
está garantizado ni verificado por este contrato).

## Fuera de alcance en v1

- Otros `type` distintos de `"gift"` (ej. follow, like, comentario).
- Otras `platform` distintas de `"tiktok"`.
- Reconexión automática o transporte alternativo (polling) del lado de
  Roblox: hoy solo existe `MessagingTransport`.
