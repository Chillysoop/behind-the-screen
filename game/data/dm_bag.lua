-- The DM's bag (Conner, November 6: "the DM should have an inventory at his disposal to choose from"): thirty things
-- the DM can tuck somewhere a friend pokes at, in any adventure (game/model/dm_bag.lua, table_life.lua's curios).
-- One of each unless it says `stock`; what's given is gone from the bag for the rest of the campaign.
--
-- kind: "bit"    a bit or bob: a keepsake in the hero's pack, no rules effect (game/model/items.lua's things)
--       "potion" a Potion of Healing (items.lua's shared potion: it heals in a fight)
--       "magic"  one of the rules' magic items (game/rules/data/magic_items.lua): it works on the hero's sheet
-- rarity: for the bag's order and the card's line. Bits are "Bit"; the rest as SRD 5.2.1 has them.

local M = {}

M.RANK = { Bit = 1, Common = 2, Uncommon = 3, Rare = 4, ["Very Rare"] = 5, Legendary = 6 }

M.list = {
    -- Bits and bobs.
    { id = "bag_lucky_copper", kind = "bit", rarity = "Bit", name = "a lucky copper with a hole through it",
      text = "A keepsake. Somebody's lucky coin, worn smooth with thumbing." },
    { id = "bag_chalk", kind = "bit", rarity = "Bit", name = "a stub of good white chalk",
      text = "A keepsake. Good for marking walls, trees and the way back." },
    { id = "bag_whistle", kind = "bit", rarity = "Bit", name = "a tin whistle",
      text = "A keepsake. It plays four notes, one of them badly." },
    { id = "bag_pressed_flower", kind = "bit", rarity = "Bit", name = "a flower pressed in wax paper",
      text = "A keepsake. Blue once, and still smells faintly of summer." },
    { id = "bag_brass_bell", kind = "bit", rarity = "Bit", name = "a little brass bell",
      text = "A keepsake. It rings when nobody's touching it, now and then." },
    { id = "bag_map_scrap", kind = "bit", rarity = "Bit", name = "a scrap of map of somewhere else",
      text = "A keepsake. Half a coastline and a town nobody's heard of." },
    { id = "bag_silver_ring", kind = "bit", rarity = "Bit", name = "a plain silver ring, too small for anyone here",
      text = "A keepsake. Worth a few silver to the right buyer." },
    { id = "bag_cards", kind = "bit", rarity = "Bit", name = "a deck of cards missing one queen",
      text = "A keepsake. Good for a game on a quiet night, short one queen." },
    { id = "bag_honey", kind = "bit", rarity = "Bit", name = "a little jar of honey, still sealed",
      text = "A keepsake. Somebody's going to want this on bread." },

    -- A potion.
    { id = "bag_potion", kind = "potion", rarity = "Common", stock = 3, thing = "potion_healing", name = "a Potion of Healing",
      text = "Drink it as a Bonus Action in a fight: 2d4 + 2 Hit Points back. One use." },

    -- Magic: uncommon.
    { id = "bag_weapon_plus1", kind = "magic", magic = "weapon_plus1" },
    { id = "bag_shield_plus1", kind = "magic", magic = "shield_plus1" },
    { id = "bag_sentinel_shield", kind = "magic", magic = "sentinel_shield" },
    { id = "bag_cloak_of_protection", kind = "magic", magic = "cloak_of_protection" },
    { id = "bag_boots_of_elvenkind", kind = "magic", magic = "boots_of_elvenkind" },
    { id = "bag_eyes_of_the_eagle", kind = "magic", magic = "eyes_of_the_eagle" },
    { id = "bag_gloves", kind = "magic", magic = "gloves_of_swimming_and_climbing" },
    { id = "bag_bracers_of_archery", kind = "magic", magic = "bracers_of_archery" },
    { id = "bag_wand_of_magic_missiles", kind = "magic", magic = "wand_of_magic_missiles" },
    { id = "bag_pearl_of_power", kind = "magic", magic = "pearl_of_power" },
    { id = "bag_luckstone", kind = "magic", magic = "stone_of_good_luck" },
    { id = "bag_periapt", kind = "magic", magic = "periapt_of_wound_closure" },

    -- Magic: rare and up. Strong: fights get easier from here.
    { id = "bag_armor_plus1", kind = "magic", magic = "armor_plus1" },
    { id = "bag_weapon_plus2", kind = "magic", magic = "weapon_plus2" },
    { id = "bag_shield_plus2", kind = "magic", magic = "shield_plus2" },
    { id = "bag_ring_of_protection", kind = "magic", magic = "ring_of_protection" },
    { id = "bag_robe_of_eyes", kind = "magic", magic = "robe_of_eyes" },
    { id = "bag_armor_plus2", kind = "magic", magic = "armor_plus2" },
    { id = "bag_weapon_plus3", kind = "magic", magic = "weapon_plus3" },
    { id = "bag_armor_plus3", kind = "magic", magic = "armor_plus3" },
}

-- (A magic entry takes its name, rarity and words from the rules.)
local mi = require "game.rules.data.magic_items"
M.by_id = {}
for _, e in ipairs(M.list) do
    if e.kind == "magic" then
        local d = assert(mi[e.magic], "no magic item " .. tostring(e.magic))
        e.name = e.name or d.name
        e.rarity = e.rarity or d.rarity
        e.text = e.text or d.text
    end
    if e.kind == "bit" then
        e.carry = true       -- (a thing a hero carries: items.thing)
    end
    M.by_id[e.id] = e
end

return M
