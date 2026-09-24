-- Nachgebaute WoW-API (nur das, was Emberstone benutzt) fuer Tests mit Lua 5.1.
-- Vorbild ist Blizzards UI-Quellcode 12.1.0 (Gethe/wow-ui-source, Zweig live).
--
-- Profil "retail"  = voller Client inkl. Deprecated-Fallbacks.
-- Profil "forever" = moderner Client, aber OHNE Deprecated-Fallbacks (CVar
--                    loadDeprecationFallbacks aus) und ohne Delve-/PvP-
--                    Wertungsfunktionen. Das ist eine vorsichtige ANNAHME,
--                    nicht im Forever-Client nachgemessen.
local M = {}

M.printed = {}
M.sent = {}          -- SendChatMessage-Aufrufe
M.addonMsgs = {}
M.raidNotices = {}
M.screenshots = 0
M.timers = {}
M.now = 1000
M.cvars = { screenshotQuality = "8" }
M.cursor = { 0, 0 }
M.openedCategory = nil
M.roster = {}        -- { {name=, level=, online=, guid=} }
M.errors = {}        -- was an geterrorhandler() ging

function M.reset(profile, locale)
    for k in pairs(M.printed) do M.printed[k] = nil end
    M.sent, M.addonMsgs, M.raidNotices, M.timers = {}, {}, {}, {}
    M.screenshots, M.now, M.openedCategory, M.roster = 0, 1000, nil, {}
    M.errors, M.inCombat, M.lockdown, M.chatFilter = {}, false, false, nil
    M.cvars = { screenshotQuality = "8" }
    M.profile, M.locale = profile or "retail", locale or "deDE"
    M.install()
end

-- ---------------- Frames ----------------
local frameMT = {}
frameMT.__index = function(t, k)
    local v = rawget(frameMT, k)
    if v then return v end
    if type(k) == "string" and k:sub(1, 1) == "_" then return nil end
    -- unbekannte Methoden: harmloser Leerlauf (wie ein vorhandener, aber
    -- fuer den Test unwichtiger Aufruf)
    return function() end
end
local function NewFrame(ftype, name, parent)
    local f = setmetatable({ _type = ftype, _name = name, _parent = parent, _scripts = {},
        _events = {}, _shown = true, _points = {}, _w = 0, _h = 0 }, frameMT)
    if name then _G[name] = f end
    if ftype == "CheckButton" then f.Text = NewFrame("FontString") end
    return f
end
M.NewFrame = NewFrame
function frameMT:SetScript(s, fn) self._scripts[s] = fn end
function frameMT:GetScript(s) return self._scripts[s] end
function frameMT:RegisterEvent(e)
    if M.unknownEvents and M.unknownEvents[e] then error("unknown event " .. e) end
    self._events[e] = true
end
function frameMT:RegisterUnitEvent(e, u) self._events[e] = u end
function frameMT:UnregisterEvent(e) self._events[e] = nil end
function frameMT:Show() self._shown = true end
function frameMT:Hide() self._shown = false end
function frameMT:IsShown() return self._shown end
function frameMT:SetShown(s) self._shown = s and true or false end
function frameMT:SetSize(w, h) self._w, self._h = w, h end
function frameMT:SetWidth(w) self._w = w end
function frameMT:GetWidth() return self._w end
function frameMT:ClearAllPoints() self._points = {} end
function frameMT:SetPoint(...) table.insert(self._points, { ... }) end
function frameMT:GetParent() return self._parent end
function frameMT:CreateTexture() return NewFrame("Texture") end
function frameMT:CreateFontString() return NewFrame("FontString") end
function frameMT:SetText(t) self._text = t end
function frameMT:GetText() return self._text end
function frameMT:SetChecked(c) self._checked = c end
function frameMT:GetChecked() return self._checked end
function frameMT:GetFrameLevel() return 2 end
function frameMT:GetEffectiveScale() return 1 end
function frameMT:GetCenter() return self._cx or 500, self._cy or 500 end
function frameMT:Fire(event, ...)
    local fn = self._scripts.OnEvent
    if fn and self._events[event] then fn(self, event, ...) end
end

M.allFrames = {}
local function CreateFrame(ftype, name, parent, template)
    local f = NewFrame(ftype, name, parent)
    table.insert(M.allFrames, f)
    return f
end

function M.FireEvent(event, ...)
    for _, f in ipairs(M.allFrames) do f:Fire(event, ...) end
end

-- ---------------- Timer ----------------
local function schedule(delay, fn, repeating)
    local t = { at = M.now + delay, fn = fn, every = repeating and delay or nil }
    function t:Cancel() self.cancelled = true end
    table.insert(M.timers, t)
    return t
end
function M.advance(sec)
    local target = M.now + sec
    while true do
        table.sort(M.timers, function(a, b) return a.at < b.at end)
        local t = M.timers[1]
        if not t or t.at > target then break end
        table.remove(M.timers, 1)
        M.now = t.at
        if not t.cancelled then
            t.fn(t)
            if t.every and not t.cancelled then t.at = M.now + t.every; table.insert(M.timers, t) end
        end
    end
    M.now = target
end

-- ---------------- Install ----------------
function M.install()
    M.allFrames = {}
    _G.EmberstoneMinimapButton, _G.EmberstoneGZPoolEditor = nil, nil
    _G.print = function(...)
        local parts = {}
        for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
        table.insert(M.printed, table.concat(parts, " "))
    end
    _G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
    _G.tinsert = table.insert
    _G.date = os.date
    _G.time = os.time
    _G.GetTime = function() return M.now end
    _G.GetLocale = function() return M.locale end
    _G.CreateFrame = CreateFrame
    _G.UIParent = NewFrame("Frame", "UIParent")
    _G.Minimap = NewFrame("Minimap", "Minimap"); Minimap._w = 140
    _G.GameTooltip = NewFrame("GameTooltip", "GameTooltip")
    _G.RaidWarningFrame = NewFrame("Frame", "RaidWarningFrame")
    _G.ChatFontNormal = {}
    _G.UISpecialFrames = {}
    _G.OKAY, _G.CANCEL = "Okay", "Abbrechen"
    _G.StaticPopupDialogs = {}
    _G.StaticPopup_Show = function(which) M.lastPopup = which end
    _G.SlashCmdList = {}
    _G.GetCursorPosition = function() return M.cursor[1], M.cursor[2] end
    _G.GetMinimapShape = nil
    _G.C_Timer = {
        After = function(d, fn) schedule(d, fn) end,
        NewTimer = function(d, fn) return schedule(d, fn) end,
        NewTicker = function(d, fn) return schedule(d, fn, true) end,
    }
    _G.Screenshot = function() M.screenshots = M.screenshots + 1 end
    _G.GetCVar = function(k) return M.cvars[k] end
    _G.SetCVar = function(k, v) M.cvars[k] = v end
    _G.UnitName = function(u) if u == "player" then return M.playerName or "Anna Müller" end end
    _G.UnitGUID = function(u) if u == "player" then return "Player-1-0001" end end
    _G.UnitIsAFK = function() return false end
    _G.UnitExists = function() return false end
    _G.UnitIsDead = function() return false end
    _G.UnitClassification = function() return "normal" end
    _G.UnitFactionGroup = function() return "Alliance" end
    _G.IsInGuild = function() return true end
    _G.GetGuildInfo = function() return "Glutwacht", "Mitglied", 3, nil end
    _G.GetNormalizedRealmName = function() return "Forever" end
    _G.GetNumGuildMembers = function() return #M.roster end
    _G.GetGuildRosterInfo = function(i)
        local m = M.roster[i]
        if not m then return nil end
        return m.name, "Rang", 1, m.level, "Krieger", "Zone", "", "", m.online ~= false,
            0, "WARRIOR", 0, 0, false, false, 0, m.guid
    end
    _G.C_GuildInfo = { GuildRoster = function() M.rosterRequests = (M.rosterRequests or 0) + 1 end }
    _G.C_ChatInfo = {
        SendChatMessage = function(msg, chan, lang, target)
            if #msg > 255 then error("message too long") end
            table.insert(M.sent, { msg = msg, channel = chan, target = target })
        end,
        SendAddonMessage = function(p, msg, chan) table.insert(M.addonMsgs, { p, msg, chan }) end,
        RegisterAddonMessagePrefix = function() return true end,
        InChatMessagingLockdown = function() return M.lockdown or false end,
    }
    _G.ChatFrameUtil = { AddMessageEventFilter = function(e, fn) M.chatFilter = fn end }
    _G.issecretvalue = function() return false end
    _G.InCombatLockdown = function() return M.inCombat end
    _G.geterrorhandler = function() return function(err) table.insert(M.errors, tostring(err)) end end
    -- Ambiguate(name, "guild"): Realm weglassen, wenn es der eigene ist
    _G.Ambiguate = function(name, context)
        local own = "-" .. GetNormalizedRealmName()
        if context == "guild" and name:sub(-#own) == own then return name:sub(1, -#own - 1) end
        return name
    end

    -- Settings-API (so wie in 12.1 Blizzard_Settings.lua)
    local id = 0
    local function newCat(name) id = id + 1; return { ID = id, name = name, settings = {} }, { AddInitializer = function() end } end
    _G.Settings = {
        VarType = { Boolean = "boolean", Number = "number" },
        RegisterVerticalLayoutCategory = function(name) return newCat(name) end,
        RegisterVerticalLayoutSubcategory = function(parent, name) return newCat(name) end,
        RegisterCanvasLayoutSubcategory = function(parent, frame, name) return newCat(name) end,
        RegisterAddOnCategory = function() end,
        RegisterProxySetting = function(cat, variable, vtype, name, default, get, set)
            local s = { variable = variable, get = get, set = set, default = default }
            function s:GetValue() return self.get() end
            function s:SetValue(v) self.set(v) end
            cat.settings[variable] = s
            return s
        end,
        CreateCheckbox = function() end,
        CreateSliderOptions = function() return { SetLabelFormatter = function() end } end,
        CreateSlider = function() end,
        OpenToCategory = function(catID) M.openedCategory = catID end,
    }
    _G.CreateSettingsListSectionHeaderInitializer = function(t) return { text = t } end
    _G.MinimalSliderWithSteppersMixin = { Label = { Right = 1 } }

    _G.RaidWarningUtil = { AddMessage = function(text) table.insert(M.raidNotices, text) end }
    if M.profile == "retail" then
        _G.RaidNotice_AddMessage = function(frame, text) table.insert(M.raidNotices, "ALT:" .. text) end
        _G.C_PartyInfo = { IsDelveInProgress = function() return false end, IsDelveComplete = function() return false end }
        _G.C_PvP = { IsArena = function() return false end, IsBattleground = function() return false end,
            IsRatedArena = function() return false end, IsRatedBattleground = function() return false end,
            IsMatchFactional = function() return false end }
        _G.GetBattlefieldArenaFaction = function() return 1 end
    else
        -- "forever": Deprecated-Fallbacks aus (CVar loadDeprecationFallbacks=0),
        -- keine Delve-/PvP-Wertungsfunktionen
        _G.RaidNotice_AddMessage = nil
        _G.C_PartyInfo = {}
        _G.C_PvP = { IsArena = function() return false end, IsBattleground = function() return false end }
        _G.GetBattlefieldArenaFaction = nil
    end
    _G.EmberstoneCommon, _G.EmberstoneCharacter = nil, nil
end

-- Emberstone laden (Reihenfolge aus der .toc)
function M.LoadAddon(root)
    local toc = io.open(root .. "/Emberstone.toc"):read("*a")
    local Addon = {}
    for line in toc:gmatch("[^\r\n]+") do
        if line:match("^src/.+%.lua$") then
            local chunk = assert(loadfile(root .. "/" .. line))
            chunk("Emberstone", Addon)
        end
    end
    return Addon
end

return M
