local game = {}

function game:enter(previous, host, server)
    self.host = host
    self.server = server

    self.entities = {}
end

function game:leave()
    self.host = nil
    self.server = nil

    self.entities = nil
end

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

function game:update(dt)
    local event = self.host:service()

    while event do
        if event.type == "receive" then
            local data = mp.unpack(event.data)
            print("Got packet " .. tostring(EVENT(data.e)))

            if data.e == EVENT.WORLD_REPLACE then
                game_world:unpack(data.data)
            elseif data.e == EVENT.ENTITY_ADD then
                local type = entity_from_id(data.t)
                local ent = type:new()
                game_entities[data.i] = ent
                ent.__id = data.i
                ent:unpack(data.d)
            elseif data.e == EVENT.ENTITY_REMOVE then
                game_entities[data.i] = nil
            elseif data.e == EVENT.ENTITY_UPDATE then
                game_entities[data.i]:unpack(data.d)
            end
        elseif event.type == "disconnect" then
            local reason = DISCONNECT(event.data)
            reason = reason and " (" .. reason .. ")" or ""

            print("Disconnected from server" .. reason)

            if QUIT_ON_DISCONNECT then
                love.event.quit()
            end
        end

        event = self.host:service()
    end

    for id, ent in pairs(self.entities) do
        ent:update(dt)
    end
end

function game:draw()
    love.graphics.print(self.server:round_trip_time(), 8, 8)

    for id, ent in pairs(self.entities) do
        ent:draw()
    end
end

return game
