entity = require "shared/entities/entity"

entities = {
    player = require "shared/entities/player",
    projectile = require "shared/entities/projectile",
    minion = require "shared/entities/minion"
}

local e_table = {}
local i_table = {}

local i = 0

for n, e in pairs(entities) do
    e_table[i] = e
    i_table[e] = i
    i = i + 1
end

function entity_from_id(i)
    return e_table[i]
end

function id_from_entity(e)
    return i_table[e]
end

function get_entity_type_name(ent)
    local meta = getmetatable(ent)
    for name, impl in pairs(entities) do
        if impl == meta then
            return name
        end
    end
    return "<unknown>"
end
