local connect_to_ip = {}
local entered

function connect_to_ip:enter()
    entered = ""

    love.graphics.setBackgroundColor(60, 70, 70)
    love.graphics.setFont(love.graphics.newFont(28))
end

function connect_to_ip:draw()
    local w, h = love.graphics.getDimensions()

    love.graphics.setColor(255, 255, 255)
    love.graphics.printf(entered .. "|", 0, h / 3, w, "center")

    love.graphics.setColor(255, 255, 255, 150)
    love.graphics.printf("Enter to connect, Escape to cancel", 0, h / 3 * 2, w, "center")
end

function connect_to_ip:keypressed(key, unicode)
    if love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl") then
        if key == "v" then
            entered = entered .. love.system.getClipboardText()
        end
    else
        if key == "escape" then
            gamestate.switch(states.menu)
        elseif key == "return" then
            if not entered:find(":", 1, true) then
                entered = entered .. ":6788"
            end
            
            gamestate.switch(states.connecting, entered)
        elseif key == "backspace" then
            entered = entered:sub(0, -2) -- no idea if thats right
        elseif key == "delete" then
            entered = "" -- because im lazy
        end
    end
end

function connect_to_ip:textinput(text)
    entered = entered .. text
end

return connect_to_ip
