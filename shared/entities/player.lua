local pathedentity = require "shared.entities.pathedentity"
local util = require "shared.util"

local player = {
    is_unit = true,
    radius = 8,
    use_funnel = true,
    use_outside_snap = true,
    allow_direct_move = true
}

player.__index = player
setmetatable(player, pathedentity)

function player:new(name)
    new = pathedentity.new(self)
    -- local sx, sy = self:get_world_instance().mesh[1]:center()

    new.name = name
    -- new.px = sx
    -- new.py = sy
    new.speed = 170
    new.health_max = 100
    new.health = new.health_max
    new.team = false

    if is_client then
        new.health_buffer = 0
        new._name_font = get_resource(love.graphics.newFont, 14)
    end

    return new
end

function player:pack(initial)
    if initial then
        return {self.name, self.team, self.health, self.health_max, pathedentity.pack(self, true)}
    else
        return {self.health, pathedentity.pack(self, false)}
    end
end

function player:unpack(t, initial)
    if initial then
        self.name = t[1]
        self.team = t[2]
        self.health = t[3]
        self.health_max = t[4]
        pathedentity.unpack(self, t[5], true)
    else
        local old = self.health
        self.health = t[1]
        pathedentity.unpack(self, t[2], false)

        local delta = old - self.health
        self.health_buffer = math.max(0, math.min(self.health_max - self.health, self.health_buffer + delta))
    end
end

function player:damage(hp)
    self.health = self.health - hp

    if self.health <= 0 then
        self.client.player = nil
        delay(1, function() self.client:spawn() end)
        remove_entity(self)
    else
        update_entity(self)
    end
end

function player:update(dt)
    if is_client then
        self.health_buffer = math.max(0, self.health_buffer - dt * 25)
    end

    pathedentity.update(self, dt)
end

function player:draw()
    pathedentity.draw(self)

    if debug_nav then -- Draw the plane we're in if any
        local plane = self:get_world_plane()

        if plane ~= nil then
            love.graphics.setColor(100, 200, 100, 100)
            plane:draw("fill")
        end
    end

    -- This draws aim direction
    -- love.graphics.setColor(255, 255, 255)
    -- love.graphics.setLineWidth(2)
    -- love.graphics.line(self.px, self.py, self.px + self.vx * 64, self.py + self.vy * 64)

    local r, g, b

    if self.team == 0 then
        r, g, b = 255, 200, 100
    elseif self.team == 1 then
        r, g, b = 100, 200, 255
    else
        r, g, b = 200, 200, 200
    end

    love.graphics.setColor(r, g, b)
    love.graphics.circle("fill", self.px, self.py, self.radius, self.radius * 2)
    love.graphics.setLineWidth(2)
    love.graphics.setColor(r/2, g/2, b/2)
    love.graphics.circle("line", self.px, self.py, self.radius, self.radius * 2)

    -- love.graphics.setColor(80, 80, 80)
    -- love.graphics.circle("fill", self.px, self.py, 8)
    -- love.graphics.setLineWidth(2)
    -- love.graphics.setColor(255, 255, 255)
    -- love.graphics.circle("line", self.px, self.py, 8)

    -- Draw health bar
    local width = 64
    local height = 12
    local spacing = 16

    local hp = self.health / self.health_max

    -- Background
    love.graphics.setColor(127, 127, 127)
    love.graphics.rectangle("fill",
        self.px - width / 2, self.py - self.radius / 2 - spacing - height,
        width, height)

    -- Lost health
    love.graphics.setColor(255, 50, 50)
    love.graphics.rectangle("fill",
        self.px - width / 2 + width * hp, self.py - self.radius / 2 - spacing - height,
        width * (self.health_buffer / self.health_max), height)

    -- Current health
    -- love.graphics.setColor(50, 255, 50)
    love.graphics.setColor(r, g, b)
    love.graphics.rectangle("fill",
        self.px - width / 2, self.py - self.radius / 2 - spacing - height,
        width * hp, height)

    -- Outline
    love.graphics.setColor(255, 255, 255)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line",
        self.px - width / 2, self.py - self.radius / 2 - spacing - height,
        width, height)

    if self.name ~= nil then
        love.graphics.setColor(r, g, b)
        love.graphics.setFont(self._name_font)
        love.graphics.printf(self.name, self.px - 200, self.py - self.radius / 2 - spacing - height - 14 - 8, 400, "center")
    end
end

function player:draw_minimap()
    local r, g, b

    if self.team == 0 then
        -- r, g, b = 255, 127, 50
        r, g, b = 125, 25, 175
    elseif self.team == 1 then
        r, g, b = 50, 127, 255
    else
        r, g, b = 127, 127, 127
    end

    if self.path ~= nil then
        love.graphics.setLineWidth(2)
        love.graphics.setColor(0, 255, 0)

        local i = #self.path

        while i > 1 do
            local a = self.path[i]
            local b = self.path[i - 1]

            if i == #self.path then
                a = {self.px, self.py}
            end

            love.graphics.line(a[1], a[2], b[1], b[2])
            i = i - 1
        end
    end

    love.graphics.setColor(r, g, b)
    love.graphics.circle("fill", self.px, self.py, self.radius * 8)
    love.graphics.setLineWidth(6)
    love.graphics.setColor(r/2, g/2, b/2)
    love.graphics.circle("line", self.px, self.py, self.radius * 8)
end

function player:use_ability(which, x, y)
    self.path = nil
    self.path_progress = 0

    local dx = x - self.px
    local dy = y - self.py
    local d = math.sqrt(dx^2 + dy^2)

    self.vx = dx / d
    self.vy = dy / d

    update_entity(self)

    if which == 1 then
        local p = entities.projectile:new()

        -- Try to target
        for id, ent in pairs(server.entities) do
            if ent ~= self and getmetatable(ent) == entities.player and
                (ent.px-x)^2 + (ent.py-y)^2 <= 64
            then
                p.target = id
                break
            end
        end

        p.ignore[self] = true
        p.team = self.team
        p.life = 3
        p.speed = 500
        p.radius = 8
        p.damage = 16
        p.px = self.px + self.vx * 8
        p.py = self.py + self.vy * 8
        p.vx = self.vx
        p.vy = self.vy

        add_entity(p)
    elseif which == 2 then
        local target

        -- Try to target
        for id, ent in pairs(server.entities) do
            if ent ~= self and getmetatable(ent) == entities.player and
                (ent.px-x)^2 + (ent.py-y)^2 <= 64
            then
                target = id
                break
            end
        end

        if target == nil then
            return
        end

        local p = entities.projectile:new()

        p.ignore[self] = true
        p.team = self.team
        p.target = target
        p.life = -1
        p.speed = 200
        p.radius = 8
        p.damage = 8
        p.px = self.px + self.vx * 8
        p.py = self.py + self.vy * 8

        add_entity(p)
    elseif which == 3 then
        local minion = entities.minion:new(x, y)
        minion.team = 0
        minion:begin_a_quest(next(server.world.paths))
        add_entity(minion)
    end
end

return player
