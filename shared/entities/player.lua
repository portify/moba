local player = {}
player.__index = player
setmetatable(player, entity)

function player:new(name)
    new = setmetatable({}, self)
    local sx, sy = self:get_world_instance().mesh[1]:center()

    new.name = name
    new.px = sx
    new.py = sy
    new.vx = 1
    new.vy = 0
    new.speed = 170
    new.health = 100

    if is_client then
        new.camera_lock = false
        new._debug_font = get_resource(love.graphics.newFont, 8)
        new._name_font = get_resource(love.graphics.newFont, 14)
    end

    return new
end

function player:pack(initial)
    if initial then
        return {
            self.name,
            self.px, self.py,
            self.vx, self.vy,
            self.path, self.path_progress,
            self.health
        }
    else
        return {
            self.px, self.py,
            self.vx, self.vy,
            self.path, self.path_progress,
            self.health
        }
    end
end

function player:unpack(t, initial)
    if initial then
        self.name = t[1]
        self.px = t[2]
        self.py = t[3]
        self.vx = t[4]
        self.vy = t[5]
        self.path = t[6]
        self.path_progress = t[7]
        self.health = t[8]
    else
        self.px = t[1]
        self.py = t[2]
        self.vx = t[3]
        self.vy = t[4]
        self.path = t[5]
        self.path_progress = t[6]
        self.health = t[7]
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

function player:get_world_plane()
    if self.px ~= self.plane_x or self.py ~= self.plane_y then
        self.plane = self:get_world_instance():get_plane(self.px, self.py)
        self.plane_x = self.px
        self.plane_y = self.py
    end

    return self.plane
end

local function lerp(t, a, b) return a + (b - a) * t end

function player:update(dt)
    if self.path ~= nil then
        local a = self.path[#self.path]
        local b = self.path[#self.path - 1]

        local dx = b[1] - a[1]
        local dy = b[2] - a[2]

        local dist = math.sqrt(dx^2 + dy^2)

        self.vx = dx / dist
        self.vy = dy / dist

        self.path_progress = self.path_progress + dt * self.speed
        local t = math.min(1, self.path_progress / dist)

        self.px = lerp(t, a[1], b[1])
        self.py = lerp(t, a[2], b[2])

        if self.path_progress >= dist then
            self.path_progress = self.path_progress - dist
            table.remove(self.path, #self.path)

            if #self.path == 1 then
                self.path = nil
            end
        end
    end
end

function player:update_camera(camera, dt, paused)
    camera:lookAt(self.px, self.py)
    camera:rotateTo(0)
end

function player:draw()
    if self.path ~= nil then
        love.graphics.setColor(255, 255, 255)

        local i = #self.path

        while i > 1 do
            local a = self.path[i]
            local b = self.path[i - 1]

            love.graphics.line(a[1], a[2], b[1], b[2])

            i = i - 1
        end
    end

    local plane = self:get_world_plane()
    --
    -- if plane ~= nil then
    --     love.graphics.setColor(100, 200, 100, 50)
    --     plane:draw("fill")
    -- end
    --
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

local funnel = require "shared/funnel"
local USE_FUNNEL = true

function player:move_to(x, y)
    local world = self:get_world_instance()
    local b = world:get_plane(x, y)

    if b == nil then
        local point, distance
        b, point, distance = world:project(x, y)

        if point ~= nil then
            x, y = point[1], point[2]
        end
    end

    if b ~= nil then
        local a = self:get_world_plane()
        local path

        if a == nil then
            path = {
                {x, y},
                {self.px, self.py}
            }
        else
            local planes = a:find_path(b)

            if planes ~= nil then
                if USE_FUNNEL then
                    path = {}
                    funnel({self.px, self.py}, {x, y}, planes, path)
                else
                    path = {{x, y}}

                    for i, plane in ipairs(planes) do
                        table.insert(path, {plane:center()})
                    end

                    table.insert(path, {self.px, self.py})
                end
            end
        end

        self.path = path
        self.path_progress = 0

        update_entity(self)
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
        local speed = 500
        local p = entities.projectile:new()

        p.px = self.px + self.vx * 16
        p.py = self.py + self.vy * 16
        p.vx = self.vx * speed
        p.vy = self.vy * speed

        add_entity(p)
    end
end

return player
