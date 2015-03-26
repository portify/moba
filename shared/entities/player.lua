local player = {}
player.__index = player
setmetatable(player, entity)

function player:new()
    new = setmetatable({}, self)
    new.px = 32
    new.py = 32
    new.vx = 1
    new.vy = 0
    new.speed = 130

    if is_client then
        new._debug_font = get_resource(love.graphics.newFont, 8)
    end

    return new
end

function player:pack()
    return {
        self.px, self.py,
        self.vx, self.vy,
        self.path, self.path_progress
    }
end

function player:unpack(t)
    self.px = t[1]
    self.py = t[2]
    self.vx = t[3]
    self.vy = t[4]
    self.path = t[5]
    self.path_progress = t[6]
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

    -- local plane = self:get_world_plane()
    --
    -- if plane ~= nil then
    --     love.graphics.setColor(100, 200, 100)
    --     plane:draw("fill")
    -- end

    love.graphics.setColor(255, 0, 255)
    love.graphics.setLineWidth(4)
    love.graphics.line(self.px, self.py, self.px + self.vx * 64, self.py + self.vy * 64)

    love.graphics.setColor(80, 80, 80)
    love.graphics.circle("fill", self.px, self.py, 8)
    love.graphics.setLineWidth(2)
    love.graphics.setColor(255, 255, 255)
    love.graphics.circle("line", self.px, self.py, 8)

    local width = 64
    local height = 12
    local spacing = 16

    local hp = 0.4

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
end

return player