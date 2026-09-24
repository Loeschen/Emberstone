-- guildding.lua
--
-- Ehemals das eigenstaendige Addon "GrindDing": beobachtet NICHT den
-- eigenen Charakter (das macht Screenshots.lua/Events.lua), sondern das
-- gesamte Online-Gilden-Roster, und meldet Levelaufstiege ANDERER
-- Mitglieder per Chat und/oder Bildschirmmeldung. Jetzt vollstaendig in
-- Emberstone integriert, damit die Gilde nur noch ein Addon installieren muss.
local ADDON_NAME, Addon = ...

-- Zerlegt "Name-Realm" in Name und Realm. Als Realm gilt NUR der Teil nach
-- dem LETZTEN Bindestrich, und nur, wenn er keine Leerzeichen enthaelt
-- (Realm-Namen im Roster sind ohne Leerzeichen). So bleiben Forever-Namen
-- wie "Anne-Marie Schmidt" heil; nur "Anne-Marie Schmidt-Realm" verliert
-- den Realm. Grenzfall: ein Name ohne Leerzeichen und ohne Realm, aber mit
-- Bindestrich ("Anne-Marie") ist davon nicht zu unterscheiden - Namen aus
-- dem Roster tragen den Realm aber immer mit.
function Addon:SplitRealm(name)
    if not name then return nil end
    local base, realm = name:match("^(.+)%-([^%-]+)$")
    if base and not realm:find("%s") then
        return base, realm
    end
    return name, nil
end

-- Normalisiert Rosternamen: schneidet einen "-Realm"-Anhang ab, damit
-- derselbe Spieler nicht unter zwei verschiedenen Schluesseln landet.
function Addon:NormalizeName(name)
    return (self:SplitRealm(name))
end

-- Anzeigename wie in Blizzards Gildenchat: Realm nur, wenn noetig
-- (Ambiguate). Wie Ambiguate mit Bindestrichen IM Namen umgeht, ist nicht
-- dokumentiert - deshalb wird sein Ergebnis nur uebernommen, wenn es der
-- volle Name oder der Name ohne Realm nach unserer eigenen Regel ist.
-- Sonst bleibt es beim vollen Namen (nie ein verstuemmelter Name).
function Addon:DisplayName(name)
    if not name then return nil end
    if Ambiguate then
        local ok, short = pcall(Ambiguate, name, "guild")
        if ok and type(short) == "string" and (short == name or short == self:NormalizeName(name)) then
            return short
        end
    end
    return name
end

-- ============================================================
-- Ignorierliste: Spieler, fuer die GuildDing UEBERHAUPT KEINE Meldung
-- erzeugen soll - weder die lokale Chat-/Bildschirmanzeige noch den
-- automatischen Gildenchat-Glueckwunsch noch das Anflstern. Gedacht fuer
-- Leute, die das nicht moechten, oder die man schlicht nicht bedenken
-- will. Der Level-Cache (EmberstoneCommon.guildLevels) wird fuer
-- ignorierte Spieler trotzdem ganz normal weitergefuehrt - sonst wuerde
-- ein spaeteres Entfernen aus der Liste alle in der Zwischenzeit
-- "verpassten" Levelaufstiege auf einen Schlag nachmelden.
-- ============================================================
function Addon:GetIgnoreList()
    EmberstoneCommon.guildDingIgnoreList = EmberstoneCommon.guildDingIgnoreList or {}
    return EmberstoneCommon.guildDingIgnoreList
end

-- Passt ein gespeicherter bzw. eingetippter Name zu einem (Roster-)Namen?
-- Treffer, wenn er dem vollen Namen oder dem Namen ohne Realm entspricht.
-- Der gespeicherte Name selbst wird bewusst NICHT normalisiert: ein von
-- Hand eingetippter Doppelname ohne Realm ("Anna Schmidt-Weber") sieht
-- sonst aus wie "Anna Schmidt" mit Realm "Weber".
function Addon:NameMatches(stored, fullName)
    if type(stored) ~= "string" or type(fullName) ~= "string" then return false end
    stored = self:Trim(stored):lower()
    fullName = self:Trim(fullName)
    if stored == "" then return false end
    return stored == fullName:lower() or stored == self:NormalizeName(fullName):lower()
end

function Addon:FindIgnoreIndex(name)
    if not name then return nil end
    for i, entry in ipairs(self:GetIgnoreList()) do
        -- Trim (in NameMatches) auch fuer aeltere Eintraege mit Leerzeichen am Ende
        if self:NameMatches(entry, name) or self:NameMatches(name, entry) then
            return i
        end
    end
    return nil
end

function Addon:IsIgnored(name)
    return self:FindIgnoreIndex(name) ~= nil
end

function Addon:AddIgnore(name)
    name = self:Trim(name)
    if name == "" then return false end
    -- Schon abgedeckt? ("Max" deckt "Max-Realm" ab, aber nicht umgekehrt)
    for _, entry in ipairs(self:GetIgnoreList()) do
        if self:NameMatches(entry, name) then return false end
    end
    table.insert(self:GetIgnoreList(), name)
    return true
end

function Addon:RemoveIgnore(name)
    local idx = self:FindIgnoreIndex(name)
    if not idx then return false end
    table.remove(self:GetIgnoreList(), idx)
    return true
end

-- ============================================================
-- Level-up-Protokoll: haelt (begrenzt) fest, wer wann welches Level
-- erreicht hat - beantwortet auch im Nachhinein "wer hat wann Level 60
-- erreicht?", nicht nur im Moment des Levelaufstiegs selbst. Ignorierte
-- Spieler (siehe oben) werden bewusst NICHT protokolliert, aus demselben
-- Grund, aus dem sie auch keine Meldung erhalten.
-- ============================================================
local MAX_LOG_ENTRIES = 500

function Addon:GetDingLog()
    EmberstoneCommon.guildDingLog = EmberstoneCommon.guildDingLog or {}
    return EmberstoneCommon.guildDingLog
end

function Addon:AddDingLogEntry(name, level)
    local log = self:GetDingLog()
    table.insert(log, { name = self:NormalizeName(name), level = level, time = time() })
    while #log > MAX_LOG_ENTRIES do
        table.remove(log, 1)
    end
end

local function FormatLogTime(t)
    return date(Addon.L["DATE_FORMAT"] or "%Y-%m-%d %H:%M", t)
end

local function PrintLogEntry(entry)
    print(string.format(Addon.L["LOG_ENTRY_LINE"], entry.name, entry.level, FormatLogTime(entry.time)))
end

-- Aufgerufen von Commands.lua bei "/emberstone log ...".
function Addon:HandleLogCommand(rest)
    rest = rest or ""
    local sub, arg = rest:match("^(%S*)%s*(.-)$")
    sub = (sub or ""):lower()
    arg = self:Trim(arg)
    local log = self:GetDingLog()

    if sub == "level" then
        local levelNum = tonumber(arg)
        if not levelNum then
            print(Addon.L["LOG_LEVEL_USAGE"])
            return
        end
        local found = false
        for _, entry in ipairs(log) do
            if entry.level == levelNum then
                found = true
                PrintLogEntry(entry)
            end
        end
        if not found then
            print(string.format(Addon.L["LOG_LEVEL_EMPTY"], levelNum))
        end
    elseif sub == "player" then
        if arg == "" then
            print(Addon.L["LOG_PLAYER_USAGE"])
            return
        end
        -- entry.name ist schon ohne Realm. Genau passende Eintraege gehen
        -- vor; nur wenn es keine gibt, wird ein Realm-Anhang der Eingabe
        -- abgeschnitten ("Anna Schmidt-Weber" soll nicht "Anna Schmidt" finden).
        local function Collect(target)
            local hits = {}
            for _, entry in ipairs(log) do
                if type(entry.name) == "string" and entry.name:lower() == target:lower() then
                    table.insert(hits, entry)
                end
            end
            return hits
        end
        local hits = Collect(arg)
        if #hits == 0 then hits = Collect(self:NormalizeName(arg)) end
        local found = #hits > 0
        for _, entry in ipairs(hits) do
            PrintLogEntry(entry)
        end
        if not found then
            print(string.format(Addon.L["LOG_PLAYER_EMPTY"], arg))
        end
    elseif sub == "clear" then
        wipe(log)
        print(Addon.L["LOG_CLEARED"])
    elseif sub == "" then
        if #log == 0 then
            print(Addon.L["LOG_EMPTY"])
            return
        end
        print(Addon.L["LOG_RECENT_HEADER"])
        local startIdx = math.max(1, #log - 9)
        for i = startIdx, #log do
            PrintLogEntry(log[i])
        end
    else
        print(Addon.L["LOG_HELP"])
    end
end

-- Aufgerufen von Commands.lua bei "/emberstone ignore ...".
function Addon:HandleIgnoreCommand(rest)
    rest = rest or ""
    local sub, name = rest:match("^(%S*)%s*(.-)$")
    sub = (sub or ""):lower()
    name = self:Trim(name)

    if sub == "add" then
        if name == "" then
            print(Addon.L["IGNORE_ADD_USAGE"])
            return
        end
        if self:AddIgnore(name) then
            print(string.format(Addon.L["IGNORE_ADD_DONE"], name))
        else
            print(string.format(Addon.L["IGNORE_ADD_EXISTS"], name))
        end
    elseif sub == "remove" then
        if name == "" then
            print(Addon.L["IGNORE_REMOVE_USAGE"])
            return
        end
        if self:RemoveIgnore(name) then
            print(string.format(Addon.L["IGNORE_REMOVE_DONE"], name))
        else
            print(string.format(Addon.L["IGNORE_REMOVE_NOT_FOUND"], name))
        end
    elseif sub == "list" then
        local list = self:GetIgnoreList()
        if #list == 0 then
            print(Addon.L["IGNORE_LIST_EMPTY"])
            return
        end
        print(Addon.L["IGNORE_LIST_HEADER"])
        for _, entry in ipairs(list) do
            print("  - " .. entry)
        end
    else
        print(Addon.L["IGNORE_HELP"])
    end
end

-- Kompatibilitaets-Wrapper (gleiches Vorsichtsprinzip wie beim GetItemInfo-
-- Fix in GrindLedger): bevorzugt die namespaced Variante, faellt aber auf
-- das alte globale GuildRoster() zurueck, falls C_GuildInfo nicht existiert.
function Addon:RequestGuildRosterUpdate()
    if C_GuildInfo and C_GuildInfo.GuildRoster then
        C_GuildInfo.GuildRoster()
    elseif GuildRoster then
        GuildRoster()
    end
end

-- Bildschirmmeldung: zuerst die aktuelle API (RaidWarningUtil.AddMessage).
-- RaidNotice_AddMessage gibt es seit 12.x nur noch als "Deprecated"-Huelle,
-- die nur mit der CVar loadDeprecationFallbacks geladen wird und mit der
-- naechsten Erweiterung wegfallen soll - deshalb nur noch als Rueckfall.
local function SafeRaidNotice(text, r, g, b)
    local color = { r = r, g = g, b = b }
    if RaidWarningUtil and RaidWarningUtil.AddMessage then
        if pcall(RaidWarningUtil.AddMessage, text, color) then return end
    end
    if RaidNotice_AddMessage and RaidWarningFrame then
        pcall(RaidNotice_AddMessage, RaidWarningFrame, text, color)
    end
end

-- Baut einen anklickbaren Spielernamen fuers Chat-Fenster: der Standard-
-- Hyperlink-Typ "player" ist derselbe Mechanismus, ueber den auch normale
-- Spielernamen in Gilden-/Gruppenchat klickbar sind (Fluestern, Einladen,
-- Freund hinzufuegen, ...) - Blizzards Standard-Chatfenster erkennt und
-- verarbeitet |Hplayer:...|h automatisch, dafuer ist kein zusaetzlicher
-- Klick-Handler noetig. Betrifft NUR die Chat-Zeile - die Bildschirm-
-- Meldung (RaidWarningFrame) unterstuetzt grundsaetzlich keine Hyperlinks
-- und bleibt bewusst reiner Text.
local function PlayerLink(name)
    return string.format("|cFFFFD100|Hplayer:%s|h[%s]|h|r", name, Addon:DisplayName(name))
end

-- ============================================================
-- Automatische Gratulation (auf Wunsch ergaenzt): schreibt tatsaechlich
-- eine Chat-Nachricht in den Gildenchat und/oder fluestert dem
-- betreffenden Mitglied direkt - im Unterschied zu CheckGuildDings oben,
-- das nur lokal bei DIR anzeigt/meldet. Beide Kanaele sind unabhaengig
-- voneinander per Option ein-/ausschaltbar und standardmaessig AUS: das
-- Versenden echter Nachrichten an andere Personen bzw. in den Gildenchat
-- ist eine staerkere Aktion als eine rein lokale Anzeige und sollte daher
-- bewusst aktiviert werden, statt ungefragt bei jedem Levelaufstieg loszugehen.
--
-- EHRLICHER HINWEIS: Bei aktivem Gildenchat-Kanal kann das bei mehreren
-- gleichzeitig levelnden Mitgliedern (z.B. gemeinsames Questen in der
-- fruehen Beta-Phase) den Gildenchat spuerbar fuellen - falls das stoert,
-- einfach den Gildenchat-Kanal aus- und nur noch Fluestern anlassen (oder
-- umgekehrt), oder beide Haken setzen nur fuer besondere Meilensteine
-- (z.B. Maximallevel) - eine Mindestlevel-Schwelle dafuer gibt es aktuell
-- nicht, kann aber bei Bedarf leicht ergaenzt werden.
-- Sentinel-Werte je Vorlagen-Art, fuer die Validierung eines (ggf. vom
-- Spieler frei eingegebenen) Formatstrings, BEVOR er gespeichert bzw.
-- tatsaechlich verschickt wird - ein kaputter Platzhalter (z.B. vergessenes
-- %d oder ein zusaetzliches %s) darf nie zu einem Lua-Fehler beim naechsten
-- Levelup fuehren.
--
-- WICHTIG: pcall(string.format, ...) allein reicht NICHT aus, um zu pruefen,
-- ob der Text ueberhaupt die erwarteten Platzhalter enthaelt - Lua ignoriert
-- ueberzaehlige/ungenutzte Argumente bei string.format stillschweigend,
-- d.h. ein Text OHNE jeden Platzhalter (z.B. "Kaputter Text ohne
-- Platzhalter") wuerde den reinen pcall-Erfolgstest bestehen, obwohl beim
-- naechsten Levelup gar kein Name/Level eingesetzt wird. Deshalb wird nach
-- dem pcall zusaetzlich geprueft, ob jeder Sentinel-Wert tatsaechlich im
-- formatierten Ergebnis auftaucht.
local GZ_TEMPLATE_SENTINELS = {
    guild = { "EmberstoneTestName", 918273 },
    whisper = { 918273 },
}

local function ValidateGZTemplate(kind, text)
    local sentinels = GZ_TEMPLATE_SENTINELS[kind]
    if not sentinels then return false end

    local ok, formatted = pcall(string.format, text, unpack(sentinels))
    if not ok then return false end

    formatted = tostring(formatted)
    for _, sentinel in ipairs(sentinels) do
        if not formatted:find(tostring(sentinel), 1, true) then
            return false
        end
    end
    -- Chatnachrichten duerfen hoechstens 255 Byte lang sein - mit einem
    -- langen Namen (Vor- und Nachname) und Level muss es noch passen.
    local okLong, longest = pcall(string.format, text, string.rep("W", 40), 100)
    if not okLong or #tostring(longest) > 255 then
        return false
    end
    return true
end

local function GZSettingKey(kind)
    return kind == "guild" and "guildDingAutoGZGuildText" or "guildDingAutoGZWhisperText"
end

local function GZDefaultTemplate(kind)
    return kind == "guild" and Addon.L["GUILD_DING_GZ_GUILD"] or Addon.L["GUILD_DING_GZ_WHISPER"]
end

function Addon:GetGZTemplate(kind)
    return self:GetSetting(GZSettingKey(kind)) or GZDefaultTemplate(kind)
end

-- Speichert einen eigenen Nachrichtentext, NACHDEM er erfolgreich gegen
-- die erwarteten Platzhalter getestet wurde. Rueckgabe true/false, damit
-- Aufrufer (Slash-Befehl, StaticPopup) bei Bedarf eine Fehlermeldung zeigen
-- koennen.
function Addon:SetGZTemplate(kind, text)
    if not GZ_TEMPLATE_SENTINELS[kind] then return false end
    if not text or text == "" then return false end

    if not ValidateGZTemplate(kind, text) then
        print(string.format(Addon.L["GZMSG_INVALID"],
            kind == "guild" and Addon.L["GZMSG_PLACEHOLDERS_GUILD"] or Addon.L["GZMSG_PLACEHOLDERS_WHISPER"]))
        return false
    end

    self:SetSetting(GZSettingKey(kind), text)
    print(Addon.L["GZMSG_SAVED"])
    return true
end

function Addon:ResetGZTemplates()
    self:SetSetting("guildDingAutoGZGuildText", nil)
    self:SetSetting("guildDingAutoGZWhisperText", nil)
    print(Addon.L["GZMSG_RESET_DONE"])
end

-- ============================================================
-- Varianten-Pool je Kanal (guild/whisper): mehrere Glueckwunschtexte statt
-- nur einem festen - beim tatsaechlichen Versand wird zufaellig einer
-- daraus gewaehlt, WENN der jeweilige "Random"-Schalter an ist UND der
-- Pool nicht leer ist. Ist der Pool leer oder Random aus, gilt weiterhin
-- ganz normal der einzelne feste Text von oben. Gleiches Prinzip wie die
-- Varianten-Pools in GrindShout (Health/Spell/Roll).
-- ============================================================
local function GZPoolField(kind)
    return kind == "guild" and "guildDingAutoGZGuildPool" or "guildDingAutoGZWhisperPool"
end

local function GZRandomKey(kind)
    return kind == "guild" and "guildDingAutoGZGuildRandom" or "guildDingAutoGZWhisperRandom"
end

function Addon:GetGZPool(kind)
    local field = GZPoolField(kind)
    EmberstoneCommon[field] = EmberstoneCommon[field] or {}
    return EmberstoneCommon[field]
end

function Addon:AddGZPoolEntry(kind, text)
    if not GZ_TEMPLATE_SENTINELS[kind] then return false end
    if not text or text == "" then return false end

    if not ValidateGZTemplate(kind, text) then
        print(string.format(Addon.L["GZMSG_INVALID"],
            kind == "guild" and Addon.L["GZMSG_PLACEHOLDERS_GUILD"] or Addon.L["GZMSG_PLACEHOLDERS_WHISPER"]))
        return false
    end

    table.insert(self:GetGZPool(kind), text)
    return true
end

function Addon:RemoveGZPoolEntry(kind, index)
    local pool = self:GetGZPool(kind)
    if not pool[index] then return false end
    table.remove(pool, index)
    return true
end

-- Waehlt den tatsaechlich zu verwendenden Text: zufaellige Pool-Variante,
-- falls aktiviert und vorhanden, sonst der einzelne feste Text.
function Addon:PickGZTemplate(kind)
    if self:GetSetting(GZRandomKey(kind)) then
        local pool = self:GetGZPool(kind)
        if #pool > 0 then
            return pool[math.random(#pool)]
        end
    end
    return self:GetGZTemplate(kind)
end

function Addon:HandleGZPoolCommand(kind, rest)
    rest = rest or ""
    local sub, arg = rest:match("^(%S*)%s*(.-)$")
    sub = (sub or ""):lower()

    if sub == "add" then
        if arg == "" then
            print(Addon.L["GZMSG_POOL_ADD_USAGE"])
            return
        end
        if self:AddGZPoolEntry(kind, arg) then
            print(Addon.L["GZMSG_POOL_ADD_DONE"])
        end
        return
    end

    if sub == "remove" then
        local idx = tonumber(arg)
        if not idx or not self:RemoveGZPoolEntry(kind, math.floor(idx)) then
            print(Addon.L["GZMSG_POOL_REMOVE_INVALID"])
            return
        end
        print(string.format(Addon.L["GZMSG_POOL_REMOVE_DONE"], math.floor(idx)))
        return
    end

    if sub == "list" then
        local pool = self:GetGZPool(kind)
        if #pool == 0 then
            print(Addon.L["GZMSG_POOL_LIST_EMPTY"])
            return
        end
        print(Addon.L["GZMSG_POOL_LIST_HEADER"])
        for i, text in ipairs(pool) do
            print("  " .. i .. ". " .. text)
        end
        return
    end

    print(Addon.L["GZMSG_POOL_HELP"])
end

-- ============================================================
-- Eigener Nachrichtentext ueber ein natives StaticPopup-Eingabefeld -
-- dieselbe, seit jeher stabile Blizzard-API wie beim Twink-Zuweisungs-
-- bzw. Export/Import-Dialog in Grindkeep (siehe dortiges Comm.lua/UI.lua),
-- bewusst NICHT die neuere, in Forever noch ungetestete Settings-API.
--
-- WICHTIG (Live-Fund 21.09.2026): Auf diesem Client heisst das Eingabefeld
-- des Popups "EditBox" (grosses E, GameDialog.xml-Region), NICHT "editBox"
-- wie beim aelteren, klassischen StaticPopup - self.editBox war schlicht
-- nil und liess "attempt to index field 'editBox' (a nil value)" werfen.
-- GetPopupEditBox() unten deckt beide Schreibweisen ab, falls ein anderer
-- Client (z.B. normales Retail) doch noch die alte Feldbezeichnung nutzt.
-- ============================================================
local function GetPopupEditBox(popup)
    return popup.EditBox or popup.editBox
end

StaticPopupDialogs["EMBERSTONE_GZMSG_GUILD"] = {
    text = Addon.L["GZMSG_EDIT_GUILD_TITLE"],
    button1 = OKAY,
    button2 = CANCEL,
    hasEditBox = true,
    editBoxWidth = 350,
    OnShow = function(self)
        local editBox = GetPopupEditBox(self)
        editBox:SetMaxLetters(0)
        editBox:SetText(Addon:GetGZTemplate("guild"))
        editBox:HighlightText()
        editBox:SetFocus()
    end,
    -- true zurueckgeben laesst das Fenster offen, wenn der Text ungueltig ist
    OnAccept = function(self)
        if not Addon:SetGZTemplate("guild", GetPopupEditBox(self):GetText()) then return true end
    end,
    EditBoxOnEnterPressed = function(self)
        local parent = self:GetParent()
        Addon:SetGZTemplate("guild", GetPopupEditBox(parent):GetText())
        parent:Hide()
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["EMBERSTONE_GZMSG_WHISPER"] = {
    text = Addon.L["GZMSG_EDIT_WHISPER_TITLE"],
    button1 = OKAY,
    button2 = CANCEL,
    hasEditBox = true,
    editBoxWidth = 350,
    OnShow = function(self)
        local editBox = GetPopupEditBox(self)
        editBox:SetMaxLetters(0)
        editBox:SetText(Addon:GetGZTemplate("whisper"))
        editBox:HighlightText()
        editBox:SetFocus()
    end,
    -- true zurueckgeben laesst das Fenster offen, wenn der Text ungueltig ist
    OnAccept = function(self)
        if not Addon:SetGZTemplate("whisper", GetPopupEditBox(self):GetText()) then return true end
    end,
    EditBoxOnEnterPressed = function(self)
        local parent = self:GetParent()
        Addon:SetGZTemplate("whisper", GetPopupEditBox(parent):GetText())
        parent:Hide()
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function Addon:ShowGZMessageDialog(kind)
    if kind == "guild" then
        StaticPopup_Show("EMBERSTONE_GZMSG_GUILD")
    elseif kind == "whisper" then
        StaticPopup_Show("EMBERSTONE_GZMSG_WHISPER")
    end
end

-- Aufgerufen von Commands.lua bei "/emberstone gzmsg ...". Ohne Text
-- oeffnet sich der Eingabedialog oben (vorausgefuellt mit dem aktuellen
-- Text) - derselbe "kurzer String direkt vs. eigenes Fenster"-Kompromiss
-- wie beim Import in Grindkeep, da die Chat-Eingabezeile selbst ein
-- Zeichenlimit hat.
function Addon:HandleGZMsgCommand(rest)
    rest = rest or ""
    local kind, restAfterKind = rest:match("^(%S*)%s*(.-)$")
    kind = (kind or ""):lower()

    if kind == "reset" then
        self:ResetGZTemplates()
        return
    end

    if kind ~= "guild" and kind ~= "whisper" then
        print(Addon.L["GZMSG_HELP"])
        print(string.format(Addon.L["GZMSG_CURRENT_GUILD"], self:GetGZTemplate("guild")))
        print(string.format(Addon.L["GZMSG_CURRENT_WHISPER"], self:GetGZTemplate("whisper")))
        return
    end

    -- "/emberstone gzmsg guild pool ..." bzw. "... random on|off" - mehrere
    -- Varianten statt eines einzelnen festen Texts, siehe GetGZPool oben.
    local sub, subRest = restAfterKind:match("^(%S*)%s*(.-)$")
    local subLower = (sub or ""):lower()

    -- Nur als Befehl werten, wenn wirklich einer gemeint ist - ein eigener
    -- Text darf mit "Random ..." oder "Pool ..." beginnen.
    local poolSub = ((subRest or ""):match("^(%S*)") or ""):lower()
    if subLower == "pool" and (poolSub == "" or poolSub == "add" or poolSub == "remove" or poolSub == "list") then
        self:HandleGZPoolCommand(kind, subRest)
        return
    end

    local onOffCheck = (subRest or ""):lower()
    if subLower == "random" and (onOffCheck == "" or onOffCheck == "on" or onOffCheck == "off") then
        local onOff = (subRest or ""):lower()
        if onOff == "on" then
            self:SetSetting(GZRandomKey(kind), true)
            print(Addon.L["GZMSG_RANDOM_ON"])
        elseif onOff == "off" then
            self:SetSetting(GZRandomKey(kind), false)
            print(Addon.L["GZMSG_RANDOM_OFF"])
        else
            print(Addon.L["GZMSG_RANDOM_USAGE"])
        end
        return
    end

    -- Sonst: kompletter Rest ist der einzelne feste Text (oder leer -> Dialog)
    if restAfterKind == "" then
        self:ShowGZMessageDialog(kind)
        return
    end

    self:SetGZTemplate(kind, restAfterKind)
end

-- ============================================================
-- Mehrzeiliger Varianten-Editor (echtes Fenster mit CreateFrame/EditBox,
-- KEIN StaticPopup) - beantwortet die urspruengliche Bitte "ein Button,
-- der ein Fenster oeffnet, in dem man z.B. 10 Zeilen Glueckwunschtexte auf
-- einmal eintragen kann". StaticPopup-Eingabefelder sind einzeilig, das
-- reicht dafuer nicht.
--
-- WICHTIG (Ehrlichkeit, kein Rätselraten): Dies ist bewusst NICHT ueber
-- die neuere Settings-Listen-API gebaut, sondern mit den einfachsten,
-- seit ueber 15 Jahren unveraenderten UI-Bausteinen (CreateFrame,
-- "UIPanelButtonTemplate", EditBox:SetMultiLine, "UIPanelScrollFrameTemplate").
-- Genau DAS ist der Unterschied zu den vorher entfernten toten Buttons:
-- CreateSettingsButtonInitializer ist ein neuer, offenbar auf WoW Forever
-- kaputter Baustein der Settings-Listen-API - ein ganz normaler
-- CreateFrame("Button", ..., "UIPanelButtonTemplate") ist etwas komplett
-- anderes und in praktisch jedem WoW-Interface seit Jahren im Einsatz.
-- Trotzdem gilt wie ueberall in diesem Projekt: nicht ungetestet als
-- "sicher funktionierend" behaupten - bitte einmal live ausprobieren.
-- ============================================================
local gzPoolEditor

local function BuildGZPoolEditor()
    if gzPoolEditor then return gzPoolEditor end

    local frame = CreateFrame("Frame", "EmberstoneGZPoolEditor", UIParent, "BackdropTemplate")
    frame:SetSize(440, 380)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface/DialogFrame/UI-DialogBox-Background",
            edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        })
    end
    frame:Hide()
    tinsert(UISpecialFrames, "EmberstoneGZPoolEditor") -- schliessbar per Escape

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("TOP", 0, -16)

    frame.hint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.hint:SetPoint("TOP", frame.title, "BOTTOM", 0, -10)
    frame.hint:SetWidth(380)
    frame.hint:SetJustifyH("CENTER")
    frame.hint:SetText(Addon.L["GZPOOL_EDITOR_HINT"])

    local scrollFrame = CreateFrame("ScrollFrame", "EmberstoneGZPoolEditorScroll", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 20, -84)
    scrollFrame:SetPoint("BOTTOMRIGHT", -36, 56)

    local scrollBg = CreateFrame("Frame", nil, scrollFrame, "BackdropTemplate")
    scrollBg:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", -4, 4)
    scrollBg:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", 4, -4)
    if scrollBg.SetBackdrop then
        scrollBg:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        scrollBg:SetBackdropColor(0, 0, 0, 0.3)
    end

    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetWidth(370)
    editBox:SetAutoFocus(false)
    editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    scrollFrame:SetScrollChild(editBox)
    frame.editBox = editBox

    local cancelButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    cancelButton:SetSize(110, 22)
    cancelButton:SetPoint("BOTTOMRIGHT", -20, 16)
    cancelButton:SetText(Addon.L["GZPOOL_EDITOR_CANCEL"])
    cancelButton:SetScript("OnClick", function() frame:Hide() end)
    frame.cancelButton = cancelButton

    local saveButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    saveButton:SetSize(110, 22)
    saveButton:SetPoint("RIGHT", cancelButton, "LEFT", -8, 0)
    saveButton:SetText(Addon.L["GZPOOL_EDITOR_SAVE"])
    frame.saveButton = saveButton
    saveButton:SetScript("OnClick", function()
        local opts = frame.opts
        if not opts then frame:Hide() return end
        local text = editBox:GetText() or ""

        -- Ein Eintrag pro Zeile, Leerzeilen werden uebersprungen.
        local lines = {}
        for line in text:gmatch("[^\r\n]+") do
            line = line:match("^%s*(.-)%s*$")
            if line ~= "" then
                table.insert(lines, line)
            end
        end

        -- Erst alle Zeilen pruefen. Ist eine ungueltig, wird NICHTS
        -- gespeichert und das Fenster bleibt offen - mit Angabe der Zeile,
        -- damit sie korrigiert werden kann, statt verloren zu gehen.
        local badLines = {}
        for i, line in ipairs(lines) do
            if not opts.validate(line) then table.insert(badLines, i) end
        end
        if #badLines > 0 then
            print(opts.badLinesMessage(table.concat(badLines, ", ")))
            return
        end

        -- Das Fenster zeigt IMMER die komplette Liste - beim Speichern wird
        -- sie deshalb komplett ersetzt, sonst waere Loeschen wirkungslos.
        opts.save(lines)
        print(Addon.L["GZMSG_SAVED"])
        frame:Hide()
    end)

    gzPoolEditor = frame
    return frame
end

-- Allgemeiner Listen-Editor (eine Zeile pro Eintrag). opts:
--   title, hint, lines (Tabelle), validate(line) -> bool,
--   badLinesMessage(zeilenListe) -> Text, save(lines)
-- Genutzt fuer die Glueckwunsch-Varianten und die AFK-Sprueche.
function Addon:ShowTextListEditor(opts)
    local frame = BuildGZPoolEditor()
    frame.opts = opts
    frame.title:SetText(opts.title or "")
    frame.hint:SetText(opts.hint or "")
    frame.editBox:SetText(table.concat(opts.lines or {}, "\n"))
    frame.editBox:SetCursorPosition(0)
    frame:Show()
    frame.editBox:SetFocus()
end

function Addon:ShowGZPoolEditor(kind)
    if kind ~= "guild" and kind ~= "whisper" then return end
    self:ShowTextListEditor({
        title = kind == "guild" and Addon.L["GZPOOL_EDITOR_TITLE_GUILD"] or Addon.L["GZPOOL_EDITOR_TITLE_WHISPER"],
        hint = Addon.L["GZPOOL_EDITOR_HINT"],
        lines = self:GetGZPool(kind),
        validate = function(line) return ValidateGZTemplate(kind, line) end,
        badLinesMessage = function(bad)
            return string.format(Addon.L["GZPOOL_EDITOR_BAD_LINES"], bad,
                kind == "guild" and Addon.L["GZMSG_PLACEHOLDERS_GUILD"] or Addon.L["GZMSG_PLACEHOLDERS_WHISPER"])
        end,
        save = function(lines)
            local pool = Addon:GetGZPool(kind)
            for i = #pool, 1, -1 do table.remove(pool, i) end
            for _, line in ipairs(lines) do Addon:AddGZPoolEntry(kind, line) end
        end,
    })
end

-- ============================================================
-- Versand: Warteschlange, Drosselung, Sperre und Abstimmung
--
-- - Nachrichten gehen einzeln mit Abstand raus (nie mehrere im selben
--   Moment), und zwar ueber C_ChatInfo.SendChatMessage, falls vorhanden.
-- - In Kampf-/Instanz-Situationen, in denen das Spiel Chatnachrichten von
--   Addons sperrt, wird gewartet statt die Nachricht still zu verlieren.
-- - Haben mehrere Gildenmitglieder Emberstone mit automatischem
--   Gildenchat-Glueckwunsch, schreibt nur EINER: jeder wartet zufaellig
--   ein paar Sekunden und kuendigt seinen Glueckwunsch per Addon-Nachricht
--   an; wer eine fremde Ankuendigung fuer denselben Levelaufstieg sieht,
--   verzichtet. (Fluestern bleibt persoenlich und wird nicht abgestimmt.)
-- ============================================================
local COMM_PREFIX = "Emberstone"
local SEND_GAP = 1.5
local sendQueue = {}
local sendBusy = false
local gzAnnounced = {} -- ["<Schluessel>:<Level>"] = true, sobald jemand gratuliert hat

local function SendChat(msg, channel, target)
    local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
    if not send then return false end
    return (pcall(send, msg, channel, nil, target))
end

local function InLockdown()
    if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown then
        local ok, locked = pcall(C_ChatInfo.InChatMessagingLockdown)
        return ok and locked == true
    end
    return false
end

local function ProcessQueue()
    if sendBusy then return end
    local item = sendQueue[1]
    if not item then return end
    sendBusy = true

    if InLockdown() then
        -- Hoechstens zwei Minuten warten, danach ist der Glueckwunsch ohnehin
        -- nicht mehr passend.
        if GetTime() - item.queuedAt > 120 then
            table.remove(sendQueue, 1)
        end
        C_Timer.After(5, function() sendBusy = false; ProcessQueue() end)
        return
    end

    table.remove(sendQueue, 1)
    if item.check == nil or item.check() then
        if not SendChat(item.msg, item.channel, item.target) then
            print(Addon.L["GUILD_DING_GZ_SEND_FAILED"])
        elseif item.onSent then
            item.onSent()
        end
    end
    C_Timer.After(SEND_GAP, function() sendBusy = false; ProcessQueue() end)
end

local function Enqueue(item)
    item.queuedAt = GetTime()
    table.insert(sendQueue, item)
    ProcessQueue()
end

-- Addon-Nachrichten fuer die Abstimmung
local commFrame = CreateFrame("Frame")
commFrame:RegisterEvent("PLAYER_LOGIN")
commFrame:RegisterEvent("CHAT_MSG_ADDON")
commFrame:SetScript("OnEvent", function(_, event, prefix, message, channel, sender)
    if event == "PLAYER_LOGIN" then
        if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
            pcall(C_ChatInfo.RegisterAddonMessagePrefix, COMM_PREFIX)
        end
        return
    end
    if prefix ~= COMM_PREFIX or channel ~= "GUILD" then return end
    if issecretvalue and (issecretvalue(message) or issecretvalue(sender)) then return end
    if type(message) ~= "string" or #message > 120 then return end
    local key, level = message:match("^GZ:(.+):(%d+)$")
    if key and level then
        gzAnnounced[key .. ":" .. level] = true
    end
end)

local function AnnounceGZ(key, level)
    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
        local payload = "GZ:" .. key .. ":" .. level
        if #payload <= 250 then
            pcall(C_ChatInfo.SendAddonMessage, COMM_PREFIX, payload, "GUILD")
        end
    end
end

-- name: Name aus dem Roster (ggf. mit Realm), key: eindeutiger Schluessel
-- des Mitglieds (GUID oder voller Name), jump: um wie viele Level gestiegen
function Addon:SendAutoGZ(name, level, key, jump)
    -- Oeffentliche Glueckwuensche nur fuer einen normalen Levelaufstieg, nicht
    -- fuer grosse Spruenge (z.B. Charakter-Boost oder lange nicht gesehen).
    if (jump or 1) > 2 then return end

    if self:GetSetting("guildDingAutoGZGuild") then
        local ok, msg = pcall(string.format, self:PickGZTemplate("guild"), self:NormalizeName(name), level)
        if ok then
            local announceKey = (key or self:NormalizeName(name)) .. ":" .. level
            C_Timer.After(1 + math.random() * 4, function()
                if gzAnnounced[announceKey] then return end -- jemand anderes war schneller
                Enqueue({
                    msg = msg, channel = "GUILD",
                    check = function() return not gzAnnounced[announceKey] end,
                    onSent = function()
                        gzAnnounced[announceKey] = true
                        AnnounceGZ(key or self:NormalizeName(name), level)
                    end,
                })
            end)
        else
            -- Sollte durch die Validierung in SetGZTemplate eigentlich nie
            -- vorkommen - Absicherung, falls eine SavedVariable von Hand
            -- oder durch eine aeltere Version manipuliert wurde.
            print(Addon.L["GUILD_DING_GZ_SEND_FAILED"])
        end
    end

    if self:GetSetting("guildDingAutoGZWhisper") then
        -- Voller Name (mit ggf. vorhandenem Realm-Suffix aus dem Roster)
        -- als Fluester-Ziel, nicht der normalisierte.
        local ok, msg = pcall(string.format, self:PickGZTemplate("whisper"), level)
        if ok then
            Enqueue({ msg = msg, channel = "WHISPER", target = name })
        else
            print(Addon.L["GUILD_DING_GZ_SEND_FAILED"])
        end
    end
end

-- Eindeutiger Schluessel eines Gildenmitglieds: bevorzugt die GUID (aendert
-- sich nie, unabhaengig von Realm und Schreibweise), sonst der volle Name mit
-- Realm. Frueher war es der Name OHNE Realm - zwei "Max" von verbundenen
-- Realms galten dann als dieselbe Person (falsche und verpasste Meldungen).
local function MemberKey(name, guid)
    if type(guid) == "string" and guid ~= "" and not (issecretvalue and issecretvalue(guid)) then
        return guid
    end
    if name and not select(2, Addon:SplitRealm(name)) and GetNormalizedRealmName then
        local realm = GetNormalizedRealmName()
        if realm and realm ~= "" then return name .. "-" .. realm end
    end
    return name
end

-- Eigener Speicher je Gilde (ein Charakter in einer anderen Gilde soll
-- nicht dieselben Eintraege sehen).
local function GuildCacheKey()
    local guildName, _, _, realm = GetGuildInfo("player")
    if not guildName then return nil end
    realm = realm or (GetNormalizedRealmName and GetNormalizedRealmName()) or ""
    return guildName .. "-" .. tostring(realm):gsub("[%s%-]", "")
end

-- Erster Abgleich dieser Sitzung und Mitglieder, die in dieser Sitzung zum
-- ersten Mal online gesehen werden, werden nur still vermerkt: wer levelte,
-- waehrend man selbst offline war, bekommt keinen verspaeteten Schwall an
-- Meldungen und Gildenchat-Glueckwuenschen.
local seenOnlineThisSession = {}

function Addon:CheckGuildDings()
    if not self:GetSetting("guildDingEnabled") then return end
    if not IsInGuild() then return end

    local guildKey = GuildCacheKey()
    if not guildKey then return end

    EmberstoneCommon.guildLevelsByGuild = EmberstoneCommon.guildLevelsByGuild or {}
    EmberstoneCommon.guildLevelsByGuild[guildKey] = EmberstoneCommon.guildLevelsByGuild[guildKey] or {}
    local levels = EmberstoneCommon.guildLevelsByGuild[guildKey]
    local legacy = EmberstoneCommon.guildLevels -- alter Speicher (Name ohne Realm) nur als Startwert
    local myGUID = UnitGUID and UnitGUID("player")

    local total = GetNumGuildMembers()
    for i = 1, total do
        local name, _, _, level, _, _, _, _, online, _, _, _, _, _, _, _, guid = GetGuildRosterInfo(i)

        if online and name and type(level) == "number" and level > 0 then
            local key = MemberKey(name, guid)
            local known = levels[key]
            if known == nil and legacy then known = legacy[self:NormalizeName(name)] end

            local isSelf = (myGUID and guid and guid == myGUID)
                or (not guid and self:NormalizeName(name) == self:NormalizeName(UnitName("player")))

            if not seenOnlineThisSession[key] then
                seenOnlineThisSession[key] = true -- erstes Sehen: nur vermerken
            elseif known and known < level and not isSelf then
                if not self:IsIgnored(name) then
                    if self:GetSetting("guildDingChat") then
                        print(string.format(Addon.L["GUILD_DING_CHAT"], PlayerLink(name), level))
                    end
                    if self:GetSetting("guildDingScreen") then
                        SafeRaidNotice(string.format(Addon.L["GUILD_DING_SCREEN"], self:DisplayName(name), level), 1, 0.82, 0.0)
                    end
                    self:SendAutoGZ(name, level, key, level - known)
                    self:AddDingLogEntry(name, level)
                end
            end
            levels[key] = level
        end
    end
end

function Addon:TestGuildDing()
    local name = UnitName("player") or Addon.L["GENERIC_YOU"]
    print(string.format(Addon.L["GUILD_DING_TEST_CHAT"], PlayerLink(name)))
    SafeRaidNotice(string.format(Addon.L["GUILD_DING_TEST_SCREEN"], name), 1, 0.82, 0.0)
end

----------------------------------------------------------------------------------------------
-- Periodische Roster-Abfrage
--
-- GuildRoster()/C_GuildInfo.GuildRoster() ist selbst kein Rechenaufwand am
-- Client (kein Bild wird neu gezeichnet, kein Frame haengt) - es ist
-- lediglich eine Anfrage an den Server, die die Aktualisierung dann per
-- GUILD_ROSTER_UPDATE-Event zurueckliefert. Insofern verursacht ein
-- 6-Sekunden-Takt fuer sich genommen kein spuerbares Ruckeln.
--
-- Trotzdem war der Einwand berechtigt: der alte Fixwert von 6 Sekunden lief
-- bisher IMMER, solange man in einer Gilde war - auch wenn "guildDingEnabled"
-- laengst deaktiviert war, und unabhaengig davon, ob man die Meldungen
-- ueberhaupt so haeufig braucht. Ausserdem duerfte Blizzard serverseitig
-- ohnehin haeufigere Anfragen abblocken (nach verbreiteter Erfahrung anderer
-- Gilden-Addons liegt die Server-Sperre eher bei ca. 10 Sekunden, das ist
-- aber nicht zu 100% verifizierbar) - ein 6-Sekunden-Takt haette also
-- vermutlich ohnehin teilweise ins Leere gelaufen.
--
-- Deshalb jetzt: Standardwert auf 15 Sekunden angehoben, ueber den Slider
-- "Abfrage-Haeufigkeit" im Optionsfenster frei einstellbar (5-60s), und der
-- Ticker startet gar nicht erst, wenn "guildDingEnabled" deaktiviert ist.
----------------------------------------------------------------------------------------------

Addon._guildPoll = Addon._guildPoll or {}

function Addon:StopGuildPolling()
    if self._guildPoll.ticker then
        self._guildPoll.ticker:Cancel()
        self._guildPoll.ticker = nil
    end
end

function Addon:StartGuildPolling()
    self:StopGuildPolling()

    if not self:GetSetting("guildDingEnabled") then
        -- Komplett deaktiviert: kein Ticker, keine periodischen
        -- Server-Anfragen mehr, nicht nur stillschweigend keine Meldung.
        return
    end

    local interval = self:GetSetting("guildDingPollInterval") or Addon.Defaults.guildDingPollInterval
    self._guildPoll.ticker = C_Timer.NewTicker(interval, function()
        if IsInGuild() then
            Addon:RequestGuildRosterUpdate()
        end
    end)
end
