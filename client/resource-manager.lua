local cache = {}

function get_resource(source, ...)
    if cache[source] == nil then
        cache[source] = setmetatable({}, {__mode = "v"})
    end

    local args = {...}

    if cache[source][args] == nil then
        print("Loading resource (" .. select("1", ...) .. ")")
        cache[source][args] = source(...)
    end

    return cache[source][args]
end
