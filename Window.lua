-- Ventana de consulta con las pociones favoritas (comando /afp).
-- Se registra como escena del juego: muestra el cursor, se cierra con ESC,
-- con el botón X y sola cuando el personaje se mueve.
local AFP = AlchemyFavoritePotions

local WINDOW_WIDTH = 640
local WINDOW_HEIGHT = 420
-- Parte de la pantalla que la ventana puede ocupar como máximo (pantallas pequeñas)
local MAX_SCREEN_RATIO = 0.9
local TITLE_TOP_OFFSET = 16
-- Margen lateral del título para que no se superponga con el botón de cerrar
local TITLE_SIDE_MARGIN = 48
-- Tipo de dato de la lista de la ventana (es una lista propia, no comparte pool con la de la mesa)
local ROW_DATA_TYPE = 1
local LIST_TOP_OFFSET = 56
local LIST_SIDE_MARGIN = 20
local LIST_BOTTOM_MARGIN = 20

local list
local emptyLabel

--- Ajusta tamaño y posición: siempre se abre centrada y cabe en la pantalla
local function ResetWindowLayout(window)
    local width = zo_min(WINDOW_WIDTH, GuiRoot:GetWidth() * MAX_SCREEN_RATIO)
    local height = zo_min(WINDOW_HEIGHT, GuiRoot:GetHeight() * MAX_SCREEN_RATIO)
    window:SetDimensions(width, height)

    -- Al arrastrar la ventana el juego cambia su ancla, hay que limpiarla antes
    window:ClearAnchors()
    window:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
end

--- Texto de la opción: el del propio juego, así sale en el idioma del cliente
local function GetLinkInChatText()
    if SI_ITEM_ACTION_LINK_TO_CHAT then
        return GetString(SI_ITEM_ACTION_LINK_TO_CHAT)
    end
    return AFP.L("LINK_IN_CHAT")
end

--- Mensaje del chat: nombre de la poción y reactivos, sin el disolvente.
-- Ejemplo: "Sorbo de aguante: Aguileña, Cardo bendito"
-- En rowData.ingredients el primero es el disolvente y el resto los reactivos.
local function BuildShareText(rowData)
    local reagentNames = {}
    for index = 2, #rowData.ingredients do
        reagentNames[#reagentNames + 1] = rowData.ingredients[index].name
    end

    return string.format("%s: %s", rowData.name, table.concat(reagentNames, ", "))
end

--- Menú de una fila de la ventana, con una sola opción: dejar la receta escrita en el chat
local function ShowRowMenu(rowControl)
    local rowData = rowControl.favoriteData

    ClearMenu()
    AddMenuItem(GetLinkInChatText(), function()
        -- Solo deja el texto escrito: el jugador elige el canal y pulsa Enter
        CHAT_SYSTEM:StartTextEntry(BuildShareText(rowData))
    end)
    ShowMenu(rowControl)
end

--- Los dos botones del ratón abren el mismo menú
local function OnRowMouseUp(rowControl, button)
    if button == MOUSE_BUTTON_INDEX_LEFT or button == MOUSE_BUTTON_INDEX_RIGHT then
        ShowRowMenu(rowControl)
    end
end

--- Dibuja una fila con el mismo aspecto que en la pestaña de la mesa
local function SetupRow(rowControl, data)
    -- Al hacer clic, las filas de la ventana no hacen lo mismo que las de la mesa
    rowControl.mouseUpHandler = OnRowMouseUp
    AFP.SetupFavoriteRow(rowControl, data)
end

--- Rellena la lista con las favoritas, en el orden elegido en la pestaña de la mesa
local function RefreshList()
    ZO_ScrollList_Clear(list)

    local data = ZO_ScrollList_GetDataList(list)
    -- Es una ventana de consulta: no importa si se puede preparar o no
    local SKIP_PROBLEMS = true
    for _, favorite in ipairs(AFP.GetFavoriteRows(SKIP_PROBLEMS)) do
        data[#data + 1] = ZO_ScrollList_CreateDataEntry(ROW_DATA_TYPE, favorite)
    end

    ZO_ScrollList_Commit(list)
    emptyLabel:SetHidden(#data > 0)
end

--- Crea la ventana y la registra como escena
function AFP.InitWindow()
    -- La Dev y la estable usan nombres distintos para no chocar si se cargan a la vez
    local baseName = AFP.isDev and AFP.devName or AFP.name
    AFP.sceneName = baseName

    local window = WINDOW_MANAGER:CreateTopLevelWindow(baseName .. "Window")
    window:SetMouseEnabled(true)
    window:SetMovable(true)
    -- La posición no se guarda y al reabrir vuelve al centro, así que se puede sacar de la pantalla
    window:SetClampedToScreen(false)
    window:SetHidden(true)
    ResetWindowLayout(window)

    -- Fondo con la plantilla del juego (sobresale 8 px de la ventana)
    WINDOW_MANAGER:CreateControlFromVirtual("$(parent)BG", window, "ZO_DefaultBackdrop")

    local title = WINDOW_MANAGER:CreateControl("$(parent)Title", window, CT_LABEL)
    title:SetFont("ZoFontWinH3")
    title:SetText(AFP.L("WINDOW_TITLE"))
    title:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    title:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    title:SetAnchor(TOPLEFT, window, TOPLEFT, TITLE_SIDE_MARGIN, TITLE_TOP_OFFSET)
    title:SetAnchor(TOPRIGHT, window, TOPRIGHT, -TITLE_SIDE_MARGIN, TITLE_TOP_OFFSET)

    -- Botón de cerrar con la plantilla del juego (ya se ancla arriba a la derecha)
    local closeButton = WINDOW_MANAGER:CreateControlFromVirtual("$(parent)Close", window, "ZO_CloseButton")
    closeButton:SetHandler("OnClicked", function()
        SCENE_MANAGER:ShowBaseScene()
    end)

    list = WINDOW_MANAGER:CreateControlFromVirtual("$(parent)List", window, "ZO_ScrollList")
    list:SetAnchor(TOPLEFT, window, TOPLEFT, LIST_SIDE_MARGIN, LIST_TOP_OFFSET)
    list:SetAnchor(BOTTOMRIGHT, window, BOTTOMRIGHT, -LIST_SIDE_MARGIN, -LIST_BOTTOM_MARGIN)
    ZO_ScrollList_AddDataType(list, ROW_DATA_TYPE, AFP.FAVORITE_ROW_TEMPLATE, AFP.FAVORITE_ROW_HEIGHT,
        SetupRow, nil, nil, AFP.ResetFavoriteRow)

    emptyLabel = WINDOW_MANAGER:CreateControl("$(parent)Empty", window, CT_LABEL)
    emptyLabel:SetFont("ZoFontGame")
    emptyLabel:SetText(AFP.L("NO_FAVORITES"))
    emptyLabel:SetAnchor(CENTER, list, CENTER, 0, 0)
    emptyLabel:SetHidden(true)

    -- El fragmento muestra y oculta la ventana; el grupo activa el cursor y el modo UI
    local fragment = ZO_SimpleSceneFragment:New(window)
    fragment:RegisterCallback("StateChange", function(_, newState)
        if newState == SCENE_FRAGMENT_SHOWING then
            ResetWindowLayout(window)
            RefreshList()
        end
    end)

    local scene = ZO_Scene:New(AFP.sceneName, SCENE_MANAGER)
    scene:AddFragment(fragment)
    scene:AddFragmentGroup(FRAGMENT_GROUP.MOUSE_DRIVEN_UI_WINDOW_NO_KEYBIND_STRIP)

    AFP.window = window
    AFP.scene = scene
end

--- Abre la ventana; si ya está abierta, vuelve a la escena base
function AFP.ToggleWindow()
    SCENE_MANAGER:Toggle(AFP.sceneName)
end
