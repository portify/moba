local pathedentity = require "shared.entities.pathedentity"
local util = require "shared.util"

local player = {
    use_funnel = true,
    use_outside_snap = true,
    allow_direct_move = true
}

player.__index = player
setmetatable(player, pathedentity)

function player:new(name)
    new = pathedentity.new(self)
    local sx, sy = self:get_world_instance().mesh[1]:center()

    new.name = name
    new.px = sx
    new.py = sy
    new.speed = 170
    new.health = 100

    if is_client then
        new._name_font = get_resource(love.graphics.newFont, 14)
    end

    return new
end

function player:pack(initial)
    if initial then
        return {self.name, self.health, pathedentity.pack(self, true)}
    else
        return {self.health, pathedentity.pack(self, false)}
    end
end

function player:unpack(t, initial)
    if initial then
        self.name = t[1]
        self.health = t[2]
        pathedentity.unpack(self, t[3], true)
    else
        self.health = t[1]
        pathedentity.unpack(self, t[2], false)
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

function player:draw()
    pathedentity.draw(self)

    if debug_nav then
        local plane = self:get_world_plane()

        if plane ~= nil then
            love.graphics.setColor(100, 200, 100, 100)
            plane:draw("fill")
        end
    end

    -- love.graphics.setColor(255, 255, 255)
    -- love.graphics.setLineWidth(2)
    -- love.graphics.line(self.px, self.py, self.px + self.vx * 64, self.py + self.vy * 64)

    love.graphics.setColor(80, 80, 80)
    love.graphics.circle("fill", self.px, self.py, 8)
    love.graphics.setLineWidth(2)
    love.graphics.setColor(255, 255, 255)
    love.graphics.circle("line", self.px, self.py, 8)

    local width = 64
    local height = 12
    local spacing = 16

    local hp = self.health / 100

    love.graphics.setColor(127, 127, 127)
    love.graphics.rectangle("fill",
        self.px - width / 2, self.py - 4 - spacing - height,
        width, height)

    love.graphics.setColor(255, 50, 50)
    love.graphics.rectangle("fill",
        self.px - width / 2, self.py - 4 - spacing - height,
        width * hp, height)

    love.graphics.setColor(255, 255, 255)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line",
        self.px - width / 2, self.py - 4 - spacing - height,
        width, height)

    if self.name ~= nil then
        love.graphics.setFont(self._name_font)
        love.graphics.printf(self.name, self.px - 200, self.py - 4 - spacing - height - 14 - 8, 400, "center")
    end
end

function player:use_ability(i, x, y)
    self.path = nil
    self.path_progress = 0

    local dx = x - self.px
    local dy = y - self.py
    local d = math.sqrt(dx^2 + dy^2)

    self.vx = dx / d
    self.vy = dy / d

    update_entity(self)

    if i == 1 then
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
        p.life = 3
        p.speed = 500
        p.radius = 8
        p.damage = 16
        p.px = self.px + self.vx * 8
        p.py = self.py + self.vy * 8
        p.vx = self.vx
        p.vy = self.vy

        add_entity(p)
    elseif i == 2 then
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
        p.target = target
        p.life = -1
        p.speed = 200
        p.radius = 8
        p.damage = 8
        p.px = self.px + self.vx * 8
        p.py = self.py + self.vy * 8

        add_entity(p)
    elseif i == 3 then
        local minion = entities.minion:new(x, y)
        add_entity(minion)
    end
end

return player
