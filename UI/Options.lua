local ADDON_NAME, ns = ...
local L = ns.L

-- ==========================================
-- OPCIONES
-- ==========================================
-- Raiz "Acerca de" (UI/About.lua, con las reglas del juego) y, colgando de
-- ella, "General" con los ajustes basicos. Se guardan en ATT_Data.settings.

local HEADER = "|cffC47FF3"
local LOGO = "Interface\\AddOns\\AzerothTicTacToe\\img\\logo_attt"

local function AddTooltip(widget, text)
    widget:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(text, nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function Percent(value)
    return math.floor(value * 100 + 0.5) .. "%"
end

local function CreateGeneral(ATT)
    local db = ATT_Data.settings
    local panel = CreateFrame("Frame")
    panel:Hide()
    local x = 16
    local refresh = {}

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", x, -16)
    title:SetText(L.OPTIONS_TITLE)

    local logo = panel:CreateTexture(nil, "ARTWORK")
    logo:SetSize(110, 110)
    logo:SetPoint("TOPRIGHT", -38, -5)
    logo:SetTexture(LOGO)

    local version = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    version:SetPoint("TOP", logo, "BOTTOM", 0, -2)
    version:SetText("v" .. (C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "?"))

    local header = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    header:SetPoint("TOPLEFT", x, -56)
    header:SetText(HEADER .. L.GENERAL_HEADER .. "|r")

    local function Checkbox(key, y, label, tooltip)
        local cb = CreateFrame("CheckButton", "AzerothTicTacToe_" .. key, panel, "InterfaceOptionsCheckButtonTemplate")
        cb:SetPoint("TOPLEFT", x, y)
        _G[cb:GetName() .. "Text"]:SetText(label)
        cb:SetScript("OnClick", function(self)
            db[key] = self:GetChecked() and true or false
            ATT:ApplySettings()
        end)
        AddTooltip(cb, tooltip)
        refresh[#refresh + 1] = function() cb:SetChecked(db[key]) end
    end

    Checkbox("minimap", -81, L.OPT_MINIMAP, L.OPT_MINIMAP_TT)
    Checkbox("sound", -111, L.OPT_SOUND, L.OPT_SOUND_TT)
    Checkbox("challenges", -141, L.OPT_CHALLENGES, L.OPT_CHALLENGES_TT)

    local line = panel:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 1, 1, 0.1)
    line:SetSize(580, 1)
    line:SetPoint("TOPLEFT", x, -180)

    -- Tamaño del tablero: 50% - 150%
    local slider = CreateFrame("Slider", "AzerothTicTacToe_scale", panel, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", x + 10, -210)
    slider:SetWidth(400)
    slider:SetMinMaxValues(0.5, 1.5)
    slider:SetValueStep(0.1)
    slider:SetObeyStepOnDrag(true)
    _G[slider:GetName() .. "Low"]:SetText(Percent(0.5))
    _G[slider:GetName() .. "High"]:SetText(Percent(1.5))
    local function Label() _G[slider:GetName() .. "Text"]:SetText(L.OPT_SCALE .. ": " .. Percent(db.scale)) end
    slider:SetScript("OnValueChanged", function(_, value)
        value = math.floor(value / 0.1 + 0.5) * 0.1
        if value == db.scale then return end
        db.scale = value
        Label()
        ATT:ApplySettings()
    end)
    AddTooltip(slider, L.OPT_SCALE_TT)
    refresh[#refresh + 1] = function()
        slider:SetValue(db.scale)
        Label()
    end

    local line2 = panel:CreateTexture(nil, "ARTWORK")
    line2:SetColorTexture(1, 1, 1, 0.1)
    line2:SetSize(580, 1)
    line2:SetPoint("TOPLEFT", x, -260)

    local function Refresh()
        for _, fn in ipairs(refresh) do fn() end
    end
    panel:SetScript("OnShow", Refresh)

    local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    reset:SetSize(180, 26)
    reset:SetPoint("TOPLEFT", x, -280)
    reset:SetText(L.DEFAULTS)
    reset:SetScript("OnClick", function()
        for k, v in pairs(ns.DEFAULTS) do db[k] = v end
        Refresh()
        ATT:ApplySettings()
    end)

    return panel
end

-- Devuelve el id de la subcategoria General, que abre /ttt
function ns.CreateOptions(ATT, commands)
    local root = ns.CreateAbout({
        name = "Azeroth TicTacToe",
        logo = LOGO,
        github = "https://github.com/Pirson-s-Addons/AzerothTicTacToe",
        curseforge = "https://www.curseforge.com/wow/addons/azeroth-tic-tac-toe",
        commands = commands,
    })
    local general = Settings.RegisterCanvasLayoutSubcategory(root, CreateGeneral(ATT), L.GENERAL)
    return general:GetID()
end
