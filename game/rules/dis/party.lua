-- Death in Space's party: a hero's sheet is the adventure's own (its `heroes`, each with `sheet` = abilities, hit
-- points and defense rating, made by the book's steps, pp. 12-23), not a class table. The shared game asks this through
-- game/model/ruleset.lua's "party" part. Pure Lua.

local M = {}

local function heroes()
    local adv = package.loaded["game.model.adventure"]
    return adv and adv.data and adv.data.heroes or {}
end

-- The sheet for a hero, by their class (the adventure gives each hero a class word of their own) or player key.
function M.sheet(class, _level)
    for key, h in pairs(heroes()) do
        if h.class == class or key == class then
            local s = h.sheet or {}
            return { class = h.class, name = h.char, hp = s.hp, max_hp = s.hp, ac = s.dr, dr = s.dr, potions = 0,
                     abilities = { bdy = s.bdy, dex = s.dex, svy = s.svy, tec = s.tec }, kit = h.kit, trinket = h.trinket,
                     origin = h.origin, background = h.background, trait = h.trait, drive = h.drive }
        end
    end
    return nil
end

return M
