local funnel = require "shared.funnel"
local util = require "shared.util"

local pathedentity = {
    use_funnel = false,
    use_outside_snap = false,
    allow_direct_move = true
}

pathedentity.__index = pathedentity
setmetatable(pathedentity, entity)

function pathedentity:new()
    return setmetatable({
        px = 0,
        py = 0,
        vx = 1,
        vy = 0,
        speed = 0
    }, self)
end

function pathedentity:pack(initial)
    local t = {self.px, self.py, self.vx, self.vy, self.path, self.path_progress}

    if initial then
        t[7] = self.speed
    end

    return t
end

function pathedentity:unpack(t, initial)
    self.px = t[1]
    self.py = t[2]
    self.vx = t[3]
    self.vy = t[4]
    self.path = t[5]
    self.path_progress = t[6]

    if initial then
        self.speed = t[7]
    end
end

function pathedentity:get_world_plane()
    if self.px ~= self.plane_x or self.py ~= self.plane_y then
        self.plane = self:get_world_instance():get_plane(self.px, self.py)
        self.plane_x = self.px
        self.plane_y = self.py
    end

    return self.plane
end

function pathedentity:update(dt)
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

        self.px = util.lerp(t, a[1], b[1])
        self.py = util.lerp(t, a[2], b[2])

        if self.path_progress >= dist then
            self.path_progress = self.path_progress - dist
            table.remove(self.path, #self.path)

            if #self.path == 1 then
                self.path = nil
            end
        end
    end
end

function pathedentity:draw()
    if debug_path and self.path ~= nil then
        love.graphics.setLineWidth(2)
        love.graphics.setColor(0, 255, 255)

        local i = #self.path

        while i > 1 do
            local a = self.path[i]
            local b = self.path[i - 1]

            love.graphics.line(a[1], a[2], b[1], b[2])

            i = i - 1
        end
    end
end

function pathedentity:update_camera(camera, dt)
    camera:lookAt(self.px, self.py)
    camera:rotateTo(0)
end

function pathedentity:move_to(x, y)
    local world = self:get_world_instance()
    local b = world:get_plane(x, y)

    if b == nil and self.use_outside_snap then
        local point, distance
        b, point, distance = world:project(x, y)

        if point ~= nil then
            x, y = point[1], point[2]
        end
    end

    if b ~= nil then
        local a = self:get_world_plane()
        local path

        if a == nil and self.allow_direct_move then
            path = {
                {x, y},
                {self.px, self.py}
            }
        else
            local planes = a:find_path(b)

            if planes ~= nil then
                if self.use_funnel then
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
        return self.path ~= nil
    end

    return false
end

return pathedentity
