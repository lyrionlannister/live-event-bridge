--!strict
-- Ejemplo mínimo de uso de LiveEventBridge.
-- Copia el folder LiveEventBridge a ServerScriptService y ajusta el
-- require de abajo según dónde lo hayas colocado.

local ServerScriptService = game:GetService("ServerScriptService")
local LiveEventBridge = require(ServerScriptService.LiveEventBridge)

LiveEventBridge.Init({
	-- topic = "live-events", -- por defecto
	-- channel = "nombre_streamer", -- opcional: filtra por canal
	debug = true,
})

local unsubscribe = LiveEventBridge.OnGift(function(event)
	print(("%s envió %s (x%d) en el canal de %s"):format(event.sender, event.gift, event.value, event.channel))
end)

-- Para dejar de escuchar más adelante:
-- unsubscribe()

-- Para apagar el SDK por completo (detiene el transporte y limpia listeners):
-- LiveEventBridge.Destroy()
