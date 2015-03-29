local projectile = {}
projectile.__index = projectile
setmetatable(projectile, entity)

function projectile.client_init()
    local image = love.graphics.newImage("assets/cloud.png")
    local system = love.graphics.newParticleSystem(image, 60)

    system:setParticleLifetime(0.4, 0.4)
    system:setEmissionRate(30)
    system:setSizes(0.1, 0.2, 0.3)
    system:setLinearAcceleration(-60, -60, 60, 60)
    system:setTangentialAcceleration(-256, 256)
    system:setColors(
        255, 255, 255, 0,
        255, 255, 255, 255,
        255, 255, 255, 255,
        255, 255, 255, 0)

    projectile.emitter_type = system
    projectile.emitter_type:stop()
end

function projectile:new()
    new = setmetatable({}, self)

    new.life = 0
    new.speed = 0
    new.radius = 0
    new.damage = 0
    new.vx = 0
    new.vy = 0
    new.team = nil

    if is_client then
        new.emitter = projectile.emitter_type:clone()
        new.emitter:reset()
        new.emitter:start()
    else
        new.ignore = {}
    end

    return new
end

function projectile:pack(initial)
    if initial then
        return {self.px, self.py, self.vx, self.vy, self.speed, self.target}
    else
        return {self.px, self.py}
    end
end

function projectile:unpack(t, initial)
    self.px = t[1]
    self.py = t[2]

    if initial then
        self.vx = t[3]
        self.vy = t[4]
        self.speed = t[5]
        self.target = t[6]
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

local function line_on_circle(a, b, c, r)
    local d = {
        b[1] - a[1],
        b[2] - a[2]
    }

    local f = {
        a[1] - c[1],
        a[2] - c[2]
    }

    local a = (d[1]^2 + d[2]^2)
    local b = 2 * (f[1] * d[1] + f[2] * d[2])
    local c = (f[1]^2 + f[2]^2) - r^2

    local discriminant = b * b - 4 * a * c

    if discriminant < 0 then
        return false
    end

    discriminant = math.sqrt(discriminant)

    local t1 = (-b - discriminant) / (2 * a)
    local t2 = (-b + discriminant) / (2 * a)

    return (t1 >= 0 and t1 <= 1) or (t2 >= 0 and t2 <= 1)
end

function projectile:update(dt)
    if not is_client and self.life >= 0 then
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
                not self.ignore[ent] and
                ent ~= self and
                ent.is_unit and
                line_on_circle(a, b, {ent.px, ent.py}, self.radius)
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
    love.graphics.setColor(255, 255, 255)
    -- love.graphics.draw(self.emitter, self.px, self.py)
    love.graphics.draw(self.emitter)

    love.graphics.setColor(255, 80, 80)
    love.graphics.circle("fill", self.px, self.py, 7, 14)
    love.graphics.setLineWidth(2)
    love.graphics.setColor(255, 160, 160)
    love.graphics.circle("line", self.px, self.py, 7, 14)
end

return projectile
