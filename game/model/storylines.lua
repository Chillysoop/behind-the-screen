-- Storylines (game/data/storylines.lua): the stories a campaign runs at once, and how well the
-- DM is juggling them. Each night, the scenes that play move the storylines their cards belong
-- to. An open storyline left alone past its `cold` weeks becomes a loose end: the table notices,
-- and the players who cared lose a little Investment and Trust each week it stays loose, down
-- to a floor. When it comes back they're surprised and glad, and get back what they lost. Too
-- many storylines in one night and the table loses the thread; two scenes on the same one and
-- it all starts connecting. Pure Lua.
--
-- campaign.storylines = { [id] = {
--   state    "open", "resolved" or "ended" (a backstory whose hero fell); missing: not opened
--   opened   the week it opened; last: the last week it moved; moves: nights it moved
--   loose    the week the table noticed it had been dropped (nil while it's alive)
--   eroded   { [player key] = { investment = n, trust = n } }: what the loose end has cost so far
--   back     the week it came back from being loose; resolved: the week it was tied off
--   char     a backstory's hero (a new character starts a new story) } }

local data = require "game.data.storylines"
local content = require "game.model.content"
local score = require "game.model.score"
local util = require "game.model.util"

local M = {}
M.data = data

-- Card id -> fixed storylines it moves; person id -> storylines.
local by_card, by_person
local function index()
    if by_card then
        return
    end
    by_card, by_person = {}, {}
    for _, id in ipairs(data.order) do
        for _, cid in ipairs(data[id].cards or {}) do
            by_card[cid] = by_card[cid] or {}
            table.insert(by_card[cid], id)
        end
        for _, pid in ipairs(data[id].people or {}) do
            by_person[pid] = by_person[pid] or {}
            table.insert(by_person[pid], id)
        end
    end
end

local function featured(campaign, key)
    local plan = campaign.plan
    return plan and util.contains(plan.threads or {}, key) or false
end

-- Every storyline this campaign has: the fixed ones, then one backstory per player.
function M.defs(campaign)
    local out = {}
    for _, id in ipairs(data.order) do
        local d = data[id]
        table.insert(out, { id = id, name = d.name, short = d.short, kind = d.kind, about = d.about, open = d.open,
                            cold = d.cold, color = d.color, ends = d.ends, noticed = d.noticed, back = d.back })
    end
    local bs = data.backstory
    for _, p in ipairs(campaign.players or {}) do
        table.insert(out, { id = "bs_" .. p.key, key = p.key, kind = "backstory", open = "start",
                            name = p.char .. "'s story", short = p.char, about = util.capitalize(p.thread or ""),
                            cold = featured(campaign, p.key) and bs.cold_featured or bs.cold, color = bs.color,
                            featured = featured(campaign, p.key) })
    end
    return out
end

function M.def(campaign, id)
    for _, d in ipairs(M.defs(campaign)) do
        if d.id == id then
            return d
        end
    end
end

-- The state table, with the storylines that start open already open (and a backstory whose
-- hero fell closed, its new hero's story waiting for its first card).
function M.get(campaign)
    campaign.storylines = campaign.storylines or {}
    local s = campaign.storylines
    for _, d in ipairs(M.defs(campaign)) do
        local st = s[d.id]
        if d.kind == "backstory" then
            local p = campaign:player(d.key)
            if st and p and st.char and st.char ~= p.char then
                -- Their hero fell: that story ended with them, nobody's let down by it.
                s["ended_" .. d.id .. "_" .. st.char] = { state = "ended", char = st.char, opened = st.opened,
                                                          last = st.last, moves = st.moves }
                st = nil
                s[d.id] = nil
                if p.pregen then
                    -- The new hero has no story cards yet: it opens when one plays.
                    s[d.id] = { state = "waiting", char = p.char }
                end
            end
            if not st and not s[d.id] and p then
                s[d.id] = { state = "open", opened = 1, last = 0, moves = 0, char = p.char, eroded = {} }
            end
        elseif d.open == "start" and not st then
            s[d.id] = { state = "open", opened = 1, last = 0, moves = 0, eroded = {} }
        end
    end
    return s
end

function M.state(campaign, id)
    return M.get(campaign)[id]
end

-- Which storylines a card moves. A backstory card moves its hero's story only while that hero
-- is still the one at the table.
function M.of_card(campaign, c)
    index()
    if not c then
        return {}
    end
    local out, seen = {}, {}
    local function add(id)
        if not seen[id] then
            seen[id] = true
            table.insert(out, id)
        end
    end
    for _, id in ipairs(by_card[c.id] or {}) do
        add(id)
    end
    if c.agenda then
        for _, id in ipairs(by_person[c.agenda] or {}) do
            add(id)
        end
    end
    if c.thread then
        local deck = require "game.model.deck"
        if deck.thread_live(campaign, c) then
            add("bs_" .. c.thread)
        end
    end
    return out
end

-- How the storyline stands as week `week` is prepped: "unopened", "warm", "cooling" (one more
-- week and it's cold), "cold" (moves this week or the table notices), "loose" (noticed),
-- "resolved" or "ended". And how many weeks since it last moved.
function M.heat(campaign, id, week)
    week = week or campaign.week
    local st = M.get(campaign)[id]
    if not st or st.state == "waiting" then
        return "unopened", 0
    elseif st.state == "resolved" or st.state == "ended" then
        return st.state, 0
    end
    local d = M.def(campaign, id)
    -- A handout keeps a storyline warm a week longer (game/model/handouts.lua): the table keeps
    -- looking at it.
    local base = math.max(st.last or 0, st.opened or 1, math.min(st.kept or 0, week))
    local since = week - base
    if st.loose then
        return "loose", since
    elseif since >= (d and d.cold or 2) then
        return "cold", since
    elseif since >= (d and d.cold or 2) - 1 and since > 0 then
        return "cooling", since
    end
    return "warm", since
end

-- What this week's board moves: { [id] = scenes }, and the ids in order of how much.
function M.board(campaign, prep)
    local count = {}
    for _, s in ipairs(prep and prep.scenes or {}) do
        local here = {}
        for _, c in pairs(s.slots or {}) do
            for _, id in ipairs(M.of_card(campaign, c)) do
                here[id] = true
            end
        end
        for id in pairs(here) do
            count[id] = (count[id] or 0) + 1
        end
    end
    local ids = {}
    for id in pairs(count) do
        table.insert(ids, id)
    end
    table.sort(ids, function(a, b)
        if count[a] ~= count[b] then
            return count[a] > count[b]
        end
        return a < b
    end)
    return count, ids
end

-- Open storylines (not resolved or ended), in data order then backstories.
function M.open_list(campaign)
    local s = M.get(campaign)
    local out = {}
    for _, d in ipairs(M.defs(campaign)) do
        local st = s[d.id]
        if st and st.state == "open" then
            table.insert(out, d)
        end
    end
    return out
end

-- Who a storyline's loose end wears down, and how fast: { { p, rate } }.
local function carers(campaign, d)
    local out = {}
    for _, p in ipairs(campaign.players) do
        if not p.on_break then
            local fan = data.STORY_FANS[p.primary] or data.STORY_FANS[p.secondary]
            if d.kind == "backstory" then
                if p.key == d.key then
                    table.insert(out, { p = p, rate = 1 })
                end
            elseif d.kind == "major" then
                table.insert(out, { p = p, rate = fan and 1 or 0.5 })
            elseif fan then
                table.insert(out, { p = p, rate = 1 })
            end
        end
    end
    return out
end

-- What every loose end together has taken from one player so far.
local function eroded_total(campaign, key)
    local ti, tt = 0, 0
    for _, st in pairs(campaign.storylines or {}) do
        local got = st.eroded and st.eroded[key]
        if got then
            ti, tt = ti + (got.investment or 0), tt + (got.trust or 0)
        end
    end
    return ti, tt
end

-- One week's wear from a loose end, down to its floor (and never past the overall one).
local function erode(campaign, d, st)
    local e = data.ERODE[d.kind] or data.ERODE.minor
    st.eroded = st.eroded or {}
    for _, cr in ipairs(carers(campaign, d)) do
        local p, rate = cr.p, cr.rate
        local got = st.eroded[p.key] or { investment = 0, trust = 0 }
        st.eroded[p.key] = got
        local ti, tt = eroded_total(campaign, p.key)
        local di = math.min(e.investment * rate, e.floor_investment - got.investment, data.ERODE_TOTAL.investment - ti)
        local dt = math.min(e.trust * rate, e.floor_trust - got.trust, data.ERODE_TOTAL.trust - tt)
        if di > 0 then
            score.add(p, "investment", -di)
            got.investment = got.investment + di
        end
        if dt > 0 then
            score.add(p, "trust", -dt)
            got.trust = got.trust + dt
        end
    end
end

-- Who notices a dropped storyline, and what they say.
local function noticer(campaign, d)
    if d.kind == "backstory" then
        local p = campaign:player(d.key)
        if p and not p.on_break then
            return p, data.backstory.noticed[p.key] or util.fill(data.backstory.other_noticed, { char = p.char })
        end
        return nil
    end
    local best
    for _, p in ipairs(campaign.players) do
        if not p.on_break and (not best or (data.STORY_FANS[p.primary] and not data.STORY_FANS[best.primary])) then
            best = p
        end
    end
    local lines = d.noticed or {}
    return best, lines[((campaign.week or 1) % math.max(1, #lines)) + 1]
end

-- At the table ------------------------------------------------------------------------------

local function line_for(night, list, key)
    if type(list) == "string" then
        return list
    end
    return night:fresh(list, key)
end

-- A scene plays: the storylines its cards move. Opens new ones, brings back dropped ones (the
-- surprise), and reads how many the table is holding tonight.
function M.on_scene(night, sc)
    local campaign = night.campaign
    local deck = require "game.model.deck"
    local story = require "game.model.story"
    local s = M.get(campaign)
    night.story_moved = night.story_moved or {}
    night.story_scene = night.story_scene or {}
    local here, seen = {}, {}
    for _, kind in ipairs(content.kinds) do
        local c = sc.comps[kind]
        if c and not night:muted(c) and night:fits_here(c) then
            -- A place moves a story when it's new to the party or tells its part; going back to
            -- the Kettle for a drink isn't the bells' story.
            local counts = c.kind ~= "location" or story.pending_reveal(campaign, c) ~= nil
                or ((deck.entry(campaign, c.id) or {}).plays or 0) == 0
            if counts then
                for _, id in ipairs(M.of_card(campaign, c)) do
                    if not seen[id] then
                        seen[id] = true
                        table.insert(here, id)
                    end
                end
            end
        end
    end
    -- What this scene moved, for the Story log (game/model/chronicle.lua).
    sc.stories = here
    -- Threads the table has to hold apart: storylines one card ties together count as one (the
    -- Velvet Hand's back room is the bells' story and Pip's at once), so weaving stories is
    -- easier to follow than juggling them side by side.
    night.story_links = night.story_links or {}
    for _, kind in ipairs(content.kinds) do
        local c = sc.comps[kind]
        if c and not night:muted(c) then
            local ids = M.of_card(campaign, c)
            for i = 2, #ids do
                table.insert(night.story_links, { ids[1], ids[i] })
            end
        end
    end
    for _, id in ipairs(here) do
        local d = M.def(campaign, id)
        local st = s[id]
        if d and (not st or st.state == "open" or st.state == "waiting") then
            if not st or st.state == "waiting" then
                s[id] = { state = "open", opened = campaign.week, last = campaign.week, moves = 0, eroded = {},
                          char = st and st.char or nil }
                st = s[id]
                night.story_opened = night.story_opened or {}
                night.story_opened[id] = true
            elseif st.loose then
                M.come_back(night, d, st)
            end
            night.story_moved[id] = (night.story_moved[id] or 0) + 1
            if night.story_moved[id] == data.MOMENTUM_SCENES then
                M.momentum(night, d)
            end
        end
    end
    -- Too many at once: each separate thread past the cap tonight loses the table a little.
    local n = M.threads_tonight(night)
    night.story_thin_said = night.story_thin_said or 0
    if n > data.ACTIVE_CAP and n > night.story_thin_said + data.ACTIVE_CAP then
        night.story_thin_said = n - data.ACTIVE_CAP
        M.spread_thin(night, n)
    end
end

-- How many separate threads tonight's storylines make (linked ones count once).
function M.threads_tonight(night)
    local parent = {}
    local function find(x)
        while parent[x] and parent[x] ~= x do
            x = parent[x]
        end
        return x
    end
    for id in pairs(night.story_moved or {}) do
        parent[id] = parent[id] or id
    end
    for _, l in ipairs(night.story_links or {}) do
        if parent[l[1]] and parent[l[2]] then
            local a, b = find(l[1]), find(l[2])
            if a ~= b then
                parent[a] = b
            end
        end
    end
    local roots = {}
    local n = 0
    for id in pairs(parent) do
        local r = find(id)
        if not roots[r] then
            roots[r] = true
            n = n + 1
        end
    end
    return n
end

-- A dropped storyline comes back: surprise, delight, and what the loose end wore away returns.
function M.come_back(night, d, st)
    local campaign = night.campaign
    local fx = data.BACK[d.kind] or data.BACK.minor
    for key, got in pairs(st.eroded or {}) do
        local p = campaign:player(key)
        if p then
            score.add(p, "investment", got.investment or 0)
            score.add(p, "trust", got.trust or 0)
        end
    end
    st.eroded = {}
    st.loose = nil
    st.back = campaign.week
    night.story_back = night.story_back or {}
    night.story_back[d.id] = true
    local who
    if d.kind == "backstory" then
        for _, p in ipairs(night.players) do
            if p.key == d.key then
                who = p
            end
        end
    else
        who = night:pick_actor({ "storyteller", "explorer", "method_actor" })
    end
    local targets = {}
    for _, p in ipairs(night.players) do
        if d.kind ~= "backstory" or p == who then
            table.insert(targets, p)
        end
    end
    for _, p in ipairs(targets) do
        for k, v in pairs(fx) do
            score.add(p, k, v)
        end
    end
    if who then
        local text = d.kind == "backstory" and (data.backstory.back[who.key]
            or util.fill(data.backstory.other_back, { char = who.char })) or line_for(night, d.back or {}, "story_back_" .. d.id)
        if text then
            night:emit({ kind = "say", who = who.key, text = text, ic = false })
        end
        night:react({ [who.key] = "cheer" })
        night:highlight(8, (d.kind == "backstory" and (who.char .. "'s story") or d.name) .. " came back when nobody expected it",
            { who }, "thread_back")
    end
    night:emit({ kind = "story_back", id = d.id, name = d.name, who = who and who.key })
end

function M.momentum(night, d)
    -- Once a night: the moment it clicks, not every time a thread comes round again.
    night.story_momentum = night.story_momentum or {}
    if next(night.story_momentum) then
        return
    end
    night.story_momentum[d.id] = true
    local who = night:pick_actor({ "storyteller", "explorer", "tactician" })
    for _, p in ipairs(night.players) do
        score.add(p, "story", data.MOMENTUM.story)
        if data.STORY_FANS[p.primary] then
            score.add(p, "investment", data.MOMENTUM.investment)
        end
    end
    if who then
        night:emit({ kind = "say", who = who.key, text = night:fresh(data.MOMENTUM_LINES, "story_momentum"), ic = false })
        night:react({ [who.key] = "lean" })
    end
end

function M.spread_thin(night, n)
    night.story_thin = n
    local who = night:pick_actor({ "casual", "storyteller", "tactician" })
    for _, p in ipairs(night.players) do
        for k, v in pairs(data.THIN) do
            score.add(p, k, v)
        end
    end
    if who then
        night:emit({ kind = "say", who = who.key, text = night:fresh(data.THIN_LINES, "story_thin"), ic = false })
        night:react({ [who.key] = "think" })
    end
    night:event("spread_thin", { who = "party", text = "The table lost the thread: " .. util.int(n) .. " storylines in one night.",
                                 weight = 2 })
end

-- After the night ----------------------------------------------------------------------------

-- The night's done: what moved, what opened, what came back, what's been dropped long enough
-- for the table to notice, and a week's wear from every loose end. Returns the report's summary.
function M.after_night(campaign, night)
    local s = M.get(campaign)
    local week = campaign.week
    local out = { moved = {}, opened = {}, back = {}, noticed = {}, cold = {}, resolved = {}, thin = night.story_thin }
    for id, n in pairs(night.story_moved or {}) do
        local st = s[id]
        if st and st.state == "open" then
            st.last = week
            st.moves = (st.moves or 0) + 1
            table.insert(out.moved, id)
        end
    end
    for id in pairs(night.story_opened or {}) do
        table.insert(out.opened, id)
    end
    for id in pairs(night.story_back or {}) do
        table.insert(out.back, id)
    end
    -- A minor story tied off: its end card's scene was won.
    local deck = require "game.model.deck"
    for _, sc in ipairs(night.scenes or {}) do
        if deck.outcome_of(sc) == "win" then
            for _, c in pairs(sc.comps) do
                for _, d in ipairs(M.defs(campaign)) do
                    local st = s[d.id]
                    if st and st.state == "open" and d.ends and util.contains(d.ends, c.id) then
                        st.state = "resolved"
                        st.resolved = week
                        st.loose = nil
                        table.insert(out.resolved, d.id)
                    end
                end
            end
        end
    end
    -- Dropped too long: the table notices. Then every loose end wears a little.
    campaign.story_noticed = {}
    for _, d in ipairs(M.defs(campaign)) do
        local st = s[d.id]
        if st and st.state == "open" then
            local heat = M.heat(campaign, d.id, week)
            if heat == "cold" and not (night.story_moved or {})[d.id] then
                st.loose = week
                table.insert(out.noticed, d.id)
                local p, text = noticer(campaign, d)
                if p and text then
                    table.insert(campaign.story_noticed, { id = d.id, key = p.key, text = text })
                end
            elseif heat == "cooling" and not (night.story_moved or {})[d.id] then
                table.insert(out.cold, d.id)
            end
            if st.loose then
                erode(campaign, d, st)
            end
        end
    end
    table.sort(out.moved)
    table.sort(out.noticed)
    return out
end

-- The loose ends right now: { def, since week noticed }.
function M.loose(campaign)
    local out = {}
    for _, d in ipairs(M.defs(campaign)) do
        local st = M.get(campaign)[d.id]
        if st and st.state == "open" and st.loose then
            table.insert(out, { def = d, since = st.loose })
        end
    end
    return out
end

-- For the prep board: what this week's plan does to the storylines, and what needs a word.
-- Returns { touched = { def... }, cold = { def... } (moves this week or the table notices),
-- loose = { def... }, thin = bool (more than the table can follow), open = n }.
function M.forecast(campaign, prep)
    local count, ids = M.board(campaign, prep)
    local out = { touched = {}, cold = {}, loose = {}, cooling = {}, open = 0, counts = count }
    for _, id in ipairs(ids) do
        local d = M.def(campaign, id)
        local st = M.get(campaign)[id]
        if d and not (st and (st.state == "resolved" or st.state == "ended")) then
            table.insert(out.touched, d)
        end
    end
    for _, d in ipairs(M.open_list(campaign)) do
        out.open = out.open + 1
        local heat = M.heat(campaign, d.id)
        if not count[d.id] then
            if heat == "loose" then
                table.insert(out.loose, d)
            elseif heat == "cold" then
                table.insert(out.cold, d)
            elseif heat == "cooling" then
                table.insert(out.cooling, d)
            end
        end
    end
    out.thin = #out.touched > data.ACTIVE_CAP
    return out
end

return M
