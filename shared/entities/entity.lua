local entity = {}
entity.__index = entity

function entity:added()
end

function entity:removed()
end

function entity:pack()
    return false
end

function entity:unpack(t)
    assert(t == false, "invalid unpack")
end

function entity:update(dt)
end

function entity:draw()
end

function entity:get_world_instance()
    if is_client then
        return states.game.world
    else
        return server.world
    end
end

-- function entity:get_type_id()
--     return id_from_entity(getmetatable(self))
-- end

return entity
