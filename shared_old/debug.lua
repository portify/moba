if USE_LOVEBIRD then
    lovebird = require "../lib/lovebird"
    lovebird.port = is_client and 8001 or 8000
    lovebird.update()
end

if USE_LOGFILE then
    local logfile = assert(love.filesystem.newFile("out.log", "w"))
    local logdirt = false
    local logtime = 0

    local print_func = print
    function print(...)
        print_func(...)
        local args = {...}
        for i, value in ipairs(args) do
            args[i] = tostring(value)
        end
        logfile:write(table.concat(args, "    ") .. "\r\n")
        logdirt = true
    end

    function logtick(dt)
        if logdirt then
            logtime = logtime + dt
            if logtime >= 1 then
                logtime = logtime - 1
                logdirt = false
                logfile:flush()
            end
        end
    end
end

function debug_patch()
    local quit = love.quit
    function love.quit()
        quit()
        if USE_LOVEBIRD then lovebird.update() end
        if USE_LOGFILE  then logtick(1)        end
    end

    local update = love.update
    function love.update(dt)
        if USE_LOVEBIRD then lovebird.update() end
        if USE_LOGFILE  then logtick(dt)       end
        update(dt)
    end
end
