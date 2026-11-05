-- Round three, batch A: state and fights (the third playtest, five fresh-eyes reviews of e691363).
-- Alive, down, stone, charmed and dead gate everything; friendly fire said aloud; what's destroyed
-- stays destroyed; the big payoffs narrated; the DM's targeting steers the foes; no browsing after a
-- wipe; recaps lead with the losses; the break at a lull and a late night that costs. Played: the
-- seeds and DMs the reviews named, exactly as the sim plays them, plus whole prologues over more
-- seeds and targeted cases. Run from the project root:
--     lua tools/tests/round3_state_check.lua [extra seeds per style]
-- Prints one line per item: what was seen, and FAIL lines where play contradicts the fix.

package.path = "./?.lua;./tools/tests/?.lua;" .. package.path
unpack = unpack or table.unpack

local adventure = require "game.model.adventure"
local campaign_mod = require "game.model.campaign"
local social = require "game.model.social"
local museum_week = require "game.model.museum_week"
local util = require "game.model.util"
local events_mod = require "game.model.events"

local EXTRA = tonumber(arg[1]) or 2
local ITEMS = { "run", "A1", "A2", "A3", "A4", "A5", "A6", "A7", "A8" }
local NAMES = {
    run = "whole prologues",
    A1 = "who can't act doesn't", A2 = "friendly fire is said", A3 = "destroyed stays destroyed",
    A4 = "the big payoffs are told", A5 = "the DM's picks steer the foes", A6 = "no browsing after a loss",
    A7 = "recaps lead with the losses", A8 = "the break at a lull, a late night costs",
}

local fails = {}
local function fail(item, msg)
    fails[item] = fails[item] or { n = 0 }
    if #fails[item] < (tonumber(os.getenv("SHOW")) or 8) then
        table.insert(fails[item], msg)
    end
    fails[item].n = fails[item].n + 1
end
local E = {}
local function add(item, key, n)
    E[item] = E[item] or {}
    E[item][key] = (E[item][key] or 0) + (n or 1)
end
local function case(item, fn)
    local ok, err = pcall(fn)
    if not ok then
        fail(item, "error: " .. tostring(err))
    end
end

-- The sim's own play (tools/sim/museum.lua), step for step, so a seed and a style here play exactly
-- the night the reviews read. `on` gets every event with the night it came from.
local function sim_play(seed, style, on)
    adventure.enter()
    local c = campaign_mod.new(seed)
    adventure.enter(c)
    c:session_zero(social.default_choices())
    local rng = require("game.model.rng").new(seed + 77)
    for _, key in ipairs({ "mara", "dev", "jess", "sam" }) do
        local hooks = adventure.data.hooks[key]
        adventure.set_hook(c, key, hooks[rng:int(1, #hooks)].id)
    end
    local R = { c = c, tag = "seed " .. seed .. " " .. style, weeks = {} }
    for w = 1, adventure.data.MAX_WEEKS do
        local prep = c:start_week()
        local pm = prep.museum
        for _, m in ipairs(c.chat) do
            if m.ask and not m.answered then
                museum_week.answer_chat(c, m, (style == "careful") and 1 or rng:int(1, 3))
            end
        end
        if on.chat then
            on.chat(R, c, w)
        end
        for _, pr in ipairs(c.adv.prompts) do
            if pr.kind == "request" then
                adventure.answer_request(c, pr.id, adventure.data.ANSWERS[style == "careful" and 2 or rng:int(1, 4)])
            elseif pr.kind == "loose" then
                adventure.answer_loose(c, pr.id, 1)
            elseif pr.kind == "ruling" then
                adventure.answer_ruling(c, pr.id, style ~= "careless")
            elseif pr.kind == "favor" then
                adventure.answer_favor(c, pr.id, 1, 1)
            end
        end
        if style ~= "careless" then
            museum_week.prep_greedy(prep)
            for _, id in ipairs(pm.ahead) do
                for _, kid in ipairs(adventure.data.rooms[id].knobs or {}) do
                    local k = adventure.data.knobs[kid]
                    museum_week.set_knob(prep, kid, k.pick_hero and "mara" or (rng:chance(0.6) or nil))
                end
            end
        end
        if pm.boss then
            c.adv.boss = { opener = rng:chance(0.7) and "talk" or "ambush", style = rng:chance(0.6) and "yields" or "last" }
        end
        local night = c:start_night()
        R.night, R.week = night, w
        if on.night then
            on.night(R, night, w)
        end
        local ev = night:advance()
        local guard = 0
        while ev.kind ~= "done" and guard < 4000 do
            guard = guard + 1
            if on.ev then
                on.ev(R, night, ev, w)
            end
            local answer
            if ev.kind == "decision" then
                local opts = ev.card.options
                local pick = (style == "careful") and 1 or rng:int(1, #opts)
                if style == "careful" and string.find(ev.card.id or "", "^table_asks_") then
                    pick = #opts
                end
                if style == "careful" and opts[pick] and opts[pick].cost then
                    local hp, max, down = 0, 0, false
                    for _, pc in ipairs(night.pc_list or {}) do
                        hp, max = hp + math.max(0, pc.hp or 0), max + (pc.hp_max or 0)
                        down = down or ((pc.hp or 1) <= 0 and not pc.dead)
                    end
                    if not down and hp > 0.35 * max then
                        for i, o in ipairs(opts) do
                            if not o.cost and not o.disabled then
                                pick = i
                                break
                            end
                        end
                    end
                end
                if opts[pick].disabled then
                    pick = 1
                end
                if on.pick then
                    pick = on.pick(R, night, ev, pick) or pick
                end
                answer = pick
            elseif ev.kind == "thought" then
                require("game.model.thoughts").bot_play(night, ev, style, rng)
            elseif ev.kind == "ruling" then
                answer = 1
            elseif ev.kind == "improv" then
                answer = { 1 }
            elseif ev.kind == "roll_where" then
                answer = "open"
            elseif ev.kind == "roll" then
                answer = rng:d20()
            end
            ev = night:advance(answer)
        end
        local rep = c:finish_night()
        R.rep = rep
        if on.after then
            on.after(R, night, rep, w)
        end
        c:level_up()
        if adventure.over(c) then
            break
        end
    end
    R.ending = c.adv.ending
    return R
end

-- A1: who can't act doesn't ---------------------------------------------------------------------
-- At every event, each hero's state on the mat right now: dead, down, stone (or charmed or out of
-- it, while a fight's on). A hero who can't act gets no line in character, no check, no card that
-- has them doing something, no small roll and no twist; their player talks as themselves.

-- The check's own reading of the mat (not game/model/able.lua's, so it can be run against old code):
-- dead, down, stone, or, while a fight's on, charmed or out of it.
local able = {}
function able.state(night, key)
    if night.watching and night.watching[key] then
        return "dead"
    end
    local pc = night.pcs and night.pcs[key]
    if not pc then
        return nil
    end
    if pc.dead then
        return "dead"
    elseif pc.down or (pc.hp or 1) <= 0 then
        return "down"
    end
    for _, e in ipairs(pc.effects or {}) do
        if e.stone then
            return "stone"
        end
    end
    if night.battle then
        for _, e in ipairs(pc.effects or {}) do
            if e.charmed_by and not e.charmed_by.dead and not e.charmed_by.removed then
                return "charmed"
            end
        end
        for _, e in ipairs(pc.effects or {}) do
            local cd = e.conds
            if cd and (cd.incapacitated or cd.unconscious or cd.paralyzed) then
                return "out"
            end
        end
    end
    return nil
end
-- Lines about a hero who can't act, not them acting.
local ABOUT = { " is stone", " cracks out", " crack out", " comes round", " goes down", " is dead", " died", " dies",
                " shakes it off", " is down", " hesitates", " can't bring", " is still under", " sits down",
                " is out", " gets last words", " won't fight", " lies ", " is on the floor", " is gone",
                " turns to stone", " starts turning", " is turning", " stays stone", " stops moving",
                " is a statue", " goes still", " slumps", " drops", " falls", " is caught", " goes grey", " lowers",
                " smiles at", " is up", " gets back up", " is on " }
function able.about_them(text, char)
    local rest = string.sub(text, #char + 1)
    for _, pat in ipairs(ABOUT) do
        if string.sub(rest, 1, #pat) == pat then
            return true
        end
    end
    return string.sub(rest, 1, 2) == "'s"
end
-- The table's whoops and brags: none on a night a hero died.
able.CHEER = { victory = true, crit = true, kill = true, cheer_other = true, scene_like = true, big_hit = true,
               fight_chat = true, hit = true, boss_appears = true, thanks = true }

-- A line said from one of a table's templates ({fills} match anything).
local function from(list, text)
    for _, t in ipairs(list or {}) do
        local pat = "^" .. string.gsub(string.gsub(t, "[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%0"), "{[%w_']+}", ".-") .. "$"
        if string.find(text or "", pat) then
            return true
        end
    end
    return false
end
-- Cards that are about the hero who can't act, not them acting: allowed.
local ABOUT_THEM = { hero_dies = true, fallen_seat = true, last_save = true, death_roll = true, potion = true,
                     dragging = true, cornered = true, boss_turn = true }
-- Cards that are a move in the fight: not for a charmed hero either.
local FIGHT_MOVE = { flanking = true, stunt = true }
-- The table's own lines that have the speaker's hero doing something ("I'm moving my mini", "Hang on,
-- I'm coming!"): not from a player whose hero can't act. (down_self is them going down.)
local ACTING = { fight_chat = true, ally_down = true, turn = true, hit = true, miss = true, kill = true, crit = true,
                 big_hit = true, spell = true, heal_cast = true, victory = true, scene_like = true, check_win = true,
                 check_lose = true, banter = true, npc_talk = true, talk_reply = true }
local function trigger_of(line)
    if type(line) ~= "string" then
        return nil
    end
    return string.match(line, "^made%.([%w_]+)%.") or string.match(line, "^([%w_]+)%.")
end
local function char_of(night, key)
    local p = night.campaign:player(key)
    return p and p.char
end
local function names_them(text, char)
    -- (The card names the hero doing something, not something said about them.)
    local i = string.find(text or "", char, 1, true)
    while i do
        local before = i == 1 or string.match(string.sub(text, i - 1, i - 1), "[^%w]")
        if before and not able.about_them(string.sub(text, i), char) then
            return true
        end
        i = string.find(text, char, i + #char, true)
    end
    return false
end
local function gate(R, night, ev, w)
    local function state(key)
        return key and able.state(night, key) or nil
    end
    local where = R.tag .. " W" .. w
    if ev.kind == "say" and not ev.farewell then
        local s = state(ev.who)
        local tr = trigger_of(ev.line)
        if s and s ~= "charmed" and (ev.ic or (tr and ACTING[tr])) and tr ~= "down_self" then
            fail("A1", where .. ": " .. tostring(char_of(night, ev.who)) .. " is " .. s .. ", but " .. ev.who .. " says ("
                .. tostring(tr or (ev.ic and "in character")) .. "): " .. ev.text)
        end
        add("A1", "lines")
    elseif ev.kind == "decision" and ev.actor then
        local s = state(ev.actor)
        local ch = char_of(night, ev.actor)
        local bad = s and not ABOUT_THEM[ev.card.id]
            and ((s ~= "charmed" and ch and names_them(ev.card.text, ch)) or FIGHT_MOVE[ev.card.id])
        if bad then
            fail("A1", where .. ": " .. tostring(ch) .. " is " .. s .. ", but gets the card " .. tostring(ev.card.id) .. " '"
                .. tostring(ev.card.title) .. "': " .. tostring(ev.card.text))
        end
        add("A1", "cards")
    elseif ev.kind == "check" or ev.kind == "ruling" or ev.kind == "tiny_roll" then
        local key = ev.actor or ev.who
        local s = state(key)
        if s and s ~= "charmed" then
            fail("A1", where .. ": " .. tostring(char_of(night, key)) .. " is " .. s .. ", but rolls: " .. tostring(ev.text or ev.skill_name or ev.skill))
        end
        add("A1", "rolls")
    elseif ev.kind == "narrate" and ev.style == "dm" and ev.text then
        -- (A thought you answered by having their hero do something: not a hero who can't act.)
        local TA = require("game.data.thoughts").answers
        for _, aid in ipairs({ "talk", "ask", "detail", "prize" }) do
            if from({ TA[aid].log }, ev.text) then
                for _, p in ipairs(night.players) do
                    local s = state(p.key)
                    if s and s ~= "charmed" and string.find(ev.text, p.char, 1, true) then
                        fail("A1", where .. ": " .. p.char .. " is " .. s .. ", but you answer a thought with: " .. ev.text)
                    end
                end
            end
        end
    elseif ev.kind == "narrate" and (ev.style == "twist" or ev.style == "good" or ev.style == "narration") then
        for _, p in ipairs(night.players) do
            local s = state(p.key)
            if s and s ~= "charmed" and p.char and string.sub(ev.text, 1, #p.char + 1) == p.char .. " "
                and not able.about_them(ev.text, p.char) then
                fail("A1", where .. ": " .. p.char .. " is " .. s .. ", but: " .. ev.text)
            end
        end
    end
end

local TOLD = require("game.data.barks").told or {}
local death_data = require "game.data.death"

-- Per night: what's been seen so far, for the watchers.
local function watch_night(R, night, w)
    R.n = { deaths = {}, turn_moments = nil, ff = nil, wake_at = nil, grief = false, thanks = false }
end

-- After a turn: what it owes the table (A2 friendly fire, A4 the big moments), checked when the next
-- turn comes or the fight ends.
local MOMENT_TOLD = { veil = { "veil" }, petrify = { "petrify", "petrify_missed" }, mirror = { "mirror" },
                      hyper = { "hyper" }, overheat = { "overheat" }, power_down = { "power_down" } }
local function settle_turn(R, w)
    local n = R.n
    local t = n.pending
    if not t then
        return
    end
    n.pending = nil
    local where = R.tag .. " W" .. w
    for kind in util.sorted_pairs(t.need) do
        if not t.heard[kind] then
            fail(kind == "friendly" and "A2" or "A4", where .. ": " .. kind .. " on the mat, and nobody at the table hears it ("
                .. tostring(t.what[kind]) .. ")")
        else
            add(kind == "friendly" and "A2" or "A4", kind .. "_told")
        end
    end
    if t.need.friendly and not t.reply then
        fail("A2", where .. ": friendly fire, and nobody at the table says anything about it")
    end
end

local function on_turn(R, night, ev, w)
    -- (A card in the middle of a turn splits it in two on the mat: it's told at the turn's end.)
    local carried = R.n.pending and R.n.pending.who == ev.who and R.n.pending or nil
    if carried then
        R.n.pending = nil
    else
        settle_turn(R, w)
    end
    local b = night.battle
    local function cr(id)
        for _, c in ipairs((b and b.creatures) or {}) do
            if c.mini == id then
                return c
            end
        end
    end
    local who = ev.who and cr(ev.who)
    local t = { need = {}, heard = {}, what = {} }
    for _, st in ipairs(ev.steps or {}) do
        local c = st.id and cr(st.id)
        if st.kind == "damage" and who and who.pc and st.src == who.mini and st.id ~= who.mini and c and c.side == who.side then
            t.need.friendly, t.what.friendly = true, who.name .. " hit " .. c.name
            R.n.ff = R.n.ff or {}
            R.n.ff[who.name] = true
        elseif st.kind == "feature" and st.museum and c then
            local k = st.museum
            if MOMENT_TOLD[k] or (k == "petrified") or (k == "freed" and c.pc) or (k == "charmed" and c.pc) then
                t.need[k], t.what[k] = true, c.name .. " " .. tostring(st.name)
            end
        elseif st.kind == "death_save" and st.roll == 20 and c and c.pc then
            t.need.nat20, t.what.nat20 = true, c.name
        end
    end
    t.who = ev.who
    if carried then
        for k, v in pairs(carried.need) do
            t.need[k], t.what[k] = v, carried.what[k]
        end
        for k, v in pairs(carried.heard) do
            t.heard[k] = v
        end
        t.reply = carried.reply
    end
    if next(t.need) then
        R.n.pending = t
    end
end

-- (Telpur's knockout, in more than one way: the same three lines word for word every time, the third
-- playtest. Counted over all the runs.)
local TELPUR = { said = {}, n = 0 }
local function telpur_watch(ev)
    local tl = adventure.data.companions.telpur.lines
    if ev.kind == "narrate" and ev.text then
        local down = type(tl.down) == "table" and tl.down or { tl.down }
        local up = type(tl.up) == "table" and tl.up or { tl.up }
        if from(down, ev.text) or from(up, ev.text) then
            TELPUR.n = TELPUR.n + 1
            TELPUR.said[ev.text] = true
        end
    end
end

local function heard_turn(R, ev)
    local t = R.n.pending
    if not t then
        return
    end
    local text = ev.text or ""
    if ev.kind == "narrate" then
        if from(TOLD.friendly_fire, text) or from(TOLD.friendly_down, text) then
            t.heard.friendly = true
        end
        for k, keys in pairs(MOMENT_TOLD) do
            for _, key in ipairs(keys) do
                if from(TOLD[key], text) then
                    t.heard[k] = true
                end
            end
        end
        if from(TOLD.stone, text) or from(TOLD.self_stone, text) or from(TOLD.stone_other, text) then
            t.heard.petrified = true
        end
        if from(TOLD.freed, text) then
            t.heard.freed = true
        end
        if from(TOLD.charmed, text) then
            t.heard.charmed = true
        end
        if from(TOLD.nat20_save, text) then
            t.heard.nat20 = true
        end
    elseif ev.kind == "say" and (ev.line == "told.friendly_hit" or ev.line == "told.friendly_sorry") then
        t.reply = true
    end
end

-- A1's night: once a hero has died, nobody whoops, the wake waits for the lair to be settled, Flitwidget
-- says something at the wake, and the night's recap leads with it.
local function after_death(R, night, ev, w)
    local n = R.n
    local where = R.tag .. " W" .. w
    for _, pc in ipairs(night.pc_list or {}) do
        if pc.dead and not n.deaths[pc.name] then
            n.deaths[pc.name] = true
            add("A1", "deaths")

        end
    end
    if not next(n.deaths) then
        return
    end
    if ev.kind == "say" then
        local tr = trigger_of(ev.line)
        if (tr and able.CHEER[tr]) or (type(ev.line) == "string" and string.find(ev.line, "^tb_")) then
            fail("A1", where .. ": a hero died tonight, and " .. ev.who .. " whoops (" .. tostring(ev.line) .. "): " .. ev.text)
        end
    elseif ev.kind == "narrate" and from({ death_data.WAKE }, ev.text) then
        local settled = night.scene and night.scene.room ~= "lair"
        for _, r in ipairs((night.mus and night.mus.rooms) or {}) do
            settled = settled or r.room == "lair"
        end
        if not settled then
            fail("A1", where .. ": the wake, with Euryale's fight still being settled: " .. ev.text)
        end
        n.wake_at = night.scene and night.scene.room
        add("A1", "wakes")
    elseif ev.kind == "decision" and ev.card.id == "hero_dies" and ev.actor then
        -- (What they carried as the death card comes up: what the fight used up is gone already.)
        n.packs = n.packs or {}
        n.packs[ev.actor] = #require("game.model.items").held_by(night.campaign, ev.actor)
    elseif ev.kind == "narrate" and (from(death_data.PACK_SHARED or {}, ev.text) or from(death_data.PACK_LEFT or {}, ev.text)) then
        n.pack_said = true
    elseif ev.kind == "npc" and ev.cast == "mus_flitwidget" then
        local gl = adventure.data.people_lines.mus_flitwidget.grief
        local grief = gl and gl[1] and gl[1].text or {}
        if from(grief, ev.text) then
            n.grief = true
        end
        if night.scene and night.scene.room == "thanks" and not n.grief_due then
            n.grief_due = true
        end
    end
end

local function night_done(R, night, rep, w)
    settle_turn(R, w)
    local n = R.n
    -- (A2: the recap owns friendly fire: the report's chain says whose spell it was.)
    for name in util.sorted_pairs(n.ff or {}) do
        local found = false
        for _, line in ipairs(rep and rep.museum and rep.museum.chain or {}) do
            found = found or string.find(line, name .. "'s", 1, true) ~= nil
        end
        if not found then
            fail("A2", R.tag .. " W" .. w .. ": " .. name .. " hit the party, and the night's recap doesn't say so")
        else
            add("A2", "recapped")
        end
    end
    if not next(n.deaths) then
        return
    end
    local where = R.tag .. " W" .. w
    if not n.wake_at and not night.end_early then
        fail("A1", where .. ": a hero died with a goodbye, and there was no wake")
    end
    -- (What the dead carried is settled out loud, never left in their seat for whoever sits there next.)
    for key, had in util.sorted_pairs(n.packs or {}) do
        local still = #require("game.model.items").held_by(night.campaign, key)
        local pc = night.pcs and night.pcs[key]
        if not (pc and pc.dead) then
            -- (brought back: still theirs)
        elseif still > 0 then
            fail("A1", where .. ": " .. key .. "'s hero died, and " .. still .. " thing(s) are still in that seat's pack")
        elseif had > 0 and not n.pack_said then
            fail("A1", where .. ": " .. key .. "'s hero died carrying " .. had .. " thing(s), and nobody said where they went")
        elseif had > 0 then
            add("A1", "packs_settled")
        end
    end
    if n.grief_due and not n.grief then
        fail("A1", where .. ": a hero died, and Flitwidget thanks them without a word about it")
    elseif n.grief then
        add("A1", "flitwidget_grieves")
    end
    local chain = rep and rep.museum and rep.museum.chain or {}
    local first = chain[1] or ""
    local named = false
    for name in util.sorted_pairs(n.deaths) do
        named = named or (string.find(first, name, 1, true) and string.find(first, "died", 1, true))
    end
    if not named then
        fail("A1", where .. ": the recap doesn't lead with the death: " .. first)
    else
        add("A1", "recap_leads_with_death")
    end
end

-- A3: what's destroyed stays destroyed. Each lair fight's line-up against the last one's losses: a foe
-- that fell in a lost fight isn't back behind her, an ally smashed or burnt out isn't back beside them
-- (nor its red switch "saved for the Gorgon"), the night's opening doesn't say they "woke the Steam Mech"
-- after it burnt out, and a second time up her stairs she doesn't open as if it were the first.
local FIRST_AMBUSH = "No drink, no questions. An arrow is already on the string when they reach the top step."
local function lair_watch(R, night, ev, w)
    local L = R.lair or { gone = {} }
    R.lair = L
    local st = night.campaign.adv
    local where = R.tag .. " W" .. w
    if ev.kind == "battle" and ev.phase == "start" and night.scene and night.scene.room == "lair" then
        local count = {}
        for _, q in ipairs(ev.foes or {}) do
            if q.monster then
                count[q.monster] = (count[q.monster] or 0) + 1
            end
        end
        for mid, n in util.sorted_pairs(count) do
            local was = L.after and L.after[mid]
            if was and n > was then
                fail("A3", where .. ": " .. n .. " " .. mid .. " behind Euryale, but only " .. was .. " walked away from her last fight")
            end
        end
        for _, q in ipairs(ev.allies or {}) do
            if L.gone[q.monster or ""] then
                fail("A3", where .. ": " .. tostring(q.name) .. " fights beside them again, after it was destroyed")
            end
        end
        L.count = count
        add("A3", "lair_fights")
    elseif (ev.kind == "narrate" or ev.kind == "say") and L.gone_name and ev.text then
        if string.find(ev.text, L.gone_name .. " clanks up", 1, true) or string.find(ev.text, L.gone_name .. "'s red switch", 1, true) then
            fail("A3", where .. ": " .. L.gone_name .. " was destroyed, and: " .. ev.text)
        end
    end
    if ev.kind == "narrate" and ev.style == "recap" and st.flags and st.flags.mech_burnt
        and string.find(ev.text, "woke the Steam Mech", 1, true) and not string.find(ev.text, "burnt", 1, true) then
        fail("A3", where .. ": the Mech burnt out, and the opening says: " .. ev.text)
    end
    if ev.kind == "narrate" and st.flags and st.flags.rematch and ev.text == FIRST_AMBUSH then
        fail("A3", where .. ": a second time up her stairs, and Euryale opens as if it were the first: " .. ev.text)
    elseif ev.kind == "narrate" and st.flags and st.flags.rematch and from(adventure.data.showdown.ambush_again or {}, ev.text) then
        add("A3", "rematch_remembered")
    end
end

-- (After the night: how its lair fights ended, read off the scenes, for the next one.)
local function lair_after(R, night)
    local L = R.lair
    if not (L and L.count) then
        return
    end
    for _, sc in ipairs(night.scenes or {}) do
        if sc.room == "lair" and sc.result then
            local after = {}
            for mid, n in pairs(L.count) do
                after[mid] = n
            end
            local died = 0
            for _, mid in ipairs(sc.foes_beaten or {}) do
                after[mid] = (after[mid] or 1) - 1
                died = died + 1
            end
            if sc.outcome ~= "win" then
                L.after = after
                if died > 0 then
                    add("A3", "lost_lair_fights_with_foes_down")
                end
            end
            for _, a in ipairs(sc.allies_lost or {}) do
                L.gone[a.id] = true
                L.gone_name = a.name
                add("A3", "allies_lost")
            end
        end
    end
end

-- A5: the DM's picks and the taunts the table heard steer the foes. After "Go for Brannoc" (the boss's
-- turn, yours to run), it goes at Brannoc, or toward him, and swings at nobody else until it has; after
-- "it's Oswin it wants", the same for the next few rounds; and "how do you want to do this?" and "about
-- to drop" name whoever really lands the blow.
local function creature_named(night, name)
    for _, c in ipairs((night.battle and night.battle.creatures) or {}) do
        if c.name == name then
            return c
        end
    end
end
local function pick_watch(R, night, ev, pick, w)
    local A = R.a5 or {}
    R.a5 = A
    if ev.card.id == "boss_turn" then
        local label = ev.card.options[pick] and ev.card.options[pick].label or ""
        local name = string.match(label, "^Go for (.-)[,%.]") or string.match(label, "^Go after (.-)[,%.]")
            or string.match(label, "^Stand over (.-) and strike")
        local t = name and creature_named(night, name)
        if t and ev.card.turn_of then
            A.want = { by = ev.card.turn_of, t = t.mini, name = name, until_round = nil, why = "the DM's pick" }
            add("A5", "boss_turn_picks")
        end
    elseif ev.card.id == "killing_blow" or ev.card.id == "boss_crit" then
        local text = ev.card.text or ""
        local name = string.match(text, "^(.-) is about to drop") or string.match(text, "about to fall to (.-)%.")
        local label = ev.card.options[pick] and ev.card.options[pick].label or ""
        if name and not string.find(label, "Second phase", 1, true) then
            A.kb = { name = name, card = ev.card.id }
        end
    end
end
local function a5_watch(R, night, ev, w)
    local A = R.a5 or {}
    R.a5 = A
    local where = R.tag .. " W" .. w
    if ev.kind == "narrate" and ev.text then
        local foe, name = string.match(ev.text, "^(.-) can't take its eyes off (.-)%. For the next few rounds")
        local c = foe and creature_named(night, foe)
        local t = name and creature_named(night, name)
        if c and t then
            A.want = { by = c.mini, t = t.mini, name = name, until_round = (night.battle.round or 0) + 3, why = "the taunt" }
            add("A5", "taunts")
        end
    elseif ev.kind == "turn" and night.battle then
        local want = A.want
        local function cr(id)
            for _, c in ipairs(night.battle.creatures) do
                if c.mini == id then
                    return c
                end
            end
        end
        if want and want.until_round and (night.battle.round or 0) > want.until_round then
            A.want, want = nil, nil
        end
        for _, st in ipairs(ev.steps or {}) do
            if want and st.kind == "condition_end" and st.id == want.by and st.name == "Taunted" then
                A.want, want = nil, nil          -- (the stare-down has worn off)
            end
            if want and st.id == want.by and (st.kind == "attack" or (st.kind == "feature" and st.name == "Bored to Death")) then
                local t = cr(want.t)
                local standing = t and not t.dead and not t.down and not t.removed
                local out = false
                for _, e in ipairs((t and t.effects) or {}) do
                    out = out or e.out_of_fight or e.stone
                end
                local at = type(st.target) == "string" and st.target or nil
                if at == want.t then
                    add("A5", "went_for_the_pick")
                    if not want.until_round then
                        A.want, want = nil, nil
                    end
                elseif standing and not out and at and cr(at) and cr(at).side ~= (cr(want.by) or {}).side then
                    fail("A5", where .. ": after " .. want.why .. " (" .. want.name .. "), " .. tostring((cr(want.by) or {}).name)
                        .. " goes at " .. tostring(cr(at).name))
                    A.want, want = nil, nil
                end
            end
            if A.kb and st.kind == "damage" and (st.hp or 1) <= 0 then
                local t = cr(st.id)
                if t and t.side == "foes" then
                    local src = st.src and cr(st.src)
                    if src and src.name ~= A.kb.name then
                        fail("A5", where .. ": the " .. A.kb.card .. " card named " .. A.kb.name .. ", and " .. src.name .. " landed it")
                    else
                        add("A5", "blow_named_right")
                    end
                    A.kb = nil
                end
            end
        end
    elseif ev.kind == "battle" and ev.phase == "end" then
        A.want, A.kb = nil, nil
    end
end

-- A6: after a lost fight or backing out of a room, nobody browses there: no small rolls, no votes over
-- what's on the shelves, no look-arounds; a wipe is said once, as a wipe, and the night doesn't cheer
-- or call it "high fives all round" afterwards.
local STOP_FIGHT = require("game.model.museum_night").WEEKLY.stop_fight
local function a6_watch(R, night, ev, w)
    local sc = night.scene
    local A = R.a6 or {}
    R.a6 = A
    local where = R.tag .. " W" .. w
    if ev.kind == "scene" then
        A.round_lines = 0
        return
    elseif ev.kind == "scene_end" then
        A.ended = night.scene
    end
    if not sc then
        return
    end
    local lost = sc.outcome == "lose" and sc.room ~= "lair" and sc.room ~= "thanks" and A.ended ~= sc
    if lost and ev.kind == "tiny_roll" then
        fail("A6", where .. ": " .. tostring(sc.room) .. " is lost and they're getting out, and " .. tostring(ev.who) .. " rolls a small "
            .. tostring(ev.skill) .. " roll there")
    elseif lost and ev.kind == "narrate" and ev.style == "aside" and string.find(ev.text or "", "^The table decides:") then
        fail("A6", where .. ": " .. tostring(sc.room) .. " is lost and they're getting out, and the table votes: " .. ev.text)
    elseif lost and ev.kind == "decision" and (string.find(ev.card.id or "", "^find_") or string.find(ev.card.id or "", "^trap_")) then
        fail("A6", where .. ": " .. tostring(sc.room) .. " is lost and they're getting out, and someone looks around: " .. tostring(ev.card.title))
    elseif lost and ev.kind == "say" and ev.line == nil and ev.ic == false then
        -- (fine: table talk)
    end
    if ev.kind == "narrate" and ev.text and string.find(ev.text, "round on the floor with 1 hit point", 1, true) then
        A.round_lines = (A.round_lines or 0) + 1
        if A.round_lines > 1 then
            fail("A6", where .. ": coming round after a fight, said one hero at a time: " .. ev.text)
        end
        if string.find(ev.text, "beaten", 1, true) then
            A.wiped = w
            add("A6", "wipes")
        end
    end
    if A.wiped == w then
        if ev.kind == "say" then
            local tr = trigger_of(ev.line)
            if (tr and able.CHEER[tr]) or (type(ev.line) == "string" and string.find(ev.line, "^tb_")) then
                fail("A6", where .. ": after a wipe, " .. ev.who .. " whoops: " .. ev.text)
            end
        elseif ev.kind == "narrate" and from(STOP_FIGHT, ev.text) then
            fail("A6", where .. ": after a wipe, the night stops on: " .. ev.text)
        end
    end
    if lost and ev.kind ~= "say" then
        add("A6", "lost_room_events_checked")
    end
end

-- A7: the recaps lead with the losses (a death, a wipe, an ally lost, who went down), in the report and
-- in the next night's "Last time"; a fight in the Chamber "smashed" its guardian; a Sentinel smashed to
-- scrap doesn't "watch them leave"; a Lecturer who got away isn't "silenced", nor "fades".
local function a7_watch(R, night, ev, w)
    local A = R.a7 or {}
    R.a7 = A
    local where = R.tag .. " W" .. w
    A.week = A.week or {}
    local wk = A.week[w] or { downs = {} }
    A.week[w] = wk
    if ev.kind == "turn" and night.battle then
        for _, st in ipairs(ev.steps or {}) do
            if st.kind == "down" then
                for _, c in ipairs(night.battle.creatures) do
                    if c.mini == st.id and c.pc then
                        wk.downs[c.name] = (wk.downs[c.name] or 0) + 1
                    end
                end
            end
        end
    elseif ev.kind == "narrate" and ev.text then
        local text = ev.text
        if string.find(text, "watches them all the way", 1, true) then
            local fought = events_mod.any(night.campaign, { kind = "fight", where = "entrance", session = night.campaign.week })
            if fought then
                fail("A7", where .. ": the Sentinel was fought, and: " .. text)
            end
        end
        local escaped = events_mod.any(night.campaign, { kind = "fight", where = "lecture", fate = "ran" })
        if escaped and (string.find(text, "The Lecturer fades", 1, true) or string.find(text, "pages of lecture notes", 1, true)
            or string.find(text, "notes drift to the floor", 1, true)) then
            fail("A7", where .. ": the Lecturer got away, and: " .. text)
        end
        if ev.style == "recap" then
            local prev = A.week[w - 1]
            if not wk.recap_seen and prev and prev.lost and #prev.lost > 0 then
                if not string.find(text, "^Last time, " .. prev.lost[1]:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%0")) then
                    fail("A7", where .. ": last time cost them (" .. prev.lost[1] .. "), and the opening says: " .. text)
                else
                    add("A7", "openings_lead_with_losses")
                end
            end
            wk.recap_seen = true
            if string.find(text, "stilled the Bone Construct", 1, true)
                and events_mod.any(night.campaign, { kind = "fight", where = "chamber", session = w - 1 }) then
                fail("A7", where .. ": the Bone Construct was smashed, and the opening says: " .. text)
            end
            if string.find(text, "silenced the Lecturer", 1, true)
                and events_mod.any(night.campaign, { kind = "fight", where = "lecture", fate = "ran" }) then
                fail("A7", where .. ": the Lecturer got away, and the opening says: " .. text)
            end
        end
    end
end
local function a7_after(R, night, rep, w)
    local A = R.a7 or {}
    local wk = A.week and A.week[w] or { downs = {} }
    local where = R.tag .. " W" .. w
    -- (A Lecturer who got away took his notes: no sleeping pages on her card. Batch B found it.)
    local c = night.campaign
    if events_mod.any(c, { kind = "fight", where = "lecture", fate = "ran", session = c.week }) then
        add("A7", "lecturer_escapes")
        if c.adv.marks.pages then
            fail("A7", where .. ": the Lecturer got away, and they have his notes anyway")
        end
    end
    local chain = rep and rep.museum and rep.museum.chain or {}
    -- (What the night cost, from the mat: who went down, who died, a wipe, an ally lost.)
    local lead = events_mod.losses and events_mod.losses(night.campaign, night.campaign.week) or {}
    wk.lost = lead
    local dead = {}
    for _, pc in ipairs(night.pc_list or {}) do
        if pc.dead then
            dead[pc.name] = true
        end
    end
    local wiped = R.a6 and R.a6.wiped == w
    for name, n in util.sorted_pairs(wk.downs) do
        if not dead[name] and not wiped then
            local said = false
            for _, l in ipairs(lead) do
                said = said or (string.find(l, name, 1, true) and string.find(l, "went down", 1, true))
            end
            if not said then
                fail("A7", where .. ": " .. name .. " went down " .. n .. " time(s), and the recap doesn't say so")
            else
                add("A7", "downs_recapped")
            end
        end
    end
    if #lead > 0 then
        local first = chain[1] or ""
        if not string.find(first, lead[1]:gsub("^%l", string.upper), 1, true) then
            fail("A7", where .. ": the report doesn't lead with what it cost (" .. lead[1] .. "): " .. first)
        else
            add("A7", "reports_lead_with_losses")
        end
    end
end

-- A8: the break comes at a lull, never in her lair between the stand-off and the first blow; a night run
-- past the time agreed at Session Zero is said at the table, isn't cheered as if it weren't, has nobody
-- asking "same time next week?", and the report says what it cost.
local function a8_watch(R, night, ev, w)
    local A = R.a8 or {}
    R.a8 = A
    local where = R.tag .. " W" .. w
    local sc = night.scene
    if ev.kind == "decision" and ev.card.id == "table_break" then
        if sc and sc.room == "lair" and not sc.result and not (night.mus and night.mus.rooms and #night.mus.rooms > 0
            and night.mus.rooms[#night.mus.rooms].room == "lair") then
            fail("A8", where .. ": the break comes in her lair, before the fight's settled")
        else
            add("A8", "breaks_at_a_lull")
        end
    end
    local late = (night.table_min or 0) > (night.table_planned or 210) + 15
    if ev.kind == "narrate" and ev.text then
        if from(require("game.model.night").LATE_LINES or {}, ev.text) then
            A.late_said = w
        end
        if late and ev.text == "It ends on a high. Somebody actually applauds." then
            fail("A8", where .. ": a night run long ends: " .. ev.text)
        end
    elseif ev.kind == "say" and late and type(ev.line) == "string" and string.find(ev.line, "^wrap%.")
        and string.find(string.lower(ev.text or ""), "same time next week", 1, true) then
        fail("A8", where .. ": a night run long, and " .. ev.who .. " says: " .. ev.text)
    end
end
local function a8_after(R, night, rep, w)
    local A = R.a8 or {}
    local where = R.tag .. " W" .. w
    local over = (night.table_min or 0) - (night.table_planned or 210)
    if over > 15 then
        add("A8", "late_nights")
        if A.late_said ~= w and not night.end_early then
            fail("A8", where .. ": the night ran " .. math.floor(over) .. " minutes past the agreed end, and nobody at the table says so")
        end
        local tt = rep and rep.table_text or ""
        if not string.find(tt, "you agreed at Session Zero", 1, true) then
            fail("A8", where .. ": a night run long, and the report says: " .. tostring(tt))
        else
            add("A8", "late_reported")
        end
    end
end

-- Whole prologues ----------------------------------------------------------------------------------
-- The 24 the reviews read (seeds 31 to 38, three DMs), more seeds, and "fragile" ones where Oswin goes
-- into Euryale's lair on 1 hit point with two failed death saves waiting: deaths are rare, and every
-- rule about the dead needs some to look at.

local runs = {}
-- fragile: "lair" (only her fight) or "every" (every fight).
local function run(seed, style, fragile)
    local key = seed .. style .. (fragile and "f" or "")
    if runs[key] then
        return runs[key]
    end
    local R = sim_play(seed, style, {
        night = watch_night,
        ev = function(R, night, ev, w)
            if fragile and ev.kind == "battle" and ev.phase == "start" and night.scene
                and (fragile == "every" or night.scene.room == "lair") then
                local pc = night.pcs and night.pcs.sam
                if pc then
                    pc.hp = 1
                end
            end
            if fragile and ev.kind == "turn" then
                local pc = night.pcs and night.pcs.sam
                if pc and pc.down and not pc.dead and pc.ds and (pc.ds.f or 0) < 2 then
                    pc.ds.f = 2
                end
            end
            if ev.kind == "turn" then
                on_turn(R, night, ev, w)
            elseif ev.kind == "battle" and ev.phase == "end" then
                settle_turn(R, w)
            else
                heard_turn(R, ev)
            end
            gate(R, night, ev, w)
            after_death(R, night, ev, w)
            lair_watch(R, night, ev, w)
            telpur_watch(ev)
            a5_watch(R, night, ev, w)
            a6_watch(R, night, ev, w)
            a7_watch(R, night, ev, w)
            a8_watch(R, night, ev, w)
        end,
        after = function(R, night, rep, w)
            night_done(R, night, rep, w)
            lair_after(R, night)
            a7_after(R, night, rep, w)
            a8_after(R, night, rep, w)
        end,
        pick = function(R, night, ev, pick)
            -- (A fragile run lets the dice stand on a hero's life: no fudging, a goodbye.)
            if fragile and (ev.card.id == "last_save" or ev.card.id == "death_roll" or ev.card.id == "hero_dies") then
                pick = 1
            end
            pick_watch(R, night, ev, pick, R.week)
            return pick
        end,
    })
    add("run", "prologues")
    runs[key] = R
    return R
end

for s = 31, 38 do
    for _, st in ipairs({ "careful", "random", "careless" }) do
        run(s, st)
    end
end
for _, style in ipairs({ "careful", "random", "careless" }) do
    for s = 1, EXTRA do
        run(40 + s, style)
    end
end
for s = 31, 38 do
    run(s, "careful", "lair")
end
for s = 31, 34 do
    run(s, "random", "every")
    run(s, "careless", "every")
end
do
    local distinct = 0
    for _ in pairs(TELPUR.said) do
        distinct = distinct + 1
    end
    if TELPUR.n >= 4 and distinct <= 2 then
        fail("A4", "Telpur goes down and comes round " .. TELPUR.n .. " times, in only " .. distinct .. " ways")
    end
    add("A4", "telpur_knockout_ways", distinct)
end
if not (E.A1 and (E.A1.deaths or 0) >= 2) then
    fail("A1", "fewer than two deaths in all the runs: nothing to check the dead against")
end

-- Targeted cases -----------------------------------------------------------------------------------

-- A night stopped as its first room starts (the street, Flitwidget there).
local function first_room(seed)
    adventure.enter()
    local c = campaign_mod.new(seed)
    adventure.enter(c)
    c:session_zero(social.default_choices())
    for _, key in ipairs({ "mara", "dev", "jess", "sam" }) do
        adventure.set_hook(c, key, adventure.data.hooks[key][1].id)
    end
    c:start_week()
    local night = c:start_night()
    local ev = night:advance()
    local guard = 0
    while ev.kind ~= "done" and not (ev.kind == "scene" and night.scene and night.scene.room) and guard < 2000 do
        guard = guard + 1
        local answer
        if ev.kind == "decision" or ev.kind == "ruling" then
            answer = 1
        elseif ev.kind == "improv" then
            answer = { 1 }
        elseif ev.kind == "roll_where" then
            answer = "open"
        elseif ev.kind == "roll" then
            answer = 10
        end
        ev = night:advance(answer)
    end
    night.first_gentle, night.gentle = night.gentle, nil
    return c, night, night.scene
end

local function drive(night, fn)
    local out = {}
    local co = coroutine.create(fn)
    local answer
    while coroutine.status(co) ~= "dead" do
        local ok, e = coroutine.resume(co, answer)
        if not ok then
            error(e)
        end
        answer = nil
        if e then
            table.insert(out, e)
            if e.kind == "decision" then
                answer = 1
            elseif e.kind == "roll_where" then
                answer = "open"
            elseif e.kind == "roll" then
                answer = 10
            elseif e.kind == "ruling" then
                answer = 1
            end
        end
    end
    return out
end

-- A1: Oswin is dead. Nobody picks him for anything, he has no say in what the party does, and the
-- table doesn't whoop.
case("A1", function()
    local c, night, sc = first_room(71)
    night.watching = { sam = true }
    local sam = c:player("sam")
    for _ = 1, 60 do
        local picks = { night:pick_actor(nil), night:pick_lead(nil), night:pick_roller({ "insight" }, sc) }
        for _, q in ipairs(picks) do
            if q == sam then
                fail("A1", "case: a picker chose dead Oswin")
            end
        end
    end
    if util.contains(night:at_hand(), sam) then
        fail("A1", "case: dead Oswin is at hand")
    end
    local mn = require "game.model.museum_night"
    local card = { id = "case_vote", text = "Which way?", options = { { label = "Left", want = "go left" }, { label = "Right", want = "go right" } } }
    local out = drive(night, function()
        mn.table_pick(night, card, {})
    end)
    for _, e in ipairs(out) do
        if e.kind == "say" and e.who == "sam" then
            fail("A1", "case: dead Oswin's player votes: " .. tostring(e.text))
        end
    end
    for _, p in ipairs(night.party_backers or {}) do
        if p == sam then
            fail("A1", "case: dead Oswin is counted for the party's choice")
        end
    end
    local said = drive(night, function()
        night:bark(c:player("dev"), "victory")
        night:bark(c:player("jess"), "crit")
        night:bark(c:player("jess"), "up_again")
        night:table_behavior("after_crit", c:player("dev"), true)
    end)
    for _, e in ipairs(said) do
        if e.kind == "say" then
            fail("A1", "case: a hero died tonight, and " .. e.who .. " says: " .. tostring(e.text))
        elseif e.kind == "narrate" and not from(TOLD.up_quiet, e.text) then
            fail("A1", "case: getting up after a death isn't quiet: " .. tostring(e.text))
        end
    end
    add("A1", "case_dead_oswin")
end)

-- A1: Oswin dies carrying the bracelet and a healing potion. They're shared out, out loud, to friends whose
-- heroes can act (the bracelet to whoever can use it), the log says they were given, and nothing's left in
-- Sam's seat for the hero who sits there next week.
case("A1", function()
    local items = require "game.model.items"
    local death = require "game.model.death"
    local c, night = first_room(73)
    local sam = c:player("sam")
    for _, it in ipairs(items.held_by(c, "sam")) do
        it.holder = "mara"
    end
    items.give(c, "bracelet", "sam", "given")
    local before = #items.held_by(c, "sam")
    night.watching = { sam = true }
    local out = drive(night, function()
        death.settle_pack(night, sam)
    end)
    if #items.held_by(c, "sam") > 0 then
        fail("A1", "case: Oswin's pack is still in Sam's seat")
    end
    local said = false
    for _, e in ipairs(out) do
        said = said or (e.kind == "narrate" and from(death_data.PACK_SHARED or {}, e.text))
    end
    if not said then
        fail("A1", "case: Oswin's things changed hands and nobody said so")
    end
    local it = items.holding(c, "bracelet")
    if not it or it.holder == "sam" then
        fail("A1", "case: the bracelet didn't go to a friend")
    end
    if not events_mod.any(c, { kind = "get", how_got = "given", whom = "sam" }) then
        fail("A1", "case: the log doesn't say Oswin's things were given on")
    end
    if before == 0 then
        fail("A1", "case: Oswin had nothing to begin with")
    end
    add("A1", "case_pack_settled")
end)

-- A3: Owen the Steam Mech is destroyed in a lost fight in her lair, along with the Knight of Shades and a
-- huntling. Next time, she has no Knight, two huntlings and her scarabs, Owen isn't with them, and the
-- night's recap leads with losing him.
case("A3", function()
    local c, night = first_room(72)
    local st = c.adv
    for _, id in ipairs({ "mech", "knight", "scarabs", "pack" }) do
        adventure.add_mark(c, id, "lair")
    end
    st.pack, st.mech_name = 3, "Owen"
    local before = adventure.boss_encounter(c)
    local mn = require "game.model.museum_night"
    mn.lair_losses(night, { room = "lair", allies_lost = { { id = "steam_mech", name = "Owen" } },
                            foes_beaten = { "knight_of_shades", "kruthik_huntling" } }, true)
    local enc = adventure.boss_encounter(c)
    local n = {}
    for _, id in ipairs(enc.ids) do
        n[id] = (n[id] or 0) + 1
    end
    if n.knight_of_shades then
        fail("A3", "case: the Knight of Shades fell, and he's behind her again")
    end
    if (n.kruthik_huntling or 0) ~= 2 then
        fail("A3", "case: one of three huntlings fell, and " .. tostring(n.kruthik_huntling) .. " are behind her")
    end
    if not n.giant_scarab_swarm then
        fail("A3", "case: the scarab swarm walked away, and it's gone from her side")
    end
    for _, a in ipairs(enc.allies) do
        if a.id == "steam_mech" then
            fail("A3", "case: Owen was destroyed, and he fights beside them again")
        end
    end
    local chain = require("game.model.events").chain(c, c.week)
    if not (chain[1] and string.find(chain[1], "Owen", 1, true)) then
        fail("A3", "case: the recap doesn't lead with losing Owen: " .. tostring(chain[1]))
    end
    if #before.allies == 0 then
        fail("A3", "case: the Mech wasn't with them to begin with")
    end
    add("A3", "case_owen_lost")
end)

-- A6: a moment that plays in the middle of a room, or at its end before the small moments, doesn't say
-- they've left it ("follow them all the way to the door", "By the gift shop they're puddles").
case("A6", function()
    local LEAVING = { "all the way to the door", "carry them out", "by the gift shop", "out the door", "they leave the room" }
    for _, m in ipairs(adventure.data.moments) do
        for _, o in ipairs(m.options or {}) do
            local low = string.lower(o.log or "")
            for _, pat in ipairs(LEAVING) do
                if string.find(low, pat, 1, true) then
                    fail("A6", "case: " .. m.id .. " (" .. tostring(m.at or "start") .. ") says they've left, and the room goes on: " .. o.log)
                end
            end
        end
    end
    add("A6", "case_leaving_lines")
end)

-- Report -------------------------------------------------------------------------------------------

local total = 0
for _, item in ipairs(ITEMS) do
    local seen = {}
    for k, n in util.sorted_pairs(E[item] or {}) do
        table.insert(seen, k .. " " .. n)
    end
    local f = fails[item]
    print(string.format("%-4s %-40s %s%s", item, NAMES[item], #seen > 0 and table.concat(seen, ", ") or "-",
        f and ("  FAIL x" .. f.n) or ""))
    for _, m in ipairs(f or {}) do
        print("     FAIL: " .. m)
    end
    total = total + (f and f.n or 0)
end
print(total == 0 and "round3_state_check: all good" or ("round3_state_check: " .. total .. " failures"))
os.exit(total == 0 and 0 or 1)
