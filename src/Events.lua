-- events.lua
local ADDON_NAME, Addon = ...

function Addon:ACHIEVEMENT_EARNED()
    if self:GetSetting("enableAchievementShots") then
        self:TakeScreenshot(self:GetDelay("achievementDelay"))
    end
end

function Addon:BOSS_KILL()
    if self:GetSetting("enableBossShots") then
        self:TakeScreenshot(self:GetDelay("bossDelay"))
    end

    -- Rein lokale, dezente Erinnerung (kein Chat-/Gilden-Versand) - bewusst
    -- bei JEDEM Bosskill statt nur beim letzten der Instanz: zuverlaessig zu
    -- erkennen, ob ein Boss der letzte einer Instanz war, braucht zusaetzliche
    -- Instanz-/Encounter-Zaehlung, die es hier (noch) nicht gibt. Auf
    -- ausdruecklichen Wunsch standardmaessig AUS.
    if self:GetSetting("groupPhotoReminderEnabled") then
        print(Addon.L["GROUP_PHOTO_REMINDER"])
    end
end

-- Rar-Mob-/Weltboss-Kill-Erkennung (siehe features/RareKill.lua fuer die
-- Begruendung, warum das ueber UNIT_HEALTH statt ueber das Kampf-Logbuch laeuft)
function Addon:UNIT_HEALTH(unit)
    self:CheckRareOrWorldBossKill(unit)
end

function Addon:CHALLENGE_MODE_COMPLETED()
    if self:GetSetting("enableChallengeShots") then
        self:TakeScreenshot(self:GetDelay("challengeDelay"))
    end
end

function Addon:CHALLENGE_MODE_NEW_RECORD()
    if self:GetSetting("enableChallengeNewRecordShots") then
        self:TakeScreenshot(self:GetDelay("challengeNewRecordDelay"))
    end
end

function Addon:PLAYER_LEVEL_UP()
    if self:GetSetting("enableLevelShots") then
        self:TakeScreenshot(self:GetDelay("levelDelay"))
    end
end

function Addon:PLAYER_LOGIN()
    self:PrintTotalScreenshots()
end

function Addon:PVP_MATCH_COMPLETE(winningTeam, matchDuration)
    -- Die gesamte Auswertung ist in pcall gewrappt: verschiebt sich eine
    -- der C_PvP-APIs in einem zukuenftigen Forever-Build, soll das nur den
    -- PvP-Sieg-Screenshot ausfallen lassen und nicht das ganze Addon mit
    -- einem sichtbaren Lua-Error stoeren - alle anderen Funktionen
    -- (eigene Screenshots, Gilden-Dings) laufen unabhaengig davon weiter.
    pcall(function()
        local isArena = C_PvP and C_PvP.IsArena and C_PvP.IsArena()
        local isBattleground = C_PvP and C_PvP.IsBattleground and C_PvP.IsBattleground()

        if not self:DidPlayerWin(winningTeam, isArena, isBattleground) then return end

        if isArena then
            if not self:GetSetting("enableArenaWinShots") then return end

            local rated = C_PvP.IsRatedArena and C_PvP.IsRatedArena()
            if self:GetSetting("onlyRatedArena") and not rated then return end

            self:TakeScreenshot(self.DefaultPvPDelay)
            return
        end

        if isBattleground then
            if not self:GetSetting("enableBattlegroundWinShots") then return end

            local rated = C_PvP.IsRatedBattleground and C_PvP.IsRatedBattleground()
            if self:GetSetting("onlyRatedBattlegrounds") and not rated then return end

            self:TakeScreenshot(self.DefaultPvPDelay)
            return
        end
    end)
end

function Addon:ZONE_CHANGED_NEW_AREA()
    if self:IsDelveInProgress() then
        self:StartWatcher()
    else
        self:StopWatcher()
    end
end

-- Auch nach einem Ladebildschirm oder /reload mitten in einer Tiefe den
-- Beobachter starten (dann gibt es kein ZONE_CHANGED_NEW_AREA).
function Addon:PLAYER_ENTERING_WORLD()
    self:ZONE_CHANGED_NEW_AREA()
end

-- Gildenweite Levelup-Benachrichtigungen (ehemals GrindDing)
function Addon:GUILD_ROSTER_UPDATE()
    self:CheckGuildDings()
end
