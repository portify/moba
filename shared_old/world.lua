local world = {}
world.__index = world

function world:new()
    local new = setmetatable({}, self)

    new.width = 0
    new.height = 0
    new.data = {}

    if not is_client then
        -- extreme cheating
        new.width = 2
        new.height = 2

        new.data = {
            {50, 255},
            {127, 200}
        }
    end

    return new
end

function world:pack()
    return {self.width, self.height, self.data}
end

function world:unpack(t)
    self.width = t[1]
    self.height = t[2]
    self.data = t[3]
end

function world:update(dt)
end

function world:draw()
    for x=1, self.width do
        for y=1, self.height do
            love.graphics.setColor(self.data[x][y], 0, 0)
            love.graphics.rectangle("fill", x*32, y*32, 32, 32)
        end
    end
end

return world
