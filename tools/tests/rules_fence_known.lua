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
    ["game/model/maps.lua"] = 6,
    ["game/model/museum_night.lua"] = 16,
    ["game/model/museum_week.lua"] = 1,
    ["game/model/night.lua"] = 40,
    ["game/model/recap.lua"] = 5,
    ["game/model/rng.lua"] = 1,
    ["game/model/table_life.lua"] = 5,
    ["game/model/takeover.lua"] = 5,
    ["game/ui/battle_hud.lua"] = 2,
    ["game/ui/levelup_view.lua"] = 1,
    ["game/ui/map_view.lua"] = 1,
    ["game/ui/night_view.lua"] = 52,
    ["game/ui/npc_view.lua"] = 1,
    ["game/ui/panels.lua"] = 12,
    ["game/ui/sheet_view.lua"] = 2,
}
return M
