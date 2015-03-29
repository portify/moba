-- Parse command-line arguments
args = {
    ["mapedit"] = {},
    ["server"] = {},
    ["listen"] = {n = 1},
    ["map"] = {n = 1},
    ["quit-on-empty"] = {},
    ["connect"] = {n = 1}
}

do
    local i = 1
    local loving = true

    while i <= #arg do
        local s, e, m = string.find(arg[i], "%-%-(.+)")

        if loving then
            if m == "console" or m == "fused" then
            elseif m == "game" then
                i = i + 1
            else
                loving = false
            end
        elseif args[m] ~= nil then
            args[m].set = true

            if args[m].n ~= nil then
                for j=1, args[m].n do
                    args[m][j] = arg[i + j]
                end

                i = i + args[m].n
            end
        else
            --
        end

        i = i + 1
    end
end

-- Figure out our context and setup config
local serialize = require "lib/ser"
local context

if args.mapedit.set then
    context = "mapedit"
    config = {
        enable_fps_warning = true,
        ui_skin = "Blue"
    }
elseif args.server.set then
    context = "server"

    config = {
        public = true,
        port = 6788,
        peer_count = 64,
        bandwidth_in = 0,
        bandwidth_out = 0,
        startup_map = "default"
    }
else
    context = "client"
    is_client = true

    config = {
        window = {
            width = 1280,
            height = 720,
            fullscreen = false,
            vsync = true,
            fsaa = 0
        },
        name = "Player",
        default_server = "127.0.0.1:6788"
    }
end

local config_file = "config-" .. context .. ".lua"

if love.filesystem.isFile(config_file) then
    -- FIXME: This doesn't handle recursive structures!
    local function patch(t, target)
        for key, value in pairs(t) do
            if type(value) == "table" and type(target[key]) == "table" then
                patch(value, target[key])
            else
                target[key] = value
            end
        end
    end

    local user = love.filesystem.load(config_file)()
    patch(user, config)
end

love.filesystem.write(config_file, serialize(config))

if not args.server.set then
    require "lib/cupid"
end

function love.conf(t)
    t.identity = "moba"
    t.version = "0.9.2"
    t.console = (not not args.server.set) or args.mapedit.set

    if args.mapedit.set then
        t.window.title = "mapedit"
        t.window.width = 1280
        t.window.height = 720
        t.window.resizable = true
        t.window.minwidth = 640
        t.window.minheight = 480
        -- t.window.vsync = false
    elseif args.server.set then
        t.window = nil

        t.modules.audio    = false
        t.modules.font     = false
        t.modules.graphics = false
        t.modules.image    = false
        t.modules.joystick = false
        t.modules.keyboard = false
        t.modules.mouse    = false
        t.modules.physics  = false
        t.modules.sound    = false
        t.modules.window   = false
    else
        t.window.title = "moba"
        t.window.width = config.window.width
        t.window.height = config.window.height
        t.window.fullscreen = config.window.fullscreen
        t.window.fullscreentype = "desktop"
        t.window.vsync = config.window.vsync
        t.window.fsaa = config.window.fsaa
    end
end
