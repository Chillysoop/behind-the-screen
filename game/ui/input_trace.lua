-- Input trace (the fix pass, A1): a log of every mouse press and release, what it hit, and
-- every card that comes up on game night with where its buttons are, so a harness clicking
-- with real X input (tools/tests/ui_play/) can tell a dropped click from a click the game
-- ignored. Off unless the build sets behind_the_screen.input_trace = 1. Writes
-- input_trace.log beside the save, one line per event:
--   <seconds> <frame> <event> <details>

local kit = require "game.ui.kit"

local M = { on = false, frame = 0, t = 0 }

local path

function M.start()
    local ok, v = pcall(sys.get_config_int, "behind_the_screen.input_trace", 0)
    M.on = ok and v and v > 0 or false
    if M.on then
        path = sys.get_save_file("behind_the_screen", "input_trace.log")
        local f = io.open(path, "w")
        if f then
            f:close()
        end
        M.log("start")
    end
    return M.on
end

function M.tick(dt)
    M.frame = M.frame + 1
    M.t = M.t + dt
end

function M.log(event, details)
    if not M.on then
        return
    end
    pcall(function()
        local f = io.open(path, "a")
        if f then
            f:write(string.format("%.3f %d %s %s\n", M.t, M.frame, event, details or ""))
            f:close()
        end
    end)
end

local function label_of(b)
    local ok, text = pcall(gui.get_text, b.label)
    text = ok and text or ""
    text = string.gsub(text, "\n.*", "")
    if text == "" and b.key then
        text = "[" .. tostring(b.key) .. "]"
    end
    return (string.gsub(text, "[|;]", "/"))
end

-- A button's rectangle in the 1600x900 layout (top-left origin).
local function rect(b)
    local p = gui.get_position(b.node)
    local s = gui.get_size(b.node)
    return math.floor(p.x + 0.5), math.floor(kit.H - p.y + 0.5), math.floor(s.x + 0.5), math.floor(s.y + 0.5)
end

-- Every button that can take a click right now, topmost first:
-- "label|x|y|w|h" joined by ";".
function M.buttons()
    local out = {}
    for i = #kit.layers, 1, -1 do
        local l = kit.layers[i]
        if not l.pinned then
            for j = #l.buttons, 1, -1 do
                local b = l.buttons[j]
                if b.enabled then
                    local x, y, w, h = rect(b)
                    table.insert(out, table.concat({ label_of(b), x, y, w, h }, "|"))
                end
            end
            if l.modal then
                break
            end
        end
    end
    return table.concat(out, ";")
end

-- A mouse press or release: where, and which button (if any) is under it.
function M.touch(action)
    if not M.on then
        return
    end
    local what = action.pressed and "press" or (action.released and "release" or nil)
    if not what then
        return
    end
    local b = kit.hit(action.x, action.y)
    M.log(what, string.format("%d %d %s", math.floor(action.x + 0.5), math.floor(kit.H - action.y + 0.5),
        b and ("hit=" .. label_of(b)) or "hit=none"))
end

return M
