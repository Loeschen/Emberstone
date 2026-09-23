-- features/AfkText.lua
--
-- Eigener AFK-Spruch statt nur "AFK".
--
-- Wird man (automatisch oder per /afk ohne Text) AFK gesetzt, bekommt jeder,
-- der einen anfluestert, vom Server die Antwort "<Name> ist AFK: AFK". Einen
-- eigenen Standardtext fuer das automatische AFK kann man in WoW nicht
-- einstellen. Deshalb setzt Emberstone das AFK direkt danach neu - mit einem
-- zufaelligen Spruch aus einer Liste, die man selbst bearbeiten kann. Das
-- entspricht "/afk <Spruch>". Wer einen anfluestert, bekommt dann
-- "<Name> ist AFK: <Spruch>".
--
-- Ablauf:
--   1. Systemmeldung "Ihr seid jetzt AFK: AFK" erkannt (nur der Standardtext;
--      ein eigenes "/afk Bin essen" bleibt unangetastet).
--   2. Kurz danach wird der Spruch gesetzt (Chat-Typ "AFK").
--   3. Da /afk den Status je nach Client umschaltet, wird nach 1,5 s
--      geprueft, ob man noch AFK ist - wenn nicht, einmal erneut setzen.
--   4. Die Zwischenmeldungen ("AFK: AFK", "nicht mehr AFK") werden im
--      eigenen Chatfenster ausgeblendet; sichtbar bleibt nur die mit dem
--      Spruch. Klappt das Setzen nicht, erscheint die Originalzeile doch
--      noch, samt kurzem Hinweis - es geht also nichts still verloren.
--
-- Rein kosmetisch: es wird nichts am Spielen automatisiert, man bleibt AFK,
-- bis man sich selbst bewegt. Standardmaessig AUS.
local ADDON_NAME, Addon = ...

local MAX_TEXT_BYTES = 200 -- genug fuer einen Spruch, Chatgrenze ist 255
local APPLY_DELAY = 0.3
local VERIFY_DELAY = 1.5
local SUPPRESS_WINDOW = 5

local DEFAULT_SAYINGS = {
    deDE = {
        "Ich nehme meine jährliche Dusche zu mir.",
        "Bin kurz Mana auffüllen. Also Kaffee.",
        "Der Kühlschrank hat nach mir gerufen.",
        "Suche gerade im echten Leben nach Loot.",
        "Erkunde das Gebiet \"Küche\".",
        "Repariere kurz meine Haltbarkeit. Also Snacks.",
        "Bin gleich wieder da. Vielleicht.",
    },
    enUS = {
        "Taking my annual shower.",
        "Refilling mana. Coffee, that is.",
        "The fridge called my name.",
        "Looting real life, brb.",
        "Exploring the zone \"Kitchen\".",
        "Repairing my durability. Snacks, that is.",
        "Back in a bit. Probably.",
    },
}

-- ------------------------------------------------------------
-- Einstellungen
-- ------------------------------------------------------------
function Addon:InitAfkText()
    if type(self:GetSetting("afkTextPool")) ~= "table" then
        local lang = (GetLocale and GetLocale() == "deDE") and "deDE" or "enUS"
        local pool = {}
        for _, s in ipairs(DEFAULT_SAYINGS[lang]) do table.insert(pool, s) end
        self:SetSetting("afkTextPool", pool)
    end
    if self:GetSetting("afkTextEnabled") == nil then
        self:SetSetting("afkTextEnabled", false)
    end
    self:InstallAfkChatFilter()
end

function Addon:GetAfkPool()
    local pool = self:GetSetting("afkTextPool")
    if type(pool) ~= "table" then
        pool = {}
        self:SetSetting("afkTextPool", pool)
    end
    return pool
end

-- ------------------------------------------------------------
-- Systemmeldungen erkennen (Blizzards eigene, uebersetzte Texte)
-- ------------------------------------------------------------
-- "Ihr seid jetzt AFK: %s" -> Lua-Muster mit einer Fangstelle
local function PatternFromFormat(fmt)
    if type(fmt) ~= "string" or not fmt:find("%%s") then return nil end
    local p = fmt:gsub("%%s", "\1")
    p = p:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
    p = p:gsub("\1", "(.+)")
    return "^" .. p .. "$"
end

local markedPatterns
local function MarkedPatterns()
    if markedPatterns then return markedPatterns end
    markedPatterns = {}
    local fromClient = PatternFromFormat(_G.MARKED_AFK_MESSAGE)
    if fromClient then table.insert(markedPatterns, fromClient) end
    -- Rueckfall, falls der Client den Text anders nennt
    table.insert(markedPatterns, "^Ihr seid jetzt AFK: (.+)$")
    table.insert(markedPatterns, "^You are now AFK: (.+)$")
    return markedPatterns
end

local function IsDefaultAfkText(text)
    if not text then return false end
    text = text:gsub("%.$", "")
    return text == "AFK" or text == _G.DEFAULT_AFK_MESSAGE or text == "Away from Keyboard"
        or text == "Abwesend"
end

-- Liefert den AFK-Text aus "Ihr seid jetzt AFK: <Text>", sonst nil.
local function AfkTextFromMessage(msg)
    if type(msg) ~= "string" then return nil end
    if issecretvalue and issecretvalue(msg) then return nil end
    for _, p in ipairs(MarkedPatterns()) do
        local text = msg:match(p)
        if text then return text end
    end
    return nil
end

local function IsClearedMessage(msg)
    if type(msg) ~= "string" then return false end
    if issecretvalue and issecretvalue(msg) then return false end
    if _G.CLEARED_AFK and msg == _G.CLEARED_AFK then return true end
    return msg == "Ihr werdet nicht mehr mit 'AFK' angezeigt." or msg == "You are no longer AFK."
end

local function InLockdown()
    return C_ChatInfo and C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() or false
end

-- ------------------------------------------------------------
-- Setzen
-- ------------------------------------------------------------
local state = {
    text = nil,          -- gerade gesetzter Spruch
    attempts = 0,
    confirmed = false,   -- Meldung mit unserem Spruch ist angekommen
    suppressUntil = 0,   -- bis dahin Zwischenmeldungen ausblenden
    original = nil,      -- Originalzeile, falls wir sie doch zeigen muessen
}

local function Now() return GetTime and GetTime() or 0 end

function Addon:CanReplaceAfk()
    return self:GetSetting("afkTextEnabled") and #self:GetAfkPool() > 0 and not InLockdown()
end

function Addon:PickAfkSaying()
    local pool = self:GetAfkPool()
    if #pool == 0 then return nil end
    return pool[math.random(#pool)]
end

local function SendAfk(text)
    local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
    if not send then return false end
    return (pcall(send, text, "AFK"))
end

local ApplyAfk -- Vorwaertsdeklaration

local function GiveUp()
    -- Nicht geklappt: die ausgeblendete Originalzeile doch noch zeigen
    if state.original then
        print("|cffffff00" .. state.original .. "|r")
    end
    print(Addon.L["AFK_FAILED"])
    state.text = nil
    state.suppressUntil = 0
end

local function Verify()
    if not state.text then return end
    local isAfk = UnitIsAFK and UnitIsAFK("player")
    if state.confirmed and isAfk then
        state.text = nil -- fertig
        return
    end
    if not isAfk and state.attempts < 2 then
        -- Der erste Befehl hat nur ausgeschaltet: noch einmal setzen
        ApplyAfk()
        return
    end
    if isAfk and not state.confirmed and state.attempts < 2 then
        ApplyAfk()
        return
    end
    GiveUp()
end

ApplyAfk = function()
    if not state.text then return end
    if InLockdown() then GiveUp() return end
    state.attempts = state.attempts + 1
    state.suppressUntil = Now() + SUPPRESS_WINDOW
    SendAfk(state.text)
    if C_Timer and C_Timer.After then
        C_Timer.After(VERIFY_DELAY, Verify)
    end
end

-- Aufgerufen fuer jede Systemmeldung (Events.lua-Mechanik in Core.lua:
-- Addon[event](Addon, ...))
function Addon:CHAT_MSG_SYSTEM(msg)
    local text = AfkTextFromMessage(msg)
    if not text then return end

    if state.text and text == state.text then
        state.confirmed = true
        return
    end

    if IsDefaultAfkText(text) and not state.text and self:CanReplaceAfk() then
        state.text = self:PickAfkSaying()
        state.attempts = 0
        state.confirmed = false
        state.original = msg
        state.suppressUntil = Now() + SUPPRESS_WINDOW
        if C_Timer and C_Timer.After then
            C_Timer.After(APPLY_DELAY, ApplyAfk)
        else
            ApplyAfk()
        end
    end
end

-- ------------------------------------------------------------
-- Zwischenmeldungen im eigenen Chat ausblenden
-- ------------------------------------------------------------
-- Der Filter entscheidet nur anhand der Meldung selbst (er laeuft einmal
-- je Chatfenster, die Reihenfolge zu CHAT_MSG_SYSTEM oben ist nicht fest).
local function AfkChatFilter(_, _, msg)
    if not Addon:GetSetting("afkTextEnabled") then return false end
    local text = AfkTextFromMessage(msg)
    if text then
        if IsDefaultAfkText(text) and Addon:CanReplaceAfk() then return true end
        return false
    end
    if IsClearedMessage(msg) and Now() < state.suppressUntil then return true end
    return false
end

local filterInstalled = false
function Addon:InstallAfkChatFilter()
    if filterInstalled then return end
    local add = _G.ChatFrame_AddMessageEventFilter
        or (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter)
    if add then
        filterInstalled = pcall(add, "CHAT_MSG_SYSTEM", AfkChatFilter)
    end
end

-- ------------------------------------------------------------
-- Bearbeiten und Befehle
-- ------------------------------------------------------------
local function ValidSaying(line)
    if not line or line == "" or #line > MAX_TEXT_BYTES then return false end
    if IsDefaultAfkText(line) then return false end -- wuerde sich selbst ausloesen
    if line:find("|", 1, true) then return false end -- keine Farb-/Link-Codes
    return true
end
Addon.ValidAfkSaying = ValidSaying

function Addon:ShowAfkEditor()
    self:ShowTextListEditor({
        title = Addon.L["AFK_EDITOR_TITLE"],
        hint = Addon.L["AFK_EDITOR_HINT"],
        lines = self:GetAfkPool(),
        validate = ValidSaying,
        badLinesMessage = function(bad) return string.format(Addon.L["AFK_EDITOR_BAD_LINES"], bad, MAX_TEXT_BYTES) end,
        save = function(lines)
            local pool = Addon:GetAfkPool()
            for i = #pool, 1, -1 do table.remove(pool, i) end
            for _, line in ipairs(lines) do table.insert(pool, line) end
        end,
    })
end

function Addon:HandleAfkCommand(rest)
    local sub, arg = (rest or ""):match("^%s*(%S*)%s*(.-)%s*$")
    sub = (sub or ""):lower()
    if sub == "on" then
        self:SetSetting("afkTextEnabled", true)
        print(Addon.L["AFK_ON"])
    elseif sub == "off" then
        self:SetSetting("afkTextEnabled", false)
        print(Addon.L["AFK_OFF"])
    elseif sub == "edit" then
        self:ShowAfkEditor()
    elseif sub == "add" then
        if ValidSaying(arg) then
            table.insert(self:GetAfkPool(), arg)
            print(Addon.L["GZMSG_SAVED"])
        else
            print(string.format(Addon.L["AFK_EDITOR_BAD_LINES"], "1", MAX_TEXT_BYTES))
        end
    elseif sub == "list" then
        local pool = self:GetAfkPool()
        if #pool == 0 then
            print(Addon.L["AFK_LIST_EMPTY"])
        else
            print(Addon.L["AFK_LIST_HEADER"])
            for i, s in ipairs(pool) do print(string.format("  %d. %s", i, s)) end
        end
    elseif sub == "test" then
        local s = self:PickAfkSaying()
        print(s and string.format(Addon.L["AFK_TEST"], s) or Addon.L["AFK_LIST_EMPTY"])
    else
        print(string.format(Addon.L["AFK_STATUS"],
            self:GetSetting("afkTextEnabled") and Addon.L["AFK_STATE_ON"] or Addon.L["AFK_STATE_OFF"],
            #self:GetAfkPool()))
        print(Addon.L["AFK_HELP"])
    end
end

-- Nur fuer Tests
Addon._afkState = state
Addon._afkPatternFromFormat = PatternFromFormat
