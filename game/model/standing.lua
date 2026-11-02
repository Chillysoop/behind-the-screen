-- Where everyone stands (v2, November 1): the DM's recap on game night, for making a call with the
-- story and the table both in view. The Story sidebar: the adventure's sides (MODULE.sides), each
-- with its key people and where each stands now. The Table sidebar: each friend, why they came and
-- whether it's paid off, what kind of night they love, who and what in the story they're drawn to
-- (or put off by), how they seem tonight, and how well you know them. Only what the DM could know:
-- tells, not hidden numbers; a want only once you've read it. Pure Lua.
--
-- Affinity (who at the table is drawn to whom): the kinds of player a person appeals to (likes),
-- the hero whose reason for coming lives in their room, and what's happened at the table since: a
-- moment with them that a friend loved (or hated) moves that friend toward (or away from) them.

local util = require "game.model.util"
local score = require "game.model.score"
local content = require "game.model.content"
local familiar = require "game.model.familiar"
local adventure = require "game.model.adventure"

local M = {}

M.KEEN, M.INTERESTED, M.PUT_OFF = 2, 1.2, -1
M.STEP = 0.5                       -- how far one strong moment moves a friend toward someone

local function sides()
    return (adventure.data and adventure.data.sides) or nil
end

-- Is there a recap to show? (The adventure has sides.)
function M.has(campaign)
    return campaign ~= nil and campaign.module ~= nil and campaign.adv ~= nil and sides() ~= nil
end

local function holds(st, when)
    if not when then
        return true
    end
    if when.done and not st.done[when.done] then
        return false
    end
    if when.mark and not st.marks[when.mark] then
        return false
    end
    if when.flag and not st.flags[when.flag] then
        return false
    end
    if when.favor and ((st.favors or {})[when.favor.who] or 0) < (when.favor.at or 1) then
        return false
    end
    return true
end

-- A person's line now: text, tone ("good" | "bad" | "quiet"), met (false while they're still ahead).
function M.member_line(campaign, m)
    local st = campaign.adv
    for _, s in ipairs(m.states or {}) do
        if holds(st, s.when) then
            return util.fill(s.text, { mech = st.mech_name or "the Mech" }), s.tone or "quiet", true
        end
    end
    if m.room then
        if st.pos == m.room then
            return "Here, right now", "quiet", true
        elseif st.skipped[m.room] then
            return "Never met: left behind", "quiet", true
        elseif (st.passed or {})[m.room] then
            return "Walked past", "quiet", true
        end
    end
    return "Still ahead", "quiet", false
end

-- The boss: how she feels about them, her marks, who's with her.
function M.boss_line(campaign, side)
    local st = campaign.adv
    local n = #(st.mark_list or {})
    local talk = adventure.talk_score(campaign)
    local mood = (talk >= 2 and "Curious about them") or (talk <= -2 and "Angry with them") or "Watching them"
    local with = {}
    for _, id in ipairs(adventure.data.mark_order or {}) do
        if st.marks[id] and side.with and side.with[id] then
            table.insert(with, side.with[id])
        end
    end
    local line = mood .. ". " .. util.int(n) .. (n == 1 and " mark on her card." or " marks on her card.")
    local tone = (talk >= 2 and "good") or (talk <= -2 and "bad") or "quiet"
    return line, tone, (#with > 0) and ("With her: " .. util.join_names(with) .. ".") or "Nobody with her yet."
end

-- How drawn a friend is to someone: their kind of player, their reason for coming, and the table since.
local function base_like(p, likes)
    likes = likes or {}
    return (2 * (likes[p.primary] or 0) + (likes[p.secondary] or 0)) / 3
end

function M.affinity(campaign, m, p)
    local n = base_like(p, m.likes)
    local h = adventure.hook(campaign, p.key)
    if h and m.room and h.room == m.room then
        n = n + 1.5
    end
    local live = campaign.adv.affinity and campaign.adv.affinity[m.id]
    return n + ((live and live[p.key]) or 0)
end

-- "keen" | "interested" | "put_off" | nil
function M.feeling(n)
    if n >= M.KEEN then
        return "keen"
    elseif n >= M.INTERESTED then
        return "interested"
    elseif n <= M.PUT_OFF then
        return "put_off"
    end
    return nil
end

-- A moment with someone just played: whoever loved it is drawn a little closer to them, whoever hated
-- it a little further away. ids: the people it was with; before: each friend's Fun going in.
function M.note(night, ids, before)
    local st = night.campaign and night.campaign.adv
    if not st or not before or #ids == 0 then
        return
    end
    st.affinity = st.affinity or {}
    for _, p in ipairs(night.players or {}) do
        local f = score.fun(p)
        local d = f - (before[p.key] or f)
        local step = (d >= 4 and M.STEP) or (d <= -4 and -M.STEP) or 0
        if step ~= 0 then
            for _, id in ipairs(ids) do
                st.affinity[id] = st.affinity[id] or {}
                st.affinity[id][p.key] = util.clamp((st.affinity[id][p.key] or 0) + step, -2, 2)
            end
        end
    end
end

-- The Story sidebar: { { name, about, people = { { id, name, role, line, tone, met, boss, with,
-- keen = { keys }, cold = { keys } } } } }, people ahead last.
function M.story(campaign)
    local out = {}
    for _, side in ipairs(sides() or {}) do
        local s = { id = side.id, name = side.name, about = side.about, people = {}, ahead = {} }
        for _, m in ipairs(side.members or {}) do
            local row = { id = m.id, name = m.name, role = m.role, boss = m.boss, keen = {}, cold = {} }
            if m.boss then
                row.line, row.tone, row.with = M.boss_line(campaign, side)
                row.met = true
            else
                row.line, row.tone, row.met = M.member_line(campaign, m)
            end
            for _, p in ipairs(campaign.players) do
                local f = M.feeling(M.affinity(campaign, m, p))
                if f == "keen" or f == "interested" then
                    table.insert(row.keen, { key = p.key, strong = f == "keen" })
                elseif f == "put_off" then
                    table.insert(row.cold, p.key)
                end
            end
            table.insert(row.met and s.people or s.ahead, row)
        end
        table.insert(out, s)
    end
    return out
end

-- What kinds of night a friend loves and which bore them (as on the prep board): two of each.
local function tastes(p)
    local loves, bored = {}, {}
    for _, id in ipairs(content.scenes.order or {}) do
        local t = score.taste(p, id)
        if t >= 1 then
            table.insert(loves, { id, t })
        elseif t < 0 then
            table.insert(bored, { id, t })
        end
    end
    table.sort(loves, function(a, b) return a[2] > b[2] end)
    table.sort(bored, function(a, b) return a[2] < b[2] end)
    local function names(list)
        local o = {}
        for k, e in ipairs(list) do
            if k <= 2 then
                table.insert(o, content.scenes[e[1]].name)
            end
        end
        return #o > 0 and table.concat(o, ", ") or nil
    end
    return names(loves), names(bored)
end

-- The Table sidebar: one row per friend.
-- { key, name, char, present, hook = { name, room, state }, loves, bored, drawn = { names },
--   cold = { names }, tonight = { tell, tier }, read = want, known, level, of }
function M.table(campaign, night)
    local out = {}
    local st = campaign.adv
    local tells = night and night.tells and night:tells() or {}
    local everyone = {}
    for _, side in ipairs(sides() or {}) do
        for _, m in ipairs(side.members or {}) do
            table.insert(everyone, m)
        end
    end
    for _, p in ipairs(campaign.players) do
        local row = { key = p.key, name = p.name, char = p.char, present = p.present ~= false }
        local h = adventure.hook(campaign, p.key)
        if h then
            local r = adventure.data.rooms[h.room]
            -- (Paid off only when the beat played with them there: museum_night.room_start.)
            local paid = (st.hook_paid or {})[p.key] ~= nil
            local state = (paid and "paid off") or ((st.done[h.room] or st.skipped[h.room] or (st.passed or {})[h.room]) and "missed so far")
                or "still to come"
            row.hook = { name = h.name, room = r and r.name or h.room, state = state }
        end
        row.loves, row.bored = tastes(p)
        local drawn, cold = {}, {}
        for _, m in ipairs(everyone) do
            local a = M.affinity(campaign, m, p)
            if M.feeling(a) == "keen" then
                table.insert(drawn, { m.name, a })
            elseif M.feeling(a) == "put_off" then
                table.insert(cold, { m.name, a })
            end
        end
        table.sort(drawn, function(a, b) return a[2] > b[2] end)
        table.sort(cold, function(a, b) return a[2] < b[2] end)
        row.drawn, row.cold = {}, {}
        for k, e in ipairs(drawn) do
            if k <= 3 then
                table.insert(row.drawn, e[1])
            end
        end
        for k, e in ipairs(cold) do
            if k <= 2 then
                table.insert(row.cold, e[1])
            end
        end
        local t = tells[p.key]
        if t and row.present then
            row.tonight = { tell = t.text, tier = score.tier(t.fun), engagement = t.engagement }
        end
        -- The last of their thoughts you read tonight (game/model/thoughts.lua): what they wanted.
        local th = night and night.th
        if th then
            local best
            for id, tt in pairs(th.list) do
                if tt.who == p.key and tt.read and tt.read.result ~= "miss" and not tt.glow and (not best or id > best) then
                    best = id
                end
            end
            if best then
                row.read = require("game.model.thoughts").want_of(night, best)
            end
        end
        row.known = familiar.name(campaign, p.key)
        row.level, row.of = familiar.dots(campaign, p.key)
        table.insert(out, row)
    end
    return out
end

return M
