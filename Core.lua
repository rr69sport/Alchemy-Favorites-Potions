-- Motor del addon: carga, SavedVariables y lógica de favoritas.
local AFP = AlchemyFavoritePotions

-- Iconos de prueba (paso 2); las filas reales usarán los iconos de los objetos
local TEST_POTION_ICON = "EsoUI/Art/Crafting/alchemy_emptySlot_solvent.dds"
local TEST_SOLVENT_ICON = "EsoUI/Art/Crafting/alchemy_emptySlot_solvent.dds"
local TEST_REAGENT_ICON = "EsoUI/Art/Crafting/alchemy_emptySlot_reagent.dds"

local function CreateTestIngredient(nameKey, icon)
    return { name = AFP.L(nameKey), icon = icon }
end

--- Devuelve las filas que muestra la pestaña de favoritas.
-- PASO 2: datos de prueba. Más adelante se construirán desde AFP.sv.favorites.
function AFP.GetFavoriteRows()
    return {
        {
            name = string.format(AFP.L("TEST_POTION"), 1),
            icon = TEST_POTION_ICON,
            ingredients = {
                CreateTestIngredient("TEST_SOLVENT", TEST_SOLVENT_ICON),
                CreateTestIngredient("TEST_REAGENT", TEST_REAGENT_ICON),
                CreateTestIngredient("TEST_REAGENT", TEST_REAGENT_ICON),
            },
        },
        {
            name = string.format(AFP.L("TEST_POTION"), 2),
            icon = TEST_POTION_ICON,
            ingredients = {
                CreateTestIngredient("TEST_SOLVENT", TEST_SOLVENT_ICON),
                CreateTestIngredient("TEST_REAGENT", TEST_REAGENT_ICON),
                CreateTestIngredient("TEST_REAGENT", TEST_REAGENT_ICON),
                CreateTestIngredient("TEST_REAGENT", TEST_REAGENT_ICON),
            },
        },
        {
            name = AFP.L("TEST_LONG_POTION"),
            icon = TEST_POTION_ICON,
            ingredients = {
                CreateTestIngredient("TEST_LONG_INGREDIENT", TEST_SOLVENT_ICON),
                CreateTestIngredient("TEST_LONG_INGREDIENT", TEST_REAGENT_ICON),
                CreateTestIngredient("TEST_LONG_INGREDIENT", TEST_REAGENT_ICON),
                CreateTestIngredient("TEST_LONG_INGREDIENT", TEST_REAGENT_ICON),
            },
        },
    }
end

--- Se llama al hacer clic en una fila de favorita.
-- PASO 2: solo confirma el clic en la versión Dev. Más adelante coloca los ingredientes.
function AFP.OnFavoriteSelected(favoriteData)
    if AFP.isDev then
        AFP.Print(string.format(AFP.L("ROW_CLICKED_DEV"), favoriteData.name))
    end
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
