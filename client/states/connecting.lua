local connecting = {}

function connecting:enter(from, address)
    print("Connecting to " .. address)

    local in_bandwidth = 0
    local out_bandwidth = 0

    self.address = address
    self.host = enet.host_create(nil, 1, CHANNEL_COUNT,
        in_bandwidth, out_bandwidth)

    if self.host == nil then
        error("Cannot create host for client")
    end

    self.server = self.host:connect(address)
    self.status = "Connecting to server"

    love.graphics.setBackgroundColor(60, 70, 70)
    love.graphics.setFont(love.graphics.newFont(28))
end

function connecting:leave()
    self.host = nil
    self.server = nil

    self.status = nil
    self.failed = nil
end

function connecting:update(dt)
    if self.failed then
        return
    end

    local event = self.host:service(0)

    while event do
        if event.type == "receive" then
            local data = mp.unpack(event.data)

            if data.e == EVENT.HELLO then
                gamestate.switch(states.game, self.address, self.host, self.server)
                return
            else
                self.server:disconnect_later(DISCONNECT.INVALID_PACKET)
            end
        elseif event.type == "connect" then
            self.status = "Handshaking"

            self.server:send(mp.pack({
                version = PROTOCOL_VERSION,
                name = config.name
            }))
        elseif event.type == "disconnect" then
            local reason = DISCONNECT(event.data)
            reason = reason and " (" .. reason .. ")" or ""

            self.failed = true
            self.status = "Error:\nConnection failed" .. reason

            break
        end

        event = self.host:service(0)
    end
end

function connecting:draw()
    local sw, sh = love.graphics.getDimensions()

    if self.failed ~= nil then
        love.graphics.setColor(127, 97, 0) -- 127 31 0
    else
        love.graphics.setColor(127, 127, 127)
    end

    love.graphics.printf(self.status, 0, sh / 4, sw, "center")
end

function connecting:keypressed()
    self.server:reset()

    if args.local_loop then
        love.event.quit()
    else
        gamestate.switch(states.menu)
    end
end

return connecting
