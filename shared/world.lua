local plane_type = require "shared/world-plane"

local world = {}
world.__index = world

function world:new()
    local new = setmetatable({}, self)
    new.mesh = {}

    if true then
        local a = plane_type:new({120, 140}, {230, 150}, {190, 240})
        table.insert(new.mesh, a)

        local b = plane_type:new({120, 140}, {230, 150}, {250, 34})
        table.insert(new.mesh, b)

        a.planes[1] = b
        b.planes[1] = a

        local c = plane_type:new({230, 150}, {250, 34}, {330, 160})
        table.insert(new.mesh, c)

        b.planes[2] = c
        c.planes[1] = b

        local d = plane_type:new({250, 34}, {330, 160}, {600, 160})
        table.insert(new.mesh, d)

        c.planes[2] = d
        d.planes[1] = c
    end

    return new
end

function world:pack()
    -- return {self.mesh}
    return false
end

function world:unpack(t)
    -- self.mesh = t[3]
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

        plane:draw("line")
        -- love.graphics.circle("line", c[1], c[2], 4)

        -- for j=1, #plane.points do
        --     local other = plane.planes[j]
        --
        --     if other ~= nil then
        --         local c1 = get_center(plane.points)
        --         local c2 = get_center(other.points)
        --         love.graphics.line(c1[1], c1[2], c2[1], c2[2])
        --     end
        -- end
    end
end

return world
