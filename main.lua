if args.mapedit.set then
    require "mapedit"
    return
end

require "enet"
mp = require "lib.msgpack"

require "shared.constants"
require "shared.debug"

-- print(require("lib.ser")(args))

if args.server.set then
    require "server"
else
    require "client"
end
