local client = {}
client.__index = client

function client:new(peer, name)
    return setmetatable({
        peer = peer,
        name = name,
        team = nil,
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
    assert(ent == nil or ent.__id ~= nil, "ent has no id")
    self.control.value = ent

    if ent == nil then
        self:send{e=EVENT.ENTITY_CONTROL, i=nil}
    else
        self:send{e=EVENT.ENTITY_CONTROL, i=ent.__id}
    end
end

function client:connected()
    print(self.name .. " connected")
    self.team = love.math.random(0, 1)

    self:send({e = EVENT.HELLO})
    self:send({e = EVENT.WORLD, d = server.world:pack()})

    -- Send down all current entities that exist
    local data = {e = EVENT.ENTITY_ADD}

    for id, ent in pairs(server.entities) do
        table.insert(data, {
            i = id,
            t = id_from_entity(getmetatable(ent)),
            d = ent:pack(PACK_TYPE.INITIAL)
        })
    end

    if #data > 0 then
        self:send(data)
    end

    self:spawn()
end

function client:spawn()
    if self.player ~= nil then
        self.player = remove_entity(self.player)
    end

    self.player = entities.player:new(self.name)
    self.player.client = self
    self.player.team = self.team

    if server.spawns[self.team] ~= nil then
        local spawn = server.spawns[self.team][love.math.random(#server.spawns[self.team])]
        self.player.px = spawn.x
        self.player.py = spawn.y
    end

    add_entity(self.player)
    self:set_control(self.player)
end

function client:disconnected(data)
    if self.player ~= nil then
        self.player = remove_entity(self.player)
    end

    print(self.name .. " disconnected")

    if args["quit-on-empty"].set then
        local others = false

        for i, cl in ipairs(server.clients) do
            if cl ~= self then
                others = true
                break
            end
        end

        if not others then
            love.event.quit()
        end
    end
end

function client:received(data)
    local control = self:get_control()

    if data.e == EVENT.MOVE_TO then
        if control ~= nil then
            control.basic_attack = nil
            control:move_to(data.x, data.y)
        end
    elseif data.e == EVENT.USE_ABILITY then
        if control ~= nil then
            control.basic_attack = nil
            control:use_ability(data.i, data.x, data.y)
        end
    elseif data.e == EVENT.BASIC_ATTACK then
        if data.i ~= nil then
            local ent = server.entities[data.i]
            
            if
                control ~= nil and ent ~= nil and
                data.i ~= control.__id and ent.team ~= self.team
            then
                control.basic_attack = data.i
            end
        end
    else
        print("Got unknown packet from client " .. name .. ": " .. data.e .. " (" .. tostring(EVENT(data.e)) .. ")")
        self:disconnect(DISCONNECT.INVALID_PACKET)
    end
end

return client
