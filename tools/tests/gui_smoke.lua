-- Drives the real game.gui_script against a mocked Defold GUI API, clicking
-- random buttons through several full weeks. Catches Lua errors, use of
-- deleted nodes, unknown fonts/textures, node-count overflow and stuck flows.
-- Run from the project root:  texlua tools/tests/gui_smoke.lua [seed] [weeks]

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
local WEEKS = tonumber(arg and arg[2]) or 5
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
    local app = self.app
    -- Prep is a step at a time (October 26): game night is the last step's button.
    if app.screen == "prep" then
        require("game.ui.prep_steps").go(app, "ready")
    end
    if not click_label("Run game night") then return false end
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


-- A gift from the table waiting on the report (game/model/keepsakes.lua): take it, then put it away.
local has_text_fn
local function take_gift(where, n)
    local keepsakes = require "game.model.keepsakes"
    local g = keepsakes.waiting(app.campaign)
    if not g then
        return
    end
    dump_once("7k_keepsake")
    if not has_text_fn("hands you something") then problem("the gift doesn't say who it's from" .. where) end
    if click_key("next_week") and app.quick then problem("the report moved on under the gift" .. where) end
    key("confirm")
    if app.quick or app.screen ~= "report" then problem("Enter moved the report on under the gift" .. where) end
    local how = ({ "gush", "use", "cool" })[((n or 0) % 3) + 1]
    if not click_key("keepsake_" .. how) then problem("no way to take the gift (" .. how .. ")" .. where) end
    if g.how ~= how or not app.keepsake_shown then problem("taking the gift didn't stick" .. where) end
    dump_once("7l_keepsake_taken")
    if not click_key("keepsake_done") then problem("no way to put the gift away" .. where) end
    if app.keepsake_shown or keepsakes.waiting(app.campaign) then problem("the gift wouldn't go away" .. where) end
    if not has_text_fn("A gift from") then problem("the report doesn't list the gift" .. where) end
end

-- Leave the report: the quick playtest questions, then the next week or the end of the slice.
-- Someone joins a small table (October 15): their page, then the week.
local function handle_join(where)
    if app.screen ~= "join" then
        return
    end
    local key = app.join and app.join.key
    dump_once("1g_join_" .. tostring(key))
    -- Their steps (October 26): their story, their idea, their ask, what turns up first.
    local steps_mod = require "game.ui.steps"
    local sv = require "game.ui.setup_view"
    local backstory = require "game.model.backstory"
    for _ = 1, 12 do
        if app.screen ~= "join" then break end
        local s = steps_mod.current(app, sv.join_flow)
        if s.id == "join_q" then
            for _, q in ipairs(backstory.data[key].questions) do click_key("bs_q_" .. q.id) end
            if backstory.asked(app.join.backstories) > backstory.data.JOIN_QUESTIONS then problem("a joiner got more questions than there's time for") end
        elseif s.id == "join_idea" then
            if click_key("step_next") then problem("the join steps went on with no answer to their idea" .. where) end
            click_key(rng:chance(0.5) and "bs_idea_yes" or "bs_idea_no")
        elseif s.id == "join_ask" then
            click_key("join_ask_agree")
        elseif s.id == "join_hook" then
            local hooks = backstory.data[key].hooks
            if not click_key("bs_hook_" .. hooks[rng:int(1, #hooks)].card) then problem("no hook choices on the join steps" .. where) end
            dump_once("1h_join_done_" .. tostring(key))
        end
        if not click_key("step_next") then problem("couldn't go on from " .. s.id .. where) return end
    end
    if app.screen ~= "prep" then problem("the welcome didn't go on to prep" .. where) return end
    if not app.campaign:player(key) then problem(key .. " didn't join the table" .. where) end
    local b = app.campaign.backstories and app.campaign.backstories[key]
    if not (b and b.hook and app.campaign.prep:pinned(b.hook)) then problem(key .. "'s hook isn't at the front of the hand" .. where) end
    if not (app.campaign.table.asks[key]) then problem(key .. "'s ask wasn't settled" .. where) end
end

local function leave_report(where)
    take_gift(where)
    if not click_key("next_week") then problem("no next-week button" .. where) return false end
    if app.quick then
        dump_once("18_quick_questions")
        if rng:chance(0.2) then
            click_key("quick_skip")
        else
            click_key("quick_prep_" .. rng:int(1, 3))
            click_key("quick_watch_" .. rng:int(1, 3))
        end
        if app.quick then problem("quick questions didn't close" .. where) return false end
    end
    handle_join(where)
    return true
end

local stats = { clicks = 0, weeks = 0, rolls = 0, modals = 0, max_nodes = 0 }

-- The lore screen (October 16): it says what it is, every scene has its column, and Back to prep
-- keeps the board (once, in session 2).
on_lore = function(app)
    stats.lore = (stats.lore or 0) + 1
    local v = app.lore_view
    if not v then problem("the lore screen drew nothing") return end
    if #v.scenes ~= 3 then problem("the lore screen has " .. #v.scenes .. " scene columns") end
    dump_once("2l_lore_w" .. tostring(app.campaign.week))
    local seen_title = false
    for _, n in ipairs(order) do
        if n.alive and n.text == "What tonight can change in the story" then seen_title = true end
    end
    if not seen_title then problem("the lore screen doesn't say what it is") end
    if app.campaign.week == 2 and not stats.lore_back then
        stats.lore_back = true
        local before = {}
        for i, sc in ipairs(app.campaign.prep.scenes) do before[i] = sc.type end
        local back
        for _, b in ipairs(buttons()) do
            if b.key == "lore_back" then back = b end
        end
        if not back then problem("no way back to prep from the lore screen") return end
        click(back)
        if app.screen ~= "prep" then problem("Back to prep didn't go back (" .. tostring(app.screen) .. ")") return end
        for i, sc in ipairs(app.campaign.prep.scenes) do
            if sc.type ~= before[i] then problem("going back to prep changed scene " .. i) end
        end
        if not click_label("Run game night") then problem("no run button after coming back from the lore screen") return end
        if app.ask then
            for _, b in ipairs(buttons()) do
                if b.key == "ask_yes" then click(b); break end
            end
        end
        if app.screen ~= "lore" then problem("running the night again skipped the lore screen") end
    end
end

function has_text_fn(fragment)
    for _, n in ipairs(order) do
        if n.alive and n.text and string.find(n.text, fragment, 1, true) then return true end
    end
    return false
end
local social = require "game.model.social"
local seeds_mod = require "game.model.seeds"

for week = 1, WEEKS do
    if app.screen == "intro" then
        dump("1_intro")
        if not click_label("Plan the campaign") then problem("no Plan the campaign button") end
        if app.screen ~= "setup" then problem("expected the setup steps, got " .. tostring(app.screen)) end
        -- Setting up, one decision at a time (October 26): walk every step. Each asks one thing;
        -- Next stays off until it's answered; your friends say something about it in bubbles.
        local steps_mod = require "game.ui.steps"
        local sv = require "game.ui.setup_view"
        local backstory = require "game.model.backstory"
        local seen, n = {}, 0
        local order = require("game.model.content").styles.order
        while app.screen == "setup" and n < 80 do
            n = n + 1
            local s = steps_mod.current(app, sv.flow)
            if not s then problem("no setup step") break end
            if seen[s.id] then problem("the setup came back to " .. s.id) break end
            seen[s.id] = true
            dump_once("1s_" .. s.id)
            if s.talk and not s.id:find("^bs_") and not s.id:find("^ask_") then
                local said = 0
                for _, k in ipairs(app.campaign:table_keys()) do
                    local t = s.talk(app, k)
                    if t and t.text and t.text ~= "" then said = said + 1 end
                end
                if said == 0 then problem("nobody says anything on the " .. s.id .. " step") end
            end
            if not steps_mod.done(app, s) and click_key("step_next") then problem("Next went on from " .. s.id .. " with nothing chosen") end
            if s.id == "table" then
                -- Seeds 1 to 4 play all four; 5 and 6 start with two and welcome Jess (session 2)
                -- and Sam (session 3) on the join steps.
                if not click_key(SEED >= 5 and "table_small" or "table_full") then problem("no table-size choices") end
                if SEED >= 5 and #app.campaign.players ~= 2 then problem("a small table should start with two, not " .. #app.campaign.players) end
                if SEED < 5 and #app.campaign.players ~= 4 then problem("a full table should start with four, not " .. #app.campaign.players) end
            elseif s.id == "style" then
                -- Every few seeds, a campaign in another style (A18), with its truths and front.
                if SEED % 3 == 0 then click_key("style_" .. order[(SEED / 3) % #order + 1]) end
            elseif s.id == "truths" then
                local st = sv.state(app)
                for _, t in ipairs(require("game.model.planner").truths_for(st.plan.style)) do
                    if rng:chance(0.4) then click_key("truth_" .. t.id) end
                end
                for _, t in ipairs(require("game.model.planner").truths_for(st.plan.style)) do
                    if #st.plan.truths < 3 then click_key("truth_" .. t.id) end
                end
            elseif s.id == "rule_death" then
                if not click_key("rule_death_cost") then problem("no death rule choices") end
            elseif s.id:find("^bs_q_") then
                -- Ask everything: the evening runs out of questions, and the buttons say so.
                local k = s.id:sub(6)
                for _, q in ipairs(backstory.data[k].questions) do click_key("bs_q_" .. q.id) end
                if backstory.asked(sv.state(app).s0.backstories) > backstory.data.QUESTIONS then
                    problem("more questions asked than the evening has")
                end
            elseif s.id:find("^bs_hook_") then
                local k = s.id:sub(9)
                local hooks = backstory.data[k].hooks
                if not click_key("bs_hook_" .. hooks[rng:int(1, #hooks)].card) then problem("no hook choices for " .. k) end
            elseif not steps_mod.done(app, s) then
                -- Anything else: one of its choices, at random.
                local opts = {}
                for _, b in ipairs(buttons()) do
                    if b.key and not b.key:find("^step_") and not b.key:find("^section_") and b.key ~= "chill_mode" then table.insert(opts, b) end
                end
                for _ = 1, 6 do
                    if steps_mod.done(app, s) or #opts == 0 then break end
                    click(opts[rng:int(1, #opts)])
                end
            end
            if not steps_mod.done(app, s) then problem("couldn't answer the " .. s.id .. " step") break end
            -- Once, back and forward again: the answer stays.
            if n == 4 then
                click_key("step_back")
                if steps_mod.current(app, sv.flow).id == s.id then problem("Back didn't go back") end
                click_key("step_next")
                if steps_mod.current(app, sv.flow).id ~= s.id then problem("Next after Back didn't come back to " .. s.id) end
            end
            -- Enter goes on too.
            if n == 6 then key("confirm") else click_key("step_next") end
        end
        for _, id in ipairs({ "table", "style", "truths", "front", "dice", "tone", "rule_xcard", "rule_death", "ready" }) do
            if not seen[id] then problem("the setup skipped its " .. id .. " step") end
        end
        if SEED < 5 and not seen.featured then problem("a full table wasn't asked whose stories come first") end
        if SEED >= 5 and seen.featured then problem("a table of two was asked whose stories come first") end
        if not (app.campaign.plan and #app.campaign.plan.truths == 3) then problem("the setup didn't lay down three truths") end
        if SEED < 5 and #app.campaign.plan.threads ~= 2 then problem("the plan doesn't feature two heroes") end
        local last_key = app.campaign:table_keys()[#app.campaign:table_keys()]
        if not (app.campaign.backstories and app.campaign.backstories[last_key] and app.campaign.backstories[last_key].hook) then
            problem("the backstories weren't written into the campaign")
        end
        if SEED >= 5 and app.campaign.table.asks.jess then problem("Session Zero settled the ask of someone who isn't there yet") end
        -- What turns up first waits at the front of the first hand.
        for k, ch in pairs(app.campaign.backstories or {}) do
            local p = app.campaign:player(k)
            if p and p.present and ch.hook and not (app.campaign.prep and app.campaign.prep:pinned(ch.hook)) then
                problem("week 1's hand doesn't hold " .. k .. "'s hook (" .. tostring(ch.hook) .. ")")
            end
        end
        if not (app.campaign.table and app.campaign.table.held) then problem("Session Zero didn't settle the table") end
    end
    if app.screen ~= "prep" then problem("expected prep, got " .. tostring(app.screen)) break end
    -- The week's prep, a step at a time (October 26): walk every step, answering each the way a
    -- player would, with a few random clicks along the way.
    local steps_mod = require "game.ui.steps"
    local ps = require "game.ui.prep_steps"
    local c = app.campaign
    local pr = c.prep
    local valley = require "game.model.valley"
    local function close_all()
        finish_talk()
        if app.convo then
            if not (click_key("convo_done") or click_key("convo_close")) then click_label("Close"); click_label("Done") end
            if app.convo then problem("conversation modal wouldn't close"); app.convo = nil end
        end
        if app.book then click_key("book_done") end
        if app.ask then click_key("ask_no") end
        if app.levelup then click_key("levelup_close") end
        if app.levelup then problem("level-up modal wouldn't close"); app.levelup = nil end
        if app.overlay then
            local was = app.overlay
            if not (click_key("notes_close") or click_key("sheet_close") or click_key("enc_done")) then key("back") end
            if app.overlay then problem(was .. " wouldn't close"); app.overlay = nil end
        end
        if app.story_panel and not click_key("story_panel_close") then key("story") end
        app.refresh()
    end
    -- A few random clicks on a step: anything but the way on, the way back, and the switch.
    local function random_clicks(nclicks)
        for _ = 1, nclicks do
            local bs = {}
            for _, b in ipairs(random_buttons()) do
                local k = b.key or ""
                if not (k:find("^step_") or k:find("^section_") or k == "chill_mode" or k:find("^ready_stop_") or k == "open_stop") then
                    table.insert(bs, b)
                end
            end
            if #bs == 0 then break end
            click(bs[rng:int(1, #bs)])
            stats.clicks = stats.clicks + 1
            stats.max_nodes = math.max(stats.max_nodes, alive_count)
            close_all()
        end
    end
    -- Make place pid stop i from the map: its pin (a town's place in its list), then the button.
    local function map_stop(i)
        local s = pr.scenes[i]
        for _, n in ipairs(app.valley_map and app.valley_map.nodes or {}) do
            for _, pc in ipairs(n.places) do
                if s.slots.location then return true end
                if #valley.stops_at(pr, pc.id) == 0 and pr:can_place(i, pc.id) then
                    if not click_key("pin_" .. n.id) then problem("no pin on the map for " .. n.id) return false end
                    if n.hub and not click_key("hub_place_" .. pc.id) then
                        problem("no row for " .. pc.id .. " in " .. n.id .. "'s card")
                        return false
                    end
                    if not click_key("make_stop") then problem("no Make it stop button on " .. pc.id .. "'s card") return false end
                    if not (s.slots.location and s.slots.location.id == pc.id) then
                        problem("Make it stop " .. i .. " didn't put " .. pc.id .. " on stop " .. i)
                    end
                end
            end
        end
        return s.slots.location ~= nil
    end
    local seen, n = {}, 0
    local module_pick
    local did_encounter, did_handout = false, false
    while app.screen == "prep" and n < 120 do
        n = n + 1
        close_all()
        local s = steps_mod.current(app, ps.flow)
        if not s then problem("no prep step") break end
        if seen[s.id] then problem("prep came back to its " .. s.id .. " step (week " .. week .. ")") break end
        seen[s.id] = true
        if week == 1 then dump_once("2s_" .. s.id) end
        if s.id ~= "ready" then random_clicks(s.id:find("^route_") and 2 or 3) end
        s = steps_mod.current(app, ps.flow)
        if s.id == "story" then
            if week == 1 then dump("2b_prep_story") end
            -- Each week's first look (the story review reads these).
            if week >= 2 and week <= 4 then dump_once("2w" .. week .. "_prep") end
            if week >= 2 then
                local thinks = 0
                for _, p in ipairs(c.players) do
                    local t = p.present and s.talk(app, p.key)
                    if t and t.think and t.text ~= "" then thinks = thinks + 1 end
                end
                if thinks == 0 then problem("nobody at the table is thinking about the story (week " .. week .. ")") end
            end
        elseif s.id == "chat" then
            if week == 2 and FULL then
                -- Messages: the spotlight conflict was pushed live last week.
                dump("13_prep_messages")
                local rows = require("game.ui.messages_view").rows(app)
                if #rows == 0 then problem("no conversations open with a live conflict") end
                local by, answered
                for _, r in ipairs(rows) do
                    if r.def.opener == "player" then
                        if r.state == "New" then by = r else answered = true end
                    end
                end
                if by then
                    if not click_key("convo_" .. by.id) then problem("couldn't open " .. by.id) end
                    if app.convo ~= by.id then problem("conversation didn't open") end
                    dump("14_convo")
                    if not click_key("convo_opt_1") then problem("no reply options in the conversation") end
                    if not (pr.convos[by.id] and #pr.convos[by.id].log >= 3) then problem("they didn't answer") end
                    dump("14b_convo_answered")
                    if not click_key("convo_done") then problem("no Done button after the conversation ended: " .. by.id) end
                elseif not answered then
                    problem("no bystander message for a live conflict")
                end
                -- Starting one yourself costs prep time only when you send.
                local jess_row
                for _, r in ipairs(require("game.ui.messages_view").rows(app)) do
                    if r.id == "spotlight_jess" then jess_row = r end
                end
                if jess_row and not pr.convos.spotlight_jess and pr:left() >= 1 then
                    local left = pr:left()
                    click_key("convo_spotlight_jess")
                    if pr:left() ~= left then problem("opening a conversation charged before sending") end
                    click_key("convo_close")
                    if pr:left() ~= left then problem("closing an unsent conversation cost time") end
                    click_key("convo_spotlight_jess")
                    click_key("convo_opt_2")
                    if pr:left() ~= left - 1 then problem("sending to Jess didn't cost an hour") end
                    local th = pr.convos.spotlight_jess
                    while th and not th.done and click_key("convo_opt_1") do end
                    click_key("convo_done")
                end
            end
            -- Answer a theory in the group chat if there is one.
            for i, m in ipairs(c.chat) do
                if m.choices and not m.answered then
                    if click_key("chat_" .. i .. "_1") and not m.answered then problem("answering a theory didn't stick") end
                    break
                end
            end
        elseif s.id == "friends" then
            if week <= 2 then dump("2f_friends_w" .. week) end
            if week == 1 then
                local sk = c.players[#c.players].key
                if not click_key("sheet_" .. sk) then problem("no sheet link on " .. sk .. "'s card") end
                if app.overlay ~= "sheet" then problem(sk .. "'s card didn't open their sheet") end
                click_key("sheet_close")
            end
            if week == 2 then
                -- Goodwill: the heart on each card, and what it means on hover (and who gave you what).
                local keepsakes = require "game.model.keepsakes"
                local given = keepsakes.get(c).given
                local from = given[1] and given[1].from
                if not from then problem("week two with no gift on the table") end
                local giver = from and c:player(from)
                if giver and not giver.present then
                    from = nil
                    for _, g in ipairs(given) do
                        local gp = c:player(g.from)
                        if gp and gp.present then from = g.from break end
                    end
                end
                local hovered = false
                for _, b in ipairs(buttons()) do
                    if from and b.key == "goodwill_" .. from then
                        local x, y = center(b)
                        call(on_input, self, nil, { x = x, y = y })
                        hovered = true
                        break
                    end
                end
                if from and not hovered then problem("no Goodwill heart on " .. from .. "'s card") end
                dump("15d_goodwill_hover")
                if hovered and not has_text_fn("They gave you") then problem("the Goodwill hover doesn't say what they gave you") end
                call(on_input, self, nil, { x = 4, y = 4 })
                -- Coffee (2h) is a one-on-one (A6): three questions, an answer to the worry, what you learned.
                local talker
                for _, p in ipairs(c.players) do
                    if p.present and pr:can_talk(p.key) and has_key("talk_" .. p.key) then
                        talker = p
                        break
                    end
                end
                if talker then
                    click_key("talk_" .. talker.key)
                    if not app.talk then problem("Coffee didn't open a one-on-one") end
                    local guard_t = 0
                    while app.talk and not app.talk.done and guard_t < 8 do
                        guard_t = guard_t + 1
                        if guard_t == 3 then dump("28_one_on_one") end
                        if not click_key("talk_opt_1") then problem("no answer to pick in the one-on-one"); break end
                    end
                    dump("28_one_on_one_done")
                    if not click_key("talk_done") then problem("the one-on-one has no Done button") end
                    if app.talk then problem("the one-on-one didn't close") end
                    local nt = pr.talk_notes and pr.talk_notes[talker.key]
                    if not (nt and nt.mood and nt.want) then problem("the one-on-one didn't note a mood and a want") end
                else
                    problem("nobody to have coffee with in week 2")
                end
            end
        elseif s.id:find("^world_") then
            local i = s.id:sub(7)
            local pick = ({ "world_let_", "world_hold_", "world_screen_" })[rng:int(1, 3)] .. i
            if not steps_mod.done(app, s) and not click_key(pick) then click_key("world_let_" .. i) end
            if week == 2 then dump_once("2x_world_move") end
        elseif s.id == "levelup" then
            if has_key("level_up") then
                click_key("level_up")
                close_all()
                if c:level_status().ready then problem("levelling up from its step didn't take") end
            end
        elseif s.id == "spotlight" then
            local opts = {}
            for _, b in ipairs(buttons()) do
                if b.key and b.key:find("^spot_") then table.insert(opts, b.key) end
            end
            if #opts > 0 then click_key(opts[rng:int(1, #opts)]) end
            if not steps_mod.done(app, s) then click_key("spot_none") end
        elseif s.id == "guests" then
            if rng:chance(0.5) then
                for _, b in ipairs(buttons()) do
                    if b.key and b.key:find("^guest_") then click(b) break end
                end
            end
        elseif s.id == "evening" then
            local books_mod = require "game.model.books"
            if week == 2 then
                -- An evening off draws cards.
                local before = 0
                for _, k in ipairs(content.kinds) do before = before + #pr.hand[k] end
                pr.inspirations = 0
                pr.inspired_by.novel = nil
                app.refresh()
                if not click_key("inspire_novel") then problem("no novel on the evening step (week 2)") end
                local after = 0
                for _, k in ipairs(content.kinds) do after = after + #pr.hand[k] end
                if after <= before then problem("inspiration drew no cards") end
            end
            if (week == 2 or week == 4) and books_mod.newest(c) then
                -- A new book (A13): the supplement evening opens it; pull an entry and see it in the game.
                pr.inspired_by.supplement = nil
                pr.inspirations = 0
                pr.reading = nil
                app.refresh()
                if not click_key("inspire_supplement") then problem("no supplement on the evening step in week " .. week) end
                if not app.book then problem("the supplement evening didn't open the new book (week " .. week .. ")") end
                local r = pr.reading
                local bk = r and books_mod.book(r.book)
                local want = week == 4 and "module" or "monster"
                local pick
                for _, e in ipairs(bk and bk.entries or {}) do
                    if e.kind == want and not books_mod.get(c).pulled[e.id] then
                        pick = pick or e
                    end
                end
                if pick then
                    click_key("book_entry_" .. pick.id)
                    dump("32_book_page_w" .. week)
                    if not click_key("book_pull") then problem("no Pull it in button") end
                    if not books_mod.get(c).pulled[pick.id] then problem("pulling " .. pick.id .. " did nothing") end
                    if pick.card and not pr.inspired[pick.card.id] then problem("a pulled card isn't in the hand: " .. pick.card.id) end
                    if week == 4 and pick.module then module_pick = pick.module end
                end
                if not click_key("book_done") then problem("no Done reading button") end
                if app.book then problem("the book didn't close") end
            end
            if not steps_mod.done(app, s) then
                if rng:chance(0.4) then
                    for _, b in ipairs(buttons()) do
                        if b.key and b.key:find("^inspire_") then click(b) break end
                    end
                    close_all()
                end
                if not steps_mod.done(app, s) then click_key("evening_none") end
            end
        elseif s.id:find("^route_") then
            local i = tonumber(s.id:sub(7))
            local sc = pr.scenes[i]
            if week == 1 and i == 3 then
                -- An open scene (A15): the players choose. Sketch spots from Your places and suggestions.
                if not click_key("open_scene") then problem("no Open scene button on the route") end
                if not sc.open then problem("Open scene didn't open stop 3") end
                dump("29_open_scene")
                local tried = {}
                for _, tab in ipairs({ "places", "suggested", "hand" }) do
                    if click_key("loc_tab_" .. tab) then
                        for _ = 1, 8 do
                            if #(sc.spots or {}) >= 2 then break end
                            local hit
                            for _, b in ipairs(buttons()) do
                                if b.key and b.key:find("^hand_") and b.key ~= "hand_prev" and b.key ~= "hand_next" and not tried[b.key] then
                                    hit = b
                                    break
                                end
                            end
                            if not hit then break end
                            tried[hit.key] = true
                            click(hit)
                            if app.ask then click_key("ask_no") end
                        end
                    end
                end
                dump("29_open_scene_spots")
                if #(sc.spots or {}) == 0 then problem("couldn't sketch any spots on the open scene (left " .. tostring(pr:left()) .. ")") end
            elseif not steps_mod.done(app, s) then
                -- (The random clicks may have made it an open scene with nothing sketched: back to a place.)
                if sc.open then click_key("open_scene") end
                if not sc.open and not sc.module then map_stop(i) end
            end
            -- A card that happens at the stop's place goes onto it from the place's card.
            local loc = sc.slots.location
            if week == 2 and loc and not sc.open and not sc.module then
                for _, hc in ipairs(valley.cards_for(pr, loc.id)) do
                    if not sc.slots[hc.kind] and pr:can_place(i, hc.id) then
                        local node = valley.node_of(loc.id)
                        click_key("pin_" .. node)
                        if node ~= loc.id then click_key("hub_place_" .. loc.id) end
                        if not click_key("here_" .. hc.id) then
                            problem("no row for " .. hc.id .. " on " .. loc.id .. "'s card")
                        elseif not (sc.slots[hc.kind] and sc.slots[hc.kind].id == hc.id) then
                            problem("clicking " .. hc.id .. " on " .. loc.id .. "'s card didn't put it on stop " .. i)
                        end
                        dump_once("2q_place_card_stop")
                        click_key("place_close")
                        break
                    end
                end
            end
            if i == 3 or i == #pr.scenes then
                -- Every stop with a place is numbered on the map.
                for k, sk in ipairs(pr.scenes) do
                    local l = sk.slots.location
                    if l and not sk.open then
                        local node = app.valley_map and app.valley_map.by_id[valley.node_of(l.id)]
                        if not (node and util_contains(node.stops, k)) then problem("stop " .. k .. " (" .. l.id .. ") isn't numbered on the map") end
                    end
                end
                if week == 1 or week == 3 then dump("2m_valley_route_w" .. week) end
                if week == 2 then
                    -- A place's card, opened from the map, says what it is; Millbrook's lists its places.
                    for _, nd in ipairs(app.valley_map and app.valley_map.nodes or {}) do
                        if not nd.hub and #nd.stops == 0 then
                            click_key("pin_" .. nd.id)
                            if not has_key("make_stop") then problem("a place's card has no Make it stop button (" .. nd.id .. ")") end
                            dump("2p_place_card")
                            click_key("place_close")
                            break
                        end
                    end
                    if click_key("pin_millbrook") then
                        dump("2h_town_card")
                        local nd = app.valley_map and app.valley_map.by_id.millbrook
                        local first = nd and nd.places[1]
                        if first then
                            if not click_key("hub_place_" .. first.id) then problem("no row for " .. first.id .. " on Millbrook's card") end
                            if not has_key("place_back") then problem("a town's place has no way back to the town") end
                        end
                        click_key("place_close")
                    else
                        problem("no Millbrook pin on the map")
                    end
                end
            end
        elseif s.id:find("^type_") then
            local i = tonumber(s.id:sub(6))
            if week == 4 and i == 3 and module_pick then
                -- A published adventure on stop 3: it fills the stop; its reward can be swapped.
                for k = 1, 3 do
                    for kind in pairs(pr.scenes[k].slots) do
                        if kind ~= "location" and pr:left() < 3 then pr:clear(k, kind) end
                    end
                end
                app.refresh()
                local can, why = pr:can_place_module(3, module_pick)
                if not can then
                    print("  (module step skipped: " .. tostring(why) .. ")")
                else
                    if not click_key("module_" .. module_pick) then problem("no module button on stop 3's kind of scene") end
                    if not (pr.scenes[3].module and pr.scenes[3].module.id == module_pick) then problem("the module didn't fill stop 3") end
                    dump("33_module_scene")
                end
            end
            if not steps_mod.done(app, s) or (week == 1 and i == 1) then
                local order = content.scenes.order
                local t = (week == 1 and i == 1) and "combat" or order[(week + i) % #order + 1]
                if not click_key("type_" .. i .. "_" .. t) then problem("no " .. t .. " on stop " .. i .. "'s kinds of scene") end
            end
        elseif s.id:find("^slot_") then
            local i, kind = s.id:match("^slot_(%d+)_(%a+)$")
            i = tonumber(i)
            local sc = pr.scenes[i]
            if sc.module then
                if week == 4 then dump_once("33b_module_" .. kind) end
            else
                if (week == 1 or week == 3) and i == 1 and kind == "cast" then dump("15b_prep_hand_w" .. week) end
                if (week == 1 or week == 3) and i == 2 and kind == "complication" then dump("15c_prep_hand_comp_w" .. week) end
                if not sc.slots[kind] and rng:chance(0.75) then
                    for _, b in ipairs(buttons()) do
                        local id = b.key and b.key:match("^hand_(.+)$")
                        if id and id ~= "prev" and id ~= "next" and not pr:placed_at(id) then
                            click(b)
                            break
                        end
                    end
                    if app.ask then click_key("ask_no") end
                end
                if not steps_mod.done(app, s) and not click_key("improvise_" .. kind) then problem("no Improvise on the " .. s.id .. " step") end
                -- A handout (game/model/handouts.lua) for a story card on a stop.
                local cur = sc.slots[kind]
                if (week == 1 or week == 3) and not did_handout and cur and require("game.model.handouts").worth_it(c, cur) then
                    did_handout = true
                    pr.extra = (pr.extra or 0) - 2      -- (time for it, whatever the random clicks spent)
                    app.refresh()
                    if not click_key("handout_toggle") then
                        problem("no handout button on a story card's slot (" .. kind .. ")")
                    elseif not (pr.handouts and pr.handouts[cur.id]) then
                        problem("making a handout didn't stick")
                    else
                        dump_once("15e_handout_made")
                    end
                end
            end
        elseif s.id:find("^fight_") then
            local i = tonumber(s.id:sub(7))
            if week == 1 and not did_encounter then
                did_encounter = true
                -- The encounter builder on a combat scene.
                if not click_key("fight_" .. i) then problem("no Build the fight button on a combat stop") end
                if app.overlay ~= "encounter" then problem("the fight button didn't open the builder") end
                dump("28_encounter_suggested")
                click_key("enc_add_ogre")
                click_key("enc_add_goblin_warrior")
                click_key("enc_lead_ogre")
                local enc = pr:encounter(i)
                if not enc.built or enc.ids[1] ~= "ogre" then problem("the builder didn't take the ogre as the lead: " .. table.concat(enc.ids, ",")) end
                -- A hazard on the mat (A10).
                if not click_key("enc_hazard_spreading_fire") then problem("no hazard buttons in the builder") end
                if pr:hazard(i) ~= "spreading_fire" then problem("the builder didn't set the hazard") end
                dump("28_encounter_built")
                -- The map (B9): lay a wall from the grid, then cover, a trap and the starts.
                if not click_key("enc_tab_map") then problem("no map tab in the builder") end
                local loc = pr.scenes[i].slots.location
                if not loc then
                    problem("no place on the combat stop to draw a map for")
                else
                    local map_view = require "game.ui.map_view"
                    click_key("map_piece_wall")
                    local maps = require "game.model.maps"
                    local LW = content.terrain_layout.W
                    for _, cell in ipairs({ { 10, 7 }, { 6, 3 }, { 14, 11 }, { 4, 10 }, { 16, 4 }, { 8, 12 } }) do
                        local m0 = maps.get(c, loc.id)
                        if m0 and maps.count(m0) > 0 then break end
                        for _, b in ipairs(buttons()) do
                            if b.key == "map_grid" then
                                local C = b.node.size.x / LW
                                local x, y = b.node.pos.x + (cell[1] - 0.5) * C, b.node.pos.y - (cell[2] - 0.5) * C
                                call(on_input, self, nil, { x = x, y = y })
                                call(on_input, self, "touch", { pressed = true, x = x, y = y })
                                break
                            end
                        end
                    end
                    local m = maps.get(c, loc.id)
                    if not m or maps.count(m) == 0 then problem("clicking the map grid laid no wall") end
                    for _, step in ipairs({ { "cover", 12, 4 }, { "cover", 13, 9 }, { "rough", 8, 6 }, { "trap", 9, 8 },
                                            { "party", 3, 7 }, { "foes", 17, 6 } }) do
                        app.map_piece = step[1]
                        map_view.paint(app, step[2], step[3])
                    end
                    for _, alt in ipairs({ { 4, 4 }, { 16, 9 }, { 5, 11 }, { 15, 3 }, { 10, 12 }, { 7, 2 }, { 13, 6 } }) do
                        local m1 = maps.get(c, loc.id)
                        for _, piece in ipairs({ "party", "foes", "trap" }) do
                            if m1 and not m1[piece] then
                                app.map_piece = piece
                                map_view.paint(app, alt[1], alt[2])
                                break
                            end
                        end
                    end
                    app.refresh()
                    click_key("map_trap")
                    m = maps.get(c, loc.id)
                    if not (m and m.party and m.foes and m.trap) then
                        problem("the map's starts or trap didn't stick (" .. loc.id .. ")")
                    end
                    local blocked = maps.layout(m)
                    local walls = 0
                    for _, p in ipairs(m.props) do
                        if p.kind == "stone_wall" or p.kind == "wall_room" then
                            walls = walls + (blocked[p.x * 1000 + p.y] and 1 or 0)
                        end
                    end
                    if walls == 0 then problem("the map's walls don't block") end
                    dump("28b_map")
                    click_key("map_template_ruins")
                    if maps.get(c, loc.id).template ~= "ruins" then problem("the template didn't change") end
                    click_key("enc_tab_fight")
                end
                click_key("enc_done")
                if app.overlay then problem("the builder wouldn't close") end
            end
        elseif s.id == "seed" then
            if week == 1 then
                local id = pr.seed_ideas[1]
                if not pr.planted then
                    if pr:left() < 1 then pr.extra = (pr.extra or 0) - 1 end
                    app.refresh()
                    if not click_key("seed_" .. id) then problem("no seed card for " .. tostring(id) .. " (left " .. pr:left() .. ")") end
                    if pr.planted ~= id then problem("clicking a seed didn't plant it") end
                end
                dump("15_prep_drawer")
            elseif not steps_mod.done(app, s) and rng:chance(0.5) then
                for _, b in ipairs(buttons()) do
                    if b.key and b.key:find("^seed_") and b.key ~= "seed_none" then click(b) break end
                end
            end
            if not steps_mod.done(app, s) then click_key("seed_none") end
            if week == 2 and next(pr.payoffs) == nil then problem("the week 1 seed's payoff card isn't in the hand") end
        elseif s.id == "ready" then
            dump("2r_ready_w" .. week)
        end
        close_all()
        s = steps_mod.current(app, ps.flow)
        if not steps_mod.done(app, s) then
            local t = {}
            for i, sc in ipairs(pr.scenes) do
                table.insert(t, i .. ":" .. tostring(sc.type) .. (sc.open and "(open)" or "") .. (sc.module and "(module)" or ""))
            end
            dump("x_prep_stuck")
            problem("couldn't answer prep's " .. s.id .. " step in week " .. week .. " (" .. table.concat(t, " ") .. ")")
            break
        end
        if s.id == "ready" then break end
        -- Once a week, back and on again; Enter goes on as well as Next.
        if n == 3 then
            click_key("step_back")
            if steps_mod.current(app, ps.flow).id == s.id then problem("Back didn't go back in prep") end
            click_key("step_next")
            if steps_mod.current(app, ps.flow).id ~= s.id then problem("Next after Back didn't come back to " .. s.id) end
        end
        if n % 4 == 0 then key("confirm") else click_key("step_next") end
    end
    if steps_mod.current(app, ps.flow).id ~= "ready" then problem("prep never got to the ready step in week " .. week) break end
    if not pr:ready() then problem("prep isn't ready on the ready step in week " .. week) break end
    -- Chill mode (October 26): off, no faces on the kinds of scene; on, they're back.
    if week == 1 then
        local prefs = require "game.ui.prefs"
        prefs.set_chill(false)
        ps.go(app, "type_2")
        local function faces_shown()
            for _, nd in ipairs(order) do
                if nd.alive and nd.enabled and nd.image and string.find(nd.image, "^face_") and nd.size.x <= 22 then return true end
            end
            return false
        end
        if faces_shown() then problem("the like-it faces show with Chill mode off") end
        if not click_key("chill_mode") then problem("no Chill mode switch on prep's steps") end
        if not prefs.chill() then problem("the Chill mode switch didn't turn it on") end
        dump("2c_chill_on")
        if not faces_shown() then problem("Chill mode on shows no faces on the kinds of scene") end
        click_key("chill_mode")
        if prefs.chill() then problem("the Chill mode switch didn't turn it off") end
        ps.go(app, "ready")
    end
    if week == 2 then
        -- Changing course (A18): on the notebook's campaign page, pick another style, ask the
        -- table, then nudge: the gateway card goes into this week's hand.
        key("next_cell")
        if app.overlay ~= "notes" then problem("N didn't open the notes in week 2") end
        if click_key("notes_tab_campaign") then
            local styles_mod = require "game.model.styles"
            local home = styles_mod.current(c)
            local target
            for _, sid in ipairs(styles_mod.data().order) do
                if sid ~= home and not target then target = sid end
            end
            if not click_key("course_style_" .. target) then problem("no course style button for " .. target) end
            local chat_before = #(c.chat or {})
            local co = c.course or {}
            if not (co.target == target and co.asked) then
                if not click_key("course_ask") then problem("no Ask the table button") end
                if #(c.chat or {}) <= chat_before then problem("asking the table posted nothing") end
            end
            co = c.course or {}
            if not (co.target == target and (co.nudge or co.force)) and not click_key("course_nudge") then
                problem("no Nudge button")
            end
            local nudge = c.course and (c.course.nudge or c.course.force)
            if not (nudge and pr:pinned(nudge)) then problem("the nudge card isn't in the hand") end
            dump("31_change_course")
        else
            problem("no campaign tab in the notes")
        end
        key("next_cell")
    end
    -- The Story log panel: look, then close it.
    if app.debug then key("debug") end     -- (the numbers overlay would hide the panel in the dumps)
    if app.story_panel then
        dump("15s_story_panel_w" .. week)
        if not click_key("story_panel_close") then problem("no Close on the Story log panel") end
        if app.story_panel then problem("the Story log panel didn't close") end
    end
    -- S opens the panel on the most pressing storyline; a keyword in it explains itself on hover.
    if week == 3 then
        key("story")
        if not app.story_panel then problem("S didn't open the Story log panel on the prep board") end
        dump("15t_story_panel_s")
        local hovered
        for _, b in ipairs(buttons()) do
            if string.sub(b.key or "", 1, 3) == "kw_" and b.rect_hit then
                local x, y = center(b)
                call(on_input, self, nil, { x = x, y = y })
                hovered = b
                break
            end
        end
        if not hovered then problem("no keywords lit in the Story log panel") end
        dump("15u_story_keyword_hover")
        if hovered and not (app.story_hover and #app.story_hover.nodes > 0) then problem("hovering a Story log keyword showed nothing") end
        call(on_input, self, nil, { x = 4, y = 4 })
        -- The storyline's name: the whole story at a glance.
        local titled
        for _, b in ipairs(buttons()) do
            if b.key == "story_panel_title" then
                local x, y = center(b)
                call(on_input, self, nil, { x = x, y = y })
                titled = true
                break
            end
        end
        if not titled then problem("no title to point at on the Story log panel") end
        dump("15v_story_glance")
        if titled and not has_text_fn("AT A GLANCE") then problem("pointing at a storyline's name didn't show it at a glance") end
        call(on_input, self, nil, { x = 4, y = 4 })
        key("story")
        if app.story_panel then problem("S didn't close the Story log panel") end
    end
    if week == 3 then
        -- One way into the notes on the board (October 20): the Notes button, as on game night.
        if not click_key("prep_notes") then problem("no Notes button on the prep board") end
        if app.overlay ~= "notes" then problem("the Notes button didn't open the notes") end
        key("next_cell")
        if has_key("notes_open") then problem("the story beat is still a second way into the notes") end
        key("next_cell")
        if app.overlay ~= "notes" then problem("N didn't open the notes in week 3") end
        if has_text_fn("Storylines") and has_key("notes_tab_threads") then problem("the Storylines tab is back") end
        for _, t in ipairs(require("game.ui.notes_view").TABS) do
            if not click_key("notes_tab_" .. t[1]) then problem("no notes tab " .. t[1]) end
            dump("30_notes_w3_" .. t[1])
        end
        key("next_cell")
    end
    if week == 1 then
        -- The real-session pass: the DM's notes (N), every tab; every character sheet, both pages.
        key("next_cell")
        if app.overlay ~= "notes" then problem("N didn't open the notes on the prep board") end
        for _, t in ipairs(require("game.ui.notes_view").TABS) do
            local tab = t[1]
            if not click_key("notes_tab_" .. tab) then problem("no notes tab " .. tab) end
            dump("26_notes_" .. tab)
        end
        if not click_key("notes_sheet_mara") then problem("no sheet button on the party page") end
        if app.overlay ~= "sheet" then problem("the party page didn't open a sheet") end
        for _, who in ipairs({ "dev", "jess", "sam", "mara" }) do
            click_key("sheet_who_" .. who)
            click_key("sheet_page_sheet")
            dump("27_sheet_" .. who)
            click_key("sheet_page_features")
            dump("27_sheet_" .. who .. "_features")
        end
        key("back")
        if app.overlay then problem("Esc didn't close the sheet") end
        -- Dialogue review (F4): work a few cells by keyboard and mouse.
        local lib = content.dialogue
        local function count(status)
            local n = 0
            for _, l in ipairs(lib.lines) do if l.status == status then n = n + 1 end end
            return n
        end
        local drafts = count("draft")
        key("review")
        if not (app.review and app.review.queue_open) then problem("F4 didn't open the review queue") end
        key("approve"); key("down"); key("reject"); key("edit")
        call(on_input, self, "text", { text = " Okay!" })
        key("backspace")
        key("confirm")
        key("next_cell"); key("prev_cell"); key("confirm")
        dump("11_review_queue")
        if not click_label("Next cell") then problem("no Next cell button in the queue") end
        if not click_label("Approve") then problem("no Approve button in the queue") end
        key("edit"); key("log"); call(on_input, self, "text", { text = "x" }); key("back")
        if count("approved") < 2 or count("rejected") < 1 or count("edited") < 1 then
            problem(string.format("review keys didn't land: approved %d rejected %d edited %d", count("approved"), count("rejected"), count("edited")))
        end
        if count("draft") >= drafts then problem("review left the drafts untouched") end
        key("back")
        if app.review.queue_open then problem("Esc didn't close the review queue") end
        if not app.review.on then problem("closing the queue turned review mode off") end
        stats.reviewed = drafts - count("draft")
        ps.go(app, "slot_2_cast")
        dump("2_prep")
        ps.go(app, "type_1")
        dump("3_prep_types")
        ps.go(app, "ready")
    end
    if not run_night_click() then problem("no run button") break end
    if app.screen ~= "night" then problem("expected night") break end
    if week == 2 then key("fast") end
    if week == 3 then key("sandbox"); key("sandbox") end
    local guard = 0
    if week == 3 then key("timer") end
    -- Review mode stays on after the queue closes, so the rail follows into the night.
    if week == 2 and not (app.review and app.review.on) then key("review") end
    if week == 4 then key("timer"); key("dm_rolls") end
    while not app.night_done and guard < 6000 do
        guard = guard + 1
        if guard % 5 == 0 then
            local minis = {}
            for _, id in ipairs({ "dev", "mara", "jess", "sam", "npc", "f1", "f2", "f3", "f4", "f5", "f6", "f7", "f8" }) do
                if rng:chance(0.85) then minis[id] = { rng:next(), rng:next() } end
            end
            call(on_message, self, "anchors", { heads = { dev = { 0.2, 0.3 }, mara = { 0.45, 0.2 }, jess = { 0.6, 0.2 },
                sam = { 1.2, 0.3 } }, minis = minis }, "table")
        end
        if guard % 97 == 0 then key("log") end
        if week == 1 and guard == 150 and not app.pending and not app.rolling then
            local clock = app.night.clock
            key("next_cell")
            if app.overlay ~= "notes" then problem("N didn't open the notes on game night") end
            for _ = 1, 10 do call(update, self, 0.5) end
            if app.night.clock ~= clock then problem("game night kept going behind the notes") end
            dump("29_night_notes")
            key("next_cell")
            if app.overlay then problem("N didn't close the notes") end
            -- One Notes button on game night (October 20), and S still opens the Story log.
            if not has_key("night_notes") then problem("no Notes button on game night") end
            if has_key("night_stories") then problem("game night still has a second notes button") end
            key("story")
            if not (app.overlay == "notes" and app.notes_tab == "storylog") then problem("S didn't open the Story log on game night") end
            key("story")
            if app.overlay then problem("S didn't close the Story log") end
            if click_key("panel_sam") then
                if app.overlay ~= "sheet" then problem("clicking Sam's panel didn't open his sheet") end
                dump("29_night_sheet")
                key("back")
            end
        end
        if week == 2 and guard == 300 then
            if not app.layers.review_rail and not app.pending then problem("review rail not shown on game night") end
            dump("12_review_rail")
            -- Hovering the rail holds the night.
            if app.layers.review_rail and app.review.rail_hit and app.review.rail_hit[1] then
                local n = app.review.rail_hit[1]
                call(on_input, self, nil, { x = n.pos.x + 5, y = n.pos.y - 5 })
                if not app.review.hold then problem("hovering the rail didn't hold the night") end
                call(on_input, self, nil, { x = 5, y = 5 })
            end
            key("queue")
            if not app.review.queue_open then problem("Q didn't open the queue on game night") end
            key("back")
        end
        call(update, self, 0.4)
        if week == 1 and app.in_battle and app.floaters and #app.floaters >= 2 and not dumped_battle then
            dumped_battle = true
            dump("4b_night_battle")
        end
        -- The newcomer playtest (October 16): the fight shows the round and the boss's health with
        -- numbers; scenes and fights end on a card; rules words explain themselves on hover.
        if app.in_battle and app.hud then
            local boss
            for _, m in pairs(app.hud.minis or {}) do
                if m.boss and not m.gone then boss = m end
            end
            if boss and #(app.hud.order or {}) > 0 then
                stats.boss_bars = (stats.boss_bars or 0) + 1
                if not app.hud.boss_nodes then problem("a boss on the mat with no health bar") end
            end
        end
        if app.side and app.side.nodes and app.side.nodes[3] then
            local top = app.side.nodes[3].text or ""
            if string.find(top, "^SCENE") then
                stats.scene_cards = (stats.scene_cards or 0) + 1
                if not dumped_once.scene_card then
                    dumped_once.scene_card = true
                    dump("4f_scene_card")
                end
            elseif string.find(top, "^FIGHT OVER") then
                stats.fight_cards = (stats.fight_cards or 0) + 1
                if not dumped_once.fight_card then
                    dumped_once.fight_card = true
                    dump("4g_fight_card")
                end
            end
        end
        if app.log_open and not app.pending and not dumped_once.gloss and app.layers.log then
            local spot = app.layers.log.spots and app.layers.log.spots[1]
            if spot then
                dumped_once.gloss = true
                local r = spot.rect
                call(on_input, self, nil, { x = r[1] + r[3] / 2, y = H - (r[2] + r[4] / 2) })
                local open
                for _, l in ipairs(kit.layers) do
                    if l.name == "gloss_card" then open = l end
                end
                if not open then problem("pointing at a rules word in the log brought up no card") end
                dump("4h_gloss_card")
                call(on_input, self, nil, { x = 1590, y = 450 })
                for _, l in ipairs(kit.layers) do
                    if l.name == "gloss_card" then problem("the rules word's card stayed after the pointer left") end
                end
                stats.gloss = (stats.gloss or 0) + 1
            end
        end
        -- The read-aloud box (A9): the DM's narration has a look of its own.
        if app.caption and app.caption.read and app.caption.life > 0 and app.caption.age > 0.3 and not dumped_read then
            dumped_read = true
            dump("4c_night_read_aloud")
        end
        if week == 1 and app.bubbles and #app.bubbles >= 1 and app.caption and app.caption.life > 0
            and not app.in_battle and not dumped_talk then
            dumped_talk = true
            dump("4a_night_talk")
        end
        if rng:chance(0.1) and not (app.pending and app.pending.kind == "cinematic") then key("roll") end
        if app.rolling then
            stats.rolls = stats.rolls + 1
            call(on_message, self, "roll_result", { value = rng:d20() }, "dice")
        elseif app.pending then
            if week == 1 and app.pending.kind == "decision" and not dumped_decision then
                dumped_decision = true
                dump("4_night_decision")
            end
            -- Taking over (B8): the talk card and the boss's turn.
            if app.pending.kind == "decision" and app.pending.card and app.pending.card.type == "talk" then
                stats.talks = (stats.talks or 0) + 1
                if not dumped_takeover_talk then
                    dumped_takeover_talk = true
                    dump("4d_talk_as_npc")
                end
            end
            if app.pending.kind == "decision" and app.pending.card and app.pending.card.type == "boss" then
                stats.boss = (stats.boss or 0) + 1
                if not dumped_takeover_boss then
                    dumped_takeover_boss = true
                    dump("4e_boss_turn")
                end
            end
            if app.pending.kind == "improv" and not dumped_improv then
                dumped_improv = true
                dump("5_night_improv")
            end
            -- The clarity pass (October 16): the odds beside a DC, what you agreed at Session Zero,
            -- how bad a fight call could get, and the week's story on the improv hand, all on screen.
            local function shown(fragment)
                for _, n in ipairs(order) do
                    -- (a wrapped line breaks where a space was: the final roll's longer card)
                    if n.alive and n.text and string.find(string.gsub(n.text, "\n", " "), fragment, 1, true) then return true end
                end
                return false
            end
            local pv = app.pending
            if pv.kind == "roll_where" then
                stats.odds = (stats.odds or 0) + 1
                if not (shown("on the d20") or shown("natural 20 makes it") or shown("almost any roll")) then
                    problem("a big roll's card without the odds: " .. tostring(pv.text))
                end
                if pv.promise and not shown("You agreed at Session Zero") then problem("a big roll's Session Zero line isn't shown") end
            elseif pv.kind == "decision" and pv.card then
                if pv.card.danger then
                    stats.danger = (stats.danger or 0) + 1
                    if not shown(string.sub(pv.card.danger, 1, 24)) then problem("a fight call's danger line isn't shown") end
                    if stats.danger == 1 then dump("5c_danger_line") end
                end
                if pv.card.promise and not shown("You agreed at Session Zero") then problem("a rules call's Session Zero line isn't shown") end
            elseif pv.kind == "improv" and pv.cards then
                for _, cd in ipairs(pv.cards) do
                    if cd.story then
                        stats.story_cards = (stats.story_cards or 0) + 1
                        if not shown("This week's story") then problem("a story card on the improv hand isn't marked") end
                        break
                    end
                end
            end
            if app.progress and app.pip_nodes and #app.pip_nodes > 0 then
                stats.last_roll = (stats.last_roll or 0) + 1
                if not shown("final roll:") then problem("the scene's dots without the final roll's label") end
            end
            -- A rules word in a tip, or on a card, keeps its card up while you read it (the re-test,
            -- October 16: "improv hand" in the tip showed nothing).
            if not dumped_once.tip_word then
                local function find_spot()
                    local found, hidden
                    for _, l in ipairs({ app.guide_layer, app.layers.modal }) do
                        for _, sp in ipairs(l and l.spots or {}) do
                            -- (Not a word the tip panel sits over: that one can't be pointed at.)
                            local r = sp.rect
                            local panel = l ~= app.guide_layer and app.guide_layer and app.guide_layer.blockers
                                and app.guide_layer.blockers[1]
                            if panel and gui.pick_node(panel, r[1] + r[3] / 2, H - (r[2] + r[4] / 2)) then
                                hidden = true
                            else
                                found = found or sp
                            end
                        end
                    end
                    return found, hidden
                end
                local spot, hidden = find_spot()
                if not spot and hidden then
                    -- The tip sits over the card's words: read it, close it, then point.
                    click_key("guide_ok")
                    spot = find_spot()
                end
                if spot then
                    dumped_once.tip_word = true
                    local r = spot.rect
                    call(on_input, self, nil, { x = r[1] + r[3] / 2, y = H - (r[2] + r[4] / 2) })
                    for _ = 1, 5 do call(update, self, 0.2) end
                    local open
                    for _, l in ipairs(kit.layers) do
                        if l.name == "gloss_card" then open = l end
                    end
                    if not open then problem("a rules word on a card or tip lost its card while pointed at") end
                    dump("5b_card_word")
                    call(on_input, self, nil, { x = 1590, y = 450 })
                    stats.card_words = (stats.card_words or 0) + 1
                end
            end
            -- The opening (October 15): the world, slide by slide, then the briefing after the
            -- introductions; and the catch-up briefing when someone joins.
            if app.pending.kind == "cinematic" then
                local ev = app.pending
                local tag = ev.id .. "_w" .. week .. "_" .. tostring(app.cine_i)
                if not dumped_once[tag] then
                    dumped_once[tag] = true
                    dump("3c_" .. tag)
                end
                stats.cine = (stats.cine or 0) + 1
                stats.briefs = stats.briefs or {}
                if ev.id == "briefing" then stats.briefs[week] = true end
                local s = ev.slides and ev.slides[app.cine_i or 1]
                if not s then problem("a cinematic with no slide " .. tostring(app.cine_i)) end
                local fin = ev.slides and ev.slides[#ev.slides]
                local obj = require("game.model.lore").objective(app.campaign)
                if ev.id == "briefing" and not (fin and fin.where and (fin.first or not obj)) then
                    problem("the briefing doesn't end on where they are and what's first")
                end
                if ev.id == "briefing" and week == 1 and s and not (s.rows and #s.rows > 0) then
                    problem("the first briefing doesn't say what matters")
                end
                -- Every card fits on its paper (October 15: a catch-up ran off the bottom).
                if s and s.briefing then
                    local fit = require("game.ui.night_view").briefing_layout(s, 980)
                    if fit.h > 700 then problem("a briefing card too tall to fit (" .. math.floor(fit.h) .. ")") end
                end
                if week == 1 and ev.id == "opening" and #ev.slides < 4 then problem("the opening has only " .. #ev.slides .. " slides") end
                if not has_key("cine_next") then problem("a cinematic slide with no way on") end
                -- The log opened over a slide leaves the slide up (October 20: it blanked the card).
                if not dumped_once.cine_log then
                    dumped_once.cine_log = true
                    key("log")
                    if not has_key("cine_next") then problem("opening the log blanked a cinematic slide") end
                    key("log")
                    if not has_key("cine_next") then problem("closing the log blanked a cinematic slide") end
                end
            end
            stats.modals = stats.modals + 1
            -- The log stays out of the way (A11): with it open, a DC or ruling card sits beside it.
            if (app.pending.kind == "ruling" or app.pending.kind == "roll_where") then
                if not app.log_open and rng:chance(0.3) then key("log") end
                if app.log_open then
                    stats.docked = (stats.docked or 0) + 1
                    for _, b in ipairs(buttons()) do
                        if b.node.pos.x < 544 then
                            problem("a " .. app.pending.kind .. " card's button sits under the open log (x " .. b.node.pos.x .. ")")
                            break
                        end
                    end
                    if not dumped_docked then
                        dumped_docked = true
                        dump("34_log_docked")
                    end
                end
            end
            if week == 3 and rng:chance(0.3) then
                -- Let the gentle timer run out sometimes.
                for _ = 1, 30 do call(update, self, 2) if not app.pending then break end end
                if not app.pending then goto continue end
            end
            -- Seeds 1 and 5 sit through every card, a slide at a time (the others click anything).
            if app.pending.kind == "cinematic" and (SEED == 1 or SEED == 5) and click_key("cine_next") then goto continue end
            -- A player's pull (October 18): who, what, why, and the four answers with their costs.
            if app.pending.kind == "decision" and app.pending.card and app.pending.card.type == "skew" then
                local card = app.pending.card
                stats.pulls = (stats.pulls or 0) + 1
                for _, a in ipairs({ "follow", "park", "steer" }) do
                    if not has_key("pull_" .. a) then problem("a pull's card has no " .. a .. " answer") end
                end
                local weave
                for _, o in ipairs(card.options) do
                    if o.answer == "weave" then weave = o end
                end
                if not weave then
                    problem("a pull's card has no Weave it in")
                elseif weave.disabled then
                    if has_key("pull_weave") then problem("Weave it in can be pressed with nothing to tie it") end
                    if not shown("Nothing on this stop ties to it") then problem("a pull's card doesn't say why it can't be woven in") end
                elseif not shown("Ties in through") then
                    problem("Weave it in doesn't say what ties it in")
                end
                if not (shown("plan slips") and shown("buy-in") and shown("or it sours")) then
                    problem("a pull's answers don't say what they cost")
                end
                if not shown(card.text) then problem("a pull's card doesn't say why they pull") end
                dump_once("5p_pull_card")
                if weave and weave.disabled then
                    -- Pressing the number of an answer that can't be given does nothing.
                    local before = app.pending
                    local NUM = { "zoom_room", "zoom_table", "zoom_imagination", "zoom_dice", "key5", "key6" }
                    for i, o in ipairs(card.options) do
                        if o.disabled then call(on_input, self, NUM[i], { pressed = true }) end
                    end
                    if app.pending ~= before then problem("the number key of an answer that can't be given answered the card") end
                end
            end
            local bs = buttons()
            if #bs == 0 then problem("modal with no buttons: " .. app.pending.kind) break end
            if rng:chance(0.2) then key("debug") end
            click(bs[rng:int(1, #bs)])
        end
        ::continue::
        stats.max_nodes = math.max(stats.max_nodes, alive_count)
    end
    if week == 2 then key("review") end
    if not app.night_done then
        local last = {}
        for i = math.max(1, #(app.log or {}) - 3), #(app.log or {}) do
            table.insert(last, tostring(app.log[i] and (app.log[i].text or app.log[i][1])))
        end
        problem("night never finished (" .. guard .. " steps); pending " .. tostring(app.pending and app.pending.kind)
            .. ", rolling " .. tostring(app.rolling) .. ", last: " .. table.concat(last, " | "))
        break
    end
    if week == 1 then dump("6_night_done") end
    -- Every attack says why it landed or didn't (the newcomer playtest, October 16).
    do
        local fought, why, contradiction = false, false, nil
        local prev
        for _, e in ipairs(app.log or {}) do
            local t = e.text or ""
            if string.find(t, "^A fight!") then fought = true end
            if string.find(t, "against AC") then why = true end
            -- "misses X (10 vs AC 12)" then "hits X (10 vs AC 12)": the graze bug.
            if prev and string.find(prev, " misses ") and string.find(t, " hits ") and string.find(t, "against AC") then
                local tg1, a1, ac1 = string.match(prev, " misses (.-): %d+ [%+%-] %d+ = (%d+) against AC (%d+)")
                local tg2, a2, ac2 = string.match(t, " hits (.-): %d+ [%+%-] %d+ = (%d+) against AC (%d+)")
                if tg1 and tg1 == tg2 and a1 == a2 and ac1 == ac2 then contradiction = prev .. " / " .. t end
            end
            prev = t
        end
        if fought and not why then problem("a fight with no attack explained in the log") end
        if contradiction then problem("a miss then a hit on the same roll: " .. contradiction) end
    end
    -- Gifts from the table: one player's Goodwill is full, so they bring something tonight.
    local keepsakes = require "game.model.keepsakes"
    if week == 1 then
        -- (Everyone's, so a bad night for one of them can't empty it below full.)
        app.campaign.keepsakes = { goodwill = {}, given = {} }
        for _, p in ipairs(app.campaign.players) do
            if p.present then
                app.campaign.keepsakes.goodwill[p.key] = keepsakes.data.FULL
            end
        end
    end
    if not click_label("See how everyone felt") then problem("no report button") break end
    if app.screen ~= "report" then problem("expected report") break end
    if week == 1 and not keepsakes.waiting(app.campaign) then problem("a full heart brought no gift") end
    take_gift(" (week " .. week .. ")", week)
    -- Behind the screen (October 18): who moved the story, every pull and your call.
    do
        local rp = app.campaign.report.pulls
        if not rp then problem("the report has no hidden layer") end
        if click_key("report_tab_behind") then
            if not has_text_fn("WHO MOVED THE STORY") then problem("the report's second tab isn't called Who moved the story") end
            if not has_text_fn("Moved the story") then problem("Behind the screen doesn't show who moved the story") end
            for _, e in ipairs(rp and rp.pulls or {}) do
                if not has_text_fn("Pulled toward " .. e.name) then problem("Behind the screen leaves out the pull toward " .. e.name) end
            end
            if rp and #rp.pulls > 0 then dump_once("7p_report_behind") end
            click_key("report_tab_felt")
            if not has_text_fn("HOW THE TABLE FELT") then problem("no way back from Behind the screen") end
        else
            problem("the report has no Behind the screen tab")
        end
    end
    if week == 1 then
        dump("7_report")
        -- The recap is the DM's (B7): another title, pin a beat, cut one, write a note.
        local r = app.campaign.report.recap
        if not r or #r.beats == 0 then problem("the report has no recap") end
        if r and #r.titles > 1 then
            click_key("recap_title")
            if r.title ~= 2 then problem("Other title didn't change the title") end
        end
        if r and r.beats[1] then
            click_key("recap_pin_1")
            if not r.beats[1].pinned then problem("pinning a recap beat didn't stick") end
        end
        if r and r.beats[2] then
            click_key("recap_cut_2")
            if not r.beats[2].cut then problem("cutting a recap beat didn't stick") end
        end
        click_key("recap_note")
        call(on_input, self, "text", { text = "Mara needs more story." })
        call(on_input, self, "backspace", { pressed = true })
        if r and r.note ~= "Mara needs more story" then problem("typing the DM's note: '" .. tostring(r and r.note) .. "'") end
        key("confirm")
        if app.report_note then problem("Enter didn't finish the note") end
        if app.screen ~= "report" then problem("Enter while typing the note left the report") end
        local log = app.campaign.session_log or {}
        if not (log[#log] and log[#log].week == 1 and log[#log].recap == r) then problem("the report never reached the session log") end
        dump("7a_report_edited")
        if click_key("snapshot_1") then
            if not app.snapshot_view then problem("Look didn't open the snapshot") end
            dump("7b_snapshot")
            if not click_key("snapshot_back") then problem("no way back from a snapshot") end
            if app.snapshot_view then problem("Back didn't close the snapshot") end
        end
        -- The notebook's session log reopens it.
        key("next_cell")
        if click_key("notes_tab_log") then
            dump("7c_session_log")
            if not has_text_fn("Mara needs more story") then problem("the session log doesn't show the note") end
        else
            problem("no Session log tab in the notebook")
        end
        key("back")
        -- Push the spotlight conflict live so week 2 has messages to answer.
        social.push(app.campaign, "spotlight", 80)
    end
    if week == 2 then
        local c = app.campaign
        if not c:level_status().ready then problem("no level-up after two nights") end
        if not click_key("level_up") then problem("no level-up button on the report") end
        if c.level ~= 3 then problem("level-up didn't happen") end
        for _, p in ipairs(c.players) do
            if not (c.picks[p.key] and c.subclasses[p.class]) then problem(p.key .. " didn't pick a subclass") end
        end
        dump("16_levelup")
        if not has_text_fn("LEVEL 3!") then problem("level-up moment not shown") end
        key("back")
        if app.levelup then problem("Esc didn't close the level-up moment") end
        dump("17_report_after_levelup")
    end
    stats.max_nodes = math.max(stats.max_nodes, alive_count)
    if not leave_report("") then break end
    stats.weeks = stats.weeks + 1
    if app.screen == "slice_end" then
        -- The end of the slice: scrapbook, survey, thanks, keep playing.
        dump("19_slice_scrapbook")
        if #app.campaign.journal ~= app.campaign.week then problem("the journal missed a week") end
        -- The table awards: one each, all different.
        local titles = {}
        for _, p in ipairs(app.campaign.players) do
            local a = app.awards and app.awards[p.key]
            if not a then
                problem("no table award for " .. p.name)
            elseif titles[a.title] then
                problem("two players got the same award: " .. a.title)
            elseif not has_text_fn(a.title) then
                problem("the award isn't on the scrapbook: " .. a.title)
            end
            titles[a and a.title or "?"] = true
        end
        if not click_key("to_survey") then problem("no survey button on the scrapbook") end
        dump("20_survey_empty")
        if click_key("save_survey") then problem("the survey saved with nothing answered") end
        for _, q in ipairs({ "satisfying", "payoff", "homework", "gut" }) do
            click_key("q_" .. q .. "_" .. rng:int(1, 5))
        end
        click_key("q_next_" .. rng:int(1, 3))
        click_key("text_drag")
        call(on_input, self, "text", { text = "Prep in week 3 dragged a bit." })
        call(on_input, self, "backspace", { pressed = true })
        call(on_input, self, "text", { text = "!" })
        click_key("text_favourite")
        call(on_input, self, "text", { text = "Pip and the innkeeper." })
        if app.slice.answers.text.drag ~= "Prep in week 3 dragged a bit!" then
            problem("typing into the survey: '" .. tostring(app.slice.answers.text.drag) .. "'")
        end
        dump("21_survey_filled")
        local before = io.open(save):read("*a")
        if not click_key("save_survey") then problem("couldn't save the survey") end
        local after = io.open(save):read("*a")
        if not string.find(after, '"type":"slice_survey"', #before - 5, true) then problem("the survey never reached the playtest log") end
        if not string.find(after, "Pip and the innkeeper.", 1, true) then problem("free-text answer missing from the log") end
        dump("22_thanks")
        if not click_key("keep_playing") then problem("no keep-playing button") end
        if app.screen ~= "prep" then problem("keep playing didn't start week " .. (app.campaign.week)) end
    end
end

-- Hard times: someone wavering, someone on a break, someone drifting, a perceptive DM,
-- and somebody leaving after the night. Every one of these must draw without errors.
local function has_text(fragment)
    for _, n in ipairs(order) do
        if n.alive and n.text and string.find(n.text, fragment, 1, true) then return true end
    end
    return false
end
if app.screen == "prep" and #problems == 0 then
    local c = app.campaign
    c.empathy_xp = 30
    local mara, dev, jess, sam = c:player("mara"), c:player("dev"), c:player("jess"), c:player("sam")
    mara.wavering, mara.present = 1, false -- wavering and away: the warning must still show
    dev.on_break, dev.break_left, dev.present = true, 4, false
    jess.commitment, jess.delta.commitment = 30, -4
    require("game.ui.prep_steps").go(app, "friends")
    dump("8_prep_hard_times")
    if not has_text("losing steam") then problem("wavering warning not shown") end
    if not has_text("drifting away") then problem("early warning not shown at high Empathy") end
    if not has_text("Taking a break") then problem("on-break card not shown") end
    local xp = c.empathy_xp
    if not click_label("Check in") then problem("no check-in button") end
    if dev.break_left ~= 2 then problem("check-in didn't shorten the break (" .. tostring(dev.break_left) .. ")") end
    if c.empathy_xp <= xp then problem("check-in gave no Empathy") end
    for i = 1, 3 do
        if not c.prep.scenes[i].type then c.prep:set_type(i, "social") end
    end
    app.refresh()
    sam.commitment, sam.wavering = 5, 3
    if not run_night_click() then problem("no run button (hard times)") end
    local guard = 0
    while app.screen == "night" and not app.night_done and guard < 8000 do
        guard = guard + 1
        call(update, self, 0.4)
        if app.rolling then
            call(on_message, self, "roll_result", { value = rng:d20() }, "dice")
        elseif app.pending then
            local bs = buttons()
            -- The improv hand needs a card picked, then Play.
            if not click_label("Play") and #bs > 0 then click(bs[1]) end
        end
    end
    if not app.night_done then problem("hard-times night never finished (" .. guard .. " steps)") end
    if not click_label("See how everyone felt") then problem("no report button (hard times)") end
    dump("9_report_hard_times")
    if not has_text("need a break") then problem("leaving banner not shown on the report") end
    if not has_text("On a break") then problem("on-break column not shown on the report") end
    if not sam.on_break then problem("Sam should be on a break after wavering at Commitment 5") end
    leave_report(" (hard times)")
    dump("10_prep_after_leaving")
    local said = false
    for _, m in ipairs(c.chat) do
        if m.key == "sam" and m.line and string.find(m.line, "^chat_leaving%.") then said = true end
    end
    if not said then problem("Sam didn't say goodbye in the group chat") end
    stats.weeks = stats.weeks + 1
end

-- Saving between sessions (M7): the game saves after every night and before every prep,
-- and a fresh start of the game offers to carry on from there.
local save_mod = require "game.model.save"
local function restart()
    -- A new run of the game: init again, as if it had been closed and opened.
    self = {}
    call(init, self)
    app = self.app
end
local function play_resumed_night(where)
    local c = app.campaign
    for i = 1, 3 do
        if not c.prep.scenes[i].type then c.prep:set_type(i, "social") end
    end
    app.refresh()
    if not run_night_click() then problem("no run button" .. where) return end
    local guard = 0
    while app.screen == "night" and not app.night_done and guard < 8000 do
        guard = guard + 1
        call(update, self, 0.4)
        if app.rolling then
            call(on_message, self, "roll_result", { value = rng:d20() }, "dice")
        elseif app.pending then
            local bs = buttons()
            if not click_label("Play") and #bs > 0 then click(bs[1]) end
        end
    end
    if not app.night_done then problem("night never finished" .. where) return end
    if not click_label("See how everyone felt") then problem("no report button" .. where) return end
    if leave_report(where) then stats.weeks = stats.weeks + 1 end
end
if #problems == 0 then
    local path = app.save_path
    local fh = path and io.open(path, "rb")
    local text = fh and fh:read("*a")
    if fh then fh:close() end
    local head = save_mod.peek(text)
    local was = app.campaign
    if not head then
        problem("no campaign save on disk after " .. stats.weeks .. " weeks")
    else
        -- Prep autosaves (A11): the save on disk is this week's board, mid-prep.
        if head.week ~= was.week or not head.at_prep then
            problem("the save is from week " .. head.week .. (head.at_prep and " (prep)" or "") .. ", expected week " .. was.week .. "'s prep")
        end
        local was_spent, was_left = was.prep and was.prep:spent(), was.prep and was.prep:left()
        if head.seed ~= was.seed then problem("the save has the wrong seed") end
        restart()
        dump("23_intro_continue")
        if not has_key("continue") then problem("the intro doesn't offer to continue a saved campaign") end
        if not has_key("new_campaign") then problem("the intro doesn't offer a new campaign next to Continue") end
        click_key("continue")
        if app.screen ~= "prep" then problem("continuing went to " .. tostring(app.screen) .. ", not prep") end
        if app.campaign.week ~= was.week then problem("continued at week " .. app.campaign.week .. ", expected " .. was.week) end
        if app.campaign == was then problem("continuing reused the old campaign table") end
        if app.campaign.prep and (app.campaign.prep:spent() ~= was_spent or app.campaign.prep:left() ~= was_left) then
            problem("continuing mid-prep didn't bring the same board back")
        end
        dump("24_prep_after_continue")
        play_resumed_night(" (after continuing)")
        -- The fix pass: quitting in the middle of game night keeps the board. The save made at
        -- "Run game night" brings back the same night, from its start.
        do
            local c = app.campaign
            if app.screen ~= "prep" then problem("not on prep before the mid-night quit (" .. tostring(app.screen) .. ")") end
            c.prep:set_type(1, "social"); c.prep:set_type(2, "combat"); c.prep:set_type(3, "mystery")
            app.refresh()
            local wk, spent = c.week, c.prep:spent()
            if not run_night_click() then problem("no run button before the mid-night quit") end
            for _ = 1, 30 do
                call(update, self, 0.4)
                if app.pending then break end
            end
            -- Number keys pick a card's options, and the open log scrolls under the wheel.
            if app.pending then
                local before = app.card_seq
                key("zoom_room")
                if app.pending and app.pending.kind ~= "improv" then problem("key 1 didn't answer the " .. app.pending.kind .. " card") end
            end
            key("log")
            for _ = 1, 4 do call(update, self, 0.4) end
            call(on_input, self, "zoom_in", { pressed = true, x = 200, y = 900 - 300 })
            if #app.log > 3 and (app.log_scroll or 0) == 0 then problem("the wheel didn't scroll the open log") end
            key("log")
            restart()
            local found = false
            for _, b in ipairs(buttons()) do
                if b.key == "continue" and string.find(label_of(b), "night", 1, true) then found = true end
            end
            if not found then problem("Continue doesn't say it goes back to game night") end
            click_key("continue")
            if app.screen ~= "night" then problem("continuing a mid-night quit went to " .. tostring(app.screen)) end
            if app.campaign.week ~= wk then problem("the mid-night quit came back at week " .. app.campaign.week .. ", not " .. wk) end
            local p2 = app.campaign.prep
            if not p2 or p2.scenes[2].type ~= "combat" or p2.scenes[3].type ~= "mystery" or p2:spent() ~= spent then
                problem("the board didn't survive the mid-night quit")
            end
            dump("24b_night_after_quit")
            local guard = 0
            while app.screen == "night" and not app.night_done and guard < 8000 do
                guard = guard + 1
                call(update, self, 0.4)
                if app.rolling then
                    call(on_message, self, "roll_result", { value = rng:d20() }, "dice")
                elseif app.pending then
                    -- Every other card by number key, the rest by clicking.
                    if guard % 2 == 0 and app.pending.kind ~= "improv" then
                        key("zoom_table")
                        if app.pending then key("zoom_room") end
                    else
                        local bs = buttons()
                        if not click_label("Play") and #bs > 0 then click(bs[1]) end
                    end
                end
            end
            if not app.night_done then problem("the night after the mid-night quit never finished") end
            if not click_label("See how everyone felt") then problem("no report button after the mid-night quit") end
            if leave_report(" (after the mid-night quit)") then stats.weeks = stats.weeks + 1 end
        end
        -- "New campaign" next to Continue asks first, then starts over (Enter would continue).
        restart()
        click_key("new_campaign")
        if app.screen ~= "intro" or not app.confirm_new then problem("one click on New campaign already started over") end
        if not has_text("Click again to start over") then problem("no note before starting over") end
        click_key("new_campaign")
        if app.screen ~= "setup" then problem("two clicks on New campaign didn't start setting up") end
        -- Stopped after the first act, before its survey: continuing goes back to the survey.
        if app.campaign.week >= content.arc.SESSIONS then
            local c = save_mod.load(save_mod.dump(app.campaign))
            c.slice_survey_done = nil
            local out = io.open(path, "wb")
            out:write(save_mod.dump(c))
            out:close()
            restart()
            click_key("continue")
            if app.screen ~= "slice_end" then problem("an unanswered first-act survey didn't come back on continue (" .. tostring(app.screen) .. ")") end
        end
        -- A save from some other build is refused politely.
        local out = io.open(path, "wb")
        out:write('F=2\nW=2\nS=1\nT[1]={"s","x","c",{"no_such_data"}}\n')
        out:close()
        restart()
        if not click_key("continue") then problem("no continue button for the broken save") end
        if app.screen ~= "intro" or not app.resume_error then problem("a broken save didn't stay on the intro with a note") end
        if has_key("continue") then problem("the broken save is still offered") end
        if not has_text("couldn't be opened") then problem("no note about the broken save") end
        if not has_key("session_zero") then problem("no way to start over after a broken save") end
        dump("25_intro_broken_save")
    end
end

-- Pinned layers (the tips): their panel swallows clicks meant for whatever is under it,
-- even with no tip button there; without the panel the same point reaches the button.
do
    local base = kit.layer("test_base")
    kit.button(100, 100, 200, 50, "Under", function() end, { key = "under" })
    local pin = kit.layer("test_pin", false, true)
    kit.into(pin, function()
        pin.blockers = { kit.box(80, 80, 260, 120, kit.rgba("#000000")) }
    end)
    if kit.hit(200, 900 - 125) then problem("a tip panel let a click through to the button under it") end
    pin.blockers = nil
    local b = kit.hit(200, 900 - 125)
    if not (b and b.key == "under") then problem("test setup: the button wasn't hit without the panel") end
    if kit.current == pin then problem("drawing into a pinned layer left it as the current layer") end
    kit.drop(pin)
    kit.drop(base)
end

-- The cozy layer (M7): sounds, the evening light and the snacks went out, and every sound
-- the game asks for is one the audio script knows.
do
    local known = {}
    local src = io.open("main/audio/audio.script"):read("*a")
    local block = string.match(src, "local SFX = (%b{})")
    for id in string.gmatch(block or "", "([%a_]+)%s*=") do known[id] = true end
    local coll = io.open("main/main.collection"):read("*a")
    local seen, by_url = {}, {}
    for _, p in ipairs(posted) do
        local url = tostring(p.url)
        by_url[url .. " " .. tostring(p.id)] = (by_url[url .. " " .. tostring(p.id)] or 0) + 1
        if url == "/audio#audio" and p.id == "sfx" then
            seen[p.m.id] = true
            if not known[p.m.id] then problem("asked for a sound the audio script doesn't have: " .. tostring(p.m.id)) end
        end
        local inst = string.match(url, "^/([%w_]+)#")
        if inst and not string.find(coll, 'id: "' .. inst .. '"', 1, true) then
            problem("posted to " .. url .. ", which isn't in main.collection")
        end
    end
    for _, id in ipairs({ "click", "dice", "card", "page" }) do
        if not seen[id] then problem("never played the " .. id .. " sound") end
    end
    for _, k in ipairs({ "/audio#audio music", "@render: mood", "/props#props mood", "/pizza#snacks eaten", "/pizza#snacks refill" }) do
        if not by_url[k] then problem("never sent " .. k) end
    end
end

local f = io.open(save)
local kinds = {}
if f then
    for line in f:lines() do
        -- (scenes on the board have a "type" too; the record's own type is one of these)
        local t = (string.find(line, '"type":"week_survey"', 1, true) and "week_survey")
            or (string.find(line, '"type":"slice_survey"', 1, true) and "slice_survey")
            or (string.find(line, '"type":"week"', 1, true) and "week") or "?"
        kinds[t] = (kinds[t] or 0) + 1
    end
    f:close()
end
if (kinds.week or 0) ~= stats.weeks then problem("playtest log has " .. tostring(kinds.week) .. " week records for " .. stats.weeks .. " weeks") end
if (kinds.week_survey or 0) ~= stats.weeks then problem("playtest log has " .. tostring(kinds.week_survey) .. " quick-question records for " .. stats.weeks .. " weeks") end
if WEEKS >= 4 and (kinds.slice_survey or 0) ~= 1 then problem("expected one slice survey in the log, got " .. tostring(kinds.slice_survey)) end
if kinds["?"] then problem(kinds["?"] .. " playtest log lines without a type") end
if (stats.cine or 0) == 0 then problem("session 1 never opened on the world") end
if (stats.scene_cards or 0) == 0 then problem("no scene ended on its card") end
if (stats.boss_bars or 0) > 0 and (stats.fight_cards or 0) == 0 then problem("fights with a boss, but none ended on its card") end
if (stats.gloss or 0) == 0 then problem("never found a rules word to point at in the log") end
if (stats.card_words or 0) == 0 then problem("never found a rules word to point at on a card or tip") end
if (stats.odds or 0) == 0 then problem("never saw a big roll's DC card") end
if (stats.lore or 0) < stats.weeks then problem("the lore screen showed " .. tostring(stats.lore or 0) .. " times in " .. stats.weeks .. " sessions") end
if (stats.last_roll or 0) == 0 then problem("never saw the scene's dots with the final roll's label") end
local briefs = stats.briefs or {}
if not briefs[1] then problem("no briefing after the introductions") end
if not FULL and not (briefs[2] and briefs[3]) then problem("no catch-up briefing when someone joined") end
if not briefs[2] then problem("session 2 didn't open on the recap card") end
os.remove(save)

print(string.format("seed %d: weeks %d, prep clicks %d, modals %d, rolls %d, lines reviewed %d, peak nodes %d/%d, messages %d",
    SEED, stats.weeks, stats.clicks, stats.modals, stats.rolls, stats.reviewed or 0, stats.max_nodes, MAX_NODES, #posted))
for _, path in pairs(other_saves) do os.remove(path); os.remove(path .. ".bak"); os.remove(path .. ".tmp") end
for _, p in ipairs(problems) do print("PROBLEM: " .. p) end
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
print(#problems == 0 and "GUI SMOKE OK" or (#problems .. " PROBLEMS"))
os.exit(#problems == 0 and 0 or 1)
