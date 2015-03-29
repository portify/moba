local util = require "shared.util"

local spawn = {}
spawn.__index = spawn
setmetatable(spawn, entity)

function spawn:new()
    return setmetatable({
        team = false,
        x = 0,
        y = 0
    }, self)
end

function spawn:from_map(line)
    local team, x, y = line:match("([01]) (.+) (.+)")
    local new = self:new()

    new.team = tonumber(team)
    new.x = tonumber(x)
    new.y = tonumber(y)

    return new
end

function spawn:hook_add()
    if server.spawns[self.team] == nil then
        server.spawns[self.team] = {self}
    else
        table.insert(server.spawns[self.team], self)
    end
end

return spawn
