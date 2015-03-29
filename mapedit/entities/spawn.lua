local util = require "mapedit.util"

local spawn = {}
spawn.__index = spawn

local font = love.graphics.newFont(20)

function spawn:new(x, y)
    local new = setmetatable({}, self)
    new.team = false
    new.x = x
    new.y = y
    return new
end

function spawn:open(line)
    local team, x, y = line:match("([01]) (.+) (.+)")
    local new = setmetatable({}, self)
    new.team = tonumber(team)
    new.x = tonumber(x)
    new.y = tonumber(y)
    return new
end

function spawn:save()
    return tostring(self.team) .. " " .. tostring(self.x) .. " " .. tostring(self.y)
end

function spawn:is_hover(x, y)
    return util.dist2(x, y, self.x, self.y) <= 256
end

function spawn:draw(state)
    local r, g, b

    if self.team == 0 then
        r, g, b = 255, 127, 50
    elseif self.team == 1 then
        r, g, b = 50, 127, 255
    else
        r, g, b = 127, 127, 127
    end

    if state == "select" then
        r = r * 1.5
        g = g * 1.5
        b = b * 1.5
    elseif state == "hover" then
        r = r * 1.2
        g = g * 1.2
        b = b * 1.2
    end

    -- Draw body
    love.graphics.setColor(r, g, b)
    love.graphics.circle("fill", self.x, self.y, 16, 32)

    -- Draw outline of body
    love.graphics.setLineWidth(4)
    love.graphics.setColor(r/2, g/2, b/2)
    love.graphics.circle("line", self.x, self.y, 16, 32)

    -- Draw text on top
    love.graphics.setFont(font)
    love.graphics.print("S", self.x - font:getWidth("S") / 2, self.y - font:getHeight("S") / 2)
end

return spawn
