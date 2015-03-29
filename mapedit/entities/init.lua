local ent_by_name_table = {}
local name_by_ent_table = {}

love.filesystem.getDirectoryItems("mapedit/entities", function (item)
    if item ~= "init.lua" and item:sub(-4) == ".lua" and love.filesystem.isFile("mapedit/entities/" .. item) then
        local name = item:sub(0, -5)
        local ent = require("mapedit.entities." .. name)

        ent_by_name_table[name] = ent
        name_by_ent_table[ent] = name

        print("Registering entity type " .. name)
    end
end)

return {
    ent_by_name = function(name)
        return ent_by_name_table[name]
    end,
    name_by_ent = function(ent)
        return name_by_ent_table[ent]
    end
}
