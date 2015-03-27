local function point_into_triangle(triangle, wx, wy)
    local x0 = triangle[1][1]
    local x1 = triangle[2][1]
    local x2 = triangle[3][1]
    local y0 = triangle[1][2]
    local y1 = triangle[2][2]
    local y2 = triangle[3][2]

    local ax0 = x1 - x0
    local ay0 = y1 - y0
    local bx0 = wx - x0
    local by0 = wy - y0
    local dz0 = (ax0 * by0) - (ay0 * bx0)

    local ax1 = x2 - x1
    local ay1 = y2 - y1
    local bx1 = wx - x1
    local by1 = wy - y1
    local dz1 = (ax1 * by1) - (ay1 * bx1)

    local ax2 = x0 - x2
    local ay2 = y0 - y2
    local bx2 = wx - x2
    local by2 = wy - y2
    local dz2 = (ax2 * by2) - (ay2 * bx2)

    local rx, ry, rz
    local wd

    local result, distance

    if dz0 >= 0 and dz1 >= 0 and dz2 >= 0 then -- +++ inside
        result = {wx, wy}
        distance = 0
    elseif dz0 < 0 and dz1 >= 0 and dz2 < 0 then -- -+- vertex
        result = {x0, y0}
        distance = bx0^2 + by0^2
    elseif dz0 < 0 and dz1 < 0 and dz2 >= 0 then -- --+ vertex
        result = {x1, y1}
        distance = bx1^2 + by1^2
    elseif dz0 >= 0 and dz1 < 0 and dz2 < 0 then -- +-- vertex
        result = {x2, y2}
        distance = bx2^2 + by2^2
    elseif dz0 < 0 and dz1 >= 0 and dz2 >= 0 then -- -++ edge
        wd = ((ax0 * bx0) + (ay0 * by0) ) / ((ax0 * ax0) + (ay0 * ay0))
        wd = math.max(0, math.min(1, wd))

        rx = x0 + (x1 - x0) * wd
        ry = y0 + (y1 - y0) * wd

        result = {rx, ry}
        distance = (wx-rx)^2 + (wy-ry)^2
    elseif dz0 >= 0 and dz1 < 0 and dz2 >= 0 then -- +-+ edge
        wd = ((ax1 * bx1) + (ay1 * by1) ) / ((ax1 * ax1) + (ay1 * ay1))
        wd = math.max(0, math.min(1, wd))
        rx = x1 + (x2 - x1) * wd
        ry = y1 + (y2 - y1) * wd

        result = {rx, ry}
        distance = (wx-rx)^2 + (wy-ry)^2
    elseif dz0 >= 0 and dz1 >= 0 and dz2 < 0 then -- ++- edge
        wd = ((ax2 * bx2) + (ay2 * by2) ) / ((ax2 * ax2) + (ay2 * ay2))
        wd = math.max(0, math.min(1, wd))
        rx = x2 + (x0 - x2) * wd
        ry = y2 + (y0 - y2) * wd

        result = {rx, ry}
        distance = (wx-rx)^2 + (wy-ry)^2
    end

    return result, distance
end

local function length(v)
    return math.sqrt(v[1]^2 + v[2]^2)
end

local function normalize(v)
    local n = length(v)
    return {v[1] / n, v[2] / n}
end

local function dot(a, b)
    return a[1] * b[1] + a[2] * b[2]
end

local function angle(a, b)
    return math.atan2(b[2] - a[2], b[1] - a[1])
end

local function project(a, b)
    -- local scalar = length(a) * math.cos(angle(a, b))
    -- local normal = normalize(b)
    -- return {scalar * normal[1], scalar * normal[2]}
    local c = normalize(b)
    local d = dot(a, c)
    return {d * c[1], d * c[2]}
end

local tri = {
    {110, 60},
    {280, 280},
    {90, 290}
}

function love.draw()
    love.graphics.polygon("line",
        tri[1][1], tri[1][2],
        tri[2][1], tri[2][2],
        tri[3][1], tri[3][2])

    local mx, my = love.mouse.getPosition()
    local p = point_into_triangle(tri, mx, my)

    love.graphics.circle("line", mx, my, 8)
    love.graphics.circle("fill", p[1], p[2], 3)
    love.graphics.line(mx, my, p[1], p[2])

    -- local ox = love.graphics.getWidth()  / 2
    -- local oy = love.graphics.getHeight() / 2
    --
    -- love.graphics.translate(ox, oy)
    --
    -- local x1, y1 = -300, -200
    -- local x2, y2 =  300,  150
    --
    -- local a = {love.mouse.getX() - ox - x1, love.mouse.getY() - oy - y1}
    -- local b = {x2 - x1, y2 - y1}
    --
    -- -- local a = {200, 100}
    -- local c = project(a, b)
    --
    -- love.graphics.setColor(255, 0, 0)
    -- love.graphics.line(x1, y1, x1 + a[1], y1 + a[2])
    -- love.graphics.setColor(0, 255, 0)
    -- love.graphics.line(x1, y1, x2, y2)
    -- love.graphics.setColor(0, 0, 255)
    -- -- love.graphics.line(0, 0, c[1], c[2])
    -- love.graphics.line(x1 + a[1], y1 + a[2], x1 + c[1], y1 + c[2])
    -- local x, y = x1 + c[1], y1 + c[2]
    --
    -- love.graphics.setColor(255, 255, 255)
    -- love.graphics.print(dot(a, normalize(b)), 8 - ox, 8 - oy)
    -- love.graphics.print(length(b), 8 - ox, 24 - oy)
    -- love.graphics.print(dot(a, normalize(b)) / length(b), x, y - 14)
end
