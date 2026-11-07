-- Death in Space's numbers on a hero's tile: hit points and defense rating from the adventure's sheet (pp. 12-23), and
-- one row of pips for the void points they hold (four at most, p. 38). A fight told as story keeps no hit points
-- between scenes, so the tile shows them whole. The shared game asks this through game/model/ruleset.lua's
-- "tile_stats" part. Pure Lua.

local M = {}

-- What each row is, for the tile's hover card.
M.TIPS = { void = "Void points: every missed check gives one, four at most. Spend one to roll twice and keep the better, "
    .. "but if that still misses, the void may leave a mark." }

-- { hp, hp_max, ac, class, res = { { id, label, cur, max } } } (the shape the tile draws: game/ui/panels.lua)
function M.of(campaign, _night, key)
    local p = campaign:player(key)
    local adv = package.loaded["game.model.adventure"]
    local h = adv and adv.data and adv.data.heroes and adv.data.heroes[key]
    if not (p and h and h.sheet) then
        return nil
    end
    local void = (campaign.void or {})[key] or 0
    return { hp = h.sheet.hp, hp_max = h.sheet.hp, ac = h.sheet.dr, class = p.class,
             res = { { id = "void", label = "Void", cur = void, max = 4, now_word = "Held now" } } }
end

return M
