-- What the friends think and don't say (v2, October 30). The Discord feedback asked for "some barks
-- [to] be internal dialogue": watch one of the players at the table react to a moment inside. A
-- thought shows what's really driving a friend right now (a turn they haven't had, a fight that's
-- dragging, the week they've had, a roll that looked convenient, a plan to go off alone), so you
-- can read the table and answer it, the way a good DM catches a look across the table.
--
-- How many you catch is your Empathy: a few a night when you're new to the table, more as you
-- learn to read them. What you catch is only a tell (drumming fingers, a glance at the notes) until
-- you read them: an Insight roll, d20 + your Empathy + how well you know that friend
-- (game/model/familiar.lua), against how hidden the thought is and how hard they are to read. A
-- clear read hears the words; a near miss gets the gist; a miss can't tell (ask them straight out,
-- or let it be); a natural 1 misreads them, and you only find out later. Answering one well grows
-- your Empathy (once a night) and how well you know them. Answers are small,
-- real table moves (a turn, a detail, a break, a quiet word), and the wrong one for the person
-- costs: put the friend who hates the spotlight in it and he shrinks. Ignoring one is allowed:
-- the need just keeps working on them, as it always did.
--
-- The night director calls in at its beats (game/model/night.lua, game/model/museum_night.lua);
-- the screen draws the bubble and the card and calls M.respond between beats (it never waits for
-- an answer). Pure Lua.

local util = require "game.model.util"
local score = require "game.model.score"
local familiar = require "game.model.familiar"
local rng_mod = require "game.model.rng"
local DATA = require "game.data.thoughts"

local M = {}

M.DATA = DATA
M.CAP = { 2, 3, 4, 4, 5 }   -- thoughts you catch a night, by Empathy level (a happy one doesn't count)
M.GLOW_CAP = 1              -- happy thoughts a night
M.BREW_AT = 6.5             -- how hungry (meter weight x shortfall) before a want shows
M.HAPPY = 62                -- above this Fun, nobody's brooding

local function state(night)
    night.th = night.th or { n = 0, glows = 0, list = {}, by_scene = {}, queue = {}, answered = 0, shown = 0, dawn = {} }
    return night.th
end
M.state = state

function M.cap(night)
    local c = night.campaign
    local level = (c and c.empathy) and c:empathy() or 1
    return M.CAP[util.clamp(level, 1, #M.CAP)]
end

local function vars(p)
    local pr = DATA.pronouns[p.key] or { them = "them", their = "their" }
    return { name = p.name, char = p.char, them = pr.them, their = pr.their }
end
M.vars = vars

local function present(night, key)
    for _, p in ipairs(night.players or {}) do
        if p.key == key then
            return p
        end
    end
    return nil
end

local function scene_index(night)
    return night.scene and night.scene.index or 0
end

-- A line for this friend and need: their own, else anyone's; an "_after" line when a call just cost them.
local function line_for(night, p, need, after)
    local mine = DATA.lines[p.key] or {}
    local key = after and (need .. "_after") or need
    local list = mine[key] or DATA.generic[key]
    if not list and after then
        list = mine[need] or DATA.generic[need]
    end
    if not list then
        return nil
    end
    return util.sentence_case(util.fill(night:fresh(list, "thought_" .. p.key .. "_" .. key), vars(p)))
end

-- A thought goes up: { id, who, need, scene, answers }. opts: after (a call just cost them), keep
-- (stays open past the scene, until what it's about happens), any_scene (doesn't use up the scene's).
function M.think(night, p, need, opts)
    opts = opts or {}
    local def = DATA.needs[need]
    if not (def and p) or night.no_thoughts then
        return nil
    end
    local th = state(night)
    local glow = need == "glow"
    if glow then
        if th.glows >= M.GLOW_CAP then
            return nil
        end
    elseif th.n >= M.cap(night) then
        return nil
    end
    local sc = scene_index(night)
    if not opts.any_scene and th.by_scene[sc] then
        return nil
    end
    local text = line_for(night, p, need, opts.after)
    if not text then
        return nil
    end
    th.next_id = (th.next_id or 0) + 1
    local id = th.next_id
    local v = vars(p)
    local answers = {}
    for _, aid in ipairs(def.answers) do
        local a = DATA.answers[aid]
        table.insert(answers, { id = aid, label = util.sentence_case(util.fill(a.label, v)) })
    end
    local tell = util.fill(def.tell or "seems to be thinking something", v)
    local t = { id = id, who = p.key, need = need, scene = sc, answers = def.answers, keep = opts.keep, glow = glow,
                text = text, tell = tell }
    th.list[id] = t
    if glow then
        th.glows = th.glows + 1
    else
        th.n = th.n + 1
    end
    if not opts.any_scene then
        th.by_scene[sc] = true
    end
    th.shown = th.shown + 1
    th.log = th.log or {}
    table.insert(th.log, { who = p.key, need = need, text = text })
    -- (The screen shows the tell until you read them; a happy thought shows on their face.)
    night:emit({ kind = "thought", id = id, who = p.key, name = p.name, char = p.char, text = text, need = need,
                 tell = tell, want = p.name .. " " .. util.fill(def.want, v), answers = answers, glow = glow or nil })
    return t
end

-- Still something to answer? (A thought passes when its scene ends, or when what it was about happens.)
function M.is_open(night, id)
    local th = night.th
    local t = th and th.list[id]
    if not t or t.answered or t.gone or t.glow then
        return false
    end
    if t.need == "plan" then
        local st = night.campaign.adv
        return st ~= nil and st.flags ~= nil and st.flags.pip_alone == true
    end
    return t.keep or t.scene == scene_index(night)
end

-- Reading them --------------------------------------------------------------------------------------

-- Reads roll on their own dice, so reading the table never changes what happens at it.
local function read_rng(night)
    if not night.read_rng then
        local c = night.campaign or {}
        night.read_rng = rng_mod.new((c.seed or 1) * 7919 + (c.week or 1) * 104729 + 17)
    end
    return night.read_rng
end

local function empathy_bonus(night)
    local c = night.campaign
    return ((c and c.empathy) and c:empathy() or 1) - 1
end

-- What it takes to read this thought: { dc, bonus, empathy, familiar, need (the d20 you need), chance,
-- known (how well you know them, in words) }.
function M.odds(night, id)
    local t = night.th and night.th.list[id]
    if not t then
        return nil
    end
    local def = DATA.needs[t.need] or {}
    local dc = def.dc or 11
    if t.need ~= "plan" then
        dc = dc + (DATA.hard_to_read[t.who] or 0)
    end
    local emp = empathy_bonus(night)
    local fam = night.campaign and familiar.bonus(night.campaign, t.who) or 0
    local bonus = emp + fam
    local need = util.clamp(dc - bonus, 2, 20)       -- a 1 always misreads, a 20 always reads
    return { dc = dc, bonus = bonus, empathy = emp, familiar = fam, need = need, chance = (21 - need) / 20,
             known = night.campaign and familiar.name(night.campaign, t.who) or "New to you" }
end

-- What they'd seem to want, misread: the thing they usually care about, if it isn't this.
local MISREAD = { "spotlight", "story", "challenge", "social", "reward" }
local function wrong_need(night, t)
    local p = present(night, t.who)
    local best, bk = -1, nil
    for _, k in ipairs(MISREAD) do
        local w = p and score.weight(p, k) or 0.2
        if k ~= t.need and not (t.need == "pace" and k == "story") and not (k == "spotlight" and p and p.shy) and w > best then
            best, bk = w, k
        end
    end
    return bk or "social"
end

-- Read them: an Insight roll, once per thought. Returns { roll, total, dc, bonus, result } where result
-- is "book" (a 20), "clear", "gist" (within 4), "miss" or "misread" (a 1: as = what you think it is).
function M.read(night, id, force_roll)
    local th = night.th
    local t = th and th.list[id]
    if not t then
        return nil
    end
    if t.read then
        return t.read
    end
    if t.glow then
        t.read = { roll = 20, total = 20, dc = 0, bonus = 0, result = "clear" }
        return t.read
    end
    if not M.is_open(night, id) then
        return nil
    end
    local o = M.odds(night, id)
    local roll = force_roll or read_rng(night):int(1, 20)      -- (force_roll: the tests)
    local total = roll + o.bonus
    local result
    if roll == 1 then
        result = "misread"
    elseif roll == 20 then
        result = "book"
    elseif roll >= o.need then
        result = "clear"
    elseif total >= o.dc - 4 then
        result = "gist"
    else
        result = "miss"
    end
    t.read = { roll = roll, total = total, dc = o.dc, bonus = o.bonus, need = o.need, result = result }
    if result == "misread" then
        t.read.as = wrong_need(night, t)
    end
    th.reads = (th.reads or 0) + 1
    local c = night.campaign
    if result == "clear" or result == "book" then
        th.clear = (th.clear or 0) + 1
        if c then
            familiar.gain(c, t.who, "clear", night)
            if result == "book" then
                familiar.gain(c, t.who, "book", night)
            end
        end
    end
    return t.read
end

-- The need a read shows (a misread shows the wrong one), and whether the words are heard.
function M.seen(night, id)
    local t = night.th and night.th.list[id]
    local r = t and t.read
    if not r then
        return nil
    end
    local need = (r.result == "misread") and r.as or t.need
    local words = r.result == "clear" or r.result == "book" or r.result == "asked"
    return { need = need, words = words, miss = r.result == "miss" }
end

-- The answers on offer once you've read them ({ id, label }); none after a miss (ask, or let it be).
function M.answers_for(night, id)
    local t = night.th and night.th.list[id]
    local sn = t and M.seen(night, id)
    if not sn or sn.miss then
        return {}
    end
    local p = present(night, t.who)
    local v = p and vars(p) or {}
    local out = {}
    for _, aid in ipairs((DATA.needs[sn.need] or {}).answers or {}) do
        table.insert(out, { id = aid, label = util.sentence_case(util.fill(DATA.answers[aid].label, v)) })
    end
    return out
end

-- The want a read shows, in words ("Mara wants a mystery to chew on").
function M.want_of(night, id)
    local t = night.th and night.th.list[id]
    local sn = t and M.seen(night, id)
    local p = t and present(night, t.who)
    if not (sn and p) or sn.miss then
        return nil
    end
    return p.name .. " " .. util.fill(DATA.needs[sn.need].want, vars(p))
end

-- A miss: ask them straight out. They tell you (a clear read), for two table minutes, and the friend
-- who hates the spotlight squirms a little at being asked in front of everyone.
function M.ask(night, id)
    local t = night.th and night.th.list[id]
    if not (t and t.read and t.read.result == "miss") or not M.is_open(night, id) then
        return false
    end
    local p = present(night, t.who)
    t.read.result = "asked"
    local a = DATA.ask_straight
    night.table_min = (night.table_min or 0) + (a.table_min or 0)
    if p then
        if p.shy then
            score.add(p, "fun", -1)
        end
        if night.campaign then
            familiar.gain(night.campaign, p.key, "asked", night)
        end
        table.insert(night.th.queue, { kind = "narrate", style = "dm", text = util.sentence_case(util.fill(a.log, vars(p))) })
    end
    return true
end

-- What's been nagging at someone, mid-scene: the meter they care about most that's fallen furthest
-- behind (weight x shortfall), for the friend who's least happy about it. In a fight, a story lover
-- loses the thread; a fighter is already getting what they came for.
function M.brew(night, in_fight)
    local th = state(night)
    if th.by_scene[scene_index(night)] or not night.rng:chance(in_fight and 0.35 or 0.45) then
        return nil
    end
    local best, bp, bneed = 0, nil, nil
    for _, p in ipairs(night.players or {}) do
        if score.fun(p) < M.HAPPY then
            for _, k in ipairs(score.METERS) do
                local sum, n = 0, 0
                for _, o in ipairs(night.players) do
                    if o ~= p then
                        sum, n = sum + o.m[k], n + 1
                    end
                end
                local avg = n > 0 and sum / n or p.m[k]
                local short = math.max(0, 50 - p.m[k]) + 0.5 * math.max(0, avg - p.m[k])
                local h = score.weight(p, k) * short
                if (k == "spotlight" and p.shy) or (in_fight and k == "challenge") then
                    h = 0
                end
                if h > best then
                    best, bp, bneed = h, p, k
                end
            end
        end
    end
    if not bp or best < M.BREW_AT then
        return nil
    end
    if in_fight and bneed == "story" then
        bneed = "pace"
    end
    return M.think(night, bp, bneed)
end

-- The meter a friend cares about most (never the spotlight for one who hates it).
local function top_need(p)
    local best, bk = -1, "story"
    for _, k in ipairs(score.METERS) do
        local w = score.weight(p, k)
        if not (k == "spotlight" and p.shy) and w > best then
            best, bk = w, k
        end
    end
    return bk
end

-- Right after a call: the friend it cost (their own reason), the shy one who just had every eye on
-- them, or now and then the one who loved it.
function M.after(night, before, card, o)
    if not before or not night.players then
        return nil
    end
    local worst, wp, bestd, gp = 0, nil, 0, nil
    for _, p in ipairs(night.players) do
        local f = score.fun(p)
        local d = f - (before[p.key] or f)
        if d <= -3 and d < worst then
            worst, wp = d, p
        end
        if d >= 4 and f >= 66 and d > bestd then
            bestd, gp = d, p
        end
    end
    -- (Not a rules call: those have their own say at the table, game/model/night.lua's conflicts.)
    if wp and card and card.type ~= "rules" and night.rng:chance(0.6) then
        return M.think(night, wp, top_need(wp), { after = true })
    end
    local actor = night.actor
    local rolled = o and o.roll
    if actor and actor.shy and rolled and card and card.type ~= "table" and night.rng:chance(0.5) then
        return M.think(night, actor, "off_spot")
    end
    if gp and night.rng:chance(0.35) then
        return M.think(night, gp, "glow")
    end
    return nil
end

-- The week they've had, before the first scene: one friend whose mood you haven't found out yet.
function M.mood(night)
    local cands = {}
    for _, p in ipairs(night.players or {}) do
        if p.mood and p.mood ~= "fine" and not p.mood_known and DATA.needs[p.mood] then
            table.insert(cands, p)
        end
    end
    if #cands == 0 or not night.rng:chance(0.7) then
        return nil
    end
    local p = night.rng:pick(cands)
    return M.think(night, p, p.mood, { keep = true, any_scene = true })
end

-- A roll that looked convenient, or a harsh call out of nowhere: the sharpest eye wonders.
function M.doubt(night, p)
    if not p or not night.rng:chance(0.7) then
        return nil
    end
    return M.think(night, p, "fairness", { any_scene = true })
end

-- Outvoted at a fork, Pip's player decides to go it alone (the BBQ story): a beat before she does.
function M.plan(night, p)
    if not p then
        return nil
    end
    return M.think(night, p, "plan", { keep = true, any_scene = true })
end

-- What each answer does. Returns true when it landed well (Empathy), false when it backfired.
local function others(night, p, fn)
    for _, o in ipairs(night.players) do
        if o ~= p then
            fn(o)
        end
    end
end

local function owe(night, p)
    night.owed = { key = p.key, rolls = 1, cards = 1, scene = scene_index(night) }
end

M.EFFECTS = {
    next_moment = function(night, p)
        if p.shy then
            score.add(p, "fun", -4)        -- the spotlight is the last thing they wanted
            return false
        end
        owe(night, p)
        score.add(p, "fun", 3)
        return true
    end,
    ask = function(night, p)
        if p.shy then
            score.add(p, "fun", -4)
            return false
        end
        score.add(p, "spotlight", 8)
        score.add(p, "fun", 3)
        return true
    end,
    detail = function(_, p)
        score.add(p, "story", 8)
        score.add(p, "fun", 3)
        return true
    end,
    stakes = function(night, p)
        score.add(p, "challenge", 8)
        score.add(p, "fun", 2)
        others(night, p, function(o)
            if score.weight(o, "challenge") < 0.12 then
                score.add(o, "fun", -1)
            end
        end)
        return true
    end,
    hurry = function(night, p)
        score.add(p, "boredom", -6)
        score.add(p, "fun", 2)
        others(night, p, function(o)
            if score.weight(o, "story") >= 0.3 then
                score.add(o, "story", -2)
            end
        end)
        night.table_min = math.max(0, (night.table_min or 0) - 3)
        return true
    end,
    talk = function(_, p)
        score.add(p, "social", 8)
        score.add(p, "fun", 3)
        if not p.shy then
            score.add(p, "spotlight", 3)
        end
        return true
    end,
    snack = function(night, p)
        for _, o in ipairs(night.players) do
            score.add(o, "social", 4)
            score.add(o, "boredom", -4)
        end
        score.add(p, "fun", 4)
        night.had_break = true
        return true
    end,
    prize = function(_, p)
        score.add(p, "reward", 8)
        score.add(p, "fun", 2)
        return true
    end,
    spare = function(night, p)
        night.spare = p.key
        score.add(p, "fun", 3)
        score.add(p, "trust", 1)
        return true
    end,
    cheer = function(_, p)
        score.add(p, "fun", 3)
        score.add(p, "trust", 2)
        return true
    end,
    open = function(night, p)
        score.add(p, "suspicion", -6)
        score.add(p, "trust", 2)
        others(night, p, function(o)
            score.add(o, "suspicion", -2)
        end)
        return true
    end,
    own = function(night, p)
        for _, o in ipairs(night.players) do
            score.add(o, "suspicion", -3)
        end
        score.add(p, "trust", 1)
        return true
    end,
    catch_eye = function(night, p)
        local st = night.campaign.adv
        if st and st.flags then
            st.flags.pip_alone = nil
        end
        score.add(p, "fun", -2)
        others(night, p, function(o)
            score.add(o, "fun", 2)
        end)
        return true
    end,
    let_go = function(_, p)
        score.add(p, "fun", 3)
        return true
    end,
    check_in = function(_, p)
        p.mood_known = true
        score.add(p, "trust", 3)
        score.add(p, "boredom", -3)
        score.add(p, "fun", 2)
        return true
    end,
    early_break = function(night, p)
        score.add(p, "boredom", -8)
        for _, o in ipairs(night.players) do
            score.add(o, "social", 3)
        end
        night.had_break = true
        return true
    end,
    keep_light = function(_, p)
        score.add(p, "fun", 4)
        score.add(p, "boredom", -2)
        return true
    end,
    early_moment = function(night, p)
        if p.shy then
            score.add(p, "fun", -3)
            return false
        end
        owe(night, p)
        score.add(p, "fun", 2)
        return true
    end,
    news = function(night, p)
        for _, o in ipairs(night.players) do
            score.add(o, "social", 4)
        end
        score.add(p, "fun", 5)
        return true
    end,
}

-- The DM answers a thought ("let_be" lets it go). Returns true if it was answered, false if the
-- moment had passed (or it wasn't an answer to this thought), plus whether it landed well.
function M.respond(night, id, aid)
    local th = night.th
    local t = th and th.list[id]
    if not t or not M.is_open(night, id) then
        if t and not t.answered then
            t.gone = true
        end
        return false
    end
    if aid == "let_be" then
        t.answered = aid
        if t.read and t.read.result == "misread" then
            table.insert(th.dawn, t)          -- you'll realise later what it really was
        end
        return true, nil
    end
    local r = t.read or M.read(night, id)
    local ok = false
    for _, a in ipairs(M.answers_for(night, id)) do
        if a.id == aid then
            ok = true
        end
    end
    if not (r and ok) then
        return false
    end
    local p = present(night, t.who)
    local fx = M.EFFECTS[aid]
    if not (p and fx) then
        return false
    end
    t.answered = aid
    th.answered = th.answered + 1
    local good = fx(night, p)
    if r.result == "misread" then
        -- You answered the wrong thing. It did what it does; it didn't touch what they wanted.
        table.insert(th.dawn, t)
        if good then
            good = nil
        end
    end
    t.good = good
    local a = DATA.answers[aid]
    night.table_min = (night.table_min or 0) + (a.table_min or 0)
    -- What you did goes in the log at the next beat (the night is waiting between beats).
    table.insert(th.queue, { kind = "narrate", style = "dm", text = util.sentence_case(util.fill(a.log, vars(p))) })
    if good then
        table.insert(th.queue, { kind = "react", poses = { [p.key] = "lean" } })
        if not th.read and night.campaign and night.campaign.gain_empathy then
            th.read = true
            night.campaign:gain_empathy("read")
        end
        if night.campaign then
            familiar.gain(night.campaign, p.key, "good", night)
        end
    elseif good == false then
        table.insert(th.queue, { kind = "react", poses = { [p.key] = "arms" } })
        table.insert(th.queue, { kind = "narrate", style = "warn",
                                 text = p.name .. " shrinks a little in " .. vars(p).their .. " chair. Wrong call for " .. vars(p).them .. "." })
    end
    return true, good
end

-- A scene starts (or the night ends): misreads you acted on, or let be, dawn on you now.
function M.dawn(night)
    local th = night.th
    if not th or #th.dawn == 0 then
        return
    end
    local list = th.dawn
    th.dawn = {}
    for _, t in ipairs(list) do
        local p = present(night, t.who)
        if p then
            local want = util.fill(DATA.needs[t.need].want, vars(p))
            night:emit({ kind = "narrate", style = "aside",
                         text = util.sentence_case(util.fill(DATA.misread_after, { name = p.name, want = want })) })
        end
    end
end

-- The night's queue of answers, said at the next beat (night.lua's emit calls this).
function M.take_queue(night)
    local th = night.th
    if not th or #th.queue == 0 then
        return nil
    end
    local q = th.queue
    th.queue = {}
    return q
end

-- For the report and the log: what you caught and what you did about it.
function M.summary(night)
    local th = night.th
    if not th then
        return { shown = 0, answered = 0 }
    end
    local good = 0
    for _, t in pairs(th.list) do
        if t.good then
            good = good + 1
        end
    end
    return { shown = th.shown, answered = th.answered, good = good, read = th.reads or 0, clear = th.clear or 0 }
end

-- A headless DM (the sims): a careful DM reads most thoughts, asks after a miss, and answers what
-- they read, mostly well (a misread fools them too); a random one now and then; a careless one never.
-- Returns the answer given (or nil), whether it landed, and the read.
function M.bot_play(night, ev, style, rng)
    if ev.glow or #(ev.answers or {}) == 0 or style == "careless" then
        return nil
    end
    if (style == "careful" and not rng:chance(0.8)) or (style == "random" and not rng:chance(0.5)) then
        return nil
    end
    local r = M.read(night, ev.id)
    if not r then
        return nil
    end
    if r.result == "miss" then
        if style == "careful" and rng:chance(0.6) then
            M.ask(night, ev.id)
        else
            M.respond(night, ev.id, "let_be")
            return "let_be", nil, r
        end
    end
    local list = M.answers_for(night, ev.id)
    if #list == 0 then
        return nil, nil, r
    end
    local p = present(night, ev.who)
    local pick
    if style == "careful" then
        for _, a in ipairs(list) do
            local bad = p and p.shy and (a.id == "next_moment" or a.id == "ask" or a.id == "early_moment")
            if not pick and not bad then
                pick = a.id
            end
        end
    else
        pick = rng:pick(list).id
    end
    pick = pick or "let_be"
    local ok, good = M.respond(night, ev.id, pick)
    return ok and pick or nil, good, r
end

return M
