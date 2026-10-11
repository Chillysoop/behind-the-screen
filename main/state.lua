-- Shared runtime state for game object scripts (they all share one Lua state).
-- The camera writes the eye and the imagination amount; the lamp writes the
-- light positions. Billboards and shadows read them every frame.

local M = {}

M.time = 0
M.cam_eye = vmath.vector3(230, 215, 285)
M.cam_target = vmath.vector3(-8, 84, -24)
M.cam_fov = math.rad(42)
M.fire_pos = nil        -- the table moves the fire with the terrain (nil = the M0 campfire)
M.fire_level = 1        -- 0 = no fire in this set
M.imagination = 0 -- 0 = room/table, 1 = fully in the imagination zoom
M.lamp_pos = vmath.vector3(0, 163, -5)
M.fire_intensity = 1

return M
