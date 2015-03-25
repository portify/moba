return function(t)
    local enum = {}

    for i, k in ipairs(t) do
        enum[k] = i
    end

    return setmetatable(enum, {
        __call = function(self, i)
            return t[i]
        end
    })
end
