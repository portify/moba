-- Parse command-line arguments
args = {}

do
    local i = 2

    if arg[1] == "--console" then
        i = i + 1
    end

    while i <= #arg do
        args[arg[i]] = true
        i = i + 1
    end
end

function love.conf(t)
    t.identity = "moba"
    t.version = "0.9.2"
    -- t.console = not not args.server
    t.console = true

    if args.mapedit then
        t.window.width = 1280
        t.window.height = 720
        t.window.resizable = true
        t.window.minwidth = 640
        t.window.minheight = 480
    else
        t.window = nil
    end

    if not args.mapedit and args.server then
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
    end
end
