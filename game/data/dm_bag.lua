-- The DM's bag (Conner, November 6: "the DM should have an inventory at his disposal to choose from"): thirty things
-- the DM can tuck somewhere a friend pokes at, in any adventure (game/model/dm_bag.lua, table_life.lua's curios).
-- One of each unless it says `stock`; what's given is gone from the bag for the rest of the campaign.
--
-- kind: "bit"    a bit or bob in the hero's pack: +1 to one kind of check while they carry it (`helps`, read by
--                game/model/items.lua's check_bonus on game night)
--       "potion" a Potion of Healing (items.lua's shared potion: it heals in a fight)
--       "magic"  one of the rules' magic items (game/rules/data/magic_items.lua): it works on the hero's sheet
-- rarity: for the bag's order and the card's line. Bits are "Bit"; the rest as SRD 5.2.1 has them.

local M = {}

M.RANK = { Bit = 1, Common = 2, Uncommon = 3, Rare = 4, ["Very Rare"] = 5, Legendary = 6 }

-- The books (Conner, November 6: "the DM should have the ability to spend an hour reading books to unlock more items for
-- the item bag"). Between sessions, an hour of prep reads one, and what it describes joins the bag. Each needs the one
-- before it read first. A thing with no `book` is in the bag from the start.
M.READ_COST = 1
M.books = {
    { id = "armourer", name = "The Wandering Armourer's Ledger",
      about = "A travelling smith's notes on shields, gloves and bows." },
    { id = "wonders", name = "Notes on Lesser Wonders", needs = "armourer",
      about = "A hedge-wizard's list of wands, pearls and lucky charms." },
    { id = "vault", name = "The Vault-Keeper's Catalogue", needs = "wonders",
      about = "What a collector locks away: armour, rings, robes, blades." },
    { id = "legend", name = "Treasures of Legend", needs = "vault",
      about = "Old stories of arms and armour made by masters." },
}

M.list = {
    -- Bits and bobs.
    { id = "bag_lucky_copper", kind = "bit", rarity = "Bit", name = "a lucky copper", helps = { skill = "sleight_of_hand", n = 1 },
      text = "Worn smooth, with a hole through it, good for coin tricks: +1 to Sleight of Hand checks while they carry it." },
    { id = "bag_chalk", kind = "bit", rarity = "Bit", name = "a stub of white chalk", helps = { skill = "survival", n = 1 },
      text = "Good for marking the way back: +1 to Survival checks while they carry it." },
    { id = "bag_whistle", kind = "bit", rarity = "Bit", name = "a tin whistle", helps = { skill = "performance", n = 1 },
      text = "It plays four notes, one of them badly: +1 to Performance checks while they carry it." },
    { id = "bag_pressed_flower", kind = "bit", rarity = "Bit", name = "a pressed flower", helps = { skill = "nature", n = 1 },
      text = "Blue once, kept in wax paper: +1 to Nature checks while they carry it." },
    { id = "bag_brass_bell", kind = "bit", rarity = "Bit", name = "a little brass bell", helps = { skill = "perception", n = 1 },
      text = "It rings when nobody's touching it, now and then: +1 to Perception checks while they carry it." },
    { id = "bag_map_scrap", kind = "bit", rarity = "Bit", name = "a scrap of map", helps = { skill = "history", n = 1 },
      text = "Half a coastline and a town nobody's heard of, somewhere else entirely: +1 to History checks while they carry it." },
    { id = "bag_silver_ring", kind = "bit", rarity = "Bit", name = "a small silver ring", helps = { skill = "persuasion", n = 1 },
      text = "Too small for anyone here, and a little gift smooths a talk: +1 to Persuasion checks while they carry it." },
    { id = "bag_cards", kind = "bit", rarity = "Bit", name = "a deck of cards", helps = { skill = "insight", n = 1 },
      text = "Missing one queen, and good for hours reading faces over cards: +1 to Insight checks while they carry it." },
    { id = "bag_honey", kind = "bit", rarity = "Bit", name = "a jar of honey", helps = { skill = "animal_handling", n = 1 },
      text = "Still sealed. Bears and dogs like it a lot: +1 to Animal Handling checks while they carry it." },

    -- A potion.
    { id = "bag_potion", kind = "potion", rarity = "Common", stock = 3, thing = "potion_healing", name = "a Potion of Healing",
      text = "Drink it as a Bonus Action in a fight: 2d4 + 2 Hit Points back. One use." },

    -- Magic: uncommon (four from the start; the rest in the first two books).
    { id = "bag_weapon_plus1", kind = "magic", magic = "weapon_plus1" },
    { id = "bag_shield_plus1", kind = "magic", magic = "shield_plus1" },
    { id = "bag_sentinel_shield", book = "armourer", kind = "magic", magic = "sentinel_shield" },
    { id = "bag_cloak_of_protection", kind = "magic", magic = "cloak_of_protection" },
    { id = "bag_boots_of_elvenkind", kind = "magic", magic = "boots_of_elvenkind" },
    { id = "bag_eyes_of_the_eagle", book = "armourer", kind = "magic", magic = "eyes_of_the_eagle" },
    { id = "bag_gloves", book = "armourer", kind = "magic", magic = "gloves_of_swimming_and_climbing" },
    { id = "bag_bracers_of_archery", book = "armourer", kind = "magic", magic = "bracers_of_archery" },
    { id = "bag_wand_of_magic_missiles", book = "wonders", kind = "magic", magic = "wand_of_magic_missiles" },
    { id = "bag_pearl_of_power", book = "wonders", kind = "magic", magic = "pearl_of_power" },
    { id = "bag_luckstone", book = "wonders", kind = "magic", magic = "stone_of_good_luck" },
    { id = "bag_periapt", book = "wonders", kind = "magic", magic = "periapt_of_wound_closure" },

    -- Magic: rare and up, in the last two books. Strong: fights get easier from here.
    { id = "bag_armor_plus1", book = "vault", kind = "magic", magic = "armor_plus1" },
    { id = "bag_weapon_plus2", book = "vault", kind = "magic", magic = "weapon_plus2" },
    { id = "bag_shield_plus2", book = "vault", kind = "magic", magic = "shield_plus2" },
    { id = "bag_ring_of_protection", book = "vault", kind = "magic", magic = "ring_of_protection" },
    { id = "bag_robe_of_eyes", book = "vault", kind = "magic", magic = "robe_of_eyes" },
    { id = "bag_armor_plus2", book = "legend", kind = "magic", magic = "armor_plus2" },
    { id = "bag_weapon_plus3", book = "legend", kind = "magic", magic = "weapon_plus3" },
    { id = "bag_armor_plus3", book = "legend", kind = "magic", magic = "armor_plus3" },
}

-- (A magic entry takes its name, rarity and words from the rules.)
local mi = require "game.rules.data.magic_items"
M.by_id = {}
M.book_by_id = {}
for _, b in ipairs(M.books) do
    M.book_by_id[b.id] = b
end
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
