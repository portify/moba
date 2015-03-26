local plane_type = require "shared/world-plane"

local world = {}
world.__index = world

function world:new(filename)
    print("world:new", filename)
    local new = setmetatable({}, self)

    new.filename = filename
    new.mesh = {}

    if not is_client then
        new:load_mesh()

        -- local a = plane_type:new({120, 140}, {230, 150}, {190, 240})
        -- table.insert(new.mesh, a)
        --
        -- local b = plane_type:new({120, 140}, {230, 150}, {250, 34})
        -- table.insert(new.mesh, b)
        --
        -- a.planes[1] = b
        -- b.planes[1] = a
        --
        -- local c = plane_type:new({230, 150}, {250, 34}, {330, 160})
        -- table.insert(new.mesh, c)
        --
        -- b.planes[2] = c
        -- c.planes[1] = b
        --
        -- local d = plane_type:new({250, 34}, {330, 160}, {600, 160})
        -- table.insert(new.mesh, d)
        --
        -- c.planes[2] = d
        -- d.planes[1] = c
    end

    return new
end

function world:load_mesh()
    print("Loading map: " .. self.filename)

    self.mesh = {}
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
        end
    end

    print("  - " .. #vertices  .. " verts")
    print("  - " .. #self.mesh .. " polys")

    local n = 0

    -- Go through all polygons with all others and find shared edges
    for t, a in ipairs(self.mesh) do
        for i=1, 3 do
            local a1 = a.points[i]
            local a2 = a.points[i % 3 + 1]

            for u, b in ipairs(self.mesh) do
                if t ~= u then
                    for j=1, 3 do
                        local b1 = b.points[j]
                        local b2 = b.points[j % 3 + 1]

                        if (a1 == b2 and a2 == b1) or (a1 == b1 and a2 == b2) then
                            a.planes[i] = b
                            -- b.planes[j] = a
                            n = n + 1
                        end
                    end
                end
            end
        end
    end

    print("  - " .. n .. " shared edges")
end

function world:pack()
    return {self.filename}
end

function world:unpack(t)
    self.filename = t[1]
    self:load_mesh()
end

-- local function get_center(points)
--     local x = (points[1][1] + points[2][1]) / 2
--     local y = (points[1][2] + points[2][2]) / 2
--
--     return {(x + points[3][1]) / 2, (x + points[3][2]) / 2}
--     -- return {x, y}
-- end
--
-- local function point_in_triangle(x, y, p0, p1, p2)
--
-- end

function world:get_plane(x, y)
    for i, plane in ipairs(self.mesh) do
        -- if point_in_triangle(x, y, plane.points[1], plane.points[2], plane.points[3]) then
        if plane:contains(x, y) then
            return plane
        end
    end

    return nil
end

function world:draw()
    love.graphics.setLineWidth(1)

    -- local which = self:get_plane(love.mouse.getPosition())

    for i, plane in ipairs(self.mesh) do
        -- if plane == which then
        --     love.graphics.setColor(100, 200, 100)
        --     plane:draw("fill")
        --     love.graphics.setColor(255, 255, 255)
        -- end

        love.graphics.setColor(255, 255, 255, 50)
        plane:draw("fill")
        -- love.graphics.setColor(255, 255, 255)
        -- plane:draw("line")
        -- love.graphics.circle("line", c[1], c[2], 4)

        -- for j=1, 3 do
        --     local other = plane.planes[j]
        --
        --     if other ~= nil then
        --         local c1 = {plane:center()}
        --         local c2 = {other:center()}
        --         love.graphics.setColor(0, 255, 0)
        --         love.graphics.line(c1[1], c1[2], c2[1], c2[2])
        --     end
        -- end
    end
end

return world
