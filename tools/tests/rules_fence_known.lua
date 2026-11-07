-- What's still to move behind the rule set (tools/tests/rules_fence_check.lua). Only ever shrinks.
local M = {}
-- A shared module reaching into the 5e engine directly: "<file> <module>".
M.REQUIRES = {
}
-- Lines with 5e's words in a shared file (not comments).
M.WORDS = {
    ["game/data/barks.lua"] = 13,
    ["game/data/dialogue/lines.json"] = 14,
    ["game/data/dialogue/triggers.json"] = 8,
    ["game/data/killing_blows.lua"] = 1,
    ["game/data/session_zero.lua"] = 1,
    ["game/data/table_behaviors.lua"] = 2,
    ["game/model/barks.lua"] = 1,
    ["game/model/fails.lua"] = 2,
    ["game/model/familiar.lua"] = 1,
    ["game/model/ideas.lua"] = 1,
    ["game/model/jokes.lua"] = 1,
    ["game/model/museum_week.lua"] = 1,
    ["game/model/rng.lua"] = 1,
    ["game/ui/battle_hud.lua"] = 2,
    ["game/ui/levelup_view.lua"] = 1,
    ["game/ui/map_view.lua"] = 1,
    ["game/ui/npc_view.lua"] = 1,
    ["game/ui/sheet_view.lua"] = 2,
}
return M
