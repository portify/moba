local world = require "shared.world"
local camera = require "lib.hump.camera"

local game = {}
local small_font

require("client.states.game.net")(game)
require("client.states.game.input")(game)
require("client.states.game.ui")(game)

function game:init()
    small_font = love.graphics.newFont(8)
end

function game:enter(previous, address, host, server)
    print("Connection ready")

    self.address = address
    self.host = host
    self.server = server

    self.entities = {}
    self.world = world:new()
    self.entity_init = {}

    self.control = setmetatable({}, {__mode = "kv"})
    self.camera = camera.new()
    self.camera_locked = false

    love.mouse.setGrabbed(true)
    love.graphics.setBackgroundColor(0, 0, 0)
end

function game:resume()
    love.mouse.setGrabbed(true)

    if love.mouse.getRelativeMode() and not love.mouse.isDown("m") then
        love.mouse.setRelativeMode(false)
    end
end

function game:leave()
    self.host = nil
    self.server = nil

    self.entities = nil
    self.world = nil

    self.control = nil
    self.camera = nil

    love.mouse.setGrabbed(false)
end

function game:get_control()
    return self.control.value
end

function game:update(dt)
    self:update_net()

    for id, ent in pairs(self.entities) do
        ent:update(dt)
    end

    self:update_input(dt)
end

function game:draw()
    self.camera:attach()
    self.world:draw()

    for id, ent in pairs(self.entities) do
        ent:draw()
    end

    self.camera:detach()

    if debug_ents then
        local count = 0
        local control = self:get_control()

        love.graphics.setFont(small_font)

        for id, ent in pairs(self.entities) do
            if ent == control then
                love.graphics.setColor(0, 255, 0)
            else
                love.graphics.setColor(255, 255, 255)
            end

            love.graphics.print(id .. " = " .. get_entity_type_name(ent), 8, 16 + count * 8)
            count = count + 1
        end

        love.graphics.setColor(0, 255, 255)
        love.graphics.print(count .. " " .. (count == 1 and "entity" or "entities"), 8, 8)
    end

    self:draw_ui()
end

return game
