local game = {
    minion_wave_timer = 5
}

function game.spawn_minion_wave_entry(type)
    for name, path in pairs(server.world.paths) do
        local a = entities.minion:new(0, 0, type)
        a.team = 0
        a:begin_a_quest(name)
        add_entity(a)

        local b = entities.minion:new(0, 0, type)
        b.team = 1
        b:begin_a_quest(name)
        add_entity(b)
    end
end

function game.spawn_minion_wave()
    for i=1, 3 do
        delay(i * 0.5, function()
            game.spawn_minion_wave_entry("melee")
        end)
    end

    for i=4, 6 do
        delay(i * 0.5, function()
            game.spawn_minion_wave_entry("caster")
        end)
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
