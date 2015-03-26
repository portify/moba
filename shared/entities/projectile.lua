local projectile = {}
projectile.__index = projectile
setmetatable(projectile, entity)

function projectile:new()
    new = setmetatable({}, self)
    new.time = 0
    new.damage = 8
    return new
end

function projectile:pack()
    return {self.px, self.py, self.vx, self.vy}
end

function projectile:unpack(t)
    self.px = t[1]
    self.py = t[2]
    self.vx = t[3]
    self.vy = t[4]
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
    if not is_client then
        self.time = self.time + dt

        if self.time >= 3 then
            remove_entity(self)
            return
        end
    end

    local a = {self.px, self.py}

    self.px = self.px + self.vx * dt
    self.py = self.py + self.vy * dt

    local b = {self.px, self.py}

    if not is_client then
        for id, ent in ipairs(server.entities) do
            if getmetatable(ent) == entities.player and line_on_circle(a, b, {ent.px, ent.py}, 8) then
                ent:damage(self.damage)
                remove_entity(self)
                return
            end
        end
    end
end

function projectile:draw()
    love.graphics.setColor(255, 80, 80)
    love.graphics.circle("fill", self.px, self.py, 3)
    love.graphics.setLineWidth(2)
    love.graphics.setColor(255, 160, 160)
    love.graphics.circle("line", self.px, self.py, 3)
end

return projectile
