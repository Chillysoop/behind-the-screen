-- The guided campaign: the room is the stage; the paper is only what needs a call.
-- No campaign meters or legacy prep widgets are created by this view.
local kit = require "game.ui.kit"
local theme = require "game.ui.theme"

local M = {}
local C = {
    paper = kit.rgba("#f3e8d1", 0.98), ink = kit.rgba("#30251e"), muted = kit.rgba("#685545"),
    dark = kit.rgba("#211a17", 0.96), card = kit.rgba("#fff7e5"),
    card_hover = kit.rgba("#f3dca9"), accent = kit.rgba("#bb853d"),
    teal = kit.rgba("#244b49"), light = kit.rgba("#f9eed9"),
}
local COLOR = {
    mara = kit.rgba("#cca85b"), dev = kit.rgba("#718fc2"),
    jess = kit.rgba("#74b6a0"), sam = kit.rgba("#ce8b7b"),
}
local FACES = { lean = true, arms = true, yawn = true, phone = true, cheer = true, gasp = true, laugh = true, think = true }
local FRIENDS = {
    { key = "mara", name = "Mara", char = "Thessaly", class_name = "Wizard", level = 2 },
    { key = "dev", name = "Dev", char = "Brannoc", class_name = "Fighter", level = 2 },
    { key = "jess", name = "Jess", char = "Pip", class_name = "Rogue", level = 2 },
    { key = "sam", name = "Sam", char = "Oswin", class_name = "Cleric", level = 2 },
}

local function str(v)
    return type(v) == "string" and v or ""
end

local function short(s, n)
    s = str(s):gsub("\n", " ")
    if #s <= n then return s end
    local cut = s:sub(1, n):match("^(.*)%s") or s:sub(1, n)
    return cut .. "..."
end

local function face(key, pose)
    return "face_" .. key .. ((pose and FACES[pose]) and ("_" .. pose) or "")
end

local function text(x, y, s, font, color, w)
    return kit.text(x, y, str(s), font, color, { w = w, gloss = false })
end

local function button(x, y, w, h, label, fn, key, opts)
    opts = opts or {}
    opts.key = key
    opts.color = opts.color or C.teal
    opts.hover = opts.hover or kit.rgba("#376460")
    opts.text_color = opts.text_color or C.light
    return kit.button(x, y, w, h, label, fn, opts)
end

local function header(app, snap)
    kit.box(0, 0, kit.W, 82, C.dark, { round = false })
    kit.box(0, 81, kit.W, 1, kit.rgba("#b58b52", 0.5), { round = false })
    text(30, 12, "Behind the Screen", "title30", C.light, 370)
    text(32, 52, "THE SILENT BELLS  /  A GUIDED CAMPAIGN", "ui14", theme.gold, 520)
    if snap then
        text(630, 20, "SESSION " .. tostring(snap.episode or 1) .. " OF 4", "ui14", theme.gold, 260)
        text(630, 43, str(snap.progress), "ui18", C.light, 470)
    end
    if not app.title then
        button(1200, 22, 164, 38, "Our story", app.open_scrapbook, "guided_story", { color = theme.panel2 })
        button(1380, 22, 188, 38, "Pause / menu", app.show_menu, "guided_menu", { color = theme.panel2 })
    end
end

local function footer(app, snap)
    local party = snap and snap.party or FRIENDS
    local w, gap, x = 373, 15, 32
    app.portraits = {}
    for i, p in ipairs(party) do
        if i > 4 then break end
        local key = p.key or FRIENDS[i].key
        local pose = (app.poses or {})[key]
        local y = 810
        kit.box(x, y, w, 70, C.dark, { radius = 9 })
        kit.box(x, y, 4, 70, COLOR[key] or theme.gold, { round = false })
        kit.picture(x + 12, y + 9, 52, 52, face(key, pose))
        text(x + 76, y + 9, p.name or FRIENDS[i].name, "ui18b", C.light, 170)
        local cls = p.class_name or p.class or FRIENDS[i].class_name
        text(x + 76, y + 35, (p.char or FRIENDS[i].char) .. "  /  " .. cls .. " " .. tostring(p.level or 2),
            "ui14", theme.dim, w - 90)
        if snap and snap.focus == key then
            text(x + w - 110, y + 12, "SPOTLIGHT", "ui14", theme.gold, 108)
        end
        app.portraits[key] = { x = x, y = y }
        x = x + w + gap
    end
end

local function episode_note(app, snap, panel_y)
    if panel_y < 370 then return end
    local body = snap.recap
    if not body or body == "" then
        body = "Four friends around your table. A prepared adventure, with room for your own ideas."
    end
    local y, w = 108, 296
    kit.box(28, y, w, 190, C.dark, { radius = 10 })
    text(47, y + 16, snap.phase == "prep_focus" and "THE STORY SO FAR" or "AT YOUR TABLE", "ui14", theme.gold, w - 38)
    text(47, y + 47, short(body, 205), "ui18", C.light, w - 38)
end

local function reaction(app, snap, panel_y)
    local r = app.reaction or (snap.reactions and snap.reactions[1])
    if not r or not r.text or panel_y < 330 then return end
    local key = r.key or "mara"
    local name = key:sub(1, 1):upper() .. key:sub(2)
    for _, p in ipairs(snap.party or FRIENDS) do
        if p.key == key then name = p.name end
    end
    local w, x, y = 326, 1244, 108
    local h = 68 + kit.text_height(r.text, "ui18", w - 34)
    kit.box(x, y, w, h, C.paper, { radius = 12 })
    kit.picture(x + 16, y + 10, 42, 42, face(key, r.pose or (app.poses or {})[key]))
    text(x + 71, y + 19, name .. " says", "ui18b", C.ink, w - 90)
    text(x + 17, y + 60, r.text, "ui18", C.ink, w - 34)
end

local function title(app)
    header(app)
    local x, y, w = 60, 154, 620
    kit.box(x + 9, y + 10, w, 565, kit.rgba("#000000", 0.24), { radius = 14 })
    kit.box(x, y, w, 565, C.paper, { radius = 14 })
    text(x + 34, y + 28, "A SEAT BEHIND THE SCREEN", "ui14", C.teal, w - 68)
    text(x + 34, y + 66, "Make Thursday\nunforgettable.", "title30", C.ink, w - 68)
    text(x + 34, y + 164,
        "Your friends bring the heroes. You bring the surprises. Guide a four-session adventure through a town whose bells have fallen silent.",
        "story22", C.ink, w - 68)
    text(x + 34, y + 287,
        "Choose a friend to spotlight and one signature twist. Then run the table, make a few memorable calls, and see what your friends do with them.",
        "ui18", C.muted, w - 68)
    local resume = app.resume and app.resume.snapshot
    if resume then
        button(x + 34, y + 398, w - 68, 58, "Continue session " .. tostring(resume.episode or 1), app.continue_game,
            "guided_resume", { font = "ui22b" })
        button(x + 34, y + 469, w - 68, 42, "Begin a new campaign", app.start_new, "guided_start", { color = theme.panel2 })
    else
        button(x + 34, y + 398, w - 68, 62, "Pull up a chair", app.start_new, "guided_start", { font = "ui22b" })
        text(x + 34, y + 484, app.resume_error and "We couldn't read the saved journey. You can begin a new campaign."
            or "No D&D experience needed. Your progress saves as you play.", "ui18", C.muted, w - 68)
    end
    footer(app)
end

local function choice_layout(snap)
    local cards = snap.cards or {}
    local n = math.max(1, #cards)
    local gap, available = 16, 1480
    local cw = (available - gap * (n - 1)) / n
    local ch = 120
    for _, c in ipairs(cards) do
        local th = kit.text_height(c.title or c.label or "Choose", "ui22b", cw - 65)
        local bh = kit.text_height(c.body or c.text or "", "ui18", cw - 40)
        ch = math.max(ch, 26 + th + 12 + bh + 24 + (c.tag and 20 or 0))
    end
    local title_h = kit.text_height(snap.title or "Your call", "title30", 1460)
    local body_h = kit.text_height(snap.text or "", "ui18", 1460)
    local roll_h = snap.roll and 40 or 0
    local h = 30 + 23 + title_h + 14 + body_h + roll_h + 22 + ch + 24
    return math.max(180, 793 - h), cw, ch, title_h, body_h, roll_h
end

local function choices(app, snap)
    local py, cw, ch, th, bh, rh = choice_layout(snap)
    episode_note(app, snap, py)
    reaction(app, snap, py)
    kit.box(32, py + 7, 1536, 793 - py, kit.rgba("#000000", 0.24), { radius = 13 })
    kit.box(28, py, 1544, 793 - py, C.paper, { radius = 13 })
    text(60, py + 22, snap.kicker or "YOUR CALL", "ui14", C.teal, 1380)
    text(60, py + 48, snap.title or "Your call", "title30", C.ink, 1460)
    text(60, py + 48 + th + 14, snap.text or "", "ui18", C.ink, 1460)
    if snap.roll then
        local r = snap.roll
        local mod = tonumber(r.modifier or r.mod) or 0
        local value = tonumber(r.d20 or r.value) or 0
        local sum = tostring(value) .. (mod < 0 and " - " or " + ") .. tostring(math.abs(mod))
            .. " = " .. tostring(r.total or value + mod)
        local line = (r.label or "The roll") .. ": " .. sum .. " against DC " .. tostring(r.dc or "?")
            .. (r.success and "  /  Success" or "  /  A miss")
        local ry = py + 48 + th + 14 + bh + 10
        kit.box(60, ry, 1480, 33, kit.rgba("#ddcfae"), { radius = 6 })
        text(72, ry + 5, line, "ui18b", C.ink, 1456)
    end
    local cy, x = py + 48 + th + 14 + bh + rh + 22, 60
    for i, c in ipairs(snap.cards or {}) do
        local card = c
        local active = app.focus_i == i
        if active and not c.disabled then
            kit.box(x - 3, cy - 3, cw + 6, ch + 6, C.accent, { radius = 10 })
        end
        button(x, cy, cw, ch, "", function() app.choose(card.id) end, "guided_choice_" .. tostring(c.id), {
            color = C.card, hover = C.card_hover, enabled = not c.disabled, radius = 8,
        })
        local ink = c.disabled and C.muted or C.ink
        kit.dot(x + cw - 24, cy + 24, 27, c.disabled and theme.paper_dim or C.teal)
        kit.text(x + cw - 24, cy + 24, tostring(i), "ui14", C.light, { pivot = gui.PIVOT_CENTER })
        local title_h = kit.text_height(c.title or c.label or "Choose", "ui22b", cw - 65)
        text(x + 20, cy + 17, c.title or c.label or "Choose", "ui22b", ink, cw - 65)
        text(x + 20, cy + 21 + title_h + 10, c.body or c.text or "", "ui18", ink, cw - 40)
        if c.tag then text(x + 20, cy + ch - 28, c.tag, "ui14", C.teal, cw - 40) end
        x = x + cw + 16
    end
    app.panel_y = py
end

local function roll_card(snap, x, y, w)
    local r = snap.roll
    if not r then return 0 end
    local modifier = tonumber(r.modifier or r.mod) or 0
    local value = tonumber(r.d20 or r.value) or 0
    local total = tonumber(r.total) or value + modifier
    local sum = tostring(value) .. (modifier < 0 and " - " or " + ") .. tostring(math.abs(modifier)) .. " = " .. tostring(total)
    kit.box(x, y, w, 76, C.teal, { radius = 9 })
    text(x + 18, y + 12, (r.label or "The dice decide") .. "  /  DC " .. tostring(r.dc or "?"), "ui14", C.light, w - 36)
    text(x + 18, y + 34, sum .. (r.success and "   Success" or "   A setback"), "ui22b", C.light, w - 36)
    return 94
end

local function result(app, snap)
    if app.playback then
        local y = 654
        kit.box(270, y, 1060, 136, C.dark, { radius = 12 })
        text(292, y + 14, "THE FIGHT PLAYS OUT", "ui14", theme.gold, 700)
        text(292, y + 42, app.playback.caption or "The party takes their places.", "ui22b", C.light, 800)
        button(1110, y + 35, 196, 52, "See the result", app.finish_replay, "guided_continue")
        text(292, y + 104, "Space: next moment  /  F: faster  /  Enter: see the result", "ui14", theme.dim, 950)
        app.panel_y = y
        return
    end
    local milestone = type(snap.milestone) == "table" and (snap.milestone.text or snap.milestone.title or "") or snap.milestone
    -- The aftermath narration may already include the automatic level-up.
    if milestone and (snap.text or ""):find(milestone, 1, true) then milestone = nil end
    local body_h = kit.text_height(snap.text or "", "story22", 1100)
    local title_h = kit.text_height(snap.title or "A moment to remember", "title30", 1390)
    local roll_h = snap.roll and 94 or 0
    local extra = milestone and 44 or 0
    local h = 110 + title_h + body_h + roll_h + extra + 86
    local py = math.max(225, 793 - h)
    episode_note(app, snap, py)
    reaction(app, snap, py)
    kit.box(100, py, 1400, 793 - py, C.paper, { radius = 14 })
    text(134, py + 24, snap.kicker or "THE TABLE RESPONDS", "ui14", C.teal, 1300)
    text(134, py + 54, snap.title or "A moment to remember", "title30", C.ink, 1300)
    local y = py + 64 + title_h
    y = y + roll_card(snap, 134, y, 1332)
    text(134, y + 8, snap.text or "", "story22", C.ink, 1100)
    if milestone then
        text(134, y + body_h + 22, milestone, "ui18b", C.teal, 1260)
    end
    button(1110, 718, 356, 54, snap.continue_label or "Continue the story", app.advance, "guided_continue")
    text(134, 737, "Your call is now part of the story.", "ui14", C.muted, 910)
    app.panel_y = py
end

local function scrapbook(app, snap, modal)
    if modal then
        kit.layer("guided_scrapbook", true)
        kit.box(0, 82, kit.W, kit.H - 82, kit.rgba("#100c0a", 0.76), { round = false })
    end
    local x, y, w, h = 118, 108, 1364, 680
    kit.box(x, y, w, h, C.paper, { radius = 14 })
    text(x + 30, y + 22, "OUR CAMPAIGN SCRAPBOOK", "ui14", C.teal, w - 60)
    text(x + 30, y + 51, snap.phase == "complete" and (snap.title or "The story we made together") or "The nights we remember", "title30", C.ink, w - 60)
    local history = snap.history or {}
    local ending_h = 0
    if not modal and snap.text and snap.text ~= "" then
        ending_h = kit.text_height(snap.text, "ui18", w - 60) + 22
        text(x + 30, y + 105, snap.text, "ui18", C.ink, w - 60)
    end
    local pages = math.max(1, math.ceil(#history / 2))
    app.history_page = math.max(1, math.min(app.history_page or pages, pages))
    local first = (app.history_page - 1) * 2 + 1
    if #history == 0 then
        text(x + 30, y + 132, "Your first Thursday is still ahead. The moments your table makes will live here.", "story22", C.muted, w - 60)
    end
    for j = 0, 1 do
        local entry = history[first + j]
        if entry then
            local cx, cy, cw = x + 30 + j * 660, y + 108 + ending_h, 644
            local ch = math.min(350, y + h - 124 - cy)
            kit.box(cx, cy, cw, ch, C.card, { radius = 9 })
            text(cx + 20, cy + 14, "SESSION " .. tostring(entry.episode or first + j), "ui14", C.teal, cw - 40)
            text(cx + 20, cy + 42, entry.title or "A night at the table", "ui22b", C.ink, cw - 40)
            local body = entry.text or entry.summary or ""
            local font = kit.text_height(body, "ui18", cw - 40) <= ch - 96 and "ui18" or "ui14"
            text(cx + 20, cy + 80, body, font, C.ink, cw - 40)
        end
    end
    if not modal and snap.keepsakes and #snap.keepsakes > 0 then
        local names = {}
        for _, k in ipairs(snap.keepsakes) do names[#names + 1] = type(k) == "table" and (k.name or k.title or "A gift") or tostring(k) end
        text(x + 30, y + h - 111, "By your screen: " .. table.concat(names, " / "), "ui14", C.muted, w - 60)
    end
    if pages > 1 then
        button(x + 30, y + h - 72, 136, 42, "Previous", function() app.history_page = math.max(1, app.history_page - 1); app.redraw() end,
            "guided_history_previous", { enabled = app.history_page > 1, color = theme.panel2 })
        button(x + 180, y + h - 72, 136, 42, "Next", function() app.history_page = math.min(pages, app.history_page + 1); app.redraw() end,
            "guided_history_next", { enabled = app.history_page < pages, color = theme.panel2 })
    end
    if modal then
        button(x + w - 250, y + h - 72, 220, 44, "Back to the table", app.close_overlay, "guided_close_story")
    else
        button(x + w - 342, y + h - 72, 312, 50, "Another campaign", app.start_new, "guided_start")
    end
end

local function overlay(app)
    if not app.overlay then return end
    if app.overlay == "story" then return scrapbook(app, app.snap, true) end
    kit.layer("guided_overlay", true)
    kit.box(0, 0, kit.W, kit.H, kit.rgba("#120d0b", 0.72), { round = false })
    local x, y, w = 480, 253, 640
    kit.box(x, y, w, 360, C.paper, { radius = 14 })
    if app.overlay == "reset" then
        text(x + 30, y + 26, "Begin a new campaign?", "title30", C.ink, w - 60)
        text(x + 30, y + 86, "Your current journey will be replaced. Your friends will start again at the Crooked Kettle.", "story22", C.ink, w - 60)
        button(x + 30, y + 218, w - 60, 54, "Keep playing this campaign", app.close_overlay, "guided_cancel_reset")
        button(x + 30, y + 288, w - 60, 44, "Yes, begin again", app.confirm_new, "guided_confirm_reset", { color = theme.panel2 })
    else
        text(x + 30, y + 26, "A moment away from the table", "title30", C.ink, w - 60)
        text(x + 30, y + 82, app.save_error and "Your progress has not saved yet. Try saving again before you leave." or "Your place in the story is saved. Take your time.",
            "ui18", C.muted, w - 60)
        button(x + 30, y + 152, w - 60, 54, "Back to the table", app.close_overlay, "guided_unpause")
        button(x + 30, y + 220, w - 60, 44, "Return to title", app.return_title, "guided_title", { color = theme.panel2 })
        button(x + 30, y + 278, w - 60, 44, "Begin a new campaign", app.start_new, "guided_start", { color = theme.panel2 })
    end
end

function M.render(app)
    kit.clear_all()
    kit.reset_hover()
    kit.gloss_tags = nil
    kit.layer("guided")
    if app.title then
        title(app)
    else
        local snap = app.snap
        header(app, snap)
        if snap.phase == "complete" then
            scrapbook(app, snap, false)
        elseif #(snap.cards or {}) > 0 then
            choices(app, snap)
        else
            result(app, snap)
        end
        footer(app, snap)
        kit.box(0, 881, kit.W, 19, C.dark, { round = false })
        text(48, 882, "1-4: choose  /  Enter: continue  /  Esc: pause  /  M: music", "ui14", C.light, 1050)
    end
    overlay(app)
    if app.save_error then
        kit.layer("guided_save_warning", true)
        kit.box(330, 86, 940, 52, kit.rgba("#592e20", 0.98), { radius = 9 })
        text(348, 100, "Your progress could not be saved. Keep the game open and try again.", "ui18", C.light, 720)
        button(1092, 94, 160, 36, "Save again", app.retry_save, "guided_retry_save")
    end
    if app.error then
        kit.layer("guided_error", true)
        kit.box(370, 280, 860, 280, C.paper, { radius = 12 })
        text(402, 310, "We couldn't turn the page.", "title30", C.ink, 796)
        text(402, 370, "Return to the title to reopen your last saved moment.", "story22", C.ink, 796)
        button(402, 466, 796, 52, "Return to title", app.recover_title, "guided_recover")
    end
end

return M
