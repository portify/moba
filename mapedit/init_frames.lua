function love.load()
    loveframes = require("lib.loveframes")

    -- local button = loveframes.Create("button")
    -- button:SetPos(10, 10)

    local layers = loveframes.Create("frame")
    layers:SetName("Layers")
    layers:SetPos(200, 300)
    layers:SetSize(500, 455)
    local list = loveframes.Create("list", layers)
    list:SetPos(5, 30)
    list:SetSize(490, 300)
    list:SetPadding(5)
    list:SetSpacing(5)
    local text1 = loveframes.Create("text", list)
    text1:SetPos(5, 5)
    text1:SetText("Hello world")

    local bar = loveframes.Create("panel")
    local button = loveframes.Create("button", bar)
    button:SetText("File")

    bar:SetSize(love.graphics.getWidth(), button:GetHeight() + 4)

    function button:OnClick(x, y)
        local menu = loveframes.Create("menu")
        menu:AddOption("New", false, function() end)
        menu:AddOption("Open...", false, function() end)
        menu:AddDivider()
        menu:AddOption("Save", false, function() end)
        menu:AddOption("Save as...", false, function() end)
        menu:AddDivider()
        menu:AddOption("Exit", false, love.event.quit)
        menu:SetPos(self:GetX(), self:GetY() + self:GetHeight())
    end

    -- local submenu3 = loveframes.Create("menu")
    -- submenu3:AddOption("Option 1", false, function() end)
    -- submenu3:AddOption("Option 2", false, function() end)
    --
    -- local submenu2 = loveframes.Create("menu")
    -- submenu2:AddOption("Option 1", false, function() end)
    -- submenu2:AddOption("Option 2", false, function() end)
    -- submenu2:AddOption("Option 3", false, function() end)
    -- submenu2:AddOption("Option 4", false, function() end)
    --
    -- local submenu1 = loveframes.Create("menu")
    -- submenu1:AddSubMenu("Option 1", false, submenu3)
    -- submenu1:AddSubMenu("Option 2", false, submenu2)
    --
    -- local menu = loveframes.Create("menu")
    -- menu:AddOption("Option A", false, function() end)
    -- menu:AddOption("Option B", false, function() end)
    -- menu:AddDivider()
    -- menu:AddOption("Option C", false, function() end)
    -- menu:AddOption("Option D", false, function() end)
    -- menu:AddDivider()
    -- menu:AddSubMenu("Option E", false, submenu1)
    -- menu:SetPos(x, y)
end

function love.update(dt)
    loveframes.update(dt)
end

function love.draw()
    loveframes.draw()
end

function love.mousepressed(x, y, button)
    loveframes.mousepressed(x, y, button)
end

function love.mousereleased(x, y, button)
    loveframes.mousereleased(x, y, button)
end

function love.keypressed(key, unicode)
    loveframes.keypressed(key, unicode)
end

function love.keyreleased(key)
    loveframes.keyreleased(key)
end

function love.textinput(text)
    loveframes.textinput(text)
end
