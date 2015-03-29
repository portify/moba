local pathedentity = require "shared.entities.pathedentity"
local util = require "shared.util"

local minion = {
    is_unit = true,
    health_max = 40
}

minion.__index = minion
setmetatable(minion, pathedentity)

local MAX_CHASE_DISTANCE = 50 ^ 2

function minion:new(px, py)
    local new = setmetatable({}, self)
    new.px = px
    new.py = py
    new.speed = 160
    new.team = false
    new.health = self.health_max
    return new
end

function minion:begin_a_quest(name)
    local path = server.world.paths[name]

    self.path = {}
    self.path_progress = 0

    if self.team == 1 then
        for i=#path, 1, -1 do
            table.insert(self.path, path[i])
        end
    else
        for i, node in ipairs(path) do
            table.insert(self.path, node)
        end
    end

    update_entity(self)
end

function minion:pack(initial)
    if initial then
        return {self.team, pathedentity.pack(self, true)}
    else
        return {self.health, pathedentity.pack(self, false)}
    end
end

function minion:unpack(t, initial)
    if initial then
        self.team = t[1]
        pathedentity.unpack(self, t[2], true)
    else
        self.health = t[1]
        pathedentity.unpack(self, t[2], false)
    end
end

function minion:set_target(target, priority)
    if self.target == nil or priority > self.target_priority then
        self.target = target
        self.target_priority = priority
    end
end

function minion:damage(hp)
    self.health = self.health - hp

    if self.health <= 0 then
        remove_entity(self)
    else
        update_entity(self)
    end
end

function minion:update(dt)
    -- -- If we have a target, give up if they're too far or no longer exist
    -- if not is_client then
    --     local target = server:by_id(self.target)
    --
    --     if target ~= nil and util.dist(self.px, self.py, target.px, target.py) > MAX_CHASE_DISTANCE then
    --         self.target = nil
    --         target = nil
    --     end
    --
    --     -- Look for a new target
    --     if target == nil then
    --         local lowest
    --
    --         for i, client in ipairs(server.clients) do
    --             if client.player ~= nil and client.player.__id ~= nil then
    --                 local distance = util.dist(self.px, self.py, client.player.px, client.player.py)
    --
    --                 if target == nil or distance < lowest then
    --                     target = client.player
    --                     lowest = distance
    --                 end
    --             end
    --         end
    --
    --         if target ~= nil then
    --             self.target = target.__id
    --         end
    --     end
    --
    --     if self.path ~= nil then
    --         local dest = self.path[1]
    --
    --         if dest[1] ~= target.px or dest[2] ~= target.py then
    --             self.path = nil
    --         end
    --     end
    --
    --     -- This is ~very~ inefficient
    --     if self.path == nil then
    --         -- And spammy on the network
    --         if not self:move_to(target.px, target.py) then
    --             self.target = nil
    --             target = nil
    --         end
    --     end
    -- end

    pathedentity.update(self, dt)
end

function minion:draw()
    pathedentity.draw(self)

    -- love.graphics.setColor(255, 0, 0)
    -- love.graphics.circle("fill", self.px, self.py, 8, 16)

    local r, g, b

    if self.team == 0 then
        r, g, b = 255, 200, 100
    elseif self.team == 1 then
        r, g, b = 100, 200, 255
    else
        r, g, b = 200, 200, 200
    end

    love.graphics.setColor(r, g, b)
    love.graphics.circle("fill", self.px, self.py, 8)
    love.graphics.setLineWidth(2)
    love.graphics.setColor(r/2, g/2, b/2)
    love.graphics.circle("line", self.px, self.py, 8)

    -- love.graphics.setColor(80, 80, 80)
    -- love.graphics.circle("fill", self.px, self.py, 8)
    -- love.graphics.setLineWidth(2)
    -- love.graphics.setColor(255, 255, 255)
    -- love.graphics.circle("line", self.px, self.py, 8)

    -- Draw health bar
    local width = 32
    local height = 6
    local spacing = 16

    local hp = self.health / self.health_max

    -- Background
    love.graphics.setColor(127, 127, 127)
    love.graphics.rectangle("fill",
        self.px - width / 2, self.py - 4 - spacing - height,
        width, height)

    -- Current health
    -- love.graphics.setColor(50, 255, 50)
    love.graphics.setColor(r, g, b)
    love.graphics.rectangle("fill",
        self.px - width / 2, self.py - 4 - spacing - height,
        width * hp, height)

    -- Outline
    love.graphics.setColor(255, 255, 255)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line",
        self.px - width / 2, self.py - 4 - spacing - height,
        width, height)
end

return minion
