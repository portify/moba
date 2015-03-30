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
        local event = self.host:service()

        while event do
            if event.type == "receive" then
                local data = mp.unpack(event.data)
                -- print("Got packet " .. tostring(EVENT(data.e)))

                if data.e == EVENT.ENTITY_ADD then
                    data.e = nil

                    for i, entry in pairs(data) do
                        local type = entity_from_id(entry.t)

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
                    data.e = nil

                    for i, entry in ipairs(data) do
                        if self.entities[entry.i] ~= nil then
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
    end
end
