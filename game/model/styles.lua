-- Campaign styles (A18): where most of the campaign's time goes, and changing course. The
-- slice's own story is the frontier-town style; cards without a style tag are frontier cards.
-- The deck leans to the home style, with room for the styles it connects to (a port leads to
-- the sea, a stair down to a dungeon). Changing course: ask the table (the group chat says
-- who's keen), nudge with a gateway card the players can take up, or force it with a story
-- event; the style changes the week after the crossing. Pure Lua. Data: game/data/styles.lua.

local content = require "game.model.content"
local score = require "game.model.score"
local util = require "game.model.util"

local M = {}

M.BLEND_WEEKS = 3
M.CROSS_JOIN = 2      -- cards of the style a crossover leads to, joining the deck each time
M.CROSS_MAX = 3       -- times one style can be crossed into before it's simply part of the world

function M.data()
    return content.styles
end

function M.current(campaign)
    return campaign.style or "frontier"
end

function M.def(id)
    return content.styles.styles[id]
end

function M.of(card)
    return card.styles or { "frontier" }
end

-- Styles reachable from home (through its connectors), in this build's set.
function M.reachable(campaign)
    local d = M.def(M.current(campaign))
    local out = {}
    for _, x in ipairs(d and d.cross or {}) do
        if content.styles.styles[x.to] then
            out[x.to] = x.via
        end
    end
    return out
end

-- How much a card leans into this week's hand (deck.hand adds it to the planner's tilt).
function M.tilt(campaign, card)
    local home = M.current(campaign)
    local mine = M.of(card)
    if util.contains(mine, home) then
        -- A way out to the styles next door (a port, a stair, a road) leans a little more.
        local reach = card.cross and M.reachable(campaign) or {}
        for _, t in ipairs(card.cross or {}) do
            if reach[t] then
                return 0.55
            end
        end
        return 0.45
    end
    if util.contains(card.cross or {}, home) then
        return 0.15
    end
    local reach = M.reachable(campaign)
    for _, s in ipairs(mine) do
        if reach[s] then
            return 0.1
        end
    end
    return -0.35
end

-- The scene types a style plays most, best first (its scene mix, for prep's hint).
function M.usual_types(campaign, n)
    local d = M.def(M.current(campaign))
    local list = {}
    for t, w in pairs(d and d.weights or {}) do
        table.insert(list, { t = t, w = w })
    end
    table.sort(list, function(a, b)
        if a.w ~= b.w then
            return a.w > b.w
        end
        return a.t < b.t
    end)
    local out = {}
    for i = 1, math.min(n or 3, #list) do
        out[i] = list[i].t
    end
    return out
end

-- How a player feels about a style, -2..2 (blended 2:1 primary:secondary).
function M.fit(p, id)
    local d = M.def(id)
    local f = d and d.fit or {}
    return (f[p.primary] or 0) * 2 / 3 + (f[p.secondary] or 0) / 3
end

-- Make a style home: its starter cards and its own cards join the deck. how: "start", "ask",
-- "nudge", "force". The table's reaction follows the research: asking first softens everything,
-- a forced shift reads as railroading for those who didn't want it.
function M.set_home(campaign, id, how)
    local d = M.def(id)
    if not d then
        return false
    end
    local deck = require "game.model.deck"
    local from = M.current(campaign)
    campaign.style = id
    campaign.style_since = campaign.week or 1
    for _, cid in ipairs(d.starter or {}) do
        deck.add(campaign, cid, math.max(1, campaign.week or 1), nil, nil)
    end
    for _, c in ipairs(content.styles.cards) do
        if util.contains(c.styles or {}, id) then
            deck.add(campaign, c.id, (campaign.week or 1) + 1, nil, nil)
        end
    end
    if how and how ~= "start" then
        local course = campaign.course or {}
        local asked = course.asked and course.target == id
        local reaction = {}
        for _, p in ipairs(campaign.players) do
            local f = M.fit(p, id)
            local t = 0
            if how == "force" then
                t = f < 0 and (asked and -1.5 or -3) or (asked and 0 or -1)
            elseif how == "nudge" and f < 0 and not asked then
                -- A nudge they took up themselves stings less than a push.
                t = -1
            end
            score.add(p, "trust", t)
            if f >= 1 then
                score.add(p, "investment", 2)
            end
            reaction[p.key] = { trust = t, fit = f }
        end
        campaign.course = { from = from, to = id, how = how, week = campaign.week, asked = asked, reaction = reaction }
    end
    return true
end

-- Ask the table first (in the group chat): free; the replies say who's keen. Returns the posts.
function M.ask(campaign, id)
    local d = M.def(id)
    if not d or not d.gateway or not d.gateway.ask then
        return nil
    end
    campaign.course = { target = id, asked = campaign.week }
    local msgs = campaign.chat or {}
    campaign.chat = msgs
    local g = d.gateway.ask
    table.insert(msgs, { who = "You", key = "dm", text = g.pitch })
    local posts = {}
    local meh = content.styles.meh_lines or { "could be fun. i'm in if everyone else is." }
    for i, p in ipairs(campaign.players) do
        if not p.on_break then
            local f = M.fit(p, id)
            local text = f >= 0.8 and g.love_line or (f <= -0.4 and g.hate_line or meh[(i - 1) % #meh + 1])
            table.insert(msgs, { who = p.name, key = p.key, text = text })
            table.insert(posts, { key = p.key, fit = f, text = text })
            score.add(p, "trust", 1)
            if f >= 0.8 then
                score.add(p, "investment", 1)
            end
        end
    end
    return posts
end

-- A gateway card into a style (nudge: a card whose win changes course; force: a story event).
function M.gateway_card(id, how)
    local d = M.def(id)
    local g = d and d.gateway and d.gateway[how]
    return g and content.components[g.id]
end

-- Put the gateway card in this week's hand (pinned, with why).
function M.plan(campaign, prep, id, how)
    local card = M.gateway_card(id, how)
    if not card then
        return false, "No way in from here."
    end
    local deck = require "game.model.deck"
    deck.add(campaign, card.id, campaign.week, nil, nil)
    local course = campaign.course or {}
    if course.target ~= id then
        course = { target = id }
    end
    campaign.course = course
    course[how] = card.id
    course.planned = campaign.week
    if prep then
        prep:pin(card.id, "course", (how == "force" and "Forces a change of course to " or "Could change course to ")
            .. M.def(id).name .. ".", { added = true })
    end
    return true, card
end

-- A crossover: a card that leads somewhere else (a port, a stair down, a road out) played tonight
-- brings a couple of that style's cards into the deck, so the party can follow it next week.
-- Cards that lead back home come first. Returns the ids that joined.
function M.cross_join(campaign, target, from_id)
    local deck = require "game.model.deck"
    local d = deck.get(campaign)
    local home = M.current(campaign)
    campaign.crossed = campaign.crossed or {}
    if (campaign.crossed[target] or 0) >= M.CROSS_MAX then
        return {}
    end
    local pool = {}
    for _, c in ipairs(content.styles.cards) do
        if util.contains(c.styles or {}, target) and not d.cards[c.id] then
            table.insert(pool, c)
        end
    end
    table.sort(pool, function(a, b)
        local ah, bh = util.contains(a.cross or {}, home), util.contains(b.cross or {}, home)
        if ah ~= bh then
            return ah
        end
        return a.id < b.id
    end)
    local out, kinds = {}, {}
    for _, c in ipairs(pool) do
        if #out >= M.CROSS_JOIN then
            break
        end
        if not kinds[c.kind] then
            kinds[c.kind] = true
            deck.add(campaign, c.id, (campaign.week or 1) + 1, from_id, "cross")
            table.insert(out, c.id)
        end
    end
    if #out > 0 then
        campaign.crossed[target] = (campaign.crossed[target] or 0) + 1
    end
    return out
end

-- After a night: crossovers open the way to other styles, and a gateway card that played changes
-- course (a nudge only if they took it up). Returns { to = style or nil, crossed = { ids } }.
function M.after_night(campaign, night)
    local out = { crossed = {} }
    local home = M.current(campaign)
    local seen = {}
    for _, sc in ipairs(night.scenes or {}) do
        if sc.terrain and sc.outcome then
            for _, c in util.sorted_pairs(sc.comps) do
                for _, t in ipairs(c.cross or {}) do
                    if t ~= home and M.def(t) and not seen[t] then
                        seen[t] = true
                        for _, id in ipairs(M.cross_join(campaign, t, c.id)) do
                            table.insert(out.crossed, { id = id, to = t, via = c.id })
                        end
                    end
                end
            end
        end
    end
    out.to = M.course_after(campaign, night)
    return out
end

function M.course_after(campaign, night)
    local course = campaign.course
    if not course or not course.target then
        return nil
    end
    for _, sc in ipairs(night.scenes or {}) do
        if sc.terrain and sc.outcome then
            for _, c in util.sorted_pairs(sc.comps) do
                if c.gateway == course.target then
                    if c.id == course.force then
                        M.set_home(campaign, course.target, "force")
                        return course.target
                    elseif c.id == course.nudge and sc.outcome == "win" then
                        M.set_home(campaign, course.target, "nudge")
                        return course.target
                    end
                end
            end
        end
    end
    return nil
end

-- The group chat the week after a change of course: the keen are excited, whoever had it forced
-- on them says so, and whoever misses the old style says that too.
function M.chat(campaign, msgs)
    local course = campaign.course
    if not course or not course.how or course.how == "start" or course.week ~= (campaign.week or 1) - 1 then
        return
    end
    local lines = content.styles.after_lines
    local to, from = M.def(course.to), M.def(course.from)
    if not lines or not to then
        return
    end
    local vars = { home = to.name, old = from and from.name or "the old place" }
    local n = 0
    for i, p in ipairs(campaign.players) do
        local re = course.reaction and course.reaction[p.key]
        if re and not p.on_break and n < 3 then
            local pool
            if re.fit >= 1 then
                pool = lines.keen
            elseif re.trust <= -1.5 then
                pool = lines.forced
            elseif re.fit < 0 then
                pool = lines.miss
            end
            if pool then
                local text = util.fill(pool[((campaign.week or 1) + i) % #pool + 1], vars)
                table.insert(msgs, { who = p.name, key = p.key, text = text })
                n = n + 1
            end
        end
    end
end

-- The first weeks after a change: whoever preferred the old style misses it a little.
-- Returns who (keys), and keeps it on the campaign for the night's tells.
function M.night_start(campaign, players)
    local since = campaign.style_since
    local course = campaign.course
    campaign.style_missed = nil
    if not since or not course or not course.from or (campaign.week - since) >= M.BLEND_WEEKS then
        return {}
    end
    local who = {}
    for _, p in ipairs(players) do
        if M.fit(p, campaign.style) < 0 and M.fit(p, course.from) > M.fit(p, campaign.style) then
            score.add(p, "fun", course.asked and -1 or -2)
            table.insert(who, p.key)
        end
    end
    campaign.style_missed = { week = campaign.week, keys = who }
    return who
end

return M
