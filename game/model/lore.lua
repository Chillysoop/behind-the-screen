-- The world's iconography and the opening of session 1 (October 15; the data is
-- game/data/lore.lua). One icon per storyline, faction, front and truth, so a card, a pip on the
-- board, a line in the Story log and the opening all say "the bells" or "the Hand" the same way,
-- at a glance. The opening is the DM setting up the world before the introductions; the briefing
-- after them says what matters, where the heroes are and what to do first. Pure Lua.

local content = require "game.model.content"
local util = require "game.model.util"

local M = {}
M.data = content.lore

-- What the heroes are out to do this week, as a sentence: the arc beat's objective
-- (game/data/arc.lua), or objective_if once they know the clue it hangs on. Shown on the
-- briefing, the prep board's story box and the night's header, so the DM always knows. nil
-- past the slice.
function M.objective(campaign, week)
    local beat = campaign:arc_beat(week)
    local obj = beat and beat.objective
    if obj and beat.objective_if and util.lazy("game.model.story").has_clue(campaign, beat.objective_if.clue) then
        obj = beat.objective_if.text
    end
    return obj and (util.capitalize(obj) .. ".") or nil
end

local function copy(t)
    local out = {}
    for k, v in pairs(t or {}) do
        out[k] = v
    end
    return out
end

function M.icon(kind, id)
    return (M.data.icons[kind] or {})[id]
end

-- How a storyline shows: { icon, color } for a world story, { face = player key, color } for a
-- hero's own (their face is their icon).
function M.storyline(campaign, id)
    local d = util.lazy("game.model.storylines").def(campaign, id)
    if not d then
        return nil
    end
    if d.kind == "backstory" then
        return { face = d.key, color = d.color, name = d.short or d.name }
    end
    return { icon = M.data.icons.storylines[id] or "story", color = d.color, name = d.short or d.name }
end

function M.faction(id)
    return { icon = M.data.icons.factions[id] or "crown", color = M.data.faction_colors[id] or "#a08ab0" }
end

-- The opening, a card at a time: the town, the story, the danger, the campaign's second front,
-- then what everyone knows (the planner's truths).
function M.opening(campaign)
    local o = M.data.opening
    local plan = campaign.plan or {}
    local planner = util.lazy("game.model.planner")
    local slides = { copy(o.town), copy(o.bells), copy(o.kessrick) }
    local f = plan.front and o.fronts[plan.front]
    if f then
        table.insert(slides, copy(f))
    elseif plan.front then
        local fd = planner.data.fronts[plan.front]
        if fd then
            table.insert(slides, { icon = "crown", color = "#a08ab0", kicker = "ALSO IN THE VALE", title = fd.name,
                                   text = fd.about or fd.impulse })
        end
    end
    local rows = {}
    for _, tid in ipairs(plan.truths or {}) do
        local t = planner.truth_def(tid)
        if t then
            table.insert(rows, { icon = M.data.icons.truths[tid] or "story", title = t.name, text = t.about })
        end
    end
    if #rows > 0 then
        table.insert(slides, { kicker = o.truths.kicker, title = o.truths.title, rows = rows, icon = "story",
                               color = "#c8a24a" })
    end
    slides[#slides].footer = o.last
    return slides
end

-- After the introductions: the key lore in a line each, what each hero is after, where they are
-- and what to do first. where/first come from the night (scene 1 and this week's objective).
function M.briefing(campaign, where, first)
    local b = M.data.briefing
    local o = M.data.opening
    local plan = campaign.plan or {}
    local later = (campaign.week or 1) >= 2 and b.rows_later or {}
    local rows = {
        { icon = o.bells.icon, color = o.bells.color, text = later.bells or b.rows.bells },
        { icon = o.kessrick.icon, color = o.kessrick.color, text = b.rows.kessrick },
    }
    local f = plan.front and o.fronts[plan.front]
    if f and b.rows[plan.front] then
        table.insert(rows, { icon = f.icon, color = f.color, text = b.rows[plan.front] })
    end
    for _, p in ipairs(campaign.players or {}) do
        local pd = content.players[p.key]
        if p.present and pd and pd.gist and pd.char == p.char then
            table.insert(rows, { face = p.key, text = pd.gist .. "." })
        end
    end
    return { kicker = b.kicker, rows = rows, where = where, where_label = b.where, first = first, first_label = b.first,
             briefing = true }
end

-- Which storyline a clue belongs to: its card's first (a story card that's no storyline's own is
-- the main story's). nil for no clue.
function M.clue_storyline(campaign, clue)
    local c = clue and content.components[clue]
    if not c then
        return nil
    end
    -- The most particular one: the Hand's own story over the main one when a clue is both.
    local main = M.data.briefing.next_story
    local ids = util.lazy("game.model.storylines").of_card(campaign, c)
    for _, id in ipairs(ids) do
        if id ~= main then
            return id
        end
    end
    return ids[1] or main
end

-- How a clue shows: { icon, color } or { face } (lore data's clue_marks first, else its storyline's).
function M.clue_mark(campaign, clue)
    local o = M.data.clue_marks and M.data.clue_marks[clue or ""]
    if o and string.sub(o, 1, 6) == "front:" then
        local fid = string.sub(o, 7)
        local slide = M.data.opening[fid] or (M.data.opening.fronts or {})[fid]
        return { icon = M.data.icons.fronts[fid] or "story", color = slide and slide.color or "#c0663e" }
    end
    local id = o or M.clue_storyline(campaign, clue)
    return id and M.storyline(campaign, id) or nil
end

-- Last session's clues as rows, each under its storyline's icon (the bell, the hand, a hero's
-- face), at most `max`. With no clues, the recap line instead (or nothing).
function M.found_rows(campaign, max, recap)
    local rows = {}
    local learned, happened = util.lazy("game.model.recap").last_learned(campaign)
    -- What happened, first (the night's biggest beat, under the face of whoever did it).
    if happened and (max or 3) >= 3 then
        local p = happened.who and content.players[happened.who]
        table.insert(rows, { icon = "story", color = "#c8a24a", face = p and happened.who or nil, text = happened.text,
                             lines = 2, found = true })
    end
    for _, f in ipairs(learned) do
        if #rows >= (max or 3) then
            break
        end
        local m = M.clue_mark(campaign, f.clue)
        local row = { icon = "story", color = "#c8a24a", text = f.text, lines = 3, found = true }
        if m then
            row.icon, row.face, row.color = m.icon, m.face, m.color
        end
        table.insert(rows, row)
    end
    if #rows == 0 and recap then
        table.insert(rows, { icon = "story", color = "#c8a24a", lines = 3, found = true,
                             text = (string.gsub(recap, "^Last session: ", "")) })
    end
    return rows
end

-- The card that opens every session after the first (October 15): what they found out last time,
-- where they are, what's next. The DM's recap, the way a real one starts the night.
function M.previously(campaign, where, first, recap)
    local b = M.data.briefing
    local week = (campaign.week or 2) - 1
    local title
    for _, le in ipairs(campaign.session_log or {}) do
        if le.week == week and le.recap and le.recap.titles then
            title = le.recap.titles[le.recap.title or 1]
        end
    end
    local rows = M.found_rows(campaign, 3, recap)
    return { kicker = string.format(b.previously, week) .. (title and (": \"" .. title .. "\"") or ""),
             sub = #rows > 0 and b.found or nil, rows = rows, where = where, where_label = b.where, first = first,
             first_label = b.first, briefing = true }
end

-- Catching someone up who joins tonight, over two cards: the story so far (the world, then what
-- the party found last time), then the party, where they are and what's first.
function M.catch_up(campaign, joined, where, first, recap)
    local b = M.data.briefing
    local all = M.briefing(campaign, where, first)
    local story, party = {}, {}
    local new, joined_names = {}, {}
    for _, p in ipairs(joined) do
        new[p.key] = true
        table.insert(joined_names, string.upper(p.name))
    end
    for _, r in ipairs(all.rows) do
        if r.face and new[r.face] then
            r.text = r.text .. " " .. b.joining
        end
        table.insert(r.face and party or story, r)
    end
    local found = M.found_rows(campaign, 2, recap)
    if #found > 0 then
        found[1].text = b.found_short .. " " .. found[1].text
    end
    for _, r in ipairs(found) do
        table.insert(story, r)
    end
    local who = table.concat(joined_names, " and ")
    return {
        { kicker = string.format(b.catch_up, who), rows = story, briefing = true },
        { kicker = b.party, rows = party, where = where, where_label = b.where, first = first, first_label = b.first,
          briefing = true },
    }
end

return M
