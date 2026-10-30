-- The Museum of Nightmares (v2) through the real UI, against the mock GUI from gui_smoke.lua: the
-- prototype notice, Session Zero, the heroes' hooks, every week's between-session questions and
-- prep board, game night, the report, level-ups, boss night, and the journey recap.
-- Run from the project root:  lua tools/tests/museum_smoke.lua [seed]   (DUMP_DIR=out to dump screens)

package.path = "./?.lua;" .. package.path
unpack = unpack or table.unpack

local SEED = tonumber(arg and arg[1]) or 1
-- Seeds 1 to 4 play a full table; 5 and 6 start small (October 15) and skip the checks that need
-- a particular player there from the start (Jess's spotlight conflict in week 2, say).
local FULL = SEED < 5
-- The game seeds a new campaign from the clock: pin it, so a run is repeatable by its seed.
do
    local real_time = os.time
    os.time = function(t)
        if t then
            return real_time(t)
        end
        return 1700000000 + SEED
    end
end
local WEEKS = 8
local H = 900

-- Fonts and textures declared in game.gui
local gui_file = io.open("game/game.gui"):read("*a")
local FONTS, TEXTURES, MAX_NODES = {}, {}, tonumber(string.match(gui_file, "max_nodes: (%d+)")) or 512
for name in string.gmatch(gui_file, 'fonts {%s*name: "([^"]+)"') do FONTS[name] = true end
for name in string.gmatch(gui_file, 'textures {%s*name: "([^"]+)"') do TEXTURES[name] = true end
local ATLAS = {}
for img in string.gmatch(io.open("assets/ui/ui.atlas"):read("*a"), '/assets/ui/([%w_]+)%.png') do ATLAS[img] = true end
for img in string.gmatch(io.open("assets/portraits/portraits.atlas"):read("*a"), '/assets/portraits/([%w_]+)%.png') do ATLAS[img] = true end

local problems = {}
local function problem(msg)
    if #problems < 30 then table.insert(problems, msg .. "\n" .. debug.traceback("", 2)) end
end

-- vmath ---------------------------------------------------------------------
vmath = {}
local V = {}
V.__index = V
function vmath.vector3(x, y, z)
    if type(x) == "table" then return setmetatable({ x = x.x, y = x.y, z = x.z }, V) end
    return setmetatable({ x = x or 0, y = y or 0, z = z or 0 }, V)
end
function vmath.vector4(x, y, z, w) return setmetatable({ x = x or 0, y = y or 0, z = z or 0, w = w or 0 }, V) end
local function num(v, where) if type(v) ~= "number" or v ~= v then problem("bad number at " .. where .. ": " .. tostring(v)) end end

-- gui -------------------------------------------------------------------------
gui = {
    PIVOT_CENTER = "c", PIVOT_N = "n", PIVOT_NE = "ne", PIVOT_E = "e", PIVOT_SE = "se", PIVOT_S = "s",
    PIVOT_SW = "sw", PIVOT_W = "w", PIVOT_NW = "nw",
    ADJUST_FIT = 0, ADJUST_ZOOM = 1, ADJUST_STRETCH = 2,
    ANCHOR_NONE = 0, ANCHOR_LEFT = 1, ANCHOR_RIGHT = 2, ANCHOR_TOP = 3, ANCHOR_BOTTOM = 4,
    EASING_INOUTSINE = 0, EASING_OUTBACK = 1, EASING_LINEAR = 2, EASING_OUTCUBIC = 3,
}
local alive, alive_count = {}, 0
local order = {}
local function new_node(kind, pos, size)
    num(pos.x, "pos.x"); num(pos.y, "pos.y")
    local n = { kind = kind, pos = pos, size = size or vmath.vector3(0, 0, 0), pivot = "c", enabled = true, alive = true }
    alive[n] = true
    table.insert(order, n)
    alive_count = alive_count + 1
    if alive_count > MAX_NODES then problem("too many nodes: " .. alive_count) end
    return n
end
local function chk(n, fn)
    if type(n) ~= "table" or not n.kind then problem(fn .. " on a non-node"); return false end
    if not n.alive then problem(fn .. " on a deleted node (" .. tostring(n.text or n.kind) .. ")"); return false end
    return true
end
function gui.new_box_node(pos, size) num(size.x, "size.x"); num(size.y, "size.y"); return new_node("box", pos, size) end
function gui.new_text_node(pos, text)
    if type(text) ~= "string" then problem("text node with " .. type(text)) end
    if string.find(text or "", "[\128-\255]") then problem("non-ASCII text: " .. text) end
    -- The review queue shows lines as written, {placeholders} and all.
    local reviewing = REVIEW_APP and REVIEW_APP.review and REVIEW_APP.review.queue_open
    if string.find(text or "", "{[%w_]+}") and not reviewing then problem("unfilled placeholder: " .. text) end
    local n = new_node("text", pos)
    n.text = text
    return n
end
function gui.delete_node(n) if chk(n, "delete_node") then n.alive = false; alive[n] = nil; alive_count = alive_count - 1 end end
function gui.set_pivot(n, p) if chk(n, "set_pivot") then n.pivot = p end end
function gui.set_color(n, c) if chk(n, "set_color") then if type(c) ~= "table" or c.w == nil then problem("set_color needs vector4") end; n.color = c end end
function gui.set_texture(n, t) if chk(n, "set_texture") then if not TEXTURES[t] then problem("unknown texture " .. tostring(t)) end end end
function gui.play_flipbook(n, a) if chk(n, "play_flipbook") then if not ATLAS[a] then problem("unknown atlas image " .. tostring(a)) end; n.image = a end end
function gui.set_slice9(n, v) if chk(n, "set_slice9") then n.slice = v.x end end
function gui.set_font(n, f) if chk(n, "set_font") then if not FONTS[f] then problem("unknown font " .. tostring(f)) end; n.font = f end end
function gui.set_outline(n) chk(n, "set_outline") end
function gui.set_shadow(n) chk(n, "set_shadow") end
function gui.set_line_break(n) chk(n, "set_line_break") end
function gui.set_size(n, s) if chk(n, "set_size") then num(s.x, "set_size.x"); n.size = s end end
function gui.get_size(n) if chk(n, "get_size") then return n.size end return vmath.vector3() end
function gui.set_scale(n) chk(n, "set_scale") end
function gui.set_position(n, p)
    if chk(n, "set_position") then num(p.x, "set_position.x"); num(p.y, "set_position.y"); n.pos = vmath.vector3(p) end
end
function gui.get_position(n) if chk(n, "get_position") then return vmath.vector3(n.pos) end return vmath.vector3() end
function gui.set_text(n, t)
    if chk(n, "set_text") then
        if type(t) ~= "string" then problem("set_text with " .. type(t)) end
        if string.find(t or "", "[\128-\255]") then problem("non-ASCII text: " .. t) end
        n.text = t
    end
end
function gui.get_text(n) if chk(n, "get_text") then return n.text or "" end return "" end
function gui.set_euler(n, v) chk(n, "set_euler"); num(v.z, "euler.z"); n.euler = v.z end
gui.set_rotation = gui.set_euler
function gui.set_enabled(n, e) if chk(n, "set_enabled") then n.enabled = e end end
function gui.is_enabled(n) if chk(n, "is_enabled") then return n.enabled ~= false end return false end
function gui.set_render_order() end
function gui.set_adjust_mode() end
function gui.cancel_animation() end
function gui.animate(n, prop, to)
    if chk(n, "animate") and prop == "position.x" then n.pos = vmath.vector3(to, n.pos.y, n.pos.z) end
end
function gui.pick_node(n, x, y)
    if not chk(n, "pick_node") then return false end
    local w, h = n.size.x, n.size.y
    local px, py = n.pos.x, n.pos.y
    local left = ({ nw = px, w = px, sw = px, n = px - w / 2, c = px - w / 2, s = px - w / 2, ne = px - w, e = px - w, se = px - w })[n.pivot]
    local top = ({ nw = py, n = py, ne = py, w = py + h / 2, c = py + h / 2, e = py + h / 2, sw = py + h, s = py + h, se = py + h })[n.pivot]
    return x >= left and x <= left + w and y <= top and y >= top - h
end

-- msg, sys, hash ------------------------------------------------------------------
local posted = {}
msg = { post = function(url, id, m) table.insert(posted, { url = url, id = id, m = m or {} }) end }
function hash(s) return s end
local save = os.tmpname()
local other_saves = {}
sys = { get_save_file = function(_, name)
    if name == "playtest_log.jsonl" then return save end
    other_saves[name] = other_saves[name] or os.tmpname()
    return other_saves[name]
end }

-- Load the script ---------------------------------------------------------------
dofile("game/game.gui_script")
local kit = require "game.ui.kit"
local rng = require("game.model.rng").new(SEED)
local content = require "game.model.content"

local self = {}
local ok, err = pcall(init, self)
if not ok then problem("init: " .. tostring(err)) end
local app = self.app
REVIEW_APP = app

local function call(fn, ...)
    local ok2, e = pcall(fn, ...)
    if not ok2 then problem(tostring(e)) end
end

local function center(b)
    local n = b.node
    return n.pos.x + n.size.x / 2, n.pos.y - n.size.y / 2
end

local function buttons()
    local out = {}
    for i = #kit.layers, 1, -1 do
        local l = kit.layers[i]
        for _, b in ipairs(l.buttons) do
            if b.enabled then table.insert(out, b) end
        end
        if l.modal then break end
    end
    return out
end

-- A tip panel swallows clicks: a point on the panel (not on its buttons) must hit nothing.
local function check_tip_absorbs(where)
    local l = app.guide_layer
    local n = l and l.blockers and l.blockers[1]
    if not n then return end
    -- between "Got it" and "Hide tips", where the panel is most likely to sit over something
    local x, y = n.pos.x + n.size.x / 2, n.pos.y - n.size.y + 32
    local b = kit.hit(x, y)
    if b and b.key ~= "guide_ok" and b.key ~= "guide_off" then
        problem("a click on the tip panel went to a hidden button (" .. tostring(b.key or (b.label and b.label.text)) .. ")" .. where)
    end
end

-- What a random click may hit: anything but "Hide tips" (the tips are tested on their own).
local function random_buttons()
    local out = {}
    for _, b in ipairs(buttons()) do
        if b.key ~= "guide_off" then table.insert(out, b) end
    end
    return out
end

local function label_of(b) return b.label and b.label.text or "" end

local function click(b)
    local x, y = center(b)
    call(on_input, self, nil, { x = x, y = y })
    call(on_input, self, "touch", { pressed = true, x = x, y = y })
end

local function click_label(prefix)
    for _, b in ipairs(buttons()) do
        if string.sub(label_of(b), 1, #prefix) == prefix then click(b); return true end
    end
    return false
end

local function key(action) call(on_input, self, action, { pressed = true }) end

-- "Run game night" may ask "are you sure?" (the slice rework): answer it like a player who's done.
local on_lore   -- (set once dump is defined, below)
local function run_night_click()
    if not click_label("Run game night") then return false end
    local app = self.app
    if app.ask then
        for _, b in ipairs(buttons()) do
            if b.key == "ask_yes" then click(b); break end
        end
    end
    -- The lore screen comes between the board and the night (October 16).
    if app.screen == "lore" then
        if on_lore then on_lore(app) end
        local go
        for _, b in ipairs(buttons()) do
            if b.key == "lore_go" then go = b end
        end
        if not go then problem("no way on from the lore screen") return false end
        click(go)
        if app.screen ~= "night" then problem("the lore screen's button didn't start the night (" .. tostring(app.screen) .. ")") end
    end
    return true
end

local finish_talk
local function click_key(k)
    -- A one-on-one left open by random clicks sits over everything: finish it first.
    if self.app.talk and finish_talk and string.sub(k, 1, 5) ~= "talk_" then
        finish_talk()
    end
    for _, b in ipairs(buttons()) do
        if b.key == k then
            -- The Story log panel sits over the table column: close it if it's in the way.
            local x, y = center(b)
            if self.app.story_panel and kit.hit(x, y) ~= b and string.sub(k, 1, 6) ~= "story_" then
                for _, c in ipairs(buttons()) do
                    if c.key == "story_panel_close" then click(c); break end
                end
                for _, c in ipairs(buttons()) do
                    if c.key == k then click(c); return true end
                end
                return false
            end
            click(b)
            return true
        end
    end
    return false
end
-- A one-on-one the random clicks opened (A6): play it through.
finish_talk = function()
    for _ = 1, 8 do
        if not self.app.talk then break end
        local done = false
        for _, b in ipairs(buttons()) do
            if b.key == "talk_opt_1" or b.key == "talk_done" then click(b); done = true; break end
        end
        if not done then break end
    end
end
local function has_key(k)
    for _, b in ipairs(buttons()) do
        if b.key == k then return true end
    end
    return false
end

local function util_contains(list, v)
    for _, x in ipairs(list or {}) do
        if x == v then return true end
    end
    return false
end

-- The prep board's scene card for stop n (the valley map, October 17): close any place's card
-- beside the map, then the stop's tab.
local function show_stop(n)
    if has_key("place_close") then
        click_key("place_close")
    end
    return click_key("stop_" .. n)
end

local DUMP = os.getenv("DUMP_DIR")
-- AUDIT=1: list every piece of text the screens had to cut short.
if os.getenv("AUDIT") then
    kit.audit = {}
    -- Which view line asked for the cut text.
    kit.audit_where = function()
        for lvl = 3, 12 do
            local info = debug.getinfo(lvl, "Sl")
            if not info then break end
            if info.short_src and not info.short_src:find("kit.lua") then
                return (info.short_src:match("([%w_]+)%.lua") or info.short_src) .. ":" .. tostring(info.currentline)
            end
        end
    end
end
local dumped_decision, dumped_improv, dumped_battle, dumped_talk, dumped_docked, dumped_read
local dumped_takeover_talk, dumped_takeover_boss
local function dump(name)
    if not DUMP then return end
    local f = io.open(DUMP .. "/" .. name .. ".txt", "w")
    for _, n in ipairs(order) do
        if n.alive and n.enabled then
            local c = n.color or vmath.vector4(1, 1, 1, 1)
            f:write(table.concat({ n.kind, n.pos.x, n.pos.y, n.size.x, n.size.y, n.pivot, c.x, c.y, c.z, c.w,
                n.font or "-", n.image or "-", n.euler or 0, n.slice or 0 }, "\t"))
            f:write("\t" .. string.gsub(n.text or "", "\n", "\\n") .. "\n")
        end
    end
    f:close()
end

local dumped_once = {}
local function dump_once(name)
    if not dumped_once[name] then
        dumped_once[name] = true
        dump(name)
    end
end

-- A gift from the table waiting on the report: take it, then put it away.
local function take_gift(where)
    local keepsakes = require "game.model.keepsakes"
    if not keepsakes.waiting(app.campaign) then
        return
    end
    click_key("keepsake_" .. ({ "gush", "use", "cool" })[rng:int(1, 3)])
    click_key("keepsake_done")
end

local function leave_report(where)
    take_gift(where)
    if not click_key("next_week") then problem("no next-week button" .. where) return false end
    if app.quick then
        click_key("quick_prep_" .. rng:int(1, 3))
        click_key("quick_watch_" .. rng:int(1, 3))
        if app.quick then click_key("quick_skip") end
        if app.quick then problem("quick questions didn't close" .. where) return false end
    end
    return true
end

local function has_text(fragment)
    for _, n in ipairs(order) do
        if n.alive and n.enabled and n.text and string.find(n.text, fragment, 1, true) then return true end
    end
    return false
end

local adventure = require "game.model.adventure"
local where = ""

-- The old story must never show on a screen.
local function scan(name)
    for _, n in ipairs(order) do
        if n.alive and n.enabled and n.text and adventure.foreign(n.text) then
            problem("old story on " .. name .. ": " .. n.text)
            return
        end
        if n.alive and n.enabled and n.text and string.find(n.text, "{[%w_]+}") then
            problem("unfilled fill-in on " .. name .. ": " .. n.text)
            return
        end
    end
end

-- The notice, then Session Zero.
if not click_key("agree") then problem("no prototype notice") end
dump("0_title")
if not has_text("Museum of Nightmares") then problem("the notice doesn't name the adventure") end
if not click_key("session_zero") then problem("no Session Zero button on the title") end
if app.screen ~= "session_zero" then problem("expected Session Zero, got " .. tostring(app.screen)) end
if not app.campaign.module then problem("a new campaign isn't in the museum") end
dump("1_session_zero")
scan("Session Zero")
click_key("guide_ok")
app.s0.tone = "mixed"
for _, k in ipairs({ "mara", "sam", "dev", "jess" }) do app.s0.asks[k] = "agree" end
for _, rk in ipairs(content.session_zero.rules.order) do
    if not app.s0.rules[rk] then app.s0.rules[rk] = content.session_zero.rules[rk].order[1] end
end
app.refresh()
if not click_key("s0_next") then problem("no way on from Session Zero") end
if not (app.s0 and app.s0.page == "hooks") then problem("the hooks page didn't open") end
dump("2_hooks")
scan("the hooks page")
if click_key("hooks_start") and app.screen ~= "session_zero" then problem("week 1 started with no hooks picked") end
for _, k in ipairs(content.players.order) do
    local hooks = adventure.data.hooks[k]
    if not click_key("hook_" .. k .. "_" .. hooks[rng:int(1, #hooks)].id) then problem("no hook buttons for " .. k) end
end
if not click_key("hooks_start") then problem("no start button on the hooks page") end
if app.screen ~= "prep" then problem("the hooks didn't go on to prep (" .. tostring(app.screen) .. ")") end

local nights, boss_seen, marks_seen = 0, false, 0
for week = 1, WEEKS do
    if app.screen ~= "prep" then break end
    local c = app.campaign
    where = " (week " .. week .. ")"
    -- Between sessions: answer every question.
    local guard = 0
    while #require("game.ui.museum_prep_view").prompts(app) > 0 and guard < 20 do
        guard = guard + 1
        dump_once("3_between_w" .. week)
        scan("between sessions" .. where)
        local pr = require("game.ui.museum_prep_view").prompts(app)[1]
        if pr.kind == "request" then
            if not click_key("req_" .. adventure.data.ANSWERS[rng:int(1, 4)]) then problem("no request answers" .. where) break end
        elseif pr.kind == "loose" then
            if not click_key("loose_" .. rng:int(1, #pr.def.options)) then problem("no loose-end answers" .. where) break end
        elseif pr.kind == "favor" then
            click_key("favor_help_1")
            click_key("favor_hurt_" .. rng:int(1, 2))
            if not click_key("favor_done") then problem("no way to settle a favor" .. where) break end
        end
    end
    dump("4_prep_w" .. week)
    scan("the prep board" .. where)
    -- The notebook, every tab: nothing from the old story in there either.
    if week == 2 or week == 3 then
        local notes_view = require "game.ui.notes_view"
        for _, t in ipairs(notes_view.MUSEUM_TABS) do
            call(app.open_notes, t[1])
            dump_once("4n_notes_" .. t[1] .. "_w" .. week)
            scan("the notebook's " .. t[1] .. " tab" .. where)
        end
        call(app.close_overlay)
    end
    -- The map repository (v2): browse, set a room's map, open a side room, make a map and paint on it.
    if week == 1 then
        if not click_key("open_maps") then problem("no way into the map repository" .. where) end
        if app.overlay ~= "maps" then problem("the map repository didn't open" .. where) end
        dump_once("4m_maps_w" .. week)
        scan("the map repository" .. where)
        local repo = require "game.model.map_repo"
        local entries = repo.entries(c)
        if #entries < 5 then problem("the map repository is nearly empty (" .. #entries .. ")") end
        for _, e in ipairs(entries) do
            if adventure.foreign(e.title) then problem("the old valley in the map repository: " .. e.title) end
        end
        click_key("mr_group_basics")
        click_key("mr_use_room")
        if not click_key("mr_room_chamber") then problem("no room to set a map for") end
        if not repo.room_map(c, "chamber") then problem("setting a room's map didn't stick") end
        click_key("mr_room_chamber")       -- and back to the book's board
        if repo.room_map(c, "chamber") then problem("couldn't put a room's own board back") end
        click_key("mr_side_room")
        if not click_key("mr_room_entrance") then problem("no room to open a side room off") end
        if #repo.side_rooms_off(c, "entrance") ~= 1 then problem("the side room didn't open") end
        if not click_key("mr_new") then problem("no New map button") end
        if app.overlay ~= "mapmaker" then problem("New map didn't open the map maker (" .. tostring(app.overlay) .. ")") end
        dump_once("4m_mapmaker_w" .. week)
        scan("the map maker" .. where)
        click_key("map_piece_pillar")
        local before = 0
        for _, mm in pairs(c.my_maps or {}) do before = before + 1 end
        if before ~= 1 then problem("New map didn't make a map (" .. before .. ")") end
        if not click_key("mr_back") then problem("no way back from the map maker") end
        if not click_key("mr_done") then problem("no Done in the map repository") end
        if app.overlay then problem("the map repository didn't close") end
    end
    if not has_text("UPSTAIRS") and not c.prep.museum.boss then problem("no Euryale card on the board" .. where) end
    if c.prep.museum.boss then
        boss_seen = true
        if not has_text("THE SHOWDOWN") then problem("boss night has no showdown board" .. where) end
        click_key("boss_opener_" .. (rng:chance(0.5) and "talk" or "ambush"))
        click_key("boss_style_" .. (rng:chance(0.5) and "yields" or "last"))
        dump("4b_showdown")
    else
        -- Prep what fits, and turn some knobs.
        for _, id in ipairs(c.prep.museum.ahead) do
            click_key("prep_" .. id)
            for _, kid in ipairs(adventure.data.rooms[id].knobs or {}) do
                if rng:chance(0.5) then
                    click_key("knob_" .. kid)
                    click_key("knob_" .. kid .. "_" .. content.players.order[rng:int(1, 4)])
                end
            end
        end
        if c.prep:spent() > c.prep.budget then problem("prep went over budget" .. where) end
        dump("4c_prep_w" .. week .. "_set")
    end
    if not click_key("run_night") then problem("no run button" .. where) break end
    if app.screen ~= "night" then problem("Run game night didn't start the night (" .. tostring(app.screen) .. ")" .. where) break end
    local g = 0
    while app.screen == "night" and not app.night_done and g < 12000 do
        g = g + 1
        call(update, self, 0.4)
        if app.rolling then
            call(on_message, self, "roll_result", { value = rng:d20() }, "dice")
        elseif app.pending then
            local bs = buttons()
            if not click_label("Play") and #bs > 0 then click(bs[rng:int(1, #bs)]) end
        end
        if g % 400 == 0 then scan("game night" .. where) end
    end
    if not app.night_done then problem("night never finished" .. where) break end
    nights = nights + 1
    dump("5_night_end_w" .. week)
    if not click_label("See how everyone felt") then problem("no report button" .. where) break end
    dump("6_report_w" .. week)
    scan("the report" .. where)
    marks_seen = marks_seen + #((c.report and c.report.museum and c.report.museum.marks) or {})
    if click_key("level_up") then
        dump("6b_levelup_w" .. week)
        for _ = 1, 6 do
            if not app.levelup then break end
            local bs = buttons()
            if #bs > 0 then click(bs[#bs]) end
        end
    end
    if not leave_report(where) then break end
    if app.screen == "slice_end" then break end
end

if app.screen ~= "slice_end" then
    problem("the prologue never reached the journey recap (" .. tostring(app.screen) .. ", " .. nights .. " nights)")
else
    dump("7_journey")
    scan("the journey recap")
    if not has_text("THE ROUTE") then problem("the journey recap has no route") end
    if not click_key("to_survey") then problem("no way on from the journey recap") end
    dump("8_survey")
end
if not boss_seen then problem("there was never a boss night") end
if app.campaign.level < 3 then problem("the party never levelled up (level " .. tostring(app.campaign.level) .. ")") end

-- A fresh launch offers to carry on (the museum's own save slot).
print(string.format("museum smoke %d: %d nights, ending %s, marks %d, level %d", SEED, nights,
    tostring(app.campaign.adv and app.campaign.adv.ending), marks_seen, app.campaign.level))
if #problems > 0 then
    for _, p in ipairs(problems) do print("PROBLEM: " .. p) end
    os.exit(1)
end
