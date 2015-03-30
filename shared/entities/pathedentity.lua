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

function pathedentity:pack(type)
    local t = {self.px, self.py, self.vx, self.vy, self.path, self.path_progress}

    if type == PACK_TYPE.INITIAL then
        t[7] = self.speed
    end

    return t
end

function pathedentity:unpack(t, type)
    self.px = t[1]
    self.py = t[2]
    self.vx = t[3]
    self.vy = t[4]
    self.path = t[5]
    self.path_progress = t[6]

    if type == PACK_TYPE.INITIAL then
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
    if self.path ~= nil and #self.path == 1 then
        self.path = nil
    end
    
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

function pathedentity:move_to(x2, y2, append)
    local world = self:get_world_instance()
    local b = world:get_plane(x2, y2)

    if b == nil and self.use_outside_snap then
        local point
        b, point = world:project(x2, y2)

        if point ~= nil then
            x2, y2 = point[1], point[2]
        end
    end

    if b ~= nil then
        local x1, y1 = self.px, self.py
        local a = self:get_world_plane()

        local path

        if a == nil then
            local point
            a, point = world:project(x1, y1)

            if point ~= nil then
                x1, y1 = point[1], point[2]
            end
        end

        if a ~= nil then
            local planes = a:find_path(b)

            if planes ~= nil then
                if self.use_funnel then
                    path = {}
                    funnel({x1, y1}, {x2, y2}, planes, path)
                else
                    path = {{x2, y2}}

                    for i, plane in ipairs(planes) do
                        table.insert(path, {plane:center()})
                    end

                    table.insert(path, {x1, y1})
                end
            end
        end

        if append then
            if path ~= nil then
                for i=2, #path do
                    table.insert(self.path, path[i])
                end
            end
        else
            self.path = path
        end

        self.path_progress = 0
        update_entity(self)
        return path ~= nil
    end

    update_entity(self)
    return false
end

return pathedentity
