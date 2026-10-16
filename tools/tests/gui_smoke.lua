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
local function run_night_click()
    if not click_label("Run game night") then return false end
    local app = self.app
    if app.ask then
        for _, b in ipairs(buttons()) do
            if b.key == "ask_yes" then click(b); break end
        end
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
    click_key("join_start")
    if app.screen ~= "join" then problem("the join page let you on with nothing written" .. where) return end
    local backstory = require "game.model.backstory"
    for _, q in ipairs(backstory.data[key].questions) do
        click_key("bs_q_" .. q.id)
    end
    if backstory.asked(app.join.backstories) > backstory.data.JOIN_QUESTIONS then problem("a joiner got more questions than there's time for") end
    click_key(rng:chance(0.5) and "bs_idea_yes" or "bs_idea_no")
    click_key("join_ask_agree")
    local hooks = backstory.data[key].hooks
    if not click_key("bs_hook_" .. hooks[rng:int(1, #hooks)].card) then problem("no hook buttons on the join page" .. where) end
    dump_once("1h_join_done_" .. tostring(key))
    if not click_key("join_start") then problem("no welcome button on the join page" .. where) return end
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
        if app.screen ~= "planner" then problem("expected the planner, got " .. tostring(app.screen)) end
        dump("1a_planner")
        -- Click a few truths and threads around, then go on with whatever's picked (or the defaults).
        for _ = 1, 6 do
            local bs = random_buttons()
            local pick = bs[rng:int(1, #bs)]
            if pick and pick.key ~= "plan_done" then click(pick) end
        end
        -- Every few seeds, a campaign in another style (A18), with its truths and front.
        if SEED % 3 == 0 then
            local order = require("game.model.content").styles.order
            click_key("style_" .. order[(SEED / 3) % #order + 1])
        end
        -- Who's at the table (October 15): seeds 1 to 4 play all four, 5 and 6 start with two and
        -- welcome Jess (session 2) and Sam (session 3) on the join page.
        if not click_key(SEED >= 5 and "table_small" or "table_full") then problem("no table-size buttons in the planner") end
        dump("1a2_planner_picked")
        if not click_key("plan_done") then
            app.plan_choices = nil
            app.refresh()
            click_key(SEED >= 5 and "table_small" or "table_full")
            if not click_key("plan_done") then problem("the planner wouldn't go on with its defaults") end
        end
        if not (app.campaign.plan and #app.campaign.plan.truths == 3) then problem("the planner didn't lay down three truths") end
        if app.screen ~= "session_zero" then problem("expected Session Zero, got " .. tostring(app.screen)) end
        dump("1b_session_zero")
        -- The first-session tips: one shows, "Got it" moves to the next, and they stay clickable.
        if app.guide_step ~= "s0_pitch" or not has_key("guide_ok") then
            problem("no first tip on Session Zero (" .. tostring(app.guide_step) .. ")")
        else
            click_key("guide_ok")
            if app.guide_step ~= "s0_asks" then problem("Got it didn't move to the next tip (" .. tostring(app.guide_step) .. ")") end
            dump("1d_session_zero_tip")
        end
        if click_label("Backstories") or click_label("Start session 1") then problem("Session Zero let you go on with nothing decided") end
        -- Click around, then make sure every question has an answer.
        for _ = 1, 30 do
            local bs = random_buttons()
            local pick = bs[rng:int(1, #bs)]
            if pick and not string.find(label_of(pick), "Start session", 1, true) and not string.find(label_of(pick), "Backstories", 1, true) then click(pick) end
        end
        app.s0 = app.s0 or { asks = {}, rules = {} }
        app.s0.tone = app.s0.tone or "mixed"
        for _, k in ipairs({ "mara", "sam", "dev", "jess" }) do app.s0.asks[k] = app.s0.asks[k] or "agree" end
        app.s0.rules.xcard = app.s0.rules.xcard or "on"
        app.s0.rules.dice = app.s0.rules.dice or "big_open"
        app.s0.rules.rulings = app.s0.rules.rulings or "quick"
        app.s0.rules.length = app.s0.rules.length or "half"
        -- When a hero dies (B3): click it, so the compact row is exercised.
        if not app.s0.rules.death and not click_key("rule_death_cost") then problem("no death rule buttons in Session Zero") end
        app.s0.rules.death = app.s0.rules.death or "cost"
        app.refresh()
        dump("1c_session_zero_done")
        -- Their backstories (October 13): a page of their own.
        if not click_label("Backstories") then problem("no way on to the backstories after Session Zero") end
        if not (app.s0 and app.s0.page == "backstories") then problem("the backstories page didn't open") end
        dump("1e_backstories")
        if click_label("Start session 1") and app.screen ~= "session_zero" then problem("Session Zero started with no backstories written") end
        if app.guide_step ~= "s0_backstories" then problem("no tip on the backstories page (" .. tostring(app.guide_step) .. ")") end
        local backstory = require "game.model.backstory"
        if SEED >= 5 and #app.campaign.players ~= 2 then problem("a small table should start with two, not " .. #app.campaign.players) end
        if SEED < 5 and #app.campaign.players ~= 4 then problem("a full table should start with four, not " .. #app.campaign.players) end
        for _, k in ipairs(app.campaign:table_keys()) do
            if not click_key("bs_tab_" .. k) then problem("no backstory tab for " .. k) end
            -- Ask everything: the evening runs out of questions, and the button says so.
            for _, q in ipairs(backstory.data[k].questions) do
                click_key("bs_q_" .. q.id)
            end
            if rng:chance(0.5) then click_key("bs_idea_yes") else click_key("bs_idea_no") end
            local hooks = backstory.data[k].hooks
            if not click_key("bs_hook_" .. hooks[rng:int(1, #hooks)].card) then problem("no hook buttons for " .. k) end
            dump("1f_backstory_" .. k)
        end
        if backstory.asked(app.s0.backstories) > backstory.data.QUESTIONS then problem("more questions asked than the evening has") end
        if backstory.left(app.s0.backstories) ~= 0 then problem("asking everything left questions over") end
        local written = app.s0.backstories
        if not click_label("Start session 1") then problem("no start button after the backstories") end
        local last_key = app.campaign:table_keys()[#app.campaign:table_keys()]
        if not (app.campaign.backstories and app.campaign.backstories[last_key] and app.campaign.backstories[last_key].hook) then
            problem("the backstories weren't written into the campaign")
        end
        if SEED >= 5 and app.campaign.table.asks.jess then problem("Session Zero settled the ask of someone who isn't there yet") end
        -- What turns up first waits at the front of the first hand.
        for k, ch in pairs(written or {}) do
            local p = app.campaign:player(k)
            if p and p.present and not (app.campaign.prep and app.campaign.prep:pinned(ch.hook)) then
                problem("week 1's hand doesn't hold " .. k .. "'s hook (" .. tostring(ch.hook) .. ")")
            end
        end
        if not (app.campaign.table and app.campaign.table.held) then problem("Session Zero didn't settle the table") end
    end
    if app.screen ~= "prep" then problem("expected prep, got " .. tostring(app.screen)) break end
    if week == 1 then
        if not (app.campaign.guide and app.campaign.guide.seen.s0_pitch) then problem("Session Zero tips weren't kept in the campaign") end
        if app.guide_step ~= "prep_story" then problem("the first prep doesn't open with its tip (" .. tostring(app.guide_step) .. ")") end
        dump("2b_prep_tip")
    end
    -- Each week's board as it opens, before anything's clicked (the story review reads these).
    if week >= 2 and week <= 4 then
        dump_once("2w" .. week .. "_prep")
    end
    -- Random clicking on the prep board, then make sure it's ready.
    for i = 1, 60 do
        local bs = random_buttons()
        local pick = bs[rng:int(1, #bs)]
        if pick and not string.find(label_of(pick), "Run game night", 1, true) then
            click(pick)
            stats.clicks = stats.clicks + 1
        end
        if i == 20 then key("debug") end
        if i == 40 then key("debug") end
        stats.max_nodes = math.max(stats.max_nodes, alive_count)
    end
    if app.overlay then
        -- Random clicks opened the notes, a sheet or the encounter builder: close it like a player would.
        local was = app.overlay
        if not (click_key("notes_close") or click_key("sheet_close") or click_key("enc_done")) then
            problem("no way to close the " .. was)
        end
        if app.overlay then problem(was .. " wouldn't close") end
    end
    if app.convo then
        click_label("Close"); click_label("Done")
        if app.convo then problem("conversation modal wouldn't close") end
    end
    if app.levelup then click_label("Back to the table") end
    if app.levelup then problem("level-up modal wouldn't close") end
    if week == 1 then
        app.sel = nil
        app.refresh()
        local c = app.campaign
        if not c.prep.planted then
            local id = c.prep.seed_ideas[1]
            if c.prep:left() < 1 then c.prep.extra = c.prep.extra - 1 end
            app.refresh()
            if not click_key("seed_" .. id) then
                local keys = {}
                for i = #kit.layers, 1, -1 do
                    for _, b in ipairs(kit.layers[i].buttons) do
                        table.insert(keys, tostring(b.key) .. (b.enabled and "" or "(off)"))
                    end
                end
                problem("no seed button in the drawer for " .. tostring(id) .. " (left " .. c.prep:left() .. "): " .. table.concat(keys, " "))
            end
            if c.prep.planted ~= id then problem("clicking a seed didn't plant it") end
        end
        dump("15_prep_drawer")
    end
    if week == 2 then
        local c = app.campaign
        app.sel = nil
        app.convo = nil
        app.refresh()
        -- The seed from week 1 is ready to pay off: its card is in the hand.
        if next(c.prep.payoffs) == nil then problem("the week 1 seed's payoff card isn't in the hand") end
        -- An evening off draws cards.
        local before = 0
        for _, k in ipairs(content.kinds) do before = before + #c.prep.hand[k] end
        c.prep.extra = c.prep.extra - 1 -- room for it
        c.prep.inspirations = 0
        c.prep.inspired_by.novel = nil
        app.refresh()
        for _ = 1, 4 do
            if not click_key("guide_ok") then break end
        end
        -- (The random clicks may have left the supplement open.)
        if app.book then click_key("book_done") end
        if not click_key("inspire_novel") then
            local keys = {}
            for _, b in ipairs(buttons()) do
                if b.key and (string.find(b.key, "insp", 1, true) or string.find(b.key, "guide", 1, true)) then table.insert(keys, b.key) end
            end
            problem("no inspiration button (" .. tostring(app.screen) .. ", week " .. tostring(c.week) .. ", tip "
                .. tostring(app.guide_step) .. ": " .. table.concat(keys, " ") .. ")")
        end
        local after = 0
        for _, k in ipairs(content.kinds) do after = after + #c.prep.hand[k] end
        if after <= before then problem("inspiration drew no cards") end
        if FULL then
        -- Messages: the spotlight conflict was pushed live last week.
        local tip_was = app.guide_step
check_tip_absorbs(" (week 2 prep)")
                finish_talk()
                if not click_key("tab_messages") then problem("no messages tab") end
        if tip_was == "prep_messages" and not (app.campaign.guide and app.campaign.guide.seen.prep_messages) then
            problem("opening Messages didn't retire the tip that asked for it")
        end
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
            finish_talk()
            for _ = 1, 4 do
                if not click_key("guide_ok") then break end
            end
            if not click_key("convo_" .. by.id) then problem("couldn't open " .. by.id) end
            if app.convo ~= by.id then problem("conversation didn't open") end
            dump("14_convo")
            if not click_key("convo_opt_1") then problem("no reply options in the conversation") end
            if not (c.prep.convos[by.id] and #c.prep.convos[by.id].log >= 3) then problem("they didn't answer") end
            dump("14b_convo_answered")
            if not click_key("convo_done") then
                local keys = {}
                for _, b in ipairs(buttons()) do table.insert(keys, tostring(b.key)) end
                local th = c.prep.convos[by.id] or {}
                problem("no Done button after the conversation ended: " .. by.id .. " done=" .. tostring(th.done)
                    .. " convo=" .. tostring(app.convo) .. " keys " .. table.concat(keys, " "))
            end
        elseif not answered then
            problem("no bystander message for a live conflict")
        end
        -- Starting one yourself costs prep time only when you send.
        local jess_row
        for _, r in ipairs(require("game.ui.messages_view").rows(app)) do
            if r.id == "spotlight_jess" then jess_row = r end
        end
        if jess_row and not c.prep.convos.spotlight_jess and c.prep:left() >= 1 then
            local left = c.prep:left()
            click_key("convo_spotlight_jess")
            if c.prep:left() ~= left then problem("opening a conversation charged before sending") end
            click_key("convo_close")
            if c.prep:left() ~= left then problem("closing an unsent conversation cost time") end
            click_key("convo_spotlight_jess")
            click_key("convo_opt_2")
            if c.prep:left() ~= left - 1 then problem("sending to Jess didn't cost an hour") end
            local th = c.prep.convos.spotlight_jess
            while th and not th.done and click_key("convo_opt_1") do end
            click_key("convo_done")
        end
        end
        -- Answer a theory in the group chat if there is one.
        click_key("tab_group")
        for i, m in ipairs(c.chat) do
            if m.choices and not m.answered then
                -- (A long chat can scroll it off the top; only check when it's on screen.)
                if click_key("chat_" .. i .. "_1") and not m.answered then problem("answering a theory didn't stick") end
                break
            end
        end
    end
    -- A one-on-one the random clicks opened (A6): play it through.
    for _ = 1, 8 do
        if not app.talk then break end
        if not (click_key("talk_opt_1") or click_key("talk_done")) then break end
    end
    -- Whatever the random clicks left open (the new book, a talk, the notebook) closes first.
    if app.book then click_key("book_done") end
    if app.ask then click_key("ask_no") end
    if app.overlay then key("back") end
    -- The Story log panel the random clicks opened (placing a story card opens it): look, then
    -- close it, so the table column is free for the checks below.
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
    for i = 1, 3 do
        if not app.campaign.prep.scenes[i].type then
            app.sel = { scene = i, kind = "type" }
            app.refresh()
            -- the type cards are the 7 big buttons in the drawer
            local bs = buttons()
            for _, b in ipairs(bs) do
                if b.node.size.y == 150 and b.node.size.x == 105 then click(b) break end
            end
        end
    end
    if not app.campaign.prep:ready() then
        local t = {}
        for i, sc in ipairs(app.campaign.prep.scenes) do
            table.insert(t, i .. ":" .. tostring(sc.type) .. (sc.open and "(open)" or "") .. (sc.module and "(module)" or ""))
        end
        dump("x_prep_not_ready")
        problem("prep not ready after picking types: " .. table.concat(t, " ") .. " (overlay " .. tostring(app.overlay)
            .. ", ask " .. tostring(app.ask and true) .. ", talk " .. tostring(app.talk and true) .. ", convo " .. tostring(app.convo and true) .. ")")
        break
    end
    -- Goodwill: the heart on each card, and what it means on hover (and who gave you what).
    if week == 2 then
        local keepsakes = require "game.model.keepsakes"
        local given = keepsakes.get(app.campaign).given
        local from = given[1] and given[1].from
        if not from then problem("week two with no gift on the table") end
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
    end
    -- A handout (game/model/handouts.lua): open a story card's slot and make one.
    if week == 1 or week == 3 then
        local handouts = require "game.model.handouts"
        local pr = app.campaign.prep
        local found
        for i, sc in ipairs(pr.scenes) do
            for _, kind in ipairs(require("game.model.content").kinds) do
                local c = sc.slots[kind]
                if not found and c and handouts.worth_it(app.campaign, c) then
                    found = { i, kind, c }
                end
            end
        end
        if found then
            pr.extra = (pr.extra or 0) - 2      -- (time for it, whatever the random clicks spent)
            app.sel = { scene = found[1], kind = found[2] }
            app.refresh()
            if not click_key("handout_toggle") then
                problem("no handout button on a story card's slot")
            elseif not (pr.handouts and pr.handouts[found[3].id]) then
                problem("making a handout didn't stick")
            else
                dump_once("15e_handout_made")
            end
            app.sel = nil
            app.refresh()
        end
    end
    -- The slice rework: the one-page hand, and the notebook later in the campaign.
    if week == 3 or week == 1 then
        app.sel = { scene = 1, kind = "cast" }
        app.refresh()
        dump("15b_prep_hand_w" .. week)
        app.sel = { scene = 2, kind = "complication" }
        app.refresh()
        dump("15c_prep_hand_comp_w" .. week)
        app.sel = nil
        app.refresh()
    end
    if (week == 2 or week == 4) and app.campaign.prep and require("game.model.books").newest(app.campaign) then
        -- A new book (A13): the supplement evening opens it; pull an entry and see it in the game.
        local books_mod = require "game.model.books"
        local pr = app.campaign.prep
        pr.inspired_by.supplement = nil
        pr.inspirations = 0
        pr.reading = nil
        -- The random clicks may have spent every hour: clear cards until the evening is affordable.
        for i = 1, #pr.scenes do
            for kind in pairs(pr.scenes[i].slots) do
                if not pr:can_inspire("supplement") then
                    pr:clear(i, kind)
                end
            end
        end
        app.sel = nil
        app.refresh()
        if not click_key("inspire_supplement") then problem("no supplement button in week " .. week) end
        if not app.book then problem("the supplement evening didn't open the new book (week " .. week .. ")") end
        local r = pr.reading
        local bk = r and books_mod.book(r.book)
        local want = week == 4 and "module" or "monster"
        local pick
        for _, e in ipairs(bk and bk.entries or {}) do
            if e.kind == want and not books_mod.get(app.campaign).pulled[e.id] then
                pick = pick or e
            end
        end
        if pick then
            click_key("book_entry_" .. pick.id)
            dump("32_book_page_w" .. week)
            if not click_key("book_pull") then problem("no Pull it in button") end
            if not books_mod.get(app.campaign).pulled[pick.id] then problem("pulling " .. pick.id .. " did nothing") end
            if pick.card and not pr.inspired[pick.card.id] then problem("a pulled card isn't in the hand: " .. pick.card.id) end
        end
        if not click_key("book_done") then problem("no Done reading button") end
        if app.book then problem("the book didn't close") end
        -- A published adventure on scene 3 (week 4): it fills the scene; its reward can be swapped.
        if week == 4 and pick and pick.module then
            -- Room for it: scene 3 closed and cleared.
            pr:set_open(3, false)
            for kind in pairs(pr.scenes[3].slots) do
                pr:clear(3, kind)
            end
            for i = 1, 2 do
                for kind in pairs(pr.scenes[i].slots) do
                    if pr:left() < 3 then
                        pr:clear(i, kind)
                    end
                end
            end
            app.refresh()
            local can, why = pr:can_place_module(3, pick.module)
            if not can then
                -- The random clicks spent the hours on talks and reading: nothing to clear makes room.
                print("  (module step skipped: " .. tostring(why) .. ")")
            elseif click_key("type_3") then
                for _ = 1, 4 do
                    if not click_key("guide_ok") then break end
                end
                if not click_key("module_" .. pick.module) then problem("no module button in the type picker") end
                if not (pr.scenes[3].module and pr.scenes[3].module.id == pick.module) then
                    problem("the module didn't fill scene 3")
                end
                dump("33_module_scene")
                app.sel = { scene = 3, kind = "reward" }
                app.refresh()
                dump("33b_module_reward")
                app.sel = nil
                app.refresh()
            else
                problem("no type button on scene 3")
            end
        end
    end
    if week == 2 then
        -- Changing course (A18): on the notebook's campaign page, pick another style, ask the
        -- table, then nudge: the gateway card goes into this week's hand.
        key("next_cell")
        if app.overlay ~= "notes" then problem("N didn't open the notes in week 2") end
        if click_key("notes_tab_campaign") then
            local styles_mod = require "game.model.styles"
            local home = styles_mod.current(app.campaign)
            local target
            for _, sid in ipairs(styles_mod.data().order) do
                if sid ~= home and not target then target = sid end
            end
            if not click_key("course_style_" .. target) then problem("no course style button for " .. target) end
            local chat_before = #(app.campaign.chat or {})
            -- (The random clicks may have asked, or nudged, already.)
            local co = app.campaign.course or {}
            if not (co.target == target and co.asked) then
                if not click_key("course_ask") then problem("no Ask the table button") end
                if #(app.campaign.chat or {}) <= chat_before then problem("asking the table posted nothing") end
            end
            co = app.campaign.course or {}
            if not (co.target == target and (co.nudge or co.force)) and not click_key("course_nudge") then
                problem("no Nudge button")
            end
            local nudge = app.campaign.course and (app.campaign.course.nudge or app.campaign.course.force)
            if not (nudge and app.campaign.prep:pinned(nudge)) then problem("the nudge card isn't in the hand") end
            dump("31_change_course")
        else
            problem("no campaign tab in the notes")
        end
        key("next_cell")
    end
    if week == 2 then
        -- (One-on-ones arrive in week 2: the first prep board keeps to scenes, hand and players.)
        -- Talk 2h is a one-on-one (A6): three questions, an answer to the worry, what you learned.
        local talker
        local pr = app.campaign.prep
        if pr:left() < 2 then
            -- Free up two hours for the talk: take a card back off the board.
            for i, sc in ipairs(pr.scenes) do
                for kind, c in pairs(sc.slots) do
                    if pr:left() < 2 and kind ~= "goal" then
                        pr:clear(i, kind)
                    end
                end
            end
            app.refresh()
        end
        for _, p in ipairs(app.campaign.players) do
            if p.present and app.campaign.prep:can_talk(p.key) and has_key("talk_" .. p.key) then
                talker = p
                break
            end
        end
        if talker then
            click_key("talk_" .. talker.key)
            if not app.talk then problem("Talk 2h didn't open a one-on-one") end
            local guard_t = 0
            while app.talk and not app.talk.done and guard_t < 8 do
                guard_t = guard_t + 1
                if guard_t == 3 then dump("28_one_on_one") end
                if not click_key("talk_opt_1") then problem("no answer to pick in the one-on-one"); break end
            end
            dump("28_one_on_one_done")
            if not click_key("talk_done") then problem("the one-on-one has no Done button") end
            if app.talk then problem("the one-on-one didn't close") end
            local n = app.campaign.prep.talk_notes and app.campaign.prep.talk_notes[talker.key]
            if not (n and n.mood and n.want) then problem("the one-on-one didn't note a mood and a want") end
        end
    end
    if week == 3 then
        key("next_cell")
        if app.overlay ~= "notes" then problem("N didn't open the notes in week 3") end
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
        local sk = app.campaign.players[#app.campaign.players].key
        if not click_key("sheet_" .. sk) then problem("no sheet link on " .. sk .. "'s prep card") end
        if app.overlay ~= "sheet" then problem(sk .. "'s prep card didn't open their sheet") end
        click_key("sheet_close")
        -- An open scene (A15): the players choose. Sketch spots from Your places and suggestions.
        do
            local pr = app.campaign.prep
            click_key("guide_ok")
            -- Room for a couple of sketches.
            for i, sc in ipairs(pr.scenes) do
                for kind in pairs(sc.slots) do
                    if pr:left() < 2 then
                        pr:clear(i, kind)
                    end
                end
            end
            app.refresh()
            if not click_key("type_3") then problem("no type button on scene 3") end
            for _ = 1, 4 do
                if not click_key("guide_ok") then break end
            end
            if not click_key("open_scene") then problem("no Open scene button in the type picker") end
            if not pr.scenes[3].open then problem("Open scene didn't open scene 3") end
            dump("29_open_scene")
            local tried = {}
            for _, tab in ipairs({ "places", "suggested", "hand" }) do
                if click_key("loc_tab_" .. tab) then
                    -- One card at a time, from a fresh look at the screen after each click.
                    for _ = 1, 8 do
                        if #(pr.scenes[3].spots or {}) >= 2 then break end
                        local hit
                        for _, b in ipairs(buttons()) do
                            if b.key and string.sub(b.key, 1, 5) == "hand_" and b.key ~= "hand_close" and b.enabled ~= false
                                and not tried[b.key] then
                                hit = b
                                break
                            end
                        end
                        if not hit then break end
                        tried[hit.key] = true
                        local before = #(pr.scenes[3].spots or {})
                        click(hit)
                        if #(pr.scenes[3].spots or {}) == before and os.getenv("SMOKE_DEBUG") then
                            print("spot click did nothing: " .. hit.key .. " toast=" .. tostring(app.toast) .. " ask=" .. tostring(app.ask ~= nil))
                        end
                    end
                end
            end
            dump("29_open_scene_spots")
            if #(pr.scenes[3].spots or {}) == 0 then
                local why = {}
                for _, cd in ipairs(pr.hand.location or {}) do
                    local ok, w = pr:can_add_spot(3, cd.id)
                    table.insert(why, cd.id .. "=" .. tostring(ok) .. (w and (":" .. w) or ""))
                end
                problem("couldn't sketch any spots on the open scene (left " .. tostring(pr:left()) .. "; " .. table.concat(why, ", ") .. ")")
            end
            app.sel = nil
            app.refresh()
        end
        -- The encounter builder on a combat scene.
        local c = app.campaign
        app.sel = nil
        local type_before = c.prep.scenes[1].type
        c.prep:set_type(1, "combat")
        app.refresh()
        if not click_key("fight_1") then problem("no fight button on a combat scene") end
        if app.overlay ~= "encounter" then problem("the fight button didn't open the builder") end
        dump("28_encounter_suggested")
        click_key("enc_add_ogre")
        click_key("enc_add_goblin_warrior")
        click_key("enc_lead_ogre")
        local enc = c.prep:encounter(1)
        if not enc.built or enc.ids[1] ~= "ogre" then problem("the builder didn't take the ogre as the lead: " .. table.concat(enc.ids, ",")) end
        -- A hazard on the mat (A10).
        if not click_key("enc_hazard_spreading_fire") then problem("no hazard buttons in the builder") end
        if c.prep:hazard(1) ~= "spreading_fire" then problem("the builder didn't set the hazard") end
        dump("28_encounter_built")
        -- The map (B9): lay a wall from the grid, then cover, a trap and the starts.
        if not click_key("enc_tab_map") then problem("no map tab in the builder") end
        local loc = c.prep.scenes[1].slots.location
        if not loc then
            -- Put a place on it: a map lives with its place.
            for _, card in ipairs((c.prep.hand or {}).location or {}) do
                if not loc then
                    c.prep:place(1, card.id)
                    loc = c.prep.scenes[1].slots.location
                end
            end
            if not loc then
                c.prep.scenes[1].slots.location = content.components.forest_road
                loc = c.prep.scenes[1].slots.location
            end
            app.refresh()
            click_key("enc_tab_map")
        end
        if not loc then
            problem("no place to draw a map for")
        else
            local map_view = require "game.ui.map_view"
            click_key("map_piece_wall")
            local maps = require "game.model.maps"
            -- Click squares on the grid until one takes a wall (the place's own scenery, a campfire
            -- or a bar, refuses one where it stands).
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
            app.refresh()
            click_key("map_trap")
            m = maps.get(c, loc.id)
            if not (m and m.party and m.foes and m.trap) then problem("the map's starts or trap didn't stick") end
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
        c.prep:set_type(1, type_before)
        app.refresh()
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
        app.sel = { scene = 2, kind = "cast" }
        app.refresh()
        dump("2_prep")
        app.sel = { scene = 1, kind = "type" }
        app.refresh()
        dump("3_prep_types")
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
                    if n.alive and n.text and string.find(n.text, fragment, 1, true) then return true end
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
                if not shown("last roll:") then problem("the scene's dots without the last roll's label") end
            end
            -- A rules word in a tip, or on a card, keeps its card up while you read it (the re-test,
            -- October 16: "improv hand" in the tip showed nothing).
            if not dumped_once.tip_word then
                local spot
                for _, l in ipairs({ app.guide_layer, app.layers.modal }) do
                    if l and l.spots and l.spots[1] then spot = spot or l.spots[1] end
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
    app.refresh()
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
        if app.screen ~= "planner" then problem("two clicks on New campaign didn't start the planner") end
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
if (stats.last_roll or 0) == 0 then problem("never saw the scene's dots with the last roll's label") end
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
