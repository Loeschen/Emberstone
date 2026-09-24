-- locale.lua
--
-- Einfache, abhaengigkeitsfreie Lokalisierung (bewusst keine externe
-- Bibliothek wie AceLocale-3.0, siehe z.B. Grindkeeps eigene kleine
-- Base64-Implementierung fuer dieselbe Haltung: fuer diesen Umfang an
-- Text reicht eine simple Tabelle, ohne eine weitere Abhaengigkeit
-- einzufuehren). Englisch ist die Standardsprache (Blizzards eigene
-- Konvention und der ueberwiegende Teil des CurseForge-Publikums),
-- Deutsch wird automatisch verwendet, wenn der Client auf "deDE" steht.
--
-- Muss als ERSTE Datei geladen werden (siehe Emberstone.toc), da so gut
-- wie jede andere Datei Addon.L[...] fuer sichtbaren Text verwendet.
--
-- Faellt ein Schluessel in der aktuellen Sprache aus (Tippfehler, neuer
-- Schluessel ohne Uebersetzung), liefert L[key] automatisch Englisch
-- zurueck statt eines Lua-Fehlers oder eines leeren Strings.
local ADDON_NAME, Addon = ...

local locale = (GetLocale() == "deDE") and "deDE" or "enUS"

local STRINGS = {
    -- Commands.lua
    OPTIONS_UNAVAILABLE = {
        enUS = "Emberstone: The options window could not be opened. You can still test the guild notification with /emberstone test.",
        deDE = "Emberstone: Das Optionsfenster konnte nicht geoeffnet werden. Mit /emberstone test kannst du trotzdem die Gilden-Benachrichtigung ausprobieren.",
    },

    -- Screenshots.lua
    -- WICHTIG: %s/%d muessen in EXAKT derselben Reihenfolge auftreten wie in
    -- deDE (Aufrufer uebergibt die Argumente einmal, unabhaengig von der
    -- Sprache: playerName, charTotal, total) - sonst landen die Werte in
    -- der falschen Reihenfolge im Text bzw. string.format wirft einen Fehler.
    SCREENSHOT_TOTAL = {
        enUS = "%s: Emberstone has taken %d screenshots so far (%d total on this account).",
        deDE = "Emberstone hat fuer %s bisher %d Screenshots gesammelt (%d insgesamt auf diesem Account).",
    },
    SCREENSHOT_SAVED = {
        enUS = "Emberstone saved a screenshot.",
        deDE = "Emberstone hat einen Screenshot gespeichert.",
    },

    -- GuildDing.lua
    GUILD_DING_CHAT = {
        enUS = "%s reached level |cFFFFD100%d|r! Congratulations!",
        deDE = "%s hat Level |cFFFFD100%d|r erreicht! Herzlichen Glueckwunsch!",
    },
    GUILD_DING_SCREEN = {
        enUS = "%s reached level %d!",
        deDE = "%s hat Level %d erreicht!",
    },
    GUILD_DING_TEST_CHAT = {
        enUS = "%s reached level |cFFFFD1000|r! (test message, not a real level-up)",
        deDE = "%s hat Level |cFFFFD1000|r erreicht! (Testnachricht, kein echter Levelaufstieg)",
    },
    GUILD_DING_TEST_SCREEN = {
        enUS = "%s reached level 0! (test)",
        deDE = "%s hat Level 0 erreicht! (Test)",
    },
    GENERIC_YOU = { enUS = "You", deDE = "Du" },

    -- UI.lua - Sektionen auf der Hauptseite
    OPT_SECTION_PREVENT_DUPES  = { enUS = "Not Too Many At Once", deDE = "Nicht zu viele auf einmal" },
    OPT_SECTION_LESS_LAG       = { enUS = "Less Stutter", deDE = "Weniger Ruckler" },
    OPT_SECTION_GUILD          = { enUS = "For the Whole Guild", deDE = "Fuer die ganze Gilde" },
    OPT_SECTION_MISC           = { enUS = "Miscellaneous", deDE = "Sonstiges" },

    -- UI.lua - Themen-Unterseiten (seit v1.9, siehe CreateSubcategory).
    -- Faellt RegisterVerticalLayoutSubcategory aus, werden dieselben Texte
    -- als Abschnitts-Ueberschriften auf der Hauptseite verwendet - sie
    -- muessen also in beiden Rollen sinnvoll lesbar sein.
    OPT_MAIN_SUBCATEGORY_HINT = {
        enUS = "The individual screenshot events are in the subpages on the left (achievements, dungeons, Mythic+, rares, PvP, guild).",
        deDE = "Die einzelnen Screenshot-Ereignisse stehen in den Unterpunkten links (Erfolge, Dungeons, Mythic+, seltene Gegner, PvP, Gilde).",
    },
    OPT_SUBCAT_ACHIEVEMENTS = { enUS = "Achievements & Levels", deDE = "Erfolge & Level" },
    OPT_SUBCAT_DUNGEONS     = { enUS = "Dungeons & Delves", deDE = "Dungeons & Tiefen" },
    OPT_SUBCAT_MYTHICPLUS   = { enUS = "Mythic+", deDE = "Mythic+" },
    OPT_SUBCAT_RARES        = { enUS = "Rares & World Bosses", deDE = "Seltene Gegner & Weltbosse" },
    OPT_SUBCAT_PVP          = { enUS = "PvP", deDE = "PvP" },

    OPT_GROUP_PHOTO_LABEL = { enUS = "Group photo reminder after boss kills", deDE = "Gruppenfoto-Erinnerung nach Bosskills" },
    OPT_GROUP_PHOTO_TOOLTIP = {
        enUS = "Shows a short local reminder to yourself after every boss kill, suggesting a group screenshot. No message is sent to anyone else.",
        deDE = "Zeigt dir nach jedem Bosskill eine kurze, rein lokale Erinnerung, ob ihr ein Gruppenfoto machen wollt. Es wird dabei niemandem sonst eine Nachricht geschickt.",
    },
    GROUP_PHOTO_REMINDER = {
        enUS = "Boss defeated! Time for a group photo? (/screenshot)",
        deDE = "Boss besiegt! Zeit fuer ein Gruppenfoto? (/screenshot)",
    },

    OPT_FOREVER_UNCERTAIN = {
        enUS = " (likely not yet available in WoW Forever)",
        deDE = " (in WoW Forever aktuell vermutlich noch nicht verfuegbar)",
    },

    -- UI.lua - eigene Meilensteine (Screenshot-Ereignisse)
    OPT_EVENT_ACHIEVEMENT_LABEL = { enUS = "Achievement earned", deDE = "Achievement geschafft" },
    OPT_EVENT_ACHIEVEMENT_TOOLTIP = {
        enUS = "Automatically takes a screenshot when you earn an achievement.",
        deDE = "Haelt automatisch einen Screenshot fest, wenn du ein Achievement erhaeltst.",
    },
    OPT_EVENT_BOSS_LABEL = { enUS = "Boss defeated", deDE = "Boss besiegt" },
    OPT_EVENT_BOSS_TOOLTIP = {
        enUS = "Automatically takes a screenshot when you defeat a boss.",
        deDE = "Haelt automatisch einen Screenshot fest, wenn du einen Boss besiegst.",
    },
    OPT_EVENT_DELVE_LABEL = { enUS = "Delve completed", deDE = "Delve abgeschlossen" },
    OPT_EVENT_DELVE_TOOLTIP = {
        enUS = "Automatically takes a screenshot when you complete a delve.",
        deDE = "Haelt automatisch einen Screenshot fest, wenn du ein Delve abschliesst.",
    },
    OPT_EVENT_LEVEL_LABEL = { enUS = "Leveled up", deDE = "Level aufgestiegen" },
    OPT_EVENT_LEVEL_TOOLTIP = {
        enUS = "Automatically takes a screenshot when you reach a new level.",
        deDE = "Haelt automatisch einen Screenshot fest, wenn du ein neues Level erreichst.",
    },
    OPT_EVENT_CHALLENGE_LABEL = { enUS = "Mythic+ completed", deDE = "Mythic+ abgeschlossen" },
    OPT_EVENT_CHALLENGE_TOOLTIP = {
        enUS = "Automatically takes a screenshot when you complete a Mythic+.",
        deDE = "Haelt automatisch einen Screenshot fest, wenn du ein Mythic+ abschliesst.",
    },
    OPT_EVENT_CHALLENGE_RECORD_LABEL = { enUS = "New Mythic+ record", deDE = "Neuer Mythic+ Rekord" },
    OPT_EVENT_CHALLENGE_RECORD_TOOLTIP = {
        enUS = "Automatically takes a screenshot when you set a new Mythic+ record.",
        deDE = "Haelt automatisch einen Screenshot fest, wenn du einen neuen Mythic+ Rekord aufstellst.",
    },
    OPT_EVENT_RARE_KILL_LABEL = { enUS = "Rare mob killed", deDE = "Rar-Mob getoetet" },
    OPT_EVENT_RARE_KILL_TOOLTIP = {
        enUS = "Automatically takes a screenshot when your current target, classified as a rare or rare elite, dies. Detected via your target's health, not the combat log.",
        deDE = "Haelt automatisch einen Screenshot fest, wenn dein anvisiertes Ziel (als Rar oder Rar-Elite eingestuft) stirbt. Wird ueber die Lebenspunkte deines Ziels erkannt, nicht ueber das Kampf-Logbuch.",
    },
    OPT_EVENT_WORLDBOSS_KILL_LABEL = { enUS = "World boss killed", deDE = "Weltboss getoetet" },
    OPT_EVENT_WORLDBOSS_KILL_TOOLTIP = {
        enUS = "Automatically takes a screenshot when your current target, classified as a world boss, dies. Detected via your target's health, not the combat log.",
        deDE = "Haelt automatisch einen Screenshot fest, wenn dein anvisiertes Ziel (als Weltboss eingestuft) stirbt. Wird ueber die Lebenspunkte deines Ziels erkannt, nicht ueber das Kampf-Logbuch.",
    },

    OPT_EVENT_DELAY_SUFFIX = { enUS = " \226\128\147 delay", deDE = " \226\128\147 Wartezeit" },
    OPT_EVENT_DELAY_TOOLTIP = {
        enUS = "How many seconds Emberstone waits before triggering the screenshot.",
        deDE = "Wie viele Sekunden Emberstone wartet, bevor der Screenshot ausgeloest wird.",
    },

    OPT_ARENA_WIN_LABEL = { enUS = "Arena won", deDE = "Arena gewonnen" },
    OPT_ARENA_WIN_TOOLTIP = {
        enUS = "Automatically takes a screenshot when you win an arena match.%s (Blizzard has not announced an arena format for Forever yet.)",
        deDE = "Haelt automatisch einen Screenshot fest, wenn du einen Arenakampf gewinnst.%s (Blizzard hat fuer Forever bisher kein Arena-Format angekuendigt).",
    },
    OPT_ONLY_RATED_ARENA_LABEL = { enUS = "Rated matches only", deDE = "Nur gewertete Kaempfe" },
    OPT_ONLY_RATED_ARENA_TOOLTIP = {
        enUS = "Only triggers on rated arena matches, not normal ones.%s",
        deDE = "Loest nur bei gewerteten Arenakaempfen aus, nicht bei normalen.%s",
    },
    OPT_BG_WIN_LABEL = { enUS = "Battleground won", deDE = "Schlachtfeld gewonnen" },
    OPT_BG_WIN_TOOLTIP = {
        enUS = "Automatically takes a screenshot when you win a battleground.",
        deDE = "Haelt automatisch einen Screenshot fest, wenn du ein Schlachtfeld gewinnst.",
    },
    OPT_ONLY_RATED_BG_LABEL = { enUS = "Rated battlegrounds only", deDE = "Nur gewertete Schlachtfelder" },
    OPT_ONLY_RATED_BG_TOOLTIP = {
        enUS = "Only triggers on rated battlegrounds, not normal ones.%s (Blizzard has not announced rated PvP for Forever yet.)",
        deDE = "Loest nur bei gewerteten Schlachtfeldern aus, nicht bei normalen.%s (Blizzard hat fuer Forever bisher kein gewertetes PvP angekuendigt).",
    },

    OPT_PREVENT_DUPES_LABEL = { enUS = "Prevent duplicate screenshots", deDE = "Doppelte Screenshots vermeiden" },
    OPT_PREVENT_DUPES_TOOLTIP = {
        enUS = "Prevents multiple screenshots for the same event, e.g. when a boss kill also triggers an achievement.",
        deDE = "Verhindert mehrere Screenshots fuer dasselbe Ereignis, z.B. wenn ein Bosskill gleichzeitig ein Achievement ausloest.",
    },
    OPT_DUPLICATE_THRESHOLD_LABEL = { enUS = "Minimum spacing", deDE = "Mindestabstand" },
    OPT_DUPLICATE_THRESHOLD_TOOLTIP = {
        enUS = "How many seconds must pass at minimum between two automatic screenshots.",
        deDE = "Wie viele Sekunden mindestens zwischen zwei automatischen Screenshots liegen sollen.",
    },

    OPT_REDUCE_QUALITY_LABEL = { enUS = "Reduce stutter", deDE = "Ruckler reduzieren" },
    OPT_REDUCE_QUALITY_TOOLTIP = {
        enUS = "Briefly lowers image quality right before an automatic screenshot and restores it afterwards. Your manual screenshots (Print Screen key) are unaffected.",
        deDE = "Senkt kurz vor einem automatischen Screenshot die Bildqualitaet ab und stellt sie danach wieder her. Deine manuellen Screenshots (Druck-Taste) bleiben davon unberuehrt.",
    },
    OPT_SCREENSHOT_QUALITY_LABEL = { enUS = "Image quality", deDE = "Bildqualitaet" },
    OPT_SCREENSHOT_QUALITY_TOOLTIP = {
        enUS = "0 = small file, barely noticeable stutter. 10 = best quality, longer stutter.",
        deDE = "0 = kleine Datei, kaum spuerbarer Ruckler. 10 = beste Qualitaet, laengerer Ruckler.",
    },

    OPT_GUILD_ENABLED_LABEL = { enUS = "Report guild level-ups", deDE = "Levelaufstiege der Gilde melden" },
    OPT_GUILD_ENABLED_TOOLTIP = {
        enUS = "Watches your online guild roster and reports when a member reaches a new level. When disabled, background polling also stops entirely.",
        deDE = "Beobachtet dein Online-Gilden-Roster und meldet, wenn ein Mitglied ein neues Level erreicht. Ausgeschaltet laufen auch keine Hintergrund-Abfragen mehr.",
    },
    OPT_GUILD_SCREEN_LABEL = { enUS = "On-screen message", deDE = "Bildschirm-Meldung" },
    OPT_GUILD_SCREEN_TOOLTIP = {
        enUS = "Shows a large on-screen message when someone in your guild levels up.",
        deDE = "Zeigt eine grosse Meldung auf dem Bildschirm, wenn jemand aus deiner Gilde aufsteigt.",
    },
    OPT_GUILD_CHAT_LABEL = { enUS = "Chat message", deDE = "Chat-Meldung" },
    OPT_GUILD_CHAT_TOOLTIP = {
        enUS = "Writes a chat message when someone in your guild levels up.",
        deDE = "Schreibt eine Nachricht in den Chat, wenn jemand aus deiner Gilde aufsteigt.",
    },
    OPT_GUILD_POLL_INTERVAL_LABEL = { enUS = "Poll frequency", deDE = "Abfrage-Haeufigkeit" },
    OPT_GUILD_POLL_INTERVAL_TOOLTIP = {
        enUS = "How often (in seconds) Emberstone checks in the background whether someone leveled up. Larger intervals mean fewer background requests, but slightly later notifications.",
        deDE = "Wie oft (in Sekunden) Emberstone im Hintergrund nachschaut, ob jemand aufgestiegen ist. Groessere Abstaende bedeuten weniger Hintergrundanfragen, aber etwas spaetere Meldungen.",
    },

    -- GuildDing.lua - automatische Gratulation (sendet echte Chat-Nachrichten,
    -- daher eigene, standardmaessig deaktivierte Optionen statt an die reine
    -- Anzeige oben (guildDingChat/guildDingScreen) gekoppelt zu sein.
    OPT_GUILD_AUTOGZ_GUILD_LABEL = { enUS = "Auto-congratulate in guild chat", deDE = "Automatisch im Gildenchat gratulieren" },
    OPT_GUILD_AUTOGZ_GUILD_TOOLTIP = {
        enUS = "Automatically writes a congratulation message in guild chat when someone in your guild levels up. Off by default - can get noisy if several members level up around the same time.",
        deDE = "Schreibt automatisch eine Glueckwunsch-Nachricht in den Gildenchat, wenn jemand aus deiner Gilde aufsteigt. Standardmaessig aus - kann unruhig werden, wenn mehrere Mitglieder gleichzeitig leveln.",
    },
    OPT_GUILD_AUTOGZ_WHISPER_LABEL = { enUS = "Auto-congratulate via whisper", deDE = "Automatisch per Fluestern gratulieren" },
    OPT_GUILD_AUTOGZ_WHISPER_TOOLTIP = {
        enUS = "Automatically whispers the member directly when they level up. Off by default - some members may not want an automatic whisper.",
        deDE = "Fluestert dem Mitglied automatisch direkt, wenn es aufsteigt. Standardmaessig aus - manche Mitglieder moechten vielleicht keine automatische Fluesternachricht.",
    },
    GUILD_DING_GZ_GUILD = {
        enUS = "Congratulations %s on level %d!",
        deDE = "Glueckwunsch %s zum Level %d!",
    },
    GUILD_DING_GZ_WHISPER = {
        enUS = "Congratulations on level %d!",
        deDE = "Glueckwunsch zum Level %d!",
    },
    GUILD_DING_GZ_SEND_FAILED = {
        enUS = "Emberstone: Auto-congratulation could not be sent (channel unavailable?).",
        deDE = "Emberstone: Automatische Gratulation konnte nicht gesendet werden (Kanal nicht verfuegbar?).",
    },

    -- GuildDing.lua - eigener, einstellbarer Nachrichtentext (/emberstone gzmsg ...)
    -- Die frueheren Options-Buttons dafuer (v1.4, CreateSettingsButtonInitializer)
    -- erschienen auf WoW Forever nie - seit v1.8 gibt es echte Buttons direkt in
    -- der Unterkategorie "Fuer die ganze Gilde" (UI.lua), gebaut mit ganz
    -- normalen CreateFrame-Buttons statt der offenbar kaputten Settings-
    -- Listen-API. Der Slash-Befehl bleibt trotzdem als Alternative bestehen.
    OPT_GUILD_AUTOGZ_GUILD_RANDOM_LABEL = { enUS = "Use random guild-chat variant", deDE = "Zufaellige Gildenchat-Variante nutzen" },
    OPT_GUILD_AUTOGZ_GUILD_RANDOM_TOOLTIP = {
        enUS = "Picks randomly from your guild-chat text variants (/emberstone gzmsg guild pool ...) instead of always using the single fixed text.",
        deDE = "Waehlt zufaellig aus deinen Gildenchat-Textvarianten (/emberstone gzmsg guild pool ...), statt immer den einen festen Text zu nutzen.",
    },
    OPT_GUILD_AUTOGZ_WHISPER_RANDOM_LABEL = { enUS = "Use random whisper variant", deDE = "Zufaellige Fluester-Variante nutzen" },
    OPT_GUILD_AUTOGZ_WHISPER_RANDOM_TOOLTIP = {
        enUS = "Picks randomly from your whisper text variants (/emberstone gzmsg whisper pool ...) instead of always using the single fixed text.",
        deDE = "Waehlt zufaellig aus deinen Fluester-Textvarianten (/emberstone gzmsg whisper pool ...), statt immer den einen festen Text zu nutzen.",
    },
    GZMSG_HELP = {
        enUS = "Usage: /emberstone gzmsg guild <text> | /emberstone gzmsg whisper <text> | /emberstone gzmsg guild|whisper pool add|remove|list | /emberstone gzmsg guild|whisper random on|off | /emberstone gzmsg reset (without text, opens an edit window instead).",
        deDE = "Verwendung: /emberstone gzmsg guild <Text> | /emberstone gzmsg whisper <Text> | /emberstone gzmsg guild|whisper pool add|remove|list | /emberstone gzmsg guild|whisper random on|off | /emberstone gzmsg reset (ohne Text oeffnet sich stattdessen ein Eingabefenster).",
    },
    GZMSG_CURRENT_GUILD = { enUS = "Current guild-chat text: %s", deDE = "Aktueller Gildenchat-Text: %s" },
    GZMSG_CURRENT_WHISPER = { enUS = "Current whisper text: %s", deDE = "Aktueller Fluester-Text: %s" },
    GZMSG_INVALID = {
        enUS = "Invalid text - it must contain exactly these placeholders, in this order: %s",
        deDE = "Ungueltiger Text - er muss genau diese Platzhalter in dieser Reihenfolge enthalten: %s",
    },
    GZMSG_PLACEHOLDERS_GUILD = { enUS = "%s (name), %d (level)", deDE = "%s (Name), %d (Level)" },
    GZMSG_PLACEHOLDERS_WHISPER = { enUS = "%d (level)", deDE = "%d (Level)" },
    GZMSG_SAVED = { enUS = "Saved.", deDE = "Gespeichert." },
    GZMSG_RESET_DONE = { enUS = "Both message texts were reset to default.", deDE = "Beide Nachrichtentexte wurden auf Standard zurueckgesetzt." },
    -- WICHTIG: Dieser Text landet als StaticPopupDialogs["..."].text direkt in
    -- Blizzards eigenem Dialog-Frame. Auf diesem Client ruft GameDialog.lua
    -- dafuer IMMER SetFormattedText(text, text_arg1, text_arg2) auf, auch wenn
    -- StaticPopup_Show ganz ohne Formatargumente aufgerufen wird - ein echtes
    -- "%s"/"%d" im Text (hier bewusst als Erklaerungstext gemeint, nicht als
    -- Platzhalter fuer dieses Popup) wird dann als fehlendes Argument gewertet
    -- und wirft einen Lua-Fehler ("string expected, got nil"). Deshalb werden
    -- die Prozentzeichen hier als "%%s"/"%%d" escaped, damit SetFormattedText
    -- sie als reinen Text ausgibt statt als Platzhalter zu behandeln.
    GZMSG_EDIT_GUILD_TITLE = {
        enUS = "Guild-chat congratulation text (must contain %%s for the name and %%d for the level, in that order):",
        deDE = "Gildenchat-Glueckwunschtext (muss %%s fuer den Namen und %%d fuer das Level enthalten, in dieser Reihenfolge):",
    },
    GZMSG_EDIT_WHISPER_TITLE = {
        enUS = "Whisper congratulation text (must contain %%d for the level):",
        deDE = "Fluester-Glueckwunschtext (muss %%d fuer das Level enthalten):",
    },

    -- UI.lua / GuildDing.lua - echte Buttons (seit v1.8 direkt in der
    -- "Fuer die ganze Gilde"-Unterkategorie), Ersatz fuer die kaputten
    -- v1.4-Buttons.
    GZ_EDITOR_SECTION_GUILD = { enUS = "Guild chat", deDE = "Gildenchat" },
    GZ_EDITOR_SECTION_WHISPER = { enUS = "Whisper", deDE = "Fluestern" },
    GZ_EDITOR_EDIT_BUTTON = { enUS = "Edit text", deDE = "Text bearbeiten" },
    GZ_EDITOR_POOL_BUTTON = { enUS = "Manage variants", deDE = "Varianten verwalten" },

    -- GuildDing.lua - mehrzeiliger Varianten-Editor (echtes Fenster, kein StaticPopup)
    GZPOOL_EDITOR_TITLE_GUILD = { enUS = "Guild-chat variants", deDE = "Gildenchat-Varianten" },
    GZPOOL_EDITOR_TITLE_WHISPER = { enUS = "Whisper variants", deDE = "Fluester-Varianten" },
    GZPOOL_EDITOR_HINT = {
        enUS = "One text per line. Guild-chat texts need %s (name) and %d (level), whisper texts need %d (level). Invalid lines are rejected and reported in the chat window when you save.",
        deDE = "Ein Text pro Zeile. Gildenchat-Texte brauchen %s (Name) und %d (Level), Fluester-Texte brauchen %d (Level). Ungueltige Zeilen werden beim Speichern abgelehnt und im Chatfenster gemeldet.",
    },
    GZPOOL_EDITOR_SAVE = { enUS = "Save", deDE = "Speichern" },
    GZPOOL_EDITOR_BAD_LINES = {
        enUS = "Emberstone: Nothing saved - line(s) %s are invalid or too long. Required placeholders: %s",
        deDE = "Emberstone: Nichts gespeichert - Zeile(n) %s sind ungültig oder zu lang. Nötige Platzhalter: %s",
    },
    DATE_FORMAT = { enUS = "%m/%d/%Y %H:%M", deDE = "%d.%m.%Y %H:%M" },
    GZPOOL_EDITOR_CANCEL = { enUS = "Cancel", deDE = "Abbrechen" },

    -- GuildDing.lua - Varianten-Pool (/emberstone gzmsg guild|whisper pool ...)
    GZMSG_RANDOM_USAGE = { enUS = "Usage: /emberstone gzmsg guild|whisper random on|off", deDE = "Verwendung: /emberstone gzmsg guild|whisper random on|off" },
    GZMSG_RANDOM_ON = { enUS = "Random variant enabled.", deDE = "Zufaellige Variante aktiviert." },
    GZMSG_RANDOM_OFF = { enUS = "Random variant disabled, using the single fixed text again.", deDE = "Zufaellige Variante deaktiviert, es gilt wieder der einzelne feste Text." },
    GZMSG_POOL_HELP = {
        enUS = "Usage: /emberstone gzmsg guild|whisper pool add <text> | pool remove <n> | pool list",
        deDE = "Verwendung: /emberstone gzmsg guild|whisper pool add <Text> | pool remove <Nummer> | pool list",
    },
    GZMSG_POOL_ADD_USAGE = { enUS = "Usage: /emberstone gzmsg guild|whisper pool add <text>", deDE = "Verwendung: /emberstone gzmsg guild|whisper pool add <Text>" },
    GZMSG_POOL_ADD_DONE = { enUS = "Variant added.", deDE = "Variante hinzugefuegt." },
    GZMSG_POOL_REMOVE_INVALID = { enUS = "Invalid number.", deDE = "Ungueltige Nummer." },
    GZMSG_POOL_REMOVE_DONE = { enUS = "Variant #%d removed.", deDE = "Variante Nr. %d entfernt." },
    GZMSG_POOL_LIST_EMPTY = { enUS = "No variants yet - the single fixed text is used.", deDE = "Noch keine Varianten - es gilt der einzelne feste Text." },
    GZMSG_POOL_LIST_HEADER = { enUS = "Variants:", deDE = "Varianten:" },

    -- GuildDing.lua - Ignorierliste
    IGNORE_HELP = {
        enUS = "Usage: /emberstone ignore add <name> | /emberstone ignore remove <name> | /emberstone ignore list",
        deDE = "Verwendung: /emberstone ignore add <Name> | /emberstone ignore remove <Name> | /emberstone ignore list",
    },
    IGNORE_ADD_USAGE = { enUS = "Usage: /emberstone ignore add <name>", deDE = "Verwendung: /emberstone ignore add <Name>" },
    IGNORE_ADD_DONE = { enUS = "%s will no longer receive any level-up notifications.", deDE = "%s wird ab sofort bei Levelaufstiegen nicht mehr gemeldet." },
    IGNORE_ADD_EXISTS = { enUS = "%s is already on the ignore list.", deDE = "%s steht bereits auf der Ignorierliste." },
    IGNORE_REMOVE_USAGE = { enUS = "Usage: /emberstone ignore remove <name>", deDE = "Verwendung: /emberstone ignore remove <Name>" },
    IGNORE_REMOVE_DONE = { enUS = "%s was removed from the ignore list.", deDE = "%s wurde von der Ignorierliste entfernt." },
    IGNORE_REMOVE_NOT_FOUND = { enUS = "%s was not on the ignore list.", deDE = "%s stand nicht auf der Ignorierliste." },
    IGNORE_LIST_EMPTY = { enUS = "The ignore list is currently empty.", deDE = "Die Ignorierliste ist aktuell leer." },
    IGNORE_LIST_HEADER = { enUS = "Ignored for level-up notifications:", deDE = "Bei Levelaufstiegen ignoriert:" },

    -- GuildDing.lua - Level-up-Protokoll
    LOG_HELP = {
        enUS = "Usage: /emberstone log | /emberstone log level <n> | /emberstone log player <name> | /emberstone log clear",
        deDE = "Verwendung: /emberstone log | /emberstone log level <Zahl> | /emberstone log player <Name> | /emberstone log clear",
    },
    LOG_LEVEL_USAGE = { enUS = "Usage: /emberstone log level <n>", deDE = "Verwendung: /emberstone log level <Zahl>" },
    LOG_LEVEL_EMPTY = { enUS = "No one has reached level %d yet (or it wasn't logged).", deDE = "Bisher hat niemand Level %d erreicht (oder es wurde nicht protokolliert)." },
    LOG_PLAYER_USAGE = { enUS = "Usage: /emberstone log player <name>", deDE = "Verwendung: /emberstone log player <Name>" },
    LOG_PLAYER_EMPTY = { enUS = "No logged level-ups found for %s.", deDE = "Keine protokollierten Levelaufstiege fuer %s gefunden." },
    LOG_CLEARED = { enUS = "The level-up log was cleared.", deDE = "Das Levelaufstiegs-Protokoll wurde geloescht." },
    LOG_EMPTY = { enUS = "The level-up log is currently empty.", deDE = "Das Levelaufstiegs-Protokoll ist aktuell leer." },
    LOG_RECENT_HEADER = { enUS = "Most recent level-ups:", deDE = "Zuletzt protokollierte Levelaufstiege:" },
    LOG_ENTRY_LINE = { enUS = "%s reached level %d on %s", deDE = "%s hat Level %d erreicht am %s" },

    -- features/AfkText.lua - eigener AFK-Spruch
    AFK_ON = { enUS = "Emberstone: Custom AFK sayings enabled. Whoever whispers you while you are AFK gets one of your sayings.", deDE = "Emberstone: Eigene AFK-Sprüche eingeschaltet. Wer dich anflüstert, während du AFK bist, bekommt einen deiner Sprüche." },
    AFK_OFF = { enUS = "Emberstone: Custom AFK sayings disabled.", deDE = "Emberstone: Eigene AFK-Sprüche ausgeschaltet." },
    AFK_FAILED = { enUS = "Emberstone: Could not set the AFK saying - the normal AFK text stays.", deDE = "Emberstone: Der AFK-Spruch konnte nicht gesetzt werden - es bleibt beim normalen AFK-Text." },
    AFK_STATUS = { enUS = "Emberstone AFK sayings: %s, %d saying(s) in the list.", deDE = "Emberstone AFK-Sprüche: %s, %d Spruch/Sprüche in der Liste." },
    AFK_STATE_ON = { enUS = "on", deDE = "an" },
    AFK_STATE_OFF = { enUS = "off", deDE = "aus" },
    AFK_HELP = {
        enUS = "Usage: /emberstone afk on | off | edit | add <text> | list | test",
        deDE = "Verwendung: /emberstone afk on | off | edit | add <Text> | list | test",
    },
    AFK_LIST_EMPTY = { enUS = "The list of AFK sayings is empty.", deDE = "Die Liste der AFK-Sprüche ist leer." },
    AFK_LIST_HEADER = { enUS = "Your AFK sayings:", deDE = "Deine AFK-Sprüche:" },
    AFK_TEST = { enUS = "Example - whoever whispers you would get: \"%s\"", deDE = "Beispiel - wer dich anflüstert, bekäme: \"%s\"" },
    AFK_EDITOR_TITLE = { enUS = "AFK sayings", deDE = "AFK-Sprüche" },
    AFK_EDITOR_HINT = {
        enUS = "One saying per line. When you go AFK, one of them is picked at random and sent to whoever whispers you.",
        deDE = "Ein Spruch pro Zeile. Wirst du AFK, wird zufällig einer ausgewählt - den bekommt, wer dich anflüstert.",
    },
    AFK_EDITOR_BAD_LINES = {
        enUS = "Emberstone: Nothing saved - line(s) %s are empty, too long (max. %d characters), contain \"|\" or are just \"AFK\".",
        deDE = "Emberstone: Nichts gespeichert - Zeile(n) %s sind leer, zu lang (max. %d Zeichen), enthalten \"|\" oder sind nur \"AFK\".",
    },
    OPT_SECTION_AFK = { enUS = "AFK sayings", deDE = "AFK-Sprüche" },
    OPT_AFK_ENABLED_LABEL = { enUS = "Custom AFK saying instead of just \"AFK\"", deDE = "Eigener AFK-Spruch statt nur \"AFK\"" },
    OPT_AFK_ENABLED_TOOLTIP = {
        enUS = "When you go AFK (automatically or with /afk without text), Emberstone sets a random saying from your list. Whoever whispers you gets it as the automatic reply. A text of your own (/afk Dinner) is left alone.",
        deDE = "Wirst du AFK (automatisch oder mit /afk ohne Text), setzt Emberstone einen zufälligen Spruch aus deiner Liste. Wer dich anflüstert, bekommt ihn als automatische Antwort. Ein eigener Text (/afk Bin essen) bleibt unangetastet.",
    },
    OPT_AFK_EDIT_BUTTON = { enUS = "Edit sayings", deDE = "Sprüche bearbeiten" },
    OPT_AFK_TEST_BUTTON = { enUS = "Show example", deDE = "Beispiel zeigen" },

    -- Minimap.lua (seit v1.12)
    OPT_MINIMAP_LABEL = { enUS = "Show minimap button", deDE = "Minimap-Symbol anzeigen" },
    OPT_MINIMAP_TOOLTIP = {
        enUS = "Shows the Emberstone button at the edge of the minimap. Left click opens these options, right click shows a test notification. Also: /emberstone minimap",
        deDE = "Zeigt das Emberstone-Symbol am Rand der Minimap. Linksklick öffnet diese Optionen, Rechtsklick zeigt eine Test-Benachrichtigung. Auch: /emberstone minimap",
    },
    MINIMAP_TOOLTIP_LEFT = { enUS = "Left click: options", deDE = "Linksklick: Optionen" },
    MINIMAP_TOOLTIP_RIGHT = { enUS = "Right click: test notification", deDE = "Rechtsklick: Test-Benachrichtigung" },
    MINIMAP_TOOLTIP_DRAG = { enUS = "Drag to move the button", deDE = "Ziehen verschiebt das Symbol" },
    MINIMAP_ON = { enUS = "Emberstone: minimap button shown.", deDE = "Emberstone: Minimap-Symbol eingeblendet." },
    MINIMAP_OFF = { enUS = "Emberstone: minimap button hidden. Show it again with /emberstone minimap", deDE = "Emberstone: Minimap-Symbol ausgeblendet. Wieder einblenden mit /emberstone minimap" },
}

local L = setmetatable({}, {
    __index = function(_, key)
        local entry = STRINGS[key]
        if not entry then return key end
        return entry[locale] or entry.enUS or key
    end,
})

Addon.L = L
