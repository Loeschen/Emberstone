-- ui.lua
--
-- Ersetzt das alte handgebaute Canvas-Options-Fenster (manuelle Pixel-
-- Positionierung per CreateFrame/SetPoint, kein eingebautes Scrollen) durch
-- Blizzards native Settings-API (Settings.RegisterVerticalLayoutCategory).
-- Gruende:
--  1. Die neue Gilden-Sektion kommt zu den schon ~15 vorhandenen
--     Screenshot-Einstellungen dazu - mit reinem Pixel-Anker-Code waere
--     das Fenster nach unten hinausgelaufen, ohne dass der sichtbare
--     Options-Bereich mitgescrollt haette. Die native API scrollt
--     automatisch.
--  2. Entspricht der bereits getroffenen Design-Entscheidung fuer
--     GrindDing (natives Blizzard-Optionsfenster statt Eigenbau-Look).
--
-- Wie beim GetItemInfo-Fund in GrindLedger gilt: nicht jede Blizzard-API
-- ist zu 100% als unveraendert in Forever bestaetigt. Checkboxen sind
-- durch GrindDing bereits im laufenden Client verifiziert. Die Slider-API
-- (Settings.CreateSliderOptions/CreateSlider) ist die unsicherste Stelle
-- hier, da wir sie in dieser Session noch nicht live getestet haben -
-- deshalb ist jede einzelne Slider-/Checkbox-Registrierung per pcall
-- abgesichert: schlaegt eine Zeile fehl, fehlt im schlimmsten Fall nur
-- dieser eine Regler, der Rest des Options-Fensters bleibt nutzbar.
local ADDON_NAME, Addon = ...
local L = Addon.L

local function AddSectionHeader(layout, text)
    if not (CreateSettingsListSectionHeaderInitializer and layout and layout.AddInitializer) then
        return
    end
    local ok, initializer = pcall(CreateSettingsListSectionHeaderInitializer, text)
    if ok and initializer then
        layout:AddInitializer(initializer)
    end
end

local function AddCheckbox(category, variable, name, tooltip, getter, setter, default)
    local ok, setting = pcall(
        Settings.RegisterProxySetting,
        category,
        variable,
        Settings.VarType and Settings.VarType.Boolean or "boolean",
        name,
        default,
        getter,
        setter
    )
    if ok and setting then
        pcall(Settings.CreateCheckbox, category, setting, tooltip)
    end
    return ok and setting or nil
end

-- HINWEIS (Version 1.4): Es gab hier frueher einen AddButton()-Helfer, der
-- ueber CreateSettingsButtonInitializer zwei "Text bearbeiten"-Buttons ins
-- Optionsfenster gesetzt hat. Live auf WoW Forever getestet: die Buttons
-- erscheinen dort nie, auch nicht nach Scrollen - CreateSettingsButtonInitializer
-- scheint auf diesem Client generell nicht zu funktionieren (kein Fehler,
-- der pcall-Schutz laesst es nur lautlos leerlaufen). Dieselbe Funktion war
-- auch die urspruenglich (faelschlich) verdaechtigte Ursache der "Blizzard-UI
-- vorbehalten"-Sperre bei GrindShout. CreateSettingsButtonInitializer bitte
-- nicht wieder einfuehren.

-- ============================================================
-- "Fuer die ganze Gilde"-Unterkategorie (v1.5/v1.8): komplett als eigene
-- Canvas-Unterkategorie gebaut (Settings.RegisterCanvasLayoutSubcategory),
-- NICHT mehr als Abschnitt in der Haupt-Checkbox-Liste. Grund: nur so
-- lassen sich die "Text bearbeiten"/"Varianten verwalten"-Buttons direkt
-- NEBEN den Gilden-Haken auf derselben Seite unterbringen (ausdruecklicher
-- Wunsch) - Blizzards Listen-API (RegisterVerticalLayoutCategory) erlaubt
-- keine frei platzierten Buttons zwischen ihren eigenen Zeilen, nur die auf
-- diesem Client kaputte CreateSettingsButtonInitializer-Zeile (siehe oben).
-- Auf einer eigenen Canvas-Seite bauen wir Checkbox/Slider/Button dagegen
-- alle selbst mit den immer schon stabilen Basis-Templates
-- ("UICheckButtonTemplate", "OptionsSliderTemplate", "UIPanelButtonTemplate")
-- - genau diese drei Bausteine sind es, mit denen z.B. auch BlizzMove seine
-- (nachweislich funktionierenden) Options-Buttons baut, nicht die neuere,
-- fuer einzelne Listenzeilen gedachte Settings-API.
--
-- Wie ueberall in diesem Projekt: pcall-abgesichert, und die Checkbox-/
-- Slider-Templates hier sind ur-alte, seit Classic/WotLK unveraenderte
-- WoW-APIs - aber auf DIESEM Beta-Client (siehe die zwei Live-Funde vom
-- 21.09.2026 bei StaticPopup) wurde bereits mehrfach bewiesen, dass man
-- nichts als "garantiert unveraendert" annehmen sollte, ohne es einmal im
-- Spiel gesehen zu haben. Bitte einmal live pruefen.
-- ============================================================
local GUILD_PANEL_WIDTH = 480

local function BuildGuildPanel()
    local panel = CreateFrame("Frame")
    panel.name = L["OPT_SECTION_GUILD"]

    local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 4, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 4)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetWidth(GUILD_PANEL_WIDTH)
    scrollFrame:SetScrollChild(content)

    local y = -16

    local title = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, y)
    title:SetText(L["OPT_SECTION_GUILD"])
    y = y - 30

    local function AttachTooltip(widget, tooltipText)
        if not tooltipText or tooltipText == "" then return end
        widget:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(tooltipText, nil, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    local function AddCanvasCheckbox(label, tooltipText, getter, setter)
        local ok, cb = pcall(CreateFrame, "CheckButton", nil, content, "UICheckButtonTemplate")
        if not ok or not cb then return end
        cb:SetPoint("TOPLEFT", 12, y)
        if cb.Text then cb.Text:SetText(label) end
        pcall(cb.SetChecked, cb, getter() and true or false)
        cb:SetScript("OnClick", function(self) setter(self:GetChecked() and true or false) end)
        -- Beim Anzeigen neu einlesen: der Wert kann sich per Slash-Befehl
        -- geaendert haben, seit das Fenster gebaut wurde.
        cb:SetScript("OnShow", function(self) pcall(self.SetChecked, self, getter() and true or false) end)
        AttachTooltip(cb, tooltipText)
        y = y - 26
        return cb
    end

    local function AddCanvasSlider(label, tooltipText, minValue, maxValue, step, getter, setter, formatter)
        local header = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        header:SetPoint("TOPLEFT", 12, y)
        header:SetText(label)
        y = y - 16

        local ok, slider = pcall(CreateFrame, "Slider", nil, content, "OptionsSliderTemplate")
        if not ok or not slider then return end
        slider:SetPoint("TOPLEFT", 16, y)
        slider:SetWidth(220)
        slider:SetMinMaxValues(minValue, maxValue)
        slider:SetValueStep(step)
        pcall(slider.SetObeyStepOnDrag, slider, true)
        pcall(slider.SetValue, slider, getter())
        if slider.Low then slider.Low:SetText("") end
        if slider.High then slider.High:SetText("") end
        if slider.Text then slider.Text:SetText("") end

        local valueLabel = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        valueLabel:SetPoint("LEFT", slider, "RIGHT", 12, 0)
        valueLabel:SetText(formatter and formatter(getter()) or tostring(getter()))

        slider:SetScript("OnValueChanged", function(self, value)
            setter(value)
            valueLabel:SetText(formatter and formatter(value) or tostring(value))
        end)
        AttachTooltip(slider, tooltipText)

        y = y - 36
        return slider
    end

    local function AddCanvasSectionHeader(label)
        y = y - 10
        local header = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        header:SetPoint("TOPLEFT", 16, y)
        header:SetText(label)
        y = y - 22
    end

    local function AddCanvasButtonPair(labelA, onClickA, labelB, onClickB)
        local ok, btnA = pcall(CreateFrame, "Button", nil, content, "UIPanelButtonTemplate")
        if ok and btnA then
            btnA:SetSize(160, 22)
            btnA:SetPoint("TOPLEFT", 16, y)
            btnA:SetText(labelA)
            btnA:SetScript("OnClick", onClickA)
        end

        local okB, btnB = pcall(CreateFrame, "Button", nil, content, "UIPanelButtonTemplate")
        if okB and btnB and ok and btnA then
            btnB:SetSize(160, 22)
            btnB:SetPoint("LEFT", btnA, "RIGHT", 12, 0)
            btnB:SetText(labelB)
            btnB:SetScript("OnClick", onClickB)
        end

        y = y - 32
    end

    AddCanvasCheckbox(L["OPT_GUILD_ENABLED_LABEL"], L["OPT_GUILD_ENABLED_TOOLTIP"],
        function() return Addon:GetSetting("guildDingEnabled") end,
        function(value)
            Addon:SetSetting("guildDingEnabled", value)
            Addon:StartGuildPolling() -- startet sofort neu bzw. stoppt sofort, ohne Neuladen
        end)

    AddCanvasCheckbox(L["OPT_GUILD_SCREEN_LABEL"], L["OPT_GUILD_SCREEN_TOOLTIP"],
        function() return Addon:GetSetting("guildDingScreen") end,
        function(value) Addon:SetSetting("guildDingScreen", value) end)

    AddCanvasCheckbox(L["OPT_GUILD_CHAT_LABEL"], L["OPT_GUILD_CHAT_TOOLTIP"],
        function() return Addon:GetSetting("guildDingChat") end,
        function(value) Addon:SetSetting("guildDingChat", value) end)

    AddCanvasSlider(L["OPT_GUILD_POLL_INTERVAL_LABEL"], L["OPT_GUILD_POLL_INTERVAL_TOOLTIP"],
        5, 60, 5,
        function() return Addon:GetSetting("guildDingPollInterval") end,
        function(value)
            Addon:SetSetting("guildDingPollInterval", value)
            Addon:StartGuildPolling() -- neuen Takt sofort uebernehmen
        end,
        function(value) return string.format("%ds", math.floor(value)) end)

    AddCanvasCheckbox(L["OPT_GUILD_AUTOGZ_GUILD_LABEL"], L["OPT_GUILD_AUTOGZ_GUILD_TOOLTIP"],
        function() return Addon:GetSetting("guildDingAutoGZGuild") end,
        function(value) Addon:SetSetting("guildDingAutoGZGuild", value) end)

    AddCanvasCheckbox(L["OPT_GUILD_AUTOGZ_WHISPER_LABEL"], L["OPT_GUILD_AUTOGZ_WHISPER_TOOLTIP"],
        function() return Addon:GetSetting("guildDingAutoGZWhisper") end,
        function(value) Addon:SetSetting("guildDingAutoGZWhisper", value) end)

    AddCanvasCheckbox(L["OPT_GUILD_AUTOGZ_GUILD_RANDOM_LABEL"], L["OPT_GUILD_AUTOGZ_GUILD_RANDOM_TOOLTIP"],
        function() return Addon:GetSetting("guildDingAutoGZGuildRandom") end,
        function(value) Addon:SetSetting("guildDingAutoGZGuildRandom", value) end)

    AddCanvasCheckbox(L["OPT_GUILD_AUTOGZ_WHISPER_RANDOM_LABEL"], L["OPT_GUILD_AUTOGZ_WHISPER_RANDOM_TOOLTIP"],
        function() return Addon:GetSetting("guildDingAutoGZWhisperRandom") end,
        function(value) Addon:SetSetting("guildDingAutoGZWhisperRandom", value) end)

    AddCanvasSectionHeader(L["GZ_EDITOR_SECTION_GUILD"])
    AddCanvasButtonPair(
        L["GZ_EDITOR_EDIT_BUTTON"], function() Addon:ShowGZMessageDialog("guild") end,
        L["GZ_EDITOR_POOL_BUTTON"], function() Addon:ShowGZPoolEditor("guild") end)

    AddCanvasSectionHeader(L["GZ_EDITOR_SECTION_WHISPER"])
    AddCanvasButtonPair(
        L["GZ_EDITOR_EDIT_BUTTON"], function() Addon:ShowGZMessageDialog("whisper") end,
        L["GZ_EDITOR_POOL_BUTTON"], function() Addon:ShowGZPoolEditor("whisper") end)

    content:SetHeight(-y + 24)

    return panel
end

local function RegisterGuildSubcategory(category)
    if not (Settings and Settings.RegisterCanvasLayoutSubcategory) then
        -- Kein Absturz: die Haupt-Checkboxliste bleibt ohne die Gilden-
        -- Sektion, Bearbeitung laeuft dann rein per Slash-Befehl
        -- (/emberstone gzmsg ...) - siehe HandleGZMsgCommand.
        return
    end
    local ok, panel = pcall(BuildGuildPanel)
    if not ok or not panel then return end
    pcall(Settings.RegisterCanvasLayoutSubcategory, category, panel, L["OPT_SECTION_GUILD"])
end

-- Eigene Canvas-Seite fuer die AFK-Sprueche (braucht echte Knoepfe, siehe
-- RegisterGuildSubcategory oben fuer den Grund).
local function BuildAfkPanel()
    local panel = CreateFrame("Frame")
    panel.name = L["OPT_SECTION_AFK"]

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(L["OPT_SECTION_AFK"])

    local cb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", 12, -46)
    if cb.Text then cb.Text:SetText(L["OPT_AFK_ENABLED_LABEL"]) end
    local function Sync() pcall(cb.SetChecked, cb, Addon:GetSetting("afkTextEnabled") and true or false) end
    Sync()
    cb:SetScript("OnShow", Sync)
    cb:SetScript("OnClick", function(self) Addon:SetSetting("afkTextEnabled", self:GetChecked() and true or false) end)
    cb:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["OPT_AFK_ENABLED_TOOLTIP"], nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    cb:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local desc = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", 20, -78)
    desc:SetWidth(440)
    desc:SetJustifyH("LEFT")
    desc:SetText(L["OPT_AFK_ENABLED_TOOLTIP"])

    local editBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    editBtn:SetSize(160, 22)
    editBtn:SetPoint("TOPLEFT", 16, -130)
    editBtn:SetText(L["OPT_AFK_EDIT_BUTTON"])
    editBtn:SetScript("OnClick", function() Addon:ShowAfkEditor() end)

    local testBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    testBtn:SetSize(160, 22)
    testBtn:SetPoint("LEFT", editBtn, "RIGHT", 12, 0)
    testBtn:SetText(L["OPT_AFK_TEST_BUTTON"])
    testBtn:SetScript("OnClick", function() Addon:HandleAfkCommand("test") end)

    return panel
end

local function RegisterAfkSubcategory(category)
    if not (Settings and Settings.RegisterCanvasLayoutSubcategory) then return end
    local ok, panel = pcall(BuildAfkPanel)
    if not ok or not panel then return end
    pcall(Settings.RegisterCanvasLayoutSubcategory, category, panel, L["OPT_SECTION_AFK"])
end

local function AddSlider(category, variable, name, tooltip, minValue, maxValue, step, default, getter, setter, formatter)
    local ok, setting = pcall(
        Settings.RegisterProxySetting,
        category,
        variable,
        Settings.VarType and Settings.VarType.Number or "number",
        name,
        default,
        getter,
        setter
    )
    if not (ok and setting) then return nil end

    local optOk, options = pcall(Settings.CreateSliderOptions, minValue, maxValue, step)
    if optOk and options and options.SetLabelFormatter and MinimalSliderWithSteppersMixin then
        pcall(options.SetLabelFormatter, options, MinimalSliderWithSteppersMixin.Label.Right, formatter)
    end

    if optOk and options then
        pcall(Settings.CreateSlider, category, setting, options, tooltip)
    end

    return setting
end

-- ============================================================
-- Themen-Unterseiten (v1.9): Die frueher eine sehr lange Liste
-- ("Deine Meilensteine" mit 8 Haken + 8 Reglern am Stueck) wird in
-- thematische Unterseiten aufgeteilt - Erfolge, Dungeons, Mythic+, seltene
-- Gegner, PvP.
--
-- WICHTIG - bewusster Unterschied zur Gilden-Seite: Hier wird NICHT die
-- selbstgebaute Canvas-Variante benutzt, sondern RegisterVerticalLayoutSubcategory,
-- also weiterhin exakt dieselben Checkbox-/Slider-Bausteine wie bisher auf
-- der Hauptseite. Die Gilden-Seite musste Canvas sein, WEIL sie echte
-- Buttons braucht; hier gibt es keine Buttons, also gibt es auch keinen
-- Grund, die bereits im Spiel verifizierte Listen-Technik gegen
-- handgebaute Frames einzutauschen (unnoetiges Risiko ohne Gegenwert).
--
-- Faellt RegisterVerticalLayoutSubcategory auf einem Client aus, landet
-- alles automatisch wieder als Abschnitt auf der Hauptseite - also exakt
-- das alte, funktionierende Verhalten, nur ohne Unterseiten.
-- ============================================================
local function CreateSubcategory(parentCategory, parentLayout, name)
    if Settings and Settings.RegisterVerticalLayoutSubcategory then
        local ok, sub, subLayout = pcall(Settings.RegisterVerticalLayoutSubcategory, parentCategory, name)
        if ok and sub then
            return sub, subLayout
        end
    end

    AddSectionHeader(parentLayout, name)
    return parentCategory, parentLayout
end

function Addon:RegisterOptions()
    if self.OptionsCategory then return end
    if not (Settings and Settings.RegisterVerticalLayoutCategory) then
        -- Ohne native Settings-API bleibt Emberstone rein slash-command-
        -- gesteuert (siehe Commands.lua) statt mit einem riskanten
        -- Eigenbau-Fenster ohne Scroll-Absicherung.
        return
    end

    local ok, category, layout = pcall(Settings.RegisterVerticalLayoutCategory, ADDON_NAME)
    if not ok or not category then return end

    self.OptionsCategory = category

    -- Kurzer Hinweis fuer Funktionen, die es in WoW Forever nach aktuellem
    -- Stand (Beta, 2 Tage alt) wahrscheinlich noch nicht gibt. Bewusst nur
    -- als Tooltip-Hinweis statt als automatische Client-Erkennung: Forever
    -- meldet sich technisch als dieselbe "Mainline"-Kennung wie Retail, eine
    -- zuverlaessige Unterscheidung per Code waere reine Spekulation. Auf
    -- Retail gilt der Hinweis ohnehin nicht, und ist das Feature in Forever
    -- nicht vorhanden, bleibt der Haken einfach ein harmloser Leerlauf.
    local FOREVER_UNCERTAIN = L["OPT_FOREVER_UNCERTAIN"]

    -- Ein Screenshot-Ereignis = ein Haken (an/aus) plus ein Regler
    -- (Verzoegerung). Immer als Paar, deshalb hier gebuendelt.
    local function AddShotEvent(cat, key, delayKey, label, tooltip)
        AddCheckbox(cat, "emberstone_" .. key, label, tooltip,
            function() return Addon:GetSetting(key) end,
            function(value) Addon:SetSetting(key, value) end,
            Addon.Defaults[key])

        AddSlider(cat, "emberstone_" .. delayKey, label .. L["OPT_EVENT_DELAY_SUFFIX"],
            L["OPT_EVENT_DELAY_TOOLTIP"],
            1, 5, 0.5,
            Addon.Defaults[delayKey],
            function() return Addon:GetSetting(delayKey) end,
            function(value) Addon:SetSetting(delayKey, value) end,
            function(value) return string.format("%.1fs", value) end)
    end

    ------------------------------------------------------------------
    -- Hauptseite: allgemeine/technische Einstellungen. Die eigentlichen
    -- Screenshot-Ereignisse liegen in den Themen-Unterseiten weiter unten,
    -- damit hier keine endlose Liste mehr entsteht.
    ------------------------------------------------------------------
    AddSectionHeader(layout, L["OPT_MAIN_SUBCATEGORY_HINT"])

    ------------------------------------------------------------------
    -- Doppelte Screenshots vermeiden
    ------------------------------------------------------------------
    AddSectionHeader(layout, L["OPT_SECTION_PREVENT_DUPES"])

    AddCheckbox(category, "emberstone_preventDuplicates", L["OPT_PREVENT_DUPES_LABEL"],
        L["OPT_PREVENT_DUPES_TOOLTIP"],
        function() return Addon:GetSetting("preventDuplicates") end,
        function(value) Addon:SetSetting("preventDuplicates", value) end,
        Addon.Defaults.preventDuplicates)

    AddSlider(category, "emberstone_duplicateThreshold", L["OPT_DUPLICATE_THRESHOLD_LABEL"],
        L["OPT_DUPLICATE_THRESHOLD_TOOLTIP"],
        0, 2, 0.25,
        Addon.Defaults.duplicateThreshold,
        function() return Addon:GetSetting("duplicateThreshold") end,
        function(value) Addon:SetSetting("duplicateThreshold", value) end,
        function(value) return string.format("%.2fs", value) end)

    ------------------------------------------------------------------
    -- Weniger Ruckler
    ------------------------------------------------------------------
    AddSectionHeader(layout, L["OPT_SECTION_LESS_LAG"])

    AddCheckbox(category, "emberstone_reduceQualityForShots", L["OPT_REDUCE_QUALITY_LABEL"],
        L["OPT_REDUCE_QUALITY_TOOLTIP"],
        function() return Addon:GetSetting("reduceQualityForShots") end,
        function(value) Addon:SetSetting("reduceQualityForShots", value) end,
        Addon.Defaults.reduceQualityForShots)

    AddSlider(category, "emberstone_screenshotQuality", L["OPT_SCREENSHOT_QUALITY_LABEL"],
        L["OPT_SCREENSHOT_QUALITY_TOOLTIP"],
        0, 10, 1,
        Addon.Defaults.screenshotQuality,
        function() return Addon:GetSetting("screenshotQuality") end,
        function(value) Addon:SetSetting("screenshotQuality", value) end,
        function(value) return tostring(math.floor(value)) end)

    ------------------------------------------------------------------
    -- Sonstiges
    ------------------------------------------------------------------
    AddSectionHeader(layout, L["OPT_SECTION_MISC"])

    AddCheckbox(category, "emberstone_groupPhotoReminderEnabled", L["OPT_GROUP_PHOTO_LABEL"],
        L["OPT_GROUP_PHOTO_TOOLTIP"],
        function() return Addon:GetSetting("groupPhotoReminderEnabled") end,
        function(value) Addon:SetSetting("groupPhotoReminderEnabled", value) end,
        Addon.Defaults.groupPhotoReminderEnabled)

    -- Minimap-Symbol: gespeichert wird "ausblenden", angezeigt "anzeigen"
    AddCheckbox(category, "emberstone_showMinimapButton", L["OPT_MINIMAP_LABEL"],
        L["OPT_MINIMAP_TOOLTIP"],
        function() return not Addon:GetSetting("minimapHide") end,
        function(value) Addon:SetMinimapShown(value) end,
        true)

    ------------------------------------------------------------------
    -- Unterseite: Erfolge & Level
    ------------------------------------------------------------------
    local achCat = CreateSubcategory(category, layout, L["OPT_SUBCAT_ACHIEVEMENTS"])

    AddShotEvent(achCat, "enableAchievementShots", "achievementDelay",
        L["OPT_EVENT_ACHIEVEMENT_LABEL"], L["OPT_EVENT_ACHIEVEMENT_TOOLTIP"] .. FOREVER_UNCERTAIN)

    AddShotEvent(achCat, "enableLevelShots", "levelDelay",
        L["OPT_EVENT_LEVEL_LABEL"], L["OPT_EVENT_LEVEL_TOOLTIP"])

    ------------------------------------------------------------------
    -- Unterseite: Dungeons & Tiefen
    ------------------------------------------------------------------
    local dungeonCat = CreateSubcategory(category, layout, L["OPT_SUBCAT_DUNGEONS"])

    AddShotEvent(dungeonCat, "enableBossShots", "bossDelay",
        L["OPT_EVENT_BOSS_LABEL"], L["OPT_EVENT_BOSS_TOOLTIP"])

    AddShotEvent(dungeonCat, "enableDelveShots", "delveDelay",
        L["OPT_EVENT_DELVE_LABEL"], L["OPT_EVENT_DELVE_TOOLTIP"] .. FOREVER_UNCERTAIN)

    ------------------------------------------------------------------
    -- Unterseite: Mythic+
    ------------------------------------------------------------------
    local mythicCat = CreateSubcategory(category, layout, L["OPT_SUBCAT_MYTHICPLUS"])

    AddShotEvent(mythicCat, "enableChallengeShots", "challengeDelay",
        L["OPT_EVENT_CHALLENGE_LABEL"], L["OPT_EVENT_CHALLENGE_TOOLTIP"] .. FOREVER_UNCERTAIN)

    AddShotEvent(mythicCat, "enableChallengeNewRecordShots", "challengeNewRecordDelay",
        L["OPT_EVENT_CHALLENGE_RECORD_LABEL"], L["OPT_EVENT_CHALLENGE_RECORD_TOOLTIP"] .. FOREVER_UNCERTAIN)

    ------------------------------------------------------------------
    -- Unterseite: Seltene Gegner & Weltbosse
    ------------------------------------------------------------------
    local rareCat = CreateSubcategory(category, layout, L["OPT_SUBCAT_RARES"])

    AddShotEvent(rareCat, "enableRareKillShots", "rareKillDelay",
        L["OPT_EVENT_RARE_KILL_LABEL"], L["OPT_EVENT_RARE_KILL_TOOLTIP"])

    AddShotEvent(rareCat, "enableWorldBossKillShots", "worldBossKillDelay",
        L["OPT_EVENT_WORLDBOSS_KILL_LABEL"], L["OPT_EVENT_WORLDBOSS_KILL_TOOLTIP"])

    ------------------------------------------------------------------
    -- Unterseite: PvP
    ------------------------------------------------------------------
    local pvpCat = CreateSubcategory(category, layout, L["OPT_SUBCAT_PVP"])

    AddCheckbox(pvpCat, "emberstone_enableArenaWinShots", L["OPT_ARENA_WIN_LABEL"],
        string.format(L["OPT_ARENA_WIN_TOOLTIP"], FOREVER_UNCERTAIN),
        function() return Addon:GetSetting("enableArenaWinShots") end,
        function(value) Addon:SetSetting("enableArenaWinShots", value) end,
        Addon.Defaults.enableArenaWinShots)

    AddCheckbox(pvpCat, "emberstone_onlyRatedArena", L["OPT_ONLY_RATED_ARENA_LABEL"],
        string.format(L["OPT_ONLY_RATED_ARENA_TOOLTIP"], FOREVER_UNCERTAIN),
        function() return Addon:GetSetting("onlyRatedArena") end,
        function(value) Addon:SetSetting("onlyRatedArena", value) end,
        Addon.Defaults.onlyRatedArena)

    AddCheckbox(pvpCat, "emberstone_enableBattlegroundWinShots", L["OPT_BG_WIN_LABEL"],
        L["OPT_BG_WIN_TOOLTIP"],
        function() return Addon:GetSetting("enableBattlegroundWinShots") end,
        function(value) Addon:SetSetting("enableBattlegroundWinShots", value) end,
        Addon.Defaults.enableBattlegroundWinShots)

    AddCheckbox(pvpCat, "emberstone_onlyRatedBattlegrounds", L["OPT_ONLY_RATED_BG_LABEL"],
        string.format(L["OPT_ONLY_RATED_BG_TOOLTIP"], FOREVER_UNCERTAIN),
        function() return Addon:GetSetting("onlyRatedBattlegrounds") end,
        function(value) Addon:SetSetting("onlyRatedBattlegrounds", value) end,
        Addon.Defaults.onlyRatedBattlegrounds)

    ------------------------------------------------------------------
    -- Unterseite: Fuer die ganze Gilde (als Canvas-Seite, weil sie als
    -- einzige echte Buttons braucht - siehe RegisterGuildSubcategory oben)
    ------------------------------------------------------------------
    RegisterGuildSubcategory(category)
    RegisterAfkSubcategory(category)

    pcall(Settings.RegisterAddOnCategory, category)
end
