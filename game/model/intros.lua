-- First-session character intros (game/data/intros.lua): before the story starts in week 1,
-- each player introduces themselves and their hero. Their mini goes down on the mat and lights
-- up, they give a little backstory in character, their partner chimes in, and the table reacts,
-- warmly, because people love a player who's all in. Pure Lua.

local util = require "game.model.util"
local score = require "game.model.score"
local rng_mod = require "game.model.rng"
local data = require "game.data.intros"

local M = {}
M.data = data

local REACT_POSE = { all_in = "cheer", warm = "lean", short = "laugh" }

function M.all_in(p)
    return (p.commitment or 0) >= data.ALL_IN_COMMITMENT or data.ALL_IN_ARCHETYPES[p.primary] == true
end

-- Where they stand while they introduce themselves: a row across the middle of the mat.
local function spot(i, n)
    return 10 - (n - 1) + 2 * (i - 1), 7
end

-- who: just these players (someone joining a small table, October 15); the others at the table
-- are already introduced, and can chime in.
function M.run(night, who)
    local players = who or night.players
    local n = #players
    if n == 0 then
        return
    end
    -- They introduce themselves where the story starts: scene 1's place goes down on the mat
    -- (its floor and walls), not the campfire the table rests on between nights.
    local first = night.scenes and night.scenes[1]
    if first and first.comps and first.comps.location then
        local t = night:terrain_for(first)
        local id = night:board_for(first, t)
        night:board_set(id, first)
        night:emit({ kind = "stage", terrain = t, board = id, party = {} })
    end
    -- Their own stream: who says what doesn't shift anything else that happens tonight.
    local rng = rng_mod.new((night.campaign.seed or 1) * 31 + 4111)
    local function pick(list)
        return list[rng:int(1, #list)]
    end
    local party, done = {}, {}
    if who then
        local names = {}
        for _, p in ipairs(who) do
            table.insert(names, p.name)
        end
        night:say(table.concat(names, " and ") .. (#who == 1 and " joins" or " join") .. " the table tonight. Introductions first.",
            "system")
        for _, q in ipairs(night.players) do
            if not util.contains(who, q) then
                done[q.key] = true
            end
        end
    else
        night:say("Before we start: who are you? Introduce yourselves, and your characters.", "dm")   -- (said to the table)
    end
    for i, p in ipairs(players) do
        local d = data.PLAYERS[p.key]
        if d then
            local x, y = spot(i, n)
            table.insert(party, { id = p.key, class = p.class, x = x, y = y })
            local copy = {}
            for j, q in ipairs(party) do
                copy[j] = q
            end
            night:emit({ kind = "intro", who = p.key, party = copy, index = i, total = n, char = p.char,
                         sub = (p.class_name or "") .. ", played by " .. p.name, table_min = data.TABLE_MIN })
            local keen = M.all_in(p)
            local short = p.shy and not keen
            night:emit({ kind = "say", who = p.key, text = pick(d.hello), ic = false })
            local si = rng:int(1, #d.story)
            -- v2: in the museum, the reason they say is the one the DM picked for their hero.
            local adventure = require "game.model.adventure"
            local h = adventure.hook(night.campaign, p.key)
            for k, hk in ipairs(adventure.data.hooks[p.key] or {}) do
                if h and hk.id == h.id and d.story[k] then
                    si = k
                end
            end
            local grim = d.grim and d.grim[si]
            night:emit({ kind = "say", who = p.key, text = d.story[si], ic = true })
            if keen and d.all_in then
                night:emit({ kind = "say", who = p.key, text = pick(d.all_in), ic = false })
            end
            -- Their partner chimes in, in character, if they've already been introduced.
            for _, q in ipairs(night.players) do
                local bond = data.BOND[q.key] and data.BOND[q.key][p.key]
                if bond and done[q.key] then
                    night:emit({ kind = "say", who = q.key, text = bond, ic = true })
                end
            end
            -- The table reacts: warm, or delighted when someone's all in.
            local others = {}
            for _, q in ipairs(night.players) do
                if q ~= p then
                    table.insert(others, q)
                end
            end
            rng:shuffle(others)
            local tone = keen and "all_in" or (short and "short" or "warm")
            local reacts = {}
            for _, l in ipairs(data.REACT[(grim and tone ~= "all_in") and "grim" or tone]) do
                table.insert(reacts, l)
            end
            rng:shuffle(reacts)
            local poses = { [p.key] = "cheer" }
            for k = 1, math.min(keen and 2 or 1, #others) do
                local q = others[k]
                night:emit({ kind = "say", who = q.key, text = reacts[k] or reacts[1], ic = false })
                poses[q.key] = REACT_POSE[tone]
            end
            night:react(poses)
            -- What it does: a moment in the light for them, and everyone warms to the table.
            score.add(p, "spotlight", data.EFFECT.spotlight)
            score.add(p, "investment", data.EFFECT.investment)
            for _, q in ipairs(night.players) do
                score.add(q, "social", data.EFFECT.social_all)
                if keen then
                    score.add(q, "fun", data.EFFECT.all_in_fun)
                end
            end
            done[p.key] = true
        end
    end
    if not who then
        M.asks(night, pick)
    end
    night.introduced = true
end

-- Lines and veils, out loud, after the introductions on the first night (round three: "You keep the
-- creepy-crawlies off screen, as you agreed with Sam at Session Zero", and nobody at the table had
-- heard a word of it). Each friend whose ask was about what they'd rather not see says it, and the
-- table hears your answer: what you agreed is what the night's reminders then say. Light: a line to
-- open, then the ask and your answer each.
M.ASKS_OPEN = { "One more thing before we start: anything you'd rather not see in here?",
                "Before the gnome: is there anything anyone doesn't want in the game?",
                "Quick check before we go in: anything off the table for anyone?" }
M.ANSWER = { agree = "You nod: \"{label}\"", push = "You hedge: \"{label}\"" }
function M.asks(night, pick)
    local t = night.campaign.table
    local s0 = require("game.model.content").session_zero
    local asks = s0 and s0.asks
    if not (t and t.asks and asks) then
        return
    end
    local said = false
    for _, key in ipairs(asks.order or {}) do
        local ask, answer = asks[key], t.asks[key]
        local p = night.campaign:player(key)
        local o = ask and answer and ask[answer]
        if ask and ask.content and o and o.label and p and p.present ~= false then
            if not said then
                night:say(pick(M.ASKS_OPEN), "dm")
                said = true
            end
            night:emit({ kind = "say", who = key, text = ask.text, ic = false })
            night:say(util.fill(M.ANSWER[answer] or M.ANSWER.agree, { label = o.label }), "dm")
            if o.reply then
                night:emit({ kind = "say", who = key, text = o.reply, ic = false })
            end
        end
    end
end

return M
