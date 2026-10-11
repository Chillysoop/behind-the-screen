-- A one-on-one before the session (A6: "Talk 2h" is a conversation, never just a button).
-- Real DMs check in with a player away from the table: how they're doing, what they'd love to
-- see, what's bugging them. Three short exchanges, and you come away knowing their mood, a want
-- and a worry. Pure Lua: the prep model pays the 2h (prep:talk), this plays the talk.
--
--   local t = one_on_one.start(campaign, prep, key)   -- { key, step, log, learned, done }
--   one_on_one.options(t)                              -- labels you can say now
--   one_on_one.choose(campaign, prep, t, i)            -- say it; they answer
--
-- What you learn lands in prep.talk_notes[key] = { mood, want, want_type, worry } for the
-- player card, and a want you then give them on the board counts on the night.

local content = require "game.model.content"
local score = require "game.model.score"
local util = require "game.model.util"

local M = {}

local MOOD_LINES = {
    fine = { "Pretty good, honestly. Normal week. Looking forward to Thursday.", "Fine! Busy, but fine. Thursday's the bright spot." },
    tired = { "Tired. Really tired. Work's been long. I'll be there, I might just yawn a lot.", "Honestly? Exhausted. But I'm not missing it." },
    celebrating = { "Great, actually! I got the job. I'm bringing cake on Thursday.", "Really good week. Something to celebrate. You'll see." },
    stressed = { "Bit stressed, if I'm honest. Deadlines. Thursday's my break from it.", "Stressed. I could do with hitting something, in the game I mean." },
    chatty = { "Good! I've got so much to tell everyone. Not even game stuff.", "Great. I've been dying to talk to people all week." },
    distracted = { "All over the place this week. Sorry if I'm on my phone a bit.", "A lot going on. I'll try to keep my head in the game." },
}

local WANT_LINES = {
    combat = { "Honestly? A proper fight. Something with teeth.", "a proper fight" },
    social = { "More talking to people. I want to haggle with someone, or charm a guard.", "people to talk to" },
    mystery = { "A mystery. Give me clues and let me be clever.", "a mystery to solve" },
    exploration = { "Somewhere new. Ruins, caves, a map with holes in it.", "somewhere new to explore" },
    puzzle = { "A puzzle. A real one, with levers.", "a puzzle" },
    downtime = { "A quiet bit. Shopping, the tavern, nobody trying to stab us.", "a quiet scene" },
    set_piece = { "Something big and flashy. A chase, a collapsing bridge.", "something big and flashy" },
}

-- What they'd love to see: their story if it's been quiet, else the kind of scene they like best.
local function want_of(campaign, p)
    if p.thread and (p.thread_hits or 0) == 0 and (campaign.week or 1) >= 2 then
        return "Any chance my backstory comes up? It's been ages since anything about " .. p.thread .. ".",
            p.char .. "'s backstory", nil, true
    end
    local best, bv
    for t in pairs(WANT_LINES) do
        local v = score.taste(p, t)
        if not bv or v > bv or (v == bv and t < best) then
            best, bv = t, v
        end
    end
    return WANT_LINES[best][1], WANT_LINES[best][2], best, false
end

-- What's bugging them, most pressing first; nil when nothing is.
local function worry_of(campaign, p)
    -- Another player getting under their skin (A17), when it's brewing.
    local rapport = require "game.model.rapport"
    for _, s in ipairs(rapport.strained(campaign)) do
        if s.hurt == p then
            return "Honestly? " .. s.doer.char .. ". The stuff with " .. s.doer.char .. " is getting old. I don't want to make it a thing.",
                "how " .. s.doer.char .. " plays", "rift", s.doer.key
        end
    end
    if (p.suspicion or 0) >= 45 then
        return "The rolls behind your screen lately... I don't know. Some of them felt a bit convenient.",
            "your hidden rolls", "trust"
    end
    if (p.commitment or 50) < 40 then
        return "Work's been a lot. I might be a bit flaky for a few weeks. It's not the game.",
            "a busy few weeks", "commitment"
    end
    local worst, wv
    for t in pairs(WANT_LINES) do
        local v = score.taste(p, t)
        if not wv or v < wv or (v == wv and t < worst) then
            worst, wv = t, v
        end
    end
    if wv and wv < 0.8 then
        local name = content.scenes[worst] and string.lower(content.scenes[worst].name) or worst
        return "Long " .. name .. " scenes lose me a bit, if I'm honest. I zone out.", "long " .. name .. " scenes", "taste"
    end
    return nil
end

function M.start(campaign, prep, key)
    local p = campaign:player(key)
    local t = { key = key, step = 1, log = {}, learned = {}, done = false, with = p.name, char = p.char }
    table.insert(t.log, { who = "dm", text = "You grab a coffee with " .. p.name .. " before the week gets away from you." })
    return t
end

local STEPS = {
    { "How are you doing this week? Really.", "How's {char} feeling about the game?" },
    { "What would you love to see this week?", "Anything you'd want {char} to get to do?" },
    { "Anything bugging you about the game?", "If you could change one thing, what would it be?" },
}

function M.options(t)
    if t.done then
        return {}
    end
    if t.step <= 3 then
        local out = {}
        for i, s in ipairs(STEPS[t.step]) do
            out[i] = util.fill(s, { char = t.char })
        end
        return out
    end
    -- How you take the worry.
    if t.learned.worry then
        return { "I hear you. I'll work on that.", "Thanks for telling me. Want me to bring it up with everyone?",
                 "That's just how it goes sometimes." }
    end
    return { "Glad to hear it. Tell me if that changes.", "Great. See you Thursday." }
end

function M.choose(campaign, prep, t, i)
    local p = campaign:player(t.key)
    local opts = M.options(t)
    i = util.clamp(math.floor(tonumber(i) or 1), 1, math.max(1, #opts))
    table.insert(t.log, { who = "dm", text = opts[i] })
    local reply
    if t.step == 1 then
        local lines = MOOD_LINES[p.mood] or MOOD_LINES.fine
        reply = lines[((campaign.week or 1) % #lines) + 1]
        if i == 2 then
            reply = reply .. " And " .. p.char .. "? Loving it. Mostly."
            score.add(p, "investment", 1)
        end
        p.mood_known = true
        t.learned.mood = score.mood(p).name
    elseif t.step == 2 then
        local line, short, typ, thread = want_of(campaign, p)
        reply = line
        t.learned.want, t.learned.want_type, t.learned.want_thread = short, typ, thread
    elseif t.step == 3 then
        local line, short, kind, other = worry_of(campaign, p)
        reply = line or "Honestly? Nope. I'm having a great time."
        t.learned.worry, t.learned.worry_kind, t.learned.worry_about = short, kind, other
    else
        if t.learned.worry then
            if i == 1 then
                score.add(p, "trust", 3)
                reply = "Thanks. That means a lot."
                if t.learned.worry_kind == "trust" then
                    score.add(p, "suspicion", -6)
                elseif t.learned.worry_kind == "rift" and t.learned.worry_about then
                    -- Being heard takes the heat down (A17: the ladder's private talk).
                    local rel = require("game.model.rapport").rel(campaign, p.key, t.learned.worry_about)
                    if rel then
                        rel.heat = rel.heat * 0.6
                        rel.rapport = math.min(100, rel.rapport + 2)
                    end
                end
            elseif i == 2 then
                score.add(p, "trust", 1)
                score.add(p, "investment", 2)
                reply = "Maybe. Let me think about it. But thanks."
            else
                score.add(p, "trust", -2)
                reply = "Yeah. Sure."
            end
        else
            reply = "Will do. See you Thursday!"
        end
        t.done = true
        prep.talk_notes = prep.talk_notes or {}
        prep.talk_notes[t.key] = t.learned
    end
    table.insert(t.log, { who = t.key, text = reply })
    t.step = t.step + 1
    return reply
end

-- The line the player card shows: what you learned.
function M.summary(learned)
    if not learned then
        return nil
    end
    local parts = {}
    if learned.want then
        table.insert(parts, "Wants " .. learned.want .. ".")
    end
    table.insert(parts, learned.worry and ("Worried about " .. learned.worry .. ".") or "No worries.")
    return table.concat(parts, " ")
end

return M
