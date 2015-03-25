local connecting = {}

function connecting:enter(from, address)
    local in_bandwidth = 0
    local out_bandwidth = 0

    self.host = enet.host_create(nil, 1, CHANNEL_COUNT,
        in_bandwidth, out_bandwidth)

    if self.host == nil then
        error("Cannot create host for client")
    end

    self.server = self.host:connect(address)
    self.status = "Connecting to server"

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
                gamestate.switch(states.game, self.host, self.server)
                return
            else
                self.server:disconnect_later(DISCONNECT.INVALID_PACKET)
            end
        elseif event.type == "connect" then
            self.status = "Handshaking"

            self.server:send(mp.pack({
                version = PROTOCOL_VERSION
            }))
        elseif event.type == "disconnect" then
            local reason = DISCONNECT(event.data)
            reason = reason and " (" .. reason .. ")" or ""

            if QUIT_ON_DISCONNECT then
                love.event.quit()
            end

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
        love.graphics.setColor(127, 31, 0, 255)
    else
        love.graphics.setColor(127, 127, 127, 255)
    end

    love.graphics.printf(self.status, 0, sh / 4, sw, "center")
end

return connecting
