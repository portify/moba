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

return function(start, goal, path, out)
    local portals = {{left = start, right = start}}

    for i=#path, 2, -1 do
        local a = path[i]
        local b = path[i - 1]

        local portal = a.portal[b]
        assert(portal ~= nil, "cannot find portal?")

        table.insert(portals, portal)
    end

    table.insert(portals, {left = goal, right = goal})
    local points = pull(portals)

    for i=#points, 1, -1 do
        table.insert(out, points[i])
    end
end
