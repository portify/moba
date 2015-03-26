local pause = {}

local menu_lib = require "client/menu"
local menu

local font_stats

function pause:init()
    local font_label = love.graphics.newFont(24)
    font_stats = get_resource(love.graphics.newFont, 10)

    menu = menu_lib:new(64, 64, font_label, {
        {label = "Resume", func = function() gamestate.pop() end},
        {label = "Disconnect from server", func = function()
            self.previous:disconnect()
        end, disabled = args.local_loop},
        {label = "Exit game", func = function() love.event.quit() end}
   }, 4, 40)
end

function pause:enter(previous)
    self.previous = previous
    self.relative = love.mouse.getRelativeMode()

    menu.index = 1

    love.mouse.setGrabbed(false)
    love.mouse.setRelativeMode(false)
end

function pause:leave()
    love.mouse.setRelativeMode(self.relative)
    self.previous = nil
end

function pause:quit()
    self.previous:quit()
end

function pause:keypressed(key, code)
    if key == "down" then
        menu:next()
    elseif key == "up" then
        menu:previous()
    end
end

function pause:keyreleased(key, code)
    if key == "escape" then
        gamestate.pop()
    elseif key == "return" then
        menu:activate()
    end
end

function pause:mousepressed(x, y, button)
    menu:mousepressed(x, y, button)
end

function pause:update(dt)
    self.previous:update(dt)
    menu:update(dt)
end

function pause:draw()
    self.previous:draw()

    love.graphics.setColor(0, 0, 0, 150)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getDimensions())

    menu:draw()

    -- Draw stats in top right
    love.graphics.setFont(font_stats)
    love.graphics.setColor(255, 255, 255, 150)
    love.graphics.printf(
        "Frame time: " .. math.ceil(love.timer.getDelta() * 1000000) .. "us (" .. love.timer.getFPS() .."fps)\n" ..
        "Ping: " .. self.previous.server:round_trip_time() .. "ms\n" ..
        "Server: " .. self.previous.address,
        0, 8, love.graphics.getWidth() - 8, "right")
end

return pause
