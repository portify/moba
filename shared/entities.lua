entity = require "shared/entities/entity"

entities = {
    projectile = require "shared/entities/projectile" -- load this first because reasons
}

entities.player = require "shared/entities/player"
entities.minion = require "shared/entities/minion"
entities.spawn = require "shared/entities/spawn" -- This shouldn't be here!
entities.tower = require "shared/entities/tower" -- TODO: separate list for mapents

-- this could be in a better place
require "shared.game.player-effects"

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
