-- delves.lua
local ADDON_NAME, Addon = ...

Addon._delve = Addon._delve or {}
local POLL_INTERVAL = 0.35

-- Guard against missing or removed Delve APIs by feature-detecting before calling.
function Addon:IsDelveComplete()
    return C_PartyInfo
        and type(C_PartyInfo.IsDelveComplete) == "function"
        and C_PartyInfo.IsDelveComplete()
end

function Addon:IsDelveInProgress()
    return C_PartyInfo
        and type(C_PartyInfo.IsDelveInProgress) == "function"
        and C_PartyInfo.IsDelveInProgress()
end

function Addon:StopWatcher()
    local delve = self._delve
    if delve.ticker then
        delve.ticker:Cancel()
        delve.ticker = nil
    end
end

function Addon:StartWatcher()
    local delve = Addon._delve
    if delve.ticker then return end

    delve.completed = false
    delve.ticker = C_Timer.NewTicker(POLL_INTERVAL, function()
        -- If we're in neither state, we're done watching.
        if not Addon:IsDelveInProgress() and not Addon:IsDelveComplete() then
            Addon:StopWatcher()
            return
        end

        -- Completion: fire once, then stop watching.
        if not delve.completed and Addon:IsDelveComplete() then
            delve.completed = true
            if self:GetSetting("enableDelveShots") then
                self:TakeScreenshot(self:GetDelay("delveDelay"))
            end
            Addon:StopWatcher()
        end
    end)
end
