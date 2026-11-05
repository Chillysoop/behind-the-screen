-- The week in the museum (v2): starting a week, the prep board's hours and choices, and what the
-- adventure keeps after a night. Engine-free.

local content = require "game.model.content"
local util = require "game.model.util"
local score = require "game.model.score"
local adventure = require "game.model.adventure"
local events = require "game.model.events"
local prep_mod = require "game.model.prep"
local social = require "game.model.social"
local progression = require "game.model.progression"
local ties = require "game.model.ties"

local MODULE = adventure.data
local M = {}

-- Prep -----------------------------------------------------------------------------------------

-- The museum's part of the prep board: which rooms are prepped, the knobs, the boss night's plan.
-- What a DM does with hours left once every room's prepped (the playtest, November 3: "two hours of
-- prep left and nothing to spend it on"). Each is an hour, once a week; hours nobody spends carry to
-- next week (up to CARRY_MAX), set when the night starts (campaign.lua).
M.SPARE = {
    { id = "rest", cost = 1, name = "Get a good night's sleep",
      what = "+1 to every read of the table tonight (your Insight rolls on their thoughts)." },
    { id = "backup", cost = 1, name = "Write a backup page",
      what = "The first room tonight you didn't prep (a side room, a detour, one past tonight's) plays as if you had." },
}
M.CARRY_MAX = 2

function M.spare_def(id)
    for _, d in ipairs(M.SPARE) do
        if d.id == id then
            return d
        end
    end
end

function M.set_spare(prep, id, on)
    local pm = prep.museum
    local d = M.spare_def(id)
    if not d then
        return false
    end
    pm.spare = pm.spare or {}
    if on and not pm.spare[id] and prep:left() < d.cost then
        return false
    end
    pm.spare[id] = on and true or nil
    return true
end

-- The hours carried in from last week (shown on the board), and what carries out of this one.
function M.carry_out(prep)
    return math.max(0, math.min(M.CARRY_MAX, prep:left()))
end

function M.new_prep(prep, campaign)
    local carry = (campaign.adv and campaign.adv.carry) or 0
    prep.budget = MODULE.BUDGET + carry
    prep.carried = carry
    prep.museum = { prepped = {}, knobs = {}, spare = {}, ahead = adventure.ahead(campaign), boss = adventure.boss_week(campaign) }
    -- Boss week: what the rooms they never played leave on her card is there now, so the showdown
    -- board you prep against is the fight they get (the playtest, Nov 2: a knight joined her
    -- after the board said he wouldn't). Her line for each comes at the night's start.
    if prep.museum.boss then
        for _, lb in ipairs(adventure.left_behind(campaign, true)) do
            if adventure.add_mark(campaign, lb.mark, lb.room) then
                local st = campaign.adv
                st.unannounced = st.unannounced or {}
                table.insert(st.unannounced, lb.mark)
            end
        end
    end
    -- The scenes the night expects, for its pacing read: tonight's rooms in order.
    prep.scenes = {}
    for _, id in ipairs(prep.museum.ahead) do
        local r = MODULE.rooms[id]
        if not r.virtual then
            local slots = {}
            for kind, cid in pairs(r.comps or {}) do
                slots[kind] = content.components[cid]
            end
            table.insert(prep.scenes, { type = r.type, slots = slots, room = id })
        end
    end
    if prep.museum.boss then
        campaign.adv.boss = campaign.adv.boss or { opener = "talk", style = "yields" }
    end
    return prep
end

function M.room_cost(id)
    local r = MODULE.rooms[id]
    return r and r.cost or 0
end

function M.knob_cost(id, value)
    local k = MODULE.knobs[id]
    return (k and value and k.cost) or 0
end

-- Hours on the museum board: rooms prepped and knobs that need writing.
function M.spent(prep)
    local pm = prep.museum
    local total = 0
    for id, on in pairs(pm.prepped) do
        if on then
            total = total + M.room_cost(id)
        end
    end
    for id, v in pairs(pm.knobs) do
        if v then
            total = total + M.knob_cost(id, v)
        end
    end
    if pm.boss then
        total = total + M.room_cost("lair")
    end
    for id, on in pairs(pm.spare or {}) do
        local d = on and M.spare_def(id)
        if d then
            total = total + d.cost
        end
    end
    return total
end

function M.can_prep(prep, id)
    local pm = prep.museum
    if pm.prepped[id] then
        return true
    end
    return prep:left() >= M.room_cost(id)
end

function M.set_prepped(prep, id, on)
    local pm = prep.museum
    if on and not M.can_prep(prep, id) then
        return false
    end
    pm.prepped[id] = on and true or nil
    return true
end

function M.set_knob(prep, id, value)
    local pm = prep.museum
    local cur = pm.knobs[id]
    local extra = M.knob_cost(id, value) - M.knob_cost(id, cur)
    if extra > 0 and prep:left() < extra then
        return false
    end
    pm.knobs[id] = value or nil
    return true
end

-- How each friend would take a choice: like values for the knob as it stands (-2..2).
function M.knob_like(id, value)
    local k = MODULE.knobs[id]
    if not k then
        return {}
    end
    if k.pick_hero then
        return value and { [value] = 2 } or {}
    end
    return k.like
end

-- The DM bent the map in prep (game/ui/ties_view.lua: a lock set, removed or opened): tonight's
-- rooms again. Rooms and knobs no longer on the way give their hours back.
function M.reahead(prep, campaign)
    local pm = prep.museum
    if not pm then
        return
    end
    pm.ahead = adventure.ahead(campaign)
    pm.boss = adventure.boss_week(campaign)
    for id in pairs(pm.prepped) do
        if not util.contains(pm.ahead, id) then
            pm.prepped[id] = nil
        end
    end
    for kid in pairs(pm.knobs) do
        local k = MODULE.knobs[kid]
        if k and not util.contains(pm.ahead, k.room) then
            pm.knobs[kid] = nil
        end
    end
    prep.scenes = {}
    for _, id in ipairs(pm.ahead) do
        local r = MODULE.rooms[id]
        if not r.virtual then
            local slots = {}
            for kind, cid in pairs(r.comps or {}) do
                slots[kind] = content.components[cid]
            end
            table.insert(prep.scenes, { type = r.type, slots = slots, room = id })
        end
    end
    if pm.boss then
        campaign.adv.boss = campaign.adv.boss or { opener = "talk", style = "yields" }
    end
end

-- Between sessions, what came true opens the DM's locks (ties.lua): tonight's rooms again if so.
-- Called by the prep board once the questions between sessions are answered.
function M.sync_ties(prep, campaign)
    if not ties.any(campaign) then
        return false
    end
    local st = campaign.adv
    local before = #(st.lock_news or {})
    ties.week(campaign)
    local ahead = adventure.ahead(campaign)
    local same = #ahead == #(prep.museum.ahead or {})
    for i, id in ipairs(ahead) do
        same = same and prep.museum.ahead[i] == id
    end
    if not same or #(st.lock_news or {}) ~= before then
        M.reahead(prep, campaign)
        return true
    end
    return false
end

-- Prep everything that fits, in order: what a quick DM does (and the tests' bots).
function M.prep_greedy(prep)
    for _, id in ipairs(prep.museum.ahead) do
        if M.can_prep(prep, id) and M.room_cost(id) > 0 then
            M.set_prepped(prep, id, true)
        end
    end
end

-- The week -------------------------------------------------------------------------------------

-- The week they've had: real life, mostly, but a great session last week carries into it (they're
-- still buzzing, telling people about it) and a flat one sours it a little (the playtest, November 3).
function M.week_mood(rng, p)
    local order = content.moods.order
    local lf = p.last_fun
    if not lf then
        return rng:pick(order)
    end
    local tilt = lf >= 70 and { celebrating = 3, chatty = 2, tired = 0.7, distracted = 0.5, stressed = 0.8 }
        or (lf < 40 and { celebrating = 0.3, chatty = 0.7, tired = 1.4, distracted = 2, stressed = 1.2 }) or {}
    local weights = {}
    for i, m in ipairs(order) do
        weights[i] = tilt[m] or 1
    end
    return rng:weighted(order, weights)
end

function M.start_week(c)
    c.week = c.week + 1
    local rng = c.rng
    c.empathy_up = nil
    c.looked = nil
    for _, p in ipairs(c.players) do
        p.mood = M.week_mood(rng, p)
        p.mood_known = false
        -- The prologue is short and everyone's keen: the whole table comes every week.
        p.on_break = false
        p.present = true
    end
    c.new_chars = require("game.model.death").start_week(c)
    -- The DM's locks: anything that came true by now opens before the board is dealt (ties.lua).
    ties.week(c)
    c.prep = prep_mod.new(c)
    M.new_prep(c.prep, c)
    c.leveled_now = nil
    social.start_week(c)
    progression.start_week(c)
    -- (The questions first: the chat posts this week's requests, not last week's answered ones.)
    c.adv.prompts = adventure.prompts(c)
    c.chat = M.write_chat(c)
    c.night = nil
    c.report = nil
    return c.prep
end

-- What last night did to each of them, in their own words for the chat (the playtest, Nov 2: the
-- chat was word for word every run; the third playtest, alive 9: it was still a script, quoting the
-- DM's card titles nobody at the table ever saw). Written from what happened: a hero lost, a hero on
-- the floor (as many times as they really were), the last hit, a fight that went against them, being
-- overruled, the moment that made or spoiled their night in the party's own words ("when we gave the
-- knight a wide berth"), a hero's reason for coming paid off (one post, however many), Pip caught at
-- it. One post a moment, the biggest first. Returns { key = text }, and the kind of each.
local function strip(t)
    return string.lower((string.gsub(t or "", "[\"%[%]]", "")))
end
M.CHAT = {
    -- (Not the hero who died's pronoun for the new one, nor "they" for one person: the new hero isn't
    -- rolled up yet. Round three's merge: "rolling up someone new, be nice to her" of a new he.)
    lost_hero = { "still not over {was}. rolling up someone new, be nice to the new kid", "rip {was}. new character incoming. worse at everything, guaranteed",
                  "{was} deserved better. new character incoming" },
    lost_hero_reply = { "{was} deserved better tbh", "pouring one out for {was}", "we will remember {was}" },
    down_once = { "{char} hit the floor and i'm still annoyed about it", "next time {char} is standing at the back", "{char} took a nap on the floor. not by choice" },
    down_twice = { "{char} went down TWICE. i want a refund", "two times on the floor for {char}. two", "{char} spent half the night on the floor. twice" },
    down_many = { "{char} went down {n} times. {n}", "{char} was on the floor more than standing up", "i lost count of how often {char} went down. {n}?" },
    kill = { "for the record, that last hit was {char}'s", "just saying. {char}. last hit. that's all", "who landed the last hit? {char}. thank you" },
    lost_fight = { "we got absolutely flattened", "that fight went so badly. i loved it. i hated it", "we lost that one. no notes. many notes" },
    overruled_more = { "the DM kept nudging us places. felt a bit on rails ngl", "felt a bit on rails ngl", "a lot of nudging this week. just saying" },
    overruled = { "still think we should've gone the other way", "the DM nudged us the other way, noted", "we went the way the DM wanted. fine" },
    best = { "when {what}. more of that please", "can we talk about when {what}", "still buzzing about when {what}", "best bit: when {what}" },
    worst = { "when {what}... not my favourite", "not gonna lie, when {what} kind of killed it for me", "not a fan of when {what}, if i'm honest" },
    hook = { "{chars} finally found what {chars_they} came for. emotional", "ok {chars}'s whole reason for coming paid off and i'm thrilled",
             "{chars} got {chars_their} answer. i'm not crying", "the bit where {chars} found what {chars_they} came for. chef's kiss" },
    hooks = { "{chars} got what they came for. emotional", "{n} whole reasons for coming paid off in one night", "{chars} found what they came for. i'm thrilled" },
    caught = { "in my defence {thing} was RIGHT THERE", "{char} got caught. {char} regrets nothing", "ok so {who} saw. it's fine. it's fine" },
}
-- The answers to a post: what it was about, not "that bit was SO good" to anything.
M.CHAT_REPLY = {
    lost_hero = { "we will avenge them", "rip", "nooo" },
    down = { "rip", "{char} was very brave on that floor", "we'll get you a helmet" },
    kill = { "the stats don't lie", "fine. FINE. it was {char}", "taking that to the grave huh" },
    lost_fight = { "we'll get them next time", "it was very funny from where i was sitting", "never again lol" },
    overruled = { "noted", "next time we vote harder", "valid" },
    best = { "honestly same", "that bit was SO good", "still thinking about it", "it really was" },
    worst = { "fair", "yeah that one dragged", "we don't talk about that" },
    hook = { "SAME", "it really was", "i saw the face you made. you were thrilled" },
    caught = { "pip. PIP.", "we're never going back to that shop", "the boot knows" },
    room = { "lol", "real", "honestly yeah", "100%", "same", "ha. yes", "this is so true", "can't stop thinking about it either" },
    news = { "CONGRATS", "oh that's amazing!!", "wait WHAT. congrats!!", "bringing cake thursday then" },
}
M.REPLY = M.CHAT_REPLY      -- (for the roadmap words check)

-- The party's own words for a moment, from the log: "we gave the knight a wide berth", "pip fished a
-- little brass key out of the pond" (lowercase, as the chat writes).
local function in_our_words(c, card, week)
    local ev = card and events.last(c, { kind = "moment", card = card, session = week })
    local t = ev and ev.text
    if not t then
        return nil
    end
    t = string.gsub(t, "^they ", "we ")
    t = string.gsub(t, "%f[%a]them%f[%A]", "us")
    return string.lower(t)
end

function M.night_lines(c, night)
    local out, kinds, vars_of = {}, {}, {}
    if not night then
        return out, kinds, vars_of
    end
    local week = c.week - 1
    local rng = c.rng
    -- (Fresh across weeks, and never the same words twice running: night.fresh's memory, keyed by the
    -- kind of post. R3, the second playtest review: the same three chat lines most weeks.)
    local function put(key, kind, vars)
        local p = c:player(key)
        if p and not out[key] then
            vars = vars or {}
            vars.char = vars.char or string.lower(p.char or "")
            vars.name = p.name
            local pick = M.fresh_line(c, M.CHAT[kind], "chat_" .. kind)
            out[key] = util.fill(pick, vars)
            kinds[key] = kind
            vars_of[key] = vars
        end
    end
    -- A hero lost.
    for key, nc in util.sorted_pairs(c.new_char or {}) do
        if nc.week == week and nc.was then
            local was = string.lower(nc.was)
            put(key, "lost_hero", { was = was })
            for _, q in ipairs(c.players) do
                if q.key ~= key and not out[q.key] then
                    put(q.key, "lost_hero_reply", { was = was })
                    break
                end
            end
        end
    end
    local downs, kb = {}, {}
    for _, e in ipairs(night.ledger or {}) do
        if e.ev == "down" and e.who then
            downs[e.who] = (downs[e.who] or 0) + 1
        elseif e.ev == "killing_blow" and e.who then
            kb[e.who] = true
        end
    end
    for key, n in util.sorted_pairs(downs) do
        put(key, n >= 3 and "down_many" or (n == 2 and "down_twice") or "down_once", { n = util.int(n) })
    end
    for key in util.sorted_pairs(kb) do
        put(key, "kill")
    end
    -- A fight that went against them (one post, from whoever minded most).
    local lost = events.last(c, { kind = "fight", session = week, outcome = "lost" })
    if lost then
        local worst, wd
        for _, p in ipairs(c.players) do
            local d = score.fun(p)
            if not out[p.key] and (not wd or d < wd) then
                worst, wd = p, d
            end
        end
        if worst then
            put(worst.key, "lost_fight")
        end
    end
    -- (Overruled: the one it happened to most says so. Three people saying it is a pile-on.)
    local most, mn
    for key, n in util.sorted_pairs((night.mus and night.mus.overruled) or {}) do
        if not out[key] and (not mn or n > mn) then
            most, mn = key, n
        end
    end
    if most then
        put(most, mn >= 2 and "overruled_more" or "overruled")
    end
    -- Pip caught with her hand in someone's stock.
    local caught = events.last(c, { kind = "steal", session = week, outcome = "caught" })
    if caught and caught.who then
        local thing, who = string.match(caught.text or "", " went for (.-), and (.-) caught ")
        if thing and who then
            put(caught.who, "caught", { thing = string.lower(thing), who = string.lower(who) })
        end
    end
    -- The call that moved them most, either way: in the party's words, never the card's title. (One
    -- moment, one post: two friends who loved the same call don't both post it.)
    local said_moment = {}
    for _, p in ipairs(c.players) do
        local best, bd
        for _, cl in ipairs(night.call_log or {}) do
            local d = cl.deltas[p.key]
            if d and math.abs(d) >= 6 and (not bd or math.abs(d) > math.abs(bd)) and not said_moment[cl.card or cl.title] then
                best, bd = cl, d
            end
        end
        local what = best and in_our_words(c, best.card, week)
        if what and not out[p.key] then
            said_moment[best.card or best.title] = true
            put(p.key, bd > 0 and "best" or "worst", { what = what })
        end
    end
    -- Their reasons for coming, paid off: one post, from one of them, however many there were.
    local paid = {}
    for key, wk in util.sorted_pairs(c.adv.hook_paid or {}) do
        local p = c:player(key)
        if wk == week and p then
            table.insert(paid, p)
        end
    end
    if #paid > 0 then
        local poster
        for _, p in ipairs(paid) do
            poster = poster or (not out[p.key] and p) or nil
        end
        if poster then
            local names = {}
            for _, p in ipairs(paid) do
                table.insert(names, string.lower(p.char))
            end
            local chars = util.join_names(names)
            put(poster.key, #paid > 1 and "hooks" or "hook", { chars = chars, n = ({ "two", "two", "three", "four" })[#paid] or util.int(#paid), chars_they = #paid > 1 and "they" or util.pronoun_of(paid[1].char).they,
                                                              chars_their = #paid > 1 and "their" or util.pronoun_of(paid[1].char).their })
        end
    end
    return out, kinds, vars_of
end

-- The group chat (the playtest, November 3: "have the group chat feel more naturally like dialogue
-- between the group; mix in some lore / casual questions to the DM"). Last night's own events and
-- the rooms, each answered by someone else; a bit of everyday chat; and now and then a question for
-- you (MODULE.chat_ask: answer it from the prep board). Requests are private messages now, one-on-one
-- with you (adventure.prompts), not posts to the group.

-- A line for the group chat that hasn't been posted lately (night.fresh's campaign memory).
function M.fresh_line(c, lines, key)
    local night_mod = util.lazy("game.model.night")
    return night_mod.fresh({ campaign = c, rng = c.rng }, lines, key)
end

-- Which question for you this week: one that fits what's going on (the gorgon's strength once she's
-- close, the healing rule after someone went down), else any still unasked, by the table's own luck.
-- (The third playtest: the same questions in the same order in 24 runs of 24.)
local ASK_FITS = {
    sam_rules = function(c) return events.any(c, { kind = "fight", session = c.week - 1 }) end,
    gorgon_strength = function(c) return (c.adv.done or {}).stairs ~= nil or (c.adv.flags or {}).truth end,
    brannoc_gorgons = function(c) return (c.adv.done or {}).hunting ~= nil end,
    telpur_deal = function(c) return (c.adv.done or {}).gift_shop ~= nil end,
}

-- A sad week: last night a hero died, the whole party went down, they lost someone fighting beside
-- them (what game night's able.somber goes quiet for, read here from the log, so a loaded save knows
-- it too), or the party lost a fight. The chat says what happened and answers it; nobody posts their
-- favourite bit, the rooms' jokes or the week's small talk.
function M.somber(c)
    local week = (c.week or 1) - 1
    for _, kind in ipairs({ "death", "wipe", "lost" }) do
        if events.any(c, { kind = kind, session = week }) then
            return true
        end
    end
    for _, nc in pairs(c.new_char or {}) do
        if nc.week == week and nc.was then
            return true      -- (a save from before deaths were in the log)
        end
    end
    if events.any(c, { kind = "fight", session = week, outcome = "lost" }) then
        return true
    end
    return false
end

function M.write_chat(c)
    local st = c.adv
    local msgs = {}
    local sad = M.somber(c)
    local said = {}
    local rng = c.rng
    -- Someone else at the table answers a post (not the one who made it, and not the same friend twice
    -- running), about what it said.
    local replied_by = {}
    local function reply_to(m, kind, vars)
        local cands = {}
        for _, q in ipairs(c.players) do
            if q.key ~= m.key and not replied_by[q.key] then
                table.insert(cands, q)
            end
        end
        if #cands == 0 then
            return
        end
        local q = cands[rng:int(1, #cands)]
        replied_by[q.key] = true
        local list = M.CHAT_REPLY[kind] or M.CHAT_REPLY.room
        table.insert(msgs, { who = q.name, key = q.key, text = util.fill(M.fresh_line(c, list, "chat_reply_" .. (M.CHAT_REPLY[kind] and kind or "room")), vars or {}),
                             reply = true })
    end
    local REPLY_KIND = { lost_hero = "lost_hero", down_once = "down", down_twice = "down", down_many = "down", kill = "kill", lost_fight = "lost_fight",
                         overruled = "overruled", overruled_more = "overruled", best = "best", worst = "worst", hook = "hook", hooks = "hook", caught = "caught" }
    -- Last night's own events first (three at most), then the rooms.
    local own, kinds, vars_of = M.night_lines(c, c.night)
    local posts = 0
    for _, p in ipairs(c.players) do
        if own[p.key] and posts < 3 and not (sad and (kinds[p.key] == "best" or kinds[p.key] == "kill")) then
            said[p.key] = true
            posts = posts + 1
            local m = { who = p.name, key = p.key, text = own[p.key] }
            table.insert(msgs, m)
            if posts <= 2 and kinds[p.key] ~= "lost_hero_reply" then
                reply_to(m, REPLY_KIND[kinds[p.key]], vars_of[p.key])
            end
        end
    end
    -- Good news that never came out at the table comes out here.
    local night = c.night
    if night and night.th then
        for _, t in ipairs(night.th.list or {}) do
            local p = c:player(t.who)
            if t.need == "celebrating" and p and not (night.news_told or {})[t.who] and not said[t.who] and MODULE.chat_news and MODULE.chat_news[t.who] then
                said[t.who] = true
                local m = { who = p.name, key = p.key, text = M.fresh_line(c, MODULE.chat_news[t.who], "chat_news_" .. t.who) }
                table.insert(msgs, m)
                reply_to(m, "news")
            end
        end
    end
    -- The rooms they played: what happened there, each friend at most once, two posts at most.
    local last = {}
    for _, step in ipairs(st.path) do
        if step.week == c.week - 1 then
            table.insert(last, step)
        end
    end
    local room_posts = 0
    for _, step in ipairs(last) do
        local fight = events.last(c, { kind = "fight", where = step.room, session = step.week })
        for k, e in ipairs(MODULE.chat[step.room] or {}) do
            local p = c:player(e.who)
            local ok = not sad and p and not said[e.who] and room_posts < 2 and posts < 5 and adventure.test(c, e.when)
                and not (e.won and not (fight and fight.outcome == "won")) and not (e.lost and not (fight and fight.outcome == "lost"))
            if ok then
                said[e.who] = true
                posts, room_posts = posts + 1, room_posts + 1
                local text = util.fill(M.fresh_line(c, e, "chat_room_" .. step.room .. "_" .. k), { mech = st.mech_name or "the robot" })
                local m = { who = p.name, key = e.who, text = text }
                table.insert(msgs, m)
                if room_posts == 1 and posts <= 3 then
                    reply_to(m, "room")
                end
            end
        end
    end
    if c.week == 1 then
        local intros = MODULE.chat_intro or {}
        local intro = intros[((c.seed or 0) % math.max(1, #intros)) + 1] or {}
        for _, l in ipairs(intro) do
            local p = c:player(l[1])
            if p then
                table.insert(msgs, { who = p.name, key = l[1], text = l[2] })
            end
        end
    end
    -- The everyday bit: snacks, timing, someone's week.
    local banter = {}
    for _, b in ipairs(MODULE.chat_banter or {}) do
        if c:player(b[1]) and (not b.week or b.week == c.week) and (not b.when or adventure.test(c, b.when)) then
            table.insert(banter, b)
        end
    end
    if #banter > 0 and c.week > 1 and not sad then
        local b = banter[((c.week * 7 + (c.seed or 0)) % #banter) + 1]
        table.insert(msgs, { who = c:player(b[1]).name, key = b[1], text = b[2] })
        -- Who said they'd be late, and why: game night's arrivals say the same (night.behavior_line_ok).
        if b.late then
            st.late = { week = c.week }
            for k, why in pairs(b.late) do
                st.late[k] = why
            end
        end
        -- What they said they bought is what they bring (the playtest, November 3: Sam's green dice
        -- were still grey on the table).
        if b.dice then
            local ds = require "game.model.dice_sets"
            if ds.data.SETS[b.dice] then
                ds.get(c).players[b[1]] = b.dice
                ds.get(c).bought = { key = b[1], set = b.dice, week = c.week }   -- (and they show off these: dice_sets.show_off)
            end
        end
        if b[3] and b[4] and c:player(b[3]) then
            table.insert(msgs, { who = c:player(b[3]).name, key = b[3], text = b[4], reply = true })
        end
    end
    -- A question for you (one a week, each once): one that fits what's going on, else any still unasked.
    st.chat_asked = st.chat_asked or {}
    local open, fits = {}, {}
    for _, q in ipairs(MODULE.chat_ask or {}) do
        if not st.chat_asked[q.id] and c:player(q.who) and c.week >= (q.from or 1) and (not q.when or adventure.test(c, q.when)) then
            table.insert(open, q)
            if ASK_FITS[q.id] and ASK_FITS[q.id](c) then
                table.insert(fits, q)
            end
        end
    end
    -- (The first question of all, and Pip's pet the week it's first open, keep their places: the pet
    -- joins from a yes.)
    local q
    for _, x in ipairs(open) do
        if x.id == "flit_wizard" or (x.id == "pip_pet" and c.week == (x.from or 1)) then
            q = q or x
        end
    end
    q = q or (#fits > 0 and fits[rng:int(1, #fits)]) or (#open > 0 and open[rng:int(1, #open)]) or nil
    if q then
        st.chat_asked[q.id] = c.week
        table.insert(msgs, { who = c:player(q.who).name, key = q.who, text = q.text, ask = q.id })
    end
    return msgs
end

-- The DM answers a question in the group chat (MODULE.chat_ask): the reply goes in the chat, and
-- the friend who asked takes it the way the answer lands.
function M.answer_chat(c, m, i)
    local q
    for _, d in ipairs(MODULE.chat_ask or {}) do
        if d.id == m.ask then
            q = d
        end
    end
    local r = q and q.replies[i]
    if not r or m.answered then
        return false
    end
    m.answered = i
    local p = c:player(q.who)
    if p then
        for stat, v in pairs(r.effects or {}) do
            score.add(p, stat, v)
        end
    end
    -- (Your answer, then theirs: in the chat, after the question.)
    local at = #c.chat + 1
    for k, mm in ipairs(c.chat) do
        if mm == m then
            at = k + 1
        end
    end
    -- (A yes to a pet: they're with the party from the next night. "If they can find one": the next
    -- time their owner looks around. companions.lua)
    if r.companion then
        require("game.model.companions").join(c, r.companion)
    elseif r.companion_find then
        c.adv = c.adv or {}
        c.adv.companion_find = r.companion_find
    end
    table.insert(c.chat, at, { who = "You", key = "dm", text = r.say })
    if r.back and p then
        table.insert(c.chat, at + 1, { who = p.name, key = p.key, text = r.back, reply = true })
    end
    return true
end

-- What prepping a room really means (for the board): the minis to put out (the room's own fight,
-- or her card's on boss night), the people you'll voice, the props and handouts, and where a
-- Session Zero ask meets what's in it. Returns a list of { kind, text }.
function M.room_prep(c, id)
    local r = MODULE.rooms[id]
    local out = {}
    local ids = r.encounter
    if id == "lair" then
        ids = adventure.boss_encounter(c).ids
    end
    if ids and #ids > 0 then
        local monsters = require "game.rules.data.monsters"
        local count, order = {}, {}
        for _, mid in ipairs(ids) do
            if not count[mid] then
                table.insert(order, mid)
            end
            count[mid] = (count[mid] or 0) + 1
        end
        local bits = {}
        for _, mid in ipairs(order) do
            local m = monsters[mid]
            local raw = m and m.name or mid
            if count[mid] == 1 and string.find(raw, "^The %u") then
                -- (One of a kind by name: "the Lecturer", not "1 the lecturer", the third playtest.)
                table.insert(bits, "the " .. string.sub(raw, 5))
            else
                local name = string.lower(raw)
                table.insert(bits, util.int(count[mid]) .. " " .. name .. ((count[mid] > 1 and not string.find(name, "s$")) and "s" or ""))
            end
        end
        table.insert(out, { kind = "minis", text = (r.optional_fight and "If it comes to a fight: " or "Minis: ") .. table.concat(bits, ", ") })
    end
    local pn = MODULE.prep_notes and MODULE.prep_notes[id] or {}
    for _, v in ipairs(pn.voices or {}) do
        table.insert(out, { kind = "voice", text = "Voice for " .. v })     -- (not "Voice: Flitwidget: quick...")
    end
    if pn.handouts and #pn.handouts > 0 then
        table.insert(out, { kind = "handout", text = "Have ready: " .. util.join_names(pn.handouts) })
    end
    local t = c.table or {}
    for tag, rooms in util.sorted_pairs(MODULE.content or {}) do
        local what = rooms[id]
        local key = what and ((t.lines and t.lines[tag]) or (t.veils and t.veils[tag]) or (t.pushed and t.pushed[tag]))
        local p = key and c:player(key)
        if p then
            local how = (t.lines and t.lines[tag]) and "line" or ((t.veils and t.veils[tag]) and "veil" or "ask, which you pushed back on")
            local plan = (how == "line" and ", so you'll leave it out altogether") or (how == "veil" and ", so you'll keep it off screen")
                or ", and it plays as written"
            table.insert(out, { kind = "ask", text = p.name .. "'s " .. how .. ": " .. what .. plan })
        end
    end
    return out
end

-- After the night: what the adventure keeps, and the report's museum section.
function M.after_night(c, night, rep)
    local st = c.adv
    local mus = night.mus or {}
    -- Out of sessions with Euryale still upstairs: the book's quiet ending (Flitwidget moves on).
    if not st.ending and c.week >= MODULE.MAX_WEEKS then
        st.ending = "timeout"
    end
    rep.museum = {
        rooms = mus.rooms or {},
        marks = mus.added or {},
        warned = require("game.model.warnings").count(c), harsh = mus.harsh_log or {},
        where = adventure.where(c),
        ending = st.ending,
        francs = st.francs,
        calls = night.top_calls and night:top_calls(5) or {},   -- (your calls tonight that moved them most)
        francs_tonight = mus.francs_earned or 0,          -- (earned tonight, whatever was spent)
        francs_spent = math.max(0, (mus.francs_start or st.francs or 0) + (mus.francs_earned or 0) - (st.francs or 0)),
        got = mus.got or {},
    }
    -- From the event log (R7, R14): what was lifted tonight (it's in someone's pack, and the report says
    -- so), and the night told as a chain of what led to what, with how well it hangs together.
    local events = require "game.model.events"
    rep.museum.lifted = {}
    for _, ev in ipairs(events.find(c, { kind = "steal", outcome = "got", session = c.week })) do
        table.insert(rep.museum.lifted, { text = ev.text, who = ev.who, thing = ev.thing })
    end
    rep.museum.chain = (events.chain(c, c.week))
    rep.museum.measure = events.measure(c, c.week)
    if night.ended_on_cliff then
        rep.museum.stopped = c.last_cliff
    end
end

-- Level-ups come at the book's milestones: the gift shop (level 3), and the end (level 4).
function M.level_ready(c)
    local st = c.adv
    if not st then
        return nil
    end
    if c.level == 2 and st.done.gift_shop then
        return true
    end
    if c.level == 3 and st.ending then
        return true
    end
    return false
end

-- Is the prologue over (the scrapbook comes next)?
function M.done(c)
    local st = c.adv
    return st and (st.ending ~= nil or c.week >= MODULE.MAX_WEEKS)
end

return M
