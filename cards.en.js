

var cards = [

    {
        "title": "Sight Totem",

        "cost": ['gun-banner', 'parrot-banner', 'rum-banner'],
        "img": "cards/totem.png",
        'extra': ['telescope', 'vp-2', 'compass'],
        'type': 'supremacy',
        "css": "bg-60 left-sign",
        "sign": "bb",
    },

    {
        "title": "Mad Bowler",
        "cost": ['gun-banner', 'gun-banner', 'skull-banner', 'rum-banner'],
        "img": "cards/bomber.png",
        // "production": ['r']
        'extra': ['vp-5', 'hook'],
        'type': 'supremacy',
        "css": "bg-top",
        "sign": "bb",
    },

    {
        "title": "Eternal Avarice",
        "cost": ['skull-banner', 'skull-banner', 'crown-banner'],
        "img": "cards/skeleton-treasure.png",
        // "production": ['r']
        'extra': ['vp-3', '3-choices'],
        'type': 'supremacy',
        "sign": "bb",
    },


    {
        "title": "Tamed Kraken",
        "cost": ['crown-banner', 'skull-banner', 'helm-banner'],
        "img": "cards/tamed.jpg",
        // "production": ['r']
        'extra': ['vp-6', 'tentacle'],
        'type': 'supremacy',
        "css": "bg-top",
        "sign": "zp",
    },

    {
        "title": "Mermaids",
        "cost": ['skull-banner', 'coin-banner', 'parrot-banner', 'parrot-banner'],
        "img": "cards/mermaid.png",
        // "production": ['r']
        'extra': ['vp-5', 'tentacle'],
        'type': 'supremacy',
        "css": "bg-40 title-small left-sign",
        "sign": "bb",
    },

    {
        "title": "Emerald Quest",
        "cost": ['crown-banner', 'crown-banner', 'helm-banner'],
        "img": "cards/temple.png",
        // "production": ['r']
        'extra': ['vp-5', 'draw-1'],
        'type': 'supremacy',
        'css': 'left-sign bg-60',
        'sign': 'bb',
    },

    {
        "title": "Smuggler's Cove",

        "cost": ['helm-banner', 'rum-banner', 'rum-banner'],
        "img": "cards/thief-town.png",
        // "production": ['r']
        'extra': ['vp-2', 'draw-2'],
        'type': 'supremacy',
        'sign': 'dc',
        "css": "bg-70",
    },

    {
        "title": "Among Misfits",

        "cost": ['parrot-banner', 'parrot-banner', 'parrot-banner'],
        "img": "cards/8.jpg",
        // "production": ['r']
        'extra': ['vp-4', 'hook'],
        'type': 'supremacy',
        "css": "bg-60",
        "sign": "zp",
    },

    {
        "title": "Hurt Kraken",

        "cost": ['gun-banner', 'gun-banner', 'gun-banner'],
        "img": "cards/shooting-kraken.jpg",
        // "production": ['r']
        'extra': ['vp-4', 'tentacle'],
        'type': 'supremacy',
        "css": "bg-top sign-extra",
        "sign": "zp",
    },

    {
        "title": "Three Paths",

        "cost": ['helm-banner', 'helm-banner', 'helm-banner'],
        "img": "cards/3-paths.png",
        // "production": ['r']
        'extra': ['vp-4', '3-choices'],
        'type': 'supremacy',
        "css": "bg-50 title-small left-sign",
        "sign": "bb",
    },

    {
        "title": "Inking Oath",

        "cost": ['coin-banner', 'coin-banner', 'coin-banner'],
        "img": "cards/ink-oath.png",
        // "production": ['r']
        'extra': ['vp-2', 'x', 'coin-banner'],
        'type': 'supremacy',
        "css": "bg-0 left-sign",
        "sign": "mg"
    },

    {
        "title": "Pearl Diving",

        "cost": ['basic-banner', 'basic-banner', 'basic-banner', 'basic-banner', 'basic-banner'],
        "img": "cards/perl2.png",
        // "production": ['r']
        'extra': ['vp-3', 'draw-2'],
        'type': 'supremacy',
        "css": "title-small bg-10 left-sign",
        "sign": "bb",
    },

    {
        "title": "Stolen Stash",
        "discard": ['h'],
        "cost": ['cs', 'cs', 'c'],
        "img": "cards/silver-chest.png",
        "banners": ['basic-banner', 'coin-banner'],
        "extra": [],
        "production": ['cs'],
        "copies": 2,
        "css": "bg-30 title-medium",
        "sign": "bb",
    },


    {
        "title": "Cutpurse Alley",
        "discard": ['g'],
        "cost": ['c', 'p', 'g', 'r'],
        "img": "cards/thief-cut.png",
        "banners": [],
        "extra": ['coin-banner', 'produce', 'draw-1'],
        "production": ['cs'],
        "copies": 1,
        "css": "bg-50 title-medium",
        "sign": "bb",
    },


    {
        "title": "Nest of Riches",
        "discard": ['p'],
        "cost": ['e', 'c', 'cs', 'cs'],
        "img": "cards/nesting.png",
        "production": ['p', 'p'],
        "banners": ['basic-banner', 'parrot-banner'],
        // "extra": ['vp-1'],
        "css": "bg-top title-medium left-sign",
        "sign": "bb",
    },

    {
        "title": "Distillery",
        "discard": ['r'],
        "cost": ['s', 'c', 'cs', 'cs'],
        "img": "cards/distill.png",
        "production": ['r', 'r'],
        "banners": ['basic-banner', 'rum-banner'],
        // "extra": ['vp-1'],
        "css": "bg-top title-small",
        "sign": "bb",
    },

    {
        "title": "Twin Thunder",
        "discard": ['g'],
        "cost": ['h', 'c', 'cs', 'cs'],
        "img": "cards/double-canon.png",
        "production": ['g', 'g'],
        "banners": ['basic-banner', 'gun-banner'],
        // "extra": ['vp-1'],
        "css": "bg-top title-small",
        "sign": "vh",
    },
    

    {
        "title": "Tavern Keeper",
        "discard": ['r'],
        "cost": ['cs', 'cs', 'cs'],
        "img": "cards/scruf.png",
        'banners': ['basic-banner', 'rum-banner'],
        "production": ['r'],
        "copies": 2,
        "css": "bg-50 title-medium",
        "sign": "bb",
    },

    {
        "title": "Tropical Messenger",
        "discard": ['p'],
        "cost": ['cs', 'cs', 'cs'],
        "img": "cards/toucan.png",
        'banners': ['basic-banner', 'parrot-banner'],
        "production": ['p'],
        "copies": 2,
        "css": "bg-top left-sign",
        "sign": "bb",
    },

    {
        "title": "Arms Dealer",
        "discard": ['g'],
        "cost": ['cs', 'cs', 'cs'],
        "img": "cards/gun-merchant.png",
        'banners': ['basic-banner', 'gun-banner'],
        "production": ['g'],
        "copies": 2,
        "css": "bg-top title-medium left-sign",
        "sign": "bb",
    },

    {
        "title": "Master Gunner",
        "discard": ['g'],
        "cost": ['g', 'c', 'cs'],
        "img": "cards/master-gunner.png",
        'banners': ['basic-banner', 'gun-banner'],
        "extra": ['hook'],
        "production": ['g'],
        "css": "bg-40",
        "sign": "bb",
    },

    {
        "title": "Eagle Eyes",
        "discard": ['p'],
        "cost": ['p', 'c', 'cs'],
        "img": "cards/spyglass.png",
        "extra": [ 'telescope'],
        'banners': ['basic-banner', 'parrot-banner'],
        "production": ['p'],
        "css": "title-small",
        "sign": "bb",
    },


    {
        "title": "Rum Runner",
        "discard": ['r'],
        "cost": ['r', 'g', 'c'],
        "img": "cards/rum-runner.png",
        'banners': ['basic-banner', 'rum-banner'],
        "extra": ['draw-1'],
        "production": ['r'],
        "css": "title-medium bg-40",
        "sign": "bb"
    },

    {
        "title": "Fortune Teller",
        "discard": ['g'],
        "cost": ['p', 'cs', 'cs'],
        "img": "cards/oracle.png",
        "production": ['r'],
        "banners": ['basic-banner'],
        "extra": ['compass'],
        "css": "bg-top title-medium",
        "sign": "bb",
    },

    {
        "title": "Barrel Trader",
        "discard": ['r'],
        "cost": ['h', 'cs', 'cs', 'c'],
        "img": "cards/rum-merchant.png",
        "banners": ['rum-banner'],
        "extra": ['draw-2'],
        "production": ['r'],
        "css": "title-medium bg-70",
        "sign": "bb",
    },


    {
        "discard": ['r'],
        "title": "Primal Mayhem",
        "img": "cards/tavern-invasion.png",
        "cost": ['r', 'cs', 'c'],
        "extra": ['vp-1'],
        'banners': ['basic-banner', 'parrot-banner'],
        "production": ['p'],
        "copies": 2,
        "css": "bg-60 title-medium left-sign",
        "sign": "vh",
    },

    {
        "title": "Armed Orangutan",
        "discard": ['p'],
        "cost": ['p', 'cs', 'c'],
        "img": "cards/orang.jpeg",
        "extra": ['vp-1'],
        'banners': ['basic-banner', 'gun-banner'],
        "production": ['g'],
        "copies": 2,
        "css": "bg-0 left-sign",
        "sign": "mg",
    },

    {
        "title": "Brawl",
        "cost": ['g', 'cs', 'c'],
        "discard": ['g'],
        "img": "cards/brawl.png",
        "extra": ['vp-1'],
        'banners': ['basic-banner', 'rum-banner'],
        "production": ['r'],
        "copies": 2,
        "css": "bg-top title-small title-top left-sign",
        "sign": "vh",
    },

    {
        "discard": ['s'],
        "title": "Gravecaller",
        "cost": ['p', 'g', 'c'],
        "img": "cards/necro.png",
        "extra": ['vp-1'],
        'banners': ['skull-banner'],
        "production": ['s'],
        "copies": 2,
        "css": "title-top title-medium",
        "sign": "bb",
    },

    {
        "title": "Wandering Wheel",
        "discard": ['h'],
        "cost": ['r', 'p', 'c'],
        "img": "cards/wheel.png",
        "extra": ['vp-1'],
        'banners': ['helm-banner'],
        "production": ['h'],
        "copies": 2,
        "css": "bg-20",
        "sign": "vh",
    },

    {
        "title": "Idol of Greed",
        "discard": ['e'],
        "cost": ['g', 'r', 'c'],
        "img": "cards/greed.png",
        'banners': ['crown-banner'],
        "extra": ['vp-1'],
        "production": ['e'],
        "copies": 2,
        "css": "bg-30 left-sign",
        "sign": "ma",
    },

    {
        "discard": ['e'],
        "title": "Gifted Thief",
        "cost": ['r', 'g', 'cs', 'cs'],
        "img": "cards/thief.png",
        "extra": ['vp-1', 'x', 'crown-banner'],
        "banners": ['coin-banner'],
        "production": ['e'],
        "css": "bg-50 title-medium",
        "sign": "bb",
    },

    {
        "discard": ['r'],
        "title": "Haunted Manor",
        "cost": ['g', 'p', 'cs', 'cs'],
        "img": "cards/haunted-manor.png",
        "banners": ['gun-banner'],
        "extra": ['vp-1', 'x', 'skull-banner'],
        "production": ['s'],
        "css": "bg-20 title-medium left-sign",
        "sign": "mg"
    },

    {
        "title": "Aerial Lookout",
        "discard": ['h'],
        "cost": ['p', 'r', 'cs'],
        "img": "cards/parrot-reconnaissance.png",
        "banners": ['basic-banner'],
        "production": ['h'],
        "extra": ['vp-1','telescope'],
        "css": "bg-top title-medium",
        "sign": "bb",
    },

    {
        "title": "Skeleton Crew",
        "discard": ['s'],
        "cost": ['h', 'g', 'g'],
        "img": "cards/skeleton-crew.png",
        "banners": ['skull-banner'],
        "extra": ['vp-2'],
        "production": ['s'],
        "css": "bg-top title-medium left-sign",
        "block": true,
        "sign": "bb",
    },

    {
        "title": "Beach Wyrms",
        "discard": ['s'],
        "cost": ['s', 'p', 'p'],
        "img": "cards/murena.jpeg",
        "extra": ['vp-2'],
        "banners": ['parrot-banner'],
        "production": ['e'],
        "block": true,
        "css": "bg-10 title-medium",
        "sign": "mg",
    },

    {
        "title": "Trade Route",
        "discard": ['p'],
        "cost": ['e', 'r', 'cs'],
        "img": "cards/trade-route.png",
        "extra": ['vp-1'],
        "banners": ['helm-banner'],
        "production": ['h'],
        "css": "bg-top left-sign",
        "sign": "bb",
    },

    {
        "discard": ['r'],
        "title": "Jungle Corsair",
        "cost": ['p', 'r', 'cs', 'cs'],
        "img": "cards/handler.png",
        "banners": ['rum-banner'],
        "extra": ['vp-1', 'x' , 'parrot-banner'],
        "production": ['g'],
        "css": "bg-70 left-sign",
        "sign": "bb",
    },

    {
        "title": "Bazaar",
        "discard": ['e'],
        "cost": ['r', 'p', 'cs', 'cs'],
        "img": "cards/animal-market.png",
        'banners': ['rum-banner'],
        "extra": ['vp-1'],
        "production": ['g', 'or', 'p'],
        "css": "bg-70 title-small",
        "sign": "bb",
    },

    {
        "title": "Heiress",
        "discard": ['p'],
        "cost": ['r', 'g', 'cs', 'cs'],
        "img": "cards/duchess.png",
        "banners": ['gun-banner'],
        "production": ['p', 'or', 'r'],
        "extra": ['vp-1'],
        "css": "bg-60 title-small left-sign",
        "sign": "bb",
    },

    {
        "title": "Robbery",
        "discard": ['g'],
        "cost": ['h', 'r', 'cs', 'c'],
        "img": "cards/fisherman.png",
        // "extra": ['vp-1'],
        "banners": ['coin-banner'],
        "production": ['g', 'or', 'cs'],
        "css": "bg-top title-small",
        "sign": "vh",
    },

    {
        "discard": ['h'],
        "title": "Fish Monger",
        "cost": ['s', 'h', 'cs'],
        "img": "cards/fish-monger.png",
        "extra": ['tentacle', 'produce', '3-choices'],
        // "banners": ['rum-banner'],
        "production": ['p'],
        "block": true,
        "css": "bg-top title-medium",
        "sign": "bb",
    },

    {
        "discard": ['h'],
        "title": "Kiss the Ring",
        "cost": ['e', 'e', 'h'],
        "img": "cards/crooked.png",
        "extra": ['vp-3'],
        "banners": ['crown-banner'],
        "production": ['s'],
        "css": "bg-top title-medium left-sign",
        "sign": "bb",
    },


    {
        "discard": ['e'],   
        "title": "Bride",
        "cost": ['s', 's', 'e'],
        "img": "cards/witch.jpeg",
        "extra": ['vp-1', 'draw-1'],
        "banners": ['helm-banner'],
        "production": ['h'],
        "css": "bg-10 title-medium",
        "sign": "mg",
    },

    {
        "title": "Deadly Expedition",
        "discard": ['r'],
        "cost": ['h', 'h', 's'],
        "img": "cards/deadly.png",
        "production": ['e'],
        "banners": ['skull-banner'],
        "extra": ['vp-1', 'x', 'skull-banner'],
        "css": "bg-top title-medium",
        "sign": "bb",
    },

    {
        "title": "Deadhand",
        "discard": ['s'],
        "cost": ['h', 'h', 'cs'],
        "img": "cards/cpt-elec.png",
        "extra": ['vp-1','hook'],
        "banners": ['gun-banner'],
        "production": ['s'],
        "css": "bg-top title-medium left-sign",
        "sign": "bb",
    },

    {
        "title": "Emerald Cultist",
        "discard": ['e'],
        "cost": ['s', 's'],
        "img": "cards/emerald-ritual.png",
        "extra": ['vp-1'],
        "banners": ['crown-banner'],
        "production": ['e'],
        "css": "bg-top",
        "sign": "bb",
    },

    {
        "title": "Real Bargain",
        "discard": ['h'],
        "cost": ['e', 'e', 'cs'],
        "img": "cards/sale.png",
        "extra": ['vp-2'],
        "banners": ['helm-banner'],
        "production": ['h'],
        "css": "bg-60 title-small",
        "sign": "bb",
    },


    {
        "title": "Rowdy Mob",
        "discard": ['r'],
        "cost": ['g', 'g', 'r'],
        "img": "cards/mob.png",
        "banners": ['gun-banner'],
        "extra": ["battle"],
        "production": ['s'],
        "sign": "vh",
        "css": "bg-top title-medium",
    },


    {
        "title": "Quiet Afternoon",
        "discard": ['p'],
        "cost": ['r', 'p', 'g', 'cs'],
        "img": "cards/quiet.png",
        "extra": ['vp-2'],
        'banners': ['rum-banner'],
        "production": ['cs'],
        "css": "bg-top left-sign",
        "sign": "zp",
        "copies": 2,
    },

    {
        "title": "Contraband Cove",
        "discard": ['r'],
        "cost": ['r', 'cs', 'c'],
        "img": "cards/market.png",
        // 'banners': ['coin-banner'],
        "extra": ['vp-1', 'x', 'rum-banner'],
        "production": ['cs'],
        "copies": 2,
        "css": "bg-40",
        "sign": "bb",
    },

    {
        "title": "Animal Sanctuary",
        "discard": ['p'],
        "cost": ['p', 'p', 'p', 'c'],
        // "img": "cards/magic-tree.png",
        "img": "cards/sanctuary.png",
        "extra": ['vp-2', 'x', 'parrot-banner'],
        "banners": ['parrot-banner'],
        "production": ['p'],
        // "value_correction": -1
        "css": "bg-top",
        "sign": "bb",
    },

    //     {
    //     "title": "Charming Plunder",
    //     "discard": ['g'],
    //     "cost": ['g', 'g', 's'],
    //     "img": "cards/attack.png",
    //     "banners": ['crown-banner'],
    //     "extra": ['battle'],
    //     "production": ['e'],
    //     "css": "bg-top",
    // },

    {
        "title": "Charming Plunder",
        "discard": ['g'],
        "cost": ['g', 'g', 's'],
        "img": "cards/attack-3.png",
        "banners": ['crown-banner'],
        "extra": ['battle'],
        "production": ['e'],
        "css": "bg-5python 0",
        "sign": "bb"
    },

    {
        "discard": ['g'],
        "title": "Ana Stormlash",
        "cost": ['s', 'h', 'g', 'c'],
        "img": "cards/ana.png",
        "banners": ['crown-banner'],
        "extra": ['battle', 'draw-1'],
        "production": ['e'],
        "css": "title-medium bg-top",
        "sign": "mb",
    },

    {
        "title": "Cavern Horror",
        "discard": ['s'],
        "cost": ['s', 'e', 'c'],
        "img": "cards/cavern-horror.png",
        "banners": ['skull-banner'],
        "extra": ['3-choices'],
        "production": ['s'],
        "sign": "vh",
        "css": "bg-top title-medium sign-extra left-sign",  
    },

    {
        "title": "Amazon Pathfinder",
        "discard": ['g'],
        "cost": ['e', 'p', 'g'],
        "img": "cards/amazon.png",
        "banners": ['helm-banner'],
        "extra": ['vp-1', 'compass'],
        "production": ['p'],
        "css": "bg-50 left-sign",
        "sign": "bb",
    },

    {
        "title": "Wily Helmsman",
        "discard": ['r'],
        "cost": ['e', 'r', 'p'],
        "img": "cards/sidekick.png",
        "extra": ['3-choices'],
        // "banners": ['helm-banner'],
        "production": ['h'],
        "css": "bg-top title-small left-sign",
        "sign": "bb",
    },



    {
        "discard": ['g'],
        "title": "Cannoneers' Guild",
        "cost": ['g', 'g', 'g'],
        "img": "cards/cannon-guild.png",
        // "banners": ["gun-banner"],
        "production": ['g'],
        "extra": ['vp-2', 'x', 'gun-banner'],
        "css": "bg-0 left-sign",
        "sign": "vh",
    },

    {
        "discard": ['s'],
        "title": "Scarlet Rogue",
        "cost": ['g', 'g', 'h'],
        "img": "cards/lady-pirate.png",
        "banners": ["gun-banner"],
        "extra": ['vp-1', 'x', 'gun-banner'],
        "production": ['p'],
        "css": "bg-top title-medium left-sign",    
        "sign": "to",
    },


    {
        "discard": ['p'],
        "title": "Glimmer of Riches",
        "cost": ['h', 'h', 'c'],
        "img": "cards/60.png",
        "banners": ['helm-banner'],
        // "production": ['h'],
        "extra": ['telescope', 'draw-2'],
        "css": "title-medium bg-70",
        "sign": "zp",
    },


    {
        "discard": ['e'],
        "title": "Emerald Magpie",
        "cost": ['e', 'p', 'cs'],
        "img": "cards/emerald-bird.png",
        "banners": ['coin-banner'],
        "extra": ['vp-1', 'x', 'crown-banner'],
        "production": ['e'],
        "css": "bg-60",
        "sign": "bb",
        // "production": ['discard-helm', 'produce', 'any'],
    },



    {
        "title": "Temple of Chaos",
        "discard": ['s'],
        "cost": ['s', 's', 's'],
        "img": "cards/doom-island.png",
        "production": ['s'],
        "extra": ['vp-3', 'x', 'skull-banner'],
        "css": "bg-top title-medium left-sign",
        "sign": "bb",
    },


    {
        "title": "Plank Workshop",
        "discard": ['h'],
        "cost": ['h', 'h', 'h'],
        "img": "cards/construction.jpg",
        // "banners": ['rum-banner'],
        "production": ['h'],
        "extra": ['vp-3', 'x', 'helm-banner'],
        "css": "bg-top",
        "sign": "zp",
    },

    {
        "title": "Emerald Mine",
        "discard": ['r'],
        "cost": ['e', 'e', 'e'],
        "img": "cards/emerald-mine.png",
        "production": ['e'],
        "extra": ['vp-3', 'x', 'crown-banner'],
        "css": "title-medium left-sign bg-10",
        "sign": "mg"
    },


    {
        "title": "Friendly Octopus",
        "discard": ['p'],
        "cost": ['e', 's', 'h', 'p', 'c'],
        "img": "cards/possesion.png",
        "extra": ['vp-5', 'tentacle'],
        "banners": ['parrot-banner'],
        "production": ['p'],
        "css": "bg-top",
        "sign": "vh",
    },

    {
        "title": "El Dorado",
        "discard": ['h'],
        "cost": ['p', 'p', 'g', 'g', 'r', 'r'],
        "img": "cards/ed-dorado.png",
        "banners": ['coin-banner'],
        "production": ['r'],
        "extra": ['vp-6'],
        "css": "bg-top title-small",
        "sign": "bb",
    },

    {
        "title": "Severed Relic",
        "discard": ['s'],
        "cost": ['r', 'g', 'cs', 'cs'],
        "img": "cards/hand-cult.png",
        "banners": ['coin-banner'],
        "extra": ['vp-2', 'x', 'coin-banner'],
        // "production": ['s']
        "css": "bg-0 title-medium",
        "sign": "mg",
    },

    // affinity cards
    {
        "title": "The Plank",
        "discard": ['p'],
        "cost": ['p', 'r', 'h'],
        "img": "cards/walk-plank.png",
        "extra": ['hook', 'tentacle'],
        "banners": ['parrot-banner'],
        "production": ['g'],
        "css": "bg-top title-small",
        "sign": "vh",
    },

    {
        "title": "Under the Canopy",
        "discard": ['p'],
        "cost": ['g', 'r', 'e'],
        "img": "cards/hunt.png",
        "extra": ['vp-2', 'telescope'],
        "banners": ['parrot-banner'],
        "production": ['p'],
        "css": "bg-top title-medium",
        "block": true,
        "sign": "bb",
    },

    {
        "title": "Bitter Vintage",
        "discard": ['r'],
        "cost": ['g', 'p', 's'],
        "img": "cards/poison.png",
        "extra": ['battle'],
        "banners": ['skull-banner'],
        "production": ['r'],
        "block": true,
        "css": "bg-40 title-medium left-sign",
        "sign": "bb",
    },


    // {
    //     "title": "Unforeseen Tentacle",
    //     "discard": ['p'],
    //     "cost": ['e', 'c'],
    //     "img": "cards/tentacle.png",
    //     "extra": ['vp-2'],
    //     "production": ['t']
    // },

    {
        "title": "Tentacle Dinner",
        "discard": ['e'],
        "cost": ['h', 'e', 'r'],
        "img": "cards/tentacle-diner.png",
        // "banners": ['skull-banner'],
        "extra": ['vp-4', 'battle', 'tentacle'],
        "css": "bg-0",
        "sign": "vh",
    },

    {
        "title": "Grave Robber",
        "discard": ['s'],
        "cost": ['s', 'g'],
        "img": "cards/graveyard.png",
        "banners": ['coin-banner'],
        "extra": ['skull-banner', 'produce', 'draw-1'],
        "css": "title-large bg-60",
        "sign": "bb",
    },

    {
        "title": "Gemback Whale",
        "discard": ['h'],
        "cost": ['h', 'p'],
        "img": "cards/whale.jpeg",
        "production": [],
        "banners": ['parrot-banner'],
        "extra": ['crown-banner', 'produce', 'draw-1'],
        "css": "bg-10 title-top title-large",
        "sign": "mg",
    },

    {
        "title": "Treasure Hunter",
        "discard": ['p'],
        "cost": ['e', 'p'],
        "img": "cards/treasure-map.png",
        // "production": ['e'],
        "banners": ['crown-banner'],
        "extra": ['helm-banner', 'produce', 'draw-1'],
        "css": "bg-top title-medium",
        "sign": "bb",
    },

    {
        "title": "Haven",
        "discard": ['r'],
        "cost": ['p', 'p', 'r', 'r', 'p'],
        "img": "cards/haven.png",
        "extra": ['vp-2', 'x', 'basic-banner'],
        "banners": ['rum-banner'],
        "production": ['p'],
        "css": "title-small bg-65 left-sign",
        "sign": "bb",
    },

    {
        "title": "Pearl Swindler",
        "discard": ['r'],
        "cost": ['p', 'g', 'r', 'cs'],
        "img": "cards/pearl-swindler.png",
        "production": ['r'],
        "banners": ['basic-banner'],
        "extra": ['vp-1', 'x', 'basic-banner'],
        "css": "bg-65",
        "sign": "bb",
    },

    {
        "title": "Tavern",
        "discard": ['r'],
        "cost": ['r', 'r', 'cs', 'cs'],
        "img": "cards/ship-tavern.png",
        "banners": ["helm-banner"],
        "production": ['r'],
        "extra": ['vp-2', 'x', 'rum-banner'],
        "css": "bg-top title-small",
        "sign": "bb",
    },

    {
        "title": "Rum Delivery",
        "discard": ['p'],
        "cost": ['p', 'p'],
        "img": "cards/turtle.png",
        "extra": ['vp-1'],
        "banners": ['basic-banner', 'parrot-banner'],
        "production": ['r'],
        "css": "bg-top title-medium left-sign",
        "sign": "bb",
    },

    {
        "title": "Wild Echo",
        "discard": ['g'],
        "cost": ['p', 'p', 'g'],
        "img": "cards/gor.png",
        "extra": ['vp-1'],
        "banners": ['gun-banner', 'parrot-banner'],
        "production": ['g'],
        "block": true,
        "css": "bg-20 title-medium left-sign",
        "sign": "mg",
    },

    {
        "title": "Ambush",
        "discard": ['e'],
        "cost": ['g', 'r', 'cs'],
        "img": "cards/wanted.jpg", // toloma8
        "banners": ['gun-banner'],
        "extra": ['hook', 'battle'],
        "production": ['g'],
        "css": "bg-top",
        "sign": "to",
        "css": "bg-top title-small left-sign",
    },

    {
        "title": "Elixir Peddler",
        "discard": ['h'],
        "cost": ['r', 'r', 'cs'],
        "img": "cards/traveling-salesman.png",
        "banners": ['helm-banner'],
        "production": ['g'],
        "extra": ['compass'],
        "css": "bg-top title-medium",
        "sign": "bb",
    },

    {
        "title": "Rum Dispensary",
        "discard": ['e'],
        "cost": ['r', 'r', 'r', 'cs'],
        "img": "cards/rum-collection.png",
        "banners": ['rum-banner', 'rum-banner'],
        "production": ['r'],
        "extra": ['vp-5'],
        "css": "bg-60",
        "sign": "bb",
    },

    {
        "title": "Having a Blast",
        "discard": ['s'],
        "cost": ['g', 'g', 'c'],
        "img": "cards/captain-crazy.png",
        "banners": ['gun-banner'],
        "production": ['g'],
        "extra": ['vp-3', 'battle'],
        "css": "bg-top left-sign",
        "sign": "bb",
    },

    {
        "title": "Hypnotic Frogs",
        "discard": ['p'],
        "cost": ['p', 'p', 'p', 'p'],
        "img": "cards/frogs.png",
        "banners": [],
        "production": ['p'],
        "banners": ['parrot-banner'],
        "extra": ['vp-7'],
        "css": "bg-70",
        "sign": "bb",
    },

    {
        "title": "Doll from the Deep",
        "discard": ['g'],
        "cost": ['s', 'p', 'c'],
        "img": "cards/voodoo.png",
        "production": ['h'],
        "banners": ['skull-banner'],
        "extra": ['compass'],
        "sign": "bb",
    },

    {
        "title": "Shadow Thief",
        "discard": ['e'],
        "cost": ['g', 'cs', 'cs', 'cs'],
        "img": "cards/shadow-thief.png",
        "production": ['e'],
        "banners": ['coin-banner'],
        "extra": ['vp-1', 'x', 'coin-banner'],
        "css": "bg-10 title-medium",
        "sign": "mg"
    },

    {
        "title": "Hoard Warden",
        "discard": ['s'],
        "cost": ['e', 'e', 's', 's', 'h', 'h'],
        "img": "cards/drowned-keeper.png",
        "production": ['s'],
        // "banners": ['helm-banner', 'skull-banner', 'crown-banner'],
        "extra": ['vp-8', 'tentacle'],
        "css": "bg-15 title-large left-sign",
        "sign": "vh",
    },

    {
        "title": "Skull Collector",
        "discard": ['g'],
        "cost": ['s', 's', 's'],
        "img": "cards/skull-collector.png",
        "production": ['p'],
        "banners": ['skull-banner'],
        "extra": ['vp-3', '3-choices'],
        "sign": "ma",
        "css": "bg-20 title-medium left-sign"
    },

    {
        "title": "Macabre Mates",
        "discard": ['g'],
        "cost": ['s', 's', 's', 'h'],
        "img": "cards/macabre-mates.png",
        // "production": ['g'],
        "banners": ['skull-banner', 'gun-banner'],
        "extra": ['vp-6', 'hook'],
        "sign": "ma",
        "css": "bg-30 title-large left-sign"
    },

    {
        "title": "Lost Crown",
        "discard": ['e'],
        "cost": ['e', 'e', 'e', 's'],
        "img": "cards/crown.png",
        "production": ['h'],
        "banners": ['skull-banner', 'crown-banner'],
        "extra": ['vp-6'],
        "css": "title-medium bg-65",
        "sign": "bb",
    },

    {
        "title": "Armada",
        "discard": ['g'],
        "cost": ['h', 'h', 'h', 'g'],
        "img": "cards/armada.png",
        // "production": ['p'],
        "banners": ['rum-banner', 'helm-banner', 'crown-banner'],
        "extra": ['vp-6'],
        "css": "bg-50 title-top",
        "sign": "bb",
    },


    {
        "title": "Flag Workshop",
        "discard": ['h'],
        "cost": ['e', 'c', 'cs'],
        "img": "cards/banner-workshop.png",
        // "production": ['g'],
        "banners": ['basic-banner', 'basic-banner', 'rum-banner', 'parrot-banner', 'coin-banner'], //'basic-banner'
        // "extra": ['vp-2'],
        "css": "title-medium bg-50",
        "sign": "bb",
    },

    {
        "title": "Fruit Picker",
        "discard": ['p'],
        "cost": ['p', 'r', 'cs'],
        "img": "cards/fruit-picker.png",
        "production": ['p'],
        "banners": ['parrot-banner', 'rum-banner'],
        "extra": ['vp-1'],
        "css": "bg-65 title-medium",
        "sign": "bb",
    },

    {
        "title": "Predator Strike",
        "discard": ['s'],
        "cost": ['p', 'p', 'g', 'g'],
        "img": "cards/strike.png",
        "production": ['s'],
        "banners": ['skull-banner'],
        "extra": ['vp-3'],
        "css": "bg-0 title-top left-sign",
        "sign": "mg",
    },

    {
        "title": "Unlucky Incident",
        "discard": ['e'],
        "cost": ['p', 'p', 'r', 'r', 'cs', 'cs'],
        "img": "cards/powder.png",
        "production": ['r'],
        "banners": ['parrot-banner', 'gun-banner'],
        "extra": ['vp-6'],
        "css": "bg-65 title-top",
        "sign": "bb",
    },

    {
        "title": "Simian Effigy",
        "discard": ['g'],
        "cost": ['r', 'r', 'p', 'p', 'e', 'e'],
        "img": "cards/statuette.png",
        "production": ["h", "or", "cs"],
        "banners": ['crown-banner'],
        "extra": ['vp-5'],
        "css": "bg-top title-top title-medium left-sign",
        "sign": "bb",
    },

    // Explicit duplicate cards to align with deck 097..108
    {
        "title": "Stolen Stash",
        "discard": ['h'],
        "cost": ['cs', 'cs', 'c'],
        "img": "cards/silver-chest.png",
        "banners": ['basic-banner', 'coin-banner'],
        "extra": [],
        "production": ['cs'],
        "css": "bg-30 title-medium",
        "sign": "bb",
    },

    {
        "title": "Tavern Keeper",
        "discard": ['r'],
        "cost": ['cs', 'cs', 'cs'],
        "img": "cards/scruf.png",
        "banners": ['basic-banner', 'rum-banner'],
        "production": ['r'],
        "css": "bg-50 title-medium",
        "sign": "bb",
    },

    {
        "title": "Tropical Messenger",
        "discard": ['p'],
        "cost": ['cs', 'cs', 'cs'],
        "img": "cards/toucan.png",
        "banners": ['basic-banner', 'parrot-banner'],
        "production": ['p'],
        "css": "bg-top left-sign",
        "sign": "bb",
    },

    {
        "title": "Arms Dealer",
        "discard": ['g'],
        "cost": ['cs', 'cs', 'cs'],
        "img": "cards/gun-merchant.png",
        "banners": ['basic-banner', 'gun-banner'],
        "production": ['g'],
        "css": "bg-top title-medium left-sign",
        "sign": "bb",
    },

    {
        "title": "Primal Mayhem",
        "discard": ['r'],
        "cost": ['r', 'cs', 'c'],
        "img": "cards/ape-rampage.png",
        "banners": ['basic-banner', 'rum-banner'],
        "production": ['p'],
        "extra": ['hook'],
        "css": "bg-top title-medium",
        "sign": "bb",
    },

    {
        "title": "Armed Orangutan",
        "discard": ['p'],
        "cost": ['p', 'cs', 'c'],
        "img": "cards/orange-rampage.png",
        "banners": ['basic-banner', 'parrot-banner'],
        "production": ['g'],
        "extra": ['hook'],
        "css": "bg-top title-medium",
        "sign": "bb",
    },

    {
        "title": "Brawl",
        "cost": ['g', 'cs', 'c'],
        "discard": ['g'],
        "img": "cards/fight.png",
        "banners": ['basic-banner', 'gun-banner'],
        "production": ['r'],
        "extra": ['battle'],
        "css": "bg-top title-medium",
        "sign": "bb",
    },

    {
        "title": "Gravecaller",
        "discard": ['s'],
        "cost": ['p', 'g', 'c'],
        "img": "cards/voodoo-zombie.png",
        "banners": ['basic-banner', 'skull-banner'],
        "production": ['s'],
        "extra": ['battle'],
        "css": "bg-10 title-medium",
        "sign": "bb",
    },

    {
        "title": "Wandering Wheel",
        "discard": ['h'],
        "cost": ['r', 'p', 'c'],
        "img": "cards/traveling-vendor.png",
        "banners": ['basic-banner', 'helm-banner'],
        "production": ['h'],
        "extra": ['draw-1'],
        "css": "bg-top title-medium left-sign",
        "sign": "bb",
    },

    {
        "title": "Idol of Greed",
        "discard": ['e'],
        "cost": ['g', 'r', 'c'],
        "img": "cards/idol.png",
        "banners": ['basic-banner', 'crown-banner'],
        "production": ['e'],
        "extra": ['draw-1'],
        "css": "bg-top title-small left-sign",
        "sign": "bb",
    },

    {
        "title": "Quiet Afternoon",
        "discard": ['p'],
        "cost": ['r', 'p', 'g', 'cs'],
        "img": "cards/retreat.png",
        "production": ['cs'],
        "banners": ['basic-banner'],
        "extra": ['vp-1', 'x', 'basic-banner'],
        "css": "bg-55 title-medium",
        "sign": "bb",
    },

    {
        "title": "Contraband Cove",
        "discard": ['r'],
        "cost": ['r', 'cs', 'c'],
        "img": "cards/smugglers-den.png",
        "production": ['cs'],
        "banners": ['basic-banner'],
        "extra": ['vp-1', 'x', 'basic-banner'],
        "css": "bg-55 title-small",
        "sign": "bb",
    },
]