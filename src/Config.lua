-- config.lua
local ADDON_NAME, Addon = ...

Addon.DefaultDelay = 3
Addon.DefaultPvPDelay = 2
Addon.DefaultThreshold = 1
Addon.DefaultScreenshotQuality = 5 -- 0-10, siehe Addon:TakeScreenshot (Screenshots.lua)

Addon.Defaults = {
    -- Eigene Meilensteine (Screenshots) - urspruenglich das Addon "Ding"
    enableAchievementShots        = false,
    enableArenaWinShots           = true,
    enableBattlegroundWinShots    = false,
    enableBossShots               = false,
    enableChallengeNewRecordShots = false,
    enableChallengeShots          = false,
    enableDelveShots              = false,
    enableLevelShots              = true,

    -- Seltene Beute / Weltboss-Kills (siehe features/RareKill.lua). Standardmaessig
    -- AUS: im Unterschied zu Boss-/Level-Erkennung (eigene, dedizierte Blizzard-
    -- Events) beruht das hier auf periodischer UNIT_HEALTH-Beobachtung des
    -- eigenen Ziels - technisch neu und in Forever noch nicht ueber laengere
    -- Zeit im Einsatz getestet, deshalb bewusst konservativ defaultet.
    enableRareKillShots           = false,
    enableWorldBossKillShots      = false,
    rareKillDelay                 = Addon.DefaultDelay,
    worldBossKillDelay            = Addon.DefaultDelay,

    achievementDelay              = Addon.DefaultDelay,
    bossDelay                     = Addon.DefaultDelay,
    challengeDelay                = Addon.DefaultDelay,
    challengeNewRecordDelay       = Addon.DefaultDelay,
    delveDelay                    = Addon.DefaultDelay,
    levelDelay                    = Addon.DefaultDelay,
    onlyRatedArena                = false,
    onlyRatedBattlegrounds        = false,
    preventDuplicates             = true,
    duplicateThreshold            = Addon.DefaultThreshold,
    lastScreenshotTime            = 0,

    -- Anti-Lag: siehe Screenshots.lua fuer die Begruendung/Grenzen dieses Mechanismus
    reduceQualityForShots         = true,
    screenshotQuality             = Addon.DefaultScreenshotQuality,

    -- Sonstiges
    -- Rein lokale Erinnerung (kein Chat-/Gilden-Versand) nach jedem Bosskill,
    -- ob man ein Gruppenfoto machen moechte. Auf Wunsch standardmaessig AUS.
    groupPhotoReminderEnabled     = false,

    -- Gildenweite Levelup-Benachrichtigungen - urspruenglich das eigenstaendige Addon "GrindDing"
    guildDingEnabled              = true,
    guildDingChat                 = true,
    guildDingScreen               = true,
    guildDingPollInterval         = 15, -- Sekunden zwischen zwei Gilden-Roster-Abfragen; siehe GuildDing.lua
    guildDingAutoGZGuild          = false, -- automatisch "Glueckwunsch ..." in den Gildenchat schreiben (siehe GuildDing.lua:SendAutoGZ)
    guildDingAutoGZWhisper        = false, -- automatisch dem betreffenden Mitglied per Fluestern gratulieren
    guildDingAutoGZGuildRandom    = false, -- zufaellige Variante aus dem Gildenchat-Pool statt des einzelnen festen Texts
    guildDingAutoGZWhisperRandom  = false, -- zufaellige Variante aus dem Fluester-Pool statt des einzelnen festen Texts
}

-- Account-weite Einstellungen
function Addon:GetSetting(key)
    return EmberstoneCommon[key]
end

function Addon:SetSetting(key, value)
    EmberstoneCommon[key] = value
end

-- Charakterbezogene Einstellungen
function Addon:GetCharacterSetting(key)
    return EmberstoneCharacter[key]
end

function Addon:SetCharacterSetting(key, value)
    EmberstoneCharacter[key] = value
end

----------------------------------------------------------------------------------------------
-- Migration von den Vorgaenger-Addons, die zu Emberstone zusammengelegt bzw.
-- umbenannt wurden:
--  - "RemGrind" (der direkte Vorgaenger, nur umbenannt: SavedVariables RemGrindCommon / RemGrindCharacter)
--  - dem reinen Screenshot-Addon "Ding" (SavedVariables: DingCommon / DingCharacter)
--  - dem gildenweiten Levelup-Addon "GrindDing" (SavedVariables: GrindDingDB)
-- Bestehende Einstellungen und der bereits gesammelte Gilden-Level-Cache gehen
-- dadurch beim Umstieg nicht verloren.
--
-- WICHTIG: Diese alten globalen Variablen sind nur dann ueberhaupt gefuellt,
-- wenn das jeweilige alte Addon zum Zeitpunkt des Logins noch installiert UND
-- aktiviert war (WoW laedt SavedVariables nur fuer Addons, die es tatsaechlich
-- startet). Wurde der alte Ordner schon vorher geloescht, sind die Daten fuer
-- Emberstone nicht mehr erreichbar - dieser Fall wird hier absichtlich still
-- uebersprungen (kein Fehler), da nichts mehr zu migrieren ist.
----------------------------------------------------------------------------------------------
-- Ein Vorgaenger gilt nur dann als uebernommen, wenn seine Daten wirklich
-- vorhanden waren - sonst wuerde ein Vorgaenger, der zufaellig erst nach
-- Emberstone geladen wird, nie mehr uebernommen. (Die .toc nennt die
-- Vorgaenger deshalb ausserdem als OptionalDeps, damit sie vorher laden.)
local function CopyMissing(src, dst)
    if type(src) ~= "table" or type(dst) ~= "table" then return false end
    for key, value in pairs(src) do
        if dst[key] == nil then dst[key] = value end
    end
    return true
end

function Addon:MigrateLegacyData()
    if not EmberstoneCommon.migratedFromRemGrind then
        local a = CopyMissing(RemGrindCommon, EmberstoneCommon)
        local b = CopyMissing(RemGrindCharacter, EmberstoneCharacter)
        if a or b then EmberstoneCommon.migratedFromRemGrind = true end
    end

    if not EmberstoneCommon.migratedFromDing then
        local a = CopyMissing(DingCommon, EmberstoneCommon)
        local b = CopyMissing(DingCharacter, EmberstoneCharacter)
        if a or b then EmberstoneCommon.migratedFromDing = true end
    end

    if not EmberstoneCommon.migratedFromGrindDing and type(GrindDingDB) == "table" then
        if type(GrindDingDB.config) == "table" then
            EmberstoneCommon.guildDingEnabled = GrindDingDB.config.enabled and true or false
            EmberstoneCommon.guildDingScreen  = GrindDingDB.config.screen and true or false
            EmberstoneCommon.guildDingChat    = GrindDingDB.config.chat and true or false
        end
        if type(GrindDingDB.levels) == "table" then
            EmberstoneCommon.guildLevels = EmberstoneCommon.guildLevels or {}
            for name, level in pairs(GrindDingDB.levels) do
                EmberstoneCommon.guildLevels[name] = level
            end
        end
        EmberstoneCommon.migratedFromGrindDing = true
    end
end
