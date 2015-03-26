local pause = {}

local font_header
local font_stats

function pause:init()
    font_header = get_resource(love.graphics.newFont, 24)
    font_stats = get_resource(love.graphics.newFont, 12)
end

function pause:enter(previous)
    self.previous = previous
    love.mouse.setGrabbed(false)
end

function pause:leave()
    self.previous = nil
end

function pause:update(dt)
    self.previous:update(dt, true)
end

function pause:draw()
    self.previous:draw()

    love.graphics.setColor(0, 0, 0, 150)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getDimensions())

    love.graphics.setColor(255, 255, 255)
    love.graphics.setFont(font_header)
    love.graphics.print("PAUSED", 128, 128)
    love.graphics.setFont(font_stats)
    love.graphics.printf(
        "latency: " .. self.previous.server:round_trip_time() .. "ms\nfps: " .. love.timer.getFPS(),
        8, 8, love.graphics.getWidth() - 16, "right")
end

function pause:keypressed(key)
    if key == "escape" then
        gamestate.pop()
    end
end

return pause
