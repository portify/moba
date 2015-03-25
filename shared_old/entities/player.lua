local class = require "../lib/class"

local player = {}
player.__index = player
setmetatable(player, entity)

local player_image = nil
local player_quads = nil

function player:new()
    if is_client and player_image == nil then
        player_image = love.graphics.newImage("assets/MobSpritesFull.png")
        player_quads = {
            forward = love.graphics.newQuad(0, 0, 32, 32, player_image:getDimensions())
        }
    end

    new = setmetatable({}, self)
    new.x = 32.0
    new.y = 32.0
    return new
end

function player:pack()
    return {self.x, self.y}
end

function player:unpack(t)
    self.x = t[1]
    self.y = t[2]
end

function player:draw()
    love.graphics.setColor(255, 255, 255)
    love.graphics.draw(player_image, player_quads.forward, self.x, self.y,
        0, 1, 1, 16, 16)
end

return player
