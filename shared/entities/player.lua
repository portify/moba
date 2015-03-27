local player = {}
player.__index = player
setmetatable(player, entity)

function player:new()
    new = setmetatable({}, self)
    local sx, sy = self:get_world_instance().mesh[1]:center()

    new.px = sx
    new.py = sy
    new.vx = 1
    new.vy = 0
    new.speed = 170
    new.health = 100

    if is_client then
        new.camera_lock = false
        new._debug_font = get_resource(love.graphics.newFont, 8)
    end

    return new
end

function player:pack()
    return {
        self.px, self.py,
        self.vx, self.vy,
        self.path, self.path_progress,
        self.health
    }
end

function player:unpack(t)
    self.px = t[1]
    self.py = t[2]
    self.vx = t[3]
    self.vy = t[4]
    self.path = t[5]
    self.path_progress = t[6]
    self.health = t[7]
end

function player:damage(hp)
    self.health = self.health - hp

    if self.health <= 0 and not is_client then
        self.client.player = nil
        delay(1, function() self.client:spawn() end)
        remove_entity(self)
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
    -- love.graphics.line(self.px, self.py, self.px + self.vx * 40, self.py + self.vy * 40)

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
end

return player
