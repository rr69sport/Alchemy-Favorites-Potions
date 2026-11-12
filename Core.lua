-- Motor del addon: carga, SavedVariables y (más adelante) lógica de favoritas.
local AFP = AlchemyFavoritePotions

--- Muestra el mensaje de la versión Dev cuando el chat ya está listo.
-- Durante EVENT_ADD_ON_LOADED el chat aún no existe, por eso se espera a EVENT_PLAYER_ACTIVATED.
local function PrintDevLoadedMessage(svName)
    local eventName = AFP.name .. "DevLoaded"

    EVENT_MANAGER:RegisterForEvent(eventName, EVENT_PLAYER_ACTIVATED, function()
        EVENT_MANAGER:UnregisterForEvent(eventName, EVENT_PLAYER_ACTIVATED)
        AFP.Print(string.format(AFP.L("LOADED_DEV"), svName))
    end)
end

local function Initialize(isDev)
    AFP.isDev = isDev

    -- Variable guardada distinta para la versión Dev y la estable.
    -- El perfil es el servidor (NA, EU, PTS) para que no se pisen.
    local svName = isDev and AFP.devSvName or AFP.svName
    AFP.sv = ZO_SavedVars:NewAccountWide(svName, AFP.svVersion, nil, AFP.defaults, GetWorldName())

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
