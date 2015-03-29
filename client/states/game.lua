local world = require "shared/world"

local camera = require "lib/hump/camera"

local game = {}

local small_font

function game:init()
    small_font = love.graphics.newFont(8)
end

function game:enter(previous, address, host, server)
    print("Connection ready")

    self.address = address
    self.host = host
    self.server = server

    self.entities = {}
    self.world = world:new()
    self.entity_init = {}

    self.control = setmetatable({}, {__mode = "kv"})
    self.camera = camera.new()
    self.camera_locked = false

    love.mouse.setGrabbed(true)
    love.graphics.setBackgroundColor(0, 0, 0)
end

function game:resume()
    love.mouse.setGrabbed(true)

    if love.mouse.getRelativeMode() and not love.mouse.isDown("m") then
        love.mouse.setRelativeMode(false)
    end
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

                    if not self.entity_init[type] then
                        if type.client_init then
                            type.client_init()
                        end

                        self.entity_init[type] = true
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
                self.control.value = self.entities[data.i]
                self.control.value:update_camera(self.camera)
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

    if control ~= nil and self.camera_locked then
        control:update_camera(self.camera, dt)
    elseif not paused and not love.mouse.getRelativeMode() and love.window.hasMouseFocus() then
        local mx, my = love.mouse.getPosition()
        local speed = 750

        if mx <= 0 then
            self.camera:move(-speed * dt, 0)
        elseif mx >= love.graphics.getWidth() - 1 then
            self.camera:move(speed * dt, 0)
        end

        if my <= 0 then
            self.camera:move(0, -speed * dt)
        elseif my >= love.graphics.getHeight() - 1 then
            self.camera:move(0, speed * dt)
        end
    end
end

function game:draw()
    self.camera:attach()
    self.world:draw()

    for id, ent in pairs(self.entities) do
        ent:draw()
    end

    self.camera:detach()

    if debug_ents then
        local count = 0
        local control = self:get_control()

        love.graphics.setFont(small_font)

        for id, ent in pairs(self.entities) do
            if ent == control then
                love.graphics.setColor(0, 255, 0)
            else
                love.graphics.setColor(255, 255, 255)
            end

            love.graphics.print(id .. " = " .. get_entity_type_name(ent), 8, 16 + count * 8)
            count = count + 1
        end

        love.graphics.setColor(0, 255, 255)
        love.graphics.print(count .. " " .. (count == 1 and "entity" or "entities"), 8, 8)
    end
end

function game:mousemoved(x, y, dx, dy)
    if love.mouse.getRelativeMode() then
        self.camera:move(-dx, -dy)
    end
end

function game:mousepressed(x, y, button)
    if not self.camera_locked and button == "m" then -- Camera drag mode
        if not love.mouse.getRelativeMode() then
            self.mouse_pre_relative = {love.mouse.getPosition()}
        end

        love.mouse.setRelativeMode(true)
    elseif button == "wd" then -- Zoom out
        self.camera.scale = math.max(0.4, self.camera.scale - 0.1)
    elseif button == "wu" then -- Zoom in
        self.camera.scale = math.min(  1, self.camera.scale + 0.1)
    end
end

function game:mousereleased(x, y, button)
    if button == "m" and love.mouse.getRelativeMode() then
        love.mouse.setRelativeMode(false)
        love.mouse.setPosition(unpack(self.mouse_pre_relative))
    end
end

function game:keypressed(key)
    local abilities = {q=1, w=2, e=3, r=4}

    if key == "y" then
        self.camera_locked = not self.camera_locked

        if self.camera_locked then
            love.mouse.setRelativeMode(false)
        end
    elseif abilities[key] ~= nil then
        local x, y = self.camera:mousepos()

        self.server:send(mp.pack{
            e = EVENT.USE_ABILITY,
            i = abilities[key],
            x = x, y = y
        })
    end
end

function game:keyreleased(key)
    if key == "escape" then
        gamestate.push(states.pause)
    end
end

return game
