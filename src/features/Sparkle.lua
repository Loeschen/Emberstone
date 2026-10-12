-- features/Sparkle.lua
--
-- Glitzern fuer Beute, Kraeuter, Erzadern und Questobjekte (seit v1.13).
-- Komplett selbst geschrieben, nur auf Basis der Blizzard-API und der
-- Konsolenvariablen (CVars) des Spiels.
--
-- Teil 1 - Quest-Gegenstaende/Beute glitzern (ab Werk AN):
--   Der Client zeigt den Beute-Glitzereffekt auch dann, wenn die Umriss-
--   Darstellung ausgeschaltet ist und "outlineModeShowLootEffectWhenDisabled"
--   gesetzt ist. Emberstone setzt dafuer die Werte aus LOOT_CVARS - beim
--   Login, nach jeder Grafikaenderung (z.B. Voreinstellung) und nach einem
--   Neustart der Grafik. Im Kampf wird nichts geaendert, sondern nach dem
--   Kampf nachgeholt.
--
-- Teil 2 - Kraeuter, Erzadern, Questobjekte (ab Werk AUS):
--   Ueber Blizzards Soft Targeting ("softinteract") waehlt der Client beim
--   Naeherkommen ein Objekt in der Naehe aus und gibt ihm eine Namensplakette.
--   Daran haengt Emberstone eine eigene Glitzer-Grafik: schwach, solange das
--   Objekt noch nicht benutzt werden kann (meist: ausser Reichweite), hell in
--   Reichweite, grau, wenn dem Charakter der Beruf fehlt. Im Kampf aus.
--   Einschraenkung: Soft Targeting waehlt immer nur EIN Objekt gleichzeitig.
--   Aussehen (v1.13, Variante B): 4-5 goldene Funken mit weichem Schimmer an
--   der Unterkante der Plakette, Blizzards schwebendes Symbol ausgeblendet.
--   Legt der Client ohne Symbol keine Plakette an, faellt Emberstone von
--   selbst auf Variante C zurueck (Symbol bleibt, Funken darunter).
--
-- Fuer beide Teile gilt: Jede CVar wird nur angefasst, wenn der Client sie
-- kennt. Der Wert des Spielers wird vorher gespeichert und beim Ausschalten
-- wiederhergestellt (Teil 2: sobald alle drei Schalter aus sind).
--
-- Vertraeglichkeit: Ist eines der Addons aus CONFLICT_ADDONS geladen, schaltet
-- Emberstone hier nichts ein und fasst keine CVar an, damit sich die Addons
-- nicht gegenseitig die Einstellungen verstellen.
local ADDON_NAME, Addon = ...
local L = Addon.L

local CONFLICT_ADDONS = { "ForeverLootSparkles", "Lueur" }

local LOOT_CVARS = {
    { name = "outlineModeShowLootEffectWhenDisabled", value = "1" },
    { name = "graphicsOutlineMode", value = "0" },
    { name = "OutlineEngineMode", value = "0" },
    { name = "raidGraphicsOutlineMode", value = "0" },
    { name = "RAIDOutlineEngineMode", value = "0" },
}

local SOFT_CVARS = {
    { name = "softTargetInteract", value = "3" },       -- Enum.SoftTargetEnableFlags.Any
    { name = "SoftTargetIconGameObject", value = "1" }, -- Plakette auch fuer Objekte
    { name = "SoftTargetIconInteract", value = "1" },
    -- Variante B: Blizzards schwebendes Symbol ausblenden (Blizzard_NamePlates.lua
    -- zeigt es nur bei einer Groesse > 0). Ob die Plakette dann bleibt, an der
    -- unser Glitzern haengt, ist nicht dokumentiert - siehe Rueckfall C unten.
    { name = "SoftTargetNameplateSize", value = "0", modeB = true },
}

-- Loest eine Neuanwendung aus, wenn der Spieler die Grafik-Voreinstellung
-- aendert (diese setzt die Umriss-Werte mit).
local PRESET_CVARS = { graphicsquality = true, raidgraphicsquality = true }

local SKILL_HERBALISM, SKILL_MINING = 182, 186

local GROUPS = {
    loot = {
        cvars = LOOT_CVARS,
        wanted = function() return Addon:GetSetting("sparkleQuestLoot") and true or false end,
    },
    soft = {
        cvars = SOFT_CVARS,
        wanted = function()
            return (Addon:GetSetting("sparkleHerbs") or Addon:GetSetting("sparkleOre")
                or Addon:GetSetting("sparkleQuestObjects")) and true or false
        end,
    },
}

-- Name (klein geschrieben) -> Gruppe und Sollwert, fuer CVAR_UPDATE
local MANAGED = {}
for key, group in pairs(GROUPS) do
    for _, cv in ipairs(group.cvars) do
        MANAGED[cv.name:lower()] = { group = key, name = cv.name, value = cv.value, modeB = cv.modeB }
    end
end

-- ------------------------------------------------------------
-- CVar-Helfer
-- ------------------------------------------------------------
local function CVarGet(name)
    local get = (C_CVar and C_CVar.GetCVar) or GetCVar
    if not get then return nil end
    local ok, value = pcall(get, name)
    if ok and value ~= nil then return tostring(value) end
    return nil
end

local function CVarSet(name, value)
    local set = (C_CVar and C_CVar.SetCVar) or SetCVar
    if not set then return false end
    local ok, result = pcall(set, name, value)
    return ok and result ~= false
end

local function InCombat()
    return InCombatLockdown and InCombatLockdown() and true or false
end

local function SavedRoot()
    EmberstoneCommon.sparkleSaved = EmberstoneCommon.sparkleSaved or {}
    return EmberstoneCommon.sparkleSaved
end

-- ------------------------------------------------------------
-- Vertraeglichkeit
-- ------------------------------------------------------------
function Addon:GetSparkleConflict()
    local isLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    if not isLoaded then return nil end
    for _, name in ipairs(CONFLICT_ADDONS) do
        local ok, loaded = pcall(isLoaded, name)
        if ok and loaded then return name end
    end
    return nil
end

-- ------------------------------------------------------------
-- Anwenden / Wiederherstellen
-- ------------------------------------------------------------
-- Rueckfall C: Blizzards Symbol bleibt sichtbar, weil das Spiel ohne Symbol
-- keine Plakette fuer das Objekt anlegt. Wird gespeichert, damit nicht bei
-- jedem Login erneut umgeschaltet wird (/emberstone sparkle retry setzt zurueck).
local function IsFallbackC()
    return EmberstoneCommon and EmberstoneCommon.sparkleFallbackC and true or false
end

local applying = false   -- eigene SetCVar-Aufrufe nicht als Spieleraenderung werten
local pending = false    -- im Kampf verschoben
local refreshQueued = false

local function ApplyGroup(key)
    local group = GROUPS[key]
    local root = SavedRoot()
    if group.wanted() then
        local saved = root[key] or {}
        for _, cv in ipairs(group.cvars) do
            local current = (not (cv.modeB and IsFallbackC())) and CVarGet(cv.name) or nil
            if current ~= nil then -- unbekannte CVar oder Rueckfall C: ueberspringen
                if saved[cv.name] == nil then saved[cv.name] = current end
                if current ~= cv.value then CVarSet(cv.name, cv.value) end
            end
        end
        root[key] = saved
    elseif root[key] then
        for name, old in pairs(root[key]) do
            local current = CVarGet(name)
            if current ~= nil and current ~= old then CVarSet(name, old) end
        end
        root[key] = nil
    end
end

local UpdateGlitter -- Vorwaertsdeklaration (Teil 2)

-- Rueckgabe: "conflict", "combat" (nachgeholt) oder "ok"
function Addon:RefreshSparkle()
    if self:GetSparkleConflict() then
        pending = false
        if UpdateGlitter then UpdateGlitter() end
        return "conflict"
    end
    if InCombat() then
        pending = true
        if UpdateGlitter then UpdateGlitter() end
        return "combat"
    end
    pending = false
    applying = true
    ApplyGroup("loot")
    ApplyGroup("soft")
    applying = false
    if UpdateGlitter then UpdateGlitter() end
    return "ok"
end

local function QueueRefresh()
    if refreshQueued then return end
    refreshQueued = true
    local function run() refreshQueued = false; Addon:RefreshSparkle() end
    if C_Timer and C_Timer.After then C_Timer.After(0.5, run) else run() end
end

-- Aus den Optionen: Einstellung setzen, sofort anwenden, im Kampf Hinweis
function Addon:SetSparkleOption(key, value)
    self:SetSetting(key, value and true or false)
    if self:RefreshSparkle() == "combat" then
        print(L["SPARKLE_AFTER_COMBAT"])
    end
end

-- ------------------------------------------------------------
-- Teil 2: Erkennen, was gerade per Soft Targeting ausgewaehlt ist
-- ------------------------------------------------------------
-- WICHTIG (Live-Fund auf Forever, v1.13): Fuer Spielobjekte wie Kraeuter
-- liefert UnitExists("softinteract") false, obwohl das Spiel das Objekt
-- ausgewaehlt hat und sein Symbol zeigt. Blizzards eigener Code
-- (Blizzard_NamePlates.lua) fragt deshalb nie UnitExists, sondern geht ueber
-- die Namensplakette: Er vergleicht deren Einheit ("nameplateN") per
-- UnitIsUnit mit "softinteract" und holt das Symbol mit SetUnitCursorTexture
-- fuer genau diese Plaketten-Einheit. Emberstone macht es jetzt genauso.
local UNIT = "softinteract"
local probe -- unsichtbare Textur, in die der Client das Cursor-Symbol legt
local plateTokens = {} -- aktuell sichtbare Namensplaketten ("nameplateN")

local function PlateUnit(plate)
    if not plate then return nil end
    if plate.GetUnit then
        local ok, unit = pcall(plate.GetUnit, plate)
        if ok and type(unit) == "string" then return unit end
    end
    return plate.unitToken or plate.namePlateUnitToken
end

local function IsSoftTarget(unit)
    if not (UnitIsUnit and unit) then return false end
    local ok, same = pcall(UnitIsUnit, unit, UNIT)
    return ok and same == true
end

-- Sucht die Plaketten-Einheit des Soft-Target-Objekts. Rueckgabe: unit oder nil
local function FindSoftUnit()
    for token in pairs(plateTokens) do
        if IsSoftTarget(token) then return token end
    end
    -- Plaketten, die schon vor dem Laden da waren (z.B. nach /reload)
    if C_NamePlate and C_NamePlate.GetNamePlates then
        local ok, plates = pcall(C_NamePlate.GetNamePlates)
        if ok and type(plates) == "table" then
            for _, plate in ipairs(plates) do
                local token = PlateUnit(plate)
                if IsSoftTarget(token) then
                    plateTokens[token] = true
                    return token
                end
            end
        end
    end
    return nil
end

-- Ist die Einheit ein Spielobjekt (kein NPC/Spieler)? true/false/nil (unbekannt)
local function IsGameObjectUnit(unit)
    if UnitGUID then
        local ok, guid = pcall(UnitGUID, unit)
        if ok and type(guid) == "string" and not (issecretvalue and issecretvalue(guid)) then
            return guid:find("^GameObject") ~= nil
        end
    end
    if UnitIsGameObject then
        local ok, isObject = pcall(UnitIsGameObject, unit)
        if ok and type(isObject) == "boolean" then return isObject end
    end
    return nil
end

-- Welches Cursor-Symbol zeigt der Client fuer das Objekt? (Pfad oder ID)
local function CursorValue(unit)
    if not SetUnitCursorTexture or not UIParent then return nil end
    if not probe then
        probe = UIParent:CreateTexture(nil, "BACKGROUND")
        probe:SetSize(1, 1)
        probe:SetAlpha(0)
    end
    local ok, has = pcall(SetUnitCursorTexture, probe, unit)
    if not ok or not has then return nil end
    if probe.GetTextureFilePath then
        local okPath, path = pcall(probe.GetTextureFilePath, probe)
        if okPath and path ~= nil then return path end
    end
    local okTex, tex = pcall(probe.GetTexture, probe)
    return okTex and tex or nil
end

local function HasProfession(skillLine)
    if not (GetProfessions and GetProfessionInfo) then return true end -- unbekannt: nicht grau
    local ok, p1, p2 = pcall(GetProfessions)
    if not ok then return true end
    for _, index in pairs({ p1, p2 }) do
        local okInfo, _, _, _, _, _, _, line = pcall(GetProfessionInfo, index)
        if okInfo and line == skillLine then return true end
    end
    return false
end

-- Liefert eine Tabelle { unit, isObject, kind = "herb"|"ore"|"quest"|nil,
-- unable, noSkill, cursor }
function Addon:ClassifySoftInteract()
    local info = {}
    local unit = FindSoftUnit()
    info.unit = unit
    if not unit then return info end
    info.isObject = IsGameObjectUnit(unit)
    if info.isObject == false then return info end -- NPCs/Spieler nicht

    local cursor = CursorValue(unit)
    info.cursor = cursor
    local s = type(cursor) == "string" and cursor:lower() or ""
    info.unable = (s:find("unable", 1, true) or s:find("error", 1, true)) and true or false
    if s:find("mine", 1, true) or s:find("mining", 1, true) then
        info.kind = "ore"
    elseif s:find("herb", 1, true) or s:find("gather", 1, true) then
        info.kind = "herb"
    elseif s:find("quest", 1, true) then
        info.kind = "quest"
    end

    if not info.kind and C_QuestLog and C_QuestLog.UnitIsRelatedToActiveQuest then
        local ok, related = pcall(C_QuestLog.UnitIsRelatedToActiveQuest, unit)
        if ok and related == true then info.kind = "quest" end
    end

    if info.kind == "herb" then info.noSkill = not HasProfession(SKILL_HERBALISM) end
    if info.kind == "ore" then info.noSkill = not HasProfession(SKILL_MINING) end
    return info
end

local KIND_SETTING = { herb = "sparkleHerbs", ore = "sparkleOre", quest = "sparkleQuestObjects" }

-- Einheitlich warmes Gold fuer alle Arten; "hell, schwach, grau" ueber
-- Anzahl und Staerke der Funken (dezent: hoechstens 5).
local LOOKS = {
    bright = { name = "bright", r = 1.0, g = 0.82, b = 0.36, count = 5, strength = 1.0, shimmer = 0.5, grey = false },
    dim    = { name = "dim",    r = 1.0, g = 0.82, b = 0.36, count = 3, strength = 0.45, shimmer = 0.18, grey = false },
    grey   = { name = "grey",   r = 0.62, g = 0.62, b = 0.62, count = 4, strength = 0.6, shimmer = 0.22, grey = true },
}

-- Aussehen fuer eine Einordnung: nil = nicht zeigen, sonst ein Eintrag aus LOOKS
function Addon:GetSparkleLook(info)
    if not info or not info.kind then return nil end
    if not self:GetSetting(KIND_SETTING[info.kind]) then return nil end
    if info.noSkill then return LOOKS.grey end
    return info.unable and LOOKS.dim or LOOKS.bright
end

-- ------------------------------------------------------------
-- Teil 2: Die Glitzer-Grafik
-- ------------------------------------------------------------
local glitter
local RECHECK = 0.3
local MAX_POINTS = 5
-- Lage relativ zur Unterkante der Plakette (dort sitzt das Objekt in etwa).
-- Nach Rolands Bildern aus 5 und 20 Metern ggf. nachjustieren.
local ANCHOR_X, ANCHOR_Y = 0, 0
local AREA_W, AREA_H = 34, 14        -- halbe Breite/Hoehe des Funkel-Bereichs
local POINT_MIN, POINT_MAX = 14, 22  -- Groesse eines Funkens
local SHIMMER_W, SHIMMER_H = 96, 30  -- flacher Schimmer am Boden

local function AssetPath(file)
    return "Interface\\AddOns\\" .. ADDON_NAME .. "\\Assets\\" .. file
end

-- Ein Funke: blitzt auf, vergeht, taucht an neuer Stelle wieder auf
local function RespawnPoint(p, first)
    local angle = math.random() * 2 * math.pi
    local dist = math.sqrt(math.random())
    p.x = math.cos(angle) * dist * AREA_W
    p.y = math.sin(angle) * dist * AREA_H + 6
    p.size = POINT_MIN + math.random() * (POINT_MAX - POINT_MIN)
    p.duration = 0.9 + math.random() * 0.7
    p.age = first and -math.random() * 1.2 or -math.random() * 0.4 -- versetzt starten
    p:ClearAllPoints()
    p:SetPoint("CENTER", p:GetParent(), "CENTER", p.x, p.y)
end

local function BuildGlitter()
    if glitter or not UIParent then return glitter end
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetSize(2 * AREA_W + POINT_MAX, 2 * AREA_H + POINT_MAX + 12)
    f:SetFrameStrata("BACKGROUND")

    local shimmer = f:CreateTexture(nil, "BACKGROUND")
    shimmer:SetPoint("CENTER", f, "CENTER", 0, 0)
    shimmer:SetSize(SHIMMER_W, SHIMMER_H)
    shimmer:SetTexture(AssetPath("glow.tga"))
    shimmer:SetBlendMode("ADD")
    f.shimmer = shimmer

    f.points = {}
    for i = 1, MAX_POINTS do
        local p = f:CreateTexture(nil, "ARTWORK")
        p:SetTexture(AssetPath("sparkle.tga"))
        p:SetBlendMode("ADD")
        p:SetAlpha(0)
        RespawnPoint(p, true)
        f.points[i] = p
    end

    f.elapsed, f.sinceCheck = 0, 0
    f.look = nil -- wird beim ersten Anzeigen gesetzt (inkl. Farbe)
    f:Hide()
    -- Funkeln animieren; ausserdem regelmaessig neu einordnen (Reichweite
    -- aendert sich beim Laufen, ohne dass sich das Ziel aendert).
    f:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = self.elapsed + elapsed
        self.sinceCheck = self.sinceCheck + elapsed
        local look = self.look or LOOKS.bright
        self.shimmer:SetAlpha(look.shimmer * (0.85 + 0.15 * math.sin(self.elapsed * 2)))
        for i, p in ipairs(self.points) do
            if i > look.count then
                p:SetAlpha(0)
            else
                p.age = p.age + elapsed
                if p.age >= p.duration then RespawnPoint(p, false) end
                local t = p.age > 0 and (p.age / p.duration) or 0
                local s = math.sin(t * math.pi)
                p:SetAlpha(look.strength * s * s)
                local size = p.size * (0.7 + 0.3 * s)
                p:SetSize(size, size)
            end
        end
        if self.sinceCheck >= RECHECK then
            self.sinceCheck = 0
            UpdateGlitter()
        end
    end)
    glitter = f
    return f
end

local function SoftPlate(unit)
    if not (unit and C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return nil end
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    if ok then return plate end
    return nil
end

UpdateGlitter = function()
    local function hide() if glitter then glitter:Hide() end end
    if not GROUPS.soft.wanted() or Addon:GetSparkleConflict() or InCombat() then return hide() end

    local info = Addon:ClassifySoftInteract()
    local look = Addon:GetSparkleLook(info)
    if not look then return hide() end
    local plate = SoftPlate(info.unit)
    if not plate then return hide() end

    local f = BuildGlitter()
    if not f then return end
    f:ClearAllPoints()
    f:SetPoint("CENTER", plate, "BOTTOM", ANCHOR_X, ANCHOR_Y)
    if f.look ~= look then
        f.look = look
        f.shimmer:SetVertexColor(look.r, look.g, look.b)
        if f.shimmer.SetDesaturated then f.shimmer:SetDesaturated(look.grey) end
        for _, p in ipairs(f.points) do
            p:SetVertexColor(look.r, look.g, look.b)
            if p.SetDesaturated then p:SetDesaturated(look.grey) end
        end
    end
    f:Show()
end

-- ------------------------------------------------------------
-- Rueckfall von B auf C
-- ------------------------------------------------------------
-- Hat das Spiel ein Objekt ausgewaehlt (UnitGUID("softinteract") ist ein
-- GameObject - auf Forever bestaetigt), aber nach PLATE_WAIT Sekunden gibt
-- es immer noch keine Plakette dafuer, legt der Client ohne Symbol offenbar
-- keine an. Dann den alten Symbol-Wert zuruecksetzen und bei C bleiben.
local PLATE_WAIT = 2

local function SoftObjectGUID()
    if not UnitGUID then return nil end
    local ok, guid = pcall(UnitGUID, UNIT)
    if ok and type(guid) == "string" and not (issecretvalue and issecretvalue(guid))
        and guid:find("^GameObject") then
        return guid
    end
    return nil
end

function Addon:GetSparkleMode()
    if IsFallbackC() then return "C" end
    if CVarGet("SoftTargetNameplateSize") == nil then return "C" end -- CVar unbekannt
    return "B"
end

local function WatchModeB()
    return GROUPS.soft.wanted() and not IsFallbackC() and not Addon:GetSparkleConflict()
        and not InCombat() and CVarGet("SoftTargetNameplateSize") == "0"
end

function Addon:ActivateSparkleFallback()
    if IsFallbackC() then return end
    EmberstoneCommon.sparkleFallbackC = true
    local saved = SavedRoot().soft
    if saved and saved.SoftTargetNameplateSize ~= nil then
        applying = true
        CVarSet("SoftTargetNameplateSize", saved.SoftTargetNameplateSize)
        applying = false
        saved.SoftTargetNameplateSize = nil
    end
    print(L["SPARKLE_FALLBACK_NOTICE"])
    UpdateGlitter()
end

local function CheckPlateLater()
    if not WatchModeB() then return end
    local guid = SoftObjectGUID()
    if not guid then return end
    local function check()
        if not WatchModeB() then return end
        if SoftObjectGUID() ~= guid then return end -- inzwischen anderes Ziel
        if FindSoftUnit() then return end           -- Plakette da: B klappt
        Addon:ActivateSparkleFallback()
    end
    if C_Timer and C_Timer.After then C_Timer.After(PLATE_WAIT, check) end
end

-- Nur fuer Tests
Addon._sparkleGlitter = function() return glitter end

-- ------------------------------------------------------------
-- Ereignisse
-- ------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
for _, event in ipairs({
    "PLAYER_LOGIN", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "CVAR_UPDATE",
    "GX_RESTARTED", "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED",
    "PLAYER_SOFT_INTERACT_CHANGED",
}) do
    pcall(eventFrame.RegisterEvent, eventFrame, event)
end

eventFrame:SetScript("OnEvent", function(_, event, arg1, arg2)
    if not EmberstoneCommon then return end -- vor ADDON_LOADED
    if event == "PLAYER_LOGIN" or event == "GX_RESTARTED" then
        Addon:RefreshSparkle()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if pending then Addon:RefreshSparkle() else UpdateGlitter() end
    elseif event == "PLAYER_REGEN_DISABLED" then
        if glitter then glitter:Hide() end
    elseif event == "CVAR_UPDATE" then
        if applying or type(arg1) ~= "string" then return end
        if issecretvalue and (issecretvalue(arg1) or issecretvalue(arg2)) then return end
        local name = arg1:lower()
        local managed = MANAGED[name]
        if managed and managed.modeB and IsFallbackC() then
            return -- im Rueckfall C gehoert der Wert wieder dem Spieler
        elseif managed then
            -- Spieler oder Voreinstellung hat den Wert geaendert: diesen
            -- neuen Wert als "seinen" merken und unseren wieder setzen.
            local saved = SavedRoot()[managed.group]
            local value = arg2 ~= nil and tostring(arg2) or CVarGet(managed.name)
            if saved and value ~= nil and value ~= managed.value then
                saved[managed.name] = value
                QueueRefresh()
            end
        elseif PRESET_CVARS[name] then
            QueueRefresh()
        end
    else
        -- Namensplaketten / Soft-Target gewechselt
        if event == "NAME_PLATE_UNIT_ADDED" and type(arg1) == "string" then
            plateTokens[arg1] = true
        elseif event == "NAME_PLATE_UNIT_REMOVED" and type(arg1) == "string" then
            plateTokens[arg1] = nil
        end
        UpdateGlitter()
        if event == "PLAYER_SOFT_INTERACT_CHANGED" then CheckPlateLater() end
    end
end)

-- ------------------------------------------------------------
-- Befehl: /emberstone sparkle [debug|retry]
-- ------------------------------------------------------------
local function OnOff(v) return v and L["SPARKLE_STATE_ON"] or L["SPARKLE_STATE_OFF"] end

function Addon:HandleSparkleCommand(rest)
    local sub = self:Trim(rest):lower()
    if sub == "retry" then
        EmberstoneCommon.sparkleFallbackC = nil
        self:RefreshSparkle()
        print(L["SPARKLE_RETRY_DONE"])
        return
    end
    if sub == "debug" then
        local info = self:ClassifySoftInteract()
        local guid = info.unit and UnitGUID and select(2, pcall(UnitGUID, info.unit))
        local guidType = type(guid) == "string" and not (issecretvalue and issecretvalue(guid))
            and (guid:match("^([^%-]+)") or "?") or tostring(guid)
        local plateCount = 0
        for _ in pairs(plateTokens) do plateCount = plateCount + 1 end
        print(string.format(L["SPARKLE_DEBUG"],
            tostring(info.unit), guidType, tostring(info.isObject), tostring(info.cursor),
            tostring(info.kind), tostring(info.unable), tostring(info.noSkill),
            tostring(SoftPlate(info.unit) ~= nil), plateCount))
        print(string.format(L["SPARKLE_DEBUG_SETTINGS"],
            OnOff(self:GetSetting("sparkleHerbs")), OnOff(self:GetSetting("sparkleOre")),
            OnOff(self:GetSetting("sparkleQuestObjects")), tostring(CVarGet("softTargetInteract")),
            tostring(CVarGet("SoftTargetIconGameObject")), tostring(InCombat())))
        print(string.format(L["SPARKLE_DEBUG_MODE"],
            self:GetSparkleMode() == "B" and L["SPARKLE_MODE_B"] or L["SPARKLE_MODE_C"],
            tostring(CVarGet("SoftTargetNameplateSize"))))
        return
    end
    local conflict = self:GetSparkleConflict()
    print(string.format(L["SPARKLE_STATUS"],
        OnOff(self:GetSetting("sparkleQuestLoot")), OnOff(self:GetSetting("sparkleHerbs")),
        OnOff(self:GetSetting("sparkleOre")), OnOff(self:GetSetting("sparkleQuestObjects"))))
    if conflict then print(string.format(L["SPARKLE_CONFLICT"], conflict)) end
end
