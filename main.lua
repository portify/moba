require "enet"
mp = require "../lib/msgpack"

require "shared/constants"
require "shared/debug"

if args.server then
    require "server"
else
    require "client"
end

-- local address = "127.0.0.1:50000"
--
-- function love.load()
--     server_host = enet.host_create(address, 64, 0, 0, 0)
--
--     client_host = enet.host_create(nil, 1, 0, 0, 0)
--     client_peer = client_host:connect(address)
-- end
--
-- function love.update(dt)
--     -- server
--     local event = server_host:service(0)
--
--     while event do
--         print("server", event.type, event.peer, event.data)
--         event = server_host:service(0)
--     end
--
--     -- client
--     local event = client_host:service(0)
--
--     while event do
--         print("client", event.type, type(event.peer), event.data)
--         event = client_host:service(0)
--     end
-- end
