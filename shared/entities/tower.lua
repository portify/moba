local util = require "shared.util"

local tower = {
    max_player_dist = 150
}
tower.__index = tower
setmetatable(tower, entity)

function tower:new()
    return setmetatable({
        team = false,
        x = 0,
        y = 0,
        timer = 0
    }, self)
end

function tower:from_map(line)
    local team, x, y = line:match("([01]) (.+) (.+)")
    local new = self:new()

    new.team = tonumber(team)
    new.x = tonumber(x)
    new.y = tonumber(y)

    return new
end

function tower:pack(initial)
    if initial then
        return {self.team, self.x, self.y}
    else
        return {self.active_target}
    end
end

function tower:unpack(t, initial)
    if initial then
        self.team = t[1]
        self.x = t[2]
        self.y = t[3]
    else
        self.active_target = t[1]
    end
end

function tower:update(dt)
    if is_client then
        return
    end

    local active_target = self.active_target
    self.active_target = nil

    for id, ent in pairs(server.entities) do
        if getmetatable(ent) == entities.player and ent.team ~= self.team then
            local distance = util.dist(self.x, self.y, ent.px, ent.py)

            if distance <= self.max_player_dist and (self.active_target == nil or distance < lowest) then
                self.active_target = id
                lowest = distance
            end
        end
    end

    if active_target ~= self.active_target then
        update_entity(self)
    end

    if self.timer <= 0 then
        if self.active_target ~= nil then
            local p = entities.projectile:new()

            p.target = self.active_target
            p.life = -1
            p.speed = 150
            p.radius = 8
            p.damage = 12
            p.px = self.x
            p.py = self.y

            add_entity(p)

            self.timer = 1.5
        end
    else
        self.timer = self.timer - dt
    end
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

    local target
    local control = states.game:get_control()

    if self.active_target ~= nil then
        target = states.game.entities[self.active_target]
    end

    -- Draw attack radius outline
    love.graphics.setLineWidth(1)

    if target == control then
        love.graphics.setColor(255, 75, 75, 40)
    else
        love.graphics.setColor(r, g, b, 40)
    end

    love.graphics.circle("fill", self.x, self.y, self.max_player_dist, self.max_player_dist * 2)
    love.graphics.circle("line", self.x, self.y, self.max_player_dist, self.max_player_dist * 2)

    -- Draw line to current target
    if target ~= nil then
        love.graphics.setLineWidth(2)
        love.graphics.setColor(255, 75, 75)
        love.graphics.line(self.x, self.y, target.px, target.py)
    end

    -- Draw body
    love.graphics.setColor(r, g, b)
    love.graphics.circle("fill", self.x, self.y, 32, 64)

    -- Draw outline of body
    love.graphics.setLineWidth(4)
    love.graphics.setColor(r/2, g/2, b/2)
    love.graphics.circle("line", self.x, self.y, 32, 64)
end

return tower
