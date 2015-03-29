local util = require "mapedit.util"
local open_settings = require "mapedit.settings"
entities = require "mapedit.entities"

local enable_mesh = true
local enable_path = true
local enable_ents = true

local vertices, polygons

local dragging, drag_start_view, drag_start_user
local pressed = {}
local view, zoom

local box_select

local ui_font

local status_text
local status_time

-- this is too hacky
local is_explicit_quit = false

local function explicit_quit()
    is_explicit_quit = true
    love.event.quit()
end

function translate_mouse(x, y)
    return (x                      ) / zoom + view[1],
           (y - menubar:GetHeight()) / zoom + view[2]
end

local function is_on_screen(x, y)
    return
        x >= view[1] - 8 * zoom and
        y >= view[2] - 8 * zoom and
        x < view[1] + love.graphics.getWidth() / zoom + 8 * zoom and
        y < view[2] + love.graphics.getHeight() / zoom + 8 * zoom - menubar:GetHeight() - statusbar:GetHeight()
end

local function set_view(x, y)
    if map.image ~= nil then
        local width = love.graphics.getWidth() / zoom
        local height = love.graphics.getHeight() / zoom - menubar:GetHeight() - statusbar:GetHeight()

        view[1] = math.min(map.image.instance:getWidth()  - width, x)
        view[2] = math.min(map.image.instance:getHeight() - height, y)
    else
        view[1] = x
        view[2] = y
    end

    view[1] = math.max(0, view[1])
    view[2] = math.max(0, view[2])
end

local function is_selected(vert)
    if box_select then
        local x1, y1 = box_select[1], box_select[2]
        local x2, y2 = translate_mouse(love.mouse.getPosition())

        -- Very bad way of checking for entity
        if getmetatable(vert) ~= nil then
            if util.in_box({vert.x, vert.y}, x1, y1, x2, y2) then
                return true
            end
        elseif util.in_box(vert, x1, y1, x2, y2) then
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

local function set_image(filename, clean)
    if filename == "" then
        if not clean and map.image then
            become_dirty()
        end

        map.image = nil
        return true
    end

    local original = filename

    if not love.filesystem.isFile(filename) and filename:sub(0, 5) == "maps/" then
        filename = "maps-bundled/" .. filename:sub(6)
    end

    if not love.filesystem.isFile(filename) then
        message_box("Error", "Cannot find file '" .. original .. "' for background image")
        return false
    end

    if not clean and (not map.image or map.image.filename ~= original) then
        become_dirty()
    end

    map.image = {
        filename = original,
        instance = love.graphics.newImage(filename)
    }

    return true
end

local function check_dirty(text, action)
    if map.dirty then
        message_box("Confirm action", "Map '" .. (map.filename or "Untitled") .. "' has been modified. Discard changes and " .. text .. " anyway?", action)
    else
        action()
    end
end

local function clear_map()
    map = {
        entities = {},
        paths = {}
    }

    view = {0, 0}
    zoom = 1

    vertices = setmetatable({}, {__mode = "v"})
    polygons = {}

    target = {}
    selection = {}
    mode = nil
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
    local abs = love.path.abs(filename)

    if not abs then
        local path = love.path.normalslashes(filename)
        path = path:sub(0, -#love.path.leaf(filename) - 1)
        love.filesystem.createDirectory(path)
    end

    data = ""

    if map.image ~= nil then
        data = data .. "i " .. map.image.filename .. "\n"
    end

    local vert_id = {}
    local vert_next = 1

    for i, ent in ipairs(map.entities) do
        local name = entities.name_by_ent(getmetatable(ent))
        if name == nil then
            error("Internal error: No name registered for " .. tostring(getmetatable(ent)))
        end

        local line = ent:save()
        if line == nil then
            error("Failed to save a " .. tostring(name) .. " entity")
        end

        data = data .. "e " .. name .. " " .. line .. "\n"
    end

    for i, path in ipairs(map.paths) do
        for i, node in ipairs(path.nodes) do
            data = data .. "n " .. node[1] .. " " .. node[2] .. " " .. path.name .. "\n"
        end
    end

    for i, vert in pairs(vertices) do
        vert_id[vert] = vert_next
        vert_next = vert_next + 1

        -- Round to nearest 0.25x
        local x = math.floor(vert[1] * 4 + 0.25) / 4
        local y = math.floor(vert[2] * 4 + 0.25) / 4

        data = data .. "v " .. x .. " " .. y .. "\n"
    end

    for i, poly in ipairs(polygons) do
        local a = vert_id[poly[1]]
        local b = vert_id[poly[2]]
        local c = vert_id[poly[3]]

        -- Force proper winding order
        if util.area2(poly) < 0 then
            a, b, c = c, b, a
        end

        data = data .. "p " .. a .. " " .. b .. " " .. c .. "\n"
    end

    if abs then
        io.open(filename, "w"):write(data)
    else
        love.filesystem.write(filename, data)
    end

    love.window.setTitle(filename .. " - mapedit")

    map.filename = filename
    map.dirty = false

    status_text = "Saved map to '" .. filename .. "'..."
    status_time = 1

    return true
end

local function open_map(filename, translate_to)
    local abs = love.path.abs(filename)

    if abs then
        status, result = pcall(function() io.input(filename) end)

        if not status then
            message_box("Error", "Map file '" .. filename .. "' does not exist")
            return false
        end
    elseif not love.filesystem.isFile(filename) then
        message_box("Error", "Map file '" .. filename .. "' does not exist")
        return false
    end

    clear_map()

    local verts = {}
    local paths = {}

    local iter
    if abs then
        iter = io.lines()
    else
        iter = love.filesystem.lines(filename)
    end

    -- for line in love.filesystem.lines(filename) do
    for line in iter do
        if line:sub(1, 2) == "v " then
            x, y = line:match("(.*) (.*)", 3)
            local vert = {tonumber(x), tonumber(y)}
            table.insert(vertices, vert)
            table.insert(verts, vert)
        elseif line:sub(1, 2) == "p " then
            a, b, c = line:match("(.*) (.*) (.*)", 3)
            a = verts[tonumber(a)]
            b = verts[tonumber(b)]
            c = verts[tonumber(c)]

            if a == nil or b == nil or c == nil then
                error("Map file refers to unexistant vertices")
            end

            table.insert(polygons, {a, b, c})
        elseif line:sub(1, 2) == "n " then
            local x, y, name = line:match("([^ ]+) ([^ ]+) (.*)", 3)

            if paths[name] == nil then
                paths[name] = {
                    name = name,
                    nodes = {}
                }

                table.insert(map.paths, paths[name])
            end

            -- storing path in here is really poor.
            table.insert(paths[name].nodes, {tonumber(x), tonumber(y), paths[path]})
        elseif line:sub(1, 2) == "e " then
            local name, rest = line:match("([^ ]+) ?(.*)", 3)

            local class = entities.ent_by_name(name)
            if class == nil then
                error("Map contains unknown entity type " .. name)
            end

            local ent = class:open(rest)
            if ent == nil then
                error("Failed to load a " .. name .. " entity")
            end

            table.insert(map.entities, ent)
        elseif line:sub(1, 2) == "i " then
            set_image(line:sub(3))
        end
    end

    collectgarbage()

    if translate_to ~= nil then
        love.window.setTitle(translate_to .. " * - mapedit")
        map.filename = translate_to
        map.dirty = true
    else
        love.window.setTitle(filename .. " - mapedit")
        map.filename = filename
        map.dirty = false
    end

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

local function perform_delete(mode)
    local deleted = false

    if enable_mesh then
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
    end

    -- Baaaaaad
    if enable_path then
        for value, yes in pairs(selection) do
            if value[3] ~= nil then
                local path = value[3]

                for i, node in ipairs(path.nodes) do
                    if node == value then
                        table.remove(path.nodes, i)
                        deleted = true
                        break
                    end
                end

                if #path.nodes < 1 then
                    for i, test in ipairs(map.paths) do
                        if path == test then
                            table.remove(map.paths, i)
                            break
                        end
                    end
                end
            end
        end
    end

    if enable_ents then
        for value, yes in pairs(selection) do
            -- Bad way of checking whether or not it is an entity
            if getmetatable(value) ~= nil then
                for i, ent in ipairs(map.entities) do
                    if ent == value then
                        table.remove(map.entities, i)
                        deleted = true
                        break
                    end
                end
            end
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

    if enable_ents then
        for i, ent in ipairs(map.entities) do
            if ent:is_hover(x, y) then
                target = {type = "ent", ent = ent}
                return
            end
        end
    end

    if enable_path then
        for i, path in ipairs(map.paths) do
            for j, node in ipairs(path.nodes) do
                if util.dist2(x, y, node[1], node[2]) <= 64 then
                    target = {
                        type = "node",
                        path = path,
                        node = node,
                        i = i,
                        j = j
                    }

                    return
                end
            end
        end
    end

    if enable_mesh then
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
    end

    target = {}
end

local function draw_path()
    love.graphics.setLineWidth(2)

    for i, path in ipairs(map.paths) do
        local prev = nil
        love.graphics.setColor(255, 255, 255)

        for i, node in ipairs(path.nodes) do
            if prev ~= nil then
                love.graphics.line(prev[1], prev[2], node[1], node[2])
            end

            prev = node
        end

        -- This double loop is really bad
        for i, node in ipairs(path.nodes) do
            if is_selected(node) then
                love.graphics.setColor( 50, 100, 200)
            elseif target.type == "node" and target.node == node then
                love.graphics.setColor( 50, 200,  50)
            else
                love.graphics.setColor(255, 255, 255)
            end

            love.graphics.circle("fill", node[1], node[2], 8, 16)
        end
    end
end

local function draw_mesh()
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
            love.filesystem.getDirectoryItems("maps-bundled/", function (map)
                if love.filesystem.isFile("maps-bundled/" .. map) and map:sub(-8) == ".textmap" then
                    open_game:AddOption(map:sub(0, -9) .. " (bundled)", false, function()
                        check_dirty("open other map", function() open_map("maps-bundled/" .. map, "maps/" .. map) end)
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
            menu:AddOption("Exit", "assets/icons/cross.png", function() check_dirty("quit", explicit_quit) end)
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

                for i, ent in ipairs(map.entities) do
                    selection[ent] = true
                end
            end)
        end},
        {"View", function (menu)
            local windows = loveframes.Create("menu")
            windows:AddOption(window.entities:GetName(), false, function()
                window.entities:SetVisible(not window.entities:GetVisible())
            end)

            menu:AddOption("Toggle status bar", false, function()
                statusbar:SetVisible(not statusbar:GetVisible())
            end)
            menu:AddDivider()
            menu:AddOption("Toggle navigation mesh", false, function()
                enable_mesh = not enable_mesh
                target = {}
                mode = nil
            end)
            menu:AddOption("Toggle paths", false, function()
                enable_path = not enable_path
                target = {}
                mode = nil
            end)
            menu:AddOption("Toggle entities", false, function()
                enable_ents = not enable_ents
                target = {}
                mode = nil
            end)
            menu:AddDivider()
            menu:AddSubMenu("Windows ->", false, windows)
        end},
        {"Tools", function (menu)
            menu:AddOption("Set Background", "assets/icons/image.png", function()
                local input = open_text_input("Set Background", "Apply", set_image)
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

    statusbar = loveframes.Create("panel")
    statusbar:SetSize(love.graphics.getWidth(), 22)
    statusbar:SetPos(0, love.graphics.getHeight() - statusbar:GetHeight())
    statustext = loveframes.Create("text", statusbar)
    statustext:SetText("")
    statustext:SetSize(statusbar:GetWidth() - 8, statusbar:GetHeight() - 8)
    statustext:SetPos(4, 3)

    ui_font = love.graphics.newFont(12)
    local filename

    for i=#arg, 3, -1 do
        local test = table.concat(arg, " ", i, #arg)

        if love.path.abs(test) then
            filename = test
            break
        end
    end

    if filename ~= nil then
        open_map(filename)
    else
        new_map()
    end

    window = {
        entities = require "mapedit.window-entities"
    }
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

function love.resize(w, h)
    menubar:SetSize(love.graphics.getWidth(), menubar:GetHeight())
    statusbar:SetSize(love.graphics.getWidth(), statusbar:GetHeight())
    statusbar:SetPos(0, love.graphics.getHeight() - statusbar:GetHeight())
    statustext:SetSize(statusbar:GetWidth() - 8, statusbar:GetHeight() - 8)

    set_view(view[1], view[2])
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

            for i, ent in ipairs(map.entities) do
                selection[ent] = true
            end
        elseif key == "d" then
            selection = {}
        elseif key == "p" then
            -- need a better way of creating new nodes.
            -- This is really bad
            local x, y = translate_mouse(love.mouse.getPosition())
            local active = next(selection)
            local path, auto

            if active ~= nil and next(selection, active) ~= nil then
                active = nil -- Check if this is the only selected thing
            end

            if active ~= nil and active[3] ~= nil then
                path = active[3]
                auto = true
            else
                path = {
                    name = "path" .. #map.paths,
                    nodes = {}
                }

                table.insert(map.paths, path)
                auto = false
            end

            -- storing path in here is really poor.
            table.insert(path.nodes, {x, y, path})

            if auto then
                selection = {[path.nodes[#path.nodes]] = true}
            end

            update_target()
        end
    else
        if key == "escape" then
            selection = {}
        elseif key == "delete" and mode == nil then
            local count = 0

            for vert, yes in pairs(selection) do
                -- Bad way of checking for entity
                if getmetatable(vert) == nil then
                    count = count + 1
                    if count == 3 then break end
                end
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

    local ox, oy = x, y
    x, y = translate_mouse(x, y)

    if mode ~= nil then
        mode = nil
        return
    end

    pressed[button] = true

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

            if enable_mesh then
                for i, vert in pairs(vertices) do
                    if vert[1] >= x1 and vert[2] >= y1 and vert[1] <= x2 and vert[2] <= y2 then
                        selection[vert] = true
                    end
                end
            end

            if enable_path then
                for i, path in ipairs(map.paths) do
                    for i, node in ipairs(path.nodes) do
                        if node[1] >= x1 and node[2] >= y1 and node[1] <= x2 and node[2] <= y2 then
                            selection[node] = true
                        end
                    end
                end
            end

            if enable_ents then
                for i, ent in ipairs(map.entities) do
                    if ent.x >= x1 and ent.y >= y1 and ent.x <= x2 and ent.y <= y2 then
                        selection[ent] = true
                    end
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
            elseif target.type == "ent" then
                selection[target.ent] = true
            elseif target.type == "node" then
                selection[target.node] = true
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

    if not pressed["l"] and mode == nil then
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
        elseif target.type == "ent" then
            target.move_x = x - target.ent.x
            target.move_y = y - target.ent.y

            mode = "move-ent"
            become_dirty()
        elseif target.type == "node" then
            target.move_x = x - target.node[1]
            target.move_y = y - target.node[2]

            mode = "move-node"
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
    elseif mode == "move-ent" then
        target.ent.x = x - target.move_x
        target.ent.y = y - target.move_y
    elseif mode == "move-node" then
        target.node[1] = x - target.move_x
        target.node[2] = y - target.move_y
    end
end

function love.draw()
    love.graphics.push()
    -- love.graphics.translate(0, 20)
    love.graphics.translate(0, menubar:GetHeight())
    love.graphics.scale(zoom)
    love.graphics.translate(-view[1], -view[2])

    if map.image ~= nil then
        love.graphics.setColor(255, 255, 255)
        love.graphics.draw(map.image.instance, 0, 0)
    end

    local vertex_count

    if enable_mesh then
        vertex_count = draw_mesh()
    else
        vertex_count = "badly implemented"
    end

    if enable_path then
        draw_path()
    end

    -- Draw all entities
    if enable_ents then
        for i, ent in ipairs(map.entities) do
            local state

            if is_selected(ent) then
                state = "select"
            elseif target.ent == ent then
                state = "hover"
            else
                state = "normal"
            end

            ent:draw(state)
        end
    end

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

    if config.enable_fps_warning and love.timer.getFPS() < 50 then
        love.graphics.setColor(255, 50, 50)
        love.graphics.print("FPS: " .. love.timer.getFPS(), 8, 28)
    end

    loveframes.draw()

    -- TODO: to be replaced with `statustext`
    if statusbar:GetVisible() then
        local textl = status_text

        if status_text == nil then
            textl =
                "Triangles: " .. #polygons .. " | " ..
                "Vertices: " .. vertex_count
        end

        local mx, my = translate_mouse(love.mouse.getPosition())
        local textr =
            math.max(0, math.floor(mx)) .. ", " ..
            math.max(0, math.floor(my)) ..
            " (" .. zoom .. "x)"

        local x, y = statustext:GetPos()
        local w = statustext:GetWidth()
        love.graphics.setColor(0, 0, 0)
        love.graphics.printf(textl, x, y, w)
        love.graphics.printf(textr, x, y, w, "right")
    end
end
