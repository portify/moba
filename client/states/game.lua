local world = require "shared/world"

local game = {}
local stats_font

function game:enter(previous, host, server)
    print("Connection ready")

    self.host = host
    self.server = server

    self.entities = {}
    self.world = world:new()

    if stats_font == nil then
        stats_font = get_resource(love.graphics.newFont, 12)
    end
end

function game:leave()
    self.host = nil
    self.server = nil

    self.entities = nil
    self.world = nil
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
            -- print("Got packet " .. tostring(EVENT(data.e)))

            if data.e == EVENT.ENTITY_ADD then
                data.e = nil

                for id, params in pairs(data) do
                    local type = entity_from_id(params.t)
                    local ent = type:new()

                    self.entities[id] = ent
                    ent.__id = id
                    ent:added()
                    ent:unpack(params.d)
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
                    self.entities[id]:unpack(packed)
                end
            elseif data.e == EVENT.WORLD then
                self.world:unpack(data.d)
            end
        elseif event.type == "disconnect" then
            local reason = DISCONNECT(event.data)
            reason = reason and " (" .. reason .. ")" or ""

            print("Disconnected from server" .. reason)

            if args.local_loop then
                love.event.quit()
            else
                gamestate.switch(states.menu)
            end

            return
        end

        event = self.host:service()
    end

    for id, ent in pairs(self.entities) do
        ent:update(dt)
    end
end

function game:draw()
    self.world:draw()

    for id, ent in pairs(self.entities) do
        ent:draw()
    end

    love.graphics.setFont(stats_font)
    love.graphics.printf("latency: " .. self.server:round_trip_time() .. "ms\nfps: " .. love.timer.getFPS(),
        8, 8, love.graphics.getWidth() - 16)
end

function game:mousepressed(x, y, button)
    if button == "r" then
        self.server:send(mp.pack({
            e = EVENT.MOVE_TO,
            x = x,
            y = y
        }))
    end
end

return game
