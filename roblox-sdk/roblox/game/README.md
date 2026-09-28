# Arena romana (coliseo) — integración de juego

Esta carpeta integra una "arena de regalos" visual en el juego de prueba
existente (`roblox-sdk/roblox/LiveEventBridge/`), sin reemplazar nada de lo
que ya había ahí.

## Qué se integró y qué se dejó intacto

**Se dejó intacto (no se tocó):**
- `ServerScriptService.LiveEventBridge` (la librería SDK completa).
- `ServerScriptService.LiveEventBridgeDemo`: sigue llamando
  `Bridge.Init({ debug = true })` y sigue mostrando su propio GUI de texto
  con el último evento. `ArenaServer` **no** vuelve a llamar `Bridge.Init`
  (solo se puede llamar una vez) — se suscribe con `Bridge.OnGift` en
  paralelo, así que ambos efectos (el texto del demo y los bloques de la
  arena) ocurren para el mismo evento, sin duplicar la suscripción a
  `MessagingService`.
- `Workspace.Baseplate` y `Workspace.SpawnLocation` originales como
  instancias — `SpawnLocation` se **reposiciona** (no se borra ni se crea
  uno nuevo) al centro de la nueva arena.
- `Lighting.SunRaysEffect` y `Lighting.DepthOfFieldEffect`: no se tocaron.

**Se modificó (con los valores anteriores documentados en los comentarios
de `ArenaEnvironment.server.luau` — el script pasó por dos rediseños
estéticos antes de llegar al coliseo romano actual, y cada versión anota
los valores de la anterior):**
- `Lighting.ClockTime`, `Ambient`, `OutdoorAmbient`, `Brightness`.
- `Lighting.Atmosphere` (Density, Haze, Glare, Color, Decay).
- `Lighting.Sky` (SunAngularSize, MoonAngularSize).
- `Lighting.Bloom` (Intensity, Threshold, Size) — bajo, casi sin efecto:
  esta estética no depende de neón/bloom como las anteriores.
- Se **agregó** un `ColorCorrectionEffect` nuevo (no existía antes).

**Se creó desde cero:**
- `Workspace.ArenaDecor`: toda la arena (plataforma de arena, línea de
  frontera dorada, muro de ladrillo con almenas, columnas con antorchas,
  estandartes, partículas de polvo ambiental). Se reconstruye por completo
  cada vez que corre `ArenaEnvironment` (borra solo esa carpeta).
- `Workspace.ArenaGiftBlocks`: contenedor de las rocas de regalo activas
  (no se toca al re-correr `ArenaEnvironment`).

## Instalación

### (a) Automática, con el MCP de Roblox Studio

Si tienes el MCP de Roblox Studio conectado, pide que se creen/actualicen
`ArenaEnvironment` y `ArenaServer` como `Script` dentro de
`ServerScriptService`, con el contenido de estos dos archivos. Es lo que se
hizo para construir y probar esta integración.

### (b) Manual

1. Copia el contenido de `LiveEventBridge/` a `ServerScriptService` (si no
   está ya ahí — en el juego de prueba ya está instalado).
2. Crea un `Script` en `ServerScriptService` llamado `ArenaEnvironment`, y
   pega el contenido de `ArenaEnvironment.server.luau`.
3. Crea otro `Script` en `ServerScriptService` llamado `ArenaServer`, y
   pega el contenido de `ArenaServer.server.luau`.
4. Asegúrate de que `ArenaEnvironment` corra antes de que los jugadores
   necesiten la arena (simplemente por estar en `ServerScriptService` ya se
   ejecuta al iniciar el servidor).

## Probar con SIMULATE = true (sin backend)

Edita la constante al inicio de `ArenaServer.server.luau`:

```lua
local SIMULATE = true
```

Como `Bridge.Init` ya fue llamado por `LiveEventBridgeDemo` con el
transporte real, `ArenaServer` **no puede** inyectarle un `FakeTransport`
(el `Init` de la librería solo se puede llamar una vez, y modificar eso
significaría tocar la librería). La alternativa mínima que se usa: llamar
directamente al `Decoder` puro de la librería (que no requiere `Init`) con
JSON simulado que cumple `contract/schema-v1.md`, y pasar el evento ya
decodificado al mismo manejador de efectos que usa el camino real. Cada 3
segundos aparece un regalo falso.

Dale a Play en Studio y deberías ver rocas cayendo sobre un jugador cada
~3 segundos. Vuelve a poner `SIMULATE = false` antes de publicar.

## Probar con eventos reales

1. Deja `SIMULATE = false` (el valor por defecto).
2. Publica el place (File → Publish to Roblox) — **importante**: según la
   documentación oficial de Roblox
   ([Messaging usage guide](https://create.roblox.com/docs/cloud/guides/usage-messaging)),
   un playtest de Studio puede *suscribirse* a un topic con
   `MessagingService:SubscribeAsync`, pero **no recibe** mensajes
   publicados desde Open Cloud (`PublishUniverseMessage`) — eso solo
   funciona en un servidor ya publicado y en vivo. Por eso la verificación
   de esta integración se hizo con `SIMULATE = true`, no contra el backend
   real, dentro de Studio.
3. Levanta el backend (`uv run uvicorn interfaces.api.main:app --reload`,
   o el contenedor con `podman compose up`).
4. Entra al juego publicado (no Play Solo en Studio) y haz que llegue un
   regalo real en el live de TikTok configurado en el backend.
5. Deberías ver la roca caer sobre un jugador del servidor.

## Ajustar la estética

Todas las constantes están al inicio de cada archivo, sin números mágicos
dispersos en el resto del código.

**En `ArenaEnvironment.server.luau`:**
- `COLOR_SAND`, `COLOR_STONE_LIGHT`, `COLOR_STONE_DARK`, `COLOR_BRICK`,
  `COLOR_GOLD`, `COLOR_BANNER`, `COLOR_FIRE_PRIMARY/SECONDARY`,
  `COLOR_ATMOSPHERE*`: paleta general (piedra, ladrillo, arena, dorado).
- `MATERIAL_FLOOR`, `MATERIAL_WALL`, `MATERIAL_TRIM`, `MATERIAL_PILLAR`,
  `MATERIAL_CAPITAL`: materiales de Roblox usados en cada elemento.
- `PLATFORM_DIAMETER`, `PLATFORM_THICKNESS`, `WALL_HEIGHT`,
  `WALL_THICKNESS`, `MERLON_EXTRA_HEIGHT`: dimensiones de la plataforma y
  el muro (las almenas alternan `WALL_HEIGHT` y
  `WALL_HEIGHT + MERLON_EXTRA_HEIGHT`).
- `PILLAR_COUNT`, `PILLAR_HEIGHT`, `PILLAR_RADIUS`, `FIRE_SIZE`: columnas
  y el tamaño de sus antorchas (`Fire` + `PointLight`).
- `BANNER_COUNT`: cantidad de estandartes colgados del muro.
- `DUST_RATE`: tasa de partículas ambientales de polvo.
- Bloque final del script: valores de `Lighting`, `Atmosphere`, `Sky`,
  `Bloom` y `ColorCorrectionEffect` (mediodía soleado y cálido).
- `ARENA_ORIGIN`: mueve toda la arena (útil si choca con algo más que se
  agregue después al Workspace).

**En `ArenaServer.server.luau`:**
- `CHANNEL`, `TARGET_USERNAME`, `SIMULATE`, `MAX_ACTIVE_BLOCKS`.
- `BLOCK_COLORS`: tonos de roca posibles; `COLOR_DUST`: color del polvo de
  impacto.
- `ROCK_SIZE_VARIANCE`: cuánto varía cada eje de la roca para que no se
  vea como un cubo perfecto.
- `DROP_HEIGHT`, `POP_TWEEN_SECONDS`, `RING_BURST_SECONDS`,
  `BLOCK_LIFETIME_SECONDS`.
