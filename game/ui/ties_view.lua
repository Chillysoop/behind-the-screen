-- The tie-and-lock editor (v2, October 30): the adventure as structure the DM can see and bend,
-- over the prep board ("Ties and locks", beside "All maps"). The floor plan on the left is the
-- adventure as a graph: its rooms, the doors between them (the little squares), a lock on what's
-- shut. Click a room for its cards (the room, its person, its moments, the heroes' reasons that pay
-- off there), each with what it needs (ins) and what it leads to (outs) and buttons to lock it,
-- play it only if, cut it, or tie something to it; click a door to lock it. Picking when, or what
-- happens, is a short list of chips. Underneath, every tie and lock with a button to take it off.
-- The model is game/model/ties.lua; nothing here is about the museum (it reads adventure.data).

local kit = require "game.ui.kit"
local theme = require "game.ui.theme"
local util = require "game.model.util"
local adventure = require "game.model.adventure"
local ties = require "game.model.ties"
local museum_week = require "game.model.museum_week"
local museum_prep_view = require "game.ui.museum_prep_view"

local MODULE = adventure.data
local M = {}

local X, Y, W, H = 40, 26, 1520, 848
local MAP_X, MAP_Y, MAP_W, MAP_H = X + 24, Y + 84, 900, 330
local LIST_Y = MAP_Y + MAP_H + 50
local PX, PY = MAP_X + MAP_W + 28, Y + 84
local PW, PH = X + W - 24 - PX, Y + H - 20 - PY
local L14 = 19

local DOOR = kit.rgba("#8a5a30")
local SHUT = kit.rgba("#7a3a22")

function M.open(app, sel)
    app.overlay = "ties"
    app.tl_pick = nil
    app.tl_msg = nil
    app.tl_page = 1
    if sel then
        app.tl_sel = sel
    elseif not app.tl_sel then
        local st = adventure.fill(app.campaign.adv)
        local first = adventure.frontier(app.campaign)[1] or st.pos or MODULE.start
        app.tl_sel = { room = first }
    end
    M.draw(app)
end

function M.close(app)
    if app.tl_layer then
        kit.drop(app.tl_layer)
        app.tl_layer = nil
    end
    if app.overlay == "ties" then
        app.overlay = nil
    end
    app.tl_pick = nil
    kit.reset_hover()
end

local function redraw(app)
    if app.overlay == "ties" then
        M.draw(app)
    end
end

-- The map changed: tonight's rooms again, and the board autosaves.
local function changed(app)
    local c = app.campaign
    if c.prep and c.prep.museum then
        museum_week.reahead(c.prep, c)
    end
    app.prep_dirty = true
end

local function say(app, text, good)
    app.tl_msg = { text = text, good = good }
end

-- Picking ----------------------------------------------------------------------------------------

local function start_pick(app, pk)
    pk.tab = nil
    app.tl_pick = pk
    app.tl_msg = nil
    redraw(app)
end

local function step_of(pk)
    if pk.mode == "tie" then
        if pk.effect and pk.effect.kind == "hook" and not pk.effect.room then
            return "hook_room"
        elseif not pk.cond then
            return "cond"
        elseif not pk.effect then
            return "effect"
        end
        return "done"
    end
    return pk.cond and "done" or "cond"
end

local function commit(app)
    local c = app.campaign
    local pk = app.tl_pick
    local made, why
    if pk.mode == "tie" and pk.effect.kind ~= "open" then
        made, why = ties.add_tie(c, { cond = pk.cond, effect = pk.effect })
    else
        local l = util.copy(pk.mode == "tie" and pk.effect.lock or pk.target)
        l.cond = pk.cond
        made, why = ties.add_lock(c, l)
    end
    if made then
        app.tl_pick = nil
        say(app, "Done. " .. ties.describe(made, c), true)
        changed(app)
    else
        -- Back one step, to pick again.
        if pk.last == "cond" and not pk.cond_given then
            pk.cond = nil
        elseif pk.last == "effect" and not pk.effect_given then
            pk.effect = nil
        elseif pk.last == "hook_room" then
            pk.effect.room = nil
        end
        say(app, why, false)
    end
end

local function picked(app, field, value)
    local pk = app.tl_pick
    if field == "hook_room" then
        pk.effect.room = value
    else
        pk[field] = value
    end
    pk.last = field
    pk.tab = nil
    app.tl_msg = nil
    if step_of(pk) == "done" then
        commit(app)
    end
    redraw(app)
end

-- A row of tab chips, then the chips of the tab that's on. tabs: { { id, name, chips = { { label,
-- key, value, enabled } } } }. Returns the y under them.
local function chip_lists(app, tabs, x, y, w, on_pick, bottom)
    local pk = app.tl_pick
    if #tabs == 0 then
        return y
    end
    local tab = tabs[1]
    for _, t in ipairs(tabs) do
        if t.id == pk.tab then
            tab = t
        end
    end
    pk.tab = tab.id
    if #tabs > 1 then
        local tx, ty = x, y
        for _, t in ipairs(tabs) do
            local tw = kit.width(t.name, "ui14") + 20
            if tx + tw > x + w then
                tx, ty = x, ty + 32
            end
            kit.button(tx, ty, tw, 26, t.name, function()
                pk.tab = t.id
                redraw(app)
            end, { font = "ui14", color = t.id == tab.id and theme.go or theme.panel2, hover = theme.button_hover,
                   key = "tl_tab_" .. t.id })
            tx = tx + tw + 6
        end
        y = ty + 38
    end
    -- One column for long labels, two when they're short.
    local col_w = (w - 8) / 2
    local cols = 2
    for _, ch in ipairs(tab.chips) do
        if kit.width(ch.label, "ui14") + 20 > col_w then
            cols = 1
        end
    end
    local cw = cols == 2 and col_w or w
    local rows = math.ceil(#tab.chips / cols)
    local rh = math.min(32, math.max(24, math.floor((bottom - y) / math.max(1, rows))))
    for i, ch in ipairs(tab.chips) do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        local cx, cy = x + col * (cw + 8), y + row * rh
        if cy + rh - 4 > bottom then
            kit.text(x, cy, "...and more.", "ui14", theme.faint)
            break
        end
        kit.button(cx, cy, cw, rh - 4, kit.ellipsize(ch.label, "ui14", cw - 20), function()
            on_pick(ch.value)
        end, { font = "ui14", color = theme.panel2, hover = theme.button_hover, enabled = ch.enabled ~= false, key = ch.key })
    end
    return y + rows * rh
end

local function cond_key(cond)
    return "tl_cond_" .. cond.kind .. "_" .. tostring(cond.room or cond.flag or cond.mark or cond.n or "")
end

local function cond_tabs(app)
    local pk = app.tl_pick
    local out = {}
    for _, t in ipairs(ties.cond_tabs(app.campaign, pk.only)) do
        local chips = {}
        for _, ch in ipairs(t.chips) do
            table.insert(chips, { label = ch.label, value = ch.cond, key = cond_key(ch.cond) })
        end
        table.insert(out, { id = t.id, name = t.name, chips = chips })
    end
    return out
end

local function effect_tabs(app)
    local c = app.campaign
    local st = c.adv
    local marks, doors, rooms, people, heroes = {}, {}, {}, {}, {}
    local function short(id)
        local r = MODULE.rooms[id]
        return r.map or r.name
    end
    for _, id in ipairs(MODULE.mark_order or {}) do
        table.insert(marks, { label = ties.mark_name(id), value = { kind = "mark", mark = id }, key = "tl_eff_mark_" .. id,
                              enabled = not st.marks[id] })
    end
    for _, d in ipairs(ties.doors()) do
        table.insert(doors, { label = short(d[1]) .. " to " .. short(d[2]),
                              value = { kind = "open", lock = { kind = "door", a = d[1], b = d[2] } },
                              key = "tl_eff_door_" .. ties.door_key(d[1], d[2]) })
    end
    for _, id in ipairs(ties.map_rooms()) do
        if id ~= MODULE.start then
            table.insert(rooms, { label = MODULE.rooms[id].name, value = { kind = "open", lock = { kind = "room", room = id } },
                                  key = "tl_eff_room_" .. id })
        end
    end
    for _, p in ipairs(MODULE.people or {}) do
        local boss = false
        for _, rid in ipairs(ties.people_rooms(p.id)) do
            boss = boss or MODULE.rooms[rid].boss
        end
        if not boss then
            table.insert(people, { label = p.name, value = { kind = "open", lock = { kind = "person", person = p.id } },
                                   key = "tl_eff_person_" .. p.id })
        end
    end
    for _, p in ipairs(c.players or {}) do
        local h = adventure.hook(c, p.key)
        if h then
            table.insert(heroes, { label = p.char .. ": " .. h.name, value = { kind = "hook", key = p.key }, key = "tl_eff_hero_" .. p.key,
                                   enabled = not st.done[h.room] })
        end
    end
    return {
        { id = "mark", name = ties.boss_name() .. " gains a mark", chips = marks },
        { id = "door", name = "A door opens", chips = doors },
        { id = "room", name = "A room opens", chips = rooms },
        { id = "person", name = "Someone comes out", chips = people },
        { id = "hook", name = "A hero's reason moves", chips = heroes },
    }
end

local function hook_room_tabs(app)
    local c = app.campaign
    local st = c.adv
    local chips = {}
    for _, id in ipairs(ties.map_rooms()) do
        local r = MODULE.rooms[id]
        if not r.virtual then
            table.insert(chips, { label = r.name, value = id, key = "tl_hookroom_" .. id,
                                  enabled = not st.done[id] and not st.skipped[id] })
        end
    end
    return { { id = "rooms", name = "Rooms", chips = chips } }
end

local function picker(app, x, y, w, h)
    local c = app.campaign
    local pk = app.tl_pick
    kit.box(x, y, w, h, theme.panel, { radius = 12 })
    local ix, iw = x + 16, w - 32
    local step = step_of(pk)
    kit.text(ix, y + 14, pk.title, "ui14", theme.gold, { w = iw, lines = 1 })
    local prompt
    if step == "cond" then
        prompt = pk.prompt
    elseif step == "effect" then
        prompt = (pk.cond.kind == "session" and ("From session " .. util.int(pk.cond.n)) or ("After " .. ties.clause(pk.cond)))
            .. ", what happens?"
    elseif step == "hook_room" then
        prompt = ties.hero_name(pk.effect.key, c) .. "'s reason for coming pays off in which room?"
    end
    kit.text(ix, y + 36, prompt or "", "ui18", theme.text, { w = iw, lines = 2 })
    local ty = y + 36 + math.min(2, #kit.wrap(prompt or "", "ui18", iw)) * 23 + 12
    local bottom = y + h - 70
    if step == "cond" then
        chip_lists(app, cond_tabs(app), ix, ty, iw, function(v)
            picked(app, "cond", v)
        end, bottom)
    elseif step == "effect" then
        chip_lists(app, effect_tabs(app), ix, ty, iw, function(v)
            if v.kind == "hook" then
                pk.effect = v
                pk.last = "effect"
                pk.tab = nil
                app.tl_msg = nil
                redraw(app)
            else
                picked(app, "effect", v)
            end
        end, bottom)
    elseif step == "hook_room" then
        chip_lists(app, hook_room_tabs(app), ix, ty, iw, function(v)
            picked(app, "hook_room", v)
        end, bottom)
    end
    if app.tl_msg and not app.tl_msg.good then
        kit.icon(ix, y + h - 60, 16, "warn", theme.orange)
        kit.text(ix + 24, y + h - 62, app.tl_msg.text, "ui14", theme.orange, { w = iw - 150, lines = 3 })
    end
    kit.button(x + w - 136, y + h - 50, 120, 36, "Cancel", function()
        app.tl_pick = nil
        app.tl_msg = nil
        redraw(app)
    end, { font = "ui18b", key = "tl_cancel" })
end

-- Cards -----------------------------------------------------------------------------------------
-- A card: { title, tag, ins = { lines }, outs = { { label, words } | text }, lock = l, note, buttons }.
-- Drawn when `draw`; returns its height either way.

local function card(spec, x, y, w, draw)
    local iw = w - 28
    local h = 10
    if draw then
        kit.box(x, y, w, spec.h or 10, theme.panel, { radius = 10 })
        kit.box(x, y, 5, spec.h or 10, spec.stripe or theme.panel3, { radius = 3 })
        kit.text(x + 14, y + h, spec.title, "ui18b", theme.text, { w = iw - 110, lines = 1 })
        kit.text(x + w - 14, y + h + 3, spec.tag or "", "ui14", theme.faint, { pivot = gui.PIVOT_NE })
    end
    h = h + 26
    local function row(label, text, col, lines)
        if not text or text == "" then
            return
        end
        local n = math.min(lines or 2, #kit.wrap(text, "ui14", iw - 74))
        if draw then
            kit.text(x + 14, y + h, label, "ui14", theme.faint)
            kit.text(x + 88, y + h, text, "ui14", col, { w = iw - 74, lines = lines or 2 })
        end
        h = h + n * L14 + 2
    end
    if spec.ins and #spec.ins > 0 then
        row("NEEDS", util.capitalize(table.concat(spec.ins, "; ")) .. ".", theme.dim, 2)
    end
    if spec.outs then
        if #spec.outs == 0 then
            row("LEADS TO", spec.no_outs or "Nothing the rest of the adventure looks at.", theme.faint, 1)
        end
        for i, o in ipairs(spec.outs) do
            if i > 3 then
                row("", "...and " .. util.int(#spec.outs - 3) .. " more.", theme.faint, 1)
                break
            end
            local label = i == 1 and "LEADS TO" or ""
            if type(o) == "string" then
                row(label, o, theme.gold, 2)
            else
                local lw = math.min(kit.width(o.label, "ui14"), (iw - 74) * 0.36)
                local words = table.concat(o.words, ", ")
                local ww = iw - 74 - lw - 10
                local n = math.min(2, #kit.wrap(words, "ui14", ww))
                if draw then
                    kit.text(x + 14, y + h, label, "ui14", theme.faint)
                    kit.text(x + 88, y + h, kit.ellipsize(o.label, "ui14", lw), "ui14", theme.dim)
                    kit.text(x + 88 + lw + 10, y + h, words, "ui14", theme.gold, { w = ww, lines = 2 })
                end
                h = h + n * L14 + 2
            end
        end
    end
    if spec.lock then
        local l = spec.lock
        local text = ties.rule(l, spec.campaign) .. (l.open and "  (open now)" or "")
        local n = math.min(2, #kit.wrap(text, "ui14", iw - 26))
        if draw then
            kit.icon(x + 14, y + h + 1, 16, "lock", l.open and theme.green or theme.gold)
            kit.text(x + 38, y + h, text, "ui14", l.open and theme.green or theme.gold, { w = iw - 26, lines = 2 })
        end
        h = h + n * L14 + 2
    end
    if spec.note then
        local n = math.min(2, #kit.wrap(spec.note, "ui14", iw))
        if draw then
            kit.text(x + 14, y + h, spec.note, "ui14", theme.faint, { w = iw, lines = 2 })
        end
        h = h + n * L14 + 2
    end
    if spec.buttons and #spec.buttons > 0 then
        h = h + 4
        local bx = x + 14
        for _, b in ipairs(spec.buttons) do
            local bw = kit.width(b.label, "ui14") + 24
            if draw then
                kit.button(bx, y + h, bw, 26, b.label, b.fn, { font = "ui14", color = b.color or theme.button, hover = theme.button_hover,
                                                                 enabled = b.enabled ~= false, key = b.key })
            end
            bx = bx + bw + 8
        end
        h = h + 30
    end
    return h + 8
end

local function lock_buttons(app, target, lock, what, keyname, pick)
    local c = app.campaign
    if lock then
        return {
            { label = "Change...", key = "tl_change_" .. keyname, fn = function()
                start_pick(app, pick)
            end },
            { label = "Take it off", key = "tl_unlock_" .. keyname, color = theme.panel3, fn = function()
                ties.remove(c, lock.id)
                say(app, "Taken off: " .. ties.describe(lock, c), true)
                changed(app)
                redraw(app)
            end },
        }
    end
    return { { label = what, key = "tl_lock_" .. keyname, fn = function()
        start_pick(app, pick)
    end } }
end

local function room_cards(app, id)
    local c = app.campaign
    local st = adventure.fill(c.adv)
    local r = MODULE.rooms[id]
    local cards = {}
    -- The room itself.
    local outs = {}
    if not r.boss then
        table.insert(outs, "When it's done: anything you lock or tie to " .. ties.the(id) .. ".")
    end
    for _, rm in ipairs(ties.room_marks(id)) do
        table.insert(outs, ties.boss_name() .. "'s card: \"" .. ties.mark_name(rm.mark) .. "\" (" .. util.lower_first(rm.how) .. ").")
    end
    local lock = ties.lock_on(c, { kind = "room", room = id })
    local buttons
    local note
    if id == MODULE.start then
        note = "The adventure starts here, so it can't be locked."
        buttons = {}
    else
        buttons = lock_buttons(app, { kind = "room", room = id }, lock, "Lock it...", "room", {
            mode = "lock", target = { kind = "room", room = id }, title = "LOCK " .. string.upper(r.name),
            prompt = "It stays shut until... (pick what opens it)" })
    end
    if not r.boss then
        table.insert(buttons, { label = "Tie...", key = "tl_tie_room", fn = function()
            start_pick(app, { mode = "tie", cond = { kind = "room", room = id }, cond_given = true, title = "TIE TO " .. string.upper(r.name) })
        end })
    end
    local ins = {}
    if id == MODULE.start then
        table.insert(ins, "nothing: it's where they start")
    elseif st.done[id] then
        table.insert(ins, "nothing now: they've been through it")
    elseif st.skipped[id] then
        table.insert(ins, "nothing now: it was left behind for good")
    else
        table.insert(ins, "a way in that isn't shut")
    end
    table.insert(cards, { title = "The room", tag = "ROOM", ins = ins, outs = outs, lock = lock, note = note, buttons = buttons,
                          stripe = theme.scene[r.type] })
    -- Its person.
    local cast = r.comps and r.comps.cast
    if cast and ties.person(cast) then
        local p = ties.person(cast)
        local plock = ties.lock_on(c, { kind = "person", person = cast })
        local n = 0
        for _, m in ipairs(MODULE.moments) do
            if util.contains(adventure.moment_people(m), cast) then
                n = n + 1
            end
        end
        local pb, pnote
        if r.boss then
            pnote = "Who it all leads to: always here."
            pb = {}
        else
            pb = lock_buttons(app, { kind = "person", person = cast }, plock, "Keep out of sight...", "person_" .. cast, {
                mode = "lock", target = { kind = "person", person = cast }, title = "KEEP " .. string.upper(p.name) .. " OUT OF SIGHT",
                prompt = "Until... (their moments are skipped and the room plays without them)" })
        end
        table.insert(cards, { title = p.name, tag = "PERSON", ins = { plock and "you to let them out" or "nothing: they're here" },
                              outs = { util.int(n) .. (n == 1 and " moment" or " moments") .. " of theirs, and their part in "
                                  .. ties.the(id) .. "." },
                              lock = plock, note = pnote or ((p.role or "") .. ". " .. (p.about or "")), buttons = pb,
                              stripe = theme.teal })
    end
    -- Its moments.
    for _, m in ipairs(ties.room_moments(id)) do
        local mlock = ties.lock_on(c, { kind = "moment", moment = m.id })
        local mb = {}
        local title = ties.plain(m.title)
        if mlock then
            mb = lock_buttons(app, nil, mlock, "", m.id, {
                mode = "lock", target = { kind = "moment", moment = m.id }, title = "\"" .. string.upper(title) .. "\" PLAYS ONLY IF",
                prompt = "It plays only if..." })
        else
            table.insert(mb, { label = "Only if...", key = "tl_only_" .. m.id, fn = function()
                start_pick(app, { mode = "lock", target = { kind = "moment", moment = m.id },
                                  title = "\"" .. string.upper(title) .. "\" PLAYS ONLY IF", prompt = "It plays only if..." })
            end })
            table.insert(mb, { label = "Cut it", key = "tl_cut_" .. m.id, color = theme.panel3, fn = function()
                local made, why = ties.add_lock(c, { kind = "moment", moment = m.id, cond = { kind = "never" } })
                if made then
                    say(app, "Done. " .. ties.describe(made, c), true)
                    changed(app)
                else
                    say(app, why, false)
                end
                redraw(app)
            end })
        end
        local conds = ties.moment_conds(m)
        if #conds > 0 then
            table.insert(mb, { label = "Tie...", key = "tl_tie_" .. m.id, fn = function()
                local pk = { mode = "tie", only = conds, title = "TIE TO \"" .. string.upper(title) .. "\"",
                             prompt = "When this card does which?" }
                if #conds == 1 then
                    pk.cond, pk.cond_given = conds[1], true
                end
                start_pick(app, pk)
            end })
        end
        table.insert(cards, { title = title, tag = "MOMENT", ins = ties.moment_ins(c, m), outs = ties.moment_outs(m),
                              no_outs = "Nothing the rest of the adventure looks at: it's for the table.", lock = mlock,
                              buttons = mb, stripe = theme.purple, campaign = c })
    end
    -- The heroes' reasons for coming that pay off here (or moved from here).
    for _, p in ipairs(c.players or {}) do
        local h = adventure.hook(c, p.key)
        if h and (h.room == id or h.moved_from == id) then
            local here = h.room == id
            local found = st.done[h.room] ~= nil
            local ins = { here and "pays off here" or ("moved to " .. ties.the(h.room)) }
            if here and h.moved_from then
                table.insert(ins, "moved here from " .. ties.the(h.moved_from))
            end
            local hb = {}
            if not found then
                table.insert(hb, { label = "Move it...", key = "tl_move_" .. p.key, fn = function()
                    start_pick(app, { mode = "tie", effect = { kind = "hook", key = p.key }, effect_given = true,
                                      title = "MOVE " .. string.upper(p.char) .. "'S REASON FOR COMING",
                                      prompt = "When does it move?" })
                end })
            end
            table.insert(cards, { title = p.char .. ": " .. h.name, tag = "WHY THEY CAME", ins = ins,
                                  outs = { found and "Found it." or "The hero sits up when it plays." },
                                  buttons = hb, stripe = theme.gold })
        end
    end
    return cards
end

local function draw_cards(app, cards, x, y, w, bottom)
    -- Pages of whole cards.
    local pages, cur, used = { {} }, 1, 0
    local space = bottom - y - 40
    for _, cd in ipairs(cards) do
        cd.h = card(cd, x, 0, w, false)
        if used + cd.h > space and #pages[cur] > 0 then
            cur = cur + 1
            pages[cur] = {}
            used = 0
        end
        table.insert(pages[cur], cd)
        used = used + cd.h + 8
    end
    local page = math.max(1, math.min(app.tl_page or 1, #pages))
    app.tl_page = page
    local cy = y
    for _, cd in ipairs(pages[page]) do
        card(cd, x, cy, w, true)
        cy = cy + cd.h + 8
    end
    if #pages > 1 then
        kit.button(x, bottom - 32, 100, 30, "<  Back", function()
            app.tl_page = page - 1
            redraw(app)
        end, { font = "ui14", enabled = page > 1, key = "tl_cards_prev" })
        kit.text(x + w / 2, bottom - 26, util.int(page) .. " of " .. util.int(#pages), "ui14", theme.dim, { pivot = gui.PIVOT_N })
        kit.button(x + w - 100, bottom - 32, 100, 30, "More  >", function()
            app.tl_page = page + 1
            redraw(app)
        end, { font = "ui14", enabled = page < #pages, key = "tl_cards_next" })
    end
end

local function room_panel(app, id, x, y, w, h)
    local r = MODULE.rooms[id]
    local c = app.campaign
    kit.text(x, y, r.name, "ui22b", theme.gold, { w = w, lines = 1 })
    local ways = {}
    for _, n in ipairs(adventure.neighbors(id)) do
        local shut = adventure.way_closed(c, id, n) or adventure.way_closed(c, n, id)
        table.insert(ways, ties.the(n) .. (shut and " (locked)" or ""))
    end
    local doors = #ways > 0 and ("Doors to " .. util.join_names(ways) .. ".") or "No doors."
    kit.text(x, y + 30, doors, "ui14", theme.dim, { w = w, lines = 2 })
    local cy = y + 30 + math.min(2, #kit.wrap(doors, "ui14", w)) * L14 + 10
    draw_cards(app, room_cards(app, id), x, cy, w, y + h)
end

local function door_panel(app, d, x, y, w, h)
    local c = app.campaign
    local a, b = d[1], d[2]
    kit.text(x, y, "A door", "ui22b", theme.gold)
    kit.text(x, y + 30, "Between " .. ties.the(a) .. " and " .. ties.the(b) .. ".", "ui14", theme.dim, { w = w, lines = 2 })
    local lock = ties.lock_on(c, { kind = "door", a = a, b = b })
    local spec = { title = "The door", tag = "DOOR", ins = { "nothing: it's open unless you lock it" },
                   outs = { "A way between the two rooms, both ways." }, lock = lock, stripe = DOOR, campaign = c,
                   buttons = lock_buttons(app, nil, lock, "Lock it...", "door", {
                       mode = "lock", target = { kind = "door", a = a, b = b }, title = "LOCK THE DOOR",
                       prompt = "Between " .. ties.the(a) .. " and " .. ties.the(b) .. ". It stays shut until..." }) }
    if lock then
        spec.ins = nil
    end
    spec.h = card(spec, x, 0, w, false)
    card(spec, x, y + 60, w, true)
    local by = y + 60 + spec.h + 16
    kit.text(x, by, "THE ROOMS EITHER SIDE", "ui14", theme.dim)
    local bx = x
    for _, id in ipairs({ a, b }) do
        local label = MODULE.rooms[id].name
        local bw = kit.width(label, "ui14") + 24
        kit.button(bx, by + 22, bw, 28, label, function()
            app.tl_sel = { room = id }
            app.tl_page = 1
            redraw(app)
        end, { font = "ui14", key = "tl_side_" .. id })
        bx = bx + bw + 8
    end
end

-- The floor plan ----------------------------------------------------------------------------------

local function room_colour(c, id)
    local st = c.adv
    local r = MODULE.rooms[id]
    if st.done[id] then
        return kit.rgba("#4f6a3e")
    elseif st.skipped[id] then
        return kit.rgba("#2a201b")
    elseif r.boss then
        return kit.rgba("#6a2e26")
    elseif adventure.room_closed(c, id) then
        return kit.rgba("#4a2f28")
    end
    return theme.panel3
end

local function draw_plan(app)
    local c = app.campaign
    local st = adventure.fill(c.adv)
    kit.box(MAP_X, MAP_Y, MAP_W, MAP_H, kit.rgba("#000000", 0.25), { radius = 10 })
    local plan = museum_prep_view.plan(MAP_X, MAP_Y, MAP_W, MAP_H)
    local sel = app.tl_sel or {}
    local here = st.pos or st.last_room
    for _, f in ipairs(plan.floors) do
        kit.text(f.x, f.y, f.fl.title, "ui14", theme.dim)
        for _, rm in ipairs(f.fl.rooms) do
            local id = rm[1]
            local r = plan.rooms[id]
            local def = MODULE.rooms[id]
            if sel.room == id then
                kit.box(r.x - 3, r.y - 3, r.w + 6, r.h + 6, theme.gold, { radius = 8 })
            elseif here == id then
                kit.box(r.x - 2, r.y - 2, r.w + 4, r.h + 4, theme.teal, { radius = 7 })
            end
            local col = room_colour(c, id)
            if r.backdrop and not st.done[id] then
                col = kit.rgba("#3a2e26")
            end
            kit.button(r.x, r.y, r.w, r.h, "", function()
                app.tl_sel = { room = id }
                app.tl_page = 1
                app.tl_pick = nil
                app.tl_msg = nil
                redraw(app)
            end, { color = col, hover = theme.button_hover, key = "tl_room_" .. id, radius = 6 })
            local label = def.map or (string.gsub(def.name, "^The ", ""))
            local lx, ly = r.x + r.w / 2, r.y + math.max(1, (r.h - 18) / 2)
            if r.label_at then
                lx, ly = r.label_at[1], r.label_at[2]
            end
            kit.text(lx, ly, kit.ellipsize(label, "ui14", r.w - 8), "ui14", st.skipped[id] and theme.faint or theme.text,
                { pivot = gui.PIVOT_N })
            if adventure.room_closed(c, id) then
                local ix = r.label_at and (lx - 8) or (r.x + r.w - 21)
                local iy = r.label_at and (ly - 20) or (r.y + 4)
                kit.icon(ix, iy, 16, "lock", theme.gold)
            end
        end
    end
    for _, f in ipairs(plan.floors) do
        if f.fl.down then
            local inner = f.inner
            local dr = f.fl.down
            local dx, dy = inner[1] + dr[1] * inner[3], inner[2] + dr[2] * inner[4]
            local dw, dh = (dr[3] - dr[1]) * inner[3], (dr[4] - dr[2]) * inner[4]
            kit.box(dx, dy, dw, dh, kit.rgba("#000000", 0.25), { radius = 4 })
            kit.text(dx + dw / 2, dy + 4, "down", "ui14", theme.faint, { pivot = gui.PIVOT_N })
        end
    end
    -- The doors: a little square each, a lock on the shut ones.
    for _, d in ipairs(plan.doors) do
        local lock = ties.lock_on(c, { kind = "door", a = d.a, b = d.b })
        local on = sel.door and ((sel.door[1] == d.a and sel.door[2] == d.b) or (sel.door[1] == d.b and sel.door[2] == d.a))
        if on then
            kit.box(d.x - 14, d.y - 14, 28, 28, theme.gold, { radius = 7 })
        end
        local shut = lock and not lock.open
        kit.button(d.x - 10, d.y - 10, 20, 20, "", function()
            app.tl_sel = { door = { d.a, d.b } }
            app.tl_pick = nil
            app.tl_msg = nil
            redraw(app)
        end, { color = shut and SHUT or DOOR, hover = theme.go_hover, key = "tl_door_" .. ties.door_key(d.a, d.b), radius = 5 })
        if shut then
            kit.icon(d.x - 8, d.y - 8, 16, "lock", theme.gold)
        else
            kit.box(d.x - 2, d.y - 7, 4, 14, kit.rgba("#2a1a10", 0.8), { round = false })
        end
    end
end

-- The list of ties and locks --------------------------------------------------------------------

local function draw_list(app)
    local c = app.campaign
    local x, y, w = MAP_X, LIST_Y, MAP_W
    local bottom = Y + H - 20
    local items = {}
    for _, l in ipairs(ties.locks(c)) do
        table.insert(items, { x = l, lock = true })
    end
    for _, t in ipairs(ties.ties(c)) do
        table.insert(items, { x = t })
    end
    kit.text(x, y, "YOUR TIES AND LOCKS  (" .. util.int(#items) .. ")", "ui14", theme.dim)
    kit.button(x + w - 130, y - 6, 130, 28, "New tie...", function()
        start_pick(app, { mode = "tie", title = "A NEW TIE", prompt = "When this happens..." })
    end, { font = "ui14", key = "tl_new_tie" })
    y = y + 28
    if #items == 0 then
        kit.text(x, y, "Nothing yet. Pick a room or a door on the plan to lock it, or a card's Tie to make something happen "
            .. "when it does. The adventure plays as written until you do.", "ui18", theme.faint, { w = w })
        return
    end
    local rh = 46
    local per = math.max(1, math.floor((bottom - y - 34) / rh))
    local pages = math.max(1, math.ceil(#items / per))
    local page = math.max(1, math.min(app.tl_list_page or 1, pages))
    for i = (page - 1) * per + 1, math.min(#items, page * per) do
        local it = items[i]
        local o = it.x
        kit.box(x, y, w, rh - 6, theme.panel, { radius = 8 })
        local done = (it.lock and o.open) or (not it.lock and o.fired)
        kit.icon(x + 10, y + 11, 18, it.lock and "lock" or "link", done and theme.faint or theme.gold)
        local status = it.lock and (o.open and "open now" or nil) or (o.fired and (o.missed and "came too late" or "done") or nil)
        local tw = w - 40 - 120 - (status and 90 or 0)
        if it.lock then
            kit.text(x + 38, y + 3, util.capitalize(ties.target_name(o)), "ui14", theme.text, { w = tw, lines = 1 })
            kit.text(x + 38, y + 20, ties.rule(o, c), "ui14", theme.dim, { w = tw, lines = 1 })
        else
            kit.text(x + 38, y + 3, ties.rule(o, c), "ui14", theme.text, { w = tw, lines = 2 })
        end
        if status then
            kit.text(x + w - 120 - 12, y + 11, status, "ui14", theme.green, { pivot = gui.PIVOT_NE })
        end
        kit.button(x + w - 112, y + 6, 104, 28, "Take it off", function()
            ties.remove(c, o.id)
            say(app, "Taken off: " .. ties.describe(o, c), true)
            changed(app)
            redraw(app)
        end, { font = "ui14", key = "tl_remove_" .. o.id })
        y = y + rh
    end
    if pages > 1 then
        kit.button(x, bottom - 30, 90, 28, "<  Back", function()
            app.tl_list_page = page - 1
            redraw(app)
        end, { font = "ui14", enabled = page > 1, key = "tl_list_prev" })
        kit.text(x + w / 2, bottom - 25, util.int(page) .. " of " .. util.int(pages), "ui14", theme.dim, { pivot = gui.PIVOT_N })
        kit.button(x + w - 90, bottom - 30, 90, 28, "More  >", function()
            app.tl_list_page = page + 1
            redraw(app)
        end, { font = "ui14", enabled = page < pages, key = "tl_list_next" })
    end
end

-- The overlay -----------------------------------------------------------------------------------

function M.draw(app)
    if app.tl_layer then
        kit.drop(app.tl_layer)
    end
    app.tl_layer = kit.layer("ties", true)
    kit.box(0, 0, kit.W, kit.H, kit.rgba("#000000", 0.55), { round = false })
    kit.box(X, Y, W, H, theme.bg, { radius = 14 })
    kit.box(X, Y, W, 64, theme.panel, { radius = 14 })
    kit.text(X + 24, Y + 14, "TIES AND LOCKS", "title30", theme.gold)
    local tx = X + 24 + kit.width("TIES AND LOCKS", "title30") + 30
    kit.text(tx, Y + 12, "Bend the adventure: lock a way, a person or a card until something happens, or tie something to "
        .. "happen when it does.", "ui18", theme.dim, { w = X + W - 170 - tx, lines = 2 })
    kit.button(X + W - 140, Y + 14, 120, 36, "Done", function()
        M.close(app)
        if app.refresh then
            app.refresh()
        end
    end, { font = "ui18b", color = theme.go, hover = theme.go_hover, key = "tl_done" })
    draw_plan(app)
    -- Under the plan: what just happened, or how it works.
    local msg = app.tl_msg
    local my = MAP_Y + MAP_H + 6
    if msg and msg.good then
        kit.text(MAP_X, my, msg.text, "ui14", theme.green, { w = MAP_W, lines = 2 })
    elseif msg and not app.tl_pick then
        kit.text(MAP_X, my, msg.text, "ui14", theme.orange, { w = MAP_W, lines = 2 })
    else
        kit.text(MAP_X, my, "Click a room for its cards, or a door (the small squares) to lock it. A lock shows on the prep "
            .. "board's plan too.", "ui14", theme.faint, { w = MAP_W, lines = 2 })
    end
    draw_list(app)
    if app.tl_pick then
        picker(app, PX, PY, PW, PH)
    else
        local sel = app.tl_sel
        if sel and sel.door then
            door_panel(app, sel.door, PX, PY, PW, PH)
        elseif sel and sel.room and MODULE.rooms[sel.room] then
            room_panel(app, sel.room, PX, PY, PW, PH)
        else
            kit.text(PX, PY, "Pick a room or a door on the plan.", "ui18", theme.faint, { w = PW })
        end
    end
end

return M
