-- screenshots.lua
local ADDON_NAME, Addon = ...

function Addon:PrintTotalScreenshots()
    C_Timer.After(Addon.DefaultDelay, function()
        local charTotal  = self:GetCharacterSetting("totalScreenshots") or 0
        local total      = self:GetSetting("totalScreenshots") or 0
        local playerName = UnitName("player") or "Unknown"

        print(string.format(
            Addon.L["SCREENSHOT_TOTAL"],
            playerName,
            charTotal,
            total
        ))
    end)
end

-- Doppelte Screenshots vermeiden: loesen mehrere Ereignisse kurz
-- hintereinander aus (z.B. Bosskill und Erfolg), entsteht nur EIN Bild.
-- Gemessen wird mit GetTime() (Sekundenbruchteile), nicht mit time() (ganze
-- Sekunden) - sonst waeren Schwellen wie 1,25 s wirkungslos.
local lastShotAt = nil      -- wann der letzte Screenshot wirklich gemacht wurde
local pendingShot = false   -- ist gerade einer geplant?

local function Clock()
    return GetTime and GetTime() or time()
end

function Addon:ShouldSkipScreenshot(now)
    if not self:GetSetting("preventDuplicates") then return false end
    if pendingShot then return true end
    local threshold = self:GetSetting("duplicateThreshold") or self.DefaultThreshold
    now = now or Clock()
    return lastShotAt ~= nil and (now - lastShotAt) < threshold
end

----------------------------------------------------------------------------------------------
-- Anti-Lag-Massnahme (auf Wunsch ergaenzt):
--
-- Screenshot() ist ein Engine-Aufruf von Blizzard selbst - das Spiel friert
-- kurz ein, kopiert den Bildschirmpuffer, kodiert ihn und schreibt ihn auf
-- die Platte. Diesen Vorgang kann ein Addon nicht "unsichtbar" machen; das
-- ist eine clientseitige Grenze, die wir hier ehrlich benennen statt einen
-- Ruckler-freien Screenshot zu versprechen, den es technisch nicht geben
-- kann.
--
-- Was ein Addon aber tatsaechlich beeinflussen kann, ist die JPEG-
-- Kompressionsstufe ueber die CVar "screenshotQuality" (0-10): ein
-- niedrigerer Wert braucht spuerbar weniger Rechenzeit zum Kodieren und
-- damit einen kuerzeren Ruckler, auf Kosten der Bildqualitaet/Dateigroesse.
-- Deshalb senkt Emberstone diese CVar kurz vor einem automatischen Screenshot
-- ab und stellt sie wenige Sekunden spaeter wieder auf den Wert zurueck,
-- den der Spieler selbst eingestellt hatte - manuelle Screenshots (z.B.
-- per Druck-Taste) sind davon also nicht betroffen. Zusaetzlich verhindert
-- die bereits vorhandene Duplikat-Erkennung oben, dass mehrere Ereignisse
-- kurz hintereinander mehrere Screenshots (und damit mehrere Ruckler)
-- ausloesen.
----------------------------------------------------------------------------------------------

local restoreQualityTimer = nil
local savedQuality = nil -- Wert des Spielers, solange eine Wiederherstellung aussteht

-- Den eigenen Wert des Spielers nur merken, wenn nicht schon einer
-- gemerkt ist: sonst wuerde ein zweiter Screenshot innerhalb weniger
-- Sekunden den bereits abgesenkten Wert als "vorher" speichern und die
-- Qualitaet bliebe dauerhaft niedrig.
local function ApplyReducedQuality()
    if not Addon:GetSetting("reduceQualityForShots") then return end
    if not GetCVar or not SetCVar then return end

    if savedQuality == nil then
        local ok, previous = pcall(GetCVar, "screenshotQuality")
        if not ok or not previous then return end
        savedQuality = previous
    end

    local target = Addon:GetSetting("screenshotQuality") or Addon.DefaultScreenshotQuality
    pcall(SetCVar, "screenshotQuality", tostring(math.floor(target)))
end

local function ScheduleQualityRestore()
    if savedQuality == nil then return end
    if restoreQualityTimer then
        restoreQualityTimer:Cancel()
    end
    restoreQualityTimer = C_Timer.NewTimer(3, function()
        if savedQuality ~= nil then pcall(SetCVar, "screenshotQuality", savedQuality) end
        savedQuality = nil
        restoreQualityTimer = nil
    end)
end

-- Beim Ausloggen/Neuladen innerhalb der drei Sekunden den Wert sofort
-- zurueckstellen, damit er nicht abgesenkt gespeichert wird.
local logoutFrame = CreateFrame("Frame")
logoutFrame:RegisterEvent("PLAYER_LOGOUT")
logoutFrame:SetScript("OnEvent", function()
    if savedQuality ~= nil and SetCVar then pcall(SetCVar, "screenshotQuality", savedQuality) end
end)

function Addon:TakeScreenshot(delay)
    if self:ShouldSkipScreenshot() then return end
    pendingShot = true -- sofort reservieren

    C_Timer.After(delay, function()
        pendingShot = false
        -- Falls seit dem Planen schon ein anderer Screenshot gemacht wurde
        -- (z.B. von Hand), nicht noch einmal ausloesen.
        if self:ShouldSkipScreenshot() then return end

        ApplyReducedQuality()
        Screenshot()
        ScheduleQualityRestore()

        lastShotAt = Clock()
        self:SetSetting("lastScreenshotTime", time())
        print(Addon.L["SCREENSHOT_SAVED"])

        -- Zaehler erst, wenn das Bild wirklich gemacht wurde
        self:SetSetting("totalScreenshots", (self:GetSetting("totalScreenshots") or 0) + 1)
        self:SetCharacterSetting("totalScreenshots", (self:GetCharacterSetting("totalScreenshots") or 0) + 1)
    end)
end

-- Auch Screenshots von Hand (Druck-Taste) zaehlen fuer die Doppelt-Sperre.
local manualFrame = CreateFrame("Frame")
manualFrame:RegisterEvent("SCREENSHOT_SUCCEEDED")
manualFrame:SetScript("OnEvent", function()
    lastShotAt = Clock()
end)
