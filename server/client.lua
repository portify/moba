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

    self.player = add_entity(entities.player:new())
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
    print(self.peer:index() .. " --> " .. tostring(EVENT(data.e)))

    if data.e == EVENT.MOVE_TO then
        if self.player ~= nil then
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

            local b = server.world:get_plane(data.x, data.y)

            if b ~= nil then
                local a = self.player:get_world_plane()
                local path

                if a == nil then
                    path = {
                        {b:center()},
                        {self.player.px, self.player.py}
                    }
                elseif a == b then
                    path = {
                        {data.x, data.y},
                        {self.player.px, self.player.py}
                    }
                else
                    local planes = a:find_path(b)

                    if planes ~= nil then
                        path = {{data.x, data.y}}

                        for i, plane in ipairs(planes) do
                            table.insert(path, {plane:center()})
                        end

                        table.insert(path, {self.player.px, self.player.py})
                    end
                end

                self.player.path = path
                self.player.path_progress = 0

                update_entity(self.player)
            end
        end
    else
        -- self:disconnect(DISCONNECT.INVALID_PACKET)
    end
end

return client
