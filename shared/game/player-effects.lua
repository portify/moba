entities.projectile:register_type("player-basic", function(self)
    -- local image = love.graphics.newImage("assets/arrow.png")
    local image = get_resource(love.graphics.newImage, "assets/arrow.png")
    local system = love.graphics.newParticleSystem(image, 60)

    system:setParticleLifetime(0.4, 0.4)
    system:setEmissionRate(50)
    system:setRelativeRotation(true)
    system:setSizes(0.3, 0.2, 0.1)
    --system:setLinearAcceleration(-60, -60, 60, 60)
    --system:setTangentialAcceleration(-256, 256)
    system:setSpeed(5,5)
    system:setColors(
        100, 255, 120, 255,
        100, 255, 120, 128,
        100, 255, 120, 64,
        100, 255, 120, 0)

    return system
end)
