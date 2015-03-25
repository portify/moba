local client = {}
client.__index = client

function client:new(peer)
    return setmetatable({peer = peer}, self)
end

function client:reset()
    self.peer:reset()
end

function client:disconnect(data)
    self.peer:disconnect_later(data)
end

function client:send(data, channel, mode)
    print(self.peer:index() .. " <-- " .. tostring(EVENT(data.e)))
    self.peer:send(mp.pack(data), channel, mode)
end

function client:connected()
    print(self.peer:index() .. " connected")

    self:send({e = EVENT.HELLO})
    -- self:send({e = EVENT.WORLD_REPLACE, data = self.server.world:pack()})

    -- Utterly decimate them with entities
    -- for i, ent in pairs(self.server.entities) do
    --     self:send({
    --         e = EVENT.ENTITY_ADD,
    --         i = i,
    --         t = ent:get_type_id(),
    --         d = ent:pack()
    --     })
    -- end
end

function client:disconnected(data)
    print(self.peer:index() .. " disconnected")

    if QUIT_ON_DISCONNECT then
        love.event.quit()
    end
end

function client:received(data)
    print(self.peer:index() .. " --> " .. tostring(EVENT(data.e)))
end

return client
