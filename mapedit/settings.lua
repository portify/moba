local ser = require "lib/ser"
local window

local function save()
    love.filesystem.write("config-mapedit.lua", ser(config))
end

return function()
    if window ~= nil then
        return
    end

    window = loveframes.Create("frame")
    window:SetName("Settings")
    window:SetScreenLocked(1)
    window:SetSize(640, 480)
    window:Center()

    local check1 = loveframes.Create("checkbox", window)
    check1:SetText("Enable FPS warning")
    check1:SetPos(6 + 1, 6 + 25)
    check1:SetChecked(config.enable_fps_warning)
    function check1:OnChanged(value)
        config.enable_fps_warning = value
        save()
    end

    local text1 = loveframes.Create("text", window)
    text1:SetPos(6 + 1, 6 + 25 + 20 + 12 + 6 + 4)
    text1:SetText("Skin:")

    local multichoice1 = loveframes.Create("multichoice", window)
    multichoice1:SetPos(6 + 1 + 50, 6 + 25 + 20 + 12 + 6)
    for name, skin in pairs(loveframes.skins.available) do
        multichoice1:AddChoice(name)
        if name == config.ui_skin then
            multichoice1:SetChoice(name)
        end
    end
    function multichoice1:OnChoiceSelected(name)
        loveframes.util.SetActiveSkin(name)
        config.ui_skin = name
        save()
    end

    function window:OnClose()
        window = nil
    end
end
