is_client = true
gamestate = require "lib/hump/gamestate"

require "client/resource-manager"
require "shared/entities"

states = {
    menu = require "client/states/menu",
    connecting = require "client/states/connecting",
    game = require "client/states/game",
    pause = require "client/states/pause"
}

function love.load()
    gamestate.registerEvents()

    if args.connect.set then
        gamestate.switch(states.connecting, args.connect[1])
    else
        gamestate.switch(states.menu)
    end
end
