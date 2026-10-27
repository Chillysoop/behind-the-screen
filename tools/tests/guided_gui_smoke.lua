-- Reuses the strict Defold GUI mock from gui_smoke.lua to exercise the guided build.
-- Drives the real game.gui_script through four sessions and a save/resume.
-- Catches Lua errors, deleted nodes, unknown resources, overflow and stuck flows.
-- Run from the repository root: lua tools/tests/guided_gui_smoke.lua [seed]

package.path = "./?.lua;" .. package.path
unpack = unpack or table.unpack

local SEED = tonumber(arg and arg[1]) or 1
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
local TABLE_SPRITES = {}
do
    local file = assert(io.open("assets/sprites/sprites.atlas"))
    for name in file:read("*a"):gmatch('/assets/sprites/([%w_]+)%.png') do TABLE_SPRITES[name] = true end
    file:close()
end
local function miniature(p)
    if not TABLE_SPRITES[p.sprite] then problem("missing tabletop sprite: " .. tostring(p.sprite)) end
    num(p.x, "miniature.x"); num(p.y, "miniature.y")
end
msg = { post = function(url, id, m)
    m = m or {}
    if url == "/table#table" and id == "stage" then
        for _, p in ipairs(m.party or {}) do miniature(p) end
        if m.npc then miniature(m.npc) end
    elseif url == "/table#table" and id == "spawn" then
        for _, p in ipairs(m.list or {}) do miniature(p) end
    end
    table.insert(posted, { url = url, id = id, m = m })
end }
function hash(s) return s end
local save = os.tmpname()
local other_saves = {}
sys = { get_save_file = function(_, name)
    if name == "playtest_log.jsonl" then return save end
    other_saves[name] = other_saves[name] or os.tmpname()
    return other_saves[name]
end }

-- This test takes the same entry point as the separately packaged executable.
local namespaces = {}
sys.get_config_int = function(key, default)
    if key == "streamlined.enabled" then return 1 end
    return default
end
sys.get_config = function(_, default) return default end
sys.get_engine_info = function() return { is_debug = false } end
sys.get_sys_info = function() return { system_name = "Linux" } end
sys.get_save_file = function(namespace, name)
    namespaces[namespace] = true
    local key = namespace .. "/" .. name
    other_saves[key] = other_saves[key] or os.tmpname()
    return other_saves[key]
end

dofile("game/game.gui_script")
local kit = require "game.ui.kit"
local guided = require "game.model.guided"
local json = require "game.model.jsonlite"
local self = {}
local ok, err = pcall(init, self)
assert(ok, "guided init: " .. tostring(err))
assert(self.guided_app, "streamlined flag did not select the separate application")
assert(self.app, "guided application was not initialized")

local function call(fn, ...)
    local worked, reason = pcall(fn, ...)
    assert(worked, tostring(reason))
    assert(#problems == 0, table.concat(problems, "\n"))
end

local function button(key)
    for i = #kit.layers, 1, -1 do
        for _, b in ipairs(kit.layers[i].buttons) do
            if b.enabled and b.key == key then return b end
        end
        if kit.layers[i].modal then break end
    end
end

local function tick(seconds)
    for _ = 1, math.max(1, math.ceil(seconds / 0.2)) do
        call(update, self, 0.2)
    end
end

local function click(key)
    local b
    for _ = 1, 160 do
        b = button(key)
        if b then break end
        tick(0.2)
    end
    assert(b, "button unavailable: " .. key .. " phase=" .. tostring(self.app.state and self.app.state.phase))
    local n = b.node
    local x, y = n.pos.x + n.size.x / 2, n.pos.y - n.size.y / 2
    assert(x >= 0 and x <= 1600 and y >= 0 and y <= 900, "button is outside the window: " .. key)
    call(on_input, self, nil, { x = x, y = y })
    call(on_input, self, "touch", { pressed = true, x = x, y = y })
    tick(0.25)
end

click("guided_start")
assert(self.app.state.phase == "prep_focus", "new game did not reach the two-choice preparation")
local calls, transitions, resumed = 0, 0, false
local phases = {}
while self.app.state.phase ~= "complete" do
    transitions = transitions + 1
    assert(transitions <= 85, "guided UI got stuck")
    local state = self.app.state
    local snap = guided.snapshot(state)
    phases[snap.phase] = true
    if not resumed and state.episode == 2 and state.phase == "decision" and state.scene_index == 2 then
        local before = guided.dump(state)
        call(final, self)
        kit.clear_all()
        self = {}
        call(init, self)
        assert(button("guided_resume"), "saved guided campaign is not offered on title")
        click("guided_resume")
        assert(guided.dump(self.app.state) == before, "reopening the executable changed the current decision")
        state = self.app.state
        snap = guided.snapshot(state)
        resumed = true
    end
    if #(snap.cards or {}) > 0 then
        local n = (SEED + state.episode + (state.scene_index or 1)) % #snap.cards + 1
        local card = snap.cards[n]
        click("guided_choice_" .. card.id)
        calls = calls + 1
    else
        click("guided_continue")
    end
end
call(final, self)
assert(resumed, "test never exercised mid-session resume")
assert(calls == 27, "unexpected required decision count: " .. calls)
assert(phases.result and phases.aftermath and phases.hook, "missing core presentation phases")
assert(namespaces.behind_the_screen_streamlined, "guided saves have no independent namespace")
assert(not namespaces.behind_the_screen, "guided build accessed the original campaign's save namespace")
assert(#problems == 0, table.concat(problems, "\n"))
assert(alive_count < MAX_NODES, "guided layout exhausted GUI nodes")

-- Static GUI-node dumps are useful when checking layout without an installed editor.
local dump_dir = os.getenv("DUMP_DIR")
if dump_dir then
    local nodes = {}
    for _, n in ipairs(order) do
        if n.alive and n.enabled ~= false then
            nodes[#nodes + 1] = {
                kind = n.kind, text = n.text, font = n.font, image = n.image,
                x = n.pos.x, y = 900 - n.pos.y, w = n.size.x, h = n.size.y,
                color = n.color and { n.color.x, n.color.y, n.color.z, n.color.w },
                pivot = n.pivot,
            }
        end
    end
    local f = assert(io.open(dump_dir .. "/guided-complete.json", "w"))
    f:write(json.encode({ nodes = nodes })); f:close()
end

for _, path in pairs(other_saves) do
    os.remove(path); os.remove(path .. ".tmp"); os.remove(path .. ".bak")
end
os.remove(save)
print(string.format("GUIDED GUI PASS: 4 episodes, %d meaningful choices, %d transitions, resume verified, %d/%d live nodes", calls, transitions, alive_count, MAX_NODES))

