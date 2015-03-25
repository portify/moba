require "../shared/const"
require "../shared/debug"

require "enet"
mp = require "../lib/msgpack"

require "../shared/entities"

local world = require "../shared/world"

gamestate = require "../shared/hump/gamestate"

states = {
    menu = require "states/menu",
    connecting = require "states/connecting",
    game = require "states/game"
}

function love.load()
    gamestate.registerEvents()
    gamestate.switch(states.menu)
    -- debug_patch()
    --
    -- QUIT_ON_DISCONNECT = arg[2] == "--quit-on-disconnect"
    --
    -- host = enet.host_create(nil, 1, NET_CHANNEL_COUNT,
    --     config.max_down, config.max_up)
    --
    -- server = host:connect(config.server)
    -- remote_world = world:new()
    -- remote_entities = {}
end

-- function love.quit()
--     server:disconnect_now(DISCONNECT.EXITING)
-- end
--
-- function love.update(dt)
--     local event = host:service()
--
--     while event do
--         if event.type == "receive" then
--             local data = mp.unpack(event.data)
--             print("Got packet " .. tostring(EVENT(data.e)))
--
--             if data.e == EVENT.WORLD_REPLACE then
--                 remote_world:unpack(data.data)
--             elseif data.e == EVENT.ENTITY_ADD then
--                 local type = entity_from_id(data.t)
--                 local ent = type:new()
--                 remote_entities[data.i] = ent
--                 ent.__id = data.i
--                 ent:unpack(data.d)
--             elseif data.e == EVENT.ENTITY_REMOVE then
--                 remote_entities[data.i] = nil
--             elseif data.e == EVENT.ENTITY_UPDATE then
--                 remote_entities[data.i]:unpack(data.d)
--             end
--         elseif event.type == "connect" then
--             print("Connected to server")
--             server:send(mp.pack({
--                 name = config.name,
--                 version = PROTOCOL_VERSION
--             }))
--         elseif event.type == "disconnect" then
--             local reason = DISCONNECT(event.data)
--             reason = reason and " (" .. reason .. ")" or ""
--             print("Disconnected from server" .. reason)
--             if QUIT_ON_DISCONNECT then love.event.quit() end
--         end
--
--         event = host:service()
--     end
-- end
--
-- function love.mousepressed(x, y, button)
--     if button == "l" then
--         server:send(mp.pack({
--             e = EVENT.MOVE_TO,
--             x = math.floor(x / 32),
--             y = math.floor(y / 32)
--         }))
--     end
-- end
--
-- function love.draw()
--     remote_world:draw()
--
--     for id, ent in pairs(remote_entities) do
--         ent:draw()
--     end
-- end
