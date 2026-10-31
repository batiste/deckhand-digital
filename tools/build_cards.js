// Converts cards.en.js (the print engine's source data) into data/cards.json
// for the Godot game. Run with: node tools/build_cards.js
//
// Card N in cards.en.js corresponds to deck/NNN-*.png, except entries 97..108:
// those images are second copies of earlier cards (the print engine uses
// `copies: 2`), so they reuse the data of the first card with the same title.

const fs = require("fs");
const path = require("path");

const root = path.join(__dirname, "..");
const src = fs.readFileSync(path.join(root, "cards.en.js"), "utf8") + "\nmodule.exports = cards;";
const mod = { exports: null };
new Function("module", src)(mod);
const raw = mod.exports;

const files = fs.readdirSync(path.join(root, "deck")).filter((f) => f.endsWith(".png")).sort();
if (files.length !== raw.length) {
    throw new Error(`card count mismatch: ${raw.length} data entries, ${files.length} images`);
}

const INFAMY_COUNT = 12;
const FIRST_REPRINT = 97;
const RESOURCES = ["g", "p", "r", "h", "s", "e", "c", "cs"];
const BANNERS = ["basic", "gun", "parrot", "rum", "helm", "skull", "crown", "coin"];
const EFFECTS = ["telescope", "compass", "hook", "battle", "draw-1", "draw-2", "3-choices"];

const banner = (token) => {
    const b = token.replace(/-banner$/, "");
    if (!BANNERS.includes(b)) throw new Error(`unknown banner ${token}`);
    return b;
};

function convert(c, index, file) {
    const infamy = index < INFAMY_COUNT;
    const card = {
        id: index + 1,
        file: `res://deck/${file}`,
        title: c.title,
        kind: infamy ? "infamy" : "supply",
        // Supply: resources to pay. Infamy: raised banners required to claim.
        cost: infamy ? c.cost.map(banner) : c.cost.slice(),
        // Production slots; each slot is a list of alternatives (a | b).
        production: [],
        banners: (c.banners || []).map(banner),
        vp: 0,
        multiplier: null, // {vp, banner}: vp per raised banner of that type
        trigger: null, // {on, effect}: each time `on` is added to your crew
        effects: [],
        tentacles: 0,
        battles: 0,
        hooks: 0,
        compasses: 0,
    };

    const prod = (c.production || []).filter((t) => t !== "or");
    if ((c.production || []).includes("or")) card.production.push(prod);
    else prod.forEach((t) => card.production.push([t]));
    for (const slot of card.production) {
        for (const t of slot) if (!RESOURCES.includes(t)) throw new Error(`${c.title}: bad production ${t}`);
    }
    for (const t of infamy ? [] : card.cost) {
        if (!RESOURCES.includes(t)) throw new Error(`${c.title}: bad cost ${t}`);
    }

    const extra = c.extra || [];
    if (extra[1] === "produce") {
        const on = extra[0] === "tentacle" ? "tentacle" : banner(extra[0]);
        card.trigger = { on, effect: extra[2] };
    } else {
        for (let i = 0; i < extra.length; i++) {
            const e = extra[i];
            if (e.startsWith("vp-")) {
                const vp = parseInt(e.slice(3), 10);
                if (extra[i + 1] === "x") {
                    card.multiplier = { vp, banner: banner(extra[i + 2]) };
                    i += 2;
                } else {
                    card.vp += vp;
                }
            } else if (e === "tentacle") card.tentacles += 1;
            else if (EFFECTS.includes(e)) {
                card.effects.push(e);
                if (e === "battle") card.battles += 1;
                if (e === "hook") card.hooks += 1;
                if (e === "compass") card.compasses += 1;
            } else {
                throw new Error(`${c.title}: unknown extra ${e}`);
            }
        }
    }
    return card;
}

const cards = [];
raw.forEach((c, i) => {
    let source = c;
    if (i + 1 >= FIRST_REPRINT) {
        source = raw.find((o) => o.title === c.title);
    }
    cards.push(convert(source, i, files[i]));
});

const supply = cards.filter((c) => c.kind === "supply").length;
const infamy = cards.filter((c) => c.kind === "infamy").length;
if (supply !== 96 || infamy !== 12) throw new Error(`expected 96 supply / 12 infamy, got ${supply}/${infamy}`);

fs.mkdirSync(path.join(root, "data"), { recursive: true });
fs.writeFileSync(path.join(root, "data", "cards.json"), JSON.stringify(cards, null, 1) + "\n");
console.log(`wrote data/cards.json: ${supply} supply, ${infamy} infamy`);
