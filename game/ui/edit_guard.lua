-- Cancelling a DM menu (the playtest, November 3: "add a cancel X button for the map repository, so
-- it's intuitive to cancel anything done so far and the original map stays in place; if anything
-- changed, ask first. Audit the other DM menus for the same"). A menu that changes the campaign takes
-- a copy of everything it can change when it opens. Its X puts that copy back, asking first when
-- something really changed; Done keeps the changes.
--
-- The menus: the map repository with the map maker (game/ui/map_repo_view.lua) and the tie-and-lock
-- editor (game/ui/ties_view.lua). The notes, the character sheets and the saves window change nothing
-- that needs undoing, so they only have Close.

local M = {}

-- A copy of plain data. A table with a metatable is a shared object (a player, the rng): kept as is.
local function deep(v, seen)
    if type(v) ~= "table" or getmetatable(v) then
        return v
    end
    seen = seen or {}
    if seen[v] then
        return seen[v]
    end
    local o = {}
    seen[v] = o
    for k, x in pairs(v) do
        o[deep(k, seen)] = deep(x, seen)
    end
    return o
end
M.deep = deep

-- The same data always writes the same string (keys in order), so "did anything change?" is one compare.
local function sig(v, out, seen)
    local t = type(v)
    -- (An empty table is the same as none: menus make their lists on first look, "x = x or {}".)
    if v == nil or (t == "table" and not getmetatable(v) and next(v) == nil) then
        table.insert(out, "~")
        return
    end
    if t ~= "table" then
        table.insert(out, t:sub(1, 1) .. tostring(v))
        return
    end
    if getmetatable(v) or seen[v] then
        table.insert(out, "@" .. tostring(v))
        return
    end
    seen[v] = true
    local keys = {}
    for k in pairs(v) do
        table.insert(keys, k)
    end
    table.sort(keys, function(a, b)
        local ta, tb = type(a), type(b)
        if ta ~= tb then
            return ta < tb
        end
        if ta == "number" or ta == "string" then
            return a < b
        end
        return tostring(a) < tostring(b)
    end)
    table.insert(out, "{")
    for _, k in ipairs(keys) do
        sig(k, out, seen)
        table.insert(out, "=")
        sig(v[k], out, seen)
        table.insert(out, ",")
    end
    table.insert(out, "}")
    seen[v] = nil
end

local function signature(app, fields)
    local out = {}
    for _, f in ipairs(fields(app)) do
        sig(f[1] and f[1][f[2]], out, {})
        table.insert(out, "|")
    end
    return table.concat(out)
end

-- Start an edit: fields(app) lists what the menu can change, as { { table, key }... }.
-- after(app), if given, runs after a cancel puts things back (tonight's rooms worked out again).
function M.begin(app, name, fields, after)
    app.edits = app.edits or {}
    local snap = { fields = fields, after = after, values = {} }
    for i, f in ipairs(fields(app)) do
        snap.values[i] = f[1] and deep(f[1][f[2]]) or nil
    end
    snap.sig = signature(app, fields)
    app.edits[name] = snap
end

function M.active(app, name)
    return app.edits and app.edits[name] ~= nil
end

function M.dirty(app, name)
    local s = app.edits and app.edits[name]
    return s ~= nil and signature(app, s.fields) ~= s.sig
end

function M.restore(app, name)
    local s = app.edits and app.edits[name]
    if not s then
        return
    end
    for i, f in ipairs(s.fields(app)) do
        if f[1] then
            f[1][f[2]] = deep(s.values[i])
        end
    end
    if s.after then
        s.after(app)
    end
end

-- Done: keep what changed.
function M.done(app, name)
    if app.edits then
        app.edits[name] = nil
    end
end

-- The X (or Esc): close, putting everything back; if something changed, ask first.
function M.cancel(app, name, close)
    if not M.dirty(app, name) then
        M.done(app, name)
        close()
        return
    end
    require("game.ui.ask_view").ask(app, {
        title = "Throw away your changes?",
        text = "Unsaved changes will be deleted. Are you sure? Everything goes back to how it was when you opened this.",
        no = "Keep editing", yes = "Delete my changes",
        on_yes = function()
            M.restore(app, name)
            M.done(app, name)
            close()
        end,
    })
end

return M
