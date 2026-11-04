-- The Museum of Nightmares (v2) through the real UI, against the mock GUI from gui_smoke.lua: the
-- prototype notice, Session Zero, the heroes' hooks, every week's between-session questions and
-- prep board, game night, the report, level-ups, boss night, and the journey recap.
-- Run from the project root:  lua tools/tests/museum_smoke.lua [seed]   (DUMP_DIR=out to dump screens;
-- TRANSCRIPT=file to write down everything a player reads, in order; AUDIT=1 to list text cut short)

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
-- Every piece of text that goes on screen, at any moment, is checked for the old story (set below,
-- once the adventure is loaded): a line that only flashes up between checkpoints still counts.
local on_text
-- A node is a handle, not a table: in the engine, reading or writing any field on one is an error
-- ("Illegal operation"). The mock's own fields are allowed; anything else stops the test (November 3:
-- a tile kept its resource pips under chip.res, which was already the roll's text node).
local NODE_FIELDS = { kind = true, pos = true, size = true, pivot = true, enabled = true, alive = true, color = true, text = true,
                      font = true, image = true, euler = true, slice = true }
local NODE_MT = {
    __index = function(_, k)
        if NODE_FIELDS[k] then return nil end
        error("a field read on a GUI node: " .. tostring(k), 2)
    end,
    __newindex = function(t, k, v)
        if not NODE_FIELDS[k] then error("a field set on a GUI node: " .. tostring(k), 2) end
        rawset(t, k, v)
    end,
}
local function new_node(kind, pos, size)
    num(pos.x, "pos.x"); num(pos.y, "pos.y")
    local n = setmetatable({ kind = kind, pos = pos, size = size or vmath.vector3(0, 0, 0), pivot = "c", enabled = true, alive = true }, NODE_MT)
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
    if on_text then on_text(text) end
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
        if on_text then on_text(t) end
        -- (The hover audit: words set into a box that has a hover card of its own are explained.)
        if GLOSS_BOXED and n.pos and package.loaded["game.ui.kit"] then
            local hs = package.loaded["game.ui.kit"].spot_hit(n.pos.x, n.pos.y)
            if hs then GLOSS_BOXED[t] = true end
        end
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

-- TRANSCRIPT=file: write down every new piece of text as it comes on screen, in the order it came,
-- with each screen's name and what was pressed, so a playtest can read the prologue as a new player
-- would see it.
local TRANSCRIPT = os.getenv("TRANSCRIPT")
local tr_file = TRANSCRIPT and io.open(TRANSCRIPT, "w")
local tr_prev, tr_screen = {}, nil
local function transcribe()
    if not tr_file then return end
    -- (Drop the deleted nodes as we go: the list of every node ever made gets long over a prologue.)
    local j = 0
    for i = 1, #order do
        local n = order[i]
        if n.alive then j = j + 1; order[j] = n end
    end
    for i = #order, j + 1, -1 do order[i] = nil end
    local a = self.app
    if a and a.screen ~= tr_screen then
        tr_screen = a.screen
        tr_file:write("\n=== SCREEN: " .. tostring(tr_screen) .. " ===\n")
    end
    local now = {}
    for _, n in ipairs(order) do
        local t = n.text
        if n.enabled and t and string.find(t, "%S") and not (n.color and n.color.w < 0.05)
            and n.pos.x > -40 and n.pos.x < 1640 and n.pos.y > -40 and n.pos.y < H + 40 and not now[t] then
            now[t] = true
            if not tr_prev[t] then tr_file:write((string.gsub(t, "\n", " ")), "\n") end
        end
    end
    tr_prev = now
end

local function call(fn, ...)
    local ok2, e = pcall(fn, ...)
    if not ok2 then problem(tostring(e)) end
    transcribe()
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
    if tr_file then tr_file:write("    [pressed: " .. ((b.label and b.label.text) or b.key or "?") .. "]\n") end
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
-- GLOSS_AUDIT=1: every game word on screen that a new player can point at for its meaning, and the
-- ones they can't (November 3: "Audit all keywords to make sure they have a hover").
local GLOSS = os.getenv("GLOSS_AUDIT") and { glossed = {}, seen = {}, boxed = {} }
if GLOSS then
    GLOSS_BOXED = GLOSS.boxed
    kit.gloss_audit = {}
    local gloss = require "game.ui.gloss"
    local hook = kit.gloss_hook
    kit.gloss_hook = function(x, y, str, font, color, pivot, tags)
        GLOSS.glossed[str] = tags
        return hook(x, y, str, font, color, pivot, tags)
    end
end
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
local foreign_seen = {}
on_text = function(t)
    if GLOSS and type(t) == "string" then
        local a = self.app
        GLOSS.seen[t] = GLOSS.seen[t] or (a and tostring(a.screen) .. (a.overlay and ("/" .. a.overlay) or "") or "?")
    end
    local c = self.app and self.app.campaign
    if c and c.module and type(t) == "string" and not foreign_seen[t] and adventure.foreign(t) then
        foreign_seen[t] = true
        problem("old story on screen: " .. t)
    end
end

-- The old story must never show on a screen.
-- Every underline the glossary draws belongs to the text drawn right after it (kit.text): an
-- underline still lit when its text is hidden or gone is a stray line on the screen.
local gloss_groups = {}
do
    local kit_ = require "game.ui.kit"
    local hook_ = kit_.gloss_hook
    if hook_ then
        kit_.gloss_hook = function(...)
            local n0 = #order
            local r = hook_(...)
            if #order > n0 then
                table.insert(gloss_groups, { from = n0 + 1, to = #order, text = #order + 1 })
            end
            return r
        end
    end
end
local function stray_underlines(name)
    local keep = {}
    for _, g in ipairs(gloss_groups) do
        local t = order[g.text]
        -- (A caller that draws its text elsewhere keeps its own underlines: the night's captions.)
        if t and t.kind ~= "text" then
            t = nil
        end
        local live = false
        for i = g.from, g.to do
            local b = order[i]
            if b and b.alive then
                live = true
                local a = b.color and b.color.w or 0
                if t and b.enabled ~= false and a > 0.01 and (not t.alive or t.enabled == false) then
                    problem("a stray underline on " .. name .. " under hidden text: " .. tostring(t.text))
                    return
                end
            end
        end
        if live then table.insert(keep, g) end
    end
    gloss_groups = keep
end

-- Nothing on a screen hangs off its edge (the playtest, November 3: tonight's rooms ran below the
-- bottom of the prep board). Text by its lines and font, boxes by their size.
local offscreen_seen = {}
local OFF_PIVOT_TOP = { nw = 0, n = 0, ne = 0, w = 0.5, c = 0.5, e = 0.5, sw = 1, s = 1, se = 1 }
local OFF_PIVOT_LEFT = { nw = 0, w = 0, sw = 0, n = 0.5, c = 0.5, s = 0.5, ne = 1, e = 1, se = 1 }
local function offscreen(name)
    local kit_ = package.loaded["game.ui.kit"]
    if not kit_ then return end
    for _, n in ipairs(order) do
        if n.alive and n.enabled ~= false and (not n.color or n.color.w > 0.01) and n.pos then
            local w, h
            if n.kind == "text" and n.text and n.text ~= "" and n.font then
                local lines = 1
                for _ in string.gmatch(n.text, "\n") do lines = lines + 1 end
                h = lines * kit_.line_height(n.font)
                w = 0
                for line in string.gmatch(n.text .. "\n", "(.-)\n") do
                    w = math.max(w, kit_.width(line, n.font))
                end
            elseif n.kind == "box" and n.size then
                w, h = n.size.x, n.size.y
            end
            if w and h and h > 0 and (n.euler or 0) == 0 then
                local top = kit_.H - n.pos.y - (OFF_PIVOT_TOP[n.pivot] or 0) * h
                local left = n.pos.x - (OFF_PIVOT_LEFT[n.pivot] or 0) * w
                -- (Full-screen backdrops and anything parked well off screen on purpose don't count.)
                local parked = top > kit_.H or top + h < 0 or left > kit_.W or left + w < 0
                if not parked and (top + h > kit_.H + 3 or left + w > kit_.W + 3 or top < -3 or left < -3) then
                    local what = n.kind == "text" and n.text or ("a box " .. math.floor(w) .. "x" .. math.floor(h))
                    local key = name:gsub("%(week %d+%)", "") .. "|" .. what
                    if not offscreen_seen[key] then
                        offscreen_seen[key] = true
                        print(string.format("OFFSCREEN %s: %s at %d,%d size %dx%d", name, string.sub(string.gsub(what, "\n", " "), 1, 80),
                            math.floor(left), math.floor(top), math.floor(w), math.floor(h)))
                    end
                end
            end
        end
    end
end

local function scan(name)
    stray_underlines(name)
    offscreen(name)
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
-- The main menu (November 3): with no saves, only New game; Load and Continue wait for a save.
if has_key("load_game") or has_key("continue") then problem("the title offers to load or continue with no saves") end
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
local thoughts_seen, thoughts_opened, thoughts_answered, reads_seen = 0, 0, 0, {}
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
        elseif pr.kind == "ruling" then
            if not click_key("ruling_" .. rng:int(1, 2)) then problem("no way to post the ruling" .. where) break end
        elseif pr.kind == "favor" then
            click_key("favor_help_1")
            click_key("favor_hurt_" .. rng:int(1, 2))
            if not click_key("favor_done") then problem("no way to settle a favor" .. where) break end
        elseif pr.kind == "chat" then
            -- A question for the DM in the group chat (November 3): answered, or left.
            local n = #(app.campaign.chat or {})
            if not click_key("chat_reply_" .. rng:int(0, 2)) then problem("no way to answer the chat" .. where) break end
            if pr.msg.answered and pr.msg.answered > 0 and #(app.campaign.chat or {}) <= n then
                problem("the DM's answer didn't go in the chat" .. where)
            end
        end
    end
    dump("4_prep_w" .. week)
    scan("the prep board" .. where)
    -- A save of your own, from the prep board (November 3).
    if week == 1 then
        if not click_key("save_game") then problem("no Save button on the prep board" .. where) end
        if not app.saves_ui then problem("the Save window didn't open" .. where) end
        dump_once("4s_save_w1")
        scan("the Save window" .. where)
        if not click_key("save_slot1") then problem("no save slot to save into" .. where) end
        if not (app.saves_ui and app.saves_ui.said) then problem("saving to a slot said nothing" .. where) end
        click_key("saves_close")
        if app.saves_ui then problem("the Save window didn't close" .. where) end
    end
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
        -- Its X (November 3): nothing changed closes straight away; a change asks first, and
        -- "Delete my changes" puts the room's map back.
        do
            local repo = require "game.model.map_repo"
            if not click_key("open_maps") then problem("no way into the map repository" .. where) end
            if not click_key("mr_cancel") then problem("no X in the map repository") end
            if app.overlay or app.ask then problem("the X with nothing changed didn't just close") end
            click_key("open_maps")
            click_key("mr_group_basics")
            click_key("mr_use_room")
            click_key("mr_room_garden")
            if not repo.room_map(c, "garden") then problem("setting the garden's map didn't stick") end
            click_key("mr_cancel")
            if not app.ask then problem("the X after a change didn't ask first") end
            dump_once("4m_maps_cancel")
            click_key("ask_no")
            if app.overlay ~= "maps" or not repo.room_map(c, "garden") then problem("Keep editing didn't keep the change") end
            click_key("mr_cancel")
            click_key("ask_yes")
            if app.overlay then problem("Delete my changes didn't close the repository") end
            if repo.room_map(c, "garden") then problem("the X didn't put the garden's map back") end
        end
        -- The tie editor's X does the same for a lock.
        do
            click_key("open_ties")
            click_key("tl_door_" .. require("game.model.ties").door_key("garden", "entrance"))
            click_key("tl_lock_door")
            click_key("tl_tab_room")
            click_key("tl_cond_room_chamber")
            local locked = adventure.way_closed(c, "garden", "entrance")
            click_key("tl_cancel")
            if locked and not app.ask then problem("the ties editor's X after a lock didn't ask first") end
            click_key("ask_yes")
            if app.overlay then problem("the ties editor's X didn't close it") end
            if adventure.way_closed(c, "garden", "entrance") then problem("the ties editor's X didn't take the lock back off") end
        end
        -- A hero's sheet: the header's three rows stay on the screen (November 3).
        if app.open_sheet then
            call(app.open_sheet, "jess")
            dump_once("4h_hero_sheet")
            scan("a hero's sheet" .. where)
            call(app.close_overlay)
        end
        -- A person's sheet (November 3): a name in a line opens it; the DM puts things in their
        -- pockets and picks how the party gets them.
        do
            local npcs = require "game.model.npcs"
            local clicked
            for _, l in ipairs(kit.layers) do
                for _, s in ipairs(l.spots or {}) do
                    if s.on_click and not clicked then
                        clicked = s
                    end
                end
            end
            if clicked then
                local r = clicked.rect
                call(on_input, self, "touch", { pressed = true, x = r[1] + r[3] / 2, y = kit.H - (r[2] + r[4] / 2) })
                if not app.npc_sheet then problem("clicking a person's name didn't open their sheet") end
                click_key("npc_close")
            end
            call(require("game.ui.gloss").on_npc, "mus_flitwidget")
            if app.npc_sheet ~= "mus_flitwidget" then problem("Flitwidget's sheet didn't open") end
            dump_once("4p_npc_sheet")
            scan("a person's sheet" .. where)
            click_key("npc_next")
            click_key("npc_add")
            local d = npcs.drops(c, "mus_flitwidget")
            if #d ~= 1 then problem("putting an item on Flitwidget didn't stick (" .. #d .. ")") end
            local how = d[1] and d[1].how
            click_key("npc_how_1")
            if d[1] and d[1].how == how then problem("the how button didn't change how they get it") end
            click_key("npc_drop_x_1")
            if #npcs.drops(c, "mus_flitwidget") ~= 0 then problem("Take it didn't take the item back") end
            click_key("npc_add")
            key("back")
            if app.npc_sheet then problem("Esc didn't close a person's sheet") end
            -- One for the Bone Construct, if they beat it.
            call(require("game.ui.gloss").on_npc, "mus_bone_construct")
            click_key("npc_add")
            click_key("npc_done")
            if app.npc_sheet then problem("Close didn't close a person's sheet") end
        end
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
        click_key("map_group_cover")
        if not click_key("map_piece_pillar") then problem("no Pillar in the Cover pieces") end
        local before = 0
        for _, mm in pairs(c.my_maps or {}) do before = before + 1 end
        if before ~= 1 then problem("New map didn't make a map (" .. before .. ")") end
        if not click_key("mr_back") then problem("no way back from the map maker") end
        if not click_key("mr_done") then problem("no Done in the map repository") end
        if app.overlay then problem("the map repository didn't close") end
        -- The tie-and-lock editor (v2): lock a door, tie a mark to a room, cut a card and take it off.
        local ties = require "game.model.ties"
        if not click_key("open_ties") then problem("no way into the tie-and-lock editor" .. where) end
        if app.overlay ~= "ties" then problem("the tie-and-lock editor didn't open" .. where) end
        dump_once("4t_ties_w" .. week)
        scan("the tie-and-lock editor" .. where)
        if not click_key("tl_room_paintings") then problem("no Hall of Paintings on the editor's plan") end
        dump_once("4t_ties_room")
        scan("a room's cards in the editor")
        if not click_key("tl_door_" .. ties.door_key("entrance", "paintings")) then problem("no door to the Hall of Paintings") end
        if not click_key("tl_lock_door") then problem("no way to lock a door") end
        dump_once("4t_ties_pick")
        scan("the editor's chips")
        click_key("tl_tab_room")
        if not click_key("tl_cond_room_chamber") then problem("no room to keep the door locked until") end
        if not adventure.way_closed(c, "entrance", "paintings") then problem("locking the door didn't stick") end
        if not click_key("tl_new_tie") then problem("no New tie in the editor") end
        click_key("tl_tab_room")
        if not click_key("tl_cond_room_garden") then problem("no room to tie a mark to") end
        click_key("tl_tab_mark")
        dump_once("4t_ties_effect")
        if not click_key("tl_eff_mark_drone") then problem("no mark to tie") end
        if #ties.ties(c) ~= 1 then problem("the tie didn't stick (" .. #ties.ties(c) .. ")") end
        click_key("tl_room_paintings")
        if not click_key("tl_cut_mus_dice_painting") and click_key("tl_cards_next") then click_key("tl_cut_mus_dice_painting") end
        local cut = ties.lock_on(c, { kind = "moment", moment = "mus_dice_painting" })
        dump_once("4t_ties_list")
        scan("the editor's list")
        if not cut then problem("couldn't cut a card")
        elseif not click_key("tl_remove_" .. cut.id) then problem("no way to take a lock off") end
        if ties.lock_on(c, { kind = "moment", moment = "mus_dice_painting" }) then problem("taking a lock off didn't stick") end
        if not click_key("tl_done") then problem("no Done in the tie-and-lock editor") end
        if app.overlay then problem("the tie-and-lock editor didn't close") end
        if not has_text("Ties and locks (2)") then problem("the board doesn't count its ties and locks") end
        dump_once("4t_board_locked")
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
        -- v2: the DM's recap, once a night a little way in: the Story and Table sidebars, then shut.
        if g == 60 and not app.pending and not app.thought_card then
            if not click_key("night_story") then problem("no Story button on game night" .. where) end
            if not app.recap_left then problem("the Story sidebar didn't open" .. where) end
            if not click_key("night_table") then problem("no Table button on game night" .. where) end
            if not app.recap_right then problem("the Table sidebar didn't open" .. where) end
            dump_once("5r_recap_w" .. week)
            scan("the recap sidebars" .. where)
            if not has_text("THE STORY") or not has_text("THE TABLE") then problem("the recap sidebars are empty" .. where) end
            local t0 = app.night.clock
            call(update, self, 2)
            if app.night.clock ~= t0 then problem("the night didn't wait while the recap was open" .. where) end
            -- (Game night's tips sit where the Table sidebar opens: they wait while the recap is up.)
            if app.guide_layer then problem("a tip stayed up over the recap sidebars" .. where) end
            click_key("recap_close_left")
            click_key("recap_close_right")
            if app.recap_left or app.recap_right then problem("the recap sidebars didn't close" .. where) end
        end
        -- Pause and the speed buttons (November 3): Pause holds the night, 4x and back to 1x stick.
        if g == 80 and not app.night_done then
            if not click_key("night_pause") then problem("no Pause button on game night" .. where) end
            if not app.paused then problem("Pause didn't pause" .. where) end
            local t0, ev0 = app.night.clock, app.beat_t
            call(update, self, 5)
            if app.beat_t ~= ev0 or app.night.clock ~= t0 then problem("the night ran on while paused" .. where) end
            if not click_key("night_speed_4x") then problem("no 4x button" .. where) end
            if app.paused or (app.speed_now and app.speed_now() ~= 4) then problem("4x didn't play at four times" .. where) end
            click_key("night_speed_1x")
            if app.speed_now and app.speed_now() ~= 1 then problem("1x didn't go back to normal speed" .. where) end
        end
        -- v2: a friend's thought. Read the first few and answer them; a card that opened by itself
        -- (Pip about to go off alone) gets an answer too, or the night would wait on it forever.
        if app.thought_card then
            dump_once("5t_thought_card")
            scan("a thought card" .. where)
            local th = app.night.th
            local before = th and th.answered or 0
            -- Read them first (an Insight roll), then: ask after a miss, answer, or let it be.
            local t = th and th.list[app.thought_card.id]
            if t and not t.read then
                if not click_key("thought_read") then problem("no way to read a friend's thought" .. where) end
                if not t.read then problem("reading a thought didn't roll" .. where) end
                dump_once("5t_thought_read")
                reads_seen[t.read and t.read.result or "none"] = true
            end
            if t and t.read and t.read.result == "miss" and rng:chance(0.5) then
                if not click_key("thought_ask") then problem("a missed read with no way to ask" .. where) end
            end
            if app.thought_card and not click_key(rng:chance(0.6) and "thought_ans_1" or "thought_let") then
                if not click_key("thought_let") then
                    problem("a thought card with no answers" .. where)
                    click_key("thought_close")
                end
            end
            if app.thought_card then problem("answering a thought didn't close its card" .. where) end
            thoughts_answered = thoughts_answered + ((th and th.answered or 0) - before)
        elseif app.thinking and next(app.thinking) and thoughts_opened < 4 then
            local key = next(app.thinking)
            if not click_key("thought_" .. key) then problem("no cloud to click over " .. key .. "'s panel" .. where) end
            thoughts_opened = thoughts_opened + 1
        end
        if app.rolling then
            call(on_message, self, "roll_result", { value = rng:d20() }, "dice")
        elseif app.pending then
            local bs = buttons()
            if not click_label("Play") and #bs > 0 then click(bs[rng:int(1, #bs)]) end
        end
        if g % 400 == 0 then scan("game night" .. where) end
    end
    if not app.night_done then problem("night never finished" .. where) break end
    if app.night.th then
        thoughts_seen = thoughts_seen + app.night.th.shown
    end
    nights = nights + 1
    dump("5_night_end_w" .. week)
    if not click_label("See how everyone felt") then problem("no report button" .. where) break end
    -- How the table felt and the night's reward first (November 3): open the box if there is one.
    dump("6r_rewards_w" .. week)
    scan("the rewards" .. where)
    if not has_key("rewards_next") then problem("no rewards before the report" .. where) end
    if has_key("rewards_open") then
        local before = #require("game.model.loot").bag(app.campaign)
        click_key("rewards_open")
        for _ = 1, 40 do
            if not app.rewards_spin then break end
            require("game.ui.rewards_view").update(app, 0.1)
        end
        if #require("game.model.loot").bag(app.campaign) ~= before + 1 then problem("the box didn't put dice in the bag" .. where) end
        dump_once("6r_rewards_open")
        scan("the opened box" .. where)
    end
    if not click_key("rewards_next") then problem("couldn't leave the rewards" .. where) end
    dump("6_report_w" .. week)
    scan("the report" .. where)
    -- A set from the bag for someone (November 3).
    do
        local loot = require "game.model.loot"
        local bag = loot.bag(app.campaign)
        if #bag > 0 then
            local key = app.campaign.players[rng:int(1, #app.campaign.players)].key
            local before, sid = #bag, bag[app.gift_pick or 1]
            if click_key("gift_" .. key) then
                if #loot.bag(app.campaign) ~= before - 1 or require("game.model.dice_sets").of(app.campaign, key) ~= sid then
                    problem("a set from the dice bag didn't go to " .. key .. where)
                end
            end
        end
    end
    -- A save from the report, and overwriting one asks first.
    if week == 1 then
        if not click_key("save_game") then problem("no Save button on the report" .. where) end
        if not click_key("save_slot2") then problem("no save slot on the report" .. where) end
        click_key("save_slot1")
        if not (app.saves_ui and app.saves_ui.confirm == "slot1") then problem("overwriting a save didn't ask first" .. where) end
        click_key("saves_close")
        if app.saves_ui then problem("the Save window didn't close" .. where) end
    end
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

if thoughts_seen == 0 then problem("nobody at the table ever had a thought") end
local final_ending, final_level = app.campaign.adv and app.campaign.adv.ending, app.campaign.level
-- A fresh launch: the main menu offers Continue, Load and New game, and Load picks up the save
-- made on the first prep board, right where it was.
do
    local self2 = {}
    local ok2, e2 = pcall(init, self2)
    if not ok2 then problem("relaunch: " .. tostring(e2)) end
    self.app = self2.app
    app = self.app
    click_key("agree")
    dump("9_title_saved")
    scan("the title with saves")
    if not has_key("continue") then problem("the title doesn't offer to continue") end
    if not has_key("load_game") then problem("the title doesn't offer Load with saves there") end
    if not has_key("new_campaign") then problem("the title doesn't offer a new game next to Continue") end
    if not click_key("load_game") then problem("no Load button") end
    if not (app.saves_ui and app.saves_ui.mode == "load") then problem("the Load window didn't open") end
    dump("9_load")
    scan("the Load window")
    if not has_key("load_auto") then problem("the autosave isn't in the Load list") end
    if not has_key("load_slot2") then problem("the report's save isn't in the Load list") end
    if not click_key("load_slot1") then
        problem("the prep board's save isn't in the Load list")
    elseif app.screen ~= "prep" or app.campaign.week ~= 1 or not app.campaign.at_prep then
        problem("loading the first prep board's save didn't go back to it (" .. tostring(app.screen) .. ", week "
            .. tostring(app.campaign.week) .. ")")
    end
end
if tr_file then tr_file:close(); tr_file = nil end
if kit.audit then
    local seen, n = {}, 0
    for _, e in ipairs(kit.audit) do
        local k = e.text .. "|" .. tostring(e.w)
        if not seen[k] then
            seen[k] = true
            n = n + 1
            print(string.format("CUT  %s  (w %s, %s lines, %s) at %s", e.text, tostring(e.w), tostring(e.lines), e.font,
                tostring(e.where)))
        end
    end
    print(n .. " different texts cut short")
end
if GLOSS then
    local gloss = require "game.ui.gloss"
    local words = dofile("tools/tests/gloss_words.lua")
    local missing = {}
    for t, where in pairs(GLOSS.seen) do
        for _, w in ipairs(words) do
            if string.find(t, w[1]) then
                local tags = GLOSS.glossed[t]
                local found = tags and gloss.find(t, tags, {}, {}, 99) or {}
                local hit = (kit.gloss_covered or {})[t] ~= nil or (GLOSS.boxed or {})[t] ~= nil
                    or (kit.gloss_audit[t] and not (kit.gloss_covered or {})[t] and true) or false
                for _, f in ipairs(found) do
                    hit = hit or (f[3].id == w[2])
                end
                if not hit then
                    local k = w[2] .. " @ " .. where
                    missing[k] = missing[k] or ((tags and "term not found: " or "no hover: ") .. (string.gsub(t, "\n", " ")))
                end
            end
        end
    end
    local keys = {}
    for k in pairs(missing) do table.insert(keys, k) end
    table.sort(keys)
    for _, k in ipairs(keys) do print("GLOSS  " .. k .. "  |  " .. string.sub(missing[k], 1, 140)) end
    print(#keys .. " game words on screen without a hover")
end
print(string.format("museum smoke %d: %d nights, ending %s, marks %d, level %d, thoughts %d (opened %d, answered %d)", SEED, nights,
    tostring(final_ending), marks_seen, final_level, thoughts_seen, thoughts_opened,
    thoughts_answered))
if #problems > 0 then
    for _, p in ipairs(problems) do print("PROBLEM: " .. p) end
    os.exit(1)
end
