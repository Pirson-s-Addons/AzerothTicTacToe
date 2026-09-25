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

ATT.prefix = "AZTICTACTOE"
ATT.gameActive = false
ATT.opponent = nil
ATT.betAmount = 0
ATT.isMyTurn = false
ATT.isHost = false
ATT.board = { "", "", "", "", "", "", "", "", "" }
ATT.pendingInvite = nil
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

-----------------------------------------
-- RESET TABLERO
-----------------------------------------
function ATT:ResetBoard()
    self.board = { "", "", "", "", "", "", "", "", "" }
    for i, cell in ipairs(self.cells) do
        cell.icon:SetTexture(nil)
        -- No ocultamos el border porque es el fondo industrial de la casilla
    end
    if self.TurnText then self.TurnText:SetText(L["WAITING_TURN"]) end
end

-----------------------------------------
-- HELPER MENSAJES Y SONIDOS
-----------------------------------------
function ATT:PlaySound(soundID)
    PlaySound(soundID, "Master")
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
    ATT_Data.debts = ATT_Data.debts or {}       -- { ["Player"] = amount } (positivo me deben, negativo debo)
    ATT_Data.history = ATT_Data.history or {}   -- { { date=T, rival=R, result=W/L/D, gold=G } }

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
-- RANKING Y RIQUEZA (EL LIBRO DE CUENTAS)
-----------------------------------------
function ATT:CreateRankingFrame()
    if self.RankingFrame then
        self.RankingFrame:Show()
        self:UpdateRankingData()
        return
    end

    local frame = CreateFrame("Frame", "ATT_RankingFrame", UIParent, "BackdropTemplate")
    frame:SetSize(400, 500)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    -- Fondo y Borde Goblin
    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    frame.bg:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal")
    frame:SetBackdrop({
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
        edgeSize = 24,
        insets = { left = 5, right = 5, top = 5, bottom = 5 }
    })

    -- Titulo
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("TOP", 0, -20)
    frame.title:SetText("|cffffd700" .. L["LEDGER_TITLE"] .. "|r")

    -- Botón Cerrar
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -5, -5)
    close:SetScript("OnClick", function() frame:Hide() end)

    ---------------------------
    -- SECCIÓN: NUEVO TRATO
    ---------------------------
    local dealHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    dealHeader:SetPoint("TOPLEFT", 25, -60)
    dealHeader:SetText("|cff00ff00" .. L["NEW_DEAL"] .. "|r")

    -- Input Nombre
    local nameBox = CreateFrame("EditBox", "ATT_NameInput", frame, "InputBoxTemplate")
    nameBox:SetSize(120, 20)
    nameBox:SetPoint("TOPLEFT", 25, -85)
    nameBox:SetAutoFocus(false)
    nameBox:SetText(L["NAME"])
    nameBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    -- Input Oro
    local goldBox = CreateFrame("EditBox", "ATT_GoldInput", frame, "InputBoxTemplate")
    goldBox:SetSize(60, 20)
    goldBox:SetPoint("LEFT", nameBox, "RIGHT", 15, 0)
    goldBox:SetAutoFocus(false)
    goldBox:SetNumeric(true)
    goldBox:SetText("0")

    -- Botón Retar
    local challengeBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    challengeBtn:SetSize(80, 22)
    challengeBtn:SetPoint("LEFT", goldBox, "RIGHT", 10, 0)
    challengeBtn:SetText(L["CHALLENGE"])
    challengeBtn:SetScript("OnClick", function()
        local name = nameBox:GetText()
        local gold = tonumber(goldBox:GetText()) or 0
        if name ~= "" and name ~= L["NAME"] then
            ATT:HandleSlashCommand(name .. " " .. gold)
            ATT:PlaySound(SND_CLICK)
        end
    end)

    ---------------------------
    -- SECCIÓN: LISTADO (Scrolling)
    ---------------------------
    -- Usaremos un ScrollFrame simple
    local scrollFrame = CreateFrame("ScrollFrame", "ATT_RankingScroll", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(330, 320)
    scrollFrame:SetPoint("TOP", 0, -140)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(330, 400)
    scrollFrame:SetScrollChild(content)

    -- Ranking e historial son texto corrido: un FontString cada uno, reescrito
    -- en cada refresco. Solo las deudas necesitan widgets por fila (botones),
    -- y esas se reciclan en content.rows.
    content.rankText = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    content.rankText:SetPoint("TOPLEFT", 10, 0)
    content.rankText:SetJustifyH("LEFT")

    content.histText = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    content.histText:SetJustifyH("LEFT")

    content.rows = {}

    frame.content = content
    self.RankingFrame = frame

    self:UpdateRankingData()
end

-- Crea o recicla la fila N de la lista de deudas
local function AcquireDebtRow(content, i)
    local row = content.rows[i]
    if row then
        row:Show()
        return row
    end

    row = CreateFrame("Frame", nil, content)
    row:SetSize(310, 20)

    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.text:SetPoint("LEFT", 10, 0)
    row.text:SetWidth(160)
    row.text:SetJustifyH("LEFT")

    row.clearBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.clearBtn:SetSize(65, 18)
    row.clearBtn:SetPoint("RIGHT", 0, 0)
    row.clearBtn:SetText(L["SETTLED"])
    row.clearBtn:SetNormalFontObject("GameFontNormalSmall")

    row.tradeBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.tradeBtn:SetSize(60, 18)
    row.tradeBtn:SetPoint("RIGHT", row.clearBtn, "LEFT", -4, 0)
    row.tradeBtn:SetText(L["COLLECT"])
    row.tradeBtn:SetNormalFontObject("GameFontNormalSmall")

    content.rows[i] = row
    return row
end

function ATT:UpdateRankingData()
    if not self.RankingFrame then return end
    local content = self.RankingFrame.content

    ---------------------------
    -- RANKING
    ---------------------------
    local sortedR = {}
    for name, wins in pairs(ATT_Data.rankings) do
        table.insert(sortedR, { name = name, wins = wins })
    end
    table.sort(sortedR, function(a, b) return a.wins > b.wins end)

    local lines = { "|cffffd700" .. L["RANKING"] .. "|r" }
    for i, data in ipairs(sortedR) do
        if i > 5 then break end -- Solo top 5
        table.insert(lines, "   " .. i .. ". " .. data.name .. ": " .. L["WINS"]:format(data.wins))
    end
    if #lines == 1 then
        table.insert(lines, "   |cff808080" .. L["NO_WINS"] .. "|r")
    end
    table.insert(lines, " ")
    table.insert(lines, "|cffffd700" .. L["DEBTS"] .. "|r")
    content.rankText:SetText(table.concat(lines, "\n"))

    local yOffset = -content.rankText:GetStringHeight() - 6

    ---------------------------
    -- DEUDAS (una fila con botones por cada una)
    ---------------------------
    local rowCount = 0
    for name, amount in pairs(ATT_Data.debts) do
        if amount ~= 0 then
            rowCount = rowCount + 1
            local row = AcquireDebtRow(content, rowCount)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 10, yOffset)

            local color = (amount > 0) and "|cff00ff00" or "|cffff0000"
            local label = (amount > 0) and L["OWES_YOU"] or L["YOU_OWE"]
            row.text:SetText(name .. " " .. color .. label .. " " .. abs(amount) .. "g|r")

            row.clearBtn:SetScript("OnClick", function()
                ATT_Data.debts[name] = 0
                ATT:UpdateRankingData()
                ATT:PlaySound(SND_HOVER)
            end)

            -- Solo tiene sentido abrir comercio si son ellos los que pagan
            if amount > 0 then
                row.tradeBtn:Show()
                row.tradeBtn:SetScript("OnClick", function() ATT:TradeWith(name) end)
            else
                row.tradeBtn:Hide()
            end

            yOffset = yOffset - 22
        end
    end

    -- Ocultar las filas sobrantes del refresco anterior
    for i = rowCount + 1, #content.rows do
        content.rows[i]:Hide()
    end

    if rowCount == 0 then
        yOffset = yOffset - 4
    end

    ---------------------------
    -- HISTORIAL
    ---------------------------
    local hist = { rowCount == 0 and "   |cff808080" .. L["NO_DEBTS"] .. "|r" or " ", " ",
        "|cffffd700" .. L["HISTORY"] .. "|r" }

    local count = 0
    for i = #ATT_Data.history, 1, -1 do
        if count >= 10 then break end -- Solo las últimas 10 partidas
        local entry = ATT_Data.history[i]
        local resultColor = (entry.result == "W") and "|cff00ff00" .. L["RESULT_WIN"] .. "|r"
            or (entry.result == "L") and "|cffff0000" .. L["RESULT_LOSS"] .. "|r"
            or "|cffffff00" .. L["RESULT_DRAW"] .. "|r"
        table.insert(hist, "   " .. entry.date .. " " .. resultColor .. " vs " .. entry.rival .. " (" .. entry.gold .. "g)")
        count = count + 1
    end
    if count == 0 then
        table.insert(hist, "   |cff808080" .. L["NO_HISTORY"] .. "|r")
    end

    content.histText:ClearAllPoints()
    content.histText:SetPoint("TOPLEFT", 10, yOffset)
    content.histText:SetText(table.concat(hist, "\n"))

    content:SetHeight(abs(yOffset) + content.histText:GetStringHeight() + 30)
end

function ATT:HandleSlashCommand(msg)
    local args = {}
    for word in msg:gmatch("%S+") do table.insert(args, word) end

    if not args[1] then
        print(L["USAGE"])
        print(L["USAGE_INVITE"])
        print("/ttt accept")
        print("/ttt cancel")
        return
    end

    local command = string.lower(args[1])

    if command == "accept" then
        self:AcceptInvite()
        return
    elseif command == "cancel" then
        self:CancelInvite()
        return
    end

    local playerName = args[1]
    local gold = math.max(0, math.floor(tonumber(args[2]) or 0))

    if SameName(playerName, GetMyName()) then
        print(L["NOT_YOURSELF"])
        return
    end
    if self.gameActive then
        print("|cffff0000[ATT]: " .. L["FINISH_BEFORE_CHALLENGE"] .. "|r")
        return
    end

    print(L["SENDING_INVITE"]:format(playerName, gold))
    self:SendInvite(playerName, gold)
end

-----------------------------------------
-- INVITACIONES
-----------------------------------------
function ATT:SendInvite(target, gold)
    self:SendMessage("INVITE:" .. GetMyName() .. ":" .. gold, target)
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
    self:SendMessage("ACCEPT:" .. GetMyName(), self.pendingInvite.host)
    self:StartGame(self.pendingInvite.host, self.pendingInvite.gold, false)
    self.pendingInvite = nil
end

function ATT:CancelInvite()
    if not self.pendingInvite then
        print("|cffff0000[ATT]: " .. L["NO_INVITE"] .. "|r")
        return
    end
    self:SendMessage("CANCEL:" .. GetMyName(), self.pendingInvite.host)
    print("|cffff0000[ATT]: " .. L["DECLINED"] .. "|r")
    self.pendingInvite = nil
end

function ATT:CancelGame()
    if self.gameActive then
        if self.opponent then
            self:SendMessage("CANCEL_GAME:" .. GetMyName(), self.opponent)
        end
        print("|cffff0000[ATT]: " .. L["GAME_CANCELLED"] .. "|r")
    end
    self.gameActive = false
    if self.MainFrame then self.MainFrame:Hide() end
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

    if msgType == "INVITE" then
        -- El anfitrión es quien envía, no el nombre que viaja en el mensaje
        local host = sender
        local gold = tonumber(parts[3])
        if not gold or gold < 0 then return end
        print("|cffffff00[ATT]: " .. L["CHALLENGED"]:format(host, gold) .. "|r")
        print("|cff888888\"" .. L["TAUNT"] .. "\"|r")
        print(L["TYPE_ACCEPT"]:format("|cff00ff00/ttt accept|r", "|cffff0000/ttt cancel|r"))
        self.pendingInvite = { host = host, gold = gold }
    elseif msgType == "ACCEPT" then
        if not self.isHost or self.gameActive or not SameName(sender, self.opponent) then return end
        print("|cff00ff00" .. L["ACCEPTED"]:format(sender) .. "|r")
        self:StartGame(sender, self.betAmount, true)
    elseif msgType == "CANCEL" then
        -- Solo el retado al que invité puede rechazarla
        if not self.isHost or self.gameActive or not SameName(sender, self.opponent) then return end
        print("|cffff0000" .. L["REJECTED"]:format(sender) .. "|r")
        self.opponent = nil
        self.isHost = false
    elseif msgType == "CANCEL_GAME" then
        if not self.gameActive or sender ~= self.opponent then return end
        print("|cffff0000[ATT]: " .. L["OPPONENT_LEFT"]:format(sender) .. "|r")
        self.gameActive = false
        if self.MainFrame then self.MainFrame:Hide() end
    elseif msgType == "MOVE" then
        -- Solo el rival de la partida en curso mueve, y solo cuando no es mi turno
        if not self.gameActive or sender ~= self.opponent or self.isMyTurn then return end

        local index = tonumber(parts[2])
        local faction = parts[3]
        if not index or index < 1 or index > 9 or not faction then return end
        if self.board[index] ~= "" then return end

        self:SetCellIcon(index, (faction == "Horde") and TEX_HORDE or TEX_ALLIANCE)
        self.board[index] = faction

        -- El rival acaba de mover: si esto cierra la partida, ha ganado él
        if self:CheckWinner(false) then return end

        self.isMyTurn = true
        self.TurnText:SetText("|cff00ff00" .. L["YOUR_TURN"] .. "|r")
        self:PlaySound(SND_CLICK)
    end
end

-----------------------------------------
-- INICIAR PARTIDA
-----------------------------------------
function ATT:StartGame(opponent, gold, iAmHost)
    local cleanOpponent = ShortName(opponent)

    self.gameActive = true
    self.opponent = cleanOpponent
    self.betAmount = gold
    self.isMyTurn = iAmHost
    self.isHost = iAmHost
    self:ResetBoard()
    self.MainFrame:Show()
    self.BetText:SetText(L["POT"] .. " |cffffffff" .. gold .. "|r |TInterface\\MoneyFrame\\UI-GoldIcon:14:14:0:0|t")
    if self.isMyTurn then
        self.TurnText:SetText("|cff00ff00" .. L["YOUR_TURN_FIRST"] .. "|r")
        self:PlaySound(SND_OPEN)
    else
        self.TurnText:SetText("|cffff0000" .. L["TURN_OF"]:format(cleanOpponent) .. "|r")
        self:PlaySound(SND_WAIT)
    end
    print("|cffffd700[ATT]: " .. L["GAME_STARTED"]:format(cleanOpponent) .. "|r")
end

-----------------------------------------
-- CREAR INTERFAZ (GOBLIN STYLE)
-----------------------------------------
function ATT:CreateMainFrame()
    local frame = CreateFrame("Frame", "ATT_MainFrame", UIParent, "BackdropTemplate")
    frame:SetSize(450, 550)
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

    -- Botón Cerrar
    local closeBtn = CreateFrame("Button", "ATT_CloseButton", frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -5, -5)
    closeBtn:SetFrameLevel(frame:GetFrameLevel() + 20)
    closeBtn:SetScript("OnClick", function()
        ATT:CancelGame()
    end)
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
    frame.BetText:SetText(L["POT"] .. " |cffffffff0|r |TInterface\\MoneyFrame\\UI-GoldIcon:14:14:0:0|t")

    -- Texto turno
    frame.TurnText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.TurnText:SetPoint("BOTTOM", 0, 35)
    frame.TurnText:SetText(L["WAITING_OPPONENT"])
    self.TurnText = frame.TurnText
    self.BetText = frame.BetText
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
                local idx = buttonSelf.index

                if not ATT.gameActive then
                    print("|cffff0000[ATT]: " .. L["GAME_OVER"] .. "|r")
                    return
                end

                if not ATT.isMyTurn then
                    print("|cffff0000[ATT]: " .. L["NOT_YOUR_TURN"] .. "|r")
                    return
                end

                if ATT.board[idx] ~= "" then
                    print("|cffff0000[ATT]: " .. L["CELL_TAKEN"] .. "|r")
                    return
                end

                ATT:PlayMove(idx)
            end)

            self.cells[index] = button
        end
    end
end

-----------------------------------------
-- JUGADAS
-----------------------------------------
function ATT:PlayMove(index)
    if not self.gameActive then return end

    local faction = self.isHost and "Horde" or "Alliance"

    self.board[index] = faction
    self:SetCellIcon(index, (faction == "Horde") and TEX_HORDE or TEX_ALLIANCE)

    self.isMyTurn = false
    self.TurnText:SetText("|cffff0000" .. L["TURN_OF"]:format(self.opponent) .. "|r")

    self:PlaySound(SND_CLICK)
    self:SendMessage("MOVE:" .. index .. ":" .. faction, self.opponent)

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
-- iPlayed: true si la última ficha la he puesto yo. Es el único dato que
-- decide de quién es la victoria; no se puede deducir de isMyTurn, porque al
-- recibir la jugada del rival todavía no se ha cambiado el turno.
function ATT:CheckWinner(iPlayed)
    local b = self.board
    local wins = {
        { 1, 2, 3 }, { 4, 5, 6 }, { 7, 8, 9 },
        { 1, 4, 7 }, { 2, 5, 8 }, { 3, 6, 9 },
        { 1, 5, 9 }, { 3, 5, 7 }
    }

    for _, c in ipairs(wins) do
        if b[c[1]] ~= "" and b[c[1]] == b[c[2]] and b[c[2]] == b[c[3]] then
            self:EndGame(true, iPlayed)
            return true
        end
    end

    -- Empate
    local draw = true
    for i = 1, 9 do if b[i] == "" then draw = false end end
    if draw then
        self:EndGame(false, iPlayed)
        return true
    end
    return false
end

-----------------------------------------
-- FINALIZAR PARTIDA
-----------------------------------------
function ATT:EndGame(hasWinner, iWon)
    local myName = GetMyName()
    local rival = self.opponent
    local gold = self.betAmount or 0
    self.gameActive = false

    if hasWinner and iWon then
        print("|cffffd700[ATT]: " .. L["VICTORY"] .. "|r")
        self:PlaySound(SND_WIN)
        ATT_Data.rankings[myName] = (ATT_Data.rankings[myName] or 0) + 1

        if gold > 0 and rival then
            ATT_Data.debts[rival] = (ATT_Data.debts[rival] or 0) + gold
            print("|cffffff00" .. L["NOW_OWES_YOU"]:format(rival, gold) .. "|r")
            print("|cffffff00" .. L["HOW_TO_COLLECT"]:format(L["COLLECT"]) .. "|r")
        end
        table.insert(ATT_Data.history, { date = date("%Y-%m-%d %H:%M"), rival = rival, result = "W", gold = gold })
    elseif hasWinner then
        print("|cffff0000[ATT]: " .. L["DEFEAT"] .. "|r")
        self:PlaySound(SND_LOSE)
        if gold > 0 and rival then
            ATT_Data.debts[rival] = (ATT_Data.debts[rival] or 0) - gold
            print("|cffff0000" .. L["NOW_YOU_OWE"]:format(rival, gold) .. "|r")
        end
        table.insert(ATT_Data.history, { date = date("%Y-%m-%d %H:%M"), rival = rival, result = "L", gold = gold })
    else
        print("|cffffff00[ATT]: " .. L["DRAW"] .. "|r")
        self:PlaySound(SND_DRAW)
        table.insert(ATT_Data.history, { date = date("%Y-%m-%d %H:%M"), rival = rival, result = "D", gold = 0 })
    end

    self.TurnText:SetText("|cffffd700" .. L["GAME_FINISHED"] .. "|r")

    -- Refrescar el libro de cuentas solo si lo tiene abierto durante la partida
    if self.RankingFrame and self.RankingFrame:IsShown() then
        self:UpdateRankingData()
    end
end
