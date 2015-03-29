local plane_type = require "shared/world-plane"

local world = {}
world.__index = world

function world:new(filename)
    local new = setmetatable({}, self)

    new.filename = filename
    new.mesh = {}
    new.paths = {}

    if not is_client then
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

function world:draw()
    if self.image ~= nil then
        love.graphics.setColor(255, 255, 255)
        love.graphics.draw(self.image, 0, 0)
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
