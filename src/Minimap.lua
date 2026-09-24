-- minimap.lua
--
-- Minimap-Symbol (seit v1.12). Bewusst ohne Bibliothek (LibDBIcon) gebaut -
-- gleiche Haltung wie bei Grindkeep und Loreclash: ein runder Knopf am
-- Minimap-Rand, mit der Maus um die Karte verschiebbar. Gespeichert wird
-- nur der Winkel, damit die Position auch bei anderer Minimap-Groesse
-- stimmt. Eckige Minimaps (z.B. ElvUI) werden beachtet.
--
-- Linksklick: Optionen, Rechtsklick: Test-Benachrichtigung.
-- Ausblenden: Optionen -> Sonstiges, oder /emberstone minimap.
local ADDON_NAME, Addon = ...
local L = Addon.L

local button

local function Place(angle)
    local rad = math.rad(angle or 240)
    local w = Minimap:GetWidth() or 140
    local r = w / 2 + 10
    local x, y = math.cos(rad), math.sin(rad)
    local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
    if shape == "SQUARE" then
        local m = math.max(math.abs(x), math.abs(y))
        x, y = x / m, y / m
        r = w / 2 + 6
    end
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x * r, y * r)
end

local function Build()
    if button or not Minimap then return end
    local b = CreateFrame("Button", "EmberstoneMinimapButton", Minimap)
    b:SetSize(31, 31)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 8)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetPoint("TOPLEFT")
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(20, 20)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetPoint("TOPLEFT", 7, -5)
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetSize(19, 19)
    icon:SetPoint("TOPLEFT", 7, -6)
    icon:SetTexture("Interface\\AddOns\\" .. ADDON_NAME .. "\\Assets\\minimap.tga")
    icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)

    b:SetScript("OnMouseDown", function() icon:SetPoint("TOPLEFT", 8, -7) end)
    b:SetScript("OnMouseUp", function() icon:SetPoint("TOPLEFT", 7, -6) end)
    b:SetScript("OnDragStart", function(self)
        GameTooltip:Hide()
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            local angle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
            Addon:SetSetting("minimapAngle", angle)
            Place(angle)
        end)
    end)
    b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    b:SetScript("OnClick", function(_, mouse)
        if mouse == "RightButton" then
            Addon:TestGuildDing()
        else
            Addon:OpenOptions()
        end
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Emberstone")
        GameTooltip:AddLine(L["MINIMAP_TOOLTIP_LEFT"], 1, 1, 1)
        GameTooltip:AddLine(L["MINIMAP_TOOLTIP_RIGHT"], 1, 1, 1)
        GameTooltip:AddLine(L["MINIMAP_TOOLTIP_DRAG"], 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button = b
end

function Addon:UpdateMinimapButton()
    if self:GetSetting("minimapHide") then
        if button then button:Hide() end
        return
    end
    Build()
    if not button then return end
    Place(self:GetSetting("minimapAngle"))
    button:Show()
end

function Addon:SetMinimapShown(show)
    self:SetSetting("minimapHide", not show)
    self:UpdateMinimapButton()
end

function Addon:OpenOptions()
    -- Blizzard fuehrt das Oeffnen des Optionsfensters als eingeschraenkte
    -- Aktion (C_SettingsUtil.OpenSettingsPanel, "HasRestrictions") - im
    -- Kampf lieber einen Hinweis zeigen, statt eine Sperre auszuloesen.
    if InCombatLockdown and InCombatLockdown() then
        print(L["OPTIONS_IN_COMBAT"])
        return
    end
    if self.OptionsCategory and self.OptionsCategory.ID and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(self.OptionsCategory.ID)
    else
        print(L["OPTIONS_UNAVAILABLE"])
    end
end

-- Addon-Sammelknopf an der Minimap (Retail, "AddonCompartmentFunc" in der .toc)
function Emberstone_OnAddonCompartmentClick()
    Addon:OpenOptions()
end
