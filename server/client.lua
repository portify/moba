local client = {}
client.__index = client

function client:new(peer)
    return setmetatable({
        peer = peer,
        control = setmetatable({}, {__mode = "kv"})
    }, self)
end

function client:reset()
    self.peer:reset()
end

function client:disconnect(data)
    self.peer:disconnect_later(data)
end

function client:send(data, channel, mode)
    -- print(self.peer:index() .. " <-- " .. tostring(EVENT(data.e)))
    self.peer:send(mp.pack(data), channel, mode)
end

function client:get_control()
    return self.control.value
end

function client:set_control(ent)
    assert(ent.__id ~= nil, "ent has no id")
    self.control.value = ent
    self:send{e=EVENT.ENTITY_CONTROL, i=ent.__id}
end

function client:connected()
    print(self.peer:index() .. " connected")

    self:send({e = EVENT.HELLO})
    self:send({e = EVENT.WORLD, d = server.world:pack()})

    -- Send down all current entities that exist
    -- Make this a bit more efficient now
    local data = {e = EVENT.ENTITY_ADD}
    local should_send = false

    for id, ent in pairs(server.entities) do
        -- data[id] = {t = ent:get_type_id(), d = ent:pack()}
        should_send = true

        data[id] = {
            t = id_from_entity(getmetatable(ent)),
            d = ent:pack()
        }
    end

    if should_send then
        self:send(data)
    end

    self:spawn()
end

function client:spawn()
    if self.player ~= nil then
        self.player = remove_entity(self.player)
    end

    self.player = entities.player:new()
    self.player.client = self

    add_entity(self.player)
    self:set_control(self.player)
end

function client:disconnected(data)
    if self.player ~= nil then
        self.player = remove_entity(self.player)
    end

    print(self.peer:index() .. " disconnected")

    if args.local_loop then
        love.event.quit()
    end
end

function client:received(data)
    -- print(self.peer:index() .. " --> " .. tostring(EVENT(data.e)))

    if data.e == EVENT.MOVE_TO then
        if self.player ~= nil then
            self.player:move_to(data.x, data.y)
            -- self.player.x = data.x
            -- self.player.y = data.y

            -- if self.player.path == nil then
            --     self.player.path = {
            --         {data.x, data.y},
            --         {self.player.px, self.player.py}
            --     }
            --
            --     self.player.path_progress = 0
            -- else
            --     table.insert(self.player.path, 1, {data.x, data.y})
            -- end


        end
    elseif data.e == EVENT.USE_ABILITY then
        if self.player ~= nil then
            self.player:use_ability(data.i)
        end
    else
        print("Got unknown packet from client " .. self.peer:index() .. ": " .. data.e)
        self:disconnect(DISCONNECT.INVALID_PACKET)
    end
end

return client
