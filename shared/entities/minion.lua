local util = require "shared/util"

local minion = {}
minion.__index = minion
setmetatable(minion, entity)

local MAX_CHASE_DISTANCE = 50 ^ 2

function minion:new(px, py)
    local new = setmetatable({}, self)
    new.px = px
    new.py = py
    new.speed = 160
    return new
end

function minion:pack(initial)
    return {self.px, self.py, self.path, self.path_progress}
end

function minion:unpack(t, initial)
    self.px = t[1]
    self.py = t[2]
    self.path = t[3]
    self.path_progress = t[4]
end

function minion:set_target(target, priority)
    if self.target == nil or priority > self.target_priority then
        self.target = target
        self.target_priority = priority
    end
end

function minion:update(dt)
    -- If we have a target, give up if they're too far or no longer exist
    if not is_client then
        local target = server:by_id(self.target)

        if target ~= nil and util.dist(self.px, self.py, target.px, target.py) > MAX_CHASE_DISTANCE then
            self.target = nil
            target = nil
        end

        -- Look for a new target
        if target == nil then
            local lowest

            for i, client in ipairs(server.clients) do
                if client.player ~= nil and client.player.__id ~= nil then
                    local distance = util.dist(self.px, self.py, client.player.px, client.player.py)

                    if target == nil or distance < lowest then
                        target = client.player
                        lowest = distance
                    end
                end
            end

            if target ~= nil then
                self.target = target.__id
            end
        end

        if self.path ~= nil then
            local dest = self.path[1]

            if dest[1] ~= target.px or dest[2] ~= target.py then
                self.path = nil
            end
        end

        -- This is ~very~ inefficient
        if self.path == nil then
            -- And spammy on the network
            self:move_to(target.px, target.py)
        end
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

function minion:draw()
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

    love.graphics.setColor(255, 0, 0)
    love.graphics.circle("fill", self.px, self.py, 8, 16)
end

local funnel = require "shared/funnel"
local USE_FUNNEL = false

function minion:get_world_plane()
    if self.px ~= self.plane_x or self.py ~= self.plane_y then
        self.plane = self:get_world_instance():get_plane(self.px, self.py)
        self.plane_x = self.px
        self.plane_y = self.py
    end

    return self.plane
end

function minion:move_to(x, y)
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

return minion
