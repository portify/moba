return function(game)
    function game:update_input(dt)
        local paused = gamestate.current() ~= self
        local mpx, mpy, mpw, mph = self:get_minimap_bounds()

        if love.mouse.isDown("r") and not paused then
            local x, y = love.mouse.getPosition()

            if x >= mpx and y >= mpy then
                x = (x - mpx) / self.minimap_scale
                y = (y - mpy) / self.minimap_scale
            else
                x, y = self.camera:worldCoords(x, y)
            end

            -- local x, y = self.camera:mousepos()
            self.move_to_timer = self.move_to_timer - dt

            if self.move_to_timer <= 0 and (x ~= self.move_to_x or y ~= self.move_to_y) then
                self.server:send(mp.pack{
                    e = EVENT.MOVE_TO,
                    x = x,
                    y = y
                })

                self.move_to_timer = 0.1
                self.move_to_x = x
                self.move_to_y = y
            end
        else
            self.move_to_timer = 0
            self.move_to_x = nil
            self.move_to_y = nil
        end

        local control = self:get_control()

        if control ~= nil and self.camera_locked then
            control:update_camera(self.camera, dt)
        elseif not paused and not love.mouse.getRelativeMode() and love.window.hasMouseFocus() then
            local mx, my = love.mouse.getPosition()
            local mp_moved = false

            -- This is a really poor way of doing minimap movement...
            -- if love.mouse.isDown("l") and self.world.image ~= nil then
            if love.mouse.isDown("l") then
                local x = (mx - mpx) / self.minimap_scale
                local y = (my - mpy) / self.minimap_scale

                if x >= 0 and y >= 0 then
                    self.camera:lookAt(x, y)
                    mp_moved = true
                end
            end

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
end
