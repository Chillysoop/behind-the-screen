-- The 5e rule set (SRD 5.2.1): what a roll is, who rolls it, what a fight is, for an adventure whose `rules` is "5e"
-- (docs/design/rule-sets.md). The shared game asks a rule set these things and reads the result's tier (great, full,
-- partial, miss, botch); the numbers and the words are the set's own. The rest of the 5e engine is game/rules/:
-- the battle on its grid, the foes' tactics, spells, skills, monsters. Pure Lua, like the rest of game/rules/.

local skills = require "game.rules.skills"
local dice = require "game.kit.dice"      -- (the table's dice, any kind: 5e rolls the d20)

local M = {}

M.id = "5e"
M.title = "D&D 5e (SRD 5.2.1)"      -- (M.name is an approach's name: "Stealth")
M.dice = { notation = "1d20", sides = 20, name = "d20", icon = "d20" }  -- the check's die, from game/kit/dice.lua:
                                                                          -- its name in the captions, its icon in the tray
M.who_rolls = "dm"                         -- the DM rolls, in the open or behind the screen
M.fight = "grid"                           -- fights on the battle grid (game/rules/battle.lua), unless a scene says
                                           -- "story" (game/model/story_fight.lua)
-- A fight told as story: what a hero rolls to get the better of it, their best of these.
M.story_approaches = { "athletics", "acrobatics", "stealth", "arcana", "religion", "intimidation" }
M.approaches = skills.NAMES                -- what a hero can try: the 18 skills, and the six abilities
M.difficulty_word = "DC"

-- 5e's engine, the parts the shared game reaches through game/model/ruleset.lua (`ruleset.part("battle")`), loaded on
-- first use. (Listed with literal requires, so Defold's builder packs each one.)
local PARTS = {
    ai = function() return require "game.rules.ai" end,
    battle = function() return require "game.rules.battle" end,
    creature = function() return require "game.rules.creature" end,
    encounter = function() return require "game.rules.encounter" end,
    hazards = function() return require "game.rules.hazards" end,
    museum = function() return require "game.rules.museum" end,
    party = function() return require "game.rules.party" end,
    rest = function() return require "game.rules.rest" end,
    skills = function() return require "game.rules.skills" end,
    spells = function() return require "game.rules.spells" end,
    subclasses = function() return require "game.rules.subclasses" end,
    ["data.classes"] = function() return require "game.rules.data.classes" end,
    ["data.equipment"] = function() return require "game.rules.data.equipment" end,
    ["data.hazards"] = function() return require "game.rules.data.hazards" end,
    ["data.magic_items"] = function() return require "game.rules.data.magic_items" end,
    ["data.monsters"] = function() return require "game.rules.data.monsters" end,
}
-- 5e's drivers in the shared folder: the grid fight with 5e's rules, the 5e sheet, a fight's danger, the tiles' HP and
-- slots, levels. Each file says `-- rules: 5e` at its top, and the shared game reaches them only through the set too.
-- (Through util.lazy, since each of them asks game/model/ruleset.lua back; game/game.gui_script requires each
-- literally, so the builder packs them.)
local util = require "game.model.util"
for _, name in ipairs({ "fight", "sheet", "matchup", "tile_stats", "progression" }) do
    PARTS[name] = function()
        return util.lazy("game.model." .. name)
    end
end
M.engine = setmetatable({}, {
    __index = function(t, k)
        local load = PARTS[k]
        if load then
            local part = load()
            rawset(t, k, part)
            return part
        end
    end,
})
-- The words the shared game says 5e's things with, so a line reads the same in a 5e adventure and never shows in
-- another set's (each set has its own). {dc}, {name}, {char}, {healed} are filled where they're said.
M.words = {
    dc = "DC",                                   -- the number to beat
    inspiration = "Heroic Inspiration",          -- the reroll token the DM hands a player
    advantage = "Advantage",
    crit = "natural 20", fumble = "natural 1",   -- the die's own best and worst
    extremes = "natural 20 or 1", extremes_both = "a natural 20 or a natural 1",
    hp = "HP", hit_points = "hit points",
    hit_while_down = " A hit on {char} while {char_they're} down counts as a failed death save.",
    short_rest = "a short rest", long_rest = "a long rest",
    rest_short_label = "They take a short rest while we eat.",
    rest_short_sub = "An hour in the game: Hit Dice, Second Wind, Channel Divinity, Arcane Recovery.",
    rest_long_label = "They take a long rest here.",
    spot_first = "A Perception roll. Miss it, and it goes off.",
    find_check = "Investigation check",
    -- (The player tiles' hovers: the hero's numbers in 5e's terms, and the token you hand out.)
    tile_hp = { "Hit points", "How much more of a beating {char} can take. At 0 they drop, and start making death saves." },
    tile_ac = { "Armor Class (AC)", "How hard {char} is to hit: an attack has to roll this or more." },
    tile_sneak = { "Sneak Attack", "Extra damage once a turn when the rogue has Advantage or an ally next to the target. It never runs out." },
    roll_hover = "The die, what it was for, and the total against what it needed: AC is how hard the target is to hit, "
        .. "DC the number a check or a save has to reach. Green: it worked. Red: it didn't. Gold: a natural 20.",
    cover_legend = "Cover: +2 to AC, +5 at 3/4",
    npc_fight = "In a fight: {hp} Hit Points, Armor Class {ac}",
    -- (The board's light, over the whole map.)
    light = {
        bright = "Daylight, or a well-lit room. Everyone sees.",
        dim = "Dusk, firelight, a gloomy hall: Lightly Obscured (Disadvantage on Perception by sight).",
        dark = "Night outside, an unlit cellar: Heavily Obscured. Only Darkvision, torches and fires see.",
    },
    -- (The recap's lines for a roll's best and worst, a die sent to jail, a token spent.)
    recap = {
        crit = { "{char} rolled a natural 20 and the table lost its mind.", "A natural 20 from {char}, right when it counted.",
                 "{who}'s die came up 20. Nobody has stopped talking about it.", "{char} landed the roll of the night.",
                 "The 20 that {char} rolled will be in the group chat for weeks." },
        fumble = { "{char} rolled a 1. Of course {char} did.", "A natural 1 for {char}, at the worst moment.",
                   "{who}'s die betrayed {who_them}: a 1.", "{char} found out what a 1 looks like up close." },
        jail = { "{who}'s d20 went to dice jail.", "One d20 is serving time tonight: {who}'s.", "{who} jailed a die. It had it coming.",
                 "Dice jail claimed {who}'s d20." },
        inspiration = { "{text}", "{text}", "Heroic Inspiration changed hands." },
    },
    -- (The DM's own read of a friend is called for the skill it's most like: "an Insight roll".)
    read = "an Insight roll", read_button = "roll Insight", read_crit = "a natural 20 always reads",
    hidden_death_save = "a death save made behind the screen",
    rest_hour = "An hour's rest: Hit Dice spent, {healed} HP back across the party.",
    rest_none = "An hour's rest. Nobody had Hit Dice left to spend, but the features are back.",
    own_dc = { "\"DC {dc}, {actor_char}.\"", "\"You need a {dc}.\"", "\"That's a DC {dc}. Go on.\"" },
    inspire_lines = {
        "You flick the Heroic Inspiration token across the table. It lands in front of {name}: one reroll, to spend whenever {char} needs it.",
        "The Heroic Inspiration token skids across the table and stops in front of {name}: one reroll, whenever {char} needs it.",
        "You slide the Heroic Inspiration token over to {name}. One reroll, for whenever {char} needs it.",
    },
}
-- What a player looks up in the rules, by a word on the card (a rules question that names one fits it).
M.rule_terms = { "concentrat", "opportunity attack", "cover", "saving throw", "two attacks", "bonus action", "advantage",
                 "stack", "flank", "grappl", "modifier" }
-- What a number to beat means, in words, when the DM sets their own (the DC card).
M.difficulty_names = { { 5, "Very easy" }, { 10, "Easy" }, { 15, "Medium" }, { 20, "Hard" }, { 25, "Very hard" }, { 30, "Nearly impossible" } }
-- What a piece on the board does, in a line of 5e's rules (SRD 5.2.1): game/model/maps.lua's rules_text.
local function int(x)
    return string.format("%d", math.floor(x + 0.5))
end
function M.piece_rules(k)
    local out = {}
    if k.door then
        table.insert(out, k.door == "open" and "An open door: walk through. Shut it again as you pass."
            or k.door == "locked" and "Locked: DC 15 to pick (Thieves' Tools) or DC 20 Strength to force. Wood, AC 15, 18 HP."
            or "Opens as someone walks through (a free interaction). Shut, it blocks sight. Wood, AC 15, 18 HP.")
    elseif k.opaque then
        table.insert(out, "Total Cover: blocks sight and movement.")
    elseif k.deg == "three_quarters" then
        table.insert(out, "Three-Quarters Cover: +5 AC and Dex saves behind it.")
    elseif k.deg == "half" then
        table.insert(out, "Half Cover: +2 AC and Dex saves behind it.")
    elseif k.blocks then
        table.insert(out, "Blocks movement.")
    end
    if k.slippery then
        table.insert(out, "Slippery: Difficult Terrain, and a DC 10 Dex save or Prone.")
    elseif k.rough then
        table.insert(out, "Difficult Terrain: every foot costs 2.")
    end
    if k.bright then
        table.insert(out, "Bright Light " .. int(k.bright) .. " ft, Dim " .. int(k.dim or 0) .. " ft more.")
    end
    return table.concat(out, " ")
end
-- A scene's final roll, by how hard the scene is (easy, middling, hard).
M.scene_dc = { 10, 12, 14 }

-- 5e's own words: no other set's adventure may show one, and the shared game only says them through this set
-- (tools/tests/rules_fence_check.lua). Dice and grids aren't here: they're the table's (game/kit/), any set's to use.
M.owns = {
    "%f[%w]DCs?%f[%W]", "%f[%w]Advantage%f[%W]", "%f[%w]Disadvantage%f[%W]", "natural 20", "natural 1%f[%D]",
    "spell slot", "hit points", "Hit Dice", "%f[%w]HP%f[%W]", "%f[%w]AC%f[%W]", "Armor Class", "saving throw", "death save",
    "Heroic Inspiration", "Proficiency", "cantrip", "short rest", "long rest", "%f[%w]Insight%f[%W]", "%f[%w]Arcana%f[%W]",
    "%f[%w]Perception%f[%W]", "%f[%w]Investigation%f[%W]", "%f[%w]Persuasion%f[%W]", "%f[%w]Stealth%f[%W]",
    "%f[%w]Athletics%f[%W]", "%f[%w]Concentration%f[%W]", "Cure Wounds", "Healing Word", "Detect Magic",
}

-- A hero's bonus for an approach: ability modifier and Proficiency Bonus (twice it with Expertise).
function M.mod(class, approach, level, subclass)
    return skills.mod(class, approach, level, subclass)
end
function M.name(approach)
    return skills.name(approach)
end
function M.signed(n)
    return skills.signed(n)
end

local D20, ADVANTAGE = dice.parse("1d20"), dice.parse("2d20kh1")

-- One die of the set's, off `rng` (game/model/rng.lua, or game/rules/dice.lua's forced faces).
function M.die(rng)
    return dice.roll(rng, D20).total
end

-- The die: one d20, or two and the better with Advantage ("adv"). The order the dice come off `rng` is part of the
-- result: a seeded playthrough is the same playthrough.
function M.roll(rng, edge)
    if edge == "adv" then
        local g = dice.roll(rng, ADVANTAGE).groups[1]
        local keep = g.kept[1] and 1 or 2
        return g.faces[keep], g.faces[3 - keep]
    end
    return M.die(rng), nil
end

-- How it came out, in the tiers the shared game reads (the DM's rulings, game/data/rulings.lua): triumph, success,
-- near, flop. A natural 20 or beating the DC by 5 is a triumph; a natural 1 or missing by 5 is a flop; a miss by
-- less is near, where a "yes, but" lives. (The DM's big rolls, game/model/night.lua's roll card.)
function M.tier(total, dc, natural)
    if natural == 20 or total >= dc + 5 then
        return "triumph"
    elseif total >= dc then
        return "success"
    elseif natural == 1 or total <= dc - 5 then
        return "flop"
    end
    return "near"
end

-- What a DC means for this roller, in words a newcomer can weigh: the number they need on the d20 and how often that
-- comes up. (A natural 20 always makes it: M.tier.)
function M.odds_line(dc, mod)
    local need = dc - (mod or 0)
    if need <= 2 then
        return "They make it on almost any roll."
    elseif need >= 20 then
        return "Only a natural 20 makes it (1 in 20)."
    end
    local chance = (21 - need) / 20
    -- (40% isn't "a coin flip": the card-led playtest, October 16.)
    local word = (chance >= 0.85 and "very likely") or (chance >= 0.6 and "likely") or (chance >= 0.45 and "a coin flip")
        or (chance >= 0.3 and "less likely than not") or (chance >= 0.15 and "unlikely") or "a long shot"
    return "They need " .. string.format("%d", math.floor(need + 0.5)) .. " or more on the d20: about "
        .. string.format("%d", math.floor(math.floor(chance * 100 + 0.5) + 0.5)) .. "%, " .. word .. "."
end

-- A check, whole: the die, the bonus, the tier, and the line for the log ("Pip: Stealth 14+7 = 21 vs DC 15,
-- success"). `extra` is anything already added to the bonus (a lesson learned, research), so the line says it all.
function M.check(rng, opts)
    local roll, other = M.roll(rng, opts.edge)
    local mod = opts.mod or 0
    local total = roll + mod
    return { roll = roll, other = other, mod = mod, total = total, dc = opts.dc, success = total >= opts.dc,
             tier = M.tier(total, opts.dc, roll), crit = roll == 20, fumble = roll == 1 }
end

-- The result's word for the log: "natural 20" and "natural 1" whatever the total, as the table says them.
function M.result_word(r)
    if r.roll == 20 then
        return "natural 20"
    elseif r.roll == 1 then
        return "natural 1"
    end
    return r.success and "success" or "miss"
end
local function int(x)
    return string.format("%d", math.floor(x + 0.5))
end
function M.line(who, approach, r)
    return who .. ": " .. M.name(approach) .. " " .. int(r.roll) .. M.signed(r.mod) .. " = " .. int(r.total)
        .. " vs DC " .. int(r.dc) .. ", " .. M.result_word(r)
end

return M
