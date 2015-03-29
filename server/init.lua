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

function love.load()
    local address

    if args.listen.set then
        address = args.listen[1]
    else
        address = (config.public and "*:" or "localhost:") .. config.port
    end

    local map = args.map[1] or config.startup_map or "default"

    server = {
        clients = {},
        entities = {},
        schedules = {},
        time = 0,
        next_id = 0,
        host = enet.host_create(address, config.peer_count, CHANNEL_COUNT,
            config.bandwidth_in, config.bandwidth_out),
        world = world:new("maps/" .. map .. ".textmap")
    }

    function server:by_id(id)
        if id == nil then
            return nil
        end

        return self.entities[id]
    end

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
                elseif data.name == "" or #data.name > 60 then
                    event.peer:disconnect(DISCONNECT.NAME)
                else
                    server.clients[index] = client:new(event.peer, data.name)
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

    local i = 1

    while i <= #server.schedules do
        local sched = server.schedules[i]

        if server.time >= sched[1] then
            sched[2]()
            table.remove(server.schedules, i)
        else
            i = i + 1
        end
    end
end

function add_entity(ent)
    if ent.__id ~= nil then return ent end
    ent.__id = server.next_id

    server.entities[server.next_id] = ent
    server.next_id = server.next_id + 1

    for i, cl in pairs(server.clients) do
        cl:send({
            e = EVENT.ENTITY_ADD,
            [ent.__id] = {
                t = id_from_entity(getmetatable(ent)),
                d = ent:pack(true)
            }
        })
    end

    ent:added()
    return ent
end

function remove_entity(ent)
    if ent.__id == nil then return nil end
    ent:removed()

    for i, cl in pairs(server.clients) do
        cl:send({e = EVENT.ENTITY_REMOVE, ent.__id})
    end

    server.entities[ent.__id] = nil
    ent.__id = nil
    return nil
end

function update_entity(ent)
    if ent.__id == nil then return end

    for i, cl in pairs(server.clients) do
        cl:send({
            e = EVENT.ENTITY_UPDATE,
            [ent.__id] = ent:pack(false)
        })
    end
end

function schedule(when, f)
    local s = {when, f}
    table.insert(server.schedules, s)
    return s
end

function delay(duration, f)
    return schedule(server.time + duration, f)
end

function cancel(s)
    for i, sched in ipairs(server.schedules) do
        if sched == s then
            table.remove(server.schedules, i)
            break
        end
    end
end
