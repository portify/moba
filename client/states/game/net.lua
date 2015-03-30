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

                    for id, params in pairs(data) do
                        local type = entity_from_id(params.t)

                        if not type.__ran_client_init then
                            if type.client_init then
                                type:client_init()
                            end

                            type.__ran_client_init = true
                        end

                        local ent = type:new()
                        self.entities[id] = ent
                        ent.__id = id
                        ent:added()
                        ent:unpack(params.d, true)
                    end
                elseif data.e == EVENT.ENTITY_REMOVE then
                    for i, id in ipairs(data) do
                        if self.entities[id] ~= nil then
                            self.entities[id]:removed()
                        end

                        self.entities[id] = nil
                    end
                elseif data.e == EVENT.ENTITY_UPDATE then
                    data.e = nil

                    for id, packed in pairs(data) do
                        self.entities[id]:unpack(packed, false)
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
