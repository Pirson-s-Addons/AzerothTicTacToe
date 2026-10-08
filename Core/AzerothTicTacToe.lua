local ADDON_NAME, ns = ...
local L = ns.L -- Locales/<idioma>.lua
local ATT = CreateFrame("Frame")
_G["AzerothTicTacToe"] = ATT

-----------------------------------------
-- VARIABLES
-----------------------------------------
-- Aliases para funciones globales de WoW/Lua
local abs, cos, sin, atan2 = math.abs, math.cos, math.sin, math.atan2
local date = date
local CreateFrame, UIParent = CreateFrame, UIParent
local Minimap, GameTooltip = Minimap, GameTooltip
local UnitName = UnitName
local PlaySound = PlaySound
local InitiateTrade = InitiateTrade
local C_ChatInfo = C_ChatInfo
local ipairs, pairs, tonumber, tostring, table = ipairs, pairs, tonumber, tostring, table

-- SoundKitIDs (API mainline: PlaySound solo acepta IDs numéricos)
local SND_CLICK, SND_OPEN, SND_WAIT = 850, 851, 875
local SND_WIN, SND_LOSE, SND_DRAW, SND_HOVER = 1451, 5274, 896, 856

local MINIMAP_RADIUS = 80

local TEX_HORDE = "Interface\\Icons\\INV_BannerPVP_01"
local TEX_ALLIANCE = "Interface\\Icons\\INV_BannerPVP_02"

-- Versión del protocolo de mensajes. La 1.00 (sin número) colocaba fichas
-- sin moverlas: no puede jugar contra esta.
local PROTOCOL = "2"

-- 3 en raya clásico: 3 fichas por jugador. Primero se colocan; con las 3 en el
-- tablero, cada turno se mueve una a una casilla libre contigua por una línea
-- (fila, columna o diagonal). No hay empate: solo tablas si las piden los dos.
local PIECES = 3
local ADJACENT = {
    [1] = { [2] = true, [4] = true, [5] = true },
    [2] = { [1] = true, [3] = true, [5] = true },
    [3] = { [2] = true, [5] = true, [6] = true },
    [4] = { [1] = true, [5] = true, [7] = true },
    [5] = { [1] = true, [2] = true, [3] = true, [4] = true, [6] = true, [7] = true, [8] = true, [9] = true },
    [6] = { [3] = true, [5] = true, [9] = true },
    [7] = { [4] = true, [5] = true, [8] = true },
    [8] = { [5] = true, [7] = true, [9] = true },
    [9] = { [5] = true, [6] = true, [8] = true },
}

-- Si al rival le toca y no mueve en este tiempo (se ha desconectado o se ha
-- ido), la partida caduca: nadie gana ni pierde. L["RULES"] dice "5 minutos".
local TURN_TIMEOUT = 300

-- Ajustes del panel de opciones (UI/Options.lua), en ATT_Data.settings
local DEFAULTS = { minimap = true, sound = true, challenges = true, scale = 1 }
ns.DEFAULTS = DEFAULTS

ATT.prefix = "AZTICTACTOE"
ATT.gameActive = false
ATT.opponent = nil
ATT.betAmount = 0
ATT.isMyTurn = false
ATT.isHost = false
ATT.board = { "", "", "", "", "", "", "", "", "" }
ATT.pendingInvite = nil
ATT.pendingStart = nil -- he aceptado un reto y espero el START del anfitrión
ATT.selected = nil     -- ficha elegida para mover
ATT.paidSent = {}      -- [rival] = importe del aviso de pago que espera su respuesta
ATT.paidRequest = nil  -- aviso de pago del rival que espera la mía
ATT.cells = {}

-- Variables persistentes: se inicializan en PLAYER_LOGIN. Aquí todavía no
-- existen; el cliente carga las SavedVariables después de ejecutar este archivo.

local function GetMyName()
    return (UnitName("player")) -- Solo el nombre, sin el reino
end

-- El sender de CHAT_MSG_ADDON llega como "Nombre-Reino". Ambiguate quita el
-- reino solo si es el mío: un rival de otro reino conserva "Nombre-Reino",
-- que es lo que hace falta para susurrarle.
local function ShortName(name)
    return name and Ambiguate(name, "none")
end

-- Lo que escribe el jugador ("pepe") no tiene por qué coincidir en mayúsculas
local function SameName(a, b)
    return a ~= nil and b ~= nil and a:lower() == b:lower()
end

-- Los comandos van en el idioma del cliente ("/ttt aceptar"); el inglés vale siempre
local function IsCommand(cmd, localized, english)
    return cmd == localized:lower() or cmd == english
end

local function Command(...)
    return "/ttt " .. table.concat({ ... }, " ")
end

-- Las apuestas y las deudas van en cobre, la unidad del juego: 1 oro = 100
-- plata = 10000 cobre. Se muestran con los iconos de moneda del propio juego.
local COIN = "|TInterface\\MoneyFrame\\UI-%sIcon:12:12:2:0|t"
local function Money(copper)
    local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    local parts = {}
    if g > 0 then parts[#parts + 1] = g .. COIN:format("Gold") end
    if s > 0 then parts[#parts + 1] = s .. COIN:format("Silver") end
    if c > 0 or #parts == 0 then parts[#parts + 1] = c .. COIN:format("Copper") end
    return table.concat(parts, " ")
end
ATT.Money = Money

-----------------------------------------
-- REGLAS
-----------------------------------------
local function CountPieces(board, faction)
    local n = 0
    for i = 1, 9 do if board[i] == faction then n = n + 1 end end
    return n
end

-- from == nil: colocar una ficha nueva. Solo mientras no estén las 3 puestas.
local function IsLegalMove(board, faction, from, to)
    if not to or to < 1 or to > 9 or board[to] ~= "" then return false end
    if CountPieces(board, faction) < PIECES then return from == nil end
    return from ~= nil and board[from] == faction and ADJACENT[from][to] == true
end

function ATT:MyFaction()
    return self.isHost and "Horde" or "Alliance"
end

function ATT:OpponentFaction()
    return self.isHost and "Alliance" or "Horde"
end

-----------------------------------------
-- RESET TABLERO
-----------------------------------------
function ATT:ResetBoard()
    self.board = { "", "", "", "", "", "", "", "", "" }
    for i, cell in ipairs(self.cells) do
        cell.icon:SetTexture(nil)
        -- No ocultamos el border porque es el fondo industrial de la casilla
    end
    self:Select(nil)
    if self.TurnText then self.TurnText:SetText(L["WAITING_TURN"]) end
end

-- Ficha elegida para mover: su casilla se tiñe de oro
function ATT:Select(index)
    self.selected = index
    for i, cell in ipairs(self.cells) do
        if i == index then
            cell.border:SetVertexColor(1, 0.82, 0, 1)
        else
            cell.border:SetVertexColor(0.5, 0.5, 0.5, 0.8)
        end
    end
end

-- Cambia el turno. Cuando pasa al rival empieza a correr su tiempo.
function ATT:SetTurn(mine)
    self.isMyTurn = mine
    if not mine then self.waitingSince = GetTime() end
    self:UpdateTurnText()
end

function ATT:UpdateTurnText(secondsLeft)
    if not self.isMyTurn then
        local text = L["TURN_OF"]:format(self.opponent)
        if secondsLeft then
            text = text .. (" (%d:%02d)"):format(math.floor(secondsLeft / 60), secondsLeft % 60)
        end
        self.TurnText:SetText("|cffff0000" .. text .. "|r")
        return
    end
    local placed = CountPieces(self.board, self:MyFaction())
    if placed < PIECES then
        self.TurnText:SetText("|cff00ff00" .. L["PLACE_PIECE"]:format(PIECES - placed) .. "|r")
    else
        self.TurnText:SetText("|cff00ff00" .. L["MOVE_PIECE"] .. "|r")
    end
end

-----------------------------------------
-- HELPER MENSAJES Y SONIDOS
-----------------------------------------
function ATT:PlaySound(soundID)
    if ATT_Data.settings.sound then PlaySound(soundID, "Master") end
end

function ATT:ApplySettings()
    local db = ATT_Data.settings
    if self.MinimapIcon then self.MinimapIcon:SetShown(db.minimap) end
    if self.MainFrame then self.MainFrame:SetScale(db.scale) end
end

function ATT:SendMessage(message, target)
    C_ChatInfo.SendAddonMessage(self.prefix, message, "WHISPER", target)
end

-----------------------------------------
-- EVENTOS
-----------------------------------------
ATT:RegisterEvent("PLAYER_LOGIN")
ATT:RegisterEvent("CHAT_MSG_ADDON")

ATT:SetScript("OnEvent", function(self, event, ...)
    if self[event] then
        self[event](self, ...)
    end
end)

-----------------------------------------
-- PLAYER LOGIN
-----------------------------------------
function ATT:PLAYER_LOGIN()
    -- Campo a campo: un ATT_Data de una versión anterior puede no traerlos todos
    ATT_Data = ATT_Data or {}
    ATT_Data.rankings = ATT_Data.rankings or {} -- { ["Player"] = wins }
    ATT_Data.losses = ATT_Data.losses or {}     -- { ["Player"] = derrotas }, desde la 1.02
    ATT_Data.debts = ATT_Data.debts or {}       -- { ["Player"] = amount } (positivo me deben, negativo debo)
    ATT_Data.history = ATT_Data.history or {}   -- { { date=T, rival=R, result=W/L/D, gold=cobre } }
    ATT_Data.settings = ATT_Data.settings or {}
    for key, value in pairs(DEFAULTS) do
        if ATT_Data.settings[key] == nil then ATT_Data.settings[key] = value end
    end
    -- La 1.00 guardaba oro entero; desde la 1.01 todo va en cobre
    if not ATT_Data.copper then
        for name, amount in pairs(ATT_Data.debts) do ATT_Data.debts[name] = amount * 10000 end
        for _, entry in ipairs(ATT_Data.history) do entry.gold = (entry.gold or 0) * 10000 end
        ATT_Data.copper = true
    end

    -- Devuelve un enum (0 = Success), no un booleano
    if C_ChatInfo.RegisterAddonMessagePrefix(self.prefix) ~= Enum.RegisterAddonMessagePrefixResult.Success then
        print("|cffff0000[ATT Error]: " .. L["PREFIX_FAILED"] .. "|r")
    end

    SLASH_TTT1 = "/ttt"
    SlashCmdList["TTT"] = function(msg)
        ATT:HandleSlashCommand(msg)
    end

    self:CreateMainFrame()
    self:CreateBoard()
    self:CreateMinimapIcon()
    self.optionsID = ns.CreateOptions(self, {
        { "/ttt", L["CMD_DESC_OPEN"] },
        { L["USAGE_INVITE"], L["CMD_DESC_CHALLENGE"] },
        { Command(L["CMD_ACCEPT"]), L["CMD_DESC_ACCEPT"] },
        { Command(L["CMD_CANCEL"]), L["CMD_DESC_CANCEL"] },
        { Command(L["CMD_ACCEPT"], L["CMD_PAID"]), L["CMD_DESC_ACCEPT_PAID"] },
        { Command(L["CMD_CANCEL"], L["CMD_PAID"]), L["CMD_DESC_CANCEL_PAID"] },
    })
    self:ApplySettings()
    C_Timer.NewTicker(1, function() ATT:CheckTimeout(GetTime()) end)

    print("|cff00ff00[ATT]: " .. L["LOADED"] .. "|r")
end

-----------------------------------------
-- MINIMAPA (ICONO GOBLIN)
-----------------------------------------
function ATT:CreateMinimapIcon()
    local icon = CreateFrame("Button", "ATT_MinimapIcon", Minimap)
    icon:SetSize(32, 32)
    icon:SetFrameStrata("MEDIUM")
    icon:SetFrameLevel(8)
    icon:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    icon.bg = icon:CreateTexture(nil, "BACKGROUND")
    icon.bg:SetSize(21, 21)
    icon.bg:SetTexture(TEX_HORDE) -- Icono Horda/Goblin
    icon.bg:SetPoint("CENTER", 0, 0)

    icon.border = icon:CreateTexture(nil, "OVERLAY")
    icon.border:SetSize(54, 54)
    icon.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    icon.border:SetPoint("TOPLEFT", 0, 0)

    icon:SetMovable(true)
    icon:EnableMouse(true)
    icon:RegisterForDrag("LeftButton")
    icon:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    -- El ángulo se guarda en radianes, que es lo que comen cos/sin
    local function PlaceAt(angle)
        icon:ClearAllPoints()
        icon:SetPoint("CENTER", Minimap, "CENTER", cos(angle) * MINIMAP_RADIUS, sin(angle) * MINIMAP_RADIUS)
    end

    PlaceAt(ATT_Data.minimapAngle or 4) -- ~4 rad: cerca de las 4 en el reloj

    icon:SetScript("OnDragStart", function(self) self:StartMoving() end)
    icon:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- Calcular ángulo relativo al centro del minimapa y volver a pegarlo al borde
        local mx, my = Minimap:GetCenter()
        local cx, cy = self:GetCenter()
        local angle = atan2(cy - my, cx - mx)
        ATT_Data.minimapAngle = angle
        PlaceAt(angle)
    end)

    icon:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            if ATT.RankingFrame and ATT.RankingFrame:IsShown() then
                ATT.RankingFrame:Hide()
            else
                ATT:CreateRankingFrame() -- Lo creamos o mostramos
            end
        else
            -- Botón derecho: Toggle tablero rápido
            if ATT.MainFrame:IsShown() then
                ATT.MainFrame:Hide()
            else
                ATT.MainFrame:Show()
            end
        end
    end)

    icon:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("|cffffd700Azeroth Tic-Tac-Toe|r")
        GameTooltip:AddLine("|cffffffff" .. L["LEFT_CLICK"] .. "|r " .. L["OPEN_LEDGER"])
        GameTooltip:AddLine("|cffffffff" .. L["RIGHT_CLICK"] .. "|r " .. L["TOGGLE_BOARD"])
        GameTooltip:Show()
    end)
    icon:SetScript("OnLeave", function() GameTooltip:Hide() end)

    self.MinimapIcon = icon
end

-----------------------------------------
-- COBRO (COMERCIO)
-----------------------------------------
-- InitiateTrade está protegida y quiere un unit token, no un nombre: solo
-- funciona con el rival seleccionado y desde un click del jugador.
function ATT:TradeWith(name)
    if SameName(GetUnitName("target", true), name) then
        InitiateTrade("target")
    else
        print("|cffff0000[ATT]: " .. L["TARGET_TO_TRADE"]:format(name) .. "|r")
    end
end

-----------------------------------------
-- LIBRO DE CUENTAS (PESTAÑAS)
-----------------------------------------
local ICON_WIN = "Interface\\RaidFrame\\ReadyCheck-Ready"
local ICON_LOSS = "Interface\\RaidFrame\\ReadyCheck-NotReady"
local ICON_DRAW = "Interface\\RaidFrame\\ReadyCheck-Waiting"
local RESULT_ICON = { W = ICON_WIN, L = ICON_LOSS, D = ICON_DRAW }
local MEDALS = { "Interface\\MoneyFrame\\UI-GoldIcon", "Interface\\MoneyFrame\\UI-SilverIcon",
    "Interface\\MoneyFrame\\UI-CopperIcon" }
local ROW_H, LIST_W = 24, 364

-- Balance con signo: verde si gano dinero, rojo si pierdo
local function SignedMoney(copper)
    if copper > 0 then return "|cff00ff00+" .. Money(copper) .. "|r" end
    if copper < 0 then return "|cffff4040-" .. Money(-copper) .. "|r" end
    return "|cff808080" .. Money(0) .. "|r"
end

-- Victorias, derrotas y tablas contra cada rival, sacadas del historial
function ATT:RivalStats()
    local byName, list = {}, {}
    for _, e in ipairs(ATT_Data.history) do
        if e.rival then
            local s = byName[e.rival]
            if not s then
                s = { name = e.rival, W = 0, L = 0, D = 0, net = 0 }
                byName[e.rival] = s
                list[#list + 1] = s
            end
            if s[e.result] then s[e.result] = s[e.result] + 1 end
            if e.result == "W" then s.net = s.net + (e.gold or 0) end
            if e.result == "L" then s.net = s.net - (e.gold or 0) end
        end
    end
    table.sort(list, function(a, b)
        local ga, gb = a.W + a.L + a.D, b.W + b.L + b.D
        if ga ~= gb then return ga > gb end
        return a.W > b.W
    end)
    return list
end

-- Cada pestaña: columnas { x, ancho, alineación }, cabecera (claves de L) y filas
local LEDGER_TABS = {
    {
        label = "TAB_RANKING", icon = "Interface\\Icons\\INV_Misc_Head_Dragon_01",
        hint = "HINT_RANKING", empty = "NO_WINS",
        layout = { { 28, 200, "LEFT" }, { 230, 65, "CENTER" }, { 297, 65, "CENTER" } },
        header = { "COL_CHARACTER", "COL_WINS", "COL_LOSSES" },
        rows = function()
            local byName, list = {}, {}
            local function Get(name)
                if not byName[name] then
                    byName[name] = { name = name, wins = 0, losses = 0 }
                    list[#list + 1] = byName[name]
                end
                return byName[name]
            end
            for name, wins in pairs(ATT_Data.rankings) do Get(name).wins = wins end
            for name, losses in pairs(ATT_Data.losses) do Get(name).losses = losses end
            table.sort(list, function(a, b)
                if a.wins ~= b.wins then return a.wins > b.wins end
                return a.losses < b.losses
            end)
            local me, rows = GetMyName(), {}
            for i, d in ipairs(list) do
                local name = SameName(d.name, me) and ("|cff00ff00" .. d.name .. "|r") or d.name
                rows[i] = { icon = MEDALS[i], values = { i .. ".  " .. name, "|cff00ff00" .. d.wins .. "|r",
                    "|cffff4040" .. d.losses .. "|r" } }
            end
            return rows
        end,
    },
    {
        label = "TAB_RIVALS", icon = "Interface\\Icons\\Ability_Warrior_Challange",
        hint = "HINT_RIVALS", empty = "NO_RIVALS",
        layout = { { 28, 130, "LEFT" }, { 160, 32, "CENTER" }, { 194, 32, "CENTER" }, { 228, 32, "CENTER" },
            { 262, 98, "RIGHT" } },
        header = { "COL_PLAYER", "RESULT_WIN", "RESULT_LOSS", "RESULT_DRAW", "COL_BALANCE" },
        rows = function()
            local rows = {}
            for i, s in ipairs(ATT:RivalStats()) do
                local icon = (s.W > s.L) and ICON_WIN or (s.W < s.L) and ICON_LOSS or ICON_DRAW
                rows[i] = { icon = icon, values = { s.name, "|cff00ff00" .. s.W .. "|r", "|cffff4040" .. s.L .. "|r",
                    "|cffffff00" .. s.D .. "|r", SignedMoney(s.net) } }
            end
            return rows
        end,
    },
    {
        label = "TAB_DEBTS", icon = "Interface\\Icons\\INV_Misc_Coin_01",
        hint = "HINT_DEBTS", empty = "NO_DEBTS",
        layout = { { 28, 105, "LEFT" }, { 135, 105, "LEFT" } },
        header = { "COL_PLAYER", "COL_AMOUNT" },
        rows = function()
            local rows = {}
            for name, amount in pairs(ATT_Data.debts) do
                if amount ~= 0 then
                    local text = (amount > 0) and ("|cff00ff00" .. L["OWES_YOU"]) or ("|cffff4040" .. L["YOU_OWE"])
                    rows[#rows + 1] = { icon = "Interface\\Icons\\INV_Misc_Coin_0" .. (amount > 0 and 1 or 5),
                        values = { name, text .. " " .. Money(abs(amount)) .. "|r" }, debt = name, amount = amount }
                end
            end
            table.sort(rows, function(a, b) return a.amount > b.amount end)
            return rows
        end,
    },
    {
        label = "TAB_HISTORY", icon = "Interface\\Icons\\INV_Scroll_03",
        hint = "HINT_HISTORY", empty = "NO_HISTORY",
        layout = { { 28, 100, "LEFT" }, { 130, 150, "LEFT" }, { 282, 78, "RIGHT" } },
        header = { "COL_DATE", "COL_PLAYER", "COL_BET" },
        rows = function()
            local rows = {}
            for i = #ATT_Data.history, math.max(1, #ATT_Data.history - 49), -1 do -- las últimas 50
                local e = ATT_Data.history[i]
                rows[#rows + 1] = { icon = RESULT_ICON[e.result], values = { "|cffaaaaaa" .. (e.date or ""):sub(6) .. "|r",
                    e.rival or "?", Money(e.gold or 0) } }
            end
            return rows
        end,
    },
}

-- Fila de la lista: franja, icono y hasta 5 columnas. Los botones solo los usa Deudas.
local function CreateRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(LIST_W, ROW_H)
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(1, 0.82, 0.4, 0.07)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(18, 18)
    row.icon:SetPoint("LEFT", 4, 0)
    row.cols = {}
    for c = 1, 5 do
        local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetWordWrap(false)
        row.cols[c] = fs
    end
    return row
end

local function SetColumns(row, layout, values)
    for c, fs in ipairs(row.cols) do
        local col = layout[c]
        if col and values[c] then
            fs:ClearAllPoints()
            fs:SetPoint("LEFT", col[1], 0)
            fs:SetWidth(col[2])
            fs:SetJustifyH(col[3])
            fs:SetText(values[c])
            fs:Show()
        else
            fs:Hide()
        end
    end
end

local function AddTip(widget, text)
    widget:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(type(text) == "function" and text(self) or text, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Caja oscura con borde dorado: separa cada zona del pergamino
local function Inset(parent)
    local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    box:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    box:SetBackdropColor(0.08, 0.05, 0.02, 0.8)
    box:SetBackdropBorderColor(0.85, 0.65, 0.3, 1)
    return box
end

function ATT:CreateRankingFrame()
    if self.RankingFrame then
        self.RankingFrame:Show()
        self:UpdateRankingData()
        return
    end

    local frame = CreateFrame("Frame", "ATT_RankingFrame", UIParent, "BackdropTemplate")
    frame:SetSize(440, 520)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("DIALOG")
    if UISpecialFrames then table.insert(UISpecialFrames, "ATT_RankingFrame") end -- Escape lo cierra

    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    frame.bg:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal")
    frame:SetBackdrop({
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
        edgeSize = 24,
        insets = { left = 5, right = 5, top = 5, bottom = 5 }
    })

    -- Título con el logo
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("TOP", 14, -20)
    frame.title:SetText("|cffffd700" .. L["LEDGER_TITLE"] .. "|r")
    frame.title:SetShadowOffset(1, -1)
    local logo = frame:CreateTexture(nil, "ARTWORK")
    logo:SetSize(30, 30)
    logo:SetPoint("RIGHT", frame.title, "LEFT", -6, 0)
    logo:SetTexture("Interface\\AddOns\\AzerothTicTacToe\\img\\logo_attt")

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -5, -5)
    close:SetScript("OnClick", function() frame:Hide() end)

    ---------------------------
    -- NUEVA PARTIDA
    ---------------------------
    local deal = Inset(frame)
    deal:SetPoint("TOPLEFT", 20, -52)
    deal:SetPoint("TOPRIGHT", -20, -52)
    deal:SetHeight(60)

    local dealIcon = deal:CreateTexture(nil, "ARTWORK")
    dealIcon:SetSize(16, 16)
    dealIcon:SetPoint("TOPLEFT", 10, -8)
    dealIcon:SetTexture("Interface\\Icons\\Ability_Warrior_Challange")
    local dealHeader = deal:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dealHeader:SetPoint("LEFT", dealIcon, "RIGHT", 5, 0)
    dealHeader:SetText(L["NEW_GAME"])

    -- Nombre: texto de ejemplo gris que se borra al escribir
    local nameBox = CreateFrame("EditBox", "ATT_NameInput", deal, "InputBoxTemplate")
    nameBox:SetSize(110, 20)
    nameBox:SetPoint("BOTTOMLEFT", 16, 9)
    nameBox:SetAutoFocus(false)
    local function ShowPlaceholder()
        if nameBox:GetText() == "" then
            nameBox:SetText(L["NAME"])
            nameBox:SetTextColor(0.5, 0.5, 0.5)
        end
    end
    nameBox:SetScript("OnEditFocusGained", function(self)
        if self:GetText() == L["NAME"] then self:SetText("") end
        self:SetTextColor(1, 1, 1)
    end)
    nameBox:SetScript("OnEditFocusLost", ShowPlaceholder)
    nameBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    ShowPlaceholder()

    -- Apuesta: oro, plata y cobre, cada uno con su icono
    local function CoinBox(name, anchor, width, maxLetters, coin)
        local box = CreateFrame("EditBox", name, deal, "InputBoxTemplate")
        box:SetSize(width, 20)
        box:SetPoint("LEFT", anchor, "RIGHT", 10, 0)
        box:SetAutoFocus(false)
        box:SetNumeric(true)
        box:SetMaxLetters(maxLetters)
        box:SetText("0")
        box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        box.icon = deal:CreateTexture(nil, "OVERLAY")
        box.icon:SetSize(13, 13)
        box.icon:SetPoint("LEFT", box, "RIGHT", 1, 0)
        box.icon:SetTexture("Interface\\MoneyFrame\\UI-" .. coin .. "Icon")
        return box
    end
    local goldBox = CoinBox("ATT_GoldInput", nameBox, 42, 6, "Gold")
    local silverBox = CoinBox("ATT_SilverInput", goldBox.icon, 24, 2, "Silver")
    local copperBox = CoinBox("ATT_CopperInput", silverBox.icon, 24, 2, "Copper")

    local challengeBtn = CreateFrame("Button", nil, deal, "UIPanelButtonTemplate")
    challengeBtn:SetSize(84, 24)
    challengeBtn:SetPoint("BOTTOMRIGHT", -10, 7)
    challengeBtn:SetText(L["CHALLENGE"])
    AddTip(challengeBtn, L["CMD_DESC_CHALLENGE"])
    challengeBtn:SetScript("OnClick", function()
        local name = nameBox:GetText()
        local coins = (tonumber(goldBox:GetText()) or 0) .. " " .. (tonumber(silverBox:GetText()) or 0)
            .. " " .. (tonumber(copperBox:GetText()) or 0)
        if name ~= "" and name ~= L["NAME"] then
            ATT:HandleSlashCommand(name .. " " .. coins)
            ATT:PlaySound(SND_CLICK)
        end
    end)

    -- Al abrirlo con un jugador seleccionado, su nombre ya viene puesto
    frame:SetScript("OnShow", function()
        if UnitIsPlayer("target") and not UnitIsUnit("target", "player") then
            nameBox:SetText(GetUnitName("target", true))
            nameBox:SetTextColor(1, 1, 1)
        end
    end)

    ---------------------------
    -- LISTA (una pestaña cada vez)
    ---------------------------
    frame.hint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.hint:SetPoint("TOPLEFT", deal, "BOTTOMLEFT", 4, -10)
    frame.hint:SetPoint("RIGHT", -24, 0)
    frame.hint:SetJustifyH("LEFT")
    frame.hint:SetTextColor(0.3, 0.18, 0.05)

    local list = Inset(frame)
    list:SetPoint("TOPLEFT", deal, "BOTTOMLEFT", 0, -30)
    list:SetPoint("BOTTOMRIGHT", -20, 20)

    frame.header = CreateRow(list)
    frame.header:SetPoint("TOPLEFT", 8, -6)
    frame.header.bg:SetColorTexture(0, 0, 0, 0)
    for _, fs in ipairs(frame.header.cols) do fs:SetFontObject("GameFontNormalSmall") end
    local line = list:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(0.85, 0.65, 0.3, 0.5)
    line:SetSize(LIST_W, 1)
    line:SetPoint("TOPLEFT", frame.header, "BOTTOMLEFT", 0, -1)

    local scrollFrame = CreateFrame("ScrollFrame", "ATT_RankingScroll", list, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 8, -34)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 8)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(LIST_W, 1)
    scrollFrame:SetScrollChild(content)
    content.rows = {}
    content.empty = content:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    content.empty:SetPoint("TOP", 0, -40)
    content.empty:SetWidth(LIST_W - 20)

    frame.content = content
    frame.scroll = scrollFrame

    ---------------------------
    -- PESTAÑAS (debajo, como en la ficha del personaje)
    ---------------------------
    frame.Tabs = {}
    for i, def in ipairs(LEDGER_TABS) do
        local tab = CreateFrame("Button", "ATT_RankingFrameTab" .. i, frame, "PanelTabButtonTemplate")
        tab:SetID(i)
        tab:SetText("|T" .. def.icon .. ":14:14|t " .. L[def.label])
        if PanelTemplates_TabResize then PanelTemplates_TabResize(tab, 0) end
        if i == 1 then
            tab:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 12, 4)
        else
            tab:SetPoint("TOPLEFT", frame.Tabs[i - 1], "TOPRIGHT", 3, 0)
        end
        tab:SetScript("OnClick", function()
            ATT:SelectLedgerTab(i)
            ATT:PlaySound(SND_HOVER)
        end)
        frame.Tabs[i] = tab
    end
    if PanelTemplates_SetNumTabs then PanelTemplates_SetNumTabs(frame, #LEDGER_TABS) end

    self.RankingFrame = frame
    self:SelectLedgerTab(self.ledgerTab or 1)
end

function ATT:SelectLedgerTab(index)
    self.ledgerTab = index
    local frame = self.RankingFrame
    if not frame then return end
    if PanelTemplates_SetTab then PanelTemplates_SetTab(frame, index) end
    frame.scroll:SetVerticalScroll(0)
    self:UpdateRankingData()
end

-- Crea o recicla la fila N de la lista
local function AcquireRow(content, i)
    local row = content.rows[i]
    if row then
        row:Show()
        return row
    end

    row = CreateRow(content)

    row.clearBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.clearBtn:SetSize(62, 20)
    row.clearBtn:SetPoint("RIGHT", -2, 0)
    row.clearBtn:SetNormalFontObject("GameFontNormalSmall")
    row.clearBtn:SetDisabledFontObject("GameFontDisableSmall")
    AddTip(row.clearBtn, function(self) return L["PAID_TOOLTIP"]:format(self.rival or "?") end)

    row.tradeBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.tradeBtn:SetSize(58, 20)
    row.tradeBtn:SetPoint("RIGHT", row.clearBtn, "LEFT", -4, 0)
    row.tradeBtn:SetText(L["COLLECT"])
    row.tradeBtn:SetNormalFontObject("GameFontNormalSmall")
    AddTip(row.tradeBtn, function(self) return L["TARGET_TO_TRADE"]:format(self.rival or "?") end)

    content.rows[i] = row
    return row
end

function ATT:UpdateRankingData()
    local frame = self.RankingFrame
    if not frame then return end
    local def = LEDGER_TABS[self.ledgerTab or 1]
    local content = frame.content

    frame.hint:SetText(L[def.hint])
    local header = {}
    for c, key in ipairs(def.header) do header[c] = L[key] end
    SetColumns(frame.header, def.layout, header)

    local rows = def.rows()
    for i, data in ipairs(rows) do
        local row = AcquireRow(content, i)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
        row.bg:SetShown(i % 2 == 1)
        row.icon:SetTexture(data.icon)
        SetColumns(row, def.layout, data.values)

        -- "Pagado" no borra nada: avisa al rival, y solo su confirmación salda la deuda
        local name = data.debt
        row.clearBtn:SetShown(name ~= nil)
        row.tradeBtn:Hide()
        if name then
            row.clearBtn.rival, row.tradeBtn.rival = name, name
            local pending = ATT.paidSent[name] ~= nil
            row.clearBtn:SetText(pending and L["PENDING"] or L["PAID"])
            row.clearBtn:SetEnabled(not pending)
            row.clearBtn:SetScript("OnClick", function()
                ATT:RequestPayment(name)
                ATT:PlaySound(SND_HOVER)
            end)
            -- Solo tiene sentido abrir comercio si son ellos los que pagan
            if data.amount > 0 then
                row.tradeBtn:Show()
                row.tradeBtn:SetScript("OnClick", function() ATT:TradeWith(name) end)
            end
        end
    end

    -- Ocultar las filas sobrantes del refresco anterior
    for i = #rows + 1, #content.rows do
        content.rows[i]:Hide()
    end

    content.empty:SetText(L[def.empty])
    content.empty:SetShown(#rows == 0)
    content:SetHeight(math.max(#rows * ROW_H, 1))
end

function ATT:HandleSlashCommand(msg)
    msg = (msg or ""):match("^%s*(.-)%s*$")

    if msg == "" then
        if self.optionsID then Settings.OpenToCategory(self.optionsID) end
        print(L["USAGE"])
        print(L["USAGE_INVITE"])
        print(Command(L["CMD_ACCEPT"]))
        print(Command(L["CMD_CANCEL"]))
        print(Command(L["CMD_ACCEPT"], L["CMD_PAID"]))
        print(Command(L["CMD_CANCEL"], L["CMD_PAID"]))
        return
    end

    local cmd = string.lower(msg)

    if IsCommand(cmd, L["CMD_ACCEPT"], "accept") then
        self:AcceptInvite()
        return
    elseif IsCommand(cmd, L["CMD_CANCEL"], "cancel") then
        self:CancelInvite()
        return
    elseif IsCommand(cmd, L["CMD_ACCEPT"] .. " " .. L["CMD_PAID"], "accept paid") then
        self:AnswerPayment(true)
        return
    elseif IsCommand(cmd, L["CMD_CANCEL"] .. " " .. L["CMD_PAID"], "cancel paid") then
        self:AnswerPayment(false)
        return
    end

    -- En Forever los personajes llevan nombre y apellido ("Caudillo Jr"): todo
    -- es el nombre salvo la apuesta, los números del final: oro, plata y cobre
    -- (opcionales, en ese orden). Los nombres no llevan cifras.
    local playerName, coins = msg, {}
    for _ = 1, 3 do
        local rest, n = playerName:match("^(.-)%s+(%d+)$")
        if not rest then break end
        table.insert(coins, 1, tonumber(n))
        playerName = rest
    end
    local gold = (coins[1] or 0) * 10000 + (coins[2] or 0) * 100 + (coins[3] or 0)

    if SameName(playerName, GetMyName()) then
        print(L["NOT_YOURSELF"])
        return
    end
    if self.gameActive then
        print("|cffff0000[ATT]: " .. L["FINISH_BEFORE_CHALLENGE"] .. "|r")
        return
    end

    print(L["SENDING_INVITE"]:format(playerName, Money(gold)))
    self:SendInvite(playerName, gold)
end

-----------------------------------------
-- INVITACIONES
-----------------------------------------
function ATT:SendInvite(target, gold)
    self:SendMessage("INVITE:" .. GetMyName() .. ":" .. gold .. ":" .. PROTOCOL, target)
    self.opponent = target
    self.betAmount = gold
    self.isHost = true
end

function ATT:AcceptInvite()
    if not self.pendingInvite then
        print("|cffff0000[ATT]: " .. L["NO_INVITE"] .. "|r")
        return
    end
    if self.gameActive then
        print("|cffff0000[ATT]: " .. L["FINISH_BEFORE_ACCEPT"] .. "|r")
        return
    end
    -- La partida empieza cuando el anfitrión echa la moneda (mensaje START)
    self:SendMessage("ACCEPT:" .. GetMyName() .. ":" .. PROTOCOL, self.pendingInvite.host)
    self.pendingStart = self.pendingInvite
    self.pendingInvite = nil
    -- Si los dos pulsaron Revancha a la vez, mi reto queda anulado: empieza el suyo
    self.isHost = false
    self:UpdateRematchButton()
    print("|cffffff00[ATT]: " .. L["WAITING_START"]:format(self.pendingStart.host) .. "|r")
end

function ATT:CancelInvite()
    if not self.pendingInvite then
        print("|cffff0000[ATT]: " .. L["NO_INVITE"] .. "|r")
        return
    end
    self:SendMessage("CANCEL:" .. GetMyName(), self.pendingInvite.host)
    print("|cffff0000[ATT]: " .. L["DECLINED"] .. "|r")
    self.pendingInvite = nil
    self:UpdateRematchButton()
end

-----------------------------------------
-- RENDIRSE Y TABLAS
-----------------------------------------
StaticPopupDialogs["ATT_SURRENDER"] = {
    text = "%s",
    button1 = YES,
    button2 = NO,
    OnAccept = function() ATT:Surrender() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

function ATT:ConfirmSurrender()
    if not self.gameActive then return end
    local text = L["SURRENDER_CONFIRM"]:format(self.opponent)
    if self.betAmount > 0 then
        text = text .. "\n" .. L["POT"] .. " " .. Money(self.betAmount)
    end
    StaticPopup_Show("ATT_SURRENDER", text)
end

-- Rendirse es perder, con apuesta incluida: cerrar la ventana no libra a nadie
function ATT:Surrender()
    if not self.gameActive then return end
    self:SendMessage("FORFEIT:" .. GetMyName(), self.opponent)
    print("|cffff0000[ATT]: " .. L["SURRENDERED"] .. "|r")
    self:EndGame("L")
end

-- Tablas solo si las piden los dos: cada uno pulsa una vez y no se puede retirar
function ATT:OfferDraw()
    if not self.gameActive or self.drawMine then return end
    self.drawMine = true
    self:SendMessage("DRAW:" .. GetMyName(), self.opponent)
    if self.drawTheirs then
        self:EndGame("D")
    else
        print("|cffffff00[ATT]: " .. L["DRAW_YOU_OFFERED"]:format(self.opponent) .. "|r")
        self:UpdateDrawButton()
    end
end

function ATT:UpdateDrawButton()
    local btn = self.DrawButton
    if not btn then return end
    local votes = (self.drawMine and 1 or 0) + (self.drawTheirs and 1 or 0)
    btn:SetText(votes == 0 and L["DRAW_OFFER"] or (L["DRAW_OFFER"] .. " " .. votes .. "/2"))
    btn:SetEnabled(self.gameActive and not self.drawMine)
end

function ATT:ShowGameButtons(shown)
    if self.SurrenderButton then self.SurrenderButton:SetShown(shown) end
    if self.DrawButton then self.DrawButton:SetShown(shown) end
    self:UpdateDrawButton()
    self:UpdateRematchButton()
end

-----------------------------------------
-- REVANCHA
-----------------------------------------
-- Al acabar, el botón reta al mismo rival por la misma apuesta. Si el rival
-- se adelanta, el mismo botón pasa a "Aceptar revancha".
function ATT:UpdateRematchButton()
    local btn = self.RematchButton
    if not btn then return end
    local rival = self.lastRival
    btn:SetShown(not self.gameActive and rival ~= nil)
    if self.gameActive or not rival then return end
    local invite = self.pendingInvite
    if invite and SameName(invite.host, rival) then
        btn:SetText(L["REMATCH_ACCEPT"])
        btn:SetEnabled(true)
        self.TurnText:SetText("|cffffff00" .. L["REMATCH_OFFERED"]:format(rival, Money(invite.gold)) .. "|r")
    elseif self.isHost and SameName(self.opponent, rival) then
        btn:SetText(L["REMATCH_SENT"])
        btn:SetEnabled(false)
    else
        btn:SetText(L["REMATCH"])
        btn:SetEnabled(true)
    end
end

function ATT:Rematch()
    local rival = self.lastRival
    if self.gameActive or not rival then return end
    if self.pendingInvite and SameName(self.pendingInvite.host, rival) then
        self:AcceptInvite()
    else
        print(L["SENDING_INVITE"]:format(rival, Money(self.lastBet)))
        self:SendInvite(rival, self.lastBet)
        self:UpdateRematchButton()
    end
end

-----------------------------------------
-- DEUDAS: AVISO DE PAGO
-----------------------------------------
-- Quien pulsa "Pagado" solo avisa. La deuda sale de los dos libros cuando el
-- otro lo confirma; si lo niega, se queda en los dos. El importe viaja con
-- signo desde el punto de vista del que avisa (+ = el rival me debe).
function ATT:RequestPayment(name)
    local amount = ATT_Data.debts[name] or 0
    if amount == 0 or self.paidSent[name] then return end
    self.paidSent[name] = amount
    self:SendMessage("PAID_REQ:" .. amount, name)
    print("|cffffff00[ATT]: " .. L["PAID_SENT"]:format(name, Money(abs(amount))) .. "|r")
    self:UpdateRankingData()
end

function ATT:AnswerPayment(accepted)
    local req = self.paidRequest
    if not req then
        print("|cffff0000[ATT]: " .. L["NO_PAID_REQUEST"] .. "|r")
        return
    end
    self.paidRequest = nil
    if accepted then
        -- Mi saldo con él es el opuesto al suyo: sumar su importe lo lleva a 0
        ATT_Data.debts[req.from] = (ATT_Data.debts[req.from] or 0) + req.amount
        self:SendMessage("PAID_OK:" .. req.amount, req.from)
        print("|cff00ff00[ATT]: " .. L["PAID_YOU_ACCEPTED"]:format(req.from) .. "|r")
    else
        self:SendMessage("PAID_NO:" .. req.amount, req.from)
        print("|cffff0000[ATT]: " .. L["PAID_YOU_REJECTED"]:format(req.from) .. "|r")
    end
    self:UpdateRankingData()
end

-----------------------------------------
-- MENSAJES ADDON
-----------------------------------------
function ATT:CHAT_MSG_ADDON(prefix, message, channel, sender)
    if prefix ~= self.prefix then return end

    sender = ShortName(sender)
    if not sender then return end

    local parts = {}
    for part in message:gmatch("([^:]+)") do table.insert(parts, part) end
    local msgType = parts[1]
    -- Todo lo de la partida solo vale si viene del rival de la partida en curso
    local fromOpponent = self.gameActive and SameName(sender, self.opponent)

    if msgType == "INVITE" then
        -- El anfitrión es quien envía, no el nombre que viaja en el mensaje
        local host = sender
        local gold = tonumber(parts[3])
        if not gold or gold < 0 then return end
        if parts[4] ~= PROTOCOL then
            print("|cffff0000[ATT]: " .. L["OLD_VERSION"]:format(host) .. "|r")
            self:SendMessage("CANCEL:" .. GetMyName(), host)
            return
        end
        if not ATT_Data.settings.challenges then
            print("|cffff8000[ATT]: " .. L["AUTO_DECLINED"]:format(host) .. "|r")
            self:SendMessage("CANCEL:" .. GetMyName(), host)
            return
        end
        local rematch = SameName(host, self.lastRival)
        print("|cffffff00[ATT]: " .. L[rematch and "REMATCH_OFFERED" or "CHALLENGED"]:format(host, Money(gold)) .. "|r")
        print("|cff888888\"" .. L["TAUNT"] .. "\"|r")
        print(L["TYPE_ACCEPT"]:format("|cff00ff00" .. Command(L["CMD_ACCEPT"]) .. "|r",
            "|cffff0000" .. Command(L["CMD_CANCEL"]) .. "|r"))
        self.pendingInvite = { host = host, gold = gold }
        if rematch and self.MainFrame then self.MainFrame:Show() end
        self:UpdateRematchButton()
    elseif msgType == "ACCEPT" then
        if not self.isHost or self.gameActive or not SameName(sender, self.opponent) then return end
        if parts[3] ~= PROTOCOL then
            -- Un 1.00 ya ha empezado su partida al aceptar: se la cerramos
            print("|cffff0000[ATT]: " .. L["OLD_VERSION"]:format(sender) .. "|r")
            self:SendMessage("CANCEL_GAME:" .. GetMyName(), sender)
            self.opponent, self.isHost = nil, false
            return
        end
        print("|cff00ff00" .. L["ACCEPTED"]:format(sender) .. "|r")
        -- A cara o cruz: empezar colocando da ventaja, así que no siempre al que reta
        local hostStarts = math.random(2) == 1
        self:SendMessage("START:" .. (hostStarts and "host" or "guest"), sender)
        self:StartGame(sender, self.betAmount, true, hostStarts)
    elseif msgType == "START" then
        local pending = self.pendingStart
        if not pending or self.gameActive or not SameName(sender, pending.host) then return end
        self.pendingStart = nil
        self:StartGame(pending.host, pending.gold, false, parts[2] == "guest")
    elseif msgType == "CANCEL" then
        -- Solo el retado al que invité puede rechazarla
        if not self.isHost or self.gameActive or not SameName(sender, self.opponent) then return end
        print("|cffff0000" .. L["REJECTED"]:format(sender) .. "|r")
        self.opponent = nil
        self.isHost = false
        self:UpdateRematchButton()
    elseif msgType == "CANCEL_GAME" then
        -- Solo lo envía la 1.00
        if not fromOpponent then return end
        print("|cffff0000[ATT]: " .. L["OPPONENT_LEFT"]:format(sender) .. "|r")
        self.gameActive = false
        self:ShowGameButtons(false)
        if self.MainFrame then self.MainFrame:Hide() end
    elseif msgType == "EXPIRE" then
        -- El rival dejó de esperar mi jugada: la partida se anula en los dos lados
        if not fromOpponent then return end
        print("|cffff8000[ATT]: " .. L["GAME_EXPIRED_YOU"]:format(sender) .. "|r")
        self:EndGame("X")
    elseif msgType == "FORFEIT" then
        if not fromOpponent then return end
        print("|cff00ff00[ATT]: " .. L["OPPONENT_SURRENDERED"]:format(sender) .. "|r")
        self:EndGame("W")
    elseif msgType == "DRAW" then
        if not fromOpponent or self.drawTheirs then return end
        self.drawTheirs = true
        if self.drawMine then
            self:EndGame("D")
        else
            print("|cffffff00[ATT]: " .. L["DRAW_OFFERED"]:format(sender, L["DRAW_OFFER"]) .. "|r")
            self:UpdateDrawButton()
            self:PlaySound(SND_WAIT)
        end
    elseif msgType == "MOVE" then
        -- Solo el rival mueve, solo en su turno y solo jugadas legales. La
        -- facción es la suya según la partida, no la que diga el mensaje.
        if not fromOpponent or self.isMyTurn then return end

        local to = tonumber(parts[2])
        local from = tonumber(parts[4])
        if from == 0 then from = nil end
        local faction = self:OpponentFaction()
        if not IsLegalMove(self.board, faction, from, to) then return end

        self:ApplyMove(faction, from, to)

        -- El rival acaba de mover: si esto cierra la partida, ha ganado él
        if self:CheckWinner(false) then return end

        self:SetTurn(true)
        self:PlaySound(SND_CLICK)
    elseif msgType == "PAID_REQ" then
        local amount = tonumber(parts[2])
        if not amount or amount == 0 then return end
        self.paidRequest = { from = sender, amount = amount }
        print("|cffffff00[ATT]: " .. L["PAID_REQUEST"]:format(sender, Money(abs(amount))) .. "|r")
        local mine = ATT_Data.debts[sender] or 0
        if mine ~= -amount then
            print("|cffff8000[ATT]: " .. L["PAID_MISMATCH"]:format(Money(abs(mine))) .. "|r")
        end
        print(L["PAID_HOW"]:format("|cff00ff00" .. Command(L["CMD_ACCEPT"], L["CMD_PAID"]) .. "|r",
            "|cffff0000" .. Command(L["CMD_CANCEL"], L["CMD_PAID"]) .. "|r"))
        self:PlaySound(SND_WAIT)
    elseif msgType == "PAID_OK" or msgType == "PAID_NO" then
        -- Solo cuenta la respuesta al aviso que yo mandé, por el mismo importe
        local amount = tonumber(parts[2])
        if not amount or self.paidSent[sender] ~= amount then return end
        self.paidSent[sender] = nil
        if msgType == "PAID_OK" then
            ATT_Data.debts[sender] = (ATT_Data.debts[sender] or 0) - amount
            print("|cff00ff00[ATT]: " .. L["PAID_ACCEPTED"]:format(sender, Money(abs(amount))) .. "|r")
        else
            print("|cffff0000[ATT]: " .. L["PAID_REJECTED"]:format(sender, Money(abs(amount))) .. "|r")
        end
        self:UpdateRankingData()
    end
end

-----------------------------------------
-- TIEMPO POR TURNO
-----------------------------------------
-- Solo cuenta el turno del rival: el mío lo vigila su cliente
function ATT:CheckTimeout(now)
    if not self.gameActive or self.isMyTurn then return end
    local left = TURN_TIMEOUT - (now - self.waitingSince)
    if left > 0 then
        self:UpdateTurnText(math.ceil(left))
        return
    end
    self:SendMessage("EXPIRE:" .. GetMyName(), self.opponent)
    print("|cffff8000[ATT]: " .. L["GAME_EXPIRED"]:format(self.opponent, TURN_TIMEOUT / 60) .. "|r")
    self:EndGame("X")
end

-----------------------------------------
-- INICIAR PARTIDA
-----------------------------------------
function ATT:StartGame(opponent, gold, iAmHost, iStart)
    local cleanOpponent = ShortName(opponent)

    self.gameActive = true
    self.opponent = cleanOpponent
    self.betAmount = gold
    self.isHost = iAmHost
    self.drawMine, self.drawTheirs = false, false
    -- Si el rival también me había retado (revancha cruzada), ese reto ya sobra
    if self.pendingInvite and SameName(self.pendingInvite.host, cleanOpponent) then self.pendingInvite = nil end
    self:ResetBoard()
    self.MainFrame:Show()
    self:ShowGameButtons(true)
    self.BetText:SetText(L["POT"] .. " |cffffffff" .. Money(gold) .. "|r")
    self:SetTurn(iStart)
    self:PlaySound(iStart and SND_OPEN or SND_WAIT)
    print("|cffffd700[ATT]: " .. L["GAME_STARTED"]:format(cleanOpponent) .. "|r")
    print("|cffffd700[ATT]: " .. L["COIN_TOSS"]:format(iStart and GetMyName() or cleanOpponent) .. "|r")
end

-----------------------------------------
-- CREAR INTERFAZ (GOBLIN STYLE)
-----------------------------------------
local function AddTooltip(button, text)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(text, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

function ATT:CreateMainFrame()
    local frame = CreateFrame("Frame", "ATT_MainFrame", UIParent, "BackdropTemplate")
    frame:SetSize(450, 580)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:Hide()
    self.MainFrame = frame

    -- Área de arrastre (Solo el título)
    local dragFrame = CreateFrame("Frame", nil, frame)
    dragFrame:SetPoint("TOPLEFT", 0, 0)
    dragFrame:SetPoint("TOPRIGHT", 0, 0)
    dragFrame:SetHeight(60)
    dragFrame:EnableMouse(true)
    dragFrame:RegisterForDrag("LeftButton")
    dragFrame:SetScript("OnDragStart", function() frame:StartMoving() end)
    dragFrame:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)

    -- Fondo Metálico Goblin / Industrial
    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    frame.bg:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal")

    -- Bordes de Oro (Colega, ¡el tiempo es dinero!)
    frame:SetBackdrop({
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
        edgeSize = 32,
        insets = { left = 5, right = 5, top = 5, bottom = 5 }
    })

    -- Cerrar solo oculta el tablero: la partida sigue (se reabre desde el
    -- minimapa). Para dejarla está el botón Rendirse.
    local closeBtn = CreateFrame("Button", "ATT_CloseButton", frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -5, -5)
    closeBtn:SetFrameLevel(frame:GetFrameLevel() + 20)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)
    self.CloseButton = closeBtn

    -- Titulo con sombra y color oro
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    frame.title:SetPoint("TOP", 0, -30)
    frame.title:SetText("|cffffd700AZEROTH TIC-TAC-TOE|r")
    frame.title:SetShadowOffset(1, -1)

    -- Subtitulo Goblin
    frame.subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.subtitle:SetPoint("TOP", frame.title, "BOTTOM", 0, -2)
    frame.subtitle:SetText("|cff888888\"" .. L["SUBTITLE"] .. "\"|r")

    -- Texto apuesta (Estilo Casino)
    frame.BetText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.BetText:SetPoint("TOP", frame.subtitle, "BOTTOM", 0, -15)
    frame.BetText:SetText(L["POT"] .. " |cffffffff" .. Money(0) .. "|r")

    -- Texto turno
    frame.TurnText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.TurnText:SetPoint("BOTTOM", 0, 50)
    frame.TurnText:SetWidth(400)
    frame.TurnText:SetText(L["WAITING_OPPONENT"])
    self.TurnText = frame.TurnText
    self.BetText = frame.BetText

    -- Rendirse (con confirmación) y Tablas, solo durante una partida
    local surrender = CreateFrame("Button", "ATT_SurrenderButton", frame, "UIPanelButtonTemplate")
    surrender:SetSize(120, 24)
    surrender:SetPoint("BOTTOMLEFT", 40, 18)
    surrender:SetText(L["SURRENDER"])
    surrender:SetScript("OnClick", function() ATT:ConfirmSurrender() end)
    AddTooltip(surrender, L["SURRENDER_TOOLTIP"])
    surrender:Hide()
    self.SurrenderButton = surrender

    local draw = CreateFrame("Button", "ATT_DrawButton", frame, "UIPanelButtonTemplate")
    draw:SetSize(120, 24)
    draw:SetPoint("BOTTOMRIGHT", -40, 18)
    draw:SetText(L["DRAW_OFFER"])
    draw:SetScript("OnClick", function() ATT:OfferDraw() end)
    AddTooltip(draw, L["DRAW_TOOLTIP"])
    draw:Hide()
    self.DrawButton = draw

    -- Revancha, solo con la partida acabada
    local rematch = CreateFrame("Button", "ATT_RematchButton", frame, "UIPanelButtonTemplate")
    rematch:SetSize(160, 24)
    rematch:SetPoint("BOTTOM", 0, 18)
    rematch:SetText(L["REMATCH"])
    rematch:SetScript("OnClick", function() ATT:Rematch() end)
    AddTooltip(rematch, L["REMATCH_TOOLTIP"])
    rematch:Hide()
    self.RematchButton = rematch
end

-----------------------------------------
-- CREAR TABLERO (MECÁNICO)
-----------------------------------------
function ATT:CreateBoard()
    local size = 120
    local spacing = 8
    for row = 1, 3 do
        for col = 1, 3 do
            local index = (row - 1) * 3 + col
            local button = CreateFrame("Button", nil, self.MainFrame)
            button:SetSize(size, size)
            button:SetFrameLevel(self.MainFrame:GetFrameLevel() + 5)

            local x = (col - 1) * (size + spacing)
            local y = -((row - 1) * (size + spacing)) - 100
            button:SetPoint("TOPLEFT", self.MainFrame, "TOPLEFT", x + 35, y)
            button.index = index

            -- Fondo de la casilla (Estilo Rejilla/Metal)
            button.border = button:CreateTexture(nil, "BACKGROUND")
            button.border:SetAllPoints()
            button.border:SetTexture("Interface\\Buttons\\UI-EmptySlot")
            button.border:SetVertexColor(0.5, 0.5, 0.5, 0.8)

            -- Resaltado Hover
            button.highlight = button:CreateTexture(nil, "HIGHLIGHT")
            button.highlight:SetAllPoints()
            button.highlight:SetTexture("Interface\\Buttons\\CheckButtonHilight")
            button.highlight:SetBlendMode("ADD")

            -- Icono del movimiento (Horda/Alianza)
            button.icon = button:CreateTexture(nil, "ARTWORK")
            button.icon:SetPoint("CENTER", 0, 0)
            button.icon:SetSize(size * 0.8, size * 0.8)
            button.icon:SetTexture(nil)

            button:SetScript("OnEnter", function(self)
                if ATT.isMyTurn and ATT.board[self.index] == "" then
                    -- Sonido mecánico sutil al pasar el ratón
                    ATT:PlaySound(SND_HOVER)
                end
            end)

            button:SetScript("OnClick", function(buttonSelf)
                ATT:OnCellClick(buttonSelf.index)
            end)

            self.cells[index] = button
        end
    end
end

-----------------------------------------
-- JUGADAS
-----------------------------------------
function ATT:OnCellClick(idx)
    if not self.gameActive then
        print("|cffff0000[ATT]: " .. L["GAME_OVER"] .. "|r")
        return
    end
    if not self.isMyTurn then
        print("|cffff0000[ATT]: " .. L["NOT_YOUR_TURN"] .. "|r")
        return
    end

    local mine = self:MyFaction()

    -- Fase de colocar: cualquier casilla libre
    if CountPieces(self.board, mine) < PIECES then
        if self.board[idx] ~= "" then
            print("|cffff0000[ATT]: " .. L["CELL_TAKEN"] .. "|r")
            return
        end
        self:PlayMove(nil, idx)
        return
    end

    -- Fase de mover: primero una ficha propia, luego su casilla de destino
    if self.board[idx] == mine then
        self:Select(idx)
        self:PlaySound(SND_HOVER)
    elseif not self.selected then
        print("|cffff0000[ATT]: " .. L["MOVE_PIECE"] .. "|r")
    elseif self.board[idx] ~= "" then
        print("|cffff0000[ATT]: " .. L["CELL_TAKEN"] .. "|r")
    elseif not ADJACENT[self.selected][idx] then
        print("|cffff0000[ATT]: " .. L["NOT_ADJACENT"] .. "|r")
    else
        self:PlayMove(self.selected, idx)
    end
end

function ATT:ApplyMove(faction, from, to)
    if from then
        self.board[from] = ""
        self:SetCellIcon(from, nil)
    end
    self.board[to] = faction
    self:SetCellIcon(to, (faction == "Horde") and TEX_HORDE or TEX_ALLIANCE)
end

function ATT:PlayMove(from, to)
    if not self.gameActive then return end

    local faction = self:MyFaction()
    if not IsLegalMove(self.board, faction, from, to) then return end

    self:ApplyMove(faction, from, to)
    self:Select(nil)
    self:SetTurn(false)

    self:PlaySound(SND_CLICK)
    self:SendMessage("MOVE:" .. to .. ":" .. faction .. ":" .. (from or 0), self.opponent)

    -- Acabo de mover yo: si esto cierra la partida, he ganado yo
    self:CheckWinner(true)
end

function ATT:SetCellIcon(index, texture)
    local button = self.cells[index]
    if button and button.icon then
        button.icon:SetTexture(texture)
    end
end

-----------------------------------------
-- CHECK WINNER
-----------------------------------------
-- iPlayed: true si la última jugada es mía. Es el único dato que decide de
-- quién es la victoria; no se puede deducir de isMyTurn, porque al recibir la
-- jugada del rival todavía no se ha cambiado el turno.
-- Sin empates: la partida sigue hasta que alguien hace 3 en raya. Con 3+3
-- fichas y 3 casillas libres nadie puede quedarse sin movimiento (comprobado
-- probando todas las posiciones), así que no hace falta regla de bloqueo.
function ATT:CheckWinner(iPlayed)
    local b = self.board
    local wins = {
        { 1, 2, 3 }, { 4, 5, 6 }, { 7, 8, 9 },
        { 1, 4, 7 }, { 2, 5, 8 }, { 3, 6, 9 },
        { 1, 5, 9 }, { 3, 5, 7 }
    }

    for _, c in ipairs(wins) do
        if b[c[1]] ~= "" and b[c[1]] == b[c[2]] and b[c[2]] == b[c[3]] then
            self:EndGame(iPlayed and "W" or "L")
            return true
        end
    end
    return false
end

-----------------------------------------
-- FINALIZAR PARTIDA
-----------------------------------------
-- result: "W" gano yo, "L" gana el rival, "D" tablas acordadas por los dos,
-- "X" caducada (el que se quedó esperando ya lo ha explicado en el chat)
function ATT:EndGame(result)
    local myName = GetMyName()
    local rival = self.opponent
    local gold = self.betAmount or 0 -- en cobre
    self.gameActive = false
    -- Para la revancha; el anfitrión deja de serlo hasta que retan otra vez
    self.lastRival, self.lastBet, self.isHost = rival, gold, false
    self:Select(nil)

    if result == "W" then
        print("|cffffd700[ATT]: " .. L["VICTORY"] .. "|r")
        self:PlaySound(SND_WIN)
        ATT_Data.rankings[myName] = (ATT_Data.rankings[myName] or 0) + 1

        if gold > 0 and rival then
            ATT_Data.debts[rival] = (ATT_Data.debts[rival] or 0) + gold
            print("|cffffff00" .. L["NOW_OWES_YOU"]:format(rival, Money(gold)) .. "|r")
            print("|cffffff00" .. L["HOW_TO_COLLECT"]:format(L["COLLECT"]) .. "|r")
        end
    elseif result == "L" then
        print("|cffff0000[ATT]: " .. L["DEFEAT"] .. "|r")
        ATT_Data.losses[myName] = (ATT_Data.losses[myName] or 0) + 1
        self:PlaySound(SND_LOSE)
        if gold > 0 and rival then
            ATT_Data.debts[rival] = (ATT_Data.debts[rival] or 0) - gold
            print("|cffff0000" .. L["NOW_YOU_OWE"]:format(rival, Money(gold)) .. "|r")
        end
    elseif result == "D" then
        print("|cffffff00[ATT]: " .. L["DRAW"] .. "|r")
        gold = 0
    end
    if result == "D" or result == "X" then self:PlaySound(SND_DRAW) end
    if result ~= "X" then
        table.insert(ATT_Data.history, { date = date("%Y-%m-%d %H:%M"), rival = rival, result = result, gold = gold })
    end

    self.TurnText:SetText("|cffffd700" .. L["GAME_FINISHED"] .. "|r")
    self:ShowGameButtons(false)

    -- Refrescar el libro de cuentas solo si lo tiene abierto durante la partida
    if self.RankingFrame and self.RankingFrame:IsShown() then
        self:UpdateRankingData()
    end
end
