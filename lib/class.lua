return {
    new = function(s)
        s.__index = s
        return setmetatable({}, s)
    end
}
