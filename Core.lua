-- Motor del addon: carga, SavedVariables y lógica de favoritas.
local AFP = AlchemyFavoritePotions

-- Inventarios donde el juego busca ingredientes para la mesa de alquimia
local INVENTORY_TYPES = { INVENTORY_BACKPACK, INVENTORY_CRAFT_BAG, INVENTORY_BANK }

--- Busca en el inventario el primer objeto con ese itemId.
-- Devuelve bagId y slotIndex, o nil si no se tiene.
local function FindItemInBags(itemId)
    for _, inventoryType in ipairs(INVENTORY_TYPES) do
        for _, bagId in ipairs(PLAYER_INVENTORY.inventories[inventoryType].backingBags) do
            for slotIndex in ZO_IterateBagSlots(bagId) do
                if GetItemId(bagId, slotIndex) == itemId then
                    return bagId, slotIndex
                end
            end
        end
    end
end

local function ShowAlert(text)
    ZO_Alert(UI_ALERT_CATEGORY_ALERT, SOUNDS.NEGATIVE_CLICK, text)
end

--- Coloca en las ranuras los ingredientes de una favorita.
-- Si falta algo no toca las ranuras y avisa de qué falta.
function AFP.ApplyFavorite(favorite)
    if #favorite.reagents > 2 and not ZO_Alchemy_IsThirdAlchemySlotUnlocked() then
        ShowAlert(AFP.L("THIRD_SLOT_LOCKED"))
        return
    end

    local solventBag, solventSlot = FindItemInBags(GetItemLinkItemId(favorite.solvent))
    local reagentSlots = {}
    local missingNames = {}

    if not solventBag then
        missingNames[#missingNames + 1] = zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemLinkName(favorite.solvent))
    end

    for _, reagentLink in ipairs(favorite.reagents) do
        local bagId, slotIndex = FindItemInBags(GetItemLinkItemId(reagentLink))
        if bagId then
            reagentSlots[#reagentSlots + 1] = { bagId = bagId, slotIndex = slotIndex }
        else
            missingNames[#missingNames + 1] = zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemLinkName(reagentLink))
        end
    end

    if #missingNames > 0 then
        ShowAlert(string.format(AFP.L("MISSING_INGREDIENTS"), table.concat(missingNames, ", ")))
        return
    end

    -- Un disolvente de rango alto no se puede usar con poco nivel de alquimia
    local _, _, rankRequirement = GetItemCraftingInfo(solventBag, solventSlot)
    if rankRequirement > GetNonCombatBonus(NON_COMBAT_BONUS_ALCHEMY_LEVEL) then
        ShowAlert(string.format(AFP.L("SOLVENT_RANK_TOO_LOW"),
            zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemLinkName(favorite.solvent))))
        return
    end

    local SUPPRESS_SOUND = true
    ALCHEMY:ClearSelections(SUPPRESS_SOUND)
    ALCHEMY:SetSolventItem(solventBag, solventSlot)
    for reagentIndex, reagentSlot in ipairs(reagentSlots) do
        ALCHEMY:SetReagentItem(reagentIndex, reagentSlot.bagId, reagentSlot.slotIndex)
    end
end

--- Se llama al hacer clic en una fila de favorita
function AFP.OnFavoriteSelected(rowData)
    AFP.ApplyFavorite(rowData.favorite)
end

--- Muestra los mensajes de la versión Dev cuando el chat ya está listo.
-- Durante EVENT_ADD_ON_LOADED el chat aún no existe, por eso se espera a EVENT_PLAYER_ACTIVATED.
local function PrintDevLoadedMessage(svName)
    local eventName = AFP.name .. "DevLoaded"

    EVENT_MANAGER:RegisterForEvent(eventName, EVENT_PLAYER_ACTIVATED, function()
        EVENT_MANAGER:UnregisterForEvent(eventName, EVENT_PLAYER_ACTIVATED)
        AFP.Print(string.format(AFP.L("LOADED_DEV"), svName))

        if AFP.hooksError then
            AFP.Print(string.format(AFP.L("HOOKS_ERROR"), tostring(AFP.hooksError)))
        end
    end)
end

local function Initialize(isDev)
    AFP.isDev = isDev

    -- Variable guardada distinta para la versión Dev y la estable.
    -- El perfil es el servidor (NA, EU, PTS) para que no se pisen.
    local svName = isDev and AFP.devSvName or AFP.svName
    AFP.sv = ZO_SavedVars:NewAccountWide(svName, AFP.svVersion, nil, AFP.defaults, GetWorldName())

    -- Si el juego cambia algo de su interfaz, falla solo el gancho y no el resto del addon
    local installed, errorMessage = pcall(AFP.InstallHooks)
    if not installed then
        AFP.hooksError = errorMessage
    end

    if isDev then
        PrintDevLoadedMessage(svName)
    end
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= AFP.name and addonName ~= AFP.devName then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(AFP.name, EVENT_ADD_ON_LOADED)
    Initialize(addonName == AFP.devName)
end

EVENT_MANAGER:RegisterForEvent(AFP.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
