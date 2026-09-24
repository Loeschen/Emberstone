-- commands.lua
local ADDON_NAME, Addon = ...

Addon.OptionsCategory = nil

function Addon:SetupSlash()
    SLASH_EMBERSTONE1 = "/emberstone"
    SLASH_EMBERSTONE2 = "/ding"
    SlashCmdList["EMBERSTONE"] = function(msg)
        self:HandleSlash(msg)
    end
end

function Addon:HandleSlash(msg)
    -- WICHTIG: nur das erste Wort (der eigentliche Befehl) wird
    -- kleingeschrieben verglichen - der Rest (z.B. ein eigener GZ-Text bei
    -- "/emberstone gzmsg guild ...") muss seine Gross-/Kleinschreibung
    -- behalten, sonst wuerde ein selbst eingegebener Nachrichtentext
    -- ungewollt komplett kleingeschrieben gespeichert.
    msg = msg or ""
    local firstSpace = msg:find(" ")
    local cmd = (firstSpace and msg:sub(1, firstSpace - 1) or msg):lower()
    local rest = firstSpace and msg:sub(firstSpace + 1) or ""

    if cmd == "test" then
        self:TestGuildDing()
        return
    end

    if cmd == "gzmsg" then
        self:HandleGZMsgCommand(rest)
        return
    end

    if cmd == "ignore" then
        self:HandleIgnoreCommand(rest)
        return
    end

    if cmd == "afk" then
        self:HandleAfkCommand(rest)
        return
    end

    if cmd == "log" then
        self:HandleLogCommand(rest)
        return
    end

    if cmd == "minimap" then
        self:SetMinimapShown(self:GetSetting("minimapHide") and true or false)
        print(self:GetSetting("minimapHide") and Addon.L["MINIMAP_OFF"] or Addon.L["MINIMAP_ON"])
        return
    end

    self:OpenOptions()
end
