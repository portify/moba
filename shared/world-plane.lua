local plane = {}
plane.__index = plane

function plane:new(...)
    return setmetatable({
        points = {...},
        planes = {}
    }, self)
end

function plane:center()
    local x = 0
    local y = 0

    for i, point in ipairs(self.points) do
        x = x + point[1]
        y = y + point[2]
    end

    return x / #self.points, y / #self.points
end

function plane:contains(x, y)
    -- only works for tris atm
    local p0 = self.points[1]
    local p1 = self.points[2]
    local p2 = self.points[3]

    local A = 1/2 * (-p1[2] * p2[1] + p0[2] * (-p1[1] + p2[1]) + p0[1] * (p1[2] - p2[2]) + p1[1] * p2[2])
    local sign

    if A < 0 then
        sign = -1
    else
        sign = 1
    end

    local s = (p0[2] * p2[1] - p0[1] * p2[2] + (p2[2] - p0[2]) * x + (p0[1] - p2[1]) * y) * sign
    local t = (p0[1] * p1[2] - p0[2] * p1[1] + (p0[2] - p1[2]) * x + (p1[1] - p0[1]) * y) * sign

    return s > 0 and t > 0 and (s + t) < 2 * A * sign
end

function plane:distance(other)
    local x1, y1 = self:center()
    local x2, y2 = other:center()

    return (x2-x1)^2 + (y2-y1)^2
end

function plane:find_path(goal)
    local dist = {[self] = 0}
    local prev = {}

    local opened = {self}

    while #opened > 0 do
        -- now /this/ is slow
        local current, lowest, index

        for i, plane in ipairs(opened) do
            if current == nil or dist[plane] < lowest then
                current = plane
                lowest = dist[plane]
                index = i
            end
        end

        -- couldn't be more slow
        table.remove(opened, index)

        if current == goal then
            local path = {current}

            while prev[current] ~= nil do
                current = prev[current]
                table.insert(path, current)
            end

            return path
        end

        for i=1, #current.points do
            local other = current.planes[i]

            if other ~= nil then
                local alt = dist[current] + current:distance(other)

                if dist[other] == nil or alt < dist[other] then
                    dist[other] = alt
                    prev[other] = current
                    table.insert(opened, other)
                end
            end
        end
    end

    return nil
end

function plane:draw(mode)
    local points = {}

    for j, point in ipairs(self.points) do
        table.insert(points, point[1])
        table.insert(points, point[2])
    end

    love.graphics.polygon(mode, points)
end

return plane
