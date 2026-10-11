-- The slice's 12 subclasses at level 3: the four from SRD 5.2.1 and eight
-- originals (working names, pending IP review). Each entry has the rules text
-- in our own words and an apply() that switches the engine hooks on.
-- The battle and AI modules read the flags set here (c.sub.*).

local M = {}

M.list = {
    -- Fighter ---------------------------------------------------------------------
    champion = {
        class = "fighter", name = "Champion", source = "SRD 5.2.1 p. 49",
        features = {
            { "Improved Critical", "Weapon and Unarmed Strike attack rolls score a Critical Hit on a 19 or 20." },
            { "Remarkable Athlete", "Advantage on Initiative and Strength (Athletics) checks. Right after you score a "
                .. "Critical Hit, you can move up to half your Speed without provoking Opportunity Attacks." },
        },
        apply = function(c)
            c.crit_range = 19
            c.sub.init_advantage = true
            c.sub.crit_move = true
        end,
    },
    banner_captain = {
        class = "fighter", name = "Banner Captain", source = "Original",
        features = {
            { "Battle Orders", "As a Bonus Action, expend one use of Second Wind to call an order to an ally within "
                .. "30 feet who can hear you. That ally can immediately use its Reaction to make one weapon attack or "
                .. "cast a cantrip that targets one creature." },
            { "Hold Fast", "While you aren't Incapacitated, each ally within 5 feet of you has a +1 bonus to Armor "
                .. "Class. This doesn't stack with another Hold Fast." },
        },
        apply = function(c)
            c.sub.battle_orders = true
            c.sub.hold_fast = true
        end,
    },
    spellguard = {
        class = "fighter", name = "Spellguard", source = "Original (classic-inspired)",
        features = {
            { "Arcane Training", "You learn two Wizard cantrips (True Strike and Shocking Grasp suggested). "
                .. "Intelligence is your spellcasting ability for them." },
            { "Spell-Etched Blade", "Your weapon is a Spellcasting Focus for you. When you take the Attack action, "
                .. "you can replace one of the attacks with casting a Wizard cantrip that takes an action." },
            { "Warding Flash", "When an attack roll hits you, you can take a Reaction to gain a +5 bonus to AC "
                .. "against that attack, possibly turning it into a miss. Once you use this feature, you can't do "
                .. "so again until you finish a Short or Long Rest." },
        },
        apply = function(c, sheet)
            c.casting = "int"
            c.sub.spellguard = true
            c.sub.warding_flash = true
            c.res.warding_flash = 1
            for _, s in ipairs((sheet and sheet.sg_cantrips) or { "true_strike", "shocking_grasp" }) do
                table.insert(c.cantrips, s)
                c.known_spells[s] = true
            end
        end,
    },

    -- Rogue -----------------------------------------------------------------------
    thief = {
        class = "rogue", name = "Thief", source = "SRD 5.2.1 p. 64",
        features = {
            { "Fast Hands", "As a Bonus Action: a Dexterity (Sleight of Hand) check to pick a lock, disarm a trap or "
                .. "pick a pocket, or take the Utilize action, or the Magic action to use a magic item." },
            { "Second-Story Work", "Climb Speed equal to your Speed; jump distance uses Dexterity." },
        },
        apply = function(c)
            c.sub.fast_hands = true
        end,
    },
    silvertongue = {
        class = "rogue", name = "Silvertongue", source = "Original",
        features = {
            { "Silver Tongue", "Expertise in Deception and Persuasion if you're proficient in them." },
            { "Feint", "As a Bonus Action, make a Charisma (Deception) check against the Wisdom (Insight) check of a "
                .. "creature within 30 feet that can see and hear you. If you win, you have Advantage on your next "
                .. "attack roll against it this turn. Unlike Steady Aim, you can move before or after." },
        },
        apply = function(c)
            c.sub.feint = true
            c.deception_bonus = 2 * c.pb  -- proficiency + Expertise
        end,
    },
    ambusher = {
        class = "rogue", name = "Ambusher", source = "Original (classic-inspired)",
        features = {
            { "Ready for Trouble", "Advantage on Initiative rolls." },
            { "Opening Strike", "On your first turn of a combat, you have Advantage on attack rolls against creatures "
                .. "that haven't taken a turn yet, and the first time you deal Sneak Attack damage that turn, roll "
                .. "one extra Sneak Attack die." },
        },
        apply = function(c)
            c.sub.init_advantage = true
            c.sub.opening_strike = true
        end,
    },

    -- Cleric ----------------------------------------------------------------------
    life = {
        class = "cleric", name = "Life Domain", source = "SRD 5.2.1 p. 40",
        features = {
            { "Disciple of Life", "When a spell you cast with a spell slot restores Hit Points, the creature regains "
                .. "2 + the slot's level extra Hit Points." },
            { "Life Domain Spells", "Always prepared: Aid, Bless, Cure Wounds, Lesser Restoration." },
            { "Preserve Life", "Channel Divinity, Magic action: restore 5 x your Cleric level Hit Points, divided "
                .. "among Bloodied creatures within 30 feet, none above half its Hit Point maximum." },
        },
        domain_spells = { "aid", "bless", "cure_wounds", "lesser_restoration" },
        apply = function(c)
            c.sub.disciple_of_life = true
            c.sub.preserve_life = true
        end,
    },
    hearth = {
        class = "cleric", name = "Hearth Domain", source = "Original",
        features = {
            { "Hearth Domain Spells", "Always prepared: Sanctuary, Shield of Faith, Aid, Prayer of Healing." },
            { "Warm Welcome", "Channel Divinity, Bonus Action: up to a number of creatures equal to your Wisdom "
                .. "modifier (minimum 1) within 30 feet (you can include yourself) each gain Temporary Hit Points "
                .. "equal to your Wisdom modifier + your Cleric level." },
            { "Kindled Courage", "You and allies within 10 feet of you have Advantage on saving throws against "
                .. "the Frightened condition." },
        },
        domain_spells = { "sanctuary", "shield_of_faith", "aid", "prayer_of_healing" },
        apply = function(c)
            c.sub.warm_welcome = true
            c.sub.kindled_courage = true
        end,
    },
    mischief = {
        class = "cleric", name = "Mischief Domain", source = "Original (classic-inspired)",
        features = {
            { "Mischief Domain Spells", "Always prepared: Disguise Self, Color Spray, Blur, Mirror Image. They count "
                .. "as Cleric spells for you." },
            { "Tricky Decoy", "Channel Divinity, Bonus Action: an illusory double of you appears in an unoccupied "
                .. "space within 30 feet. It lasts 1 minute, until you use this feature again, or until you have the "
                .. "Incapacitated condition. When a creature attacks you or an ally within "
                .. "10 feet of the decoy, it must succeed on a Wisdom save against your spell save DC or attack the "
                .. "decoy instead. The decoy's AC equals your spell save DC, and a hit ends it. On "
                .. "later turns, you can move the decoy up to 30 feet as a Bonus Action." },
        },
        domain_spells = { "disguise_self", "color_spray", "blur", "mirror_image" },
        apply = function(c)
            c.sub.tricky_decoy = true
        end,
    },

    -- Wizard ----------------------------------------------------------------------
    evoker = {
        class = "wizard", name = "Evoker", source = "SRD 5.2.1 p. 82",
        features = {
            { "Evocation Savant", "Add two Evocation spells of level 2 or lower to your spellbook for free, and one "
                .. "more each time you gain a new level of spell slots." },
            { "Potent Cantrip", "When you cast a cantrip at a creature and miss, or it succeeds on the save, it still "
                .. "takes half the cantrip's damage (no other effect)." },
        },
        apply = function(c)
            c.sub.potent_cantrip = true
        end,
    },
    wayfinder = {
        class = "wizard", name = "Wayfinder", source = "Original",
        features = {
            { "Wayfinder Spells", "Misty Step and Longstrider are added to your spellbook; Misty Step is always "
                .. "prepared." },
            { "Charted Step", "When you roll Initiative, you and up to two allies you can see within 30 feet can each "
                .. "move up to 10 feet without provoking Opportunity Attacks." },
            { "Folded Path", "Once per Short or Long Rest, when you cast Misty Step you can bring one willing creature "
                .. "within 5 feet of you; it appears in a space within 5 feet of where you arrive." },
        },
        domain_spells = { "misty_step" },
        apply = function(c)
            c.sub.charted_step = true
            c.res.folded_path = 1
        end,
    },
    mirror_mage = {
        class = "wizard", name = "Mirror Mage", source = "Original (classic-inspired)",
        features = {
            { "Mirror Mage Spells", "Mirror Image, Blur, Silent Image and Color Spray are added to your spellbook; "
                .. "Mirror Image and Color Spray are always prepared." },
            { "Quick Reflection", "You can cast Mirror Image as a Bonus Action. Once per Long Rest, you can cast "
                .. "it this way without expending a spell slot." },
            { "Shimmer", "When a creature you can see makes an attack roll against you, you can take a Reaction to "
                .. "give that roll Disadvantage. Uses: your Intelligence modifier (minimum 1) per Long Rest." },
        },
        domain_spells = { "mirror_image", "color_spray" },
        apply = function(c)
            c.sub.shimmer = true
            c.sub.quick_reflection = true
            c.res.qr_free = 1
            c.res.shimmer = math.max(1, math.floor((c.abilities.int - 10) / 2))
        end,
    },
}

M.by_class = {
    fighter = { "champion", "banner_captain", "spellguard" },
    rogue = { "thief", "silvertongue", "ambusher" },
    cleric = { "life", "hearth", "mischief" },
    wizard = { "evoker", "wayfinder", "mirror_mage" },
}

function M.apply(c, id, sheet)
    local s = M.list[id]
    assert(s, "unknown subclass " .. tostring(id))
    assert(s.class == c.class, id .. " is not a " .. c.class .. " subclass")
    c.sub = c.sub or {}
    c.subclass_name = s.name
    s.apply(c, sheet)
    for _, spell in ipairs(s.domain_spells or {}) do
        c.known_spells[spell] = true
        c.always_prepared = c.always_prepared or {}
        c.always_prepared[spell] = true
    end
end

return M
