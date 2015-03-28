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
    love.window.setMode(1280, 720)
    gamestate.registerEvents()

    local info = debug.getinfo(love.update)
    print("defined at " .. info.short_src .. ":" .. info.linedefined)

    if args.local_loop then
        gamestate.switch(states.connecting, "127.0.0.1:6788")
    else
        gamestate.switch(states.menu)
    end
end
