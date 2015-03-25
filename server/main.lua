local function error_printer(msg, layer)
    print((debug.traceback("Error: " .. tostring(msg), 1+(layer or 1)):gsub("\n[^\n]+$", "")))
end

function love.errhand(msg)
    error_printer(tostring(msg), 2)

    while enable_console do
        love.timer.sleep(0.1)
        love.event.pump()
        for e, a, b, c in love.event.poll() do
            if e == "quit" then return end
        end
    end
end

require "../shared/debug"

require "enet"
mp = require "../lib/msgpack"

require "../shared/entities"

local server = require "server"

function love.load(arg)
    debug_patch()

    QUIT_ON_DISCONNECT = arg[2] == "--quit-on-disconnect"
    main = server:new()
    print("Server now running")
end

function love.quit()
    main:close(true)
end

function love.update(dt)
    main:update(dt)
end
