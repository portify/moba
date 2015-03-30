local util = require "shared.util"

entities.projectile:register_type("tower", function(self)
    -- local image = love.graphics.newImage("assets/arrow.png")
    local image = get_resource(love.graphics.newImage, "assets/arrow.png")
    -- local system = love.graphics.newParticleSystem(image, 60)
    local system = love.graphics.newParticleSystem(image, 175) -- very bad

    --system:setParticleLifetime(0.4, 0.4)
    system:setParticleLifetime(3, 3)
    system:setEmissionRate(50)
    system:setRelativeRotation(true)
    system:setSizes(0.3, 0.2, 0.1)
    --system:setLinearAcceleration(-60, -60, 60, 60)
    --system:setTangentialAcceleration(-256, 256)
    system:setSpeed(5,5)
    system:setColors(
        255, 50, 75, 255,
        255, 50, 75, 128,
        255, 50, 75, 64,
        255, 50, 75, 0)

    return system
end)


local tower = {
    is_unit = true,
    radius = 32,
    health_max = 2500,
    max_player_dist = 150
}

tower.__index = tower
setmetatable(tower, entity)

function tower:new()
    return setmetatable({
        team = false,
        px = 0,
        py = 0,
        timer = 0,
        health = self.health_max,
        damage_scale = 1,
    }, self)
end

function tower:from_map(line)
    local team, x, y = line:match("([01]) (.+) (.+)")
    local new = self:new()

    new.team = tonumber(team)
    new.px = tonumber(x)
    new.py = tonumber(y)

    return new
end

function tower:pack(initial)
    if initial then
        return {self.team, self.px, self.py}
    else
        return {self.active_target, self.health}
    end
end

function tower:unpack(t, initial)
    if initial then
        self.team = t[1]
        self.px = t[2]
        self.py = t[3]
    else
        self.active_target = t[1]
        self.health = t[2]
    end
end

function tower:damage(hp)
    local prev = self.health
    self.health = math.max(0, self.health - hp)

    if prev ~= self.health then
        if self.health <= 0 then
            self.active_target = nil
        end

        update_entity(self)
    end
end

function tower:update(dt)
    if is_client or self.health <= 0 then
        return
    end

    local active_target = self.active_target

    if active_target ~= nil then
        local ent = server.entities[active_target]

        if
            ent == nil or
            util.dist(self.px, self.py, ent.px, ent.py) > self.max_player_dist
        then
            self.active_target = nil
            self.damage_scale = 1
        end
    end

    if self.active_target == nil then
        for id, ent in pairs(server.entities) do
            if ent ~= self and ent.is_unit and ent.team ~= self.team then
                local distance = util.dist(self.px, self.py, ent.px, ent.py)

                if distance <= self.max_player_dist and (self.active_target == nil or distance < lowest) then
                    self.active_target = id
                    lowest = distance
                end
            end
        end
    end

    if active_target ~= self.active_target then
        update_entity(self)
    end

    if self.timer <= 0 then
        if self.active_target ~= nil then
            local p = entities.projectile:new("tower")

            p.ignore[self] = true
            p.target = self.active_target
            p.unescapeable = true
            p.life = -1
            p.speed = 100
            p.radius = 8
            p.damage = 100 * self.damage_scale
            p.px = self.px
            p.py = self.py
            p.team = self.team

            add_entity(p)

            self.timer = 1.5
            self.damage_scale = math.min(3.5, self.damage_scale + 0.25)
        end
    else
        self.timer = self.timer - dt
    end
end

function tower:draw()
    local r, g, b

    if self.team == 0 then
        -- r, g, b = 255, 127, 50
        r, g, b = 125, 25, 175
    elseif self.team == 1 then
        r, g, b = 50, 127, 255
    else
        r, g, b = 127, 127, 127
    end

    if self.health > 0 then
        local target
        local control = states.game:get_control()

        if self.active_target ~= nil then
            target = states.game.entities[self.active_target]
        end

        -- Draw attack radius outline
        love.graphics.setLineWidth(1)

        if control ~= nil and target == control then
            love.graphics.setColor(255, 0, 0, 40)
        else
            love.graphics.setColor(r, g, b, 40)
        end

        love.graphics.circle("fill", self.px, self.py, self.max_player_dist, self.max_player_dist * 2)
        love.graphics.circle("line", self.px, self.py, self.max_player_dist, self.max_player_dist * 2)

        -- Draw line to current target
        if target ~= nil then
            love.graphics.setLineWidth(2)
            love.graphics.setColor(255, 75, 75)
            love.graphics.line(self.px, self.py, target.px, target.py)
        end
    end

    -- Draw body
    love.graphics.setColor(r, g, b)
    love.graphics.circle("fill", self.px, self.py, self.radius, self.radius * 2)

    -- Draw outline of body
    love.graphics.setLineWidth(4)
    love.graphics.setColor(r/2, g/2, b/2)
    love.graphics.circle("line", self.px, self.py, self.radius, self.radius * 2)

    if self.health > 0 then
        -- Draw health bar
        local width = 64
        local height = 12
        local spacing = 32
        local hp = self.health / self.health_max

        love.graphics.setColor(127, 127, 127)
        love.graphics.rectangle("fill",
            self.px - width / 2, self.py - self.radius / 2 - spacing - height,
            width, height)

        love.graphics.setColor(r, g, b)
        love.graphics.rectangle("fill",
            self.px - width / 2, self.py - self.radius / 2 - spacing - height,
            width * hp, height)

        love.graphics.setColor(255, 255, 255)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line",
            self.px - width / 2, self.py - self.radius / 2 - spacing - height,
            width, height)
    end
end

function tower:draw_minimap()
    local r, g, b

    if self.team == 0 then
        -- r, g, b = 255, 127, 50
        r, g, b = 125, 25, 175
    elseif self.team == 1 then
        r, g, b = 50, 127, 255
    else
        r, g, b = 127, 127, 127
    end

    love.graphics.setColor(r, g, b)
    love.graphics.circle("fill", self.px, self.py, 54)
end

return tower
