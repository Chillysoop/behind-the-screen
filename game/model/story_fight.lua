-- A fight told as story (docs/design/rule-sets.md, step 4): no grid, no minis moving, for any rule set. The party
-- against a clock: each hero at hand says what they go for, rolls the set's check against the set's number for how
-- hard the scene is, and the tier says what happens. A triumph fills two of the clock's marks, a success one; a near
-- miss fills one but the foes get one back at the hero ("yes, but"); a flop fills none, and the foes make their move.
-- Two hits take a hero out of the fight. The clock full is a win; everyone out, or the fight going on too long, a
-- loss. Then it's in the log like any fight (night:log_fight), so the report, the recap and the journey tell it.
-- Pure Lua. The words are the table's own, never a rule set's (the check's line is the set's: set.line).
--
--   story_fight.run(night, sc)   -> result { winner = "party" | "foes", rounds, pc_downs, story = true }
-- A scene plays its fight this way when its `fight_mode` is "story", or its rule set's `fight` is.

local util = require "game.model.util"
local ruleset = require "game.model.ruleset"
local score = require "game.model.score"

local M = {}

M.MAX_ROUNDS = 6
M.HARM_OUT = 2           -- hits that take a hero out of the fight
M.MARKS = { 4, 5, 6 }    -- the clock's marks, by how hard the scene is

-- What the players say, in character, before they roll: theirs to announce (the DM only says what happens).
M.GO = {
    "I'm going for {foe}. Here goes.",
    "{Foe}'s mine. Watch this.",
    "Right. I go straight at {foe}.",
    "Covering the others. I'm going in.",
    "Let's finish this. I go for {foe}.",
}
-- What happens, by the tier. {char} is the hero who rolled, {foe} who they're up against.
M.SAID = {
    triumph = { "A clean hit. {Foe} won't take many more like that.", "That's the one. {Foe} reels back, badly shaken.",
                "Everything goes right at once, and {foe} gives a lot of ground." },
    success = { "That one lands. {Foe} gives ground.", "It works: {foe} has to fall back a step.",
                "A good one. {Foe} is feeling it now." },
    near = { "It lands, but {foe} gets one back at {char}.", "{Foe} takes it, and answers it, hard, at {char}.",
             "Half of it works: {foe} gives ground, and catches {char} on the way." },
    flop = { "{Foe} sees it coming, and makes {char} pay for it.", "Nothing doing. {Foe} turns it round on {char}.",
             "It goes wrong, and {foe} is right there to take advantage." },
}
M.HURT = { "{char} is hurt.", "{char} is hurting now.", "That hurts {char}." }
M.OUT = { "{char} is out of the fight.", "That's {char} out of it.", "{char} goes down and stays down." }
M.OPEN = { "It's a fight: {foe} against the party.", "No more talking: {foe} comes at them.", "And it's on, against {foe}." }
M.WIN = { "{Foe} breaks, and the fight is theirs.", "That's enough for {foe}: it's over, and they've won it.",
          "{Foe} is done. The party is still standing." }
M.LOSE = { "It's no good: {foe} has the better of them.", "They can't win this one. {Foe} has them beaten.",
           "{Foe} is too much for them tonight." }
M.LONG = { "It drags on, and on, and {foe} is still standing.", "Round after round, and neither side gives way: {foe} holds them off." }
M.UP = { "When it's over, {names} {are} back on {their} feet, bruised.", "Once it's done, {names} {are} up again, sore all over." }

local function words(night, list, key, vars)
    return util.fill(night:fresh(list, key), vars)
end

-- Who they're up against, in a word the table's heard: the fight's leader, the room's people, or "them".
function M.foe_name(sc)
    return (sc.encounter and sc.encounter.boss_name) or sc.boss_name or "them"
end

function M.run(night, sc)
    local set = ruleset.current()
    local threat = util.clamp(math.floor((sc.fight_hard or sc.difficulty or 2) + 0.5), 1, 3)
    local need = (set.story_marks or M.MARKS)[threat]
    local dc = (set.scene_dc and set.scene_dc[threat]) or 12
    local foe = M.foe_name(sc)
    local vars = { foe = foe, Foe = util.capitalize(foe) }
    local harm, out_list, clock, rounds = {}, {}, 0, 0
    sc.story_fight = { need = need, dc = dc, clock = 0 }
    night:say(words(night, M.OPEN, "story_open", vars), "narration")
    local function standing()
        local out = {}
        for _, p in ipairs(night:at_hand(true)) do
            if (harm[p.key] or 0) < M.HARM_OUT then
                table.insert(out, p)
            end
        end
        return out
    end
    while clock < need and rounds < M.MAX_ROUNDS and #standing() > 0 do
        rounds = rounds + 1
        for _, p in ipairs(standing()) do
            if clock >= need then
                break
            end
            local v = util.copy(vars)
            v.char = p.char
            night:emit({ kind = "say", who = p.key, ic = true, text = util.capitalize(words(night, M.GO, "story_go", v)) })
            local approach, mod = night:best_skill(p, set.story_approaches or {})
            -- (The set's own edge: Death in Space's void points, spent when it matters.)
            local edge, note
            if set.edge then
                edge, note = set.edge(night.campaign, p, { dc = dc, mod = mod or 0, big = true })
                if note then
                    night:say(util.fill(night:fresh(set.words[note.kind], note.kind), note.vars), "dice")
                end
            end
            local r = set.check(night.rng, { mod = mod or 0, dc = dc, edge = edge })
            night:emit({ kind = "check", text = set.line(p.char, approach, r), roll = r.roll, bonus = r.mod, total = r.total,
                         dc = dc, success = r.success, actor = p.key, char = p.char, skill = approach,
                         skill_name = set.name(approach), crit = r.crit, fumble = r.fumble, tier = r.tier, story = true })
            if night.set_after_check then
                night:set_after_check(p, r, note)
            end
            local tier = r.tier
            night:say(words(night, M.SAID[tier], "story_" .. tier, v), (tier == "triumph" or tier == "success") and "good" or "bad")
            if tier == "triumph" then
                clock = clock + 2
                score.add(p, "spotlight", 8)
                score.add(p, "fun", 3)
            elseif tier == "success" then
                clock = clock + 1
                score.add(p, "spotlight", 4)
            elseif tier == "near" then
                clock = clock + 1
            end
            if tier == "near" or tier == "flop" then
                harm[p.key] = (harm[p.key] or 0) + 1
                if harm[p.key] >= M.HARM_OUT then
                    table.insert(out_list, p)
                    night:say(words(night, M.OUT, "story_out", v), "bad")
                else
                    night:say(words(night, M.HURT, "story_hurt", v), "bad")
                end
            end
            sc.story_fight.clock = clock
        end
    end
    local won = clock >= need
    if not won and #standing() > 0 then
        night:say(words(night, M.LONG, "story_long", vars), "narration")
    end
    night:say(words(night, won and M.WIN or M.LOSE, won and "story_win" or "story_lose", vars), won and "good" or "bad")
    for _, p in ipairs(night.players) do
        score.add(p, "challenge", won and 6 or 10)
        score.add(p, "fun", won and 2 or -4)
    end
    -- (Who was out of it comes round: a story fight's knocks aren't a grid fight's, and nobody's left on the floor.)
    if #out_list > 0 then
        local names = {}
        for _, p in ipairs(out_list) do
            table.insert(names, p.char)
        end
        local one = #names == 1
        night:say(util.fill(night:fresh(M.UP, "story_up"), { names = util.join_names(names), are = one and "is" or "are",
            their = one and util.pronoun_of(names[1]).their or "their" }), "aside")
    end
    local result = { winner = won and "party" or "foes", rounds = rounds, pc_downs = #out_list, story = true }
    sc.result = result
    sc.outcome = won and "win" or "lose"
    sc.foes_ran, sc.allies_lost = {}, {}
    sc.foes_beaten = {}
    if won then
        for _, id in ipairs(sc.encounter and sc.encounter.ids or {}) do
            table.insert(sc.foes_beaten, type(id) == "table" and (id.id or id[1]) or id)
        end
    end
    night:log_fight(sc, nil, result)
    return result
end

return M
