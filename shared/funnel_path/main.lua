local world
local path, portals, spoints

local cx = -750
local cy = -1000
local cs = 1

local function triarea2(a, b, c)
    local ax = b[1] - a[1]
    local ay = b[2] - a[2]
    local bx = c[1] - a[1]
    local by = c[2] - a[2]
    return bx*ay - ax*by
end

local function vequal(a, b)
    return math.abs(b[1] - a[1]) < 0.001 and math.abs(b[2] - a[2]) < 0.001
end

local function pull(portals)
    local portalApex  = portals[1].left
    local portalLeft  = portals[1].left
    local portalRight = portals[1].right

    local apexIndex  = 1
    local leftIndex  = 1
    local rightIndex = 1

    local points = {portalApex}

    for i=2, #portals do
        local did_continue = false

        local left  = portals[i].left
        local right = portals[i].right

        -- Update right vertex.
        if triarea2(portalApex, portalRight, right) <= 0.0 then
            if vequal(portalApex, portalRight) or triarea2(portalApex, portalLeft, right) > 0.0 then
                -- Tighten the funnel.
                portalRight = right
                rightIndex = i
            else
                -- Right over left, insert left to path and restart scan from portal left point.
                table.insert(points, portalLeft)
                -- Make current left the new apex.
                portalApex = portalLeft
                apexIndex = leftIndex
                -- Reset portal
                portalLeft = portalApex
                portalRight = portalApex
                leftIndex = apexIndex
                rightIndex = apexIndex
                -- Restart scan
                --i = apexIndex -- dunno if this needs - 1
                i = apexIndex - 1
                -- continue
                did_continue = true
            end
        end

        -- Update left vertex.
        if not did_continue and triarea2(portalApex, portalLeft, left) >= 0.0 then
            if vequal(portalApex, portalLeft) or triarea2(portalApex, portalRight, left) < 0.0 then
                -- Tighten the funnel.
                portalLeft = left
                leftIndex = i
            else
                -- Left over right, insert right to path and restart scan from portal right point.
                table.insert(points, portalRight)
                -- Make current right the new apex.
                portalApex = portalRight
                apexIndex = rightIndex
                -- Reset portal
                portalLeft = portalApex
                portalRight = portalApex
                leftIndex = apexIndex
                rightIndex = apexIndex
                -- Restart scan
                --i = apexIndex -- dunno if this needs - 1
                i = apexIndex - 1
                -- continue
            end
        end
    end

    table.insert(points, portals[#portals].left)
    return points
end

function love.load()
    world = require("world"):new("map.txt")
end

function love.mousemoved(x, y, dx, dy)
    x = x / cs - cx
    y = y / cs - cy

    local x1, y1 = world.mesh[1]:center()
    local x2, y2 = x, y

    local target = world:get_plane(x, y)
    portals = nil
    spoints = nil

    if target ~= nil then
        path = world.mesh[1]:find_path(target)
    else
        path = nil
    end

    if path ~= nil then
        portals = {
            {left = {x1, y1}, right = {x1, y1}}
        }

        -- for i, each in ipairs(path) do
        for i=#path, 1, -1 do
            local each = path[i]
            table.insert(portals, {left = each[2][1], right = each[2][2]})
        end

        table.insert(portals, {left = {x2, y2}, right = {x2, y2}})
        spoints = pull(portals)
    end
end

function love.draw()
    love.graphics.setBackgroundColor(255, 255, 255)

    love.graphics.scale(cs)
    love.graphics.translate(cx, cy)
    world:draw()

    love.graphics.setColor(0, 255, 0, 127)
    world.mesh[1]:draw("fill")

    if path ~= nil then
        love.graphics.setColor(255, 0, 0)
        love.graphics.setLineWidth(2)

        for i=1, #path-1 do
            local a = {path[i  ][1]:center()}
            local b = {path[i+1][1]:center()}
            love.graphics.line(a[1], a[2], b[1], b[2])
        end
    end

    if portals ~= nil then
        love.graphics.setLineWidth(2)

        for i, portal in ipairs(portals) do
            love.graphics.setColor(200, 200, 0, 200)
            love.graphics.line(portal.left[1], portal.left[2], portal.right[1], portal.right[2])
            love.graphics.setColor(50, 50, 0)
            if (i-1) % 2 == 0 then
                love.graphics.print(i, portal.left[1], portal.left[2])
            else
                love.graphics.print(i, portal.right[1], portal.right[2])
            end
        end
    end

    if spoints ~= nil then
        love.graphics.setLineWidth(2)
        love.graphics.setPointSize(6)
        love.graphics.setColor(0, 0, 0)

        for i=1, #spoints-1 do
            love.graphics.line(spoints[i][1], spoints[i][2], spoints[i+1][1], spoints[i+1][2])
        end

        for i=1, #spoints do
            love.graphics.print(tostring(i), spoints[i][1], spoints[i][2])
            -- love.graphics.point(spoints[i][1], spoints[i][2])
        end

        -- local p = {}
        --
        -- for i, each in ipairs(spoints) do
        --     table.insert(p, each[1])
        --     table.insert(p, each[2])
        -- end
        --
        -- love.graphics.line(p)
    end
end
