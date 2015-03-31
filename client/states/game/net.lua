return function(game)
    function game:quit()
        self:disconnect()

        local event = self.host:service()

        while event do
            event = self.host:service()
        end
    end

    function game:disconnect()
        self.server:disconnect_later(DISCONNECT.EXITING)
    end

    function game:update_net()
        local update_count = {}
        local update_key = {}

        update_count.bytes = 0

        for name, impl in pairs(entities) do
            local entry = {
                name = name,
                count = 0
            }

            table.insert(update_count, entry)
            update_key[impl] = entry
        end

        local event = self.host:service()

        while event do
            if event.type == "receive" then
                local data = mp.unpack(event.data)
                -- print("Got packet " .. tostring(EVENT(data.e)))

                if data.e == EVENT.ENTITY_ADD then
                    -- data.e = nil
                    update_count.bytes = update_count.bytes + #event.data

                    for i, entry in ipairs(data) do
                        local type = entity_from_id(entry.t)
                        update_key[type].count = update_key[type].count + 1

                        if not type.__ran_client_init then
                            if type.client_init then
                                type:client_init()
                            end

                            type.__ran_client_init = true
                        end

                        local ent = type:new()
                        self.entities[entry.i] = ent
                        ent.__id = entry.i
                        ent:added()
                        ent:unpack(entry.d, PACK_TYPE.INITIAL)
                    end
                elseif data.e == EVENT.ENTITY_REMOVE then
                    for i, id in ipairs(data) do
                        if self.entities[id] ~= nil then
                            if not self.entities[id]:removed() then
                                self.entities[id].__id = nil
                                self.entities[id] = nil
                            end
                        end
                    end
                elseif data.e == EVENT.ENTITY_UPDATE then
                    update_count.bytes = update_count.bytes + #event.data

                    for i, entry in ipairs(data) do
                        if self.entities[entry.i] ~= nil then
                            local t = getmetatable(self.entities[entry.i])
                            update_key[t].count = update_key[t].count + 1
                            self.entities[entry.i]:unpack(entry.d, entry.t)
                        end
                    end
                elseif data.e == EVENT.ENTITY_CONTROL then
                    if data.i == nil then
                        self.control.value = nil
                    else
                        self.control.value = self.entities[data.i]
                        self.control.value:update_camera(self.camera)
                    end
                elseif data.e == EVENT.WORLD then
                    self.world:unpack(data.d)
                    self.entities = {}
                end
            elseif event.type == "disconnect" then
                local reason = DISCONNECT(event.data)
                reason = reason and " (" .. reason .. ")" or ""

                print("Disconnected from server" .. reason)

                if args.connect.set then
                    love.event.quit()
                else
                    gamestate.switch(states.menu)
                end

                return
            end

            event = self.host:service()
        end

        if self.update_graph_index == self.update_graph_count then
            self.update_graph_index = 1
        else
            self.update_graph_index = self.update_graph_index + 1
        end

        self.update_graph_data[self.update_graph_index] = update_count
    end
end
