local world = require "shared/world"

local camera = require "lib/hump/camera"

local game = {}

function game:enter(previous, host, server)
    print("Connection ready")

    self.host = host
    self.server = server

    self.entities = {}
    self.world = world:new()

    self.control = setmetatable({}, {__mode = "kv"})
    self.camera = camera.new()

    love.mouse.setGrabbed(true)
end

function game:resume()
    love.mouse.setGrabbed(true)
end

function game:leave()
    self.host = nil
    self.server = nil

    self.entities = nil
    self.world = nil

    self.control = nil
    self.camera = nil

    love.mouse.setGrabbed(false)
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

function game:get_control()
    return self.control.value
end

function game:update(dt)
    local paused = gamestate.current() ~= self
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
            elseif data.e == EVENT.ENTITY_CONTROL then
                self.control.value = self.entities[data.i]
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

    if love.mouse.isDown("r") and not paused then
        local x, y = self.camera:mousepos()
        self.move_to_timer = self.move_to_timer - dt

        if self.move_to_timer <= 0 and x ~= self.move_to_x and y ~= self.move_to_y then
            self.server:send(mp.pack({
                e = EVENT.MOVE_TO,
                x = x,
                y = y
            }))

            self.move_to_timer = 0.05
            self.move_to_x = x
            self.move_to_y = y
        end
    else
        self.move_to_timer = 0
        self.move_to_x = nil
        self.move_to_y = nil
    end

    for id, ent in pairs(self.entities) do
        ent:update(dt)
    end

    local control = self:get_control()

    if control ~= nil then
        control:update_camera(self.camera, dt, paused)
    end
end

function game:draw()
    self.camera:attach()
    self.world:draw()

    for id, ent in pairs(self.entities) do
        ent:draw()
    end

    self.camera:detach()
end

function game:keypressed(key)
    if key == "escape" then
        gamestate.push(states.pause)
    elseif key == "y" then
        local control = self:get_control()

        if control ~= nil then
            control.camera_lock = not control.camera_lock
        end
    end
end

return game
