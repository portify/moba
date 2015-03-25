local function error_printer(msg, layer)
    print((debug.traceback("Error: " .. tostring(msg), 1+(layer or 1)):gsub("\n[^\n]+$", "")))
end

function love.errhand(msg)
    error_printer(tostring(msg), 2)

    while true do
        love.timer.sleep(0.1)
        love.event.pump()
        for e, a, b, c in love.event.poll() do
            if e == "quit" then return end
        end
    end
end

local client = require("server/client")

function love.load()
    local bind_address = "0.0.0.0:6788"

    server = {
        clients = {},
        entities = {},
        time = 0,
        next_id = 0,
        host = enet.host_create(bind_address, 64, CHANNEL_COUNT, 0, 0)
    }

    if server.host ~= nil then
        print("Listening on " .. bind_address)
    else
        error("Cannot listen on " .. bind_address)
    end
end

function love.quit()
    for i=1, server.host:peer_count() do
        server.host:get_peer(i):disconnect(DISCONNECT.EXITING)
    end

    server.host:service(0)
    server.host = nil

    collectgarbage()
end

function love.update(dt)
    local event = server.host:service(0)

    while event do
        if event.type == "connect" then
            -- Ignore for now, consider timing out connections that fail to
            -- handshake for a duration automatically
        elseif event.type == "disconnect" then
            local index = event.peer:index()

            if server.clients[index] ~= nil then
                server.clients[index]:disconnected(event.data)
                server.clients[index] = nil
            end
        elseif event.type == "receive" then
            local index = event.peer:index()
            local data = mp.unpack(event.data)

            if server.clients[index] == nil then
                if data.version ~= PROTOCOL_VERSION then
                    event.peer:disconnect(DISCONNECT.INCOMPATIBLE)
                else
                    server.clients[index] = client:new(event.peer)
                    server.clients[index]:connected()
                end
            else
                server.clients[index]:received(data)
            end
        end

        event = server.host:service(0)
    end
end
