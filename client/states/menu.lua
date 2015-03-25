local menu = {}
local address = "127.0.0.1:6788"

function menu:enter()
    love.graphics.setFont(love.graphics.newFont(16))
    love.graphics.setLineWidth(2)
    love.graphics.setBackgroundColor(60, 70, 70, 255)
end

function menu:draw()
    local text = "Connect to " .. address
    local height = love.graphics.getFont():getHeight(text)
    local x, y = 48, 48

    love.graphics.setColor(255, 200, 127, 255)
    love.graphics.rectangle("line", x - 12 - 3, y + height/2 - 3, 6, 6)
    love.graphics.setColor(255, 255, 255)
    love.graphics.print(text, x, y)
end

function menu:keyreleased(key, code)
    if key == "return" then
        gamestate.switch(states.connecting, address)
    end
end

return menu
