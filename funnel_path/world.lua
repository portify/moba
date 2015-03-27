local plane_type = require "world-plane"

local world = {}
world.__index = world

function world:new(filename)
    local new = setmetatable({}, self)

    new.filename = filename
    new.mesh = {}
    new:load()

    return new
end

function world:load()
    print("Loading map: " .. self.filename)

    self.mesh = {}
    self.image = nil

    local vertices = {}

    for line in love.filesystem.lines(self.filename) do
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
        elseif line:sub(1, 2) == "i " then
            if is_client then
                self.image = love.graphics.newImage(line:sub(3))
            end
        end
    end

    print("  - " .. #vertices  .. " verts")
    print("  - " .. #self.mesh .. " polys")

    local n = 0

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
                                    n = n + 1
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    print("  - " .. n .. " shared edges")
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
    love.graphics.setLineWidth(1)

    if self.image ~= nil then
        love.graphics.setColor(255, 255, 255)
        love.graphics.draw(self.image, 0, 0)
    end

    for i, plane in ipairs(self.mesh) do
        love.graphics.setColor(255, 255, 255, 25)
        plane:draw("fill")
        love.graphics.setColor(255, 255, 255, 50)
        plane:draw("line")
    end
end

return world
