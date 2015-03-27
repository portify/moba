local world
local path

-- inline float triarea2(const float* a, const float* b, const float* c)
-- {
--  const float ax = b[0] - a[0];
--  const float ay = b[1] - a[1];
--  const float bx = c[0] - a[0];
--  const float by = c[1] - a[1];
--  return bx*ay - ax*by;
-- }

-- inline bool vequal(const float* a, const float* b)
-- {
--  static const float eq = 0.001f*0.001f;
--  return vdistsqr(a, b) < eq;
-- }

function love.load()
    world = require("world"):new("map.txt")
end

function love.mousepressed(x, y, button)
    x = x / 0.5 + 600
    y = y / 0.5 + 500

    local target = world:get_plane(x, y)

    if target ~= nil then
        path = world.mesh[1]:find_path(target)
    else
        path = nil
    end
end

function love.draw()
    love.graphics.scale(0.5)
    love.graphics.translate(-600, -500)
    world:draw()

    if path ~= nil then
        love.graphics.setColor(255, 0, 255)
        love.graphics.setLineWidth(3)

        for i, each in ipairs(path) do
            local x, y = each[1]:center()
            local a = each[2][1]
            local b = each[2][2]
            --print(a[1], a[2], b[1], b[2])
            love.graphics.circle("fill", x, y, 8, 16)
            love.graphics.line(a[1], a[2], b[1], b[2])
        end
    end
end