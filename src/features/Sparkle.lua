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
--   Kuerschnern (ab Werk AUS): haeutbare Leichen. Auf Forever geprueft: Die
--   Leiche ist "softinteract" (Creature-GUID, tot, Cursor
--   "Crosshair_Skin_64"), bekommt aber KEINE Namensplakette - ihre Lage auf
--   dem Bildschirm ist fuer Addons nicht abfragbar. Deshalb erscheint hier
--   ein Krallen-Leuchten an fester Stelle neben dem eigenen Charakter
--   (SkinHint weiter unten), nicht an der Leiche.
--   Aussehen (v1.13, Variante B): ein grosses, weich pulsierendes Leuchten
--   (additiv) an der Unterkante der Plakette, fuenf Farben zur Auswahl
--   (Standard: Gold), Blizzards schwebendes Symbol ausgeblendet.
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

local SKILL_HERBALISM, SKILL_MINING, SKILL_SKINNING = 182, 186, 393

local GROUPS = {
    loot = {
        cvars = LOOT_CVARS,
        wanted = function() return Addon:GetSetting("sparkleQuestLoot") and true or false end,
    },
    soft = {
        cvars = SOFT_CVARS,
        wanted = function()
            return (Addon:GetSetting("sparkleHerbs") or Addon:GetSetting("sparkleOre")
                or Addon:GetSetting("sparkleQuestObjects") or Addon:GetSetting("sparkleSkinning")) and true or false
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
-- keine Plakette fuer das Objekt anlegt. Gilt nur fuer diese Sitzung: beim
-- naechsten Login und nach RETRY_AFTER Sekunden wird B erneut versucht.
-- (Bis zur Testfassung vom 12.10.2026 wurde der Rueckfall dauerhaft
-- gespeichert und schon durch ein einziges Objekt ohne Plakette ausgeloest -
-- z.B. Deko-Objekte, die nie ein Symbol bekommen, oder ein Objekt ausserhalb
-- des Bildes. Siehe Rueckfall-Waechter weiter unten.)
local fallback = {
    active = false,      -- C aktiv
    confirmedB = false,  -- unter B wurde in dieser Sitzung schon eine Plakette gefunden
    failures = {},       -- GUIDs, die unter B ohne Plakette blieben
    failCount = 0,
    notified = false,    -- Chat-Hinweis nur einmal pro Sitzung
    retryAt = nil,
    quietUntil = 0,      -- nach Login/Ladebildschirm nicht werten
}

local function IsFallbackC()
    return fallback.active
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
local NoteBWorks   -- Vorwaertsdeklaration (Rueckfall-Waechter)
local UpdateSkinHint -- Vorwaertsdeklaration (Kuerschnern)

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
    local result = self:RefreshSparkle()
    if UpdateSkinHint then UpdateSkinHint() end
    if result == "combat" then
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

-- Art eines Objekts anhand des Cursor-Symbols (z.B. auf Forever
-- "Cursor Crosshair_GatherHerbs_64") bzw. der Quest-Zuordnung.
-- Rueckgabe: kind ("herb"|"ore"|"quest"|"skin"|nil), unable, cursor
local function KindOf(unit)
    local cursor = CursorValue(unit)
    local s = type(cursor) == "string" and cursor:lower() or ""
    local unable = (s:find("unable", 1, true) or s:find("error", 1, true)) and true or false
    local kind
    if s:find("skin", 1, true) then
        kind = "skin" -- haeutbare Leiche (Kuerschnerei)
    elseif s:find("mine", 1, true) or s:find("mining", 1, true) then
        kind = "ore"
    elseif s:find("herb", 1, true) or s:find("gather", 1, true) then
        kind = "herb"
    elseif s:find("quest", 1, true) then
        kind = "quest"
    end
    if not kind and C_QuestLog and C_QuestLog.UnitIsRelatedToActiveQuest then
        local ok, related = pcall(C_QuestLog.UnitIsRelatedToActiveQuest, unit)
        if ok and related == true then kind = "quest" end
    end
    return kind, unable, cursor
end

-- Liefert eine Tabelle { unit, isObject, kind = "herb"|"ore"|"quest"|nil,
-- unable, noSkill, cursor }
function Addon:ClassifySoftInteract()
    local info = {}
    local unit = FindSoftUnit()
    info.unit = unit
    if not unit then return info end
    info.isObject = IsGameObjectUnit(unit)
    if info.isObject == false then return info end -- NPCs/Leichen: siehe SkinHint
    info.kind, info.unable, info.cursor = KindOf(unit)
    if info.kind == "skin" then info.kind = nil end -- Kuerschnern nur ueber SkinHint
    if info.kind == "herb" then info.noSkill = not HasProfession(SKILL_HERBALISM) end
    if info.kind == "ore" then info.noSkill = not HasProfession(SKILL_MINING) end
    return info
end

local KIND_SETTING = { herb = "sparkleHerbs", ore = "sparkleOre", quest = "sparkleQuestObjects",
    skin = "sparkleSkinning" }

-- Haeutbare Leiche, unabhaengig von einer Plakette (die Leichen nicht haben).
-- Rueckgabe: { guid, dead, cursor, unable, noSkill, isSkin }
function Addon:GetSoftCorpseInfo()
    local info = {}
    if UnitGUID then
        local ok, guid = pcall(UnitGUID, UNIT)
        if ok and type(guid) == "string" and not (issecretvalue and issecretvalue(guid)) then
            info.guid = guid
        end
    end
    if not info.guid then return info end
    if UnitIsDead then
        local ok, dead = pcall(UnitIsDead, UNIT)
        info.dead = ok and dead == true
    end
    local kind, unable, cursor = KindOf(UNIT)
    info.cursor, info.unable = cursor, unable
    info.isSkin = kind == "skin" and info.dead == true and not info.guid:find("^GameObject")
    if info.isSkin then info.noSkill = not HasProfession(SKILL_SKINNING) end
    return info
end

-- "Hell, schwach, grau" - gilt fuer alle Farben. Die Farbe selbst kommt aus
-- der gewaehlten Variante, "grau" ersetzt sie.
local LOOKS = {
    bright = { name = "bright", strength = 1.0, scale = 1.0, grey = false },
    dim    = { name = "dim",    strength = 0.4, scale = 0.8, grey = false },
    grey   = { name = "grey",   strength = 0.6, scale = 0.9, grey = true },
}
local GREY_COLOR = { 0.7, 0.7, 0.7 }

-- Aussehen fuer eine Einordnung: nil = nicht zeigen, sonst ein Eintrag aus LOOKS
function Addon:GetSparkleLook(info)
    if not info or not info.kind then return nil end
    if not self:GetSetting(KIND_SETTING[info.kind]) then return nil end
    if info.noSkill then return LOOKS.grey end
    return info.unable and LOOKS.dim or LOOKS.bright
end

-- ------------------------------------------------------------
-- Teil 2: Das Leuchten (v1.13: fuenf Farben zur Auswahl)
-- ------------------------------------------------------------
-- Weiches magisches Leuchten mit additiver Ueberblendung (wie Effekte im
-- Spiel): ein grosser weicher Schein (glow.tga) und darueber ein heller
-- Kern mit feinen Lichtstrahlen (sparkle_glow.tga), beide selbst erstellt
-- und eingefaerbt, sanft pulsierend. Die Varianten unterscheiden sich nur
-- in der Farbe. Lage: relativ zur Unterkante der Namensplakette (dort sitzt
-- das Objekt in etwa); "y" schiebt das Leuchten nach unten zur Pflanze.
local SPARKLE_STYLES = {
    { id = "gold",   color = { 1.0, 0.78, 0.25 } },
    { id = "green",  color = { 0.35, 1.0, 0.35 } },
    { id = "arcane", color = { 0.35, 0.65, 1.0 } },
    { id = "white",  color = { 1.0, 1.0, 0.95 } },
    { id = "violet", color = { 0.78, 0.4, 1.0 } },
}
local STYLE_BY_ID = {}
for i, style in ipairs(SPARKLE_STYLES) do
    style.index = i
    STYLE_BY_ID[style.id] = style
end
Addon.SparkleStyles = SPARKLE_STYLES

local GLOW_SIZE = 110      -- Kern mit Strahlen (in Reichweite)
local HALO_SIZE = 150      -- weicher Schein dahinter
local GLOW_Y = -16         -- unter die Unterkante der Plakette, naeher an die Pflanze

local function AssetPath(file)
    return "Interface\\AddOns\\" .. ADDON_NAME .. "\\Assets\\" .. file
end
Addon.SparkleAssetPath = AssetPath

function Addon:GetSparkleStyle()
    return STYLE_BY_ID[self:GetSetting("sparkleStyle")] or SPARKLE_STYLES[1]
end

local glitter
local RECHECK = 0.3

-- Setzt das Leuchten (Kern "main", Schein "halo") fuer Zeitpunkt t, sanft
-- pulsierend. Wird auch fuer die Vorschau in den Optionen benutzt.
function Addon:DrawSparkle(main, halo, look, t, anchor, size, y)
    size = (size or GLOW_SIZE) * look.scale
    local wave = math.sin(t * 2.4)
    local k = 1 + 0.10 * wave
    main:SetSize(size * k, size * k)
    main:ClearAllPoints()
    main:SetPoint("CENTER", anchor, "CENTER", 0, y or GLOW_Y)
    main:SetAlpha(look.strength * (0.85 + 0.15 * wave))
    if halo then
        local hs = size * (HALO_SIZE / GLOW_SIZE) * (1 + 0.06 * wave)
        halo:SetSize(hs, hs)
        halo:ClearAllPoints()
        halo:SetPoint("CENTER", main, "CENTER", 0, 0)
        halo:SetAlpha(look.strength * (0.55 + 0.1 * wave))
    end
end

function Addon:ApplySparkleColors(main, halo, style, look)
    local c = look.grey and GREY_COLOR or style.color
    for _, tex in ipairs({ main, halo }) do
        tex:SetVertexColor(c[1], c[2], c[3])
        if tex.SetDesaturated then tex:SetDesaturated(look.grey) end
    end
end

local function NewGlowTextures(parent)
    local halo = parent:CreateTexture(nil, "BORDER")
    halo:SetTexture(AssetPath("glow.tga"))
    halo:SetBlendMode("ADD")
    local main = parent:CreateTexture(nil, "ARTWORK")
    main:SetTexture(AssetPath("sparkle_glow.tga"))
    main:SetBlendMode("ADD")
    return main, halo
end
Addon.NewSparkleTextures = NewGlowTextures

local function BuildGlitter()
    if glitter or not UIParent then return glitter end
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetSize(8, 8)
    f:SetFrameStrata("BACKGROUND")
    f.main, f.halo = NewGlowTextures(f)
    f.elapsed, f.sinceCheck = 0, 0
    f.look, f.style = nil, nil -- werden beim ersten Anzeigen gesetzt (inkl. Farbe)
    f:Hide()
    -- Pulsieren; ausserdem regelmaessig neu einordnen (Reichweite aendert
    -- sich beim Laufen, ohne dass sich das Ziel aendert).
    f:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = self.elapsed + elapsed
        self.sinceCheck = self.sinceCheck + elapsed
        if self.look then
            Addon:DrawSparkle(self.main, self.halo, self.look, self.elapsed, self)
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
    local function hide()
        if glitter then glitter:Hide() end
    end
    if not GROUPS.soft.wanted() or Addon:GetSparkleConflict() or InCombat() then return hide() end

    local info = Addon:ClassifySoftInteract()
    local look = Addon:GetSparkleLook(info)
    if not look then return hide() end
    local plate = SoftPlate(info.unit)
    if not plate then return hide() end
    NoteBWorks()

    local f = BuildGlitter()
    if not f then return end
    f:ClearAllPoints()
    f:SetPoint("CENTER", plate, "BOTTOM", 0, 0)
    local style = Addon:GetSparkleStyle()
    if f.look ~= look or f.style ~= style then
        f.look, f.style = look, style
        Addon:ApplySparkleColors(f.main, f.halo, style, look)
        Addon:DrawSparkle(f.main, f.halo, look, f.elapsed, f)
    end
    f:Show()
end

-- Farbe auswaehlen (Optionen, /emberstone sparkle style ...)
function Addon:SetSparkleStyle(id)
    local style = STYLE_BY_ID[id] or SPARKLE_STYLES[tonumber(id) or 0]
    if not style then return nil end
    self:SetSetting("sparkleStyle", style.id)
    UpdateGlitter()
    UpdateSkinHint()
    if self.SparklePanel and self.SparklePanel.Sync then self.SparklePanel.Sync() end
    return style
end

-- ------------------------------------------------------------
-- Kuerschnern: Krallen-Leuchten an fester Stelle neben dem Charakter
-- ------------------------------------------------------------
-- Leichen haben keine Plakette, deshalb kein Leuchten an der Leiche selbst.
-- Solange "softinteract" eine tote, haeutbare Leiche ist, pulsiert rechts
-- neben der Bildschirmmitte (dort steht bei normaler Kamera der eigene
-- Charakter) ein Krallen-Leuchten in der gewaehlten Farbe. Unauffaellig:
-- klein, rechts versetzt, hinter allen Fenstern, keine Toene.
local SKIN_HINT_X, SKIN_HINT_Y = 120, -40   -- von der Bildschirmmitte aus
local SKIN_HINT_SIZE = 56
local skinHint

local function BuildSkinHint()
    if skinHint or not UIParent then return skinHint end
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetSize(8, 8)
    f:SetFrameStrata("BACKGROUND")
    f:SetPoint("CENTER", UIParent, "CENTER", SKIN_HINT_X, SKIN_HINT_Y)
    local halo = f:CreateTexture(nil, "BORDER")
    halo:SetTexture(AssetPath("glow.tga"))
    halo:SetBlendMode("ADD")
    local main = f:CreateTexture(nil, "ARTWORK")
    main:SetTexture(AssetPath("sparkle_claw.tga"))
    main:SetBlendMode("ADD")
    f.main, f.halo = main, halo
    f.elapsed, f.sinceCheck = 0, 0
    f:Hide()
    f:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = self.elapsed + elapsed
        self.sinceCheck = self.sinceCheck + elapsed
        if self.look then
            Addon:DrawSparkle(self.main, self.halo, self.look, self.elapsed, self, SKIN_HINT_SIZE, 0)
        end
        if self.sinceCheck >= RECHECK then -- Reichweite aendert sich beim Laufen
            self.sinceCheck = 0
            UpdateSkinHint()
        end
    end)
    skinHint = f
    return f
end

UpdateSkinHint = function()
    local function hide() if skinHint then skinHint:Hide() end end
    if not Addon:GetSetting("sparkleSkinning") or Addon:GetSparkleConflict() or InCombat() then
        return hide()
    end
    local corpse = Addon:GetSoftCorpseInfo()
    if not corpse.isSkin then return hide() end
    local look = corpse.noSkill and LOOKS.grey or (corpse.unable and LOOKS.dim or LOOKS.bright)
    local f = BuildSkinHint()
    if not f then return end
    local style = Addon:GetSparkleStyle()
    if f.look ~= look or f.style ~= style then
        f.look, f.style = look, style
        Addon:ApplySparkleColors(f.main, f.halo, style, look)
        Addon:DrawSparkle(f.main, f.halo, look, f.elapsed, f, SKIN_HINT_SIZE, 0)
    end
    f:Show()
end

Addon._sparkleSkinHint = function() return skinHint end -- nur fuer Tests

-- ------------------------------------------------------------
-- Rueckfall von B auf C
-- ------------------------------------------------------------
-- Hat das Spiel ein Objekt ausgewaehlt (UnitGUID("softinteract") ist ein
-- GameObject - auf Forever bestaetigt), aber nach PLATE_WAIT Sekunden gibt
-- es immer noch keine Plakette dafuer, legt der Client ohne Symbol offenbar
-- keine an. Dann den alten Symbol-Wert zuruecksetzen und bei C bleiben.
local PLATE_WAIT = 2         -- erste Pruefung, zweite nach 2 * PLATE_WAIT
local FAILS_NEEDED = 3       -- so viele verschiedene Objekte ohne Plakette
local RETRY_AFTER = 600      -- Sekunden bis zum neuen Versuch mit B
local QUIET_AFTER_LOAD = 10  -- Sekunden nach Login/Ladebildschirm ohne Wertung

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

local function Now() return GetTime and GetTime() or 0 end

local function WatchModeB()
    return GROUPS.soft.wanted() and not IsFallbackC() and not fallback.confirmedB
        and not Addon:GetSparkleConflict() and not InCombat()
        and CVarGet("SoftTargetNameplateSize") == "0"
end

-- B neu versuchen (Login, nach RETRY_AFTER, /emberstone sparkle retry)
function Addon:RetrySparkleModeB()
    fallback.active = false
    fallback.confirmedB = false
    fallback.failures, fallback.failCount = {}, 0
    fallback.retryAt = nil
    return self:RefreshSparkle()
end

function Addon:ActivateSparkleFallback(lastKind, lastCursor)
    if IsFallbackC() then return end
    fallback.active = true
    local saved = SavedRoot().soft
    if saved and saved.SoftTargetNameplateSize ~= nil then
        applying = true
        CVarSet("SoftTargetNameplateSize", saved.SoftTargetNameplateSize)
        applying = false
        saved.SoftTargetNameplateSize = nil
    end
    -- Fuer /emberstone sparkle debug festhalten, wann und warum
    EmberstoneCommon.sparkleLastFallback = {
        time = time and time() or 0,
        objects = fallback.failCount,
        wait = 2 * PLATE_WAIT,
        kind = lastKind and tostring(lastKind) or "?",
        cursor = lastCursor and tostring(lastCursor) or "?",
    }
    fallback.retryAt = (time and time() or 0) + RETRY_AFTER
    if C_Timer and C_Timer.After then
        C_Timer.After(RETRY_AFTER, function()
            if fallback.active then Addon:RetrySparkleModeB() end
        end)
    end
    if not fallback.notified then
        fallback.notified = true
        print(L["SPARKLE_FALLBACK_NOTICE"])
    end
    UpdateGlitter()
end

-- Unter B: Ist ein Objekt ausgewaehlt, fuer das das Spiel ein Symbol zeigen
-- wuerde (Kraut, Erz, Questobjekt - am Cursor erkannt; Deko-Objekte ohne
-- Symbol zaehlen nicht), aber nach 2 und nach 4 Sekunden gibt es keine
-- Plakette, zaehlt das als Fehlversuch. Erst bei FAILS_NEEDED verschiedenen
-- Objekten - und nur, wenn in dieser Sitzung unter B noch nie eine Plakette
-- gefunden wurde - wird auf C umgeschaltet.
NoteBWorks = function()
    if not IsFallbackC() and CVarGet("SoftTargetNameplateSize") == "0" then
        fallback.confirmedB = true
    end
end

local function CheckPlateLater()
    if not WatchModeB() or Now() < fallback.quietUntil then return end
    local guid = SoftObjectGUID()
    if not guid or fallback.failures[guid] then return end
    if FindSoftUnit() then NoteBWorks() return end
    local kind, _, cursor = KindOf(UNIT)
    if not kind then return end -- Objekt ohne Symbol: sagt nichts ueber B
    if not (C_Timer and C_Timer.After) then return end
    local function still()
        if not WatchModeB() or SoftObjectGUID() ~= guid then return false end
        if FindSoftUnit() then NoteBWorks() return false end
        return true
    end
    C_Timer.After(PLATE_WAIT, function()
        if not still() then return end
        C_Timer.After(PLATE_WAIT, function()
            if not still() or fallback.failures[guid] then return end
            fallback.failures[guid] = true
            fallback.failCount = fallback.failCount + 1
            if fallback.failCount >= FAILS_NEEDED then
                Addon:ActivateSparkleFallback(kind, cursor)
            end
        end)
    end)
end

function Addon:GetSparkleFallbackState()
    return {
        active = fallback.active, confirmedB = fallback.confirmedB,
        failCount = fallback.failCount, needed = FAILS_NEEDED, retryAt = fallback.retryAt,
        last = EmberstoneCommon and EmberstoneCommon.sparkleLastFallback,
    }
end

-- Nur fuer Tests
Addon._sparkleGlitter = function() return glitter end

-- ------------------------------------------------------------
-- Ereignisse
-- ------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
for _, event in ipairs({
    "PLAYER_LOGIN", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "CVAR_UPDATE",
    "GX_RESTARTED", "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "PLAYER_ENTERING_WORLD",
    "PLAYER_SOFT_INTERACT_CHANGED",
}) do
    pcall(eventFrame.RegisterEvent, eventFrame, event)
end

eventFrame:SetScript("OnEvent", function(_, event, arg1, arg2)
    if not EmberstoneCommon then return end -- vor ADDON_LOADED
    if event == "PLAYER_LOGIN" then
        -- Rueckfall C wird nicht mehr dauerhaft gespeichert (Altlast der
        -- Testfassungen entfernen); B bei jedem Login neu versuchen.
        EmberstoneCommon.sparkleFallbackC = nil
        fallback.quietUntil = Now() + QUIET_AFTER_LOAD
        Addon:RetrySparkleModeB()
    elseif event == "PLAYER_ENTERING_WORLD" then
        fallback.quietUntil = Now() + QUIET_AFTER_LOAD
    elseif event == "GX_RESTARTED" then
        Addon:RefreshSparkle()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if pending then Addon:RefreshSparkle() else UpdateGlitter() end
        UpdateSkinHint()
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Feuert, bevor InCombatLockdown() greift: deshalb ausdruecklich aus
        if glitter then glitter:Hide() end
        if skinHint then skinHint:Hide() end
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
        if event == "PLAYER_SOFT_INTERACT_CHANGED" then
            UpdateSkinHint()
            CheckPlateLater()
        end
    end
end)

-- ------------------------------------------------------------
-- Befehl: /emberstone sparkle [debug|retry|style <Name oder 1-5>]
-- ------------------------------------------------------------
local function OnOff(v) return v and L["SPARKLE_STATE_ON"] or L["SPARKLE_STATE_OFF"] end

function Addon:HandleSparkleCommand(rest)
    local sub = self:Trim(rest):lower()
    local word, arg = sub:match("^(%S*)%s*(.-)$")
    if word == "style" then
        local style = self:SetSparkleStyle(arg)
        if style then
            print(string.format(L["SPARKLE_STYLE_SET"], L["SPARKLE_STYLE_" .. style.id:upper()]))
        else
            print(L["SPARKLE_STYLE_USAGE"])
        end
        return
    end
    if sub == "retry" then
        self:RetrySparkleModeB()
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
            OnOff(self:GetSetting("sparkleQuestObjects")), OnOff(self:GetSetting("sparkleSkinning")),
            tostring(CVarGet("softTargetInteract")),
            tostring(CVarGet("SoftTargetIconGameObject")), tostring(InCombat())))
        local corpse = self:GetSoftCorpseInfo()
        print(string.format(L["SPARKLE_DEBUG_SOFT"],
            tostring(corpse.guid), tostring(corpse.dead), tostring(corpse.cursor),
            tostring(corpse.isSkin == true), tostring(skinHint ~= nil and skinHint:IsShown())))
        print(string.format(L["SPARKLE_DEBUG_MODE"],
            self:GetSparkleMode() == "B" and L["SPARKLE_MODE_B"] or L["SPARKLE_MODE_C"],
            tostring(CVarGet("SoftTargetNameplateSize")),
            L["SPARKLE_STYLE_" .. self:GetSparkleStyle().id:upper()]))
        local fb = self:GetSparkleFallbackState()
        local dateFmt = L["DATE_FORMAT"] or "%Y-%m-%d %H:%M"
        local last = L["SPARKLE_FB_NEVER"]
        if type(fb.last) == "table" then
            last = string.format(L["SPARKLE_FB_LAST"], date(dateFmt, fb.last.time or 0),
                fb.last.objects or 0, fb.last.wait or 0, tostring(fb.last.kind), tostring(fb.last.cursor))
        end
        local nextTry = ""
        if fb.active then
            nextTry = string.format(L["SPARKLE_FB_NEXT"], fb.retryAt and date("%H:%M", fb.retryAt) or "?")
        end
        print(string.format(L["SPARKLE_DEBUG_FALLBACK"],
            fb.confirmedB and L["SPARKLE_STATE_ON"] or L["SPARKLE_STATE_OFF"],
            fb.failCount, fb.needed, last, nextTry))
        return
    end
    local conflict = self:GetSparkleConflict()
    print(string.format(L["SPARKLE_STATUS"],
        OnOff(self:GetSetting("sparkleQuestLoot")), OnOff(self:GetSetting("sparkleHerbs")),
        OnOff(self:GetSetting("sparkleOre")), OnOff(self:GetSetting("sparkleQuestObjects")),
        OnOff(self:GetSetting("sparkleSkinning"))))
    if conflict then print(string.format(L["SPARKLE_CONFLICT"], conflict)) end
end
