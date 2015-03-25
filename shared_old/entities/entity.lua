local entity = {}
entity.__index = entity

function entity:pack()
    return nil
end

function entity:unpack(t)
    assert(t == nil, "invalid unpack")
end

function entity:update(dt)
end

function entity:draw()
end

function entity:get_type_id()
    return id_from_entity(getmetatable(self))
end

return entity
