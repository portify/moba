local menu = {}
menu.__index = menu

function menu:new(x, y, font, entries, margin, spacing)
    return setmetatable({
        x = x,
        y = y,
        font = font,
        entries = entries,
        margin = margin or 4,
        spacing = spacing or 30,
        index = 1,
        mx = love.mouse.getX(),
        my = love.mouse.getY()
    }, self)
end

function menu:activate()
    return self.entries[self.index].func()
end

function menu:previous()
    for i=1, #self.entries-1 do
        local index = ((self.index - i - 1) % #self.entries) + 1
        if not self.entries[index].disabled then
            self.index = index
            break
        end
    end
end

function menu:next()
    for i=1, #self.entries-1 do
        local index = ((self.index + i - 1) % #self.entries) + 1
        if not self.entries[index].disabled then
            self.index = index
            break
        end
    end
end

function menu:mousepressed(x, y, button)
    if button ~= "l" then return end

    for i, entry in ipairs(self.entries) do
        if not entry.disabled then
            if
                x >= self.x - self.margin and
                y >= self.y - self.margin + (i-1) * self.spacing and
                x < self.x + self.margin + self.font:getWidth(entry.label) and
                y < self.y + self.margin + self.font:getHeight(entry.label) + (i-1) * self.spacing
            then
                entry.func()
                break
            end
        end
    end
end

function menu:update(dt)
    local mx, my = love.mouse.getPosition()

    if mx ~= self.mx or my ~= self.my then
        for i, entry in ipairs(self.entries) do
            if not entry.disabled then
                if
                    mx >= self.x - self.margin and
                    my >= self.y - self.margin + (i-1) * self.spacing and
                    mx < self.x + self.margin + self.font:getWidth(entry.label) and
                    my < self.y + self.margin + self.font:getHeight(entry.label) + (i-1) * self.spacing
                then
                    self.index = i
                    break
                end
            end
        end
    end

    self.mx = mx
    self.my = my
end

function menu:draw()
    love.graphics.setFont(self.font)

    for i, entry in ipairs(self.entries) do
        if i == self.index then
            love.graphics.setColor(0, 0, 0, 75)
            love.graphics.rectangle("fill", -- setLineWidth(2) + "line"
                self.x - self.margin,
                self.x - self.margin + (i-1) * self.spacing,
                self.font:getWidth(entry.label) + self.margin * 2,
                self.font:getHeight(entry.label) + self.margin * 2)

            love.graphics.setColor(255, 255, 255)
        elseif entry.disabled then
            love.graphics.setColor(255, 255, 255, 50)
        else
            love.graphics.setColor(255, 255, 255, 200)
        end

        love.graphics.print(entry.label, 64, 64 + (i-1) * self.spacing)
    end
end

return menu
