-- Words for things in a story's world: places, people, creatures, food and goods. While an
-- adventure runs, a shared line (table talk, a friend's quip, a DM card, a rest, a stunt, a
-- killing blow) that names one of these only plays if the adventure itself names it too
-- (game/model/adventure.lua, M.fits): the museum has statues, so "Pip, stop talking to the statue"
-- can play; it has no goats, so "Someone mentions the goat" can't. A new adventure gets the same
-- check for free against its own words.
--
-- phrases: callbacks to things that would have had to happen ("just like last time"); a shared
-- line that says one never plays while an adventure runs, since nothing promises it happened.
-- Data only: add words as the shared content grows.

return {
    words = {
        -- places and buildings
        "tavern", "inn", "innkeeper", "bartender", "barkeep", "village", "town square", "market", "farm", "farmhouse", "barn",
        "mill", "millrace", "chapel", "shrine", "altar", "crypt", "graveyard", "graves", "barrow", "cairn", "ruins", "tower",
        "bell", "bells", "camp", "campfire", "cellar", "sewer", "sewers", "dock", "docks", "harbour", "harbor", "port", "ship",
        "boat", "river", "rapids", "bridge", "ford", "forest", "woods", "hills", "ridge", "valley", "vale", "cave mouth",
        "wilderness", "coast", "island", "castle", "manor", "guildhall", "library", "temple steps",
        "chimney", "tunnel", "quarry", "toll", "waymark",
        -- people
        "farmer", "farmhand", "miller", "baker", "blacksmith", "smith", "mayor", "captain", "lieutenant", "sergeant",
        "guildmaster", "inspector", "lawyer", "surveyor", "merchant prince", "abbot", "priest", "saint", "bard", "minstrel",
        "lookout", "sentry", "watchman", "watchmen", "patrol", "riders", "bandit", "bandits", "crew", "cultist", "cultists",
        "refugees", "king", "queen", "prince", "princess", "lord", "lords", "lady", "grandmother", "apprentice", "apprentices",
        "stallholder", "shopkeeper", "messenger", "smuggler", "smugglers", "pirate", "pirates",
        -- creatures
        "goblin", "goblins", "orc", "orcs", "ogre", "troll", "dragon", "wolf", "wolves", "bear", "owlbear", "rat", "rats",
        "spider", "spiders", "goat", "goose", "geese", "cow", "sheep", "horse", "horses", "pony", "mule", "mules", "deer",
        "rooster", "chicken", "frog", "frogs", "wasp", "wasps", "bees", "elf", "elves", "dwarf", "dwarves", "undead",
        "skeleton", "zombie", "ghoul", "vampire",
        -- goods, food and things
        "ring", "amulet", "locket", "coin purse", "purse", "pouch", "coppers", "silver piece", "silver pieces",
        "relic", "idol", "banner", "lantern", "lanterns", "cart", "carts", "wagon", "barrel", "barrels", "crate", "crates",
        "cask", "casks", "rope", "ropes", "ladder", "shovel", "chalk", "map scrap", "letter", "ledger", "contract",
        "soup", "stew", "bread", "pie", "pies", "cabbages", "apples", "berries", "ale", "mead", "cheese wheel",
        "riddle", "cipher", "runes", "riddle door", "pet", "rug", "rafters", "chandelier",
        -- the old campaign's own
        "Sir Nibbles", "Nibbles", "the Kettle", "Millbrook", "Ilsa", "Kessrick",
        -- the museum's own (November 6, the adventure standard: so the next story doesn't inherit them)
        "museum", "exhibit", "exhibits", "gift shop", "Flitwidget", "Franc", "Francs", "Telpur", "Euryale", "Gorgon",
        "gorgon", "Lecturer", "Exhibit B", "Sentinel", "Bone Construct", "Steam Mech", "Celestia",
    },
    phrases = {
        "just like last time", "like last time", "remember the", "remember when", "last time we", "as always",
        "for the third time", "for the second time", "again, tonight", "from earlier", "the clue from", "her plan last time",
        "his plan last time", "the one from before", "won tonight", "like we planned", "ooh, potions",
    },
}
