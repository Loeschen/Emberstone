-- pvp.lua
local ADDON_NAME, Addon = ...

-- GetBattlefieldArenaFaction() ist ein altes, nicht C_*-namespaced Global.
-- Nach der Erfahrung mit GetItemInfo() (das sich in GrindLedger als in
-- Forever entfernt herausgestellt hat) ist nicht auszuschliessen, dass
-- auch diese Funktion irgendwann verschoben/umbenannt wird - dafuer liegt
-- aber keine Bestaetigung vor, daher wird hier NICHT spekulativ auf eine
-- vermutete C_PvP-Variante umgeschrieben. Stattdessen nur defensiv
-- abgesichert: schlaegt der Aufruf fehl, gibt es nil statt eines harten
-- Lua-Errors.
local function SafeGetBattlefieldArenaFaction()
    if not GetBattlefieldArenaFaction then return nil end
    local ok, result = pcall(GetBattlefieldArenaFaction)
    if ok then return result end
    return nil
end

function Addon:GetTeamIndex(isArena, isBattleground)
    if isArena then
        return SafeGetBattlefieldArenaFaction()
    end

    if isBattleground then
        if C_PvP and C_PvP.IsMatchFactional and C_PvP.IsMatchFactional() then
            return (UnitFactionGroup("player") == "Horde") and 0 or 1
        end
        return SafeGetBattlefieldArenaFaction() -- cross-faction BGs
    end

    return nil
end

function Addon:DidPlayerWin(winningTeam, isArena, isBattleground)
    local teamIndex = self:GetTeamIndex(isArena, isBattleground)
    return (teamIndex ~= nil and winningTeam ~= nil and teamIndex == winningTeam)
end
