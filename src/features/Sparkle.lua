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
        MANAGED[cv.name:lower()] = { group = key, name = cv.name, value = cv.value }
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
local applying = false   -- eigene SetCVar-Aufrufe nicht als Spieleraenderung werten
local pending = false    -- im Kampf verschoben
local refreshQueued = false

local function ApplyGroup(key)
    local group = GROUPS[key]
    local root = SavedRoot()
    if group.wanted() then
        local saved = root[key] or {}
        for _, cv in ipairs(group.cvars) do
            local current = CVarGet(cv.name)
            if current ~= nil then -- unbekannte CVar: ueberspringen
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
local UNIT = "softinteract"
local probe -- unsichtbare Textur, in die der Client das Cursor-Symbol legt

-- Welches Cursor-Symbol zeigt der Client fuer das Objekt? (Pfad oder ID)
local function CursorValue()
    if not SetUnitCursorTexture or not UIParent then return nil end
    if not probe then
        probe = UIParent:CreateTexture(nil, "BACKGROUND")
        probe:SetSize(1, 1)
        probe:SetAlpha(0)
    end
    local ok, has = pcall(SetUnitCursorTexture, probe, UNIT)
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

-- Liefert eine Tabelle { kind = "herb"|"ore"|"quest"|nil, unable, noSkill, cursor }
function Addon:ClassifySoftInteract()
    local info = {}
    if not (UnitExists and UnitExists(UNIT)) then return info end
    if UnitIsGameObject then
        local ok, isObject = pcall(UnitIsGameObject, UNIT)
        if ok and not isObject then return info end
    end

    local cursor = CursorValue()
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
        local ok, related = pcall(C_QuestLog.UnitIsRelatedToActiveQuest, UNIT)
        if ok and related == true then info.kind = "quest" end
    end

    if info.kind == "herb" then info.noSkill = not HasProfession(SKILL_HERBALISM) end
    if info.kind == "ore" then info.noSkill = not HasProfession(SKILL_MINING) end
    return info
end

local KIND_SETTING = { herb = "sparkleHerbs", ore = "sparkleOre", quest = "sparkleQuestObjects" }
local KIND_COLOR = {
    herb = { 0.45, 1.0, 0.45 },
    ore = { 1.0, 0.72, 0.35 },
    quest = { 1.0, 0.88, 0.3 },
}
local ALPHA_BRIGHT, ALPHA_DIM, ALPHA_GREY = 1.0, 0.35, 0.55

-- Aussehen fuer eine Einordnung: nil = nicht zeigen, sonst r, g, b, alpha, grau
function Addon:GetSparkleLook(info)
    if not info or not info.kind then return nil end
    if not self:GetSetting(KIND_SETTING[info.kind]) then return nil end
    if info.noSkill then
        return 0.6, 0.6, 0.6, ALPHA_GREY, true
    end
    local c = KIND_COLOR[info.kind]
    return c[1], c[2], c[3], info.unable and ALPHA_DIM or ALPHA_BRIGHT, false
end

-- ------------------------------------------------------------
-- Teil 2: Die Glitzer-Grafik
-- ------------------------------------------------------------
local glitter
local RECHECK = 0.3

local function BuildGlitter()
    if glitter or not UIParent then return glitter end
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetSize(64, 64)
    f:SetFrameStrata("BACKGROUND")
    local tex = f:CreateTexture(nil, "ARTWORK")
    tex:SetPoint("CENTER")
    tex:SetSize(48, 48)
    tex:SetTexture("Interface\\AddOns\\" .. ADDON_NAME .. "\\Assets\\sparkle.tga")
    tex:SetBlendMode("ADD")
    f.tex = tex
    f.elapsed, f.sinceCheck, f.baseAlpha = 0, 0, 1
    f:Hide()
    -- Leichtes Pulsieren; ausserdem regelmaessig neu einordnen (Reichweite
    -- aendert sich beim Laufen, ohne dass sich das Ziel aendert).
    f:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = self.elapsed + elapsed
        self.sinceCheck = self.sinceCheck + elapsed
        local wave = math.sin(self.elapsed * 3)
        self.tex:SetSize(48 + 6 * wave, 48 + 6 * wave)
        self.tex:SetAlpha(self.baseAlpha * (0.8 + 0.2 * wave))
        if self.sinceCheck >= RECHECK then
            self.sinceCheck = 0
            UpdateGlitter()
        end
    end)
    glitter = f
    return f
end

local function SoftPlate()
    if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return nil end
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, UNIT)
    if ok then return plate end
    return nil
end

UpdateGlitter = function()
    local function hide() if glitter then glitter:Hide() end end
    if not GROUPS.soft.wanted() or Addon:GetSparkleConflict() or InCombat() then return hide() end

    local r, g, b, alpha, grey = Addon:GetSparkleLook(Addon:ClassifySoftInteract())
    if not r then return hide() end
    local plate = SoftPlate()
    if not plate then return hide() end

    local f = BuildGlitter()
    if not f then return end
    f:ClearAllPoints()
    f:SetPoint("CENTER", plate, "CENTER", 0, 0)
    f.tex:SetVertexColor(r, g, b)
    if f.tex.SetDesaturated then f.tex:SetDesaturated(grey) end
    f.baseAlpha = alpha
    f:Show()
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
        if managed then
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
        UpdateGlitter()
    end
end)

-- ------------------------------------------------------------
-- Befehl: /emberstone sparkle [debug]
-- ------------------------------------------------------------
local function OnOff(v) return v and L["SPARKLE_STATE_ON"] or L["SPARKLE_STATE_OFF"] end

function Addon:HandleSparkleCommand(rest)
    local sub = self:Trim(rest):lower()
    if sub == "debug" then
        local info = self:ClassifySoftInteract()
        print(string.format(L["SPARKLE_DEBUG"],
            tostring(UnitExists and UnitExists(UNIT) or false), tostring(info.cursor),
            tostring(info.kind), tostring(info.unable), tostring(info.noSkill)))
        return
    end
    local conflict = self:GetSparkleConflict()
    print(string.format(L["SPARKLE_STATUS"],
        OnOff(self:GetSetting("sparkleQuestLoot")), OnOff(self:GetSetting("sparkleHerbs")),
        OnOff(self:GetSetting("sparkleOre")), OnOff(self:GetSetting("sparkleQuestObjects"))))
    if conflict then print(string.format(L["SPARKLE_CONFLICT"], conflict)) end
end
