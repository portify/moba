local pathedentity = require "shared.entities.pathedentity"
local util = require "shared.util"

local minion = {}
minion.__index = minion
setmetatable(minion, pathedentity)

local MAX_CHASE_DISTANCE = 50 ^ 2

function minion:new(px, py)
    local new = setmetatable({}, self)
    new.px = px
    new.py = py
    new.speed = 160
    return new
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
            if not self:move_to(target.px, target.py) then
                self.target = nil
                target = nil
            end
        end
    end

    pathedentity.update(self, dt)
end

function minion:draw()
    pathedentity.draw(self)

    love.graphics.setColor(255, 0, 0)
    love.graphics.circle("fill", self.px, self.py, 8, 16)
end

return minion
