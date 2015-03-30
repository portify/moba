-- FIXME: Needs to wrap around at -pi ~ pi!
local angleview = {}

function angleview:is_open(angle)
    for i=1, #self do
        if self[i][1] <= angle and self[i][2] >= angle then
            return false
        end
    end
    
    return true
end

function angleview:block(av, bv)
    local ar, br

    for i=#self, 1, -1 do
        local region = self[i]

        if av >= region[1] and bv <= region[2] then
            return
        end

        if region[1] >= av and region[2] <= bv then
            table.remove(self, i)

            if ar ~= nil then ar = ar - 1 end
            if br ~= nil then br = br - 1 end
        else
            if ar == nil and region[1] <= av and region[2] >= av then
                ar = i
            end

            if br == nil and region[1] <= bv and region[2] >= bv then
                br = i
            end
        end
    end

    if ar == nil and br == nil then
        table.insert(self, {av, bv})
        return
    end

    if ar == nil then
        self[br][1] = av
    elseif br == nil then
        self[ar][2] = bv
    else
        local ac = self[ar][1]
        local bc = self[br][2]

        -- This is probably wrong
        table.remove(self, ar)
        table.remove(self, br)

        table.insert(self, {ac, bc})
    end
end

return function()
    return setmetatable({}, {__index = angleview})
end
