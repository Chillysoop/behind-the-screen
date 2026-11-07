-- The battle HUD for a rule set whose fights are told as story (game/model/story_fight.lua): nothing on the mat, no
-- initiative strip, no hit point bars to keep. Game night calls the same functions it calls on 5e's HUD
-- (game/ui/battle_hud.lua), and each does nothing. Reached through game/ui/sets.lua, by the adventure's set.

local M = {}

local NAMES = { "ally", "area", "condition", "draw", "gone", "initiative", "join", "refresh", "round", "set_hp", "start",
                "stop", "turn", "update", "zone_end" }
for _, name in ipairs(NAMES) do
    M[name] = function() end
end

-- (No zones on the mat to click.)
function M.zone_rects()
    return {}
end

return M
