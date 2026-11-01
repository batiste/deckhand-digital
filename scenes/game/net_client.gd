class_name NetClient
extends Node
## Connection to the online relay (server/): joins a table, and passes moves
## to and from it. The game itself runs here, in lockstep with the other
## players' machines; see server/src/index.ts for the messages.

signal welcomed(player_id: int, code: String)
signal lobby_changed(players: Array, host: int, started: bool)
signal started(seed_value: int, seats: Array, options: Dictionary, actions: Array)
signal acted(n: int, seat: int, action: Dictionary)
signal desynced(n: int)
signal failed(message: String)
signal disconnected

const DEFAULT_URL := "https://play.tidale.org"
const SETTINGS := "user://settings.cfg"
const RETRY_SECONDS := 2.0
const PING_SECONDS := 20.0

## The relay's address; `--relay=http://localhost:8787` on the command line
## overrides it (for testing against `npm run dev` in server/).
var url := DEFAULT_URL
var code := ""
var player_id := -1
var host := -1
var players: Array = []
var is_started := false

var _socket: WebSocketPeer
var _name := ""
var _open := false
var _wanted := false # stay connected (reconnect if dropped)
var _retry_in := 0.0
var _ping_in := PING_SECONDS

func _ready() -> void:
	for arg in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if arg.begins_with("--relay="):
			url = arg.trim_prefix("--relay=")

## Asks the relay for a new table code; calls `done` with it ("" on failure).
func create_table(done: Callable) -> void:
	var request := HTTPRequest.new()
	add_child(request)
	request.request_completed.connect(func(result: int, status: int, _h: PackedStringArray, body: PackedByteArray) -> void:
		request.queue_free()
		var reply: Variant = JSON.parse_string(body.get_string_from_utf8()) if result == HTTPRequest.RESULT_SUCCESS and status == 200 else null
		done.call(reply.code if reply is Dictionary and reply.has("code") else ""))
	if request.request(url + "/new") != OK:
		request.queue_free()
		done.call("")

## Joins table `table_code` as `player_name` (or as before, on this machine).
func join(table_code: String, player_name: String) -> void:
	leave()
	code = table_code.strip_edges().to_upper()
	_name = player_name
	_wanted = true
	_connect()

func leave() -> void:
	_wanted = false
	if _socket:
		_socket.close()
	_socket = null
	_open = false
	player_id = -1
	host = -1
	players = []
	is_started = false

func is_host() -> bool:
	return player_id >= 0 and player_id == host

## Whether player `id` is connected.
func is_online(id: int) -> bool:
	for p: Dictionary in players:
		if p.id == id:
			return p.online
	return false

func start_game(bots: int, options: Dictionary) -> void:
	_send({"t": "start", "bots": bots, "options": options})

func send_action(seat: int, action: Dictionary) -> void:
	_send({"t": "act", "seat": seat, "action": action})

## Reports this machine's game checksum after action `n`.
func send_checksum(n: int, checksum: int) -> void:
	_send({"t": "sum", "n": n, "sum": str(checksum)})

func _connect() -> void:
	_socket = WebSocketPeer.new()
	var ws_url := url.replace("https://", "wss://").replace("http://", "ws://")
	if _socket.connect_to_url("%s/table/%s" % [ws_url, code]) != OK:
		_socket = null
		_retry_in = RETRY_SECONDS
	_open = false

func _process(delta: float) -> void:
	if not _wanted:
		return
	if _socket == null:
		_retry_in -= delta
		if _retry_in <= 0.0:
			_connect()
		return
	_socket.poll()
	match _socket.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			if not _open:
				_open = true
				var hello := {"t": "hello", "name": _name}
				var token := _token()
				if not token.is_empty():
					hello.token = token
				_send(hello)
			while _socket.get_available_packet_count() > 0:
				_receive(_socket.get_packet().get_string_from_utf8())
			_ping_in -= delta
			if _ping_in <= 0.0:
				_ping_in = PING_SECONDS
				_send({"t": "ping"})
		WebSocketPeer.STATE_CLOSED:
			var was_open := _open
			_socket = null
			_open = false
			_retry_in = RETRY_SECONDS
			if was_open:
				disconnected.emit()

func _receive(text: String) -> void:
	var message: Variant = JSON.parse_string(text)
	if not message is Dictionary:
		return
	message = _ints(message)
	match message.get("t", ""):
		"welcome":
			player_id = message.id
			_save_token(message.token)
			welcomed.emit(player_id, code)
		"lobby":
			players = message.players
			host = message.host
			is_started = message.started
			lobby_changed.emit(players, host, is_started)
		"start":
			# When rejoining, it carries the actions played so far.
			is_started = true
			started.emit(message.seed, message.seats, message.get("options", {}), message.get("actions", []))
		"act":
			acted.emit(message.n, message.seat, message.action)
		"desync":
			desynced.emit(message.n)
		"error":
			_wanted = false
			failed.emit(message.message)

func _send(message: Dictionary) -> void:
	if _socket and _socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_socket.send_text(JSON.stringify(message))

## JSON numbers arrive as floats; the engine works with ints.
static func _ints(value: Variant) -> Variant:
	if value is float and value == floorf(value) and absf(value) < 9.0e15:
		return int(value)
	if value is Array:
		return value.map(_ints)
	if value is Dictionary:
		var out := {}
		for key: Variant in value:
			out[key] = _ints(value[key])
		return out
	return value

# Each table's seat token is kept, so a dropped player gets their seat back.
# (By table and name: two copies of the game on one machine are two players.)

func _token() -> String:
	var config := ConfigFile.new()
	config.load(SETTINGS)
	return config.get_value("tables", "%s/%s" % [code, _name], "")

func _save_token(token: String) -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS)
	config.set_value("tables", "%s/%s" % [code, _name], token)
	config.save(SETTINGS)
