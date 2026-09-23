-- util.lua
local ADDON_NAME, Addon = ...

-- Kleiner Helfer fuer Delay-Lookups mit sicherem Fallback
function Addon:GetDelay(key)
    local default = Addon.Defaults[key] or Addon.DefaultDelay
    local value   = Addon:GetSetting(key)

    if type(value) ~= "number" or value < 0 then
        return default
    end

    return value
end

function Addon:NumToString(n)
    if n == 0 then
        return "0"
    end

    return tostring(n)
end
