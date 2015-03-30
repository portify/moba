local game = {
    minion_wave_timer = 2.5
}

function game.spawn_minion_wave_entry()
    for name, path in pairs(server.world.paths) do
        -- print("spawning minions onto path " .. name)

        local a = entities.minion:new(0, 0)
        a.team = 0
        a:begin_a_quest(name)
        add_entity(a)

        local b = entities.minion:new(0, 0)
        b.team = 1
        b:begin_a_quest(name)
        add_entity(b)
    end
end

function game.spawn_minion_wave()
    for i=1, 5 do
        delay(i * 0.5, game.spawn_minion_wave_entry)
    end
end

function game.update(dt)
    if game.minion_wave_timer > 0 then
        game.minion_wave_timer = game.minion_wave_timer - dt
    end

    if game.minion_wave_timer <= 0 then
        game.spawn_minion_wave()
        game.minion_wave_timer = game.minion_wave_timer + 20
    end
end

return game
