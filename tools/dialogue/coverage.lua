-- Dialogue coverage report (M5): which cells (a trigger for one speaker, and one
-- tier or mood for split triggers) have enough approved lines, which are waiting on
-- review, and which need more lines generated. The gate: every slice cell has at
-- least 3 approved lines.
--
--   lua tools/dialogue/coverage.lua            (from the project root; any Lua 5.1+ or LuaJIT)
--
-- Prints a summary and writes tools/dialogue/coverage.html, a grid of every cell.

package.path = "./?.lua;" .. package.path
local dialogue = require "game.model.dialogue"

local lib = dialogue.load()
local cells, totals = lib:coverage()
local min = lib.min_approved

local function pct(a, b)
    return b > 0 and math.floor(100 * a / b + 0.5) or 0
end

-- Summary -----------------------------------------------------------------------------------

print(string.format("%d lines: %d approved, %d drafts, %d rejected", totals.lines, totals.approved, totals.draft, totals.rejected))
print(string.format("cells with %d+ approved: %d of %d (%d%%)", min, totals.ok, totals.cells, pct(totals.ok, totals.cells)))
local groups, order = {}, {}
for _, c in ipairs(cells) do
    if not groups[c.group] then
        groups[c.group] = { ok = 0, cells = 0, short = 0, waiting = 0 }
        table.insert(order, c.group)
    end
    local g = groups[c.group]
    g.cells = g.cells + 1
    g.ok = g.ok + (c.ok and 1 or 0)
    g.short = g.short + (c.short and 1 or 0)
    g.waiting = g.waiting + ((not c.ok and not c.short) and 1 or 0)
end
for _, name in ipairs(order) do
    local g = groups[name]
    print(string.format("  %-22s %3d of %3d done, %3d waiting on review, %3d need more lines", name, g.ok, g.cells, g.waiting, g.short))
end
if totals.short > 0 then
    print(string.format("%d cells can't reach %d approved without new lines: run tools/dialogue/generate.py", totals.short, min))
end
print(totals.ok == totals.cells and "GATE PASSED: every slice cell has " .. min .. "+ approved lines"
    or ("gate open: " .. (totals.cells - totals.ok) .. " cells to go"))

-- HTML grid ---------------------------------------------------------------------------------

local function esc(s)
    return (string.gsub(tostring(s), "[<>&\"]", { ["<"] = "&lt;", [">"] = "&gt;", ["&"] = "&amp;", ['"'] = "&quot;" }))
end

local by_key = {}
for _, c in ipairs(cells) do
    by_key[c.key] = c
end

local function cell_html(c)
    if not c then
        return '<td class="na"></td>'
    end
    local cls = c.ok and "ok" or (c.short and "short" or "wait")
    local tip = string.format("%d approved, %d drafts, %d rejected", c.approved, c.draft, c.rejected)
    return string.format('<td class="%s" title="%s"><b>%d</b><span>/%d</span>%s</td>', cls, esc(tip), c.approved, min,
        c.draft > 0 and ('<i>+' .. c.draft .. '</i>') or "")
end

local sections = {}
for _, name in ipairs(order) do
    -- Columns: the speakers this group's triggers use, in a stable order.
    local cols, seen = {}, {}
    for _, t in ipairs(lib.triggers) do
        if t.group == name then
            for _, s in ipairs(t.speakers) do
                if not seen[s] then
                    seen[s] = true
                    table.insert(cols, s)
                end
            end
        end
    end
    local head = { "<tr><th>Trigger</th>" }
    for _, s in ipairs(cols) do
        local v = lib.voices[s]
        table.insert(head, "<th>" .. esc(v.kind == "player" and v.name or (string.gsub(v.name, ",.*", ""))) .. "</th>")
    end
    table.insert(head, "</tr>")
    local rows = {}
    for _, t in ipairs(lib.triggers) do
        if t.group == name then
            local splits = t.split and t.split.values or { false }
            for _, v in ipairs(splits) do
                local r = { "<tr><th title=\"" .. esc(t.when) .. "\">" .. esc(t.id) .. (v and (" <em>" .. esc(v) .. "</em>") or "") .. "</th>" }
                for _, s in ipairs(cols) do
                    table.insert(r, cell_html(by_key[dialogue.cell_key(t.id, s, v or nil)]))
                end
                table.insert(r, "</tr>")
                table.insert(rows, table.concat(r))
            end
        end
    end
    local g = groups[name]
    table.insert(sections, string.format('<section><h2>%s <small>%d of %d done</small></h2><div class="scroll"><table>%s%s</table></div></section>',
        esc(name), g.ok, g.cells, table.concat(head), table.concat(rows, "\n")))
end

local html = [[<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Dialogue coverage</title>
<style>
:root { --bg: #f6f1e7; --fg: #2b2018; --dim: #6f5f4b; --line: #e2d7c3; --ok: #3f7f3a; --ok-bg: #dcebd3;
        --wait: #8a6414; --wait-bg: #f3e4bf; --short: #a8402f; --short-bg: #f4d6cf; }
@media (prefers-color-scheme: dark) { :root { --bg: #1b1411; --fg: #f3e7cf; --dim: #b9a88e; --line: #352821;
        --ok: #9fd08a; --ok-bg: #24331f; --wait: #e8c06a; --wait-bg: #3a2e16; --short: #f09080; --short-bg: #3d1e19; } }
body { background: var(--bg); color: var(--fg); font: 14px/1.4 system-ui, sans-serif; margin: 0; padding: 24px 16px; }
main { max-width: 1100px; margin: 0 auto; }
h1 { font-size: 22px; margin: 0 0 4px; } h2 { font-size: 16px; margin: 28px 0 8px; } small { color: var(--dim); font-weight: 400; }
p { color: var(--dim); margin: 0 0 8px; max-width: 70ch; }
.scroll { overflow-x: auto; } table { border-collapse: collapse; font-variant-numeric: tabular-nums; }
th, td { border-bottom: 1px solid var(--line); padding: 4px 10px; text-align: left; white-space: nowrap; }
td { text-align: center; min-width: 54px; } td b { font-weight: 600; } td span { color: var(--dim); font-size: 12px; }
td i { font-style: normal; font-size: 11px; color: var(--dim); margin-left: 4px; } th em { color: var(--dim); font-style: normal; }
td.ok { background: var(--ok-bg); color: var(--ok); } td.wait { background: var(--wait-bg); color: var(--wait); }
td.short { background: var(--short-bg); color: var(--short); }
.key span { display: inline-block; padding: 1px 8px; border-radius: 4px; margin-right: 6px; }
</style></head><body><main>
<h1>Dialogue coverage</h1>
<p>]] .. string.format("%d lines: %d approved, %d drafts, %d rejected. Cells with %d or more approved lines: <b>%d of %d</b>.",
    totals.lines, totals.approved, totals.draft, totals.rejected, min, totals.ok, totals.cells) .. [[</p>
<p class="key"><span class="ok" style="background:var(--ok-bg);color:var(--ok)">done</span><span style="background:var(--wait-bg);color:var(--wait)">waiting on review</span><span style="background:var(--short-bg);color:var(--short)">needs more lines</span>
Each cell shows approved lines out of the ]] .. min .. [[ needed, then drafts still to review.</p>
]] .. table.concat(sections, "\n") .. [[
</main></body></html>
]]

local f = assert(io.open("tools/dialogue/coverage.html", "w"))
f:write(html)
f:close()
print("wrote tools/dialogue/coverage.html")
