--!strict
-- Decoder: string JSON crudo -> LiveEvent validado, o nil.
-- Lógica pura: no toca servicios de Roblox. Nunca lanza errores.

local Types = require(script.Parent.Types)

type LiveEvent = Types.LiveEvent

local Decoder = {}

local function isNonEmptyString(value: any): boolean
	return type(value) == "string" and value ~= ""
end

-- Valida y construye un LiveEvent a partir de una tabla ya decodificada.
-- Devuelve nil si falta algún campo, tiene el tipo incorrecto, v ~= 1, o
-- type ~= "gift".
local function validate(decoded: any): LiveEvent?
	if type(decoded) ~= "table" then
		return nil
	end

	if type(decoded.v) ~= "number" or decoded.v ~= 1 then
		return nil
	end

	if decoded.type ~= "gift" then
		return nil
	end

	if not isNonEmptyString(decoded.platform) then
		return nil
	end

	if not isNonEmptyString(decoded.channel) then
		return nil
	end

	if not isNonEmptyString(decoded.sender) then
		return nil
	end

	if not isNonEmptyString(decoded.gift) then
		return nil
	end

	if type(decoded.value) ~= "number" or decoded.value < 0 then
		return nil
	end

	if type(decoded.ts) ~= "number" then
		return nil
	end

	return {
		v = 1,
		type = "gift",
		platform = decoded.platform,
		channel = decoded.channel,
		sender = decoded.sender,
		gift = decoded.gift,
		value = decoded.value,
		ts = decoded.ts,
	}
end

function Decoder.decode(raw: string): LiveEvent?
	local ok, decoded = pcall(function()
		return game:GetService("HttpService"):JSONDecode(raw)
	end)

	if not ok then
		return nil
	end

	return validate(decoded)
end

return Decoder
