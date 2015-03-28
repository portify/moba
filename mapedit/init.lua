local util = require "mapedit/util"
local open_settings = require "mapedit/settings"

local draw_status_bar = true

local map
local vertices, polygons
local mode, target
local selection

local dragging, drag_start_view, drag_start_user
local pressed = {}
local view, zoom

local box_select

local ui_font

local status_text
local status_time

local menubar
local current_message_box

-- this is too hacky
local is_explicit_quit = false

local function explicit_quit()
    is_explicit_quit = true
    love.event.quit()
end

local function translate_mouse(x, y)
    return (x                      ) / zoom + view[1],
           (y - menubar:GetHeight()) / zoom + view[2]
end

local function is_selected(vert)
    if box_select then
        local x1, y1 = box_select[1], box_select[2]
        local x2, y2 = translate_mouse(love.mouse.getPosition())

        if util.in_box(vert, x1, y1, x2, y2) then
            return true
        end
    end

    return selection[vert]
    -- return util.in_array(selection, vert)
end

local function become_dirty()
    if not map.dirty then
        map.dirty = true
        love.window.setTitle((map.filename or "Untitled") .. " * - mapedit")
    end
end

local function set_image(filename, clean)
    if filename == "" then
        if not clean and map.image then
            become_dirty()
        end

        map.image = nil
        return
    end

    if not clean and (not map.image or map.image.filename ~= filename) then
        become_dirty()
    end

    map.image = {
        filename = filename,
        instance = love.graphics.newImage(filename)
    }
end

local function message_box(title, text, action)
    if current_message_box then
        current_message_box:Remove()
    end

    local frame = loveframes.Create("frame")
    frame:SetName(title)
    frame:SetScreenLocked(1)
    frame:Center()

    local label = loveframes.Create("text", frame)
    label:SetPos(6 + 1, 6 + 25)
    label:SetSize(frame:GetWidth() - 2 - 12, frame:GetHeight() - 26 - 12)
    label:SetText(text)

    local button = loveframes.Create("button", frame)
    button:SetText("OK")
    button:SetPos(
        frame:GetWidth()  - 6 - 1 - button:GetWidth(),
        frame:GetHeight() - 6 - 1 - button:GetHeight())

    function button:OnClick()
        frame:Remove()
        if action then action() end
    end

    current_message_box = frame
end

local function check_dirty(text, action)
    if map.dirty then
        message_box("Confirm action", "Map '" .. (map.filename or "Untitled") .. "' has been modified. Discard changes and " .. text .. " anyway?", action)
    else
        action()
    end
end

local function clear_map()
    map = {}

    view = {0, 0}
    zoom = 1

    vertices = setmetatable({}, {__mode = "v"})
    polygons = {}

    target = {}
    selection = {}
    box_select = nil
end

local function new_map()
    love.window.setTitle("Untitled - mapedit")

    clear_map(true)
    -- set_image("maps/map.jpg", true)

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

    if map.image ~= nil then
        data = data .. "i " .. map.image.filename .. "\n"
    end

    local vert_id = {}
    local vert_next = 1

    for i, vert in pairs(vertices) do
        vert_id[vert] = vert_next
        vert_next = vert_next + 1
        data = data .. "v " .. vert[1] .. " " .. vert[2] .. "\n"
    end

    for i, poly in ipairs(polygons) do
        local a = vert_id[poly[1]]
        local b = vert_id[poly[2]]
        local c = vert_id[poly[3]]

        if util.area2(poly) < 0 then
            a, b, c = c, b, a
        end

        data = data .. "p " .. a .. " " .. b .. " " .. c .. "\n"
    end

    love.filesystem.write(filename, data)
    love.window.setTitle(filename .. " - mapedit")

    map.filename = filename
    map.dirty = false

    status_text = "Saved map to '" .. filename .. "'..."
    status_time = 1

    return true
end

local function open_map(filename)
    if not love.filesystem.isFile(filename) then
        message_box("Error", "Map file '" .. filename .. "' does not exist")
        return false
    end

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

    love.window.setTitle(filename .. " - mapedit")

    map.filename = filename
    map.dirty = false

    status_text = "Loaded map from '" .. filename .. "'..."
    status_time = 1

    return true
end

local function open_text_input(title, label, action)
    local frame = loveframes.Create("frame")
    frame:SetSize(300, 25 + 6 + 25 + 6 + 1)
    frame:SetName(title)
    frame:SetScreenLocked(1)
    frame:Center()

    local input = loveframes.Create("textinput", frame)
    input:SetPos(6 + 1, 6 + 25)
    input:SetFocus(true)

    local button = loveframes.Create("button", frame)
    button:SetText(label)
    button:SetPos(6 + 1 + input:GetWidth() + 6, 6 + 25)

    local function submit()
        if action(input:GetText()) then
            frame:Remove()
        end
    end

    input.OnEnter = submit
    button.OnClick = submit

    return input
end

local function save_map_as()
    local input = open_text_input("Save As...", "Save", save_map)
    input:SetText("maps/.textmap")
    input:MoveIndicator(5, true)
end

local function open_map_from()
    local input = open_text_input("Open...", "Open", open_map)
    input:SetText("maps/.textmap")
    input:MoveIndicator(5, true)
end

local function set_view(x, y)
    if map.image ~= nil then
        view[1] = math.min(map.image.instance:getWidth()  - (love.graphics.getWidth()  / zoom     ), x)
        view[2] = math.min(map.image.instance:getHeight() - (love.graphics.getHeight() / zoom - 42), y)
    else
        view[1] = x
        view[2] = y
    end

    view[1] = math.max(0, view[1])
    view[2] = math.max(0, view[2])
end

local function is_on_screen(x, y)
    return
        x >= view[1] - 8 * zoom and
        y >= view[2] - 8 * zoom and
        x < view[1] + love.graphics.getWidth()  / zoom + 8 * zoom and
        y < view[2] + love.graphics.getHeight() / zoom + 8 * zoom - 42
end

local function perform_delete(mode)
    local deleted = false
    local test

    if mode == "vert" then
        test = function(poly)
            return selection[poly[1]] or selection[poly[2]] or selection[poly[3]]
        end
    elseif mode == "edge" then
        test = function(poly)
            return
                (selection[poly[1]] and selection[poly[2]]) or
                (selection[poly[2]] and selection[poly[3]]) or
                (selection[poly[3]] and selection[poly[1]])
        end
    elseif mode == "poly" then
        test = function(poly)
            return selection[poly[1]] and selection[poly[2]] and selection[poly[3]]
        end
    else
        error("unknown delete mode " .. mode)
    end

    for i=#polygons, 1, -1 do
        if test(polygons[i]) then
            table.remove(polygons, i)
            deleted = true
        end
    end

    selection = {}
    target = {}

    collectgarbage()

    if deleted then
        become_dirty()
    end
end

local function update_target()
    local x, y = translate_mouse(love.mouse.getPosition())

    for i, vert in pairs(vertices) do
        if
            x >= vert[1] - 5 and y >= vert[2] - 5 and
            x <  vert[1] + 5 and y <  vert[2] + 5
        then
            target = {type = "vert", vert = vert}
            return
        end
    end

    for i, poly in ipairs(polygons) do
        for i=1, #poly do
            local a = poly[i]
            local b = poly[(i % #poly) + 1]

            if util.line_on_circle(a, b, {x, y}, 4) then
                target = {type = "edge", poly = poly, edge = i, a = a, b = b}
                return
            end
        end

        if util.point_in_triangle(x, y, poly[1], poly[2], poly[3]) then
            target = {type = "poly", poly = poly}
            return
        end
    end

    target = {}
end

local function draw_status(vertex_count)
    local width, height = love.graphics.getDimensions()
    local p = 4
    local h = 22
    local w = width - p * 2

    local textl

    if status_text == nil then
        textl =
            "Triangles: " .. #polygons .. " | " ..
            "Vertices: " .. vertex_count .. (#selection > 0 and (" (" .. #selection .. " selected)") or "")
    else
        textl = status_text
    end

    local mx, my = translate_mouse(love.mouse.getPosition())
    local textr =
        math.max(0, math.floor(mx)) .. ", " ..
        math.max(0, math.floor(my)) ..
        " (" .. zoom .. "x)"

    love.graphics.setColor(240, 240, 240)
    love.graphics.rectangle("fill", 0, height - h, width, h)
    love.graphics.setColor(0, 0, 0)
    love.graphics.printf(textl, p * 2, height - h + p, width - p * 4)
    love.graphics.printf(textr, p * 2, height - h + p, width - p * 4, "right")
end

local function draw_map()
    if map.image ~= nil then
        love.graphics.setColor(255, 255, 255)
        love.graphics.draw(map.image.instance, 0, 0)
    end

    -- Should definitely switch to a static surface that we only update when
    -- the mesh is changed.
    -- Set stuff up for drawing the mesh
    local cull_cache = {}
    local edge_cache = {}

    local function vert_seen(v)
        if cull_cache[v] == nil then
            cull_cache[v] = is_on_screen(v[1], v[2])
        end
        return cull_cache[v]
    end

    love.graphics.setLineWidth(1)
    love.graphics.setPointStyle("rough")
    love.graphics.setPointSize(10 * zoom)

    -- Draw all polygons that have vertices within the screen
    for i, poly in ipairs(polygons) do
        if vert_seen(poly[1]) or vert_seen(poly[2]) or vert_seen(poly[3]) then
            if is_selected(poly[1]) and is_selected(poly[2]) and is_selected(poly[3]) then
                love.graphics.setColor( 50, 100, 200, 150)
            elseif target.type == "poly" and target.poly == poly then
                love.graphics.setColor( 50, 200,  50, 150)
            else
                love.graphics.setColor(255, 255, 255,  50)
            end

            love.graphics.polygon("fill",
                poly[1][1], poly[1][2],
                poly[2][1], poly[2][2],
                poly[3][1], poly[3][2])

            -- Draw all edges of the polygon
            -- This could be unrolled without too much verbosity, --
            for i=1, 3 do
                local a = poly[i]
                local b = poly[i % #poly + 1] -- it would be good for this

                if not edge_cache[{a, b}] and not edge_cache[{b, a}] then
                    if is_selected(a) and is_selected(b) then
                        love.graphics.setColor( 50, 100, 200)
                    elseif target.type == "edge" and target.a == a and target.b == b or target.a == b and target.b == a then
                        love.graphics.setColor( 50, 200,  50)
                    else
                        love.graphics.setColor(255, 255, 255)
                    end

                    love.graphics.line(a[1], a[2], b[1], b[2])
                    edge_cache[{a, b}] = true
                end
            end
        end
    end

    -- Figure out snap stuff
    local snap1, snap2

    if target.type == "vert" then
        -- snap2 = util.find_nearby_vert(vertices, target.vert, 8)
        snap2 = util.find_near_vert(vertices, target.vert)

        if snap2 ~= nil then
            snap1 = target.vert
        end
    end

    local vertex_count = 0

    -- Draw all vertices separately
    for i, vert in pairs(vertices) do
        if vert_seen(vert) then -- Cull vertices to screen as well
            if vert == snap1 or vert == snap2 then
                love.graphics.setColor(200,  50, 200)
            elseif is_selected(vert) then
                love.graphics.setColor( 50, 100, 200)
            elseif target.type == "vert" and target.vert == vert then
                love.graphics.setColor( 50, 200,  50)
            else
                love.graphics.setColor(255, 255, 255)
            end

            love.graphics.point(vert[1], vert[2])
        end

        vertex_count = vertex_count + 1
    end

    return vertex_count
end

local function generate_menu_bar(entries)
    local bar = loveframes.Create("panel")
    local offset = 0
    local height = 0

    for i, entry in ipairs(entries) do
        local button = loveframes.Create("button", bar)
        button:SetPos(offset, 0)
        button:SetText(entry[1])

        function button:OnClick()
            local menu = loveframes.Create("menu")
            menu:SetPos(self:GetX(), self:GetY() + self:GetHeight())
            entry[2](menu)
        end

        height = math.max(height, button:GetHeight())
        offset = offset + button:GetWidth()
    end

    bar:SetPos(0, 0)
    bar:SetSize(love.graphics.getWidth(), height)

    return bar
end

--------------
-- love events

function love.load()
    loveframes = require("lib.loveframes")
    loveframes.util.SetActiveSkin(config.ui_skin)

    menubar = generate_menu_bar {
        {"File", function (menu)
            -- Generate game map menu
            local open_game = loveframes.Create("menu")
            love.filesystem.getDirectoryItems("maps/", function (map)
                if love.filesystem.isFile("maps/" .. map) and map:sub(-8) == ".textmap" then
                    open_game:AddOption(map:sub(0, -9), false, function()
                        check_dirty("open other map", function() open_map("maps/" .. map) end)
                    end)
                end
            end)

            menu:AddOption("New", "assets/icons/page_add.png", function() check_dirty("create new map", new_map) end)
            menu:AddOption("Open...", "assets/icons/folder.png", function() check_dirty("open other map", open_map_from) end)
            menu:AddSubMenu("Open game map ->", "assets/icons/folder_go.png", open_game)
            menu:AddDivider()
            menu:AddOption("Save", "assets/icons/disk.png", function()
                if map.filename == nil then
                    save_map_as()
                else
                    save_map(map.filename)
                end
            end)
            menu:AddOption("Save as...", "assets/icons/disk_multiple.png", function() save_map_as() end)
            menu:AddDivider()
            menu:AddOption("Exit", "assets/icons/cross.png", function() check_dirty("exit", love.event.quit) end)
        end},
        {"Edit", function (menu)
            menu:AddOption("Undo (you wish)", "assets/icons/arrow_undo.png")
            menu:AddOption("Redo (you wish)", "assets/icons/arrow_redo.png")
            menu:AddDivider()
            menu:AddOption("Deselect", "assets/icons/shape_square_delete.png", function()
                selection = {}
            end)
            menu:AddOption("Select All", "assets/icons/shape_square.png", function()
                selection = {}

                for i, vert in pairs(vertices) do
                    selection[vert] = true
                    -- table.insert(selection, vert)
                end
            end)
        end},
        {"View", function (menu)
            menu:AddOption("Toggle Status Bar", false, function()
                draw_status_bar = not draw_status_bar
            end)
        end},
        {"Tools", function (menu)
            menu:AddOption("Set Background", "assets/icons/image.png", function()
                local input = open_text_input("Set Background", "Apply", function(filename)
                    if filename == "" or love.filesystem.isFile(filename) then
                        set_image(filename)
                        return true
                    else
                        message_box("Error", "Cannot find file '" .. filename .. "' for background image")
                        return false
                    end
                end)
            end)
            menu:AddOption("Delete Stray Triangles", "assets/icons/bug_link.png", function()
                for t=#polygons, 1, -1 do
                    local a = polygons[t]
                    local shared = false

                    for i=1, 3 do
                        if shared then break end

                        local a1 = a[i]
                        local a2 = a[i % 3 + 1]

                        for u, b in ipairs(polygons) do
                            if shared then break end

                            if t ~= u then
                                for j=1, 3 do
                                    local b1 = b[j]
                                    local b2 = b[j % 3 + 1]

                                    if (a1 == b2 and a2 == b1) or (a1 == b1 and a2 == b2) then
                                        shared = true
                                        break
                                    end
                                end
                            end
                        end
                    end

                    if not shared then
                        table.remove(polygons, t)
                        become_dirty()
                    end
                end

                collectgarbage()
            end)
            menu:AddDivider()
            menu:AddOption("Settings", "assets/icons/cog.png", open_settings)
        end},
        {"Help", function (menu)
            menu:AddOption("Help", "assets/icons/help.png", function()
                local window = loveframes.Create("frame")
                window:SetName("Help")
                window:SetScreenLocked(1)
                window:Center()
                local text = loveframes.Create("text", window)
                text:SetPos(6 + 1, 6 + 25)
                text:SetSize(window:GetWidth() - 2 - 12, window:GetHeight() - 26 - 12)
                text:SetText("Drag from a lone face to extrude new triangle and grab last vertex, move vertex near other to snap. Single (ctrl+)click to select, delete to delete ALL polygons that use ANY of the selected vertices.")
            end)
            menu:AddOption("About", "assets/icons/information.png", function()
                local window = loveframes.Create("frame")
                window:SetName("About")
                window:SetScreenLocked(1)
                window:Center()
                local text = loveframes.Create("text", window)
                text:SetPos(6 + 1, 6 + 25)
                text:SetSize(window:GetWidth() - 2 - 12, window:GetHeight() - 26 - 12)
                text:SetText("This is the `moba` (really bad name) map editor, which is (just as bad) named `mapedit`. Very original. Regardless, it's a pretty cool map editor. Fun fact: You can open as many instances of this window as you want! Play around.")
            end)
        end}
    }

    ui_font = love.graphics.newFont(12)
    new_map()
end

function love.quit()
    if not is_explicit_quit then
        check_dirty("quit", explicit_quit)
        return true
    end
end

function love.update(dt)
    if status_text ~= nil then
        status_time = status_time - dt

        if status_time < 0 then
            status_text = nil
        end
    end

    loveframes.update(dt)
end

function love.keypressed(key, unicode)
    if loveframes.keypressed(key) then
        return
    end

    if love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl") then
        if key == "n" then
            check_dirty("create new map", new_map)
        elseif key == "o" then
            check_dirty("open other map", open_map_from)
        elseif key == "s" then
            if map.filename == nil or love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift") then
                save_map_as()
            else
                save_map(map.filename)
            end
        elseif key == "a" then
            selection = {}

            for i, vert in pairs(vertices) do
                selection[vert] = true
            end
        elseif key == "d" then
            selection = {}
        -- elseif key == "f" then
        --     for i, poly in pairs(polygons) do
        --         if util.area2(poly) < 0 then
        --             poly[1], poly[2], poly[3] = poly[3], poly[2], poly[1]
        --         end
        --     end
        end
    else
        if key == "escape" then
            selection = {}
        elseif key == "delete" and mode == nil then
            local count = 0

            for vert, yes in pairs(selection) do
                count = count + 1
                if count == 3 then break end
            end

            if count == 2 then
                perform_delete("edge")
            else
                perform_delete("vert")
            end
        elseif (love.keyboard.isDown("lalt") or love.keyboard.isDown("ralt")) and mode == nil then
            if key == "q" then
                perform_delete("poly")
            elseif key == "w" then
                perform_delete("edge")
            elseif key == "e" then
                perform_delete("vert")
            end
        end
    end

    loveframes.keypressed(key, unicode)
end

function love.keyreleased(key)
    loveframes.keyreleased(key)
end

function love.textinput(text)
    loveframes.textinput(text)
end

function love.mousepressed(x, y, button)
    if loveframes.mousepressed(x, y, button) then
        return
    end

    pressed[button] = true

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
        love.mouse.setRelativeMode(true)
    elseif button == "wu" then
        local old = zoom
        zoom = math.min(4, zoom + 0.25)
        local new = zoom

        -- zoom into cursor
        set_view(view[1] + 0, view[2] + 0)
    elseif button == "wd" then
        local old = zoom
        zoom = math.max(0.25, zoom - 0.25)
        local new = zoom

        -- zoom out of cursor
        set_view(view[1] + 0, view[2] + 0)
    end
end

function love.mousereleased(x, y, button)
    if loveframes.mousereleased(x, y, button) or not pressed[button] then
        return
    end

    pressed[button] = false

    local ox, oy = x, y
    x, y = translate_mouse(x, y)

    if button == "m" then
        -- dragging = false
        love.mouse.setRelativeMode(false)
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
                    selection[vert] = true
                end
            end

            box_select = nil
            return
        end

        if mode == nil then
            if target.type == "vert" then
                selection[target.vert] = true
            elseif target.type == "edge" then
                selection[target.a] = true
                selection[target.b] = true
            elseif target.type == "poly" then
                selection[target.poly[1]] = true
                selection[target.poly[2]] = true
                selection[target.poly[3]] = true
            end
        elseif mode == "move-vertex" then
            target.vert[1] = x
            target.vert[2] = y

            do
                -- local snap = util.find_nearby_vert(vertices, target.vert, 8)
                local snap = util.find_near_vert(vertices, target.vert)

                if snap ~= nil then
                    for i=#polygons, 1, -1 do
                        local poly = polygons[i]

                        if poly[1] == target.vert then poly[1] = snap end
                        if poly[2] == target.vert then poly[2] = snap end
                        if poly[3] == target.vert then poly[3] = snap end

                        -- If polygon snaps into itself remove the polygon as it has no area anymore
                        if poly[1] == poly[2] or poly[1] == poly[3] or poly[2] == poly[3] then
                            table.remove(polygons, i)
                        end
                    end

                    target = {}
                    become_dirty()
                end
            end

            collectgarbage()
        end

        mode = nil
    end
end

function love.mousemoved(x, y, dx, dy)
    local ox, oy = x, y
    x, y = translate_mouse(x, y)

    if love.mouse.getRelativeMode() then
        set_view(
            view[1] - dx * 1.5 / zoom,
            view[2] - dy * 1.5 / zoom
        )
    end

    if box_select then
        return
    end

    if not pressed["l"] then
        update_target()
        return
    end

    if mode == nil then
        if target.type == "vert" then
            mode = "move-vertex"
            become_dirty()
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
                become_dirty()
            else
                -- Otherwise, extrapolate a new polygon from the edge
                local c = {x, y}
                table.insert(vertices, c)

                local poly = {a, b, c}
                table.insert(polygons, poly)

                target = {
                    type = "vert",
                    vert = c
                }

                mode = "move-vertex"
                become_dirty()
            end
        elseif target.type == "poly" then
            target.move_x = x - target.poly[1][1]
            target.move_y = y - target.poly[1][2]

            mode = "move-poly"
            become_dirty()
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
    -- love.graphics.translate(0, 20)
    love.graphics.translate(0, menubar:GetHeight())
    love.graphics.scale(zoom)
    love.graphics.translate(-view[1], -view[2])

    local vertex_count = draw_map()

    -- Draw the (extremely ugly) vertex snapping guide
    -- if target.type == "vert" then
    --     local snap = util.find_nearby_vert(vertices, target.vert, 8)
    --
    --     if snap ~= nil then
    --         love.graphics.setColor(0, 0, 0)
    --         love.graphics.setLineWidth(8)
    --         love.graphics.line(target.vert[1], target.vert[2], snap[1], snap[2])
    --     end
    -- end

    -- Draw the box we're currently selecting in
    if box_select then
        local x1, y1 = box_select[1], box_select[2]
        local x2, y2 = translate_mouse(love.mouse.getPosition())

        love.graphics.setColor(155, 155, 255, 100)
        love.graphics.rectangle("fill", x1, y1, x2 - x1, y2 - y1)
        love.graphics.setColor(155, 155, 255, 200)
        love.graphics.rectangle("line", x1, y1, x2 - x1, y2 - y1)
    end

    love.graphics.pop()
    love.graphics.setFont(ui_font)

    if draw_status_bar then
        draw_status(vertex_count)
    end

    if config.enable_fps_warning and love.timer.getFPS() < 50 then
        love.graphics.setColor(255, 50, 50)
        love.graphics.print("FPS: " .. love.timer.getFPS(), 8, 28)
    end

    loveframes.draw()
end
