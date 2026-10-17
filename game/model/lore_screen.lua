-- The lore screen (October 16, Conner: "this should help telegraph what upcoming lore decisions
-- will mean for the DM"): between the prep board and game night, one page for the DM alone that
-- says what tonight can change in the story. Scene by scene: the clues on the board, what a won
-- or lost scene opens for next session, what holds a front back or settles a move off screen.
-- Then every storyline, what happens to it tonight and what leaving it costs; the clue next
-- session hangs on; the fronts behind the screen; and the calls with lasting effects that could
-- come up. Everything here is already decided by the model (cards' on tables, arc.lua's open_if
-- and objective_if, the storylines' heat, the planner's fronts, world moves on screen): this
-- only says it before the night instead of after. Pure Lua.

local content = require "game.model.content"
local util = require "game.model.util"
local story = require "game.model.story"
local deck = require "game.model.deck"
local storylines = require "game.model.storylines"

local M = {}

local SLOT_ORDER = { "location", "cast", "goal", "complication", "reward" }

M.MAX_ITEMS = 7          -- per scene, most telling first

local function lazy(name)
    return util.lazy(name)
end

local function name_of(id)
    local c = content.components[id]
    return c and c.name or id
end

-- A card's name in the middle of a sentence: a place or a person as a name ("the ghost of
-- Oswin's abbot"), anything else in quotes ("Find Ilsa's last journal").
local function mid_name(id)
    local c = content.components[id]
    if c and c.kind ~= "location" and c.kind ~= "cast" then
        return "\"" .. c.name .. "\""
    end
    if c and c.kind == "cast" and c.short then
        return c.short
    end
    return util.lower_first(name_of(id))
end
M.card_words = mid_name

local function pronouns(c)
    local p = c and c.pronoun
    if p == "she" then
        return "her", "her"
    elseif p == "he" then
        return "him", "him"
    end
    return "them", "them"
end

local function short_of(c)
    return c and (c.short or c.name) or "?"
end

-- "a, b and c", each a card's name, for the cards a list would open that aren't in the deck yet.
local function opens(campaign, ids)
    local out = {}
    for _, id in ipairs(ids or {}) do
        local st = deck.state(campaign, id)
        if (st == nil or st == "locked") and content.components[id] then
            table.insert(out, mid_name(id))
        end
    end
    return out
end
M.opens = opens

-- The cards of a prepped scene, in slot order (an open scene's spots after its slots).
function M.scene_cards(prep, i)
    local s = prep and prep.scenes and prep.scenes[i]
    local out, seen = {}, {}
    if not s then
        return out
    end
    for _, kind in ipairs(SLOT_ORDER) do
        local c = s.slots and s.slots[kind]
        if c and not seen[c.id] then
            seen[c.id] = true
            table.insert(out, c)
        end
    end
    for _, id in ipairs(s.spots or {}) do
        local c = content.components[id]
        if c and not seen[c.id] then
            seen[c.id] = true
            table.insert(out, c)
        end
    end
    return out
end

-- Where each card sits tonight: card id -> scene index (the first one).
local function board_index(prep)
    local at = {}
    for i = 1, #(prep and prep.scenes or {}) do
        for _, c in ipairs(M.scene_cards(prep, i)) do
            at[c.id] = at[c.id] or i
        end
    end
    return at
end

-- The clue a card would give the party if it played tonight, or nil.
local function clue_of(campaign, c)
    local _, clue = story.pending_reveal(campaign, c)
    if clue and not story.has_clue(campaign, c.id) then
        return clue
    end
    return nil
end

-- The big questions a clue counts toward: { { q, found, need } }.
local function questions_of(campaign, id)
    local out = {}
    local questions = lazy("game.model.questions")
    for _, q in ipairs(questions.list()) do
        if util.contains(q.clues or {}, id) then
            local st = questions.status(campaign, q)
            if not st.answered then
                table.insert(out, { q = q.q, found = st.found, need = q.answered_at or 3 })
            end
        end
    end
    return out
end

-- The second front, as the planner keeps it: { id, def, st } or nil.
local function second_front(campaign)
    local planner = lazy("game.model.planner")
    local plan = planner.get(campaign)
    local id = plan and plan.front
    local f = id and planner.data.fronts[id]
    if not f or f.fixed then
        return nil
    end
    local sid = content.lore.front_story and content.lore.front_story[id]
    if sid and not storylines.in_scope(campaign, sid) then
        return nil
    end
    return { id = id, def = f, st = plan.fronts and plan.fronts[id] or {} }
end

-- A front's name as the opening calls it ("The Velvet Hand"), else the planner's.
function M.front_name(id, def)
    local lo = content.lore
    local slide = lo.opening[id] or (lo.opening.fronts or {})[id] or {}
    return (id == "kessrick") and "Kessrick" or (slide.title or (def and def.name) or id)
end

-- A world move put on screen this week whose card this is: { faction, def }.
local function screen_move(campaign, c)
    local world = lazy("game.model.world")
    local ok, w = pcall(world.get, campaign)
    if not ok or not w or w.week ~= campaign.week then
        return nil
    end
    for _, m in ipairs(w.moves or {}) do
        if m.state == "screen" and m.card == c.id and not m.settled then
            return { faction = m.faction, def = world.move_def(m.faction, m.move), fname = (require "game.data.factions")[m.faction].name }
        end
    end
    return nil
end

-- What one card on tonight's board can change. Each item: { kind, text, tone, card = id, more }.
-- kind: clue, next, opens_win, opens_lose, opens, resolve, front, move, villain, thread, seed.
function M.card_items(campaign, prep, i, c, hinge)
    local out = {}
    local function add(kind, text, tone, more)
        table.insert(out, { kind = kind, text = text, tone = tone, card = c.id, more = more })
    end
    -- A clue: what they can find out, and what it counts toward.
    local clue = clue_of(campaign, c)
    if clue then
        local when = c.kind == "goal" and "as the scene ends, won or lost" or "the first time it plays"
        local qs = questions_of(campaign, c.id)
        local more = "They find this out " .. when .. "."
        for _, q in ipairs(qs) do
            more = more .. " A clue to the big question \"" .. q.q .. "\": " .. util.int(q.found) .. " found so far, and "
                .. util.int(q.need) .. " answer it."
        end
        add("clue", util.capitalize(short_of(c)) .. ": " .. clue .. (c.kind == "goal" and " (Found as the scene ends, won or lost.)" or ""),
            "story", more)
        out[#out].clue = c.id
        if hinge and hinge[c.id] then
            add("next", "Next session hangs on this clue: " .. hinge[c.id], "next")
        end
    end
    -- What a won or lost scene opens for next session (the card's own on table).
    local on = c.on
    if on then
        local win, lose, played = opens(campaign, on.win), opens(campaign, on.lose), opens(campaign, on.played)
        if #played > 0 then
            add("opens", "Playing " .. mid_name(c.id) .. " puts " .. util.join_names(played) .. " in your hand next session.", "good")
        end
        if #win > 0 then
            add("opens_win", "Win: " .. util.join_names(win) .. (#win == 1 and " joins" or " join") .. " your hand of cards next session.", "good")
            out[#out].names = win
        end
        if #lose > 0 then
            add("opens_lose", "Lose: " .. util.join_names(lose) .. (#lose == 1 and " joins" or " join") .. " your hand of cards next session.", "bad")
            out[#out].names = lose
        end
    end
    -- A minor storyline this card can tie off.
    for _, id in ipairs(storylines.of_card(campaign, c)) do
        local d = storylines.def(campaign, id)
        local st = storylines.state(campaign, id)
        if d and d.ends and util.contains(d.ends, c.id) and not (st and (st.state == "resolved" or st.state == "ended")) then
            add("resolve", "Win and " .. util.lower_first(d.short or d.name) .. " is tied off for good.", "good")
        end
    end
    -- A front's card: winning holds it back a week.
    local sf = second_front(campaign)
    if sf and sf.def.cards and util.contains(sf.def.cards, c.id) and not sf.st.doom then
        add("front", "Win and " .. util.lower_first(M.front_name(sf.id, sf.def)) .. " is held back: its plan doesn't "
            .. "move next session.", "front")
    end
    -- A move off screen the DM chose to play out here.
    local mv = screen_move(campaign, c)
    if mv and mv.def and mv.def.results then
        local r = mv.def.results
        add("move", mv.fname .. ": " .. mv.def.name .. ". Win and it fails; lose and it lands.", "front",
            "Win: " .. ((r.bad and r.bad.text) or "it fails.") .. " Lose: " .. ((r.full and r.full.text) or "it lands."))
    end
    -- A villain: beaten, they're done; got away, they're back.
    if c.villain then
        local ledger = lazy("game.model.ledger")
        local pid = ledger.person_of(c)
        local back = pid and ledger.status(campaign, pid) == "got away"
        local g = pid and ledger.grudge_level(campaign, pid) or 0
        local obj = pronouns(c)
        add("villain", (back and (util.capitalize(short_of(c)) .. " is back, and holds a grudge (" .. util.int(math.floor(g + 0.5))
            .. " of " .. util.int(ledger.GRUDGE_MAX) .. "). ") or "")
            .. "Beat " .. obj .. " and it's over. Let " .. obj .. " get away and " .. util.lower_first(short_of(c))
            .. " comes back with a grudge.", "bad")
    end
    -- A hero's own story.
    if c.thread and c.step and deck.thread_live(campaign, c) then
        local p = campaign:player(c.thread)
        if p and p.present ~= false then
            add("thread", p.char .. "'s story, step " .. util.int(c.step) .. ".", "thread")
            out[#out].thread = c.thread
        end
    end
    -- A seed the DM planted, paying off.
    if prep and prep.payoffs and prep.payoffs[c.id] then
        add("seed", "Pays off the seed you planted.", "good")
    end
    -- Someone's own want, brought in (ledger.agenda_card).
    if c.agenda then
        local ledger = lazy("game.model.ledger")
        local who = ledger.about(c.agenda).name or "Someone"
        if c.agenda_kind == "warm" then
            add("want", who .. " asked for this. A favour is asked once: play it and it's done.", "good")
        elseif c.agenda_kind == "back" then
            add("want", who .. " is back for the party, and it's personal.", "bad")
        else
            add("want", who .. " is against the party right now, and this is their doing.", "bad")
        end
    end
    return out
end

-- The clue next session hangs on: { week, title, clue = id, name, at = scene index|nil, found,
-- with = what changes, without, goal_slot = the story goal that can find it }.
function M.next_session(campaign, prep)
    local week = campaign.week or 1
    local nb = content.arc.beats[week + 1]
    if not nb then
        return nil
    end
    local hinge = (nb.objective_if and nb.objective_if.clue) or (nb.open_if and nb.open_if.clue)
    local out = { week = week + 1, title = nb.title and util.title_case(nb.title) or ("Session " .. util.int(week + 1)) }
    if not hinge then
        out.plain = nb.objective and util.capitalize(nb.objective) .. "." or nil
        return out
    end
    out.clue = hinge
    out.name = name_of(hinge)
    out.found = story.has_clue(campaign, hinge)
    out.with = nb.objective_if and nb.objective_if.text and (util.capitalize(nb.objective_if.text) .. ".") or nil
    out.without = nb.objective and (util.capitalize(nb.objective) .. ".") or nil
    out.at = board_index(prep)[hinge]
    -- Where it has to happen, and whether you hold it (the lore playtest: "Find the hidden map" was
    -- refused on the forest road, and nothing had said it needs the chapel).
    local hc = content.components[hinge]
    local places = {}
    for _, w in ipairs(hc and hc.with or {}) do
        local lc = content.components[w]
        if lc and lc.kind == "location" then
            table.insert(places, util.lower_first(lc.name))
        end
    end
    if hc and hc.kind ~= "location" and #places > 0 then
        out.where = places
    end
    local held = false
    for _, c in ipairs(prep and prep.hand and hc and prep.hand[hc.kind] or {}) do
        held = held or c.id == hinge
    end
    out.in_hand = held
    -- The week's story goal can find it too, on an empty goal slot (night.story_goal_card).
    local beat = campaign:arc_beat()
    local sg = beat and beat.story_goal and content.components[beat.story_goal]
    if sg and sg.pays == hinge then
        out.goal_slot = sg.name
    end
    return out
end

-- How a storyline stands tonight, and what tonight does to it: { id, name, heat, scenes = {i},
-- line, tone, urgent }.
local function storyline_row(campaign, d, scenes, fix)
    local heat, since = storylines.heat(campaign, d.id)
    local st = storylines.state(campaign, d.id)
    local row = { id = d.id, name = d.short or d.name, heat = heat, scenes = scenes, kind = d.kind }
    if d.kind == "backstory" then
        local p = campaign:player(d.key)
        row.who = p and (p.name .. "'s hero") or nil
    end
    local n = #scenes
    local where = n > 0 and ("Scene" .. (n > 1 and "s " or " ") .. table.concat((function()
        local t = {}
        for k, i in ipairs(scenes) do
            t[k] = util.int(i)
        end
        return t
    end)(), n == 2 and " and " or ", ")) or nil
    local cold = d.cold or 2
    -- after: how it stands once tonight is played (the lore playtest, October 16: "Cooling" beside
    -- "Scene 1 moves it tonight" read as tonight's forecast).
    if n > 0 then
        if heat == "unopened" then
            row.line, row.tone, row.after = where .. " opens it tonight.", "good", "starts"
        elseif heat == "loose" then
            row.line, row.tone, row.after = where .. " brings it back: what it's cost the table comes back, and they cheer.",
                "good", "back"
        elseif n >= 2 then
            row.line, row.tone, row.after = where .. ": two scenes on one story builds momentum. The players who love a "
                .. "story lean in.", "good", "moves"
        else
            row.line, row.tone, row.after = where .. " moves it tonight.", "good", "moves"
        end
        return row
    end
    row.urgent = (heat == "cold" or heat == "loose") and 2 or (heat == "cooling" and 1 or 0)
    local who = d.kind == "backstory" and (function()
        local p = campaign:player(d.key)
        return p and p.name or "its player"
    end)() or (d.kind == "major" and "everyone, the story lovers most" or "the players who love a story")
    if heat == "unopened" then
        row.line, row.tone, row.after = "Not started yet. Nothing goes wrong while it waits.", "dim", "waiting"
    elseif heat == "loose" then
        row.line, row.tone, row.after = "A loose end: every session it costs " .. who .. " some Investment and Trust, until "
            .. "a card brings it back.", "bad", "loose"
    elseif heat == "cold" then
        row.line, row.tone, row.after = "Cold and off tonight's board. Leave it and the table notices: " .. who
            .. (who == "everyone, the story lovers most" and " start" or " starts") .. " losing Investment.",
            "bad", "noticed"
    elseif heat == "cooling" then
        row.line, row.tone, row.after = "Off tonight's board. Leave it and it's cold next session, then the table "
            .. "notices.", "warn", "cold"
    elseif heat == "warm" then
        -- Sessions until it reads "cooling" if nothing moves it (storylines.heat: since == cold - 1).
        local left = math.max(1, cold - 1 - (since or 0))
        row.line, row.tone, row.after = "Not tonight. Left alone, it starts to cool " .. (left == 1 and "next session." or
            ("in " .. util.int(left) .. " sessions.")), "dim", "fine"
    end
    if st and st.kept and st.kept >= (campaign.week or 1) then
        row.line = row.line .. " (A handout is keeping it warm.)"
    end
    -- What would move it, from your hand (the lore playtest: "nothing tells me which card").
    if heat ~= "warm" and fix and #fix > 0 then
        row.fix = "In your hand: " .. util.join_names(fix) .. "."
    elseif d.kind == "backstory" and heat ~= "warm" and fix and fix.spot then
        row.fix = "Spotlight " .. fix.spot .. " on the prep board to bring in " .. fix.spot_card .. "."
    elseif heat == "cooling" or heat == "cold" or heat == "loose" then
        row.fix = "None of its cards is in your hand this session."
    end
    return row
end

-- Does this card move its storylines when it plays (storylines.on_scene: going back to a place
-- the party knows, with nothing left to tell, doesn't)?
local function moves_story(campaign, c)
    return c.kind ~= "location" or story.pending_reveal(campaign, c) ~= nil
        or ((deck.entry(campaign, c.id) or {}).plays or 0) == 0
end

-- How many separate threads tonight's board makes (storylines one card ties together count once,
-- as storylines.threads_tonight counts them at the table).
local function thread_count(campaign, prep, on_board)
    local parent = {}
    local function find(x)
        while parent[x] ~= x do
            x = parent[x]
        end
        return x
    end
    for id in pairs(on_board) do
        parent[id] = id
    end
    for i = 1, #(prep and prep.scenes or {}) do
        for _, c in ipairs(M.scene_cards(prep, i)) do
            local ids = storylines.of_card(campaign, c)
            for k = 2, #ids do
                if parent[ids[1]] and parent[ids[k]] then
                    local a, b = find(ids[1]), find(ids[k])
                    if a ~= b then
                        parent[a] = b
                    end
                end
            end
        end
    end
    local n, roots = 0, {}
    for id in pairs(parent) do
        local r = find(id)
        if not roots[r] then
            roots[r] = true
            n = n + 1
        end
    end
    return n
end

function M.storyline_rows(campaign, prep)
    local on_board = {}
    for i = 1, #(prep and prep.scenes or {}) do
        local seen = {}
        for _, c in ipairs(M.scene_cards(prep, i)) do
            for _, id in ipairs(moves_story(campaign, c) and storylines.of_card(campaign, c) or {}) do
                if not seen[id] then
                    seen[id] = true
                    on_board[id] = on_board[id] or {}
                    table.insert(on_board[id], i)
                end
            end
            -- A story card that's no storyline's own moves the main story (storylines.of_card_all).
            if #storylines.of_card(campaign, c) == 0 and prep.arc_cards and prep.arc_cards[c.id] then
                local main = content.lore.briefing.next_story
                if not seen[main] then
                    seen[main] = true
                    on_board[main] = on_board[main] or {}
                    table.insert(on_board[main], i)
                end
            end
        end
    end
    -- The cards in your hand that would move each storyline, not on tonight's board yet.
    local in_hand = {}
    local placed = board_index(prep)
    for _, kind in ipairs(content.kinds) do
        for _, c in ipairs(prep and prep.hand and prep.hand[kind] or {}) do
            if not placed[c.id] and moves_story(campaign, c) then
                for _, id in ipairs(storylines.of_card(campaign, c)) do
                    in_hand[id] = in_hand[id] or {}
                    if #in_hand[id] < 2 then
                        table.insert(in_hand[id], mid_name(c.id))
                    end
                end
            end
        end
    end
    local rows = {}
    for _, d in ipairs(storylines.defs(campaign)) do
        local st = storylines.state(campaign, d.id)
        local done = st and (st.state == "resolved" or st.state == "ended" or st.state == "waiting")
        if not done and storylines.in_scope(campaign, d.id) then
            local fix = in_hand[d.id] or {}
            if d.kind == "backstory" and #fix == 0 and prep and prep.spotlight_card then
                local okc, sc = pcall(prep.spotlight_card, prep, d.key)
                local p = campaign:player(d.key)
                if okc and sc and p then
                    fix.spot, fix.spot_card = p.name, mid_name(sc.id)
                end
            end
            table.insert(rows, storyline_row(campaign, d, on_board[d.id] or {}, fix))
        end
    end
    -- Tonight's first (in scene order), then what's slipping, then the rest.
    for k, r in ipairs(rows) do
        r.order = k
    end
    table.sort(rows, function(a, b)
        local an, bn = #a.scenes > 0, #b.scenes > 0
        if an ~= bn then
            return an
        end
        if an then
            if a.scenes[1] ~= b.scenes[1] then
                return a.scenes[1] < b.scenes[1]
            end
            return a.order < b.order
        end
        if (a.urgent or 0) ~= (b.urgent or 0) then
            return (a.urgent or 0) > (b.urgent or 0)
        end
        return a.order < b.order
    end)
    return rows, thread_count(campaign, prep, on_board)
end

-- The fronts behind the screen: { { icon, color, name, text, hold, doom } }.
function M.fronts(campaign, prep)
    local out = {}
    local planner = lazy("game.model.planner")
    local ok, sum = pcall(planner.summary, campaign)
    if not ok or not sum then
        return out
    end
    local lo = content.lore
    local at = board_index(prep)
    local week = campaign.week or 1
    for _, f in ipairs(sum.fronts or {}) do
        local sid = lo.front_story and lo.front_story[f.id]
        if not sid or storylines.in_scope(campaign, sid) then
            local slide = lo.opening[f.id] or (lo.opening.fronts or {})[f.id] or {}
            local row = { icon = lo.icons.fronts[f.id] or "crown", color = slide.color or "#a08ab0",
                          name = (f.id == "kessrick") and "Kessrick" or (slide.title or f.name) }
            local done, total, nxt = 0, #(f.track or {}), nil
            for _, t in ipairs(f.track or {}) do
                if t.done then
                    done = done + 1
                elseif not nxt then
                    nxt = t.text
                end
            end
            row.name = M.front_name(f.id, f)
            row.done, row.steps = done, total
            if f.fixed and week > #(f.track or {}) then
                row = nil      -- (past the arc: his story's been told)
            elseif f.fixed then
                row.text = nxt and ("Next session: " .. nxt .. " Nothing at the table holds this back: it moves with the story.")
                    or ("His plan is at its last step. If nothing stops it: " .. (f.doom or ""))
                row.more = "Kessrick's plan is the story itself: each session takes it a step further, whatever the party does."
            elseif f.doomed then
                row.text = "Its plan is complete: " .. (f.doom or "")
                row.doom = true
            else
                local left = total - done
                if nxt then
                    local rest = left - 1
                    row.text = "Next session, unless it's held: " .. nxt .. " "
                        .. (rest <= 0 and "After that, its plan is complete: " or ("Then " .. util.int(rest) .. " more step"
                            .. (rest == 1 and "" or "s") .. " until its plan is complete: ")) .. (f.doom or "")
                else
                    row.text = "Next session, unless it's held, its plan is complete: " .. (f.doom or "")
                end
                row.more = "Its plan moves every session, whether or not the party has met them. If it's ever complete, the "
                    .. "campaign goes on, but worse: everyone at the table loses some Investment (how much they care about "
                    .. "the story)."
                local fdef = planner.data.fronts[f.id]
                local holds = {}
                for _, cid in ipairs(fdef and fdef.cards or {}) do
                    if at[cid] then
                        table.insert(holds, "scene " .. util.int(at[cid]) .. " (" .. short_of(content.components[cid]) .. ")")
                    end
                end
                if #holds > 0 then
                    row.hold = "Win " .. util.join_names(holds) .. " and it's held back a session."
                else
                    local names = {}
                    for _, cid in ipairs(fdef and fdef.cards or {}) do
                        local st = deck.state(campaign, cid)
                        if #names < 2 and st == "deck" then
                            table.insert(names, mid_name(cid))
                        end
                    end
                    row.hold = "Nothing on tonight's board holds it back. Win a scene with one of its cards to do that"
                        .. (#names > 0 and (": " .. util.join_names(names) .. ".") or ".")
                end
            end
            if row then
                table.insert(out, row)
            end
        end
    end
    -- World moves still to decide (the prep board's "world moves to decide"): factions acting off screen.
    local world = lazy("game.model.world")
    local okw, n = pcall(world.pending, campaign)
    if okw and n and n > 0 then
        table.insert(out, { icon = "clock", color = "#e8b04a", name = "World moves",
                            text = util.int(n) .. " world move" .. (n == 1 and "" or "s") .. " still undecided: the factions "
                                .. "acting off screen. Undecided, " .. (n == 1 and "it rolls" or "they roll") .. " for "
                                .. (n == 1 and "itself" or "themselves") .. " after tonight. Back to prep to decide.",
                            more = "Each faction makes a move every session. On the prep board you can let it happen (it "
                                .. "rolls), put it on screen as a card tonight, or hold one back." })
    end
    -- Villains still at large, and how angry they are.
    local ledger = lazy("game.model.ledger")
    local ok2, ws = pcall(ledger.world_state, campaign)
    if ok2 and ws and ws.people then
        local ids = {}
        for pid, wp in pairs(ws.people) do
            if wp.status == "got away" then
                table.insert(ids, pid)
            end
        end
        table.sort(ids)
        for _, pid in ipairs(ids) do
            local ab = ledger.about(pid)
            local g = ledger.grudge_level(campaign, pid)
            table.insert(out, { icon = "warn", color = "#d0604f", name = ab.name,
                                text = ab.name .. " got away, and holds a grudge (" .. util.int(math.floor(g + 0.5)) .. " of "
                                    .. util.int(ledger.GRUDGE_MAX) .. "). They'll be back, angrier each time." })
        end
    end
    return out
end

-- Calls with lasting effects that could come up tonight: { { text, tone } }.
function M.calls(campaign, prep)
    local out = {}
    local villains, cliff = {}, nil
    for i = 1, #(prep and prep.scenes or {}) do
        for _, c in ipairs(M.scene_cards(prep, i)) do
            if c.villain then
                table.insert(villains, short_of(c))
            end
            if c.cliffhanger then
                cliff = i
            end
        end
    end
    if #villains > 0 then
        table.insert(out, { text = "If " .. util.join_names(villains) .. (#villains > 1 and " are" or " is")
            .. " beaten and cornered, you choose: let them get away (they come back with a grudge) or finish it.",
            tone = "bad", pri = 1 })
    end
    local death = lazy("game.model.death")
    local ok, mode = pcall(death.mode_for, campaign, nil)
    local dd = ok and mode and require("game.data.death").MODE[mode]
    if dd then
        table.insert(out, { text = "If a hero falls: your table agreed \"" .. dd.name .. "\". " .. dd.about, tone = "dim", pri = 5,
                            more = "Agreed at Session Zero, before the first session. A player can ask for their own rule on "
                                .. "their character sheet." })
    end
    if cliff then
        table.insert(out, { text = "Scene " .. util.int(cliff) .. " ends the night on a cliffhanger: next session opens on it.",
                            tone = "story", pri = 2 })
    end
    -- What every night asks of you, and what you agreed to (Session Zero).
    local DICE_SHORT = { open = "You agreed: everything in the open.", big_open = "You agreed: big moments in the open.",
                         screen = "You agreed: behind the screen is fine." }
    local dice = campaign.table and campaign.table.rules and campaign.table.rules.dice
    local dp = dice and DICE_SHORT[dice]
    table.insert(out, { text = "Big rolls: you choose to say the DC (the number to beat) out loud, or keep it behind your "
        .. "screen." .. (dp and (" " .. dp) or ""), tone = "dim", pri = 6,
        more = "Out loud, the table trusts the result. Behind the screen you could quietly change it, but getting caught "
            .. "costs Trust." })
    local rul = campaign.table and campaign.table.rules and campaign.table.rules.rulings
    local rul_def = rul and content.session_zero.rules.rulings[rul]
    if rul_def then
        table.insert(out, { text = "Rules arguments: your table agreed \"" .. rul_def.name .. "\". "
            .. (rul == "quick" and "A quick call means looking it up before next session."
                or "The answers that keep it say \"(as agreed)\"."), tone = "dim", pri = 7 })
    end
    -- Seeds you planted: a payoff left off the board, and the last chance before one goes stale.
    local seeds_def = content.seeds
    local week = campaign.week or 1
    local on = board_index(prep)
    for _, sd in ipairs(campaign.seeds and campaign.seeds.planted or {}) do
        local def = seeds_def[sd.id]
        local pay = def and def.payoff and content.components[def.payoff]
        if sd.state == "growing" and pay and not on[pay.id] and prep and prep.payoffs and prep.payoffs[pay.id] then
            local last = (week + 1 - (sd.week or week)) >= (seeds_def.PAYOFF_WEEKS or 3)
            table.insert(out, { tone = last and "warn" or "dim", pri = last and 3 or 6,
                text = "The seed you planted, \"" .. (def.name or sd.id) .. "\", pays off with " .. mid_name(pay.id)
                    .. ", in your hand and not on tonight's board."
                    .. (last and " Tonight's its last chance: next session it goes stale, and the story fans lose some Investment."
                        or "") })
        end
    end
    -- The goal slot left empty: the improv hand offers the week's story.
    local beat = campaign:arc_beat()
    local sg = beat and beat.story_goal and content.components[beat.story_goal]
    if sg and not (sg.pays and story.has_clue(campaign, sg.pays)) and not deck.is_spent(campaign, sg.id) then
        local empty = {}
        for i, s in ipairs(prep and prep.scenes or {}) do
            -- (A fight doesn't ask what they're there for: night.play_scene.)
            if not (s.slots and s.slots.goal) and not s.module and s.type ~= "combat" and s.type ~= "set_piece" then
                table.insert(empty, util.int(i))
            end
        end
        if #empty > 0 then
            table.insert(out, { text = "Goal left empty in scene " .. util.join_names(empty) .. ": the improv hand will offer "
                .. "this week's story, \"" .. sg.name .. "\".", tone = "story", pri = 3 })
        end
    end
    -- The ones with lasting effects first.
    for k, o in ipairs(out) do
        o.k = k
    end
    table.sort(out, function(a, b)
        if (a.pri or 9) ~= (b.pri or 9) then
            return (a.pri or 9) < (b.pri or 9)
        end
        return a.k < b.k
    end)
    return out
end

-- Everything the screen shows.
function M.build(campaign, prep)
    prep = prep or campaign.prep
    local view = { week = campaign.week or 1, scenes = {} }
    view.objective = lazy("game.model.lore").objective(campaign)
    view.title = lazy("game.model.lore").session_name(campaign, view.week)
    if view.title == "Session " .. util.int(view.week) then
        view.title = nil
    end
    view.story_over = content.arc.beats[view.week] == nil
    view.next = M.next_session(campaign, prep)
    local hinge = {}
    if view.next and view.next.clue and not view.next.found and view.next.with then
        hinge[view.next.clue] = view.next.with
    end
    for i = 1, #(prep and prep.scenes or {}) do
        local s = prep.scenes[i]
        local cards = M.scene_cards(prep, i)
        local sv = { i = i, type = s.type, cards = cards, items = {}, stories = {} }
        local seen_story = {}
        for _, c in ipairs(cards) do
            for _, id in ipairs(moves_story(campaign, c) and storylines.of_card(campaign, c) or {}) do
                if not seen_story[id] then
                    seen_story[id] = true
                    table.insert(sv.stories, id)
                end
            end
        end
        local ty = s.type and content.scenes[s.type]
        sv.type_name = ty and ty.name or "Scene"
        local loc = s.slots and s.slots.location
        sv.place = loc and loc.name or (s.open and "Several places" or "A place you'll make up")
        local goal = s.slots and s.slots.goal
        sv.goal = goal and goal.name or nil
        if s.type == "combat" and prep.encounter then
            local ok, enc = pcall(prep.encounter, prep, i)
            sv.fight = ok and enc and enc.boss_name or nil
        end
        -- A scene's wins and losses open one list each (a scene is won or lost as a whole).
        local win, lose = {}, {}
        for _, c in ipairs(cards) do
            for _, it in ipairs(M.card_items(campaign, prep, i, c, hinge)) do
                if it.kind == "opens_win" then
                    for _, n in ipairs(it.names) do
                        table.insert(win, n)
                    end
                elseif it.kind == "opens_lose" then
                    for _, n in ipairs(it.names) do
                        table.insert(lose, n)
                    end
                else
                    table.insert(sv.items, it)
                end
            end
        end
        -- (The lore playtest: "Lose: it gets the old bell paths and ..." read as nothing gained by
        -- winning; what a loss keeps, and what it adds, are said apart.)
        local in_win = {}
        for _, n in ipairs(win) do
            in_win[n] = true
        end
        local both, lose_only = {}, {}
        for _, n in ipairs(lose) do
            if in_win[n] then
                table.insert(both, n)
            else
                table.insert(lose_only, n)
            end
        end
        local function joins(list)
            return util.join_names(list) .. (#list == 1 and " joins" or " join") .. " your hand of cards next session"
        end
        if #win > 0 and #both == #win and #lose_only == 0 then
            table.insert(sv.items, { kind = "opens", tone = "good", text = "Win or lose: " .. joins(win) .. "." })
        else
            if #win > 0 then
                table.insert(sv.items, { kind = "opens_win", tone = "good", text = "Win: " .. joins(win) .. "." })
            end
            if #lose > 0 then
                local text
                if #both > 0 and #lose_only > 0 then
                    text = "Lose: they still get " .. util.join_names(both) .. ", plus " .. util.join_names(lose_only) .. "."
                elseif #both > 0 then
                    text = "Lose: they still get " .. util.join_names(both) .. "."
                else
                    text = "Lose: " .. joins(lose) .. " instead."
                end
                table.insert(sv.items, { kind = "opens_lose", tone = "bad", text = text })
            end
        end
        -- The most telling first: what next session hangs on, clues, then the rest.
        local RANK = { next = 1, clue = 2, front = 3, move = 3, resolve = 4, opens_win = 5, opens_lose = 6, opens = 6, want = 7,
                       villain = 7, thread = 8, seed = 9 }
        for k, it in ipairs(sv.items) do
            it.k = k
        end
        table.sort(sv.items, function(a, b)
            local ra, rb = RANK[a.kind] or 9, RANK[b.kind] or 9
            if ra ~= rb then
                return ra < rb
            end
            return a.k < b.k
        end)
        sv.more = math.max(0, #sv.items - M.MAX_ITEMS)
        while #sv.items > M.MAX_ITEMS do
            table.remove(sv.items)
        end
        table.insert(view.scenes, sv)
    end
    view.storylines, view.on_board = M.storylines_view(campaign, prep)
    view.thin = view.on_board > (storylines.data and storylines.data.ACTIVE_CAP or 4)
    view.fronts = M.fronts(campaign, prep)
    view.calls = M.calls(campaign, prep)
    return view
end

function M.storylines_view(campaign, prep)
    return M.storyline_rows(campaign, prep)
end

return M
