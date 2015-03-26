local vertices, polygons
local mode, target

local function line_on_circle(a, b, c, r)
    local d = {
        b[1] - a[1],
        b[2] - a[2]
    }

    local f = {
        a[1] - c[1],
        a[2] - c[2]
    }

    local a = (d[1]^2 + d[2]^2)
    local b = 2 * (f[1] * d[1] + f[2] * d[2])
    local c = (f[1]^2 + f[2]^2) - r^2

    local discriminant = b * b - 4 * a * c

    if discriminant < 0 then
        return false
    end

    discriminant = math.sqrt(discriminant)

    local t1 = (-b - discriminant) / (2 * a)
    local t2 = (-b + discriminant) / (2 * a)

    return (t1 >= 0 and t1 <= 1) or (t2 >= 0 and t2 <= 1)
end

local function point_in_triangle(x, y, p0, p1, p2)
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

function love.load()
    vertices = setmetatable({}, {__mode = "v"})
    polygons = {}

    local a = {64, 64}
    local b = {128, 64}
    local c = {64, 128}

    table.insert(vertices, a)
    table.insert(vertices, b)
    table.insert(vertices, c)

    table.insert(polygons, {a, b, c})
end

local function update_target()
    local pos = {love.mouse.getPosition()}

    for i, vert in ipairs(vertices) do
        if math.sqrt((vert[1]-pos[1])^2 + (vert[2]-pos[2])^2) <= 4 then
            target = {type = "vert", vert = vert}
            return
        end
    end

    for i, poly in ipairs(polygons) do
        for i=1, #poly do
            local a = poly[i]
            local b = poly[(i % #poly) + 1]

            if line_on_circle(a, b, pos, 2) then
                target = {type = "edge", poly = poly, edge = i}
                return
            end
        end

        if point_in_triangle(pos[1], pos[2], poly[1], poly[2], poly[3]) then
            target = {type = "poly", poly = poly}
            return
        end
    end

    target = {}
end

function love.update(dt)
    local x = love.mouse.getX()
    local y = love.mouse.getY()

    if mode == "move-vertex" then
        target.vert[1] = x
        target.vert[2] = y
    elseif mode == "move-edge" then
        local a = target.poly[target.edge]
        local b = target.poly[(target.edge % #target.poly) + 1]

        local i = a[1]
        local j = a[2]

        a[1] = x - target.move_x
        a[2] = y - target.move_y
        b[1] = (x + (b[1] - i)) - target.move_x
        b[2] = (y + (b[2] - j)) - target.move_y
    else
        update_target()
    end
end

function love.keypressed(key)
    if key == "s" then
        data = ""

        local vert_id = {}

        for i, vert in ipairs(vertices) do
            vert_id[vert] = i
            data = data .. "v " .. vert[1] .. " " .. vert[2] .. "\n"
        end

        for i, poly in ipairs(polygons) do
            local a = vert_id[poly[1]]
            local b = vert_id[poly[2]]
            local c = vert_id[poly[3]]
            data = data .. "p " .. a .. " " .. b .. " " .. c .. "\n"
        end

        love.filesystem.write("map.txt", data)
    end
end

function love.mousepressed(x, y, button)
    if button == "l" and mode == nil then
        if target.type == "vert" then
            mode = "move-vertex"
        elseif target.type == "edge" then
            local a = target.poly[target.edge]
            local b = target.poly[(target.edge % #target.poly) + 1]

            -- See if another polygon uses this edge
            local in_use = false

            for i, poly in ipairs(polygons) do
                if poly ~= target.poly then
                    for i=1, #poly do
                        local t = poly[i]
                        local u = poly[(i % #poly) + 1]

                        if (a == t and b == u) or (a == u and b == t) then
                            in_use = true
                            break
                        end
                    end
                end

                if in_use then
                    break
                end
            end

            if in_use then
                -- If it's in use, just start sort of awkwardly moving the edge
                target.move_x = x - a[1]
                target.move_y = y - a[2]

                mode = "move-edge"
            else
                -- Otherwise, extrapolate a new polygon from the edge
                local c = {love.mouse.getPosition()}
                table.insert(vertices, c)

                local poly = {a, b, c}
                table.insert(polygons, poly)

                target = {
                    type = "vertex",
                    vert = c
                }

                mode = "move-vertex"
            end
        end
    end
end

function love.mousereleased(x, y, button)
    if button == "l" then
        if mode == "move-vertex" then
            target.vert[1] = x
            target.vert[2] = y

            -- Try to snap the vertex
            for i, vert in ipairs(vertices) do
                -- Serious bug: Will snap if own polygon is connected to receptor
                if vert ~= target.vert and math.sqrt((vert[1]-target.vert[1])^2 + (vert[2]-target.vert[2])^2) <= 4 then
                    -- O snap.
                    -- This means we should replace target.vert with vert in all polygons

                    for i, poly in ipairs(polygons) do
                        if poly[1] == target.vert then poly[1] = vert end
                        if poly[2] == target.vert then poly[2] = vert end
                        if poly[3] == target.vert then poly[3] = vert end
                    end

                    target.vert = vert
                    collectgarbage()

                    break
                end
            end
        elseif mode == "move-edge" then
            local a = target.poly[target.edge]
            local b = target.poly[(target.edge % #target.poly) + 1]

            local i = a[1]
            local j = a[2]

            a[1] = x - target.move_x
            a[2] = y - target.move_y
            b[1] = (x + (b[1] - i)) - target.move_x
            b[2] = (y + (b[2] - j)) - target.move_y
        end

        mode = nil
    end
end

function love.draw()
    love.graphics.setLineWidth(2)

    for i, poly in ipairs(polygons) do
        if target.type == "poly" and target.poly == poly then
            love.graphics.setColor(50, 255, 50, 150)
        else
            love.graphics.setColor(255, 255, 255, 50)
        end

        love.graphics.polygon("fill",
            poly[1][1], poly[1][2],
            poly[2][1], poly[2][2],
            poly[3][1], poly[3][2])

        for i=1, #poly do
            local a = poly[i]
            local b = poly[(i % #poly) + 1]

            if target.type == "edge" and target.poly == poly and target.edge == i then
                love.graphics.setColor(50, 255, 50, 150)
            else
                love.graphics.setColor(255, 255, 255)
            end

            love.graphics.line(a[1], a[2], b[1], b[2])
        end
    end

    for i, vert in ipairs(vertices) do
        if target.type == "vert" and target.vert == vert then
            love.graphics.setColor(50, 255, 50, 150)
        else
            love.graphics.setColor(255, 255, 255)
        end

        love.graphics.circle("fill", vert[1], vert[2], 4, 8)
    end
end
