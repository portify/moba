return function(game)
    game.minimap_scale = 0.065

    function game:get_minimap_bounds()
        local sw, sh = love.graphics.getDimensions()

        if self.world.image ~= nil then
            local w, h = self.world.image:getDimensions()
            w = w * self.minimap_scale
            h = h * self.minimap_scale
            local x = sw - w
            local y = sh - h
            return x, y, w, h
        end

        return sw + 1, sh + 1, -1, -1
    end

    function game:draw_ui()
        local sw, sh = love.graphics.getDimensions()

        if debug_ents then
            local count = 0
            local control = self:get_control()

            love.graphics.setFont(self.small_font)

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

        if debug_perf then
            love.graphics.setFont(self.small_font)
            love.graphics.setColor(0, 255, 255)
            love.graphics.printf(
                "Frame time: " .. math.ceil(love.timer.getAverageDelta() * 1000000) .. "us (" .. love.timer.getFPS() .."fps)\n" ..
                "Ping: " .. self.server:round_trip_time() .. "ms",
                8, 8, sw - 16, "right")
        end

        if self.world.image ~= nil then
            local w, h = self.world.image:getDimensions()
            w = w * self.minimap_scale
            h = h * self.minimap_scale
            local x = sw - w
            local y = sh - h

            love.graphics.setColor(255, 255, 255)
            love.graphics.setShader(self.world.fog_shader)
            love.graphics.draw(self.world.image, x, y, 0, self.minimap_scale, self.minimap_scale)
            love.graphics.setShader()

            -- Clamp game world to minimap
            love.graphics.setScissor(x, y, w, h)
            love.graphics.push()
            love.graphics.translate(x, y)
            love.graphics.scale(self.minimap_scale)

            -- Draw entities
            for id, ent in pairs(self.entities) do
                if ent.draw_minimap then
                    ent:draw_minimap()
                end
            end

            -- Draw the game view
            local cx = self.camera.x
            local cy = self.camera.y
            local cw = sw / self.camera.scale
            local ch = sh / self.camera.scale
            cx = cx - cw / 2
            cy = cy - ch / 2
            love.graphics.setColor(255, 255, 255, 50)
            love.graphics.rectangle("fill", cx, cy, cw, ch)
            love.graphics.setColor(255, 255, 255, 100)
            love.graphics.setLineWidth(4)
            love.graphics.rectangle("line", cx, cy, cw, ch)

            -- Unclamp
            love.graphics.pop()
            love.graphics.setScissor()

            -- Draw border
            love.graphics.setColor(50, 50, 50)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", x, y, w, h)
        end

        if self.selection ~= nil then
            local selection = self.entities[self.selection]
            
            if selection ~= nil then
                selection:draw_select()
            end
        end
    end
end
