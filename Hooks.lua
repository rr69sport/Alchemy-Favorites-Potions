-- Ganchos sobre la interfaz de alquimia del teclado (ALCHEMY):
-- pestaña de favoritas y su lista de filas.
local AFP = AlchemyFavoritePotions

-- Descriptor de la pestaña: no coincide con ningún tipo de objeto del juego
local FAVORITES_FILTER = "AlchemyFavoritePotionsFavorites"
-- Tipo de dato de la lista; el juego usa 1 y 2 para solventes y reactivos
local FAVORITE_DATA_TYPE = 100
local FAVORITE_ROW_TEMPLATE = "AlchemyFavoritePotions_Row"
local FAVORITE_ROW_HEIGHT = 108
local DEFAULT_NAME_QUALITY = ITEM_DISPLAY_QUALITY_MAGIC or 2

--- Ruta de una textura del addon.
-- La carpeta cambia según la versión cargada (AlchemyFavoritePotions o AlchemyFavoritePotionsDev).
local function GetTexturePath(fileName)
    local folderName = AFP.isDev and AFP.devName or AFP.name
    return string.format("%s/textures/%s.dds", folderName, fileName)
end

--- Reconstruye las pestañas del juego añadiendo la de favoritas.
-- Es una réplica de ZO_AlchemyInventory:Initialize (alchemy_keyboard.lua). La de favoritas va
-- la primera porque el juego selecciona por defecto la última pestaña, que debe seguir siendo "Todo".
local function SetupTabs(inventory)
    local favoritesTab = inventory:CreateNewTabFilterData(
        FAVORITES_FILTER,
        AFP.L("TAB_FAVORITES"),
        GetTexturePath("heart_up"),
        GetTexturePath("heart_down"),
        GetTexturePath("heart_over"),
        GetTexturePath("heart_disabled")
    )
    local reagentsTab = inventory:CreateNewTabFilterData(
        ITEMTYPE_REAGENT,
        GetString(SI_ALCHEMY_REAGENTS_TAB),
        "EsoUI/Art/Crafting/alchemy_tabIcon_reagent_up.dds",
        "EsoUI/Art/Crafting/alchemy_tabIcon_reagent_down.dds",
        "EsoUI/Art/Crafting/alchemy_tabIcon_reagent_over.dds",
        "EsoUI/Art/Crafting/alchemy_tabIcon_reagent_disabled.dds"
    )
    local solventsTab = inventory:CreateNewTabFilterData(
        IsAlchemySolvent,
        GetString(SI_ALCHEMY_SOLVENT_TAB),
        "EsoUI/Art/Crafting/alchemy_tabIcon_solvent_up.dds",
        "EsoUI/Art/Crafting/alchemy_tabIcon_solvent_down.dds",
        "EsoUI/Art/Crafting/alchemy_tabIcon_solvent_over.dds",
        "EsoUI/Art/Crafting/alchemy_tabIcon_solvent_disabled.dds"
    )
    local allTab = inventory:CreateNewTabFilterData(
        nil,
        GetString("SI_ITEMFILTERTYPE", ITEMFILTERTYPE_ALL),
        "EsoUI/Art/Inventory/inventory_tabIcon_all_up.dds",
        "EsoUI/Art/Inventory/inventory_tabIcon_all_down.dds",
        "EsoUI/Art/Inventory/inventory_tabIcon_all_over.dds",
        "EsoUI/Art/Inventory/inventory_tabIcon_all_disabled.dds"
    )

    inventory:SetFilters({ favoritesTab, reagentsTab, solventsTab, allTab })
end

--- Dibuja una fila de favorita con los datos de AFP.GetFavoriteRows()
local function SetupFavoriteRow(rowControl, data)
    rowControl.favoriteData = data

    rowControl.icon:SetTexture(data.icon)
    rowControl.name:SetText(data.name)
    local nameRed, nameGreen, nameBlue = GetInterfaceColor(INTERFACE_COLOR_TYPE_ITEM_QUALITY_COLORS,
        data.displayQuality or DEFAULT_NAME_QUALITY)
    rowControl.name:SetColor(nameRed, nameGreen, nameBlue, 1)

    local textRed, textGreen, textBlue = GetInterfaceColor(INTERFACE_COLOR_TYPE_ITEM_TOOLTIP, ITEM_TOOLTIP_COLOR_ACCENT)
    for index, label in ipairs(rowControl.ingredientLabels) do
        local ingredient = data.ingredients[index]
        if ingredient then
            label:SetHidden(false)
            label:SetText(ingredient.name)
            label:SetColor(textRed, textGreen, textBlue, 1)
            label.icon:SetTexture(ingredient.icon)
        else
            label:SetHidden(true)
        end
    end
end

--- Limpia la fila cuando el juego la devuelve al pool.
--- Al pasar un reset propio, el juego ya no aplica el suyo, así que hay que ocultar la fila aquí
local function ResetFavoriteRow(rowControl)
    rowControl:SetHidden(true)
    rowControl.favoriteData = nil
    rowControl.highlight:SetHidden(true)
end

--- Sustituye Refresh y SortData de la lista solo mientras está activa la pestaña de favoritas
local function InstallListOverrides(inventory)
    local baseRefresh = inventory.Refresh
    inventory.Refresh = function(self, data)
        if self.filterType ~= FAVORITES_FILTER then
            return baseRefresh(self, data)
        end

        for _, favorite in ipairs(AFP.GetFavoriteRows()) do
            data[#data + 1] = ZO_ScrollList_CreateDataEntry(FAVORITE_DATA_TYPE, favorite)
        end

        self:SetNoItemLabelText(AFP.L("NO_FAVORITES"))
        self:SetNoItemLabelHidden(#data > 0)
    end

    -- Las favoritas mantienen el orden en que se guardaron
    local baseSortData = inventory.SortData
    inventory.SortData = function(self)
        if self.filterType ~= FAVORITES_FILTER then
            return baseSortData(self)
        end
    end
end

function AFP.OnFavoriteRowMouseEnter(rowControl)
    rowControl.highlight:SetHidden(false)
end

function AFP.OnFavoriteRowMouseExit(rowControl)
    rowControl.highlight:SetHidden(true)
end

function AFP.OnFavoriteRowMouseUp(rowControl, button, upInside)
    if upInside and button == MOUSE_BUTTON_INDEX_LEFT and rowControl.favoriteData then
        AFP.OnFavoriteSelected(rowControl.favoriteData)
    end
end

--- Instala todos los ganchos. Se llama una sola vez al cargar el addon.
function AFP.InstallHooks()
    if AFP.hooksInstalled then
        return
    end

    local inventory = ALCHEMY and ALCHEMY.inventory
    if not inventory then
        error("ALCHEMY.inventory not found")
    end

    SetupTabs(inventory)
    ZO_ScrollList_AddDataType(inventory.list, FAVORITE_DATA_TYPE, FAVORITE_ROW_TEMPLATE, FAVORITE_ROW_HEIGHT,
        SetupFavoriteRow, nil, nil, ResetFavoriteRow)
    InstallListOverrides(inventory)

    AFP.hooksInstalled = true
end
