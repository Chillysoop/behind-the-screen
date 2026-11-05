-- The overlap check (docs/design/2026-11-05-root-causes.md, class 7: layout): nothing on screen covers text
-- that's meant to be read. Plays whole prologues through the real UI against the mock GUI
-- (tools/tests/museum_smoke.lua with OVERLAP_CHECK=1) and measures every screen it dumps and every step of
-- game night, from the nodes themselves (tools/tests/overlap.lua): where each piece is, how wide and tall its
-- text comes out in its font. Run from the project root:
--     lua tools/tests/overlap_check.lua [seeds]
--   SCREENS  no two pieces of readable text cross, and no solid box sits on one, on any screen measured
--   NIGHT    game night's moving pieces were each measured while up: the DM's caption, the friends' bubbles, a
--            roll over a tile (big and small), the death-save card, the side card, a toast, a room's title
-- Fails on 1ea3901 (the small roll over OUT OF CHARACTER, a roll's numbers over a friend's bubble).

local SEEDS = tonumber(arg[1]) or 4
local WANT = { "caption", "bubble", "roll", "small_roll", "dying", "side_card", "toast", "title" }
local found, pieces, scans, problems = {}, {}, 0, {}
for seed = 1, SEEDS do
    local p = io.popen("OVERLAP_CHECK=1 lua tools/tests/museum_smoke.lua " .. seed .. " 2>&1")
    local done = false
    for l in p:lines() do
        local f = { }
        for part in string.gmatch(l .. "\t", "([^\t]*)\t") do
            f[#f + 1] = part
        end
        if f[1] == "OVERLAP" then
            local key = f[3] .. "\t" .. string.gsub(f[4] or "", "@.*", "") .. "\t" .. string.gsub(f[5] or "", "@.*", "")
            if not found[key] then
                found[key] = { seed = seed, screen = f[2], line = l }
                found[#found + 1] = key
            end
        elseif f[1] == "OVERLAP_SCANS" then
            scans = scans + tonumber(f[2])
        elseif f[1] == "OVERLAP_PIECE" then
            pieces[f[2]] = (pieces[f[2]] or 0) + tonumber(f[3])
        elseif string.find(l, "^museum smoke %d+:") then
            done = true
        elseif string.find(l, "^PROBLEM") then
            problems[#problems + 1] = "seed " .. seed .. ": " .. l
        end
    end
    p:close()
    if not done then
        problems[#problems + 1] = "seed " .. seed .. ": the smoke test didn't finish"
    end
end
local total = 0
print(string.format("SCREENS  measured %d screens in %d prologues%s", scans, SEEDS, #found > 0 and ("  FAIL x" .. #found) or ""))
for i, key in ipairs(found) do
    local f = found[key]
    if i <= 20 then
        print("         FAIL (seed " .. f.seed .. ", " .. f.screen .. "): " .. string.sub(string.gsub(f.line, "^OVERLAP\t[^\t]*\t", ""), 1, 300))
    end
end
total = total + #found
local bits, missing = {}, {}
for _, k in ipairs(WANT) do
    bits[#bits + 1] = k .. " " .. tostring(pieces[k] or 0)
    if not pieces[k] then
        missing[#missing + 1] = k
    end
end
print("NIGHT    " .. table.concat(bits, ", ") .. (#missing > 0 and ("  FAIL: never measured while up: " .. table.concat(missing, ", ")) or ""))
total = total + #missing
for _, p in ipairs(problems) do
    print("         FAIL: " .. p)
end
total = total + #problems
print(total == 0 and "overlap check: all clear" or ("overlap check: " .. total .. " failures"))
os.exit(total == 0 and 0 or 1)
