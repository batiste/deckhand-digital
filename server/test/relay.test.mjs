// Talks to a running relay (npm run dev) as several players.
//   RELAY=http://localhost:8787 node test/relay.test.mjs
const base = process.env.RELAY ?? "http://localhost:8787";
let failures = 0;
const check = (ok, what) => {
	console.log(`${ok ? "ok  " : "FAIL"} ${what}`);
	if (!ok) failures++;
};

function connect(code) {
	const ws = new WebSocket(`${base.replace(/^http/, "ws")}/table/${code}`);
	const inbox = [];
	const waiters = [];
	ws.addEventListener("message", (e) => {
		const m = JSON.parse(e.data);
		inbox.push(m);
		for (const w of [...waiters]) if (w.test(m)) { waiters.splice(waiters.indexOf(w), 1); w.resolve(m); }
	});
	const opened = new Promise((r) => ws.addEventListener("open", r));
	const next = (t, pred = () => true) => {
		const found = inbox.find((m) => m.t === t && pred(m));
		if (found) { inbox.splice(inbox.indexOf(found), 1); return Promise.resolve(found); }
		return new Promise((resolve, reject) => {
			const w = { test: (m) => m.t === t && pred(m), resolve: (m) => { inbox.splice(inbox.indexOf(m), 1); resolve(m); } };
			waiters.push(w);
			setTimeout(() => reject(new Error(`timed out waiting for ${t}`)), 3000);
		});
	};
	return { ws, opened, next, send: (m) => ws.send(JSON.stringify(m)), inbox };
}

const { code } = await (await fetch(`${base}/new`)).json();
check(/^[A-Z0-9]{5}$/.test(code), `new table code ${code}`);

const anna = connect(code);
await anna.opened;
anna.send({ t: "hello", name: "Anna" });
const welcomeA = await anna.next("welcome");
check(welcomeA.id === 0 && welcomeA.token, "first player is id 0 with a token");

const ben = connect(code);
await ben.opened;
ben.send({ t: "hello", name: "Ben" });
const welcomeB = await ben.next("welcome");
check(welcomeB.id === 1, "second player is id 1");
const lobby = await anna.next("lobby", (m) => m.players.length === 2);
check(lobby.host === 0 && lobby.players.every((p) => p.online), "lobby: two online players, Anna hosts");

ben.send({ t: "start", bots: 2 });
await new Promise((r) => setTimeout(r, 200));
check(!anna.inbox.some((m) => m.t === "start"), "only the host can start");

anna.send({ t: "start", bots: 2, options: { beginner_draft: true } });
const startA = await anna.next("start");
const startB = await ben.next("start");
check(startA.seed === startB.seed && startA.seats.length === 4, "both get the same seed and 4 seats");
check(startA.seats[2].bot && startA.seats[2].owner === null, "seats 2 and 3 are bots");

anna.send({ t: "act", seat: 0, action: { redraw: false } });
ben.send({ t: "act", seat: 1, action: { redraw: true } });
anna.send({ t: "act", seat: 2, action: { redraw: false } }); // host plays a bot
ben.send({ t: "act", seat: 0, action: { pick: 99 } }); // not Ben's seat: ignored
ben.send({ t: "act", seat: 3, action: { redraw: false } }); // a bot, but Ben is not host: ignored
const a0 = await anna.next("act", (m) => m.n === 0);
const a1 = await anna.next("act", (m) => m.n === 1);
const a2 = await anna.next("act", (m) => m.n === 2);
const b2 = await ben.next("act", (m) => m.n === 2);
check(a0.seat === 0 && a1.seat === 1 && a2.seat === 2, "actions numbered in arrival order");
check(JSON.stringify(a2) === JSON.stringify(b2), "everyone gets the same action");
await new Promise((r) => setTimeout(r, 200));
check(!anna.inbox.some((m) => m.t === "act" && m.n === 3), "actions for seats you don't play are dropped");

// Ben drops out: Anna (host) may now play his seat.
ben.ws.close();
await anna.next("lobby", (m) => m.players[1] && !m.players[1].online);
anna.send({ t: "act", seat: 1, action: { pick: 5 } });
const a3 = await anna.next("act", (m) => m.n === 3);
check(a3.seat === 1, "the host plays a player who dropped out");

// Ben comes back with his token and gets the whole game.
const ben2 = connect(code);
await ben2.opened;
ben2.send({ t: "hello", token: welcomeB.token });
const rejoin = await ben2.next("welcome");
const restart = await ben2.next("start");
check(rejoin.id === 1 && restart.seed === startA.seed, "rejoining keeps Ben's seat and the seed");
check(restart.actions?.length === 4, `rejoining replays the ${restart.actions?.length} actions so far`);

// A stranger cannot join a started game.
const eve = connect(code);
await eve.opened;
eve.send({ t: "hello", name: "Eve" });
const refused = await eve.next("error");
check(/started/.test(refused.message), "strangers cannot join a started game");

// Checksums: a mismatch is reported to everyone.
anna.send({ t: "sum", n: 3, sum: "123" });
ben2.send({ t: "sum", n: 3, sum: "456" });
const desync = await anna.next("desync");
check(desync.n === 3, "a checksum mismatch is reported");

for (const c of [anna, ben2, eve]) c.ws.close();
console.log(failures ? `\n${failures} FAILURE(S)` : "\nALL RELAY TESTS PASSED");
process.exit(failures ? 1 : 0);
