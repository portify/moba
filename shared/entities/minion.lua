local pathedentity = require "shared.entities.pathedentity"
local util = require "shared.util"

local minion = {
    is_unit = true,
    radius = 12,
    health_max = 150,
    use_funnel = true,
    use_outside_snap = true
}

minion.__index = minion
setmetatable(minion, pathedentity)

local MAX_CHASE_DISTANCE = 200 ^ 2
local MAX_ATTACK_DISTANCE = 50 ^ 2

function minion:new(px, py, type)
    local new = setmetatable({}, self)
    new.px = px
    new.py = py
    new.vx = 1
    new.vy = 0
    new.type = type
    new.speed = 100
    new.team = false
    new.health = self.health_max
    return new
end

function minion:is_alive()
    return self.health > 0
end

function minion:begin_a_quest(name)
    local path = server.world.paths[name]

    self.path = {}
    self.path_progress = 0
    self.destiny = self.path

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

function minion:play_move(duration, vertices, no_update)
    if duration == nil then
        self.move_duration = nil
        self.move_elapsed = nil
        self.move_curve = nil

        if not is_client then
            self.move_vertices = nil
        end
    else
        self.move_duration = duration
        self.move_elapsed = 0
        self.move_curve = love.math.newBezierCurve(vertices)

        if not is_client then
            self.move_vertices = vertices
        end
    end

    if not is_client and not no_update then
        update_entity(self, PACK_TYPE.MOVE_ANIM)
    end
end

function minion:pack(type)
    if type == PACK_TYPE.INITIAL then
        return {self.team, pathedentity.pack(self, type)}
    elseif type == PACK_TYPE.MOVE_ANIM then
        return {self.move_duration, self.move_vertices}
    else
        return {self.health, pathedentity.pack(self, type)}
    end
end

function minion:unpack(t, type)
    if type == PACK_TYPE.INITIAL then
        self.team = t[1]
        pathedentity.unpack(self, t[2], type)
    elseif type == PACK_TYPE.MOVE_ANIM then
        self:play_move(t[1], t[2])
    else
        self.health = t[1]
        pathedentity.unpack(self, t[2], type)
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

function minion:get_draw_pos()
    local x, y = 0, 0

    if self.move_curve ~= nil then
        local t = self.move_elapsed / self.move_duration
        x, y = self.move_curve:evaluate(t)
    end

    return self.px + x, self.py + y
end

function minion:update(dt)
    pathedentity.update(self, dt)

    if self.move_curve ~= nil then
        self.move_elapsed = self.move_elapsed + dt

        if self.move_elapsed > self.move_duration then
            self.move_curve = nil
            self.move_elapsed = nil
            self.move_duration = nil

            if not is_client then
                self.move_vertices = nil
            end
        end
    end

    if not is_client then
        local target = server:by_id(self.target)

        if target == nil or not target:is_alive() or util.dist2(self.px, self.py, target.px, target.py) > MAX_CHASE_DISTANCE then
            if self.target ~= nil then
                -- print("lost target")
                self.target = nil
                self.path = nil
                update_entity(self)
            end

            target = nil
        end

        -- Look for a new target
        if not target then
            local lowest

            for id, ent in pairs(server.entities) do
                if
                    ent ~= self and
                    ent.is_unit and
                    ent.team ~= self.team and
                    ent:is_alive()
                then
                    local distance = util.dist2(self.px, self.py, ent.px, ent.py)

                    if distance <= MAX_CHASE_DISTANCE and (target == nil or distance < lowest) then
                        target = ent
                        lowest = distance
                    end
                end
            end

            if target ~= nil then
                -- print("got target " .. target.__id)
                self.target = target.__id
            end
        end

        if target then
            local distance = util.dist2(self.px, self.py, target.px, target.py)

            if distance <= MAX_ATTACK_DISTANCE then
                if self.path ~= nil then
                    self.path = nil
                    update_entity(self)
                end

                if not self.move_curve then
                    self:play_move(1, {
                        0, 0,
                        self.vx * -12, self.vy * -12,
                        self.vx *  24, self.vy *  24,
                        self.vx *   4, self.vy *   4,
                        0, 0
                    })

                    delay(0.6, function() target:damage(10) end)
                end
            else
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
                        -- self.target = nil
                        -- target = nil
                    end
                end
            end
        elseif self.path == nil then
            self.path = self.destiny
            table.remove(self.path)

            if #self.path > 0 then
                self:move_to(self.path[#self.path][1], self.path[#self.path][2], true)
            else
                self.path = nil
                update_entity(self)
            end

            -- self.path = self.destiny
            -- self.path_progress = 0
            -- update_entity(self)
        end
    end
end

-- *CLIENT*
-- Test if the mouse position (x, y) would select this entity
-- Used for basic attacks and info UI
function minion:try_select(x, y)
    local px, py = self:get_draw_pos()
    local x1, y1 = px - self.radius, py - self.radius
    local x2, y2 = px + self.radius, py + self.radius
    return x >= x1 and y >= y1 and x < x2 and y < y2
end

-- *CLIENT*
-- Draw the selection UI for a selected instance of this entity
function minion:draw_select()
end

function minion:draw(mode)
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

    local x, y = self:get_draw_pos()

    if mode ~= nil then
        if mode == "select" then
            love.graphics.setColor(255, 0, 0)
        elseif mode == "hover" then
            love.graphics.setColor(255, 255, 255)
        end

        love.graphics.setLineWidth(8)
        love.graphics.rectangle("line", x - self.radius, y - self.radius, self.radius * 2, self.radius * 2)
    end

    love.graphics.setColor(r, g, b)
    -- love.graphics.circle("fill", x, y, self.radius, self.radius * 2)
    love.graphics.rectangle("fill", x - self.radius, y - self.radius, self.radius * 2, self.radius * 2)
    love.graphics.setLineWidth(2)
    love.graphics.setColor(r/2, g/2, b/2)
    -- love.graphics.circle("line", x, y, self.radius, self.radius * 2)
    love.graphics.rectangle("line", x - self.radius, y - self.radius, self.radius * 2, self.radius * 2)

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
        self.px - width / 2, self.py - self.radius / 2 - spacing - height,
        width, height)

    -- Current health
    -- love.graphics.setColor(50, 255, 50)
    love.graphics.setColor(r, g, b)
    love.graphics.rectangle("fill",
        self.px - width / 2, self.py - self.radius / 2 - spacing - height,
        width * hp, height)

    -- Outline
    love.graphics.setColor(255, 255, 255)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line",
        self.px - width / 2, self.py - self.radius / 2 - spacing - height,
        width, height)
end

function minion:draw_minimap()
    local r, g, b

    -- if self.team == 0 then
    --     -- r, g, b = 255, 127, 50
    --     r, g, b = 125, 25, 175
    -- elseif self.team == 1 then
    --     r, g, b = 50, 127, 255
    -- else
    --     r, g, b = 127, 127, 127
    -- end

    if self.team == 0 then
        -- r, g, b = 255, 200, 100
        r, g, b = 255, 0, 255
    elseif self.team == 1 then
        -- r, g, b = 100, 200, 255
        r, g, b = 0, 255, 255
    else
        r, g, b = 200, 200, 200
    end

    love.graphics.setColor(r, g, b)
    -- love.graphics.circle("fill", self.px, self.py, self.radius * 8)
    love.graphics.rectangle("fill", self.px - 20, self.py - 20, 40, 40)
end

return minion
