-- Dialogue review mode (M5), development builds only. F4 turns it on.
--
-- On game night a rail on the right shows each line as it fires, beside its
-- trigger and speaker, with Approve, Edit and Reject; hovering the rail holds the
-- night. The queue (Q on game night, F4 anywhere else) walks every cell that still
-- has drafts: the cell's lines, the trigger and the speaker's voice sheet, all
-- reviewable from the keyboard. Every decision saves straight away
-- (game/model/dialogue.lua says where).

local kit = require "game.ui.kit"
local theme = require "game.ui.theme"
local content = require "game.model.content"
local dialogue = require "game.model.dialogue"
local util = require "game.model.util"

local M = {}

local RAIL_X, RAIL_W, RAIL_Y = 1196, 380, 104
local RAIL_MAX = 4
local LIST_X, LIST_W, LIST_Y, ROW_H, ROWS = 24, 360, 100, 25, 29
local MID_X, MID_W = 404, 760
local SIDE_X, SIDE_W = 1184, 392

local STATUS_COLOR = {
    draft = kit.rgba("#8a7c6a"), approved = kit.rgba("#7fb069"), edited = kit.rgba("#5aa39b"), rejected = kit.rgba("#d0604f"),
}
local STATUS_NAME = { draft = "Draft", approved = "Approved", edited = "Edited", rejected = "Rejected" }
local VOICE_NAME = { table = "the player, at the table", character = "the character, in the story",
                     chat = "a group chat message", npc = "the DM voicing the NPC" }

local function lib()
    return content.dialogue
end

-- 1228 -> "1,228"
local function num(n)
    local s = util.int(n)
    local out = string.gsub(s, "^(%d+)(%d%d%d)$", "%1,%2")
    return out
end

function M.available()
    return dialogue.dev_build() and not dialogue.playtest_build()
end

local function state(app)
    app.review = app.review or { on = false, fired = {}, cell_i = 1, sel = 1, scroll = 0 }
    return app.review
end

local function speaker_name(key)
    local v = lib().voices[key]
    if not v then
        return key
    end
    return v.kind == "player" and (v.name .. " (" .. v.char .. ")") or v.name
end

-- Saving -----------------------------------------------------------------------------------------

function M.attach_project(app)
    local root = dialogue.find_project()
    local r = state(app)
    if root and not lib().root then
        -- Read the project's lines.json (fresher than the copy built into the game) and save there.
        local fresh = dialogue.load({ root = root })
        content.dialogue = fresh
    end
    r.where = lib().root and "project" or "save file"
end

local function decide(app, id, status, text)
    local r = state(app)
    if lib():set_status(id, status, text) then
        local where, err = lib():save()
        r.saved = where and ("Saved to the " .. (where == "project" and "project's lines.json" or "overrides file"))
            or ("Couldn't save: " .. tostring(err))
    end
end

-- Queue ---------------------------------------------------------------------------------------------

-- Cells that still have drafts, in trigger order.
local function queue_cells()
    local out = {}
    for _, c in ipairs(lib():all_cells()) do
        for _, l in ipairs(lib():cell_lines(c.key)) do
            if l.status == "draft" then
                table.insert(out, c)
                break
            end
        end
    end
    return out
end

local function counts(key)
    local a, d = 0, 0
    for _, l in ipairs(lib():cell_lines(key)) do
        if dialogue.APPROVED[l.status] then
            a = a + 1
        elseif l.status == "draft" then
            d = d + 1
        end
    end
    return a, d
end

function M.open_queue(app, focus_id, edit)
    local r = state(app)
    r.queue = queue_cells()
    r.cell_i = 1
    r.sel = 1
    r.focus = nil
    if focus_id then
        local l = lib().by_id[focus_id]
        if l then
            -- Show that line's cell even if it has no drafts left.
            local t = lib().trigger[l.trigger]
            local key = dialogue.cell_key(l.trigger, l.speaker, t and t.split and l[t.split.field] or nil)
            local found
            for i, c in ipairs(r.queue) do
                if c.key == key then
                    found = i
                end
            end
            if not found then
                for _, c in ipairs(lib():all_cells()) do
                    if c.key == key then
                        table.insert(r.queue, 1, c)
                        found = 1
                    end
                end
            end
            r.cell_i = found or 1
            for i, x in ipairs(lib():cell_lines(key)) do
                if x.id == focus_id then
                    r.sel = i
                end
            end
        end
    end
    r.queue_open = true
    r.hold = true
    if edit then
        M.start_edit(app)
    end
    M.draw_queue(app)
end

function M.close_queue(app)
    local r = state(app)
    r.queue_open = false
    r.editing = nil
    r.hold = false
    if app.layers.review_queue then
        kit.drop(app.layers.review_queue)
        app.layers.review_queue = nil
    end
    kit.reset_hover()
end

local function current_cell(app)
    local r = state(app)
    return r.queue and r.queue[r.cell_i]
end

local function current_lines(app)
    local c = current_cell(app)
    return c and lib():cell_lines(c.key) or {}
end

local function move_cell(app, d)
    local r = state(app)
    r.cell_i = util.clamp(r.cell_i + d, 1, math.max(1, #r.queue))
    r.sel = 1
    -- Start on the first line that still needs a decision.
    for i, l in ipairs(current_lines(app)) do
        if l.status == "draft" then
            r.sel = i
            break
        end
    end
    r.editing = nil
end

-- Approve every draft left in this cell, then move on.
local function approve_rest(app)
    for _, l in ipairs(current_lines(app)) do
        if l.status == "draft" then
            decide(app, l.id, "approved")
        end
    end
    move_cell(app, 1)
end

function M.start_edit(app, field)
    local r = state(app)
    local l = current_lines(app)[r.sel]
    if not l then
        return
    end
    field = field or "text"
    if field == "reply" and not l.reply then
        field = "text"
    end
    r.editing = { id = l.id, field = field, text = l[field] or "", other = field == "text" and l.reply or l.text }
end

local function commit_edit(app)
    local r = state(app)
    local e = r.editing
    if not e then
        return
    end
    local l = lib().by_id[e.id]
    local text = string.gsub(e.text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    if l and text ~= "" then
        if e.field == "reply" then
            if text ~= l.reply then
                l.orig_reply = l.orig_reply or l.reply
                l.reply = text
                decide(app, l.id, "edited")
            end
        else
            decide(app, l.id, "edited", text)
        end
    end
    r.editing = nil
end

-- Drawing the queue --------------------------------------------------------------------------------

local function button(x, y, w, label, fn, color)
    return kit.button(x, y, w, 28, label, fn, { font = "ui14", color = color or theme.button, hover = theme.button_hover })
end

function M.draw_queue(app)
    local r = state(app)
    if app.layers.review_queue then
        kit.drop(app.layers.review_queue)
    end
    app.layers.review_queue = kit.layer("review_queue", true)
    kit.box(0, 0, kit.W, kit.H, kit.rgba("#120c09", 0.99), { round = false })
    local _, totals = lib():coverage()
    kit.text(24, 14, "DIALOGUE REVIEW", "ui22b", theme.gold)
    kit.text(24, 46, num(totals.approved) .. " of " .. num(totals.lines) .. " lines approved, "
        .. num(totals.rejected) .. " rejected.  Cells with " .. util.int(lib().min_approved) .. "+ approved: "
        .. num(totals.ok) .. " of " .. num(totals.cells) .. ".  " .. num(#r.queue) .. " cells still have drafts.",
        "ui14", theme.dim)
    kit.text(LIST_X + 8, LIST_Y - 20, "CELLS WITH DRAFTS", "ui14", theme.gold)
    kit.text(LIST_X + LIST_W - 8, LIST_Y - 20, "approved / drafts", "ui14", theme.faint, { pivot = gui.PIVOT_NE })
    kit.text(1576, 14, r.saved or ("Saves to the " .. (lib().root and "project's lines.json" or "overrides file")), "ui14",
        r.saved and string.find(r.saved, "Couldn't", 1, true) and theme.red or theme.faint, { pivot = gui.PIVOT_NE })
    kit.text(1576, 46, "Up/Down line   A approve   E edit   R reject   Enter approve the rest   N/P next/previous cell   Esc close",
        "ui14", theme.faint, { pivot = gui.PIVOT_NE })

    -- Left: the cells still to review.
    local first = util.clamp(r.cell_i - math.floor(ROWS / 2), 1, math.max(1, #r.queue - ROWS + 1))
    for i = first, math.min(#r.queue, first + ROWS - 1) do
        local c = r.queue[i]
        local y = LIST_Y + (i - first) * ROW_H
        local a, d = counts(c.key)
        if i == r.cell_i then
            kit.box(LIST_X, y - 2, LIST_W, ROW_H, kit.rgba("#ffffff", 0.1), { radius = 6 })
        end
        local label = c.trigger.id .. "  " .. lib().voices[c.speaker].name .. (c.split and ("  " .. c.split) or "")
        local b = kit.button(LIST_X, y - 2, LIST_W, ROW_H, "", function()
            r.cell_i = i
            r.sel = 1
            r.editing = nil
            M.draw_queue(app)
        end, { color = kit.rgba("#000000", 0.01), hover = kit.rgba("#ffffff", 0.06) })
        kit.text(LIST_X + 8, y + 2, kit.ellipsize(label, "ui14", 250), "ui14", i == r.cell_i and theme.text or theme.dim)
        kit.text(LIST_X + LIST_W - 8, y + 2, util.int(a) .. " / " .. util.int(d), "ui14",
            a >= lib().min_approved and theme.green or theme.faint, { pivot = gui.PIVOT_NE })
    end
    if #r.queue == 0 then
        kit.text(LIST_X, LIST_Y, "Nothing left to review. Every line has a decision.", "ui18", theme.green, { w = LIST_W })
    end

    local c = current_cell(app)
    if not c then
        return
    end
    -- Middle: the cell and its lines.
    local t = c.trigger
    kit.text(MID_X, 84, t.id .. "  -  " .. speaker_name(c.speaker) .. (c.split and ("  -  " .. c.split) or ""), "ui22b", theme.text)
    local when_h = kit.text_height(t.when, "ui18", MID_W)
    kit.text(MID_X, 118, t.when, "ui18", theme.dim, { w = MID_W })
    local fills = {}
    for _, f in ipairs(t.fill or {}) do
        table.insert(fills, "{" .. f .. "}")
    end
    kit.text(MID_X, 124 + when_h, "Spoken as " .. VOICE_NAME[t.voice] .. ".   Fill-ins: "
        .. (#fills > 0 and table.concat(fills, " ") or "none") .. ".   At most " .. util.int(t.max or 90) .. " characters.",
        "ui14", theme.faint, { w = MID_W })
    local y = 156 + when_h
    for i, l in ipairs(lib():cell_lines(c.key)) do
        local editing = r.editing and r.editing.id == l.id
        local text_w = MID_W - 240
        local body = l.text
        local h = kit.text_height(body, "ui18", text_w) + 34
        if l.reply then
            h = h + kit.text_height("Reply: " .. l.reply, "ui14", text_w) + 4
        end
        local problems = lib():lint(l)
        if #problems > 0 then
            h = h + 20
        end
        if editing then
            h = math.max(h, 120)
        end
        local sel = i == r.sel
        kit.box(MID_X, y, MID_W, h, sel and kit.rgba("#3a2c22") or kit.rgba("#221913"), { radius = 8 })
        kit.box(MID_X, y, 6, h, STATUS_COLOR[l.status] or theme.faint, { round = false })
        kit.text(MID_X + 18, y + 8, (STATUS_NAME[l.status] or l.status) .. (l.to and ("   to " .. lib().voices[l.to].name) or "")
            .. (l.orig and "   (was: " .. kit.ellipsize(l.orig, "ui14", 260) .. ")" or ""), "ui14", STATUS_COLOR[l.status] or theme.faint)
        if editing then
            local e = r.editing
            kit.box(MID_X + 14, y + 28, MID_W - 28, 56, theme.paper, { radius = 6 })
            kit.text(MID_X + 24, y + 34, e.text .. "_", "ui18", theme.ink, { w = MID_W - 48, lines = 2 })
            kit.text(MID_X + 18, y + 90, "Editing the " .. e.field .. ". Enter saves, Esc cancels" .. (l.reply and ", Tab switches to the "
                .. (e.field == "text" and "reply" or "line") or "") .. ".  " .. util.int(#e.text) .. "/" .. util.int(t.max or 90),
                "ui14", #e.text > (t.max or 90) and theme.red or theme.faint)
        else
            kit.text(MID_X + 18, y + 28, body, "ui18", l.status == "rejected" and theme.faint or theme.text, { w = text_w })
            local yy = y + 28 + kit.text_height(body, "ui18", text_w)
            if l.reply then
                kit.text(MID_X + 18, yy + 2, "Reply: " .. l.reply, "ui14", theme.dim, { w = text_w })
                yy = yy + kit.text_height("Reply: " .. l.reply, "ui14", text_w) + 4
            end
            if #problems > 0 then
                kit.text(MID_X + 18, yy + 2, table.concat(problems, "; "), "ui14", theme.red, { w = text_w })
            end
            local bx = MID_X + MID_W - 214
            local id = l.id
            button(bx, y + 8, 76, "Approve", function()
                r.sel = i
                decide(app, id, "approved")
                M.draw_queue(app)
            end, theme.go)
            button(bx + 80, y + 8, 56, "Edit", function()
                r.sel = i
                M.start_edit(app)
                M.draw_queue(app)
            end)
            button(bx + 140, y + 8, 66, "Reject", function()
                r.sel = i
                decide(app, id, "rejected")
                M.draw_queue(app)
            end, kit.rgba("#5a2a22"))
        end
        y = y + h + 8
    end
    button(MID_X, y + 4, 290, "Approve the rest and next  (Enter)", function()
        approve_rest(app)
        M.draw_queue(app)
    end, theme.go)
    button(MID_X + 300, y + 4, 140, "Next cell  (N)", function()
        move_cell(app, 1)
        M.draw_queue(app)
    end)
    button(MID_X + 450, y + 4, 120, "Close  (Esc)", function()
        M.close_queue(app)
    end)

    -- Right: the speaker's voice sheet.
    M.draw_voice(c.speaker, SIDE_X, 84, SIDE_W)
end

function M.draw_voice(key, x, y, w)
    local v = lib().voices[key]
    if not v then
        return
    end
    kit.box(x, y, w, 860 - y, kit.rgba("#221913"), { radius = 10 })
    local cy = y + 12
    local function para(label, text, color)
        if not text or text == "" then
            return
        end
        if label then
            kit.text(x + 14, cy, label, "ui14", theme.gold)
            cy = cy + 19
        end
        local h = kit.text_height(text, "ui14", w - 28)
        if cy + h > 850 then
            return
        end
        kit.text(x + 14, cy, text, "ui14", color or theme.text, { w = w - 28 })
        cy = cy + h + 8
    end
    kit.text(x + 14, cy, v.name, "ui22b", theme.text, { w = w - 28, lines = 1 })
    cy = cy + 30
    if v.kind == "player" then
        para(nil, v.char .. ", " .. v.class .. ". " .. v.archetypes .. ".", theme.dim)
        para("At the table", v.table)
        para("In character", v.character)
        para("In the group chat", v.chat)
    else
        para(nil, v.personality)
    end
    para("Tics", table.concat(v.tics or {}, "  /  "))
    para("Never", table.concat(v.never or {}, "  /  "), kit.rgba("#e8a090"))
    if v.kind == "player" then
        para("Samples", table.concat(v.samples_table or {}, "  |  ") .. "  |  " .. table.concat(v.samples_character or {}, "  |  "), theme.dim)
    else
        para("Samples", table.concat(v.samples or {}, "  |  "), theme.dim)
    end
end

-- The game night rail -------------------------------------------------------------------------------

-- A line just fired (say or npc beat): remember it for the rail.
function M.on_line(app, ev)
    local r = state(app)
    if not r.on or not ev.line then
        return
    end
    local l = lib().by_id[ev.line]
    if not l then
        return
    end
    for i = #r.fired, 1, -1 do
        if r.fired[i].id == ev.line then
            table.remove(r.fired, i)
        end
    end
    -- What was actually said (fill-ins filled); a banter reply joins its line.
    local said = ev.text
    if ev.part == "reply" and r.last_said and r.last_said.id == ev.line then
        said = r.last_said.text .. "  /  " .. ev.text
    end
    r.last_said = { id = ev.line, text = said }
    table.insert(r.fired, { id = ev.line, text = said })
    while #r.fired > RAIL_MAX do
        table.remove(r.fired, 1)
    end
    M.draw_rail(app)
end

function M.draw_rail(app)
    local r = state(app)
    if app.layers.review_rail then
        kit.drop(app.layers.review_rail)
        app.layers.review_rail = nil
    end
    if not r.on or app.screen ~= "night" or app.pending or app.night_done or r.queue_open then
        return
    end
    app.layers.review_rail = kit.layer("review_rail", false)
    local y = RAIL_Y
    r.rail_hit = {}
    table.insert(r.rail_hit, kit.box(RAIL_X, y, RAIL_W, 26, kit.rgba("#120c09", 0.85), { radius = 6 }))
    kit.text(RAIL_X + 10, y + 4, "REVIEW  F4 off   Q queue   hover holds the night", "ui14", theme.gold)
    y = y + 32
    for i = #r.fired, 1, -1 do
        local l = lib().by_id[r.fired[i].id]
        if l then
            local text = r.fired[i].text
            local th = math.min(3, #kit.wrap(text, "ui14", RAIL_W - 24)) * 19
            local h = 30 + th + 36
            table.insert(r.rail_hit, kit.box(RAIL_X, y, RAIL_W, h, kit.rgba("#140e0b", 0.9), { radius = 8 }))
            kit.box(RAIL_X, y, 5, h, STATUS_COLOR[l.status] or theme.faint, { round = false })
            kit.text(RAIL_X + 14, y + 6, kit.ellipsize(lib().voices[l.speaker].name .. "  -  " .. l.trigger
                .. "  -  " .. (STATUS_NAME[l.status] or l.status), "ui14", RAIL_W - 28), "ui14", STATUS_COLOR[l.status] or theme.dim)
            kit.text(RAIL_X + 14, y + 26, text, "ui14", theme.text, { w = RAIL_W - 24, lines = 3 })
            local by = y + 30 + th
            local id = l.id
            kit.button(RAIL_X + 14, by, 80, 26, "Approve", function()
                decide(app, id, "approved")
                M.draw_rail(app)
            end, { font = "ui14", color = theme.go, hover = theme.go_hover })
            kit.button(RAIL_X + 100, by, 60, 26, "Edit", function()
                M.open_queue(app, id, true)
            end, { font = "ui14" })
            kit.button(RAIL_X + 166, by, 70, 26, "Reject", function()
                decide(app, id, "rejected")
                M.draw_rail(app)
            end, { font = "ui14", color = kit.rgba("#5a2a22") })
            kit.button(RAIL_X + 242, by, 124, 26, "Voice and cell", function()
                M.open_queue(app, id, false)
            end, { font = "ui14" })
            y = y + h + 6
        end
    end
end

-- Hovering the rail holds the night so there's time to read and decide.
function M.on_move(app, x, y)
    local r = app.review
    if not r or not r.on or r.queue_open then
        return
    end
    r.hold = false
    if app.layers.review_rail then
        for _, n in ipairs(r.rail_hit or {}) do
            if gui.pick_node(n, x, y) then
                r.hold = true
            end
        end
    end
end

-- On and off ---------------------------------------------------------------------------------------

function M.toggle(app)
    local r = state(app)
    if not M.available() then
        return
    end
    if not r.attached then
        r.attached = true
        M.attach_project(app)
    end
    if r.queue_open then
        M.close_queue(app)
        r.on = false
    elseif app.screen == "night" then
        r.on = not r.on
        r.hold = false
    else
        r.on = true
        M.open_queue(app)
        return
    end
    M.draw_rail(app)
end

-- After the screen is rebuilt (its layers were cleared), put the review layers back.
function M.rebuild(app)
    local r = app.review
    if not r then
        return
    end
    app.layers.review_rail, app.layers.review_queue = nil, nil
    if r.queue_open then
        M.draw_queue(app)
    else
        M.draw_rail(app)
    end
end

-- Keys. Returns true when the review mode used the input.
function M.on_input(app, action_id, action)
    local r = app.review
    if not r or not r.queue_open then
        return false
    end
    local e = r.editing
    if e then
        if action_id == hash("text") and action.text then
            local ch = string.gsub(action.text, "[^\32-\126]", "")
            e.text = e.text .. ch
            M.draw_queue(app)
        elseif action.pressed or action.repeated then
            if action_id == hash("backspace") then
                e.text = string.sub(e.text, 1, -2)
            elseif action_id == hash("confirm") then
                commit_edit(app)
            elseif action_id == hash("back") then
                r.editing = nil
            elseif action_id == hash("log") then
                local l = lib().by_id[e.id]
                if l and l.reply then
                    commit_edit(app)
                    M.start_edit(app, e.field == "text" and "reply" or "text")
                end
            else
                return true
            end
            M.draw_queue(app)
        end
        return true
    end
    if action_id == hash("touch") or action_id == nil then
        return false -- clicks and hover go to the buttons
    end
    if not (action.pressed or action.repeated) then
        return true
    end
    local lines = current_lines(app)
    local l = lines[r.sel]
    if action_id == hash("up") then
        r.sel = util.clamp(r.sel - 1, 1, math.max(1, #lines))
    elseif action_id == hash("down") then
        r.sel = util.clamp(r.sel + 1, 1, math.max(1, #lines))
    elseif action_id == hash("approve") and l then
        decide(app, l.id, "approved")
        r.sel = util.clamp(r.sel + 1, 1, #lines)
    elseif action_id == hash("reject") and l then
        decide(app, l.id, "rejected")
        r.sel = util.clamp(r.sel + 1, 1, #lines)
    elseif action_id == hash("edit") and l then
        M.start_edit(app)
    elseif action_id == hash("confirm") then
        approve_rest(app)
    elseif action_id == hash("next_cell") then
        move_cell(app, 1)
    elseif action_id == hash("prev_cell") then
        move_cell(app, -1)
    elseif action_id == hash("back") or action_id == hash("review") then
        M.close_queue(app)
        M.draw_rail(app)
        return true
    else
        return true
    end
    M.draw_queue(app)
    return true
end

return M
