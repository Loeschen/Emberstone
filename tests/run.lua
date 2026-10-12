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
        "src/features/GuildDing.lua", "src/features/AfkText.lua", "src/features/Screenshots.lua",
        "src/features/Sparkle.lua" }
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
        for k in pairs(M.printed) do M.printed[k] = nil end
        SlashCmdList.EMBERSTONE("log player Anna Schmidt-Weber")
        assert(has(M.printed, "Anna Schmidt-Weber"), "Treffer fehlt")
        -- genau EIN Treffer (der Eintrag fuer Level 30 gehoert zu "Anna Schmidt")
        local n = 0
        for _, l in ipairs(M.printed) do if l:find("Anna Schmidt", 1, true) then n = n + 1 end end
        eq(n, 1, "Anzahl Treffer")
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

    -- -------- Glitzern (v1.13) --------
    local LOOT = { outlineModeShowLootEffectWhenDisabled = "1", graphicsOutlineMode = "0", OutlineEngineMode = "0",
        raidGraphicsOutlineMode = "0", RAIDOutlineEngineMode = "0" }
    local LOOT_OLD = { outlineModeShowLootEffectWhenDisabled = "0", graphicsOutlineMode = "2", OutlineEngineMode = "1",
        raidGraphicsOutlineMode = "1", RAIDOutlineEngineMode = "1" }
    local SOFT = { softTargetInteract = "3", SoftTargetIconGameObject = "1", SoftTargetIconInteract = "1",
        SoftTargetNameplateSize = "0" }
    local SOFT_OLD = { softTargetInteract = "1", SoftTargetIconGameObject = "0", SoftTargetIconInteract = "1",
        SoftTargetNameplateSize = "24" }
    local function cvarsAre(want, what)
        for k, v in pairs(want) do eq(M.cvars[k], v, (what or "") .. " " .. k) end
    end
    local function setsInCombat()
        local n = 0
        for _, s in ipairs(M.cvarSets) do if s[3] then n = n + 1 end end
        return n
    end

    test("Glitzern: ab Werk Quest-Beute an, Soft Targeting unverändert", function()
        local A = boot(profile, locale)
        eq(A:GetSetting("sparkleQuestLoot"), true)
        eq(A:GetSetting("sparkleHerbs"), false)
        cvarsAre(LOOT, "Beute")
        cvarsAre(SOFT_OLD, "Soft")
        eq(EmberstoneCommon.sparkleSaved.loot.graphicsOutlineMode, "2", "gespeichert")
    end)

    test("Glitzern: Ausschalten stellt die vorherigen Werte wieder her", function()
        local A = boot(profile, locale)
        A:SetSparkleOption("sparkleQuestLoot", false)
        cvarsAre(LOOT_OLD, "zurück")
        eq(EmberstoneCommon.sparkleSaved.loot, nil, "Speicher geleert")
        A:SetSparkleOption("sparkleQuestLoot", true)
        cvarsAre(LOOT, "wieder an")
    end)

    test("Glitzern: Login im Kampf ändert nichts, nach dem Kampf nachgeholt", function()
        boot(profile, locale, function() M.inCombat = true end)
        cvarsAre(LOOT_OLD, "im Kampf")
        eq(setsInCombat(), 0, "SetCVar im Kampf")
        M.inCombat = false
        M.FireEvent("PLAYER_REGEN_ENABLED")
        cvarsAre(LOOT, "nach Kampf")
    end)

    test("Glitzern: Umschalten im Kampf -> Hinweis, danach übernommen", function()
        local A = boot(profile, locale)
        M.inCombat = true
        A:SetSparkleOption("sparkleQuestLoot", false)
        eq(setsInCombat(), 0, "SetCVar im Kampf")
        assert(has(M.printed, A.L["SPARKLE_AFTER_COMBAT"]), "Hinweis fehlt")
        cvarsAre(LOOT, "noch unverändert")
        M.inCombat = false
        M.FireEvent("PLAYER_REGEN_ENABLED")
        cvarsAre(LOOT_OLD, "nach Kampf zurück")
    end)

    test("Glitzern: Grafik-Voreinstellung setzt Umriss -> neuer Spielerwert gemerkt, unserer wieder gesetzt", function()
        local A = boot(profile, locale)
        -- Voreinstellung gewaehlt: Client setzt Umriss-Modus auf 3
        M.cvars.graphicsOutlineMode = "3"
        M.FireEvent("CVAR_UPDATE", "graphicsOutlineMode", "3")
        M.advance(1)
        eq(M.cvars.graphicsOutlineMode, "0", "wieder gesetzt")
        eq(EmberstoneCommon.sparkleSaved.loot.graphicsOutlineMode, "3", "neuer Spielerwert")
        A:SetSparkleOption("sparkleQuestLoot", false)
        eq(M.cvars.graphicsOutlineMode, "3", "beim Ausschalten")
    end)

    test("Glitzern: Voreinstellung ohne eigene Meldung je CVar wird trotzdem korrigiert", function()
        boot(profile, locale)
        M.cvars.raidGraphicsOutlineMode = "2"         -- still geaendert
        M.cvars.graphicsQuality = "3"
        M.FireEvent("CVAR_UPDATE", "graphicsQuality", "3")
        M.advance(1)
        eq(M.cvars.raidGraphicsOutlineMode, "0")
        M.cvars.graphicsOutlineMode = "1"
        M.FireEvent("GX_RESTARTED")
        eq(M.cvars.graphicsOutlineMode, "0", "nach Grafik-Neustart")
    end)

    test("Glitzern: unbekannte CVar wird übersprungen (kein Fehler)", function()
        boot(profile, locale, function() end)
        M.reset(profile, locale)
        M.cvars.OutlineEngineMode = nil
        M.cvars.RAIDOutlineEngineMode = nil
        M.LoadAddon(ROOT)
        M.FireEvent("ADDON_LOADED", "Emberstone")
        M.FireEvent("PLAYER_LOGIN")
        eq(M.cvars.graphicsOutlineMode, "0")
        eq(M.cvars.OutlineEngineMode, nil)
        eq(EmberstoneCommon.sparkleSaved.loot.OutlineEngineMode, nil, "nicht gespeichert")
        eq(#M.errors, 0)
    end)

    test("Glitzern: Soft Targeting erst mit einem Schalter, zurück erst wenn alle drei aus", function()
        local A = boot(profile, locale)
        A:SetSparkleOption("sparkleHerbs", true)
        cvarsAre(SOFT, "Kräuter an")
        A:SetSparkleOption("sparkleOre", true)
        A:SetSparkleOption("sparkleHerbs", false)
        cvarsAre(SOFT, "Erz noch an")
        A:SetSparkleOption("sparkleQuestObjects", true)
        A:SetSparkleOption("sparkleOre", false)
        cvarsAre(SOFT, "Questobjekte noch an")
        A:SetSparkleOption("sparkleQuestObjects", false)
        cvarsAre(SOFT_OLD, "alle aus")
        cvarsAre(LOOT, "Beute bleibt")
    end)

    test("Glitzern: ForeverLootSparkles geladen -> nichts eingeschaltet, Hinweis", function()
        local A = boot(profile, locale, function() M.loadedAddons.ForeverLootSparkles = true end)
        cvarsAre(LOOT_OLD, "unverändert")
        eq(#M.cvarSets, 0, "SetCVar-Aufrufe")
        A:SetSparkleOption("sparkleHerbs", true)
        cvarsAre(SOFT_OLD, "Soft unverändert")
        SlashCmdList.EMBERSTONE("sparkle")
        assert(has(M.printed, "ForeverLootSparkles"), "Hinweis im Chat")
    end)

    test("Glitzern: Lueur geladen -> Optionen zeigen Hinweis, Haken gesperrt", function()
        local A = boot(profile, locale, function() M.loadedAddons.Lueur = true end)
        assert(A.SparklePanel, "Glitzer-Seite fehlt")
        A.SparklePanel.Sync()
        eq(#M.cvarSets, 0, "SetCVar-Aufrufe")
    end)

    -- Soft-Target-Szenarien (Cursor-Dateinamen sind ANNAHMEN fuer den Test)
    local function soft(A, cursor, extra)
        local plate = M.NewFrame("Frame", nil)
        plate.GetUnit = function() return "nameplate1" end
        M.soft = { token = "nameplate1", guid = "GameObject-0-1-2-3-1617-0001", cursor = cursor, plate = plate }
        for k, v in pairs(extra or {}) do M.soft[k] = v end
        if not (extra and extra.noAddedEvent) then M.FireEvent("NAME_PLATE_UNIT_ADDED", "nameplate1") end
        M.FireEvent("PLAYER_SOFT_INTERACT_CHANGED", "", "GameObject-1")
        return A._sparkleGlitter()
    end

    test("Glitzern: Kraut in Reichweite hell, außer Reichweite schwach, ohne Beruf grau", function()
        local A = boot(profile, locale)
        A:SetSparkleOption("sparkleHerbs", true)
        M.profs = { 182 }
        local g = soft(A, "Interface\\Cursor\\GatherHerbs")
        assert(g and g:IsShown(), "nicht sichtbar")
        eq(g.look.name, "bright", "hell")
        eq(g.main._desat, false, "nicht grau")
        eq(g.main._color[1], 1.0, "Gold")
        soft(A, "Interface\\Cursor\\UnableGatherHerbs")
        eq(g.look.name, "dim", "schwach")
        assert(g.look.scale < 1 and g.look.strength < 1, "schwach = kleiner und blasser")
        M.profs = { 186 }
        soft(A, "Interface\\Cursor\\GatherHerbs")
        eq(g.look.name, "grey", "grau ohne Kräuterkunde")
        eq(g.main._desat, true, "entsättigt")
    end)

    test("Glitzern: Erz nur mit Erz-Schalter", function()
        local A = boot(profile, locale)
        A:SetSparkleOption("sparkleHerbs", true)
        M.profs = { 186 }
        local g = soft(A, "Interface\\Cursor\\Mine")
        assert(not g or not g:IsShown(), "Erz glitzert ohne Erz-Schalter")
        A:SetSparkleOption("sparkleOre", true)
        g = soft(A, "Interface\\Cursor\\Mine")
        assert(g and g:IsShown(), "Erz glitzert nicht")
        eq(g.look.name, "bright")
        eq(g.main._color[2], 0.78, "Erz ebenfalls Gold")
    end)

    test("Glitzern: Questobjekt über Quest-Zuordnung, im Kampf aus", function()
        local A = boot(profile, locale)
        A:SetSparkleOption("sparkleQuestObjects", true)
        local g = soft(A, "Interface\\Cursor\\Interact", { quest = true })
        assert(g and g:IsShown(), "Questobjekt glitzert nicht")
        M.inCombat = true
        M.FireEvent("PLAYER_REGEN_DISABLED")
        eq(g:IsShown(), false, "im Kampf")
        M.inCombat = false
        M.FireEvent("PLAYER_REGEN_ENABLED")
        eq(g:IsShown(), true, "nach Kampf")
    end)

    test("Glitzern: ohne Namensplakette oder ohne Objekt nichts", function()
        local A = boot(profile, locale)
        A:SetSparkleOption("sparkleHerbs", true)
        M.profs = { 182 }
        local g = soft(A, "Interface\\Cursor\\GatherHerbs", { plate = false })
        assert(not g or not g:IsShown(), "ohne Plakette")
        M.soft = nil
        M.FireEvent("PLAYER_SOFT_INTERACT_CHANGED", "GameObject-1", "")
        g = A._sparkleGlitter()
        assert(not g or not g:IsShown(), "ohne Objekt")
    end)

    test("Glitzern: Objekt wird erkannt, obwohl UnitExists(softinteract) false ist (Forever-Fund)", function()
        local A = boot(profile, locale)
        A:SetSparkleOption("sparkleHerbs", true)
        M.profs = { 182 }
        local g = soft(A, "Interface\\Cursor\\GatherHerbs")
        eq(UnitExists("softinteract"), false, "Mock wie auf Forever")
        assert(g and g:IsShown(), "nicht erkannt")
        local info = A:ClassifySoftInteract()
        eq(info.unit, "nameplate1", "Plaketten-Einheit")
        eq(info.isObject, true, "Spielobjekt")
    end)

    test("Glitzern: Plakette schon vor dem Laden da (/reload) wird gefunden", function()
        local A = boot(profile, locale)
        A:SetSparkleOption("sparkleHerbs", true)
        local g = soft(A, "Interface\\Cursor\\GatherHerbs", { noAddedEvent = true })
        assert(g and g:IsShown(), "ohne NAME_PLATE_UNIT_ADDED nicht gefunden")
    end)

    test("Glitzern: NPC als Soft-Target glitzert nicht", function()
        local A = boot(profile, locale)
        A:SetSparkleOption("sparkleQuestObjects", true)
        local g = soft(A, "Interface\\Cursor\\Quest", { guid = "Creature-0-1-2-3-4-5", quest = true })
        assert(not g or not g:IsShown(), "NPC glitzert")
    end)

    test("Glitzern: Plakette entfernt -> Glitzern weg", function()
        local A = boot(profile, locale)
        A:SetSparkleOption("sparkleHerbs", true)
        local g = soft(A, "Interface\\Cursor\\GatherHerbs")
        assert(g:IsShown())
        M.soft = nil
        M.FireEvent("NAME_PLATE_UNIT_REMOVED", "nameplate1")
        eq(g:IsShown(), false)
    end)

    test("Glitzern: Debug-Ausgabe nennt Plaketten-Einheit und GUID-Art", function()
        local A = boot(profile, locale)
        A:SetSparkleOption("sparkleHerbs", true)
        soft(A, "Interface\\Cursor\\GatherHerbs")
        SlashCmdList.EMBERSTONE("sparkle debug")
        assert(has(M.printed, "nameplate1"), "Einheit fehlt")
        assert(has(M.printed, "GameObject"), "GUID-Art fehlt")
    end)

    test("Glitzern: Glitzer-Grafik aus dem Addon-Ordner", function()
        local A = boot(profile, locale)
        A:SetSparkleOption("sparkleHerbs", true)
        local g = soft(A, "Interface\\Cursor\\GatherHerbs")
        eq(g.main._file, "Interface\\AddOns\\Emberstone\\Assets\\sparkle_glow.tga")
        eq(g.halo._file, "Interface\\AddOns\\Emberstone\\Assets\\glow.tga")
    end)

    -- -------- Variante B mit Rueckfall C --------
    test("Glitzern: Standard ist ein großes goldenes Leuchten unter der Plakette, additiv, pulsierend", function()
        local A = boot(profile, locale)
        A:SetSparkleOption("sparkleHerbs", true)
        M.profs = { 182 }
        local g = soft(A, "Interface\\Cursor\\GatherHerbs")
        eq(A:GetSetting("sparkleStyle"), "gold", "Voreinstellung")
        local pt = g._points[#g._points]
        eq(pt[1], "CENTER"); eq(pt[2], M.soft.plate, "an der Plakette"); eq(pt[3], "BOTTOM", "Unterkante")
        local mp = g.main._points[#g.main._points]
        assert(mp[5] < 0, "tiefer als die Unterkante (näher an der Pflanze)")
        eq(g.main._blend, "ADD", "Kern additiv")
        eq(g.halo._blend, "ADD", "Schein additiv")
        eq(g.main._file, "Interface\\AddOns\\Emberstone\\Assets\\sparkle_glow.tga")
        eq(g.halo._file, "Interface\\AddOns\\Emberstone\\Assets\\glow.tga")
        assert(g.main._color[1] == 1.0 and g.main._color[3] < 0.5, "Gold")
        local minW, maxW = 1e9, 0
        for _ = 1, 60 do
            g._scripts.OnUpdate(g, 0.05)
            minW = math.min(minW, g.main._w); maxW = math.max(maxW, g.main._w)
        end
        assert(minW >= 90, "deutlich größer als der erste Stern (48): " .. minW)
        assert(maxW - minW > 8, "pulsiert nicht")
        assert(g.halo._w > g.main._w, "Schein größer als der Kern")
    end)

    test("Glitzern: fünf Farben, gleiche Leuchtform - hell, schwach, grau bei allen", function()
        local A = boot(profile, locale)
        A:SetSparkleOption("sparkleHerbs", true)
        eq(#A.SparkleStyles, 5, "Anzahl Farben")
        local colors = {}
        for _, style in ipairs(A.SparkleStyles) do
            A:SetSparkleStyle(style.id)
            M.profs = { 182 }
            local g = soft(A, "Interface\\Cursor\\GatherHerbs")
            assert(g:IsShown(), style.id .. " nicht sichtbar")
            eq(g.main._file, "Interface\\AddOns\\Emberstone\\Assets\\sparkle_glow.tga", style.id .. " Leuchtform")
            local key = table.concat(g.main._color, ",")
            assert(not colors[key], style.id .. " gleiche Farbe wie eine andere Variante")
            colors[key] = true
            eq(g.main._color[1], style.color[1], style.id .. " Farbe")
            local alphas = {}
            for _ = 1, 40 do
                g._scripts.OnUpdate(g, 0.05)
                alphas[#alphas + 1] = g.main._alpha
            end
            local brightAlpha, brightW = math.max(unpack(alphas)), g.main._w
            soft(A, "Interface\\Cursor\\UnableGatherHerbs")
            g._scripts.OnUpdate(g, 0.05)
            assert(g.main._alpha < brightAlpha, style.id .. ": schwach nicht blasser")
            assert(g.main._w < brightW * 1.05, style.id .. ": schwach nicht kleiner")
            eq(g.main._color[1], style.color[1], style.id .. ": schwach behält die Farbe")
            M.profs = {}
            soft(A, "Interface\\Cursor\\GatherHerbs")
            g._scripts.OnUpdate(g, 0.05)
            eq(g.main._desat, true, style.id .. ": grau")
            eq(g.main._color[1], g.main._color[2], style.id .. ": grau statt farbig")
        end
    end)

    test("Glitzern: Farbwahl gespeichert, per Befehl und Optionen", function()
        local A = boot(profile, locale)
        SlashCmdList.EMBERSTONE("sparkle style 3")
        eq(A:GetSetting("sparkleStyle"), "arcane", "per Nummer")
        SlashCmdList.EMBERSTONE("sparkle style VIOLET")
        eq(A:GetSetting("sparkleStyle"), "violet", "per Name")
        assert(has(M.printed, A.L["SPARKLE_STYLE_VIOLET"]), "Bestätigung fehlt")
        SlashCmdList.EMBERSTONE("sparkle style kaputt")
        eq(A:GetSetting("sparkleStyle"), "violet", "ungültig ändert nichts")
        assert(has(M.printed, A.L["SPARKLE_STYLE_USAGE"]), "Hilfe fehlt")
        local buttons = A.SparklePanel.styleButtons
        eq(#buttons, 5, "fünf Knöpfe")
        buttons[2]._scripts.OnClick(buttons[2])
        eq(A:GetSetting("sparkleStyle"), "green", "Klick")
        for i, b in ipairs(buttons) do eq(b.border:IsShown(), i == 2, "Rahmen " .. i) end
        eq(buttons[2].preview.main._blend, "ADD", "Vorschau additiv")
        A.SparklePanel._scripts.OnUpdate(A.SparklePanel, 0.1) -- Vorschau pulsiert ohne Fehler
        EmberstoneCommon.sparkleStyle = "star" -- Wert aus der Vorfassung
        eq(A:GetSparkleStyle().id, "gold", "unbekannt -> Gold")
    end)

    test("Glitzern: Debug nennt die Leuchtfarbe", function()
        local A = boot(profile, locale)
        A:SetSparkleStyle("white")
        SlashCmdList.EMBERSTONE("sparkle debug")
        assert(has(M.printed, A.L["SPARKLE_STYLE_WHITE"]), "Farbe fehlt")
    end)

    test("Glitzern B: Symbol-Größe 0, alter Wert gespeichert und beim Ausschalten zurück", function()
        local A = boot(profile, locale)
        A:SetSparkleOption("sparkleOre", true)
        eq(M.cvars.SoftTargetNameplateSize, "0")
        eq(A:GetSparkleMode(), "B")
        A:SetSparkleOption("sparkleOre", false)
        eq(M.cvars.SoftTargetNameplateSize, "24", "zurück")
    end)

    -- Rueckfall-Waechter (ueberarbeitet nach Forever-Fund vom 12.10.2026: C wurde
    -- durch ein einziges Objekt ausgeloest und blieb dauerhaft)
    local HERB = "Cursor Crosshair_GatherHerbs_64" -- so auf Forever beobachtet
    local function settle() M.advance(11) end      -- Ruhezeit nach Login vorbei
    local function objectWithoutPlate(n, cursor)
        M.soft = { guid = "GameObject-0-1-2-3-1617-00" .. tostring(n or 1) }
        if cursor ~= false then M.soft.cursor = cursor or HERB end
        M.FireEvent("PLAYER_SOFT_INTERACT_CHANGED", "", "x")
    end
    local function threeWithoutPlate()
        for n = 1, 3 do objectWithoutPlate(n); M.advance(4.5) end
    end

    test("Glitzern B: Plakette kommt -> kein Rückfall", function()
        local A = boot(profile, locale)
        A:SetSparkleOption("sparkleHerbs", true)
        settle()
        soft(A, HERB)
        M.advance(5)
        eq(A:GetSparkleMode(), "B")
        eq(M.cvars.SoftTargetNameplateSize, "0")
    end)

    test("Glitzern B: Plakette kommt etwas später (1 s) -> kein Fehlversuch", function()
        local A = boot(profile, locale)
        A:SetSparkleOption("sparkleHerbs", true)
        settle()
        objectWithoutPlate(1)
        M.advance(1)
        soft(A, HERB)
        M.advance(5)
        eq(A:GetSparkleFallbackState().failCount, 0)
        eq(A:GetSparkleMode(), "B")
    end)

    test("Glitzern (Forever-Fund): EIN Objekt ohne Plakette löst C nicht mehr aus", function()
        local A = boot(profile, locale)
        A:SetSparkleOption("sparkleHerbs", true)
        settle()
        objectWithoutPlate(1)
        M.advance(10)
        eq(A:GetSparkleMode(), "B")
        eq(M.cvars.SoftTargetNameplateSize, "0")
        eq(A:GetSparkleFallbackState().failCount, 1, "als Fehlversuch gezählt")
    end)

    test("Glitzern: Deko-Objekte ohne Symbol (kein Cursor) zählen nicht", function()
        local A = boot(profile, locale)
        A:SetSparkleOption("sparkleHerbs", true)
        settle()
        for n = 1, 5 do objectWithoutPlate(n, false); M.advance(5) end
        eq(A:GetSparkleFallbackState().failCount, 0)
        eq(A:GetSparkleMode(), "B")
    end)

    test("Glitzern: dasselbe Objekt mehrfach zählt nur einmal", function()
        local A = boot(profile, locale)
        A:SetSparkleOption("sparkleHerbs", true)
        settle()
        for _ = 1, 4 do objectWithoutPlate(1); M.advance(5) end
        eq(A:GetSparkleFallbackState().failCount, 1)
        eq(A:GetSparkleMode(), "B")
    end)

    test("Glitzern: Ruhezeit nach Login - in den ersten 10 s wird nichts gewertet", function()
        local A = boot(profile, locale)
        A:SetSparkleOption("sparkleHerbs", true)
        objectWithoutPlate(1)
        M.advance(5)
        eq(A:GetSparkleFallbackState().failCount, 0, "nach Login")
        settle()
        M.FireEvent("PLAYER_ENTERING_WORLD") -- Ladebildschirm
        objectWithoutPlate(2)
        M.advance(5)
        eq(A:GetSparkleFallbackState().failCount, 0, "nach Ladebildschirm")
    end)

    test("Glitzern Rückfall C: erst bei 3 verschiedenen Objekten ohne Plakette (je 4 s)", function()
        local A = boot(profile, locale)
        A:SetSparkleOption("sparkleHerbs", true)
        settle()
        objectWithoutPlate(1); M.advance(4.5)
        objectWithoutPlate(2); M.advance(4.5)
        eq(A:GetSparkleMode(), "B", "nach 2 Objekten")
        objectWithoutPlate(3); M.advance(3)
        eq(A:GetSparkleMode(), "B", "3. Objekt erst nach 2 s geprüft")
        M.advance(1.5)
        eq(A:GetSparkleMode(), "C", "nach 3 Objekten")
        eq(M.cvars.SoftTargetNameplateSize, "24", "alter Wert zurück")
        assert(has(M.printed, A.L["SPARKLE_FALLBACK_NOTICE"]), "Hinweis fehlt")
        local last = EmberstoneCommon.sparkleLastFallback
        eq(last.objects, 3, "Grund: Anzahl"); eq(last.wait, 4, "Grund: Wartezeit"); eq(last.kind, "herb", "Grund: Art")
        eq(last.cursor, HERB, "Grund: Cursor")
        -- Mit Symbol erscheint das Leuchten darunter
        local g = soft(A, HERB)
        assert(g and g:IsShown(), "Leuchten in C")
        -- Ausschalten: alles zurück
        A:SetSparkleOption("sparkleHerbs", false)
        cvarsAre(SOFT_OLD, "alles zurück")
    end)

    test("Glitzern: unter B einmal Plakette gefunden -> in dieser Sitzung kein Rückfall mehr", function()
        local A = boot(profile, locale)
        A:SetSparkleOption("sparkleHerbs", true)
        settle()
        soft(A, HERB)
        M.advance(1)
        eq(A:GetSparkleFallbackState().confirmedB, true, "B bestätigt")
        threeWithoutPlate()
        eq(A:GetSparkleMode(), "B")
    end)

    test("Glitzern: nach Rückfall nach 10 Minuten automatisch neuer Versuch mit B", function()
        local A = boot(profile, locale)
        A:SetSparkleOption("sparkleHerbs", true)
        settle()
        threeWithoutPlate()
        eq(A:GetSparkleMode(), "C")
        M.soft = nil
        M.advance(590)
        eq(A:GetSparkleMode(), "C", "vor 10 Minuten")
        M.advance(20)
        eq(A:GetSparkleMode(), "B", "nach 10 Minuten")
        eq(M.cvars.SoftTargetNameplateSize, "0")
        eq(A:GetSparkleFallbackState().failCount, 0, "Zähler zurückgesetzt")
        -- Erneuter Rückfall: Chat-Hinweis nur einmal pro Sitzung
        threeWithoutPlate()
        eq(A:GetSparkleMode(), "C")
        local n = 0
        for _, l in ipairs(M.printed) do if l == A.L["SPARKLE_FALLBACK_NOTICE"] then n = n + 1 end end
        eq(n, 1, "Hinweis einmal")
    end)

    test("Glitzern: Rückfall gilt nur für die Sitzung - nach Neustart wieder B, Grund bleibt im Debug", function()
        local A = boot(profile, locale)
        A:SetSparkleOption("sparkleHerbs", true)
        settle()
        threeWithoutPlate()
        eq(A:GetSparkleMode(), "C")
        local saved = EmberstoneCommon
        saved.sparkleFallbackC = true -- Altlast aus der Testfassung
        M.reset(profile, locale)
        M.cvars.SoftTargetNameplateSize = "24"
        local A2 = M.LoadAddon(ROOT)
        EmberstoneCommon = saved
        M.FireEvent("ADDON_LOADED", "Emberstone")
        M.FireEvent("PLAYER_LOGIN")
        eq(A2:GetSparkleMode(), "B", "nach Neustart B")
        eq(M.cvars.SoftTargetNameplateSize, "0", "Symbol wieder aus")
        eq(EmberstoneCommon.sparkleFallbackC, nil, "Altlast entfernt")
        SlashCmdList.EMBERSTONE("sparkle debug")
        assert(has(M.printed, A2.L["SPARKLE_MODE_B"]), "Darstellung B")
        local reason = A2.L["SPARKLE_FB_LAST"]:sub(1, 10):gsub("%%s", "")
        local found = false
        for _, l in ipairs(M.printed) do if l:find(HERB, 1, true) then found = true end end
        assert(found, "Grund des letzten Rückfalls fehlt im Debug")
    end)

    test("Glitzern Rückfall C: CVAR_UPDATE ändert nichts, retry versucht B sofort", function()
        local A = boot(profile, locale)
        A:SetSparkleOption("sparkleHerbs", true)
        settle()
        threeWithoutPlate()
        M.cvars.SoftTargetNameplateSize = "30"
        M.FireEvent("CVAR_UPDATE", "SoftTargetNameplateSize", "30")
        M.advance(1)
        eq(M.cvars.SoftTargetNameplateSize, "30", "Spielerwert bleibt")
        SlashCmdList.EMBERSTONE("sparkle retry")
        eq(A:GetSparkleMode(), "B")
        eq(M.cvars.SoftTargetNameplateSize, "0")
        A:SetSparkleOption("sparkleHerbs", false)
        eq(M.cvars.SoftTargetNameplateSize, "30", "zurück auf den Spielerwert")
    end)

    test("Glitzern Rückfall C: nicht bei Zielwechsel, nicht im Kampf, nicht wenn alles aus", function()
        local A = boot(profile, locale)
        A:SetSparkleOption("sparkleHerbs", true)
        settle()
        for n = 1, 3 do objectWithoutPlate(n); M.advance(3); objectWithoutPlate(n + 10); M.advance(1) end
        eq(A:GetSparkleMode(), "B", "Zielwechsel")
        M.soft = nil; M.advance(10)
        M.inCombat = true
        threeWithoutPlate()
        eq(A:GetSparkleMode(), "B", "Kampf")
        M.inCombat = false
        A:SetSparkleOption("sparkleHerbs", false)
        threeWithoutPlate()
        eq(A:GetSparkleMode(), "B", "alles aus")
    end)

    test("Glitzern: Debug zeigt B bzw. C mit Zeitpunkt und Grund", function()
        local A = boot(profile, locale)
        A:SetSparkleOption("sparkleHerbs", true)
        SlashCmdList.EMBERSTONE("sparkle debug")
        assert(has(M.printed, A.L["SPARKLE_MODE_B"]), "B fehlt")
        assert(has(M.printed, A.L["SPARKLE_FB_NEVER"]), "\"nie\" fehlt")
        settle()
        threeWithoutPlate()
        SlashCmdList.EMBERSTONE("sparkle debug")
        assert(has(M.printed, A.L["SPARKLE_MODE_C"]), "C fehlt")
        assert(has(M.printed, HERB), "Cursor im Grund fehlt")
        assert(has(M.printed, os.date("%H:%M", os.time() + 600):sub(1, 2)), "nächster Versuch fehlt")
    end)

    -- -------- Kuerschnern --------
    -- So auf Forever beobachtet (Grosser Nachtsauger, Tirisfal): softinteract ist
    -- die Leiche (Creature-GUID), tot, Cursor "Cursor Crosshair_Skin_64" - aber
    -- es gibt KEINE Namensplakette (GetNamePlates leer).
    local SKIN = "Cursor Crosshair_Skin_64"
    local function corpse(cursor, extra)
        M.soft = { guid = "Creature-0-4621-0-175377-1553-00004D5D9C", dead = true, cursor = cursor or SKIN }
        for k, v in pairs(extra or {}) do M.soft[k] = v end
        M.FireEvent("PLAYER_SOFT_INTERACT_CHANGED", "", "x")
    end
    local function hint(A) return A._sparkleSkinHint() end
    local function shown(A) local h = hint(A); return h ~= nil and h:IsShown() end

    test("Kürschnern: ab Werk aus; mit Schalter Krallen-Leuchten neben dem Charakter, ohne Plakette", function()
        local A = boot(profile, locale)
        eq(A:GetSetting("sparkleSkinning"), false, "ab Werk aus")
        A:SetSparkleOption("sparkleHerbs", true)
        M.profs = { 393 }
        corpse()
        assert(not shown(A), "leuchtet ohne Schalter")
        A:SetSparkleOption("sparkleSkinning", true)
        corpse()
        assert(shown(A), "Krallen-Leuchten fehlt")
        local h = hint(A)
        local pt = h._points[#h._points]
        eq(pt[1], "CENTER"); eq(pt[2], UIParent, "an fester Stelle (UIParent)"); eq(pt[3], "CENTER")
        assert(pt[4] > 0, "rechts neben der Mitte")
        eq(h.main._file, "Interface\\AddOns\\Emberstone\\Assets\\sparkle_claw.tga", "Krallen-Grafik")
        eq(h.main._blend, "ADD", "additiv")
        eq(h.main._color[1], A:GetSparkleStyle().color[1], "Glitzerfarbe")
        local g = A._sparkleGlitter()
        assert(not g or not g:IsShown(), "kein Leuchten an einer Plakette")
        local minW, maxW = 1e9, 0
        for _ = 1, 40 do h._scripts.OnUpdate(h, 0.05); minW = math.min(minW, h.main._w); maxW = math.max(maxW, h.main._w) end
        assert(maxW - minW > 3, "pulsiert nicht")
        assert(maxW < 80, "unauffällig klein: " .. maxW)
    end)

    test("Kürschnern: Farbwahl wirkt sofort auch auf das Krallen-Leuchten", function()
        local A = boot(profile, locale)
        A:SetSparkleOption("sparkleSkinning", true)
        M.profs = { 393 }
        corpse()
        A:SetSparkleStyle("violet")
        eq(hint(A).main._color[1], A:GetSparkleStyle().color[1])
    end)

    test("Kürschnern: verschwindet sofort, wenn die Leiche nicht mehr ausgewählt ist", function()
        local A = boot(profile, locale)
        A:SetSparkleOption("sparkleSkinning", true)
        M.profs = { 393 }
        corpse()
        assert(shown(A))
        M.soft = nil
        M.FireEvent("PLAYER_SOFT_INTERACT_CHANGED", "x", "")
        eq(shown(A), false, "nach Abwahl")
        corpse()
        A:SetSparkleOption("sparkleSkinning", false)
        eq(shown(A), false, "Schalter aus")
    end)

    test("Kürschnern: im Kampf aus (schon beim Kampfbeginn), danach wieder da", function()
        local A = boot(profile, locale)
        A:SetSparkleOption("sparkleSkinning", true)
        M.profs = { 393 }
        corpse()
        M.FireEvent("PLAYER_REGEN_DISABLED") -- feuert vor der Kampfsperre
        eq(shown(A), false, "bei Kampfbeginn")
        M.inCombat = true
        corpse()
        eq(shown(A), false, "im Kampf")
        M.inCombat = false
        M.FireEvent("PLAYER_REGEN_ENABLED")
        eq(shown(A), true, "nach dem Kampf")
    end)

    test("Kürschnern: hell, schwach (außer Reichweite/Stufe zu niedrig), grau ohne Kürschnerei", function()
        local A = boot(profile, locale)
        A:SetSparkleOption("sparkleSkinning", true)
        M.profs = { 393 }
        corpse()
        eq(hint(A).look.name, "bright", "hell")
        corpse("Cursor Crosshair_UnableSkin_64")
        eq(hint(A).look.name, "dim", "schwach")
        M.profs = { 182, 186 }
        corpse()
        eq(hint(A).look.name, "grey", "grau ohne Kürschnerei")
        eq(hint(A).main._desat, true)
        -- Reichweite ändert sich ohne Zielwechsel: regelmäßige Neubewertung
        M.profs = { 393 }
        M.soft.cursor = "Cursor Crosshair_UnableSkin_64"
        hint(A)._scripts.OnUpdate(hint(A), 0.35)
        eq(hint(A).look.name, "dim", "neu bewertet")
    end)

    test("Kürschnern: plünderbare Leiche, lebender NPC und Spielobjekt zeigen nichts", function()
        local A = boot(profile, locale)
        A:SetSparkleOption("sparkleSkinning", true)
        corpse("Cursor Crosshair_LootAll_64")
        assert(not shown(A), "plünderbare Leiche")
        corpse(SKIN, { dead = false })
        assert(not shown(A), "lebender NPC")
        corpse(SKIN, { guid = "GameObject-0-1-2-3-1617-0001" })
        assert(not shown(A), "Spielobjekt mit Skin-Cursor")
    end)

    test("Kürschnern: bei Vertraeglichkeits-Konflikt aus", function()
        local A = boot(profile, locale, function() M.loadedAddons.Lueur = true end)
        A:SetSparkleOption("sparkleSkinning", true)
        corpse()
        assert(not shown(A))
    end)

    test("Kürschnern: Leichen lösen nie den Rückfall auf C aus", function()
        local A = boot(profile, locale)
        A:SetSparkleOption("sparkleSkinning", true)
        A:SetSparkleOption("sparkleHerbs", true)
        M.advance(11)
        for n = 1, 5 do
            M.soft = { guid = "Creature-0-1-2-3-1553-000" .. n, cursor = SKIN, dead = true }
            M.FireEvent("PLAYER_SOFT_INTERACT_CHANGED", "", "x")
            M.advance(5)
        end
        eq(A:GetSparkleFallbackState().failCount, 0, "keine Fehlversuche")
        eq(A:GetSparkleMode(), "B")
    end)

    test("Kürschnern: Blizzards Plaketten werden nicht angefasst (Lebensbalken-Code entfernt)", function()
        local A = boot(profile, locale)
        A:SetSparkleOption("sparkleSkinning", true)
        M.profs = { 393 }
        -- selbst wenn es eine Plakette gäbe: kein Eingriff mehr
        local bar = M.NewFrame("Frame")
        local plate = M.NewFrame("Frame"); plate.GetUnit = function() return "nameplate1" end
        rawset(plate, "UnitFrame", { HealthBarsContainer = bar })
        corpse(SKIN, { token = "nameplate1", plate = plate })
        M.FireEvent("NAME_PLATE_UNIT_ADDED", "nameplate1")
        eq(bar._alpha, nil, "Lebensbalken unberührt")
        eq(A._sparkleHiddenBar, nil, "Code entfernt")
    end)

    test("Kürschnern: Debug zeigt softinteract-ID, tot und Cursor ohne Plakette", function()
        local A = boot(profile, locale)
        A:SetSparkleOption("sparkleSkinning", true)
        M.profs = { 393 }
        corpse()
        SlashCmdList.EMBERSTONE("sparkle debug")
        assert(has(M.printed, "Creature-0-4621-0-175377-1553-00004D5D9C"), "ID fehlt")
        assert(has(M.printed, SKIN), "Cursor fehlt")
        local line
        for _, l in ipairs(M.printed) do if l:find("Creature-0-4621", 1, true) then line = l end end
        assert(line:find("true", 1, true), "tot/häutbar fehlt")
        SlashCmdList.EMBERSTONE("sparkle")
        local status = string.format(A.L["SPARKLE_STATUS"], A.L["SPARKLE_STATE_ON"], A.L["SPARKLE_STATE_OFF"],
            A.L["SPARKLE_STATE_OFF"], A.L["SPARKLE_STATE_OFF"], A.L["SPARKLE_STATE_ON"])
        assert(has(M.printed, status), "Status ohne Kürschnern")
    end)

    test("Glitzern: /emberstone sparkle und sparkle debug ohne Fehler", function()
        local A = boot(profile, locale)
        SlashCmdList.EMBERSTONE("sparkle")
        SlashCmdList.EMBERSTONE("sparkle debug")
        assert(#M.printed >= 2)
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
