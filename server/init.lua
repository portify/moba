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
local world = require("shared/world")

require "shared/entities"

config = {
    public = true,
    port = 6788,
    peer_count = 64,
    bandwidth_in = 0,
    bandwidth_out = 0
}

function love.load()
    local address = (config.public and "*:" or "localhost:") .. config.port

    server = {
        clients = {},
        entities = {},
        time = 0,
        next_id = 0,
        host = enet.host_create(address, config.peer_count, CHANNEL_COUNT,
            config.bandwidth_in, config.bandwidth_out),
        world = world:new()
    }

    if server.host ~= nil then
        print("Listening on " .. address)
    else
        error("Cannot listen on " .. address)
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
    server.time = server.time + dt
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

    for id, ent in pairs(server.entities) do
        ent:update(dt)
    end
end

function add_entity(ent)
    ent.__id = server.next_id

    server.entities[server.next_id] = ent
    server.next_id = server.next_id + 1

    for i, cl in ipairs(server.clients) do
        cl:send({
            e = EVENT.ENTITY_ADD,
            [ent.__id] = {
                t = id_from_entity(getmetatable(ent)),
                d = ent:pack()
            }
        })
    end

    ent:added()
    return ent
end

function remove_entity(ent)
    assert(ent.__id ~= nil, "entity has no id")
    ent:removed()

    for i, cl in ipairs(server.clients) do
        cl:send({e = EVENT.ENTITY_REMOVE, i = ent.__id})
    end

    server.entities[ent.__id] = nil
    ent.__id = nil
    return nil
end

function update_entity(ent)
    for i, cl in ipairs(server.clients) do
        cl:send({
            e = EVENT.ENTITY_UPDATE,
            [ent.__id] = ent:pack()
        })
    end
end
