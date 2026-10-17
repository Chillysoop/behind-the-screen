-- The lore screen (October 16): after the prep board, before the table sits down. What tonight
-- can change in the story, for the DM alone: scene by scene, the clues, what a won or lost scene
-- puts in next session's hand, what holds a front back; every storyline, and what leaving it
-- costs; the clue next session hangs on; the fronts behind the screen; and the calls with lasting
-- effects. Not happy with it? Back to prep. The words are game/model/lore_screen.lua's.

local kit = require "game.ui.kit"
local theme = require "game.ui.theme"
local util = require "game.model.util"
local content = require "game.model.content"
local gloss = require "game.ui.gloss"
local marks = require "game.ui.lore_marks"
local lore = require "game.model.lore"
local lore_screen = require "game.model.lore_screen"

local M = {}

local PAD = 14
local LH = 19                         -- ui14's line
local SCENE_X, SCENE_W, SCENE_GAP = 24, 368, 12
local TOP_Y, MID_Y, BOT_Y = 108, 530, 826
local RIGHT_X, RIGHT_W = 1168, 408

local TONE = {
    story = theme.text, next = theme.gold, good = theme.green, bad = theme.orange, front = theme.purple,
    thread = theme.text, dim = theme.dim, warn = theme.gold,
}

-- Each kind of line: its mark, its hover card's title, what it means (the lore playtest, October 16:
-- the hover cards only repeated the line), and its word in the key at the bottom.
local KIND = {
    clue = { icon = "story", color = theme.gold, title = "A clue in this scene", key = "clue",
             explain = "Something the party can find out tonight. It goes in your notes, and the story builds on it." },
    next = { icon = "hourglass", color = theme.gold, title = "Next session hangs on it", key = "next session's clue",
             explain = "Next session's plan changes if they find this. Without it, they set out a different way." },
    opens_win = { icon = "up", color = theme.green, title = "If they win this scene", key = "if won",
                  explain = "A scene is won when the heroes get what they came for. These cards are added to your hand "
                      .. "(the cards you prep from) for next session." },
    opens_lose = { icon = "down", color = theme.orange, title = "If they lose this scene", key = "if lost",
                   explain = "A lost scene still moves the story, just another way. These cards are added to your hand for "
                       .. "next session." },
    opens = { icon = "up", color = theme.teal, title = "Whatever happens", key = "either way",
              explain = "Played at all, win or lose, this puts cards in your hand for next session." },
    resolve = { icon = "reward", color = theme.green, title = "A story it can tie off", key = "ties a story off",
                explain = "Win this and a side story is finished for good: one less thread for the table to keep track of." },
    front = { icon = "crown", color = theme.purple, title = "Holding a plan back", key = "holds a plan back",
              explain = "A faction's plan moves a step every session. Win a scene with one of its cards and it stays put "
                  .. "for a session." },
    move = { icon = "crown", color = theme.purple, title = "A move off screen, played out here", key = "a world move",
             explain = "You chose to play a faction's move tonight instead of rolling for it. How the scene goes decides it." },
    villain = { icon = "warn", color = theme.red, title = "A villain", key = "villain",
                explain = "Beat a villain and they're done. One who gets away comes back later, angrier each time." },
    thread = { icon = "story", color = theme.dim, title = "A hero's own story", key = "a hero's story",
               explain = "A step in one hero's backstory. Their player loves it when it moves." },
    seed = { icon = "reward", color = theme.green, title = "A seed paying off", key = "a seed pays off",
             explain = "Something you planted in an earlier session comes good. The table loves a payoff." },
    want = { icon = "heart", color = theme.heart, title = "Someone's own want", key = "a want",
             explain = "Someone in the world brought this to the party: a favour, or trouble." },
}
local KEY_ORDER = { "clue", "next", "opens_win", "opens_lose", "front", "villain", "thread", "want" }

-- After tonight (lore_screen's row.after): the word and its colour.
local AFTER = {
    starts = { "Starts tonight", theme.green }, back = { "Comes back", theme.green }, moves = { "Moves tonight", theme.green },
    fine = { "Fine for now", theme.dim }, cold = { "Goes cold", theme.gold }, noticed = { "Table notices", theme.orange },
    loose = { "Still loose", theme.red }, waiting = { "Not started", theme.faint },
}
local HEAT_EXPLAIN = "A story stays alive while cards move it. Left alone it cools, then goes cold. Leave a cold "
    .. "story one more session and the table notices: someone says they miss it, and the players who care lose "
    .. "Investment (how much they care about the story) every session until a card brings it back."

local function lines_h(text, w, max)
    return math.min(kit.text_height(text, "ui14", w), max * LH)
end

local function truncated(text, w, max)
    return kit.text_height(text, "ui14", w) > max * LH
end

local function panel(x, y, w, h)
    kit.box(x, y, w, h, theme.panel, { radius = 10 })
end

local function label(x, y, text, color)
    kit.text(x, y, text, "ui14", color or theme.gold)
end

-- One line with its mark in front; a hover card when there's more to say than fits.
local function item(app, it, x, y, w, max)
    local k = KIND[it.kind] or KIND.clue
    if it.kind == "thread" and it.thread then
        marks.storyline(app, "bs_" .. it.thread, x, y + 1, 16)
    elseif it.kind == "clue" and it.clue then
        local m = lore.clue_mark(app.campaign, it.clue)
        if m then
            marks.mark(m, x, y + 1, 16)
        else
            kit.icon(x, y + 1, 16, k.icon, k.color)
        end
    else
        kit.icon(x, y + 1, 16, k.icon, k.color)
    end
    local tw = w - 24
    kit.text(x + 24, y, it.text, "ui14", TONE[it.tone] or theme.text, { w = tw, lines = max })
    local h = lines_h(it.text, tw, max)
    -- Every line explains itself on hover: the whole line, what kind of line it is, and any more.
    gloss.card_spot(x - 2, y - 2, w + 4, h + 4, k.title,
        it.text .. (it.more and ("\n\n" .. it.more) or "") .. (k.explain and ("\n\n" .. k.explain) or ""))
    return h
end

-- A scene's column: what it is, the stories it moves, and what it can change.
local function scene_column(app, sv, x, y, w, h)
    panel(x, y, w, h)
    local iw = w - 2 * PAD
    label(x + PAD, y + 10, "SCENE " .. util.int(sv.i), theme.gold)
    -- The stories it moves, by their marks.
    local mx = x + PAD + kit.width("SCENE " .. util.int(sv.i), "ui14") + 10
    for _, id in ipairs(sv.stories or {}) do
        if mx < x + w - 140 and marks.storyline(app, id, mx, y + 11, 16) then
            mx = mx + 20
        end
    end
    local col = theme.scene[sv.type or ""] or theme.panel3
    local tn = string.upper(sv.type_name or "")
    local tw = kit.width(tn, "ui14") + 16
    kit.box(x + w - PAD - tw, y + 9, tw, 22, col, { radius = 6 })
    kit.text(x + w - PAD - tw / 2, y + 11, tn, "ui14", theme.text, { pivot = gui.PIVOT_N })
    kit.text(x + PAD, y + 34, kit.ellipsize(sv.place, "ui18b", iw), "ui18b", theme.text)
    local sub = sv.goal and ("Goal: " .. sv.goal) or (sv.fight and ("A fight: " .. sv.fight)) or "No goal set: you'll make one up."
    kit.text(x + PAD, y + 60, kit.ellipsize(sub, "ui14", iw), "ui14", theme.dim)
    local ty = y + 88
    kit.box(x + PAD, ty - 6, iw, 1, theme.panel3, { round = false })
    if #sv.items == 0 then
        kit.text(x + PAD, ty + 2, "Nothing here moves the story: a scene for the table, not the plot.", "ui14", theme.faint,
            { w = iw })
        return
    end
    local bottom = y + h - 12 - (sv.more > 0 and LH or 0)
    local shown = 0
    for _, it in ipairs(sv.items) do
        local max = (it.kind == "clue" or it.kind == "next") and 4 or 3
        local ih = lines_h(it.text, iw - 24, max)
        if ty + ih > bottom then
            break
        end
        ty = ty + item(app, it, x + PAD, ty, iw, max) + 8
        shown = shown + 1
    end
    local rest = sv.more + (#sv.items - shown)
    if rest > 0 then
        kit.text(x + PAD, y + h - 12 - LH, "+" .. util.int(rest) .. " more on the board", "ui14", theme.faint)
    end
end

-- Every storyline in play: its mark, how it stands, and what tonight does to it.
local function storylines_column(app, view, x, y, w, h)
    panel(x, y, w, h)
    local iw = w - 2 * PAD
    label(x + PAD, y + 10, "EVERY STORY, AND WHAT TONIGHT DOES TO IT")
    local ty = y + 36
    if view.thin then
        local t = util.int(view.on_board) .. " separate stories on tonight's board: more than the table can follow. "
            .. "Each one past four costs a little fun."
        kit.icon(x + PAD, ty + 1, 16, "warn", theme.orange)
        kit.text(x + PAD + 24, ty, t, "ui14", theme.orange, { w = iw - 24, lines = 3 })
        ty = ty + lines_h(t, iw - 24, 3) + 10
    end
    local bottom = y + h - 12
    local shown = 0
    -- Stories nobody's started share one line at the bottom: nothing goes wrong while they wait.
    local rows, waiting = {}, {}
    for _, r in ipairs(view.storylines) do
        if r.after == "waiting" then
            table.insert(waiting, r)
        else
            table.insert(rows, r)
        end
    end
    local wait_text
    if #waiting > 0 then
        local names = {}
        for _, r in ipairs(waiting) do
            table.insert(names, r.name)
        end
        wait_text = "Not started yet: " .. util.join_names(names) .. ". Nothing goes wrong while they wait; any of their "
            .. "cards starts one."
        bottom = bottom - lines_h(wait_text, iw, 3) - 8
    end
    for _, r in ipairs(rows) do
        local lh = lines_h(r.line or "", iw - 26, 2)
        local fh = r.fix and lines_h(r.fix, iw - 26, 2) or 0
        if ty + 24 + lh + fh > bottom - LH then
            break
        end
        marks.storyline(app, r.id, x + PAD, ty + 2, 18)
        local nw = kit.width(r.name, "ui18b")
        kit.text(x + PAD + 26, ty, kit.ellipsize(r.name, "ui18b", iw - 140), "ui18b", theme.text)
        if r.who and nw + 40 + kit.width(r.who, "ui14") < iw - 120 then
            kit.text(x + PAD + 26 + nw + 8, ty + 3, r.who, "ui14", theme.faint)
        end
        local aw = AFTER[r.after] or { r.heat, theme.dim }
        kit.text(x + w - PAD, ty + 3, aw[1], "ui14", aw[2], { pivot = gui.PIVOT_NE })
        kit.text(x + PAD + 26, ty + 24, r.line or "", "ui14", TONE[r.tone] or theme.dim, { w = iw - 26, lines = 2 })
        if r.fix then
            kit.text(x + PAD + 26, ty + 24 + lh, r.fix, "ui14", theme.teal, { w = iw - 26, lines = 2 })
        end
        local d = require("game.model.storylines").def(app.campaign, r.id)
        local extra = r.kind == "backstory" and ("\n\nIt moves with the cards that carry " .. r.name .. "'s face.") or ""
        gloss.card_spot(x + 4, ty - 2, w - 8, 24 + lh + fh + 4, r.name .. (r.who and ("  (" .. r.who .. ")") or ""),
            (r.line or "") .. (r.fix and ("\n" .. r.fix) or "") .. ((d and d.about) and ("\n\n" .. d.about) or "") .. extra
            .. "\n\n" .. HEAT_EXPLAIN)
        ty = ty + 24 + lh + fh + 10
        shown = shown + 1
    end
    if shown < #rows then
        kit.text(x + PAD, bottom - LH, "+" .. util.int(#rows - shown) .. " more in the Story log (S on the prep board)",
            "ui14", theme.faint)
    end
    if wait_text then
        local wy = y + h - 12 - lines_h(wait_text, iw, 3)
        kit.box(x + PAD, wy - 8, iw, 1, theme.panel3, { round = false })
        kit.text(x + PAD, wy, wait_text, "ui14", theme.faint, { w = iw, lines = 3 })
        local fixes = {}
        for _, r in ipairs(waiting) do
            if r.fix then
                table.insert(fixes, r.name .. ": " .. string.gsub(r.fix, "^In your hand: ", ""))
            end
        end
        gloss.card_spot(x + 4, wy - 2, w - 8, lines_h(wait_text, iw, 3) + 4, "Stories not started yet",
            wait_text .. (#fixes > 0 and ("\n\nIn your hand now:\n" .. table.concat(fixes, "\n")) or ""))
    end
end

-- The clue next session hangs on, and what changes with it.
local function next_box(app, view, x, y, w, h)
    panel(x, y, w, h)
    local iw = w - 2 * PAD
    local n = view.next
    label(x + PAD, y + 10, "NEXT SESSION")
    local ty = y + 34
    local function say(text, color, max, font)
        font = font or "ui14"
        kit.text(x + PAD, ty, text, font, color, { w = iw, lines = max or 3 })
        ty = ty + math.min(kit.text_height(text, font, iw), (max or 3) * kit.line_height(font)) + 6
    end
    if not n then
        if view.story_over then
            say("The bells' story has been told.", theme.text, 2, "ui18b")
            say("What happens next grows from the storylines on the right, and the cards they put in your hand.", theme.dim, 4)
        else
            say("Tonight is the last session of this story.", theme.text, 2, "ui18b")
            say("However it ends, it ends tonight: every clue on the board is the last chance to find it.", theme.dim, 4)
        end
        return
    end
    say("Session " .. util.int(n.week) .. ": " .. n.title, theme.text, 1, "ui18b")
    if not n.clue then
        if n.plain then
            say("The party sets out to " .. util.lower_first(n.plain), theme.dim, 4)
        end
        return
    end
    if n.found then
        say("They already know what it hangs on (" .. lore_screen.card_words(n.clue) .. "), so they'll set out to "
            .. util.lower_first(n.with or n.without or ""), theme.green, 4)
        return
    end
    say("It hangs on one clue: " .. lore_screen.card_words(n.clue) .. ".", theme.gold, 2)
    if n.at then
        say("It's on tonight's board, in scene " .. util.int(n.at) .. ".", theme.text, 2)
    elseif n.goal_slot then
        say("It isn't on tonight's board, but an empty goal slot's improv hand offers \"" .. n.goal_slot
            .. "\", which finds it.", theme.text, 3)
    else
        local how = n.in_hand and "It's in your hand: back to prep to put it on a scene" or "It isn't in your hand yet"
        if n.in_hand and n.where then
            how = how .. " at " .. util.join_names(n.where)
        end
        say(how .. ". Without it, they go without the clue.", theme.orange, 3)
    end
    if n.with then
        say("Found: " .. n.with, theme.green, 3)
    end
    if n.without then
        -- A goal card's clue is found won or lost: it's only missed if its scene never plays (the
        -- card-led playtest, October 16: "found either way, so how can it be missed?").
        local cc = content.components[n.clue]
        if n.at and cc and cc.kind == "goal" then
            say("Only if scene " .. util.int(n.at) .. " doesn't play: " .. util.lower_first(n.without), theme.orange, 3)
        else
            say("If they miss it: " .. util.lower_first(n.without), theme.orange, 3)
        end
    end
end

-- The fronts and the villains at large: for the DM's eyes only.
local function behind_box(app, view, x, y, w, h)
    panel(x, y, w, h)
    local iw = w - 2 * PAD
    label(x + PAD, y + 10, "BEHIND THE SCREEN", theme.orange)
    kit.text(x + w - PAD, y + 10, "only you know", "ui14", theme.faint, { pivot = gui.PIVOT_NE })
    local ty = y + 34
    local bottom = y + h - 10
    local HOLD = kit.rgba("#c2a8f0")
    for _, f in ipairs(view.fronts) do
        local th = lines_h(f.text, iw - 24, 4)
        local hh = f.hold and lines_h(f.hold, iw - 24, 2) or 0
        if ty + 20 + th > bottom then
            break
        end
        local top = ty
        kit.icon(x + PAD, ty + 1, 16, f.icon, kit.rgba(f.color))
        local steps = (f.steps and f.steps > 0 and not f.doom)
            and ("plan: " .. util.int(f.done or 0) .. " of " .. util.int(f.steps) .. " steps done") or nil
        local sw = steps and (kit.width(steps, "ui14") + 12) or 0
        kit.text(x + PAD + 24, ty, kit.ellipsize(f.name, "ui14", iw - 24 - sw), "ui14", theme.text)
        if steps then
            kit.text(x + w - PAD, ty, steps, "ui14", theme.faint, { pivot = gui.PIVOT_NE })
        end
        ty = ty + 20
        kit.text(x + PAD + 24, ty, f.text, "ui14", theme.dim, { w = iw - 24, lines = 4 })
        local full = f.text
        ty = ty + th + 2
        if f.hold and ty + hh <= bottom then
            kit.text(x + PAD + 24, ty, f.hold, "ui14", HOLD, { w = iw - 24, lines = 2 })
            full = full .. "\n\n" .. f.hold
            ty = ty + hh
        end
        gloss.card_spot(x + 4, top - 2, w - 8, ty - top + 4, f.name, full .. (f.more and ("\n\n" .. f.more) or ""))
        ty = ty + 8
    end
end

-- Calls with lasting effects that could come up tonight.
local function calls_box(app, view, x, y, w, h)
    panel(x, y, w, h)
    local iw = w - 2 * PAD
    label(x + PAD, y + 10, "CALLS YOU MAY FACE TONIGHT")
    local ty = y + 34
    local bottom = y + h - 10
    if #view.calls == 0 then
        kit.text(x + PAD, ty, "Nothing with lasting effects is set up. The night's calls are yours to enjoy.", "ui14", theme.faint,
            { w = iw })
        return
    end
    for _, k in ipairs(view.calls) do
        local th = lines_h(k.text, iw - 18, 3)
        if ty + th > bottom then
            break
        end
        kit.dot(x + PAD + 5, ty + 10, 7, TONE[k.tone] or theme.dim)
        kit.text(x + PAD + 18, ty, k.text, "ui14", TONE[k.tone] or theme.text, { w = iw - 18, lines = 3 })
        gloss.card_spot(x + 4, ty - 2, w - 8, th + 4, "A call you may face", k.text .. (k.more and ("\n\n" .. k.more) or ""))
        ty = ty + th + 8
    end
end

function M.build(app)
    local c = app.campaign
    local view = lore_screen.build(c, c.prep)
    app.lore_view = view
    kit.box(0, 0, kit.W, kit.H, theme.bg, { round = false })
    kit.gloss_scope({ story = true, table = true, report = true }, function()
        -- What this page is.
        kit.text(24, 10, "SESSION " .. util.int(view.week) .. (view.title and (": \"" .. view.title .. "\"") or ""), "ui14", theme.gold)
        kit.text(24, 30, "What tonight can change in the story", "title30", theme.text)
        kit.text(24, 74, "Only you see this. Tonight's board, the stories it moves, and what each scene's outcome "
            .. "will mean next session. Not what you want? Go back and change the board.", "ui14", theme.dim, { w = 1100 })
        if view.objective then
            local ox, ow = RIGHT_X, RIGHT_W
            marks.storyline(app, content.lore.briefing.next_story, ox, 14, 18)
            kit.text(ox + 26, 12, "THIS WEEK THEY'RE OUT TO", "ui14", theme.gold)
            kit.text(ox + 26, 34, view.objective, "ui18b", theme.text, { w = ow - 26, lines = 3 })
        end
        for k, sv in ipairs(view.scenes) do
            scene_column(app, sv, SCENE_X + (k - 1) * (SCENE_W + SCENE_GAP), TOP_Y, SCENE_W, MID_Y - TOP_Y - 12)
        end
        storylines_column(app, view, RIGHT_X, TOP_Y, RIGHT_W, BOT_Y - TOP_Y)
        next_box(app, view, SCENE_X, MID_Y, SCENE_W, BOT_Y - MID_Y)
        behind_box(app, view, SCENE_X + SCENE_W + SCENE_GAP, MID_Y, SCENE_W, BOT_Y - MID_Y)
        calls_box(app, view, SCENE_X + 2 * (SCENE_W + SCENE_GAP), MID_Y, SCENE_W, BOT_Y - MID_Y)
    end)
    kit.button(24, 840, 200, 44, "<  Back to prep", function()
        M.back(app)
    end, { font = "ui18b", key = "lore_back" })
    kit.text(236, 852, "Esc", "ui14", theme.faint)
    -- The key to the marks (the lore playtest: "no legend for the icons").
    local kx = 290
    for _, kind in ipairs(KEY_ORDER) do
        local k = KIND[kind]
        local kw = 20 + kit.width(k.key, "ui14") + 18
        if kx + kw > 1220 then
            break
        end
        kit.icon(kx, 853, 16, k.icon, k.color)
        kit.text(kx + 20, 852, k.key, "ui14", theme.dim)
        kx = kx + kw
    end
    kit.button(1356, 836, 220, 50, "Start game night  >", function()
        M.go(app)
    end, { color = theme.go, hover = theme.go_hover, font = "ui22b", key = "lore_go" })
    kit.text(1340, 852, "or press Enter", "ui14", theme.faint, { pivot = gui.PIVOT_NE })
end

function M.go(app)
    app.go("night", { lore_seen = true })
end

function M.back(app)
    app.go("prep", { resume = true, from_lore = true })
end

return M
