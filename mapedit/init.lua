print("mapedit")

local vertices, polygons, image
local mode, target
local selection

local dragging, drag_start_view, drag_start_user
local has_moved_mouse
local view, zoom

local box_select

local function translate_mouse(x, y)
    return x / zoom - view[1], y / zoom - view[2]
end

local function is_selected(vert, no_boxes_allowed)
    if not no_boxes_allowed and box_select then
        local x1, y1 = box_select[1], box_select[2]
        local x2, y2 = translate_mouse(love.mouse.getPosition())

        if x2 < x1 then
            x1, x2 = x2, x1
        end

        if y2 < y1 then
            y1, y2 = y2, y1
        end

        if vert[1] >= x1 and vert[2] >= y1 and vert[1] <= x2 and vert[2] <= y2 then
            return true
        end
    end

    for i, each in ipairs(selection) do
        if each == vert then
            return true
        end
    end

    return false
end

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

local function set_image(filename)
    image = {
        filename = filename,
        instance = love.graphics.newImage(filename)
    }
end

local function clear_map()
    view = {0, 0}
    zoom = 1

    vertices = setmetatable({}, {__mode = "v"})
    polygons = {}

    target = {}
    selection = {}
    box_select = nil

    image = nil
end

local function reset_map()
    clear_map()
    set_image("maps/map.jpg")

    local a = {64, 64}
    local b = {128, 64}
    local c = {64, 128}

    table.insert(vertices, a)
    table.insert(vertices, b)
    table.insert(vertices, c)

    table.insert(polygons, {a, b, c})
end

local function save_map(filename)
    data = ""

    if image ~= nil then
        data = data .. "i " .. image.filename .. "\n"
    end

    local vert_id = {}

    for i, vert in pairs(vertices) do
        vert_id[vert] = #vert_id
        data = data .. "v " .. vert[1] .. " " .. vert[2] .. "\n"
    end

    for i, poly in ipairs(polygons) do
        local a = vert_id[poly[1]]
        local b = vert_id[poly[2]]
        local c = vert_id[poly[3]]
        data = data .. "p " .. a .. " " .. b .. " " .. c .. "\n"
    end

    love.filesystem.write(filename, data)
end

local function load_map(filename)
    clear_map()
    local verts = {}

    for line in love.filesystem.lines(filename) do
        if line:sub(1, 2) == "v " then
            x, y = line:match("(.*) (.*)", 3)
            local vert = {tonumber(x), tonumber(y)}
            table.insert(vertices, vert)
            table.insert(verts, vert)
        elseif line:sub(1, 2) == "p " then
            a, b, c = line:match("(.*) (.*) (.*)", 3)
            table.insert(polygons, {
                verts[tonumber(a)],
                verts[tonumber(b)],
                verts[tonumber(c)]
            })
        elseif line:sub(1, 2) == "i " then
            set_image(line:sub(3))
        end
    end

    collectgarbage()
end

function love.load()
    reset_map()
end

local function update_target()
    local pos = {translate_mouse(love.mouse.getPosition())}

    for i, vert in pairs(vertices) do
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
                target = {type = "edge", poly = poly, edge = i, a = a, b = b}
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
    local x, y = translate_mouse(love.mouse.getPosition())

    if not love.mouse.isDown("l") then
        update_target()
    end

    -- if mode == "move-vertex" then
    --     target.vert[1] = x
    --     target.vert[2] = y
    -- elseif mode == "move-edge" then
    --     local a = target.poly[target.edge]
    --     local b = target.poly[(target.edge % #target.poly) + 1]
    --
    --     local i = a[1]
    --     local j = a[2]
    --
    --     a[1] = x - target.move_x
    --     a[2] = y - target.move_y
    --     b[1] = (x + (b[1] - i)) - target.move_x
    --     b[2] = (y + (b[2] - j)) - target.move_y
    -- end

    -- if dragging then
    --     view[1] = drag_start_view[1] + (x - drag_start_user[1])
    --     view[2] = drag_start_view[2] + (y - drag_start_user[2])
    -- end
end

function love.keypressed(key)
    if key == "s" then
        save_map("maps/map.txt")
    elseif key == "l" then
        load_map("maps/map.txt")
    elseif key == "delete" and mode == nil then
        for i=#polygons, 1, -1 do
            local p = polygons[i]

            -- This is pretty bad
            if is_selected(p[1]) or is_selected(p[2]) or is_selected(p[3]) then
                table.remove(polygons, i)
            end
            -- if is_selected(p[1]) then
            --     if is_selected(p[2]) or is_selected(p[3]) then
            --         table.remove(polygons, i)
            --     end
            -- elseif is_selected(p[2]) and is_selected(p[3]) then
            --     table.remove(polygons, i)
            -- end
        end

        selection = {}
        target = {}

        collectgarbage()
    elseif key == "a" and (love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")) then
        selection = {}

        for i, vert in pairs(vertices) do
            table.insert(selection, vert)
        end
    end
end

function love.mousepressed(x, y, button)
    local ox, oy = x, y
    x, y = translate_mouse(x, y)

    if button == "l" then
        if not love.keyboard.isDown("lctrl") and not love.keyboard.isDown("rctrl") then
            selection = {}
        end

        if love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift") then
            box_select = {x, y}
        end
    elseif button == "m" then
        dragging = true
        drag_start_view = view
        drag_start_user = {x, y}
    elseif button == "wu" then
        zoom = math.min(4, zoom + 0.25)
    elseif button == "wd" then
        zoom = math.max(0.25, zoom - 0.25)
    end
end

function love.mousereleased(x, y, button)
    local ox, oy = x, y
    x, y = translate_mouse(x, y)

    if button == "m" then
        dragging = false
    elseif button == "l" then
        if box_select then
            local x1, y1 = box_select[1], box_select[2]
            local x2, y2 = x, y

            if x2 < x1 then
                x1, x2 = x2, x1
            end

            if y2 < y1 then
                y1, y2 = y2, y1
            end

            for i, vert in pairs(vertices) do
                if vert[1] >= x1 and vert[2] >= y1 and vert[1] <= x2 and vert[2] <= y2 then
                    table.insert(selection, vert)
                end
            end

            box_select = nil
            return
        end

        if mode == nil then
            if target.type == "vert" then
                table.insert(selection, target.vert)
            elseif target.type == "edge" then
                table.insert(selection, target.a)
                table.insert(selection, target.b)
            elseif target.type == "poly" then
                table.insert(selection, target.poly[1])
                table.insert(selection, target.poly[2])
                table.insert(selection, target.poly[3])
            end
        elseif mode == "move-vertex" then
            target.vert[1] = x
            target.vert[2] = y

            -- Try to snap the vertex
            for i, vert in pairs(vertices) do
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
        -- elseif mode == "move-edge" then
        --     local a = target.a
        --     local b = target.b
        --
        --     local i = a[1]
        --     local j = a[2]
        --
        --     a[1] = x - target.move_x
        --     a[2] = y - target.move_y
        --     b[1] = (x + (b[1] - i)) - target.move_x
        --     b[2] = (y + (b[2] - j)) - target.move_y
        end

        mode = nil
    end
end

function love.mousemoved(x, y, dx, dy)
    local ox, oy = x, y
    x, y = translate_mouse(x, y)

    if dragging then
        view[1] = drag_start_view[1] + (x - drag_start_user[1])
        view[2] = drag_start_view[2] + (y - drag_start_user[2])
    end

    if not love.mouse.isDown("l") or box_select then
        return
    end

    if mode == nil then
        if target.type == "vert" then
            mode = "move-vertex"
        elseif target.type == "edge" then
            local a = target.a
            local b = target.b

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
                local c = {x, y}
                table.insert(vertices, c)

                local poly = {a, b, c}
                table.insert(polygons, poly)

                target = {
                    type = "vertex",
                    vert = c
                }

                mode = "move-vertex"
            end
        elseif target.type == "poly" then
            target.move_x = x - target.poly[1][1]
            target.move_y = y - target.poly[1][2]

            mode = "move-poly"
        end
    end

    if mode == "move-vertex" then
        target.vert[1] = x
        target.vert[2] = y
    elseif mode == "move-edge" then
        local i = target.a[1]
        local j = target.a[2]

        target.a[1] = x - target.move_x
        target.a[2] = y - target.move_y
        target.b[1] = (x + (target.b[1] - i)) - target.move_x
        target.b[2] = (y + (target.b[2] - j)) - target.move_y
    elseif mode == "move-poly" then
        local i = target.poly[1][1]
        local j = target.poly[1][2]

        target.poly[1][1] = x - target.move_x
        target.poly[1][2] = y - target.move_y
        target.poly[2][1] = (x + (target.poly[2][1] - i)) - target.move_x
        target.poly[2][2] = (y + (target.poly[2][2] - j)) - target.move_y
        target.poly[3][1] = (x + (target.poly[3][1] - i)) - target.move_x
        target.poly[3][2] = (y + (target.poly[3][2] - j)) - target.move_y
    end
end

function love.draw()
    love.graphics.push()
    love.graphics.scale(zoom)
    love.graphics.translate(view[1], view[2])

    if image.instance ~= nil then
        love.graphics.setColor(255, 255, 255)
        love.graphics.draw(image.instance, 0, 0)
    end

    love.graphics.setLineWidth(2)

    local edge_cache = {}

    for i, poly in ipairs(polygons) do
        if is_selected(poly[1]) and is_selected(poly[2]) and is_selected(poly[3]) then
            love.graphics.setColor(50, 50, 255)
        elseif target.type == "poly" and target.poly == poly then
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

            if not edge_cache[{a, b}] and not edge_cache[{b, a}] then
                if is_selected(a) and is_selected(b) then
                    love.graphics.setColor(50, 50, 255, 150)
                elseif target.type == "edge" and target.a == a and target.b == b or target.a == b and target.b == a then
                    love.graphics.setColor(50, 255, 50, 150)
                else
                    love.graphics.setColor(255, 255, 255)
                end

                love.graphics.line(a[1], a[2], b[1], b[2])
                edge_cache[{a, b}] = true
            end
        end
    end

    for i, vert in pairs(vertices) do
        if is_selected(vert) then
            love.graphics.setColor(50, 50, 255)
        elseif target.type == "vert" and target.vert == vert then
            love.graphics.setColor(50, 255, 50, 150)
        else
            love.graphics.setColor(255, 255, 255)
        end

        love.graphics.circle("fill", vert[1], vert[2], 4, 8)
    end

    if box_select then
        local x1, y1 = box_select[1], box_select[2]
        local x2, y2 = translate_mouse(love.mouse.getPosition())

        love.graphics.setColor(155, 155, 255, 100)
        love.graphics.rectangle("fill", x1, y1, x2 - x1, y2 - y1)
        love.graphics.setColor(155, 155, 255, 200)
        love.graphics.rectangle("line", x1, y1, x2 - x1, y2 - y1)
    end

    love.graphics.pop()
    love.graphics.setColor(255, 255, 255)
    love.graphics.print(#polygons .. " polygons, " .. #vertices .. " vertices", 16, 16)
end
