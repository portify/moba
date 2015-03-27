if args.mapedit then
    require "mapedit"
    return
end

require "enet"
mp = require "../lib/msgpack"

require "shared/constants"
require "shared/debug"

if args.server then
    require "server"
else
    require "client"
end
