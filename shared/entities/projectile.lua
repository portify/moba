local util = require "shared.util"

local projectile = {}
projectile.__index = projectile
setmetatable(projectile, entity)

projectile.type_loaders = {}

function projectile:register_type(name, loader)
    if self.types ~= nil then
        error("Cannot call projectile.register_type after projectile.client_init")
    end

    self.type_loaders[name] = loader
end

function projectile:client_init()
    self.types = {}

    for name, loader in pairs(self.type_loaders) do
        self.types[name] = loader(self)
        self.types[name]:stop()
    end
end

function projectile:new(type)
    new = setmetatable({}, self)

    new.type = type
    new.life = 0
    new.speed = 0
    new.radius = 0
    new.damage = 0
    new.vx = 0
    new.vy = 0
    new.team = nil

    if not is_client then
        new.ignore = {}
    end

    return new
end

function projectile:removed()
    if is_client and self.emitter then
        self.is_removed = true
        self.emitter:stop()
        return true
    end
end

function projectile:pack(type)
    if type == PACK_TYPE.INITIAL then
        return {self.px, self.py, self.type, self.vx, self.vy, self.speed, self.target, self.unescapeable}
    else
        return {self.px, self.py}
    end
end

function projectile:unpack(t, type)
    self.px = t[1]
    self.py = t[2]

    if type == PACK_TYPE.INITIAL then
        self.type = t[3]

        if self.types[self.type] ~= nil then
            self.emitter = self.types[self.type]:clone()
            self.emitter:reset()
            self.emitter:start()
        end

        self.vx = t[4]
        self.vy = t[5]
        self.speed = t[6]
        self.target = t[7]
        self.unescapeable = t[8]
    end
end

function projectile:get_world_plane()
    if self.px ~= self.plane_x or self.py ~= self.plane_y then
        self.plane = self:get_world_instance():get_plane(self.px, self.py)
        self.plane_x = self.px
        self.plane_y = self.py
    end

    return self.plane
end

function projectile:update(dt)
    if self.is_removed then
        self.emitter:update(dt)

        if self.emitter:getCount() == 0 then
            states.game.entities[self.__id] = nil
            self.__id = nil
        end

        return
    end

    if not is_client and self.life > 0 then
        self.life = self.life - dt

        if self.life <= 0 then
            remove_entity(self)
            return
        end
    end

    local a = {self.px, self.py}
    local target

    if self.target ~= nil then
        if is_client then
            target = states.game.entities[self.target]
        else
            target = server.entities[self.target]
        end
    end

    if target ~= nil then
        local dx = target.px - self.px
        local dy = target.py - self.py
        local d = math.sqrt(dx^2 + dy^2)
        self.vx = dx / d
        self.vy = dy / d

        if self.unescapeable then
            self.speed = self.speed * (1 + dt / 2)
        end

        if self.speed * dt >= d then
            self.speed = d / dt
        end

    elseif not is_client and self.life < 0 then
        remove_entity(self)
        return
    end

    self.px = self.px + self.vx * self.speed * dt
    self.py = self.py + self.vy * self.speed * dt

    local b = {self.px, self.py}

    if not is_client then
        for id, ent in pairs(server.entities) do
            if
                ent ~= self and
                ent.is_unit and
                not self.ignore[ent] and
                (self.target == nil or id == self.target) and
                -- util.line_on_circle(a, b, {ent.px, ent.py}, self.radius)
                util.circle_on_circle(ent.px, ent.py, ent.radius, self.px, self.py, self.radius)
            then
                if ent.team ~= self.team then
                    ent:damage(self.damage)
                end

                remove_entity(self)
                return
            end
        end
    end

    if is_client then
        self.emitter:moveTo(self.px, self.py)
        self.emitter:setDirection(math.atan2(self.vy, self.vx))
        self.emitter:update(dt)
    end
end

function projectile:draw()
    if self.emitter ~= nil then
        love.graphics.setColor(255, 255, 255)
        -- love.graphics.draw(self.emitter, self.px, self.py)
        love.graphics.draw(self.emitter)
    end

    -- love.graphics.setColor(255, 80, 80)
    -- love.graphics.circle("fill", self.px, self.py, 7, 14)
    -- love.graphics.setLineWidth(2)
    -- love.graphics.setColor(255, 160, 160)
    -- love.graphics.circle("line", self.px, self.py, 7, 14)
end

return projectile
