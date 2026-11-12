-- Datos de las favoritas: combinación puesta en las ranuras, guardado y filas de la lista.
local AFP = AlchemyFavoritePotions

--- Estado de la combinación puesta en las ranuras
AFP.COMBINATION_STATUS = {
    READY = 1,      -- se puede guardar
    INCOMPLETE = 2, -- falta disolvente o reactivos
    INVALID = 3,    -- los reactivos no producen ninguna poción
    UNKNOWN = 4,    -- el resultado aún no es conocido para el personaje
}

--- Identificador de una combinación: disolvente + reactivos ordenados.
-- No depende de la posición en el inventario ni del orden de las ranuras.
local function GetCombinationKey(solventLink, reagentLinks)
    local reagentIds = {}
    for _, reagentLink in ipairs(reagentLinks) do
        reagentIds[#reagentIds + 1] = GetItemLinkItemId(reagentLink)
    end
    table.sort(reagentIds)

    return string.format("%d:%s", GetItemLinkItemId(solventLink), table.concat(reagentIds, ","))
end

--- Identificador de una combinación con la forma { solvent, reagents, potion }
function AFP.GetFavoriteKey(combination)
    return GetCombinationKey(combination.solvent, combination.reagents)
end

--- Lee la combinación puesta en las ranuras de la mesa de alquimia.
-- Devuelve la combinación (solo si se puede guardar) y su estado.
function AFP.GetCurrentCombination()
    if not ALCHEMY or not ALCHEMY:IsCraftable() then
        return nil, AFP.COMBINATION_STATUS.INCOMPLETE
    end

    local solventBag, solventSlot, reagent1Bag, reagent1Slot, reagent2Bag, reagent2Slot, reagent3Bag, reagent3Slot =
        ALCHEMY:GetAllCraftingBagAndSlots()

    local potionLink, prospectiveResult = GetAlchemyResultingItemLink(
        solventBag, solventSlot,
        reagent1Bag, reagent1Slot,
        reagent2Bag, reagent2Slot,
        reagent3Bag, reagent3Slot
    )

    -- La calidad (color del nombre) sale de aquí, igual que en el tooltip del juego;
    -- el enlace de la poción no la trae
    local _, _, _, _, _, _, _, displayQuality = GetAlchemyResultingItemInfo(
        solventBag, solventSlot,
        reagent1Bag, reagent1Slot,
        reagent2Bag, reagent2Slot,
        reagent3Bag, reagent3Slot
    )

    if prospectiveResult == PROSPECTIVE_ALCHEMY_RESULT_UNCRAFTABLE then
        return nil, AFP.COMBINATION_STATUS.INVALID
    end

    -- Solo se guardan las conocidas: el nombre y el icono de la poción son siempre correctos
    if prospectiveResult ~= PROSPECTIVE_ALCHEMY_RESULT_KNOWN then
        return nil, AFP.COMBINATION_STATUS.UNKNOWN
    end

    local reagents = {
        GetItemLink(reagent1Bag, reagent1Slot, LINK_STYLE_DEFAULT),
        GetItemLink(reagent2Bag, reagent2Slot, LINK_STYLE_DEFAULT),
    }
    if reagent3Bag and reagent3Slot then
        reagents[#reagents + 1] = GetItemLink(reagent3Bag, reagent3Slot, LINK_STYLE_DEFAULT)
    end

    local combination = {
        solvent = GetItemLink(solventBag, solventSlot, LINK_STYLE_DEFAULT),
        reagents = reagents,
        potion = potionLink,
        quality = displayQuality,
    }

    return combination, AFP.COMBINATION_STATUS.READY
end

--- Posición de la combinación en la lista guardada, o nil si no es favorita
local function FindFavoriteIndex(key)
    for index, favorite in ipairs(AFP.sv.favorites) do
        if AFP.GetFavoriteKey(favorite) == key then
            return index
        end
    end
end

function AFP.IsFavorite(combination)
    return FindFavoriteIndex(AFP.GetFavoriteKey(combination)) ~= nil
end

function AFP.AddFavorite(combination)
    if AFP.IsFavorite(combination) then
        return
    end

    AFP.sv.favorites[#AFP.sv.favorites + 1] = {
        solvent = combination.solvent,
        reagents = combination.reagents,
        potion = combination.potion,
        quality = combination.quality,
    }
end

function AFP.RemoveFavorite(combination)
    local index = FindFavoriteIndex(AFP.GetFavoriteKey(combination))
    if index then
        table.remove(AFP.sv.favorites, index)
    end
end

--- Nombre del objeto con el formato del juego
local function GetItemLinkDisplayName(itemLink)
    return zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemLinkName(itemLink))
end

local function CreateIngredientRow(itemLink)
    return {
        name = GetItemLinkDisplayName(itemLink),
        icon = GetItemLinkIcon(itemLink),
    }
end

--- Devuelve las filas que muestra la pestaña de favoritas, en el orden en que se guardaron
function AFP.GetFavoriteRows()
    local rows = {}

    for _, favorite in ipairs(AFP.sv.favorites) do
        local ingredients = { CreateIngredientRow(favorite.solvent) }
        for _, reagentLink in ipairs(favorite.reagents) do
            ingredients[#ingredients + 1] = CreateIngredientRow(reagentLink)
        end

        rows[#rows + 1] = {
            name = GetItemLinkDisplayName(favorite.potion),
            icon = GetItemLinkIcon(favorite.potion),
            displayQuality = favorite.quality or GetItemLinkDisplayQuality(favorite.potion),
            ingredients = ingredients,
            favorite = favorite,
        }
    end

    return rows
end
