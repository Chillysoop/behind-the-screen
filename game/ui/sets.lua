-- The screens a rule set brings of its own (docs/design/rule-sets.md): 5e's grid fight told step by step on the board.
-- The shared screens reach them only through here, by the adventure's set (game/model/ruleset.lua), the way the
-- shared game reaches a set's engine through ruleset.part; another set's adventure gets an error, never 5e's.
--     require("game.ui.sets").part("fight_steps").play_step(app, s, pace)

local ruleset = require "game.model.ruleset"

local M = {}

-- (Listed with literal requires, so the builder packs each one.)
M.SCREENS = {
    ["5e"] = {
        fight_steps = function() return require "game.ui.fight_steps_5e" end,
        battle_hud = function() return require "game.ui.battle_hud" end,
        levelup_view = function() return require "game.ui.levelup_view" end,
        sheet_view = function() return require "game.ui.sheet_view" end,
    },
}

function M.part(name)
    local set = ruleset.current()
    local screens = M.SCREENS[set.id]
    local load = screens and screens[name]
    if not load then
        error(tostring(set.title or set.id) .. " has no " .. tostring(name) .. " screen (docs/design/rule-sets.md: no leaks)", 2)
    end
    return load()
end

-- The same, as a stand-in a screen can hold from load time (`local battle_hud = sets.screen("battle_hud")`): every
-- field read goes to the current set's screen at that moment.
function M.screen(name)
    return setmetatable({}, {
        __index = function(_, k)
            return M.part(name)[k]
        end,
    })
end

return M
