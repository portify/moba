local templates = {
    {"Spawn (team 1)", function (x, y)
        local ent = entities.ent_by_name("spawn"):new(x, y)
        ent.team = 0
        return ent
    end},
    {"Spawn (team 2)", function (x, y)
        local ent = entities.ent_by_name("spawn"):new(x, y)
        ent.team = 1
        return ent
    end},
    {"Tower (team 1)", function (x, y)
        local ent = entities.ent_by_name("tower"):new(x, y)
        ent.team = 0
        return ent
    end},
    {"Tower (team 2)", function (x, y)
        local ent = entities.ent_by_name("tower"):new(x, y)
        ent.team = 1
        return ent
    end}
}

local window = loveframes.Create("frame")
window:SetName("Entity Toolbox")
window:SetIcon("assets/icons/bricks.png")
window:SetScreenLocked(1)
window:SetDockable(true)
window:SetSize(200, 300)
window:SetPos(love.graphics.getWidth() - window:GetWidth(), menubar:GetHeight())

local list = loveframes.Create("list", window)
list:SetPos(1 + 6, 25 + 6)
list:SetSize(window:GetWidth() - 2 - 12, window:GetHeight() - 26 - 12)

local y = 0
for i, template in ipairs(templates) do
    local button = loveframes.Create("button", list)
    -- button:SetPos(0, y)
    button:SetText(template[1])
    y = y + button:GetHeight()
    function button:OnClick()
        local x, y = translate_mouse(love.mouse.getPosition())
        local ent = template[2](x, y)
        table.insert(map.entities, ent)
        target = {type = "ent", ent = ent, move_x = 0, move_y = 0}
        selection = {}
        mode = "move-ent"
    end
end

function window:OnClose()
    window:SetVisible(false)
    return false
end

return window
