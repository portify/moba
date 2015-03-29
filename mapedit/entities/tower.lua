local tower = {}
tower.__index = tower

function tower:new(x, y)
    local new = setmetatable({}, self)
    new.team = false
    new.x = x
    new.y = y
    return new
end

function tower:open(line)
    local team, x, y = line:match("([01]) (.+) (.+)")
    local new = setmetatable({}, self)
    new.team = tonumber(team)
    new.x = tonumber(x)
    new.y = tonumber(y)
    return new
end

function tower:save()
    return tostring(self.team) .. " " .. tostring(self.x) .. " " .. tostring(self.y)
end

function tower:draw()
    local r, g, b

    if self.team == 0 then
        r, g, b = 255, 127, 50
    elseif self.team == 1 then
        r, g, b = 50, 127, 255
    else
        r, g, b = 127, 127, 127
    end

    -- -- Draw attack radius outline
    -- love.graphics.setLineWidth(1)
    --
    -- if target == control then
    --     love.graphics.setColor(255, 75, 75, 40)
    -- else
    --     love.graphics.setColor(r, g, b, 40)
    -- end
    --
    -- love.graphics.circle("fill", self.x, self.y, self.max_player_dist, self.max_player_dist * 2)
    -- love.graphics.circle("line", self.x, self.y, self.max_player_dist, self.max_player_dist * 2)

    -- Draw body
    love.graphics.setColor(r, g, b)
    love.graphics.circle("fill", self.x, self.y, 32, 64)

    -- Draw outline of body
    love.graphics.setLineWidth(4)
    love.graphics.setColor(r/2, g/2, b/2)
    love.graphics.circle("line", self.x, self.y, 32, 64)
end

return tower
