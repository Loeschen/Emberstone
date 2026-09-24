-- Emberstone-Tests mit Lua 5.1 und nachgebauter WoW-API (siehe wow_mock.lua).
--
-- Aufruf aus dem Addon-Ordner:   lua5.1 tests/run.lua
-- oder mit Pfad:                 lua5.1 tests/run.lua /pfad/zu/Emberstone
--
-- Laedt die Dateien in der Reihenfolge der Emberstone.toc, jeweils fuer
-- Retail und Forever (siehe Profile in wow_mock.lua) und fuer deDE/enUS.
local TESTDIR = arg[0]:match("^(.*)[/\\]") or "."
package.path = TESTDIR .. "/?.lua;" .. package.path
local ROOT = arg[1] or (TESTDIR .. "/..")
local M = require("wow_mock")

-- print wird von der Mock-API ersetzt (Chat-Ausgabe des Addons), daher
-- eigene Ausgabe ueber io.write
local function out(s) io.write(tostring(s), "\n") end

local passed, failed = 0, 0
local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then passed = passed + 1; out("  ok     " .. name)
    else failed = failed + 1; out("  FEHLER " .. name .. "\n         " .. tostring(err)) end
end
local function eq(a, b, msg)
    if a ~= b then error((msg and msg .. ": " or "") .. "erwartet <" .. tostring(b) .. ">, bekommen <" .. tostring(a) .. ">", 2) end
end
local function has(list, needle)
    for _, l in ipairs(list) do if tostring(l):find(needle, 1, true) then return true end end
    return false
end

local function boot(profile, locale, pre)
    M.reset(profile, locale)
    if pre then pre() end
    local A = M.LoadAddon(ROOT)
    M.FireEvent("ADDON_LOADED", "Emberstone")
    M.FireEvent("PLAYER_LOGIN")
    M.FireEvent("PLAYER_ENTERING_WORLD")
    return A
end

-- ------------------------------------------------------------------
-- Uebersetzungen (unabhaengig vom Profil)
-- ------------------------------------------------------------------
out("\n== Übersetzungen ==")
local function loadStrings()
    local src = io.open(ROOT .. "/src/Locale.lua"):read("*a")
    src = src:gsub("local L = setmetatable", "__TEST_STRINGS = STRINGS\nlocal L = setmetatable", 1)
    _G.GetLocale = function() return "deDE" end
    assert(loadstring(src))("Emberstone", {})
    return __TEST_STRINGS
end

test("Jeder benutzte Schlüssel hat deDE und enUS", function()
    local S = loadStrings()
    local files = { "src/Commands.lua", "src/Core.lua", "src/Events.lua", "src/Minimap.lua", "src/UI.lua",
        "src/features/GuildDing.lua", "src/features/AfkText.lua", "src/features/Screenshots.lua" }
    local missing = {}
    for _, f in ipairs(files) do
        local c = io.open(ROOT .. "/" .. f):read("*a")
        for k in c:gmatch('L%["([%w_]+)"%]') do
            if not (S[k] and S[k].deDE and S[k].enUS) then missing[#missing + 1] = k .. " (" .. f .. ")" end
        end
    end
    if #missing > 0 then error(table.concat(missing, ", ")) end
end)

test("Platzhalter in deDE und enUS gleich (außer Datumsformat)", function()
    local S = loadStrings()
    local function spec(s)
        local t = {}
        for c in s:gmatch("%%([%-%d%.]*[%a%%])") do if c ~= "%" then t[#t + 1] = c:sub(-1) end end
        return table.concat(t, ",")
    end
    for k, e in pairs(S) do
        if k ~= "DATE_FORMAT" and e.deDE and e.enUS then eq(spec(e.deDE), spec(e.enUS), k) end
    end
end)

test("Deutsche Texte ohne ae/oe/ue-Ersatzschreibung", function()
    local S = loadStrings()
    local bad = { "fuer", "Fuer", "ueber", "Glueck", "Fluest", "oeffn", "Haelt", "aess", "Qualitaet",
        "zufaell", "Zufaell", "Ungueltig", "verfuegbar", "moecht", "geloescht", "getoetet", "grosse" }
    for k, e in pairs(S) do
        for _, w in ipairs(bad) do
            if e.deDE and e.deDE:find(w, 1, true) then error(k .. " enthält '" .. w .. "'") end
        end
    end
end)

for _, profile in ipairs({ "retail", "forever" }) do
  for _, locale in ipairs({ "deDE", "enUS" }) do
    out(("\n== Profil %s / %s =="):format(profile, locale))

    test("Laden + Initialisierung ohne Lua-Fehler", function()
        local A = boot(profile, locale)
        assert(A.OptionsCategory, "Optionskategorie fehlt")
        assert(SlashCmdList.EMBERSTONE, "Slash-Befehl fehlt")
        M.advance(20)
        eq(#M.errors, 0, "Fehler an geterrorhandler")
    end)

    -- -------- Minimap-Symbol --------
    test("Minimap-Symbol wird beim Start gebaut und gezeigt", function()
        boot(profile, locale)
        local b = _G.EmberstoneMinimapButton
        assert(b, "Button fehlt")
        assert(b:IsShown(), "Button nicht sichtbar")
        local p = b._points[#b._points]
        -- 240 Grad, Radius 80: x = cos(240)*80 = -40, y = sin(240)*80 = -69.28
        assert(math.abs(p[4] + 40) < 0.01 and math.abs(p[5] + 69.282) < 0.01, "Position falsch")
    end)

    test("Symbolpfad kommt aus dem Addon-Namen", function()
        local seen
        boot(profile, locale, function()
            local orig = CreateFrame
            _G.CreateFrame = function(...)
                local f = orig(...)
                local ct = f.CreateTexture
                f.CreateTexture = function(self2, ...)
                    local t = ct(self2, ...)
                    t.SetTexture = function(_, path) if tostring(path):find("minimap.tga", 1, true) then seen = path end end
                    return t
                end
                return f
            end
        end)
        eq(seen, "Interface\\AddOns\\Emberstone\\Assets\\minimap.tga")
    end)

    test("/emberstone minimap ohne Zusatz schaltet aus und wieder ein", function()
        local A = boot(profile, locale)
        SlashCmdList.EMBERSTONE("minimap")
        eq(A:GetSetting("minimapHide"), true, "nach 1. Aufruf")
        eq(EmberstoneMinimapButton:IsShown(), false, "Button nach 1. Aufruf")
        assert(has(M.printed, A.L["MINIMAP_OFF"]), "Aus-Meldung fehlt")
        SlashCmdList.EMBERSTONE("MiniMap")
        eq(A:GetSetting("minimapHide"), false, "nach 2. Aufruf")
        eq(EmberstoneMinimapButton:IsShown(), true, "Button nach 2. Aufruf")
        assert(has(M.printed, A.L["MINIMAP_ON"]), "Ein-Meldung fehlt")
    end)

    test("/emberstone minimap on|show|off|hide setzt gezielt", function()
        local A = boot(profile, locale)
        SlashCmdList.EMBERSTONE("minimap show")   -- schon sichtbar: bleibt sichtbar
        eq(A:GetSetting("minimapHide"), false, "show")
        SlashCmdList.EMBERSTONE("minimap on")
        eq(A:GetSetting("minimapHide"), false, "on")
        SlashCmdList.EMBERSTONE("minimap HIDE ")
        eq(A:GetSetting("minimapHide"), true, "hide")
        SlashCmdList.EMBERSTONE("minimap off")
        eq(A:GetSetting("minimapHide"), true, "off")
        eq(EmberstoneMinimapButton:IsShown(), false, "Button nach off")
        SlashCmdList.EMBERSTONE("minimap on")
        eq(EmberstoneMinimapButton:IsShown(), true, "Button nach on")
    end)

    test("/emberstone minimap mit unbekanntem Zusatz: Hilfe, keine Änderung", function()
        local A = boot(profile, locale)
        SlashCmdList.EMBERSTONE("minimap blubb")
        eq(A:GetSetting("minimapHide"), false)
        assert(has(M.printed, A.L["MINIMAP_USAGE"]), "Hilfe fehlt")
    end)

    test("Ausgeblendet gespeichert -> beim Login kein Button, später einblendbar", function()
        boot(profile, locale)
        local saved = EmberstoneCommon; saved.minimapHide = true
        M.reset(profile, locale)
        local A2 = M.LoadAddon(ROOT)
        EmberstoneCommon = saved
        M.FireEvent("ADDON_LOADED", "Emberstone")
        assert(_G.EmberstoneMinimapButton == nil, "Button sollte gar nicht erst gebaut werden")
        A2.OptionsCategory.settings.emberstone_showMinimapButton:SetValue(true)
        assert(_G.EmberstoneMinimapButton and EmberstoneMinimapButton:IsShown(), "Einblenden über Optionen klappt nicht")
    end)

    test("Optionen-Haken zeigt Zustand nach Slash-Befehl richtig an", function()
        local A = boot(profile, locale)
        local s = A.OptionsCategory.settings.emberstone_showMinimapButton
        eq(s:GetValue(), true)
        SlashCmdList.EMBERSTONE("minimap")
        eq(s:GetValue(), false)
    end)

    test("Klicks: links öffnet Optionen, rechts Test-Meldung", function()
        local A = boot(profile, locale)
        local b = EmberstoneMinimapButton
        b._scripts.OnClick(b, "LeftButton")
        eq(M.openedCategory, A.OptionsCategory.ID, "Optionen")
        b._scripts.OnClick(b, "RightButton")
        assert(has(M.printed, "Anna Müller"), "Test-Meldung mit Name fehlt")
    end)

    test("Im Kampf: Hinweis statt Optionen (Symbol, Addon-Menü, Befehl)", function()
        local A = boot(profile, locale)
        M.inCombat = true
        local b = EmberstoneMinimapButton
        b._scripts.OnClick(b, "LeftButton")
        Emberstone_OnAddonCompartmentClick("Emberstone", "LeftButton")
        SlashCmdList.EMBERSTONE("")
        eq(M.openedCategory, nil, "Optionen wurden trotzdem geöffnet")
        local n = 0
        for _, l in ipairs(M.printed) do if l == A.L["OPTIONS_IN_COMBAT"] then n = n + 1 end end
        eq(n, 3, "Anzahl Kampf-Hinweise")
        M.inCombat = false
        SlashCmdList.EMBERSTONE("")
        eq(M.openedCategory, A.OptionsCategory.ID, "nach dem Kampf")
    end)

    test("Ziehen speichert Winkel (rechts oben = 45 Grad)", function()
        local A = boot(profile, locale)
        local b = EmberstoneMinimapButton
        b._scripts.OnDragStart(b)
        M.cursor = { 600, 600 } -- Minimap-Mitte 500/500
        b._scripts.OnUpdate(b, 0.016)
        eq(math.floor(A:GetSetting("minimapAngle") + 0.5), 45)
        b._scripts.OnDragStop(b)
        eq(b._scripts.OnUpdate, nil, "OnUpdate nach Loslassen")
    end)

    test("Eckige Minimap (GetMinimapShape = SQUARE)", function()
        boot(profile, locale, function() _G.GetMinimapShape = function() return "SQUARE" end end)
        local p = EmberstoneMinimapButton._points[#EmberstoneMinimapButton._points]
        -- 240 Grad auf Quadrat: y ist die groessere Komponente -> y = -76
        assert(math.abs(p[5] + 76) < 0.01, "y=" .. tostring(p[5]))
    end)

    test("Fehler beim Minimap-Aufbau geht an geterrorhandler, Start läuft weiter", function()
        local A = boot(profile, locale, function()
            Minimap.GetWidth = function() error("Minimap kaputt") end
        end)
        eq(#M.errors, 1, "Anzahl Fehler")
        assert(M.errors[1]:find("Minimap kaputt", 1, true), M.errors[1])
        assert(A.OptionsCategory and SlashCmdList.EMBERSTONE, "Rest des Starts fehlt")
    end)

    test("Addon-Sammelknopf ruft Optionen auf", function()
        local A = boot(profile, locale)
        Emberstone_OnAddonCompartmentClick("Emberstone", "LeftButton")
        eq(M.openedCategory, A.OptionsCategory.ID)
    end)

    test("Ohne Settings-API: Hinweis statt Fehler", function()
        local A = boot(profile, locale, function() _G.Settings = nil end)
        SlashCmdList.EMBERSTONE("")
        assert(has(M.printed, A.L["OPTIONS_UNAVAILABLE"]), "Hinweis fehlt")
    end)

    -- -------- Namen (Leerzeichen, Bindestriche, Realm) --------
    test("NormalizeName: normaler Name mit Realm", function()
        local A = boot(profile, locale)
        eq(A:NormalizeName("Max-Forever"), "Max")
        eq(A:NormalizeName("Max-Aman'Thul"), "Max")
        eq(A:NormalizeName("Max"), "Max")
    end)

    test("NormalizeName: Leerzeichen bleiben, nur Realm wird abgeschnitten", function()
        local A = boot(profile, locale)
        eq(A:NormalizeName("Anna Müller-Forever"), "Anna Müller")
        eq(A:NormalizeName("Anna Müller"), "Anna Müller")
    end)

    test("NormalizeName: Anne-Marie Schmidt mit und ohne Realm", function()
        local A = boot(profile, locale)
        eq(A:NormalizeName("Anne-Marie Schmidt-Forever"), "Anne-Marie Schmidt", "mit Realm")
        eq(A:NormalizeName("Anne-Marie Schmidt"), "Anne-Marie Schmidt", "ohne Realm")
        eq(A:NormalizeName("Anna Schmidt-Weber-Forever"), "Anna Schmidt-Weber", "Doppelname hinten")
        -- Bekannte Grenze der Regel: ein Doppelname hinten OHNE Realm ist von
        -- "Name-Realm" nicht zu unterscheiden. Aus dem Roster kommt der Realm
        -- immer mit; eingetippte Namen deckt NameMatches ab (Tests unten).
        eq(A:NormalizeName("Anna Schmidt-Weber"), "Anna Schmidt", "Grenzfall")
    end)

    test("Ignorieren/Log: eingetippter Doppelname ohne Realm (Anna Schmidt-Weber)", function()
        local A = boot(profile, locale)
        SlashCmdList.EMBERSTONE("ignore add Anna Schmidt-Weber")
        assert(A:IsIgnored("Anna Schmidt-Weber-Forever"), "sie selbst")
        assert(not A:IsIgnored("Anna Schmidt-Forever"), "Anna Schmidt fälschlich ignoriert")
        SlashCmdList.EMBERSTONE("ignore remove Anna Schmidt-Weber-Forever")
        eq(#A:GetIgnoreList(), 0, "Entfernen mit Realm")
        A:AddDingLogEntry("Anna Schmidt-Weber-Forever", 20)
        A:AddDingLogEntry("Anna Schmidt-Forever", 30)
        SlashCmdList.EMBERSTONE("log player Anna Schmidt-Weber")
        assert(has(M.printed, "Anna Schmidt-Weber"), "Treffer fehlt")
        for _, l in ipairs(M.printed) do
            assert(not l:find("30", 1, true), "falscher Treffer: " .. l)
        end
    end)

    test("Ignorieren: gleicher Name auf anderem Realm, wenn mit Realm eingetragen", function()
        local A = boot(profile, locale)
        SlashCmdList.EMBERSTONE("ignore add Max-Forever")
        assert(A:IsIgnored("Max-Forever"), "Max-Forever")
        assert(not A:IsIgnored("Max-Andersrealm"), "Max-Andersrealm")
        SlashCmdList.EMBERSTONE("ignore add Max")
        assert(A:IsIgnored("Max-Andersrealm"), "ohne Realm eingetragen gilt für alle Realms")
    end)

    test("DisplayName: Realm nur, wenn nötig (Ambiguate), sonst voller Name", function()
        local A = boot(profile, locale)
        eq(A:DisplayName("Anne-Marie Schmidt-Forever"), "Anne-Marie Schmidt", "eigener Realm")
        eq(A:DisplayName("Anne-Marie Schmidt-Andersrealm"), "Anne-Marie Schmidt-Andersrealm", "fremder Realm")
        -- Schneidet ein Ambiguate am ERSTEN Bindestrich ab, wird das nicht uebernommen
        _G.Ambiguate = function(name) return name:match("^([^%-]+)") end
        eq(A:DisplayName("Anne-Marie Schmidt-Forever"), "Anne-Marie Schmidt-Forever", "kaputtes Ambiguate")
        _G.Ambiguate = nil
        eq(A:DisplayName("Max-Forever"), "Max-Forever", "ohne Ambiguate")
    end)

    test("Gilden-Ding mit Vor- und Nachnamen: Chat, Bildschirm, GZ, Flüstern, Log", function()
        local A = boot(profile, locale)
        A:SetSetting("guildDingAutoGZGuild", true)
        A:SetSetting("guildDingAutoGZWhisper", true)
        M.roster = { { name = "Anne-Marie Schmidt-Forever", level = 10, guid = "Player-1-0002" } }
        A:CheckGuildDings()           -- erstes Sehen: still
        M.roster[1].level = 11
        A:CheckGuildDings()
        M.advance(30)
        assert(has(M.printed, "|Hplayer:Anne-Marie Schmidt-Forever|h[Anne-Marie Schmidt]|h"), "Chat-Link fehlt")
        assert(has(M.raidNotices, "Anne-Marie Schmidt"), "Bildschirmmeldung fehlt")
        assert(not has(M.raidNotices, "ALT:"), "alte API benutzt, obwohl RaidWarningUtil da ist")
        local guild, whisper
        for _, s in ipairs(M.sent) do
            if s.channel == "GUILD" then guild = s end
            if s.channel == "WHISPER" then whisper = s end
        end
        assert(guild and guild.msg:find("Anne-Marie Schmidt", 1, true), "Gildenchat-GZ fehlt/Name falsch")
        assert(not guild.msg:find("Forever", 1, true), "Realm im Gildenchat")
        eq(whisper and whisper.target, "Anne-Marie Schmidt-Forever", "Flüsterziel")
        eq(A:GetDingLog()[1].name, "Anne-Marie Schmidt", "Log")
    end)

    test("Bildschirmmeldung: Rückfall auf RaidNotice_AddMessage", function()
        local A = boot(profile, locale)
        _G.RaidWarningUtil = nil
        _G.RaidNotice_AddMessage = function(_, text) table.insert(M.raidNotices, "ALT:" .. text) end
        A:TestGuildDing()
        assert(has(M.raidNotices, "ALT:"), "Rückfall nicht benutzt")
    end)

    test("Bildschirmmeldung: ganz ohne API kein Fehler", function()
        local A = boot(profile, locale)
        _G.RaidWarningUtil, _G.RaidNotice_AddMessage = nil, nil
        A:TestGuildDing()
    end)

    test("Ignorieren mit Leerzeichen im Namen", function()
        local A = boot(profile, locale)
        SlashCmdList.EMBERSTONE("ignore add Bernd Brot")
        assert(A:IsIgnored("Bernd Brot-Forever"), "nicht ignoriert")
        assert(not A:IsIgnored("Bernd"), "Teilname fälschlich ignoriert")
    end)

    test("Ignorieren: Leerzeichen am Anfang und Ende werden entfernt", function()
        local A = boot(profile, locale)
        SlashCmdList.EMBERSTONE("ignore add   Bernd Brot  ")
        eq(A:GetIgnoreList()[1], "Bernd Brot", "gespeichert")
        assert(A:IsIgnored("Bernd Brot-Forever"), "greift nicht")
        SlashCmdList.EMBERSTONE("ignore remove Bernd Brot ")
        eq(#A:GetIgnoreList(), 0, "Entfernen")
    end)

    test("Ignorieren: alter Eintrag mit Leerzeichen am Ende greift trotzdem", function()
        local A = boot(profile, locale)
        table.insert(A:GetIgnoreList(), "Bernd Brot ")
        assert(A:IsIgnored("Bernd Brot-Forever"))
    end)

    test("Ignorieren von 'Anne-Marie Schmidt' trifft nur sie", function()
        local A = boot(profile, locale)
        SlashCmdList.EMBERSTONE("ignore add Anne-Marie Schmidt")
        eq(A:GetIgnoreList()[1], "Anne-Marie Schmidt", "gespeichert")
        assert(A:IsIgnored("Anne-Marie Schmidt-Forever"), "sie selbst")
        assert(not A:IsIgnored("Anne Weber-Forever"), "Anne Weber")
        assert(not A:IsIgnored("Anne-Sophie Weber-Forever"), "Anne-Sophie Weber")
    end)

    test("Log-Suche mit Leerzeichen im Namen und am Ende", function()
        local A = boot(profile, locale)
        A:AddDingLogEntry("Bernd Brot-Forever", 12)
        SlashCmdList.EMBERSTONE("log player Bernd Brot  ")
        assert(has(M.printed, "Bernd Brot"), "kein Treffer")
        assert(not has(M.printed, A.L["LOG_PLAYER_EMPTY"]:gsub("%%s.*", "")), "Leer-Meldung trotz Treffer")
    end)

    test("GZ-Vorlage: langer Name mit Umlauten passt in 255 Byte", function()
        local A = boot(profile, locale)
        local long = string.rep("Ä", 12) .. " " .. string.rep("Ö", 12)
        local msg = string.format(A:GetGZTemplate("guild"), long, 80)
        assert(#msg <= 255)
    end)

    test("Eigener gespeicherter GZ-Text bleibt unverändert", function()
        local A = boot(profile, locale, function() end)
        A:SetSetting("guildDingAutoGZGuildText", "Glueckwunsch %s zu %d!")
        eq(A:GetGZTemplate("guild"), "Glueckwunsch %s zu %d!")
    end)

    -- -------- Screenshots --------
    test("Level-Screenshot inkl. Qualität zurücksetzen", function()
        local A = boot(profile, locale)
        M.FireEvent("PLAYER_LEVEL_UP", 11)
        M.advance(A:GetDelay("levelDelay") + 0.01)
        eq(M.screenshots, 1)
        eq(M.cvars.screenshotQuality, "5")
        M.advance(4)
        eq(M.cvars.screenshotQuality, "8")
    end)

    test("Doppelt-Sperre: Boss + Erfolg = ein Bild", function()
        local A = boot(profile, locale)
        A:SetSetting("enableBossShots", true); A:SetSetting("enableAchievementShots", true)
        M.FireEvent("BOSS_KILL", 1, "Boss")
        M.FireEvent("ACHIEVEMENT_EARNED", 1)
        M.advance(10)
        eq(M.screenshots, 1)
    end)
  end
end

out(("\n%d bestanden, %d fehlgeschlagen"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
