print("client/init.lua")

gamestate = require "lib/hump/gamestate"

states = {
    -- menu = require "client/states/menu",
    connecting = require "client/states/connecting",
    game = require "client/states/game"
}

function love.load()
    love.window.setMode(1280, 720)

    gamestate.registerEvents()
    gamestate.switch(states.connecting, "127.0.0.1:6788")
end
