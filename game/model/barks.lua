-- Fight barks that fit the moment (November 3). The playtest, Nov 2: "Dev's fight barks and
-- Mara's long-fight tell recur most", and lines that ignored the moment ("NATURAL TWENTY!" on a
-- 19, "Who's next?" after the last foe). A bark now comes with the moment it's about:
--
--   moment = { foe, boss, weapon, spell, roll, crit, left, last, dmg, hp, hp_max, healer, ally,
--              ally_hp, round, room, dealt, ... }
--
-- built from the turn's steps and the fight (M.from_steps, M.from_fight). Library lines are
-- checked against it (game/data/barks.lua `fits`: a phrase that needs a fact), and lines made
-- from the moment itself (`made`, in each friend's voice) are offered beside them, each said
-- once a night and the same words not again for three weeks. Pure Lua.

local util = require "game.model.util"
local DATA = require "game.data.barks"

local M = {}

M.MADE_SHARE = 0.6     -- how often a line made from the moment wins over a library one that fits

local function lower_name(name)
    return name and util.lower_first(name) or nil
end

-- What the table calls a foe: "the Kruthik Huntling" (not "Kruthik Huntling 3"), "the Lecturer",
-- "Euryale". A boss or a named person keeps their name; anything else is "the" something.
function M.foe_label(c)
    if not c or not c.name then
        return nil
    end
    local n = (string.gsub(c.name, "%s+%d+$", ""))
    if string.sub(n, 1, 4) == "The " or string.sub(n, 1, 4) == "the " or c.boss or c.person then
        return n
    end
    return "the " .. n
end
local foe_label = M.foe_label

local function number_word(n)
    return DATA.NUMBERS[n] or tostring(n)
end

-- What's true right now, as facts the `fits` rules and `when`s test.
local FACT = {
    nat20 = function(mo) return mo.roll == 20 end,
    crit19 = function(mo) return mo.crit and mo.roll == 19 end,
    more_left = function(mo) return (mo.left or 0) > 0 end,
    rest_left = function(mo) return (mo.left or 0) >= 2 end,     -- (others besides the one named: "the rest might break")
    last = function(mo) return mo.left == 0 end,
    small_foe = function(mo) return mo.foe ~= nil and not mo.boss end,
    big_hit = function(mo) return mo.dmg ~= nil and mo.hp_max ~= nil and mo.dmg >= 0.45 * mo.hp_max end,
    low_hp = function(mo) return mo.hp ~= nil and mo.hp_max ~= nil and mo.hp > 0 and mo.hp <= 0.35 * mo.hp_max end,
    was_winning = function(mo) return (mo.dealt or 0) > 0 end,
    concentrating = function(mo) return mo.concentrating == true end,
    round3 = function(mo) return (mo.round or 0) >= 3 end,
    long_fight = function(mo) return (mo.round or 0) >= 5 end,
    surge_ready = function(mo) return mo.surge_ready == true end,
    party_hurt = function(mo) return mo.party_hurt == true end,
    target_down = function(mo) return mo.target_down == true end,
    fire = function(mo) return mo.spell ~= nil and string.find(string.lower(mo.spell), "fire", 1, true) ~= nil end,
    dmg19 = function(mo) return mo.dmg == 19 end,
    never = function() return false end,
    spell_fire_bolt = function(mo) return mo.spell == "Fire Bolt" end,
    spell_sacred_flame = function(mo) return mo.spell == "Sacred Flame" end,
    spell_bless = function(mo) return mo.spell == "Bless" end,
    survivors = function(mo) return mo.survivors == true end,
    no_slots = function(mo) return mo.no_slots == true end,
    cleric = function(mo) return mo.class == "cleric" end,
}
M.FACT = FACT

-- Is a library line true in this moment? Lines with none of the phrases always are.
function M.fits(text, mo)
    if not mo or not text then
        return true
    end
    local low = string.lower(text)
    for _, rule in ipairs(DATA.fits) do
        if string.find(low, rule[1]) and not FACT[rule[2]](mo) then
            return false
        end
    end
    return true
end

-- The room's facts, for lines said outside a fight's turns (DATA.context). ctx = { someone (a person
-- to talk to is here), fight (the room has a fight in it), calm (no danger in it), clue (something
-- learned tonight), big (the foe in front of them is Large or bigger), foes (how many), thing (the
-- boss is a creature, not a person) }.
local CONTEXT = {
    nobody_here = function(c) return not c.someone end,
    someone_here = function(c) return c.someone == true end,
    fight_here = function(c) return c.fight == true end,
    no_fight_here = function(c) return not c.fight end,
    calm = function(c) return c.calm == true end,
    clue_found = function(c) return c.clue == true end,
    big_foe = function(c) return c.big == true end,
    several_foes = function(c) return (c.foes or 0) > 1 end,
    boss_is_a_thing = function(c) return c.thing == true end,
    on_time = function(c) return not c.late end,
    before_midnight = function(c) return not c.midnight end,
    nobody_died = function(c) return not c.died end,
    self_close = function(c) return c.self_close == true end,
    lock_here = function(c) return c.lock == true end,
    puzzle_here = function(c) return c.puzzle == true end,
    never = function() return false end,
    not_looked = function(c) return not c.looked end,
    big_ending = function(c) return c.big_ending == true end,
    statue_here = function(c) return c.statue == true end,
    first_fight = function(c) return c.first_fight == true end,
}
M.CONTEXT = CONTEXT

function M.context_fits(text, ctx)
    if not text or not ctx then
        return true
    end
    local low = string.lower(text)
    for _, rule in ipairs(DATA.context or {}) do
        if string.find(low, rule[1], 1, true) and not CONTEXT[rule[2]](ctx) then
            return false
        end
    end
    return true
end

-- The fill-ins a moment offers ({Foe} for the start of a sentence).
local function fills(mo, p)
    local v = {}
    local function put(k, val)
        if val ~= nil and val ~= "" then
            v[k] = tostring(val)
            v[string.upper(string.sub(k, 1, 1)) .. string.sub(k, 2)] = util.capitalize(tostring(val))
        end
    end
    put("foe", lower_name(mo.foe))
    -- (The foe's own pronoun, {foe_they}: "Euryale hits harder than she looks", not "than it looks".)
    -- (One creature the adventure doesn't name a pronoun for is "it", never "they looks".)
    local fp = mo.foe and util.pronoun_of(mo.foe).they or nil
    put("foe_they", fp == "they" and "it" or fp)
    put("weapon", mo.weapon and string.lower(mo.weapon) or nil)
    put("spell", mo.spell)
    put("left", mo.left and mo.left > 0 and number_word(mo.left) or nil)
    put("dmg", mo.dmg and mo.dmg > 0 and util.int(mo.dmg) or nil)
    put("hp", mo.hp and mo.hp > 0 and util.int(mo.hp) or nil)
    put("healer", mo.healer)
    put("ally", mo.ally)
    put("ally_hp", mo.ally_hp and util.int(mo.ally_hp) or nil)
    put("round", mo.round and util.int(mo.round) or nil)
    put("room", mo.room and string.lower(mo.room) or nil)
    put("dist", mo.dist and util.int(mo.dist) or nil)
    put("charmer", lower_name(mo.charmer))
    if p then
        v.char = p.char
        v.name = p.name
    end
    return v
end
M.fills = fills

-- Every fill a line names is in the moment.
local function filled(text, v)
    for k in string.gmatch(text, "{([%w_]+)}") do
        if v[k] == nil then
            return nil
        end
    end
    return (string.gsub(text, "{([%w_]+)}", v))
end

-- The lines this moment can make for this friend: { { id, text } }, freshest first.
function M.made(night, trigger, p, mo)
    local pool = DATA.made[trigger] and DATA.made[trigger][p.key]
    if not pool or not mo then
        return {}
    end
    local v = fills(mo, p)
    local out = {}
    night.made_used = night.made_used or {}
    local camp = night.campaign
    local said = camp and camp.said or {}
    local week = camp and camp.week or 0
    for i, l in ipairs(pool) do
        local id = "made." .. trigger .. "." .. p.key .. "." .. i
        local text = (not l.when or FACT[l.when](mo)) and filled(l[1], v) or nil
        local w = text and said["made:" .. text]
        if text and not night.made_used[id] and not (w and week - w < 3) then
            table.insert(out, { id = id, text = text })
        end
    end
    return out
end

-- Say it: a line made from the moment, or a library line that fits it. Returns text, id.
function M.pick(night, trigger, p, mo, vars)
    local made = M.made(night, trigger, p, mo)
    local function use_made()
        local m = night.rng:pick(made)
        night.made_used[m.id] = true
        if night.campaign then
            night.campaign.said = night.campaign.said or {}
            night.campaign.said["made:" .. m.text] = night.campaign.week or 0
        end
        return m.text, m.id
    end
    if #made > 0 and night.rng:chance(M.MADE_SHARE) then
        return use_made()
    end
    local text, line = night.talk:line(trigger, p, vars, function(l)
        return M.fits(l.text, mo)
    end)
    if not text and #made > 0 then
        return use_made()
    end
    return text, line and line.id
end

-- The moment ------------------------------------------------------------------------------------

local function creature(night, id)
    local b = night.battle
    if not (b and id) then
        return nil
    end
    for _, c in ipairs(b.creatures or {}) do
        if c.mini == id then
            return c
        end
    end
    return nil
end

local function alive_foes(night)
    local n = 0
    for _, c in ipairs((night.battle and night.battle.creatures) or {}) do
        if c.side == "foes" and not c.dead and not c.removed then
            n = n + 1
        end
    end
    return n
end

-- What the whole fight looks like from the table: the round, who's left, who's hurt.
function M.from_fight(night, p)
    local b = night.battle
    local mo = { round = b and b.round or nil, left = alive_foes(night) }
    local sc = night.scene
    mo.room = sc and sc.comps and sc.comps.location and sc.comps.location.name or nil
    -- The foe on everyone's mind: the boss while it stands, else the healthiest one left.
    local best
    for _, c in ipairs((b and b.creatures) or {}) do
        if c.side == "foes" and not c.dead and not c.removed then
            if c.boss then
                best = c
                break
            end
            if not best or (c.hp or 0) > (best.hp or 0) then
                best = c
            end
        end
    end
    mo.foe, mo.boss = foe_label(best), best and best.boss or nil
    -- The friend who's worst off, if it isn't the speaker.
    local worst
    for _, c in ipairs((b and b.creatures) or {}) do
        if c.pc and not c.dead and (c.hp or 0) > 0 and (not p or c.player_key ~= p.key)
            and c.hp < 0.5 * c.hp_max and (not worst or c.hp / c.hp_max < worst.hp / worst.hp_max) then
            worst = c
        end
    end
    if worst then
        mo.ally, mo.ally_hp = worst.name, worst.hp
    end
    local hurt, conc = false, false
    for _, c in ipairs((b and b.creatures) or {}) do
        if c.pc and not c.dead then
            hurt = hurt or ((c.hp or 0) < 0.75 * (c.hp_max or 1))
            conc = conc or c.conc ~= nil
        end
    end
    mo.party_hurt, mo.concentrating = hurt, conc
    local me = p and night:pc_of(p)
    if me then
        mo.class = p.class
        mo.hp, mo.hp_max = me.hp, me.hp_max
        mo.dealt = me.stats and me.stats.dealt or 0
        mo.surge_ready = (me.res and (me.res.action_surge or 0) > 0) or false
        local slots, casts = 0, false
        for _, n in pairs((me.res and me.res.slots) or {}) do
            casts = true
            slots = slots + n
        end
        mo.no_slots = casts and slots == 0
    end
    return mo
end

-- What just happened on a turn: the fight's picture plus this turn's own facts, from the side of
-- the friend who'll say it (p). who: whose turn it was.
function M.from_steps(night, steps, who, p)
    local mo = M.from_fight(night, p)
    local me = p and night:pc_of(p)
    local mine = me and me.mini
    local actor = who and who.mini
    local killed
    for _, s in ipairs(steps or {}) do
        if s.kind == "attack" and s.id == actor then
            local t = creature(night, s.target)
            mo.foe = (t and t.side ~= (who and who.side) and foe_label(t)) or mo.foe
            mo.weapon = mo.weapon or (not s.spell and s.weapon) or nil
            if s.crit then
                mo.crit, mo.roll = true, s.roll
            end
            mo.target_down = t and ((t.hp or 1) <= 0 or t.dead) or false
        elseif s.kind == "spell" and s.id == actor then
            mo.spell = mo.spell or s.name
            local t = type(s.target) == "string" and creature(night, s.target)
            if t and t.side ~= (who and who.side) then
                mo.foe = foe_label(t)
            end
        elseif s.kind == "damage" and s.id == mine then
            mo.dmg = (mo.dmg or 0) + (s.amount or 0)
            mo.hp = s.hp
        elseif s.kind == "damage" and s.id ~= mine and actor == mine then
            mo.dealt_now = (mo.dealt_now or 0) + (s.amount or 0)
        elseif s.kind == "death" then
            local c = creature(night, s.id)
            if c and c.side == "foes" then
                killed = c
            end
        elseif s.kind == "up" or s.kind == "heal" then
            local by = creature(night, s.by) or (who and who.pc and who) or nil
            if by and by.mini ~= mine then
                mo.healer = by.name
            end
        end
    end
    -- On a monster's turn, the one it hurt or dropped names the monster.
    if who and who.side == "foes" then
        mo.foe, mo.boss = foe_label(who), who.boss
    end
    if killed then
        mo.foe, mo.boss = foe_label(killed), killed.boss
    end
    mo.left = alive_foes(night)
    -- (A big hit reads the damage dealt; an ouch, the damage taken.)
    if mo.dealt_now and not mo.dmg then
        mo.dmg = mo.dealt_now
    end
    return mo
end

return M
