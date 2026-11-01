// Deckhand online relay.
//
// The game runs on every player's machine, in lockstep: the relay does not
// know the rules. Each table is one Durable Object that picks the seed when
// the host starts, and keeps the ordered list of actions. It sends every
// action to every player, so all copies of the game make the same moves.
// The host's machine plays the bots (and players who dropped out).
//
// Messages are JSON objects with a "t" (type) field.
//   client -> relay: hello {name, token?}, start {bots, options},
//                    act {seat, action}, sum {n, sum}
//   relay -> client: welcome {id, token, code}, lobby {players, host, started},
//                    start {seed, seats, options, actions} (the actions so far,
//                    when rejoining),
//                    act {n, seat, action}, desync {n}, error {message}

import { DurableObject } from "cloudflare:workers";

export interface Env {
	TABLES: DurableObjectNamespace<Table>;
}

const CODE_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
const CODE_LENGTH = 5;
const MAX_SEATS = 5;
const MAX_NAME = 24;
// A table nobody has touched for this long is deleted.
const EXPIRY_MS = 7 * 24 * 3600 * 1000;

export default {
	async fetch(request: Request, env: Env): Promise<Response> {
		const url = new URL(request.url);
		if (url.pathname === "/new") {
			return Response.json({ code: newCode() }, { headers: { "access-control-allow-origin": "*" } });
		}
		const match = url.pathname.match(/^\/table\/([A-Z0-9]{3,12})$/);
		if (match) {
			if (request.headers.get("Upgrade") !== "websocket") {
				return new Response("Expected a WebSocket", { status: 426 });
			}
			const table = env.TABLES.get(env.TABLES.idFromName(match[1]));
			return table.fetch(request);
		}
		return new Response("Deckhand relay\n", { headers: { "content-type": "text/plain" } });
	},
};

function newCode(): string {
	const bytes = crypto.getRandomValues(new Uint8Array(CODE_LENGTH));
	return Array.from(bytes, (b) => CODE_ALPHABET[b % CODE_ALPHABET.length]).join("");
}

interface Player {
	id: number;
	token: string;
	name: string;
}

interface Seat {
	name: string;
	bot: boolean;
	owner: number | null; // player id, null for bots
}

interface TableState {
	code: string;
	players: Player[];
	started: boolean;
	seed: number;
	seats: Seat[];
	options: Record<string, unknown>;
}

interface Action {
	seat: number;
	action: unknown;
}

export class Table extends DurableObject<Env> {
	private state: TableState | null = null;
	private log: Action[] | null = null;
	// First checksum reported after each action, to spot a desync.
	private sums = new Map<number, string>();

	constructor(ctx: DurableObjectState, env: Env) {
		super(ctx, env);
		// Answer pings without waking the object.
		ctx.setWebSocketAutoResponse(new WebSocketRequestResponsePair('{"t":"ping"}', '{"t":"pong"}'));
	}

	async fetch(request: Request): Promise<Response> {
		const code = new URL(request.url).pathname.split("/").pop()!;
		const state = await this.load();
		if (!state.code) {
			state.code = code;
		}
		const pair = new WebSocketPair();
		// Hibernatable: the object can sleep between moves without dropping anyone.
		this.ctx.acceptWebSocket(pair[1]);
		pair[1].serializeAttachment({ id: -1 });
		return new Response(null, { status: 101, webSocket: pair[0] });
	}

	async webSocketMessage(ws: WebSocket, raw: string | ArrayBuffer): Promise<void> {
		let message: any;
		try {
			message = JSON.parse(typeof raw === "string" ? raw : new TextDecoder().decode(raw));
		} catch {
			return this.send(ws, { t: "error", message: "Bad message" });
		}
		const state = await this.load();
		const me: number = ws.deserializeAttachment()?.id ?? -1;
		switch (message.t) {
			case "hello":
				return this.hello(ws, state, message);
			case "start":
				return this.start(me, state, message);
			case "act":
				return this.act(me, state, message);
			case "sum":
				return this.sum(message);
		}
	}

	async webSocketClose(ws: WebSocket, code: number): Promise<void> {
		try {
			ws.close(code === 1005 ? 1000 : code);
		} catch {
			// Already closed.
		}
		// Everyone else learns this player has gone (and who hosts now).
		this.broadcastLobby(await this.load());
	}

	async webSocketError(ws: WebSocket): Promise<void> {
		await this.webSocketClose(ws, 1011);
	}

	async alarm(): Promise<void> {
		const last: number = (await this.ctx.storage.get("touched")) ?? 0;
		if (this.ctx.getWebSockets().length === 0 && Date.now() - last > EXPIRY_MS) {
			await this.ctx.storage.deleteAll();
			this.state = null;
			this.log = null;
			return;
		}
		await this.ctx.storage.setAlarm(Date.now() + EXPIRY_MS);
	}

	private async hello(ws: WebSocket, state: TableState, message: any): Promise<void> {
		let player = state.players.find((p) => typeof message.token === "string" && p.token === message.token);
		if (!player) {
			if (state.started) {
				return this.send(ws, { t: "error", message: "This game has already started." });
			}
			if (state.players.length >= MAX_SEATS) {
				return this.send(ws, { t: "error", message: "This table is full." });
			}
			player = {
				id: state.players.length,
				token: crypto.randomUUID(),
				name: String(message.name ?? "").trim().slice(0, MAX_NAME) || `Pirate ${state.players.length + 1}`,
			};
			state.players.push(player);
			await this.save();
		}
		ws.serializeAttachment({ id: player.id });
		this.send(ws, { t: "welcome", id: player.id, token: player.token, code: state.code });
		if (state.started) {
			// Catching up (rejoining): the whole game so far.
			const actions = await this.loadLog();
			this.send(ws, { t: "start", seed: state.seed, seats: state.seats, options: state.options, actions });
		}
		this.broadcastLobby(state);
	}

	private async start(me: number, state: TableState, message: any): Promise<void> {
		if (state.started || me !== this.host(state)) {
			return;
		}
		const bots = Math.max(0, Math.min(MAX_SEATS - state.players.length, Number(message.bots) || 0));
		if (state.players.length + bots < 2) {
			return;
		}
		const seats: Seat[] = state.players.map((p) => ({ name: p.name, bot: false, owner: p.id }));
		const names = ["Calico Mae", "One-Eyed Bart", "Silver Ines", "Doc Barnacle"];
		for (let i = 0; i < bots; i++) {
			seats.push({ name: names[i % names.length], bot: true, owner: null });
		}
		state.started = true;
		state.seed = crypto.getRandomValues(new Uint32Array(1))[0] & 0x7fffffff;
		state.seats = seats;
		state.options = { beginner_draft: Boolean(message.options?.beginner_draft) };
		this.log = [];
		await this.save();
		await this.ctx.storage.put("log", this.log);
		this.broadcast({ t: "start", seed: state.seed, seats, options: state.options });
		this.broadcastLobby(state);
	}

	private async act(me: number, state: TableState, message: any): Promise<void> {
		const seat = state.seats[message.seat];
		if (!state.started || !seat) {
			return;
		}
		// A seat is played by its owner; the host plays bots and absent players.
		const online = this.onlineIds();
		const mine = seat.owner === me;
		const hosting = me === this.host(state) && (seat.bot || seat.owner === null || !online.has(seat.owner));
		if (!mine && !hosting) {
			return;
		}
		const log = await this.loadLog();
		const entry = { seat: message.seat, action: message.action ?? {} };
		log.push(entry);
		await this.ctx.storage.put("log", log);
		await this.ctx.storage.put("touched", Date.now());
		this.broadcast({ t: "act", n: log.length - 1, ...entry });
	}

	private sum(message: any): void {
		const n = Number(message.n);
		const sum = String(message.sum);
		const first = this.sums.get(n);
		if (first === undefined) {
			this.sums.set(n, sum);
		} else if (first !== sum) {
			this.broadcast({ t: "desync", n });
		}
	}

	// The host is the first player (in joining order) who is connected.
	private host(state: TableState): number {
		const online = this.onlineIds();
		return state.players.find((p) => online.has(p.id))?.id ?? -1;
	}

	private onlineIds(): Set<number> {
		const ids = new Set<number>();
		for (const ws of this.ctx.getWebSockets()) {
			if (ws.readyState === WebSocket.OPEN) {
				const id = ws.deserializeAttachment()?.id ?? -1;
				if (id >= 0) ids.add(id);
			}
		}
		return ids;
	}

	private broadcastLobby(state: TableState): void {
		const online = this.onlineIds();
		this.broadcast({
			t: "lobby",
			players: state.players.map((p) => ({ id: p.id, name: p.name, online: online.has(p.id) })),
			host: this.host(state),
			started: state.started,
		});
	}

	private broadcast(message: object): void {
		const text = JSON.stringify(message);
		for (const ws of this.ctx.getWebSockets()) {
			try {
				ws.send(text);
			} catch {
				// Closing; it will be dropped.
			}
		}
	}

	private send(ws: WebSocket, message: object): void {
		ws.send(JSON.stringify(message));
	}

	private async load(): Promise<TableState> {
		if (!this.state) {
			this.state = (await this.ctx.storage.get<TableState>("state")) ?? {
				code: "",
				players: [],
				started: false,
				seed: 0,
				seats: [],
				options: {},
			};
		}
		return this.state;
	}

	private async loadLog(): Promise<Action[]> {
		if (!this.log) {
			this.log = (await this.ctx.storage.get<Action[]>("log")) ?? [];
		}
		return this.log;
	}

	private async save(): Promise<void> {
		await this.ctx.storage.put("state", this.state);
		await this.ctx.storage.put("touched", Date.now());
		await this.ctx.storage.setAlarm(Date.now() + EXPIRY_MS);
	}
}
