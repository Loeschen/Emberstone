-- rarekill.lua
--
-- Erkennt den Kill eines seltenen Mobs ("rare"/"rareelite") oder eines
-- Weltbosses ("worldboss") und loest dafuer einen eigenen Screenshot aus.
--
-- Anders als bei Dungeon-/Raid-Bossen (BOSS_KILL, ein dedizierter Blizzard-
-- Event) gibt es fuer Rar-Mobs/Weltbosse keinen eigenen "wurde getoetet"-
-- Event. Bewusst NICHT ueber das Kampf-Logbuch (COMBAT_LOG_EVENT_UNFILTERED)
-- geloest: genau dieser Event hat sich bei GrindShout auf WoW Forever als
-- Ausloeser fuer die "der Blizzard-UI vorbehalten"-Sperre herausgestellt,
-- selbst wenn der eigene Code dabei nichts Gefaehrliches tut. Stattdessen
-- wird UNIT_HEALTH auf das eigene Ziel beobachtet - derselbe, bereits in
-- GrindShouts Health.lua live erprobte und nachweislich unproblematische
-- Mechanismus, nur eben auf "target" statt "player" angewendet.
local ADDON_NAME, Addon = ...

Addon._rareKill = Addon._rareKill or { lastGUID = nil }

local RARE_CLASSIFICATIONS = {
    rare = true,
    rareelite = true,
}

-- Wird von Events.lua bei jedem UNIT_HEALTH-Event fuer "target" aufgerufen.
-- Feuert hoechstens einmal pro individuellem Ziel (GUID-Vergleich), auch
-- wenn UNIT_HEALTH fuer denselben toten Gegner noch mehrfach nachfeuert.
function Addon:CheckRareOrWorldBossKill(unit)
    if unit ~= "target" then return end
    -- In Instanzen koennen neuere Clients Einheiten-Daten als "geheime
    -- Werte" liefern, mit denen nicht gerechnet werden darf.
    local ok = pcall(self.CheckRareOrWorldBossKillUnsafe, self)
    if not ok then return end
end

function Addon:CheckRareOrWorldBossKillUnsafe()
    if not UnitExists("target") then return end
    if not UnitIsDead("target") then return end

    local classification = UnitClassification("target")
    local isWorldBoss = classification == "worldboss"
    local isRare = RARE_CLASSIFICATIONS[classification] == true

    if not isWorldBoss and not isRare then return end

    local guid = UnitGUID("target")
    if issecretvalue and (issecretvalue(guid) or issecretvalue(classification)) then return end
    if not guid or guid == self._rareKill.lastGUID then return end
    self._rareKill.lastGUID = guid

    if isWorldBoss then
        if self:GetSetting("enableWorldBossKillShots") then
            self:TakeScreenshot(self:GetDelay("worldBossKillDelay"))
        end
    elseif isRare then
        if self:GetSetting("enableRareKillShots") then
            self:TakeScreenshot(self:GetDelay("rareKillDelay"))
        end
    end
end
