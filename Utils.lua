-- Utilidades generales.
local AFP = AlchemyFavoritePotions

local CHAT_PREFIX = "[Alchemy Favorite Potions] "

--- Escribe un mensaje en el chat con el prefijo del addon
function AFP.Print(text)
    d(CHAT_PREFIX .. text)
end
