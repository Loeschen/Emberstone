-- core.lua
local ADDON_NAME, Addon = ...

Addon.frame = CreateFrame("Frame")

Addon.frame:SetScript("OnEvent", function(_, event, ...)
    if Addon[event] then
        Addon[event](Addon, ...)
    end
end)

-- Nur dieses eine Event wird beim Datei-Laden registriert
Addon.frame:RegisterEvent("ADDON_LOADED")

function Addon:ADDON_LOADED(name)
    if name ~= ADDON_NAME then return end
    self:OnInitialize()
end

function Addon:OnInitialize()
    if not EmberstoneCommon then
        EmberstoneCommon = {}
    end

    if not EmberstoneCharacter then
        EmberstoneCharacter = {}
    end

    -- 1) ZUERST die Daten aus den alten/zusammengelegten Vorgaenger-Addons
    -- uebernehmen, BEVOR irgendwelche Standardwerte gesetzt werden. Das ist
    -- wichtig: MigrateLegacyData() kopiert einen Wert nur dann, wenn das
    -- jeweilige Feld noch leer (nil) ist - waeren die Defaults schon vorher
    -- gesetzt, faende die Migration nie ein leeres Feld vor und wuerde real
    -- nie etwas uebernehmen (das war ein Fehler in der Vorversion).
    if self.MigrateLegacyData then
        self:MigrateLegacyData()
    end

    -- 2) Defaults fuer alles anwenden, was auch nach der Migration noch leer ist
    -- (also fuer wirklich neue Installationen, oder neu dazugekommene Optionen)
    if self.Defaults then
        for key, defaultValue in pairs(self.Defaults) do
            if self:GetSetting(key) == nil then
                self:SetSetting(key, defaultValue)
            end
        end
    end

    -- 3) totalScreenshots-Zaehler sicherstellen (account-weit + Charakter)
    if self:GetSetting("totalScreenshots") == nil then
        self:SetSetting("totalScreenshots", 0)
    end

    if self:GetCharacterSetting("totalScreenshots") == nil then
        self:SetCharacterSetting("totalScreenshots", 0)
    end

    -- 4) Events fuer eigene Meilensteine registrieren - jedes einzeln
    -- abgesichert: kennt ein Client (z.B. WoW Forever) ein Ereignis nicht,
    -- faellt nur diese eine Funktion aus statt der ganze Rest (Gilde,
    -- Optionen, Slash-Befehle).
    for _, event in ipairs({
        "ACHIEVEMENT_EARNED", "BOSS_KILL", "CHALLENGE_MODE_COMPLETED",
        "CHALLENGE_MODE_NEW_RECORD", "PLAYER_LEVEL_UP", "PLAYER_LOGIN",
        "PVP_MATCH_COMPLETE", "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD",
        "GUILD_ROSTER_UPDATE", -- 5) Gildenweite Levelup-Benachrichtigungen (ehemals GrindDing)
        "CHAT_MSG_SYSTEM",     -- eigener AFK-Spruch (features/AfkText.lua)
    }) do
        pcall(self.frame.RegisterEvent, self.frame, event)
    end
    -- Rar-Mob-/Weltboss-Kill-Erkennung (siehe features/RareKill.lua): nur
    -- fuer das eigene Ziel, nicht fuer jede Einheit in der Umgebung.
    if self.frame.RegisterUnitEvent then
        pcall(self.frame.RegisterUnitEvent, self.frame, "UNIT_HEALTH", "target")
    else
        pcall(self.frame.RegisterEvent, self.frame, "UNIT_HEALTH")
    end

    -- Startet den periodischen Abgleich mit dem Gilden-Roster - respektiert
    -- dabei "guildDingEnabled" und die einstellbare Abfrage-Haeufigkeit
    -- (siehe GuildDing.lua:StartGuildPolling). Wird die Funktion komplett
    -- deaktiviert, laeuft gar kein Ticker mehr, statt nur die Benachrichtigung
    -- stumm zu unterdruecken.
    self:StartGuildPolling()

    -- Eigener AFK-Spruch (standardmaessig aus, siehe features/AfkText.lua)
    if self.InitAfkText then
        pcall(self.InitAfkText, self)
    end

    -- 6) Settings-Panel registrieren
    if self.RegisterOptions then
        self:RegisterOptions()
    end

    -- 7) Slash-Befehle einrichten
    if self.SetupSlash then
        self:SetupSlash()
    end

    -- 8) Minimap-Symbol (ausblendbar unter Optionen -> Sonstiges)
    if self.UpdateMinimapButton then
        pcall(self.UpdateMinimapButton, self)
    end
end
