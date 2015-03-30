local plane_type = require "shared/world-plane"

local world = {}
world.__index = world

function world:new(filename)
    local new = setmetatable({}, self)

    new.filename = filename
    new.mesh = {}
    new.paths = {}

    if is_client then
        local vertexcode = [[
            vec4 position(mat4 transform_projection, vec4 vertex_position) {
                return transform_projection * vertex_position;
            }
        ]]

        local pixelcode = [[
            extern Image vision;
            //extern vec2 image_size;
            /* extern vec2 vision_center;
            extern number vision_radius;
            extern number vision_penumbra;
            number get_fog(vec2 where) {
                number dist = distance(where, vision_center);
                return clamp(mix(1.0, 0.0, (dist - vision_radius) / vision_penumbra), 0.0, 1.0);
            } */

            /*number get_color_scale(vec2 where) {
                //number fog = get_fog(where);
                //return 0.5 + fog * 0.5;
                //return Texel(vision, where).r;
            }*/

            vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
                vec4 texcolor = Texel(texture, texture_coords);
                vec4 original = texcolor * color;
                //vec2 where = vec2(texture_coords.x * image_size.x, texture_coords.y * image_size.y);
                //return original * get_color_scale(texture_coords);
                //return original * get_color_scale(where);
                //vec4 vision = Texel(vision, texture_coords);
                //return vec4(texture_coords.x, texture_coords.y, vision.r, 1);
                //return vision;
                return original * Texel(vision, texture_coords);
            }
        ]]

        new.fog_shader = love.graphics.newShader(pixelcode, vertexcode)
    else
        new:load()
    end

    return new
end

function world:load()
    local original = self.filename
    local filename = self.filename

    print("Loading map " .. filename)

    if not love.filesystem.isFile(filename) and filename:sub(0, 5) == "maps/" then
        filename = "maps-bundled/" .. filename:sub(6)
        print("  Doesn't exist, redirecting to " .. filename)
    end

    if not love.filesystem.isFile(filename) then
        error("Cannot find map " .. original)
    end

    self.mesh = {}
    self.paths = {}
    self.image = nil

    local vertices = {}

    for line in love.filesystem.lines(filename) do
        if line:sub(1, 2) == "v " then
            x, y = line:match("(.*) (.*)", 3)
            table.insert(vertices, {tonumber(x), tonumber(y)})
        elseif line:sub(1, 2) == "p " then
            a, b, c = line:match("(.*) (.*) (.*)", 3)
            table.insert(self.mesh, plane_type:new(
                vertices[tonumber(a)],
                vertices[tonumber(b)],
                vertices[tonumber(c)]
            ))
        elseif line:sub(1, 2) == "n " and not is_client then
            local x, y, name = line:match("([^ ]+) ([^ ]+) (.*)", 3)

            if self.paths[name] == nil then
                self.paths[name] = {}
            end

            table.insert(self.paths[name], {tonumber(x), tonumber(y)})
        elseif line:sub(1, 2) == "e " and not is_client then
            local name, rest = line:match("([^ ]+) ?(.*)", 3)

            local type = entities[name]
            if type == nil then
                error("Unknown entity type " .. name .. " in map")
            end

            local ent = type:from_map(rest)
            add_entity(ent)
        elseif line:sub(1, 2) == "i " then
            if is_client then
                local original = line:sub(3)
                local filename = original

                if not love.filesystem.isFile(filename) and filename:sub(0, 5) == "maps/" then
                    filename = "maps-bundled/" .. filename:sub(6)
                end

                if love.filesystem.isFile(filename) then
                    self.image = love.graphics.newImage(filename)
                else
                    print("  Cannot find image " .. original .. ", ignoring directive")
                end
            end
        end
    end

    -- Go through all polygons with all others and find shared edges
    -- Aaaaaaa this is so ugly
    for t, a in ipairs(self.mesh) do
        for i=1, 3 do
            if a.planes[i] == nil then
                local a1 = a.points[i]
                local a2 = a.points[i % 3 + 1]

                for u, b in ipairs(self.mesh) do
                    if t ~= u then
                        for j=1, 3 do
                            if b.planes[j] == nil then
                                local b1 = b.points[j]
                                local b2 = b.points[j % 3 + 1]

                                if (a1 == b2 and a2 == b1) or (a1 == b1 and a2 == b2) then
                                    a.planes[i] = b
                                    b.planes[j] = a

                                    a.portal[b] = {left = a1, right = a2}
                                    b.portal[a] = {left = b1, right = b2}
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if is_client and self.image ~= nil then
        self.fog_canvas = love.graphics.newCanvas(self.image:getDimensions())
        self.fog_shader:send("vision", self.fog_canvas)
        -- self.fog_shader:send("image_size", {self.image:getDimensions()})
        -- self.fog_shader:send("vision_radius", 250)
        -- self.fog_shader:send("vision_penumbra", 30)
    end
end

function world:pack()
    return {self.filename}
end

function world:unpack(t)
    self.filename = t[1]
    self:load()
end

function world:project(ix, iy)
    local best_plane, best_point, best_distance

    for i, plane in ipairs(self.mesh) do
        local point, distance = plane:project(ix, iy)

        if point ~= nil and (best_distance == nil or distance < best_distance) then
            best_plane = plane
            best_point = point
            best_distance = distance
        end
    end

    if best_distance ~= nil then
        return best_plane, best_point, best_distance
    end
end

function world:get_plane(x, y)
    for i, plane in ipairs(self.mesh) do
        if plane:contains(x, y) then
            return plane
        end
    end

    return nil
end

local angleview = require "shared.angleview"

function world:update_fog_canvas()
    love.graphics.push()
    love.graphics.reset()
    love.graphics.setCanvas(self.fog_canvas)

    -- love.graphics.setColor(127, 127, 127)
    love.graphics.setColor(255, 255, 255)
    love.graphics.rectangle("fill", 0, 0, self.image:getDimensions())

    local control = states.game:get_control()

    if control ~= nil then
        -- local x, y = control.px, control.py
        -- local view = angleview()
        --
        -- love.graphics.setStencil(function()
        --     love.graphics.circle("fill", x, y, 250)
        -- end)
        --
        -- love.graphics.setColor(255, 255, 255)

        -- for i, plane in ipairs(self.mesh) do
        --     local visible = false
        --
        --     for i=1, 3 do
        --         local p = plane.points[i]
        --         p = math.atan2(y - p[2], x - p[1])
        --
        --         if view:is_open(p) then
        --             visible = true
        --             break
        --         end
        --     end
        --
        --     if visible then
        --         plane:draw("fill")
        --
        --         for i=1, 3 do
        --             if plane.planes[i] == nil then
        --                 local a = plane.points[i]
        --                 local b = plane.points[i % 3 + 1]
        --                 a = math.atan2(y - a[2], x - a[1])
        --                 b = math.atan2(y - b[2], x - b[1])
        --                 if a > b then a, b = b, a end
        --                 view:block(a, b)
        --             end
        --         end
        --     end
        -- end
        --
        -- love.graphics.setStencil()
    end

    love.graphics.pop()
    love.graphics.setCanvas()
end

function world:draw()
    if self.image ~= nil then
        self:update_fog_canvas()
        love.graphics.setShader(self.fog_shader)
        love.graphics.setColor(255, 255, 255)
        love.graphics.draw(self.image, 0, 0)
        love.graphics.setShader()
    end

    if debug_nav then
        love.graphics.setLineWidth(1)

        for i, plane in ipairs(self.mesh) do
            love.graphics.setColor(255, 255, 255, 25)
            plane:draw("fill")
            love.graphics.setColor(255, 255, 255, 50)
            plane:draw("line")
        end

        local plane = self:get_plane(states.game.camera:mousepos())

        if plane ~= nil then
            love.graphics.setColor(200, 100, 100, 100)
            plane:draw("fill")
        end
    end

    if debug_nav_link then
        love.graphics.setLineWidth(1)

        for i, plane in ipairs(self.mesh) do
            for j=1, 3 do
                local other = plane.planes[j]

                if other ~= nil then
                    local c1 = {plane:center()}
                    local c2 = {other:center()}
                    love.graphics.setColor(0, 255, 0)
                    love.graphics.line(c1[1], c1[2], c2[1], c2[2])
                end
            end
        end
    end
end

return world
