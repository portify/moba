-- 255 219 158

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

function player:client_init()
    -- self.health_bar_back = love.graphics.newImage("assets/health_bar_back.png")
    -- self.health_bar_start = love.graphics.newImage("assets/health_bar_start.png")
    -- self.health_bar_piece = love.graphics.newImage("assets/health_bar_piece.png")
    -- self.health_bar_end = love.graphics.newImage("assets/health_bar_end.png")
    self.image_bar_tick = love.graphics.newImage("assets/health_bar_tick.png")
    self.image_bar_back = love.graphics.newImage("assets/health_bar2_back.png")
    self.image_bar_health = love.graphics.newImage("assets/health_bar2_health.png")
    self.image_bar_mana = love.graphics.newImage("assets/health_bar2_mana.png")
    self.image_bar_xp = love.graphics.newImage("assets/health_bar2_xp.png")
    self.image_bar_glass = love.graphics.newImage("assets/health_bar2_glass.png")
end

function player:new(name)
    new = pathedentity.new(self)

    new.name = name
    new.speed = 170
    new.team = false
    new.health_max = 300
    new.health = new.health_max
    new.mana_max = 300
    new.mana = new.mana_max
    new.level = 1
    new.xp = 0

    if is_client then
        new.health_anim = new.health
        new._name_font = get_resource(love.graphics.newFont, 14)

        local w, h
        w, h = new.image_bar_health:getDimensions()
        new.quad_bar_health = love.graphics.newQuad(0, 0, w, h, w, h)
        new.quad_bar_health_anim = love.graphics.newQuad(0, 0, w, h, w, h)
        w, h = new.image_bar_mana:getDimensions()
        new.quad_bar_mana = love.graphics.newQuad(0, 0, w, h, w, h)
        w, h = new.image_bar_xp:getDimensions()
        new.quad_bar_xp = love.graphics.newQuad(0, h, w, 0, w, h)
    else
        new.xp = 50
    end

    return new
end

function player:pack(initial)
    if initial then
        return {
            self.name, self.team,
            self.health, self.health_max,
            self.mana, self.mana_max,
            self.xp,
            pathedentity.pack(self, true)
        }
    else
        return {
            self.health,
            self.mana,
            self.xp,
            pathedentity.pack(self, false)
        }
    end
end

function player:unpack(t, initial)
    local health = self.health
    local mana = self.mana
    local xp = self.xp

    if initial then
        self.name = t[1]
        self.team = t[2]
        self.health = t[3]
        self.health_max = t[4]
        self.mana = t[5]
        self.mana_max = t[6]
        self.xp = t[7]
        pathedentity.unpack(self, t[8], true)
    else
        self.health = t[1]
        self.health_anim = math.max(self.health, self.health_anim)
        self.mana = t[2]
        self.xp = t[3]
        pathedentity.unpack(self, t[4], false)
    end

    if self.health ~= health then
        local w, h = self.image_bar_health:getDimensions()
        self.quad_bar_health:setViewport(0, 0, w * (self.health / self.health_max), h)
    end

    if self.mana ~= mana then
        local w, h = self.image_bar_mana:getDimensions()
        self.quad_bar_mana:setViewport(0, 0, w * (self.mana / self.mana_max), h)
    end

    if self.xp ~= xp then
        local w, h = self.image_bar_xp:getDimensions()
        local f = self.xp / 100 -- test
        print(f)
        self.quad_bar_xp:setViewport(0, h * f, w, h * (1 - f))
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
    if is_client and self.health_anim > self.health then
        self.health_anim = math.max(self.health, self.health_anim - dt * 25)

        if self.health_anim > self.health then
            local w, h = self.image_bar_health:getDimensions()
            self.quad_bar_health_anim:setViewport(0, 0, w * (self.health_anim / self.health_max), h)
        end
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

    self:draw_ui()
end

function player:draw_ui()
    local w = self.image_bar_back:getWidth()
    local h = self.image_bar_back:getHeight()
    local x = math.floor(self.px - w / 2 + 0.5)
    local y = math.floor(self.py - h - self.radius - 4 + 0.5)

    love.graphics.setColor(255, 255, 255)
    love.graphics.draw(self.image_bar_back, x, y)

    if self.health_anim > self.health then
        love.graphics.setColor(255, 150, 100)
        love.graphics.draw(self.image_bar_health, self.quad_bar_health_anim, x + 16, y + 17)
    end

    love.graphics.setColor(255, 219, 158) -- Original yellow
    love.graphics.draw(self.image_bar_health, self.quad_bar_health, x + 16, y + 17)

    -- Draw ticks over health
    local i = 1
    local step = 100
    local bw = self.image_bar_health:getWidth()
    local tw = self.image_bar_tick:getWidth()

    love.graphics.setColor(255, 255, 255)

    while i * step < self.health do
        local sx = (step / self.health_max) * i * bw - tw / 2
        love.graphics.draw(self.image_bar_tick, x + 16 + sx, y + 17)
        i = i + 1
    end

    -- Mana bar
    -- love.graphics.setColor(255, 255, 255)
    love.graphics.draw(self.image_bar_mana, self.quad_bar_mana, x + 16, y + 29)

    -- Level
    local xpx, xpy, xpw, xph = self.quad_bar_xp:getViewport()
    love.graphics.draw(self.image_bar_xp, self.quad_bar_xp, x + 3, y + 3 + xpy)
    love.graphics.setFont(self._name_font)
    love.graphics.print(tostring(self.level), x + 8, y + 4)

    -- Glass over level
    love.graphics.draw(self.image_bar_glass, x + 3, y + 3)

    if self.name ~= nil then
        local r, g, b

        if self.team == 0 then
            r, g, b = 255, 200, 100
        elseif self.team == 1 then
            r, g, b = 100, 200, 255
        else
            r, g, b = 200, 200, 200
        end

        love.graphics.setColor(r, g, b)
        love.graphics.setFont(self._name_font)
        love.graphics.printf(self.name, math.floor(self.px - 200 + 0.5), y - 8 + 6, 400, "center")
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
