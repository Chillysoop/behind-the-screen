-- The Death in Space rule set (Death in Space core rules by Christian Plogfors and Carl Niblaeus, Free League, 2021;
-- pages are the reader's own PDF's printed numbers): what a roll is, who rolls it, what a fight is, for an adventure
-- whose `rules` is "dis" (docs/design/rule-sets.md). Our words, never the book's.
--
-- A check is a d20 plus one of four abilities, Body, Dexterity, Savvy and Tech (from -3 to +3), and 12 or more works
-- (p. 36). A miss always costs something, and it opens the hero to the void: a void point, four at most (p. 38). A
-- void point spent rolls the check twice and keeps the better (p. 38), but if that roll still misses, the void may
-- leave a mark (p. 38). Fights stand on the room's board, by the book (pp. 52-54): game/rules/dis/battle.lua, told by
-- game/rules/dis/fight.lua and game/ui/fight_steps_dis.lua. Pure Lua.

local dice = require "game.kit.dice"      -- (the table's dice: Death in Space rolls the d20 too)

local M = {}

M.id = "dis"
M.title = "Death in Space"
M.dice = { notation = "1d20", sides = 20, name = "d20", icon = "d20" }
M.who_rolls = "dm"                         -- (the DM rolls for the table here, in the open or behind the screen)
M.fight = "grid"                           -- (on the room's board: game/rules/dis/battle.lua; a scene can still be told)
M.TARGET = 12                              -- a check works on 12 or more, always (p. 36)
M.VOID_MAX = 4                             -- void points a hero can hold (p. 38)
M.inspiration = false                      -- (no reroll token the DM hands out: the void points are the players' own)
M.difficulty_word = "target"
M.fixed_dc = 12                            -- (the shared game never moves it: what helps or hinders is advantage)
M.scene_dc = { 12, 12, 12 }                -- (the same 12 however hard: the book makes a hard thing hard by its cost)

-- What a hero can try: the four abilities (p. 36).
M.ABILITIES = { bdy = "Body", dex = "Dexterity", svy = "Savvy", tec = "Tech" }
M.approaches = M.ABILITIES
-- The table's ways of trying something, in the shared game's words (its stock moves and goals name them), as Death in
-- Space's abilities: what a hero rolls for each. An ability is itself.
M.APPROACH = {
    athletics = "bdy", intimidation = "bdy", strength = "bdy", constitution = "bdy",
    acrobatics = "dex", stealth = "dex", sleight_of_hand = "dex", dexterity = "dex", initiative = "dex",
    perception = "svy", insight = "svy", persuasion = "svy", deception = "svy", performance = "svy",
    investigation = "svy", survival = "svy", animal_handling = "svy", religion = "svy", nature = "svy",
    wisdom = "svy", charisma = "svy",
    history = "tec", arcana = "tec", medicine = "tec", intelligence = "tec", thieves_tools = "tec",
}
function M.approach(sk)
    if M.ABILITIES[sk] then
        return sk
    end
    return M.APPROACH[sk] or "svy"
end
-- A fight told as story: what a hero rolls to get the better of it, their best of these.
M.story_approaches = { "bdy", "tec", "dex" }
M.story_marks = { 4, 6, 8 }                -- (a fight told as story takes longer to win here: the book's fights are deadly)

-- The words the shared game says Death in Space's things with (each set has its own).
M.words = {
    turn_order = { "Everyone in the fight, in the order they act. Whoever started it went first, and each one who acts "
        .. "picks who's next: the crew pass their turns among themselves while any of them are left to go. The lit one "
        .. "is acting now. Once everyone has gone, it's the next round.", "Turn order" },
    dc = "target",
    advantage = "advantage", disadvantage = "disadvantage",
    crit = "natural 20", fumble = "natural 1",
    extremes = "natural 20 or 1", extremes_both = "a natural 20 or a natural 1",
    hp = "HP", hit_points = "hit points",
    void = "void point", void_plural = "void points",
    short_rest = "a breather", long_rest = "a full night's rest in the hub",
    rest_short_label = "They catch their breath while we eat.",
    rest_short_sub = "A few minutes in the game: no hit points back, but a moment to think.",
    rest_long_label = "They sleep it off in the hub.",
    rest_hour = "A breather. {healed} hit points back across the crew.",
    rest_none = "A breather. Nobody's patched up, but nobody's worse.",
    rest_long_said = "A full night's sleep. Everyone wakes up stiff, but whole.",
    rest_long_healed = { "A full night's sleep and a hot meal: {healed} hit points back across the crew." },
    spot_first = "A Savvy check. Miss it, and it goes off.",
    find_check = "Savvy check",
    tile_hp = { "Hit points", "How much more {char} can take. At 0, a Body check decides whether {char} lives." },
    tile_ac = { "Defense rating (DR)", "How hard {char} is to hit: an attack has to roll this or more." },
    roll_hover = "The die, what it was for, and the total against what it needed: 12 for a check, the defense rating for an "
        .. "attack. Green: it worked. Red: it didn't, and a void point comes with it.",
    cover_legend = "Cover: shots at someone behind it have disadvantage",
    npc_fight = "In a fight: {hp} hit points, defense rating {ac}",
    light = {
        bright = "Work lights, a lit deck. Everyone sees.",
        dim = "Flickering panels, a corridor on emergency power.",
        dark = "No power at all. Only lamps and suit lights see.",
    },
    recap = {
        crit = { "{char} rolled a natural 20, and the table went quiet, then loud.", "A natural 20 from {char}, right when it counted." },
        fumble = { "{char} rolled a 1, and the void noticed.", "A natural 1 for {char}, at the worst moment." },
        jail = { "{who}'s d20 went to dice jail.", "Dice jail claimed {who}'s d20." },
        void = { "{text}", "The void got its fingers into {char}." },
    },
    read = "a read", read_button = "read them", read_crit = "a natural 20 always reads",
    hidden_death_save = "a dying roll made behind the screen",
    own_dc = { "\"Twelve, {actor_char}. It's always twelve.\"", "\"You need a twelve.\"", "\"Twelve or more. Go on.\"" },
    -- (The void taking a hero's miss, and what it leaves when a spent point fails anyway: our own, after p. 39.)
    void_gain = { "{char} takes a void point ({n} now).", "The miss leaves its mark: a void point for {char} ({n}).",
                  "{char} feels the void lean in ({n} now)." },
    void_cancel = { "{char} spends a void point against the setbacks: one die, straight.",
                    "A void point from {char} cancels the setbacks out: just the one die." },
    void_spend = { "{char} spends a void point and rolls twice.", "A void point from {char}: two dice, the better one counts." },
    void_mark = { "The void leaves something behind on {char}: {mark}.", "That one costs {char} more than a roll: {mark}." },
    void_marks = { "whispers in any static, ever after", "a cold patch of skin that won't warm", "dreams of a suffocating dark",
                   "memories that don't fit, and might not have happened yet", "a faint glow under one fingernail" },
}
-- Death in Space's own words: no other set's adventure may show one (tools/tests/rules_fence_check.lua). Dice, grids,
-- and the words both games use (hit points, advantage, natural 20) aren't here: a word leaks only where the
-- adventure's set doesn't own it.
M.owns = {
    "%f[%w]void points?%f[%W]", "%f[%w]Void points?%f[%W]", "%f[%w]void corruption%f[%W]", "%f[%w]cosmic mutation",
    "%f[%w]defense rating%f[%W]", "%f[%w]holos%f[%W]", "%d holo%f[%W]", "%f[%w]Savvy%f[%W]", "%f[%w]Tech check", "%f[%w]Body check",
    "%f[%w]BDY%f[%W]", "%f[%w]SVY%f[%W]", "%f[%w]TEC%f[%W]", "%f[%w]non%-phys%f[%W]",
}
-- (Words 5e owns that this set also uses, so the fence lets them through here: game/rules/sets/dnd5e.lua's owns.)
M.shares = { "hit points", "%f[%w]HP%f[%W]", "%f[%w]Advantage%f[%W]", "%f[%w]Disadvantage%f[%W]", "natural 20", "natural 1%f[%D]" }
M.rule_terms = { "advantage", "void", "cover", "morale" }
M.difficulty_names = { { 12, "What every check needs" } }

-- The usual ways a secret of each kind comes out, besides the adventure's own (game/model/secrets.lua): an ability
-- check against 12, asking someone who likes the crew, listening in.
M.secret_defaults = {
    person = {
        { kind = "check", skill = { "svy" }, dc = 12, gives = "hint" },
        { kind = "ask", opinion = "warm", gives = "known" },
        { kind = "check", skill = { "dex" }, dc = 12, gives = "hint", eavesdrop = true },
    },
    document = { { kind = "read", skill = { "tec", "svy" }, dc = 12, gives = "known" } },
    place = { { kind = "check", skill = { "svy" }, dc = 12, gives = "known" } },
    body = { { kind = "check", skill = { "tec" }, dc = 12, gives = "known" } },
    item = { { kind = "check", skill = { "tec" }, dc = 12, gives = "known" } },
    creature = { { kind = "check", skill = { "svy", "tec" }, dc = 12, gives = "known" } },
}

-- Who a player's hero is: the adventure's crew member (its `heroes`), or the new character who took their place after
-- a death (its `pregens`, by the player's `pregen`).
function M.hero_of(campaign, key)
    local adv = package.loaded["game.model.adventure"]
    local data = adv and adv.data or {}
    local p = campaign and campaign.player and campaign:player(key)
    if p and p.pregen then
        for _, g in ipairs((data.pregens or {})[key] or {}) do
            if g.id == p.pregen then
                return g
            end
        end
    end
    return (data.heroes or {})[key]
end

-- A hero's bonus for an approach: the ability's value on their sheet.
function M.hero_mod(campaign, p, approach)
    local h = M.hero_of(campaign, p.key)
    local sheet = h and h.sheet or {}
    return sheet[M.approach(approach)] or 0
end

-- A rest (p. 54): game/rules/dis/fight.lua heals the crew, and this says it.
function M.rest_with(night, long)
    local f = M.engine.fight
    if not night.pc_list then
        f.party(night)
    end
    local healed = f.rest(night, long, night.scene and night.scene.room == "hub")
    if long then
        local util = require "game.model.util"
        return healed > 0 and util.fill(night:fresh(M.words.rest_long_healed, "rest_long_healed"), { healed = tostring(healed) })
            or M.words.rest_long_said
    end
    return M.words.rest_none
end
function M.mod()
    return 0
end
function M.name(approach)
    return M.ABILITIES[M.approach(approach)]
end
function M.signed(n)
    local r = math.floor(n + 0.5)
    return (r >= 0 and "+" or "") .. string.format("%d", r)
end

local D20, ADVANTAGE = dice.parse("1d20"), dice.parse("2d20kh1")
function M.die(rng)
    return dice.roll(rng, D20).total
end
function M.roll(rng, edge)
    if edge == "adv" then
        local g = dice.roll(rng, ADVANTAGE).groups[1]
        local keep = g.kept[1] and 1 or 2
        return g.faces[keep], g.faces[3 - keep]
    end
    return M.die(rng), nil
end

-- How it came out, in the shared game's tiers: 12 or more works, a natural 20 or 17 and up works beautifully; a miss
-- by 3 or less is near (it works, at a cost), and a natural 1 or a miss by more is a flop.
function M.tier(total, dc, natural)
    dc = dc or M.TARGET
    if natural == 20 or total >= dc + 5 then
        return "triumph"
    elseif total >= dc then
        return "success"
    elseif natural == 1 or total < dc - 3 then
        return "flop"
    end
    return "near"
end
function M.odds_line(dc, mod)
    local need = (dc or M.TARGET) - (mod or 0)
    if need <= 2 then
        return "They make it on almost any roll."
    elseif need >= 20 then
        return "Only a natural 20 makes it."
    end
    local chance = (21 - need) / 20
    return "They need " .. string.format("%d", math.floor(need + 0.5)) .. " or more on the d20: about "
        .. string.format("%d", math.floor(chance * 100 + 0.5)) .. "%."
end
function M.check(rng, opts)
    local dc = opts.dc or M.TARGET
    local roll, other = M.roll(rng, opts.edge)
    local mod = opts.mod or 0
    local total = roll + mod
    return { roll = roll, other = other, mod = mod, total = total, dc = dc, success = total >= dc,
             tier = M.tier(total, dc, roll), crit = roll == 20, fumble = roll == 1 }
end
function M.result_word(r)
    if r.roll == 20 then
        return "natural 20"
    elseif r.roll == 1 then
        return "natural 1"
    end
    return r.success and "success" or "miss"
end
function M.line(who, approach, r)
    return who .. ": " .. M.name(approach) .. " " .. string.format("%d", r.roll) .. M.signed(r.mod) .. " = "
        .. string.format("%d", r.total) .. " (" .. string.format("%d", r.dc or M.TARGET) .. " to beat), " .. M.result_word(r)
end

-- The void (p. 38). The campaign keeps each hero's points (campaign.void[key]); the shared game asks the set before
-- a check whether the player spends one (edge), and tells it after (after_check), and says what the set says back.
local function voids(campaign)
    campaign.void = campaign.void or {}
    return campaign.void
end
function M.void_points(campaign, key)
    return voids(campaign)[key] or 0
end
-- Before a check: a player with a void point spends it when the roll matters and they'd likely miss (a big roll, or a
-- check they need 14 or more for). Returns "adv" and the line to say, or nil.
function M.edge(campaign, p, opts)
    local v = voids(campaign)
    local have = v[p.key] or 0
    local need = (opts.dc or M.TARGET) - (opts.mod or 0)
    if have > 0 and (opts.big or need >= 14) then
        v[p.key] = have - 1
        return "adv", { kind = "void_spend", vars = { char = p.char } }
    end
    return nil
end
-- After a check: a miss gives a void point (unless one was spent on it); a spent point that still missed may leave a
-- mark: 1d6 at or under the points left (p. 38). Returns what to say: { kind, vars } entries.
function M.after_check(campaign, p, r, rng, spent)
    local out = {}
    if r.success then
        return out
    end
    local v = voids(campaign)
    if spent then
        local left = v[p.key] or 0
        if rng:int(1, 6) <= left then
            local marks = M.words.void_marks
            campaign.void_marks = campaign.void_marks or {}
            local mark = marks[rng:int(1, #marks)]
            campaign.void_marks[p.key] = campaign.void_marks[p.key] or {}
            table.insert(campaign.void_marks[p.key], mark)
            table.insert(out, { kind = "void_mark", vars = { char = p.char, mark = mark } })
        end
        return out
    end
    local n = math.min(M.VOID_MAX, (v[p.key] or 0) + 1)
    if n ~= (v[p.key] or 0) then
        v[p.key] = n
        table.insert(out, { kind = "void_gain", vars = { char = p.char, n = tostring(n) } })
    end
    return out
end

-- Death in Space's engine: what the shared game reaches through game/model/ruleset.lua. A roster of the adventure's
-- own creatures (standard.lua puts its stat blocks here), and nothing of 5e's.
M.engine = {
    ["data.monsters"] = {},
    progression = require "game.rules.dis.progression",
    party = require "game.rules.dis.party",
    tile_stats = require "game.rules.dis.tile_stats",
    fight = require "game.rules.dis.fight",
}

return M
