extends Control

const DECK_DIR := "res://deck"
const BACKS_DIR := "res://backs"
const CARDS_DATA_PATH := "res://cards.en.js"
const INFAMY_CARDS_COUNT := 12
const CARD_TRIM_SIZE_MM := Vector2(63.0, 88.0)
const CARD_BLEED_MM := 3.0
const CARD_CORNER_RADIUS_PX := 10.08
const HAND_FULL_SPREAD_COUNT := 10
const HAND_CARD_SIZE := Vector2(180, 258)
const CREW_CARD_SIZE := Vector2(180, 258)
const CREW_VISIBLE_TOP_RATIO := 0.18
const CREW_COLUMN_COUNT := 3
const CREW_X_STAGGER := 5.0
const HAND_MIN_ANGLE := 8.0
const HAND_MAX_ANGLE := 26.0
const HAND_CURVE_HEIGHT_MIN := 10.0
const HAND_CURVE_HEIGHT_MAX := 46.5
const HAND_HOVER_LIFT := 30.0
const HAND_SELECTED_LIFT := 34.0
const HAND_HOVER_SCALE := 1.45
const HAND_SELECTED_SCALE := 1.14
const CREW_HOVER_LIFT := 16.0
const CREW_HOVER_SCALE := 1.5
const RESOURCE_ORDER: Array[String] = ["g", "p", "r", "h", "s", "e", "c", "cs"]

const RESOURCE_LABELS := {
	"g": "Gun",
	"p": "Parrot",
	"r": "Rum",
	"h": "Helm",
	"s": "Skull",
	"e": "Crown",
	"c": "Gold Coin",
	"cs": "Silver Coin",
}

const RESOURCE_ALIASES := {
	"gun-banner": "g",
	"parrot-banner": "p",
	"rum-banner": "r",
	"helm-banner": "h",
	"skull-banner": "s",
	"crown-banner": "e",
	"coin-banner": "c",
	"basic-banner": "cs",
}

var infamy_deck: Array[String] = []
var supply_deck: Array[String] = []
var all_infamy_cards: Array[String] = []
var all_supply_cards: Array[String] = []
var infamy_row_cards: Array[String] = []
var revealed_round_index: int = -1
var hand_cards: Array[TextureRect] = []
var crew_column_cards: Array[Array] = [[], [], []]
var hovered_hand_card: TextureRect = null
var selected_hand_card: TextureRect = null
var hovered_crew_card: TextureRect = null
var hovered_infamy_row_card: TextureRect = null
var pending_build_card: TextureRect = null
var payment_selected_cards: Array[TextureRect] = []
var card_defs_by_path: Dictionary = {}
var infamy_back_texture: Texture2D = null
var supply_back_texture: Texture2D = null

var card_display_shader: Shader = preload("res://scenes/cards_stack/shaders/card_display.gdshader")

@onready var infamy_button: Button = $MarginContainer/MainColumn/TopBoard/DecksRow/InfamyDeckButton
@onready var supply_button: Button = $MarginContainer/MainColumn/TopBoard/DecksRow/SupplyDeckButton
@onready var infamy_preview: TextureRect = $MarginContainer/MainColumn/TopBoard/DecksRow/InfamyDeckButton/InfamyCardPreview
@onready var supply_preview: TextureRect = $MarginContainer/MainColumn/TopBoard/DecksRow/SupplyDeckButton/SupplyCardPreview
@onready var reveal_round_button: Button = $MarginContainer/MainColumn/ActionRow/RevealRoundButton
@onready var row_card_nodes: Array[TextureRect] = [
	$MarginContainer/MainColumn/TopBoard/InfamyRow/RowCard1,
	$MarginContainer/MainColumn/TopBoard/InfamyRow/RowCard2,
	$MarginContainer/MainColumn/TopBoard/InfamyRow/RowCard3,
	$MarginContainer/MainColumn/TopBoard/InfamyRow/RowCard4,
	$MarginContainer/MainColumn/TopBoard/InfamyRow/RowCard5,
]
@onready var hand_area: Control = $MarginContainer/MainColumn/WideBody/HandPanel/HandCenter/HandArea
@onready var build_confirm_dialog: ConfirmationDialog = $BuildConfirmDialog
@onready var build_card_preview: TextureRect = $BuildConfirmDialog/DialogMargin/DialogContent/TopRow/BuildCardPreview
@onready var build_card_label: Label = $BuildConfirmDialog/DialogMargin/DialogContent/TopRow/InfoColumn/BuildCardLabel
@onready var cost_label: Label = $BuildConfirmDialog/DialogMargin/DialogContent/TopRow/InfoColumn/CostLabel
@onready var crew_production_label: Label = $BuildConfirmDialog/DialogMargin/DialogContent/TopRow/InfoColumn/CrewProductionLabel
@onready var remaining_cost_label: Label = $BuildConfirmDialog/DialogMargin/DialogContent/TopRow/InfoColumn/RemainingCostLabel
@onready var payment_status_label: Label = $BuildConfirmDialog/DialogMargin/DialogContent/PaymentStatusLabel
@onready var crew_columns: Array[Control] = [
	$MarginContainer/MainColumn/WideBody/CrewPanel/CrewColumns/CrewCol1,
	$MarginContainer/MainColumn/WideBody/CrewPanel/CrewColumns/CrewCol2,
	$MarginContainer/MainColumn/WideBody/CrewPanel/CrewColumns/CrewCol3,
]

func _ready() -> void:
	_load_back_textures()
	_load_decks()
	_load_card_definitions()
	_apply_card_materials()
	_refresh_ui()
	hand_area.resized.connect(_on_hand_area_resized)
	_setup_new_game()
	call_deferred("_refresh_card_material_sizes")
	for col: Control in crew_columns:
		col.resized.connect(_on_crew_column_resized)

func _get_bleed_margin_uv() -> Vector2:
	var total_w_mm: float = CARD_TRIM_SIZE_MM.x + CARD_BLEED_MM * 2.0
	var total_h_mm: float = CARD_TRIM_SIZE_MM.y + CARD_BLEED_MM * 2.0
	return Vector2(CARD_BLEED_MM / total_w_mm, CARD_BLEED_MM / total_h_mm)

func _create_card_display_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = card_display_shader
	material.set_shader_parameter("bleed_margin_uv", _get_bleed_margin_uv())
	material.set_shader_parameter("corner_radius_px", CARD_CORNER_RADIUS_PX)
	return material

func _apply_card_materials() -> void:
	var static_cards: Array[TextureRect] = []
	static_cards.append(infamy_preview)
	static_cards.append(supply_preview)
	for row_card: TextureRect in row_card_nodes:
		static_cards.append(row_card)

	for card: TextureRect in static_cards:
		card.material = _create_card_display_material()
		card.resized.connect(_on_card_rect_resized.bind(card))

	for row_card: TextureRect in row_card_nodes:
		row_card.mouse_entered.connect(_on_infamy_row_card_mouse_entered.bind(row_card))
		row_card.mouse_exited.connect(_on_infamy_row_card_mouse_exited.bind(row_card))

	_refresh_infamy_row_hover_visuals(false)

func _on_card_rect_resized(card: TextureRect) -> void:
	_update_card_material_size(card)
	if row_card_nodes.has(card):
		card.pivot_offset = card.size / 2.0

func _refresh_card_material_sizes() -> void:
	var static_cards: Array[TextureRect] = []
	static_cards.append(infamy_preview)
	static_cards.append(supply_preview)
	for row_card: TextureRect in row_card_nodes:
		static_cards.append(row_card)

	for card: TextureRect in static_cards:
		_update_card_material_size(card)

	for hand_card: TextureRect in hand_cards:
		_update_card_material_size(hand_card)

	for column_cards: Array in crew_column_cards:
		for crew_card: TextureRect in column_cards:
			_update_card_material_size(crew_card)

func _update_card_material_size(card: TextureRect) -> void:
	var material := card.material as ShaderMaterial
	if material == null:
		return
	material.set_shader_parameter("rect_size", card.size)

func _load_back_textures() -> void:
	infamy_back_texture = _load_texture_from_path("%s/back-infamy.png" % BACKS_DIR)
	supply_back_texture = _load_texture_from_path("%s/back-supply.png" % BACKS_DIR)

func _load_decks() -> void:
	infamy_deck.clear()
	supply_deck.clear()
	all_infamy_cards.clear()
	all_supply_cards.clear()

	var dir := DirAccess.open(DECK_DIR)
	if dir == null:
		push_error("Could not open deck directory: %s" % DECK_DIR)
		return

	var card_files: Array[String] = []
	dir.list_dir_begin()
	while true:
		var file_name := dir.get_next()
		if file_name.is_empty():
			break
		if dir.current_is_dir():
			continue
		if not file_name.to_lower().ends_with(".png"):
			continue
		card_files.append(file_name)
	dir.list_dir_end()

	card_files.sort_custom(_sort_card_files)

	for i in range(card_files.size()):
		var card_path := "%s/%s" % [DECK_DIR, card_files[i]]
		if i < INFAMY_CARDS_COUNT:
			all_infamy_cards.append(card_path)
		else:
			all_supply_cards.append(card_path)

func _sort_card_files(a: String, b: String) -> bool:
	return _extract_card_index(a) < _extract_card_index(b)

func _extract_card_index(file_name: String) -> int:
	var prefix := file_name.get_slice("-", 0)
	if prefix.is_valid_int():
		return int(prefix)
	return 100000

func _refresh_ui() -> void:
	infamy_button.disabled = infamy_deck.is_empty()
	supply_button.disabled = supply_deck.is_empty()

	infamy_preview.texture = infamy_back_texture if not infamy_deck.is_empty() else null
	supply_preview.texture = supply_back_texture if not supply_deck.is_empty() else null
	reveal_round_button.disabled = revealed_round_index >= row_card_nodes.size() - 1

func _load_texture_from_path(path: String) -> Texture2D:
	var texture := load(path) as Texture2D
	if texture == null:
		push_warning("Could not load texture: %s" % path)
	return texture

func _set_last_drawn(path: String, _deck_name: String) -> void:
	_add_card_to_hand(path)

func _add_card_to_hand(path: String) -> void:
	var texture: Texture2D = _load_texture_from_path(path)
	if texture == null:
		return

	var card: TextureRect = TextureRect.new()
	card.texture = texture
	card.set_meta("card_path", path)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card.size = HAND_CARD_SIZE
	card.pivot_offset = HAND_CARD_SIZE / 2.0
	card.material = _create_card_display_material()
	card.mouse_entered.connect(_on_hand_card_mouse_entered.bind(card))
	card.mouse_exited.connect(_on_hand_card_mouse_exited.bind(card))
	card.gui_input.connect(_on_hand_card_gui_input.bind(card))
	card.resized.connect(_on_card_rect_resized.bind(card))
	hand_area.add_child(card)
	hand_cards.append(card)
	_update_card_material_size(card)
	_layout_hand(true)
	call_deferred("_layout_hand_deferred")

func _layout_hand(animated: bool) -> void:
	var count: int = hand_cards.size()
	if count == 0:
		return

	var area_size: Vector2 = hand_area.size
	if area_size.x < HAND_CARD_SIZE.x:
		var parent_area: Vector2 = hand_area.get_parent_area_size()
		if parent_area.x > 0.0:
			area_size.x = parent_area.x
		else:
			area_size.x = HAND_CARD_SIZE.x * 2.5
	if area_size.y <= 0.0:
		area_size.y = maxf(hand_area.get_parent_area_size().y, HAND_CARD_SIZE.y + HAND_CURVE_HEIGHT_MAX + 40.0)

	if area_size.x <= 0.0 or area_size.y <= 0.0:
		return

	var max_horizontal_span: float = minf(area_size.x * 0.86, 1280.0)
	var min_horizontal_span: float = HAND_CARD_SIZE.x * 0.38
	var spread_t: float = clampf(float(count - 1) / float(HAND_FULL_SPREAD_COUNT - 1), 0.0, 1.0)
	# Keep 2-3 cards close, then progressively open the fan as hand grows.
	var horizontal_span: float = lerpf(min_horizontal_span, max_horizontal_span, spread_t)
	var step: float = 0.0
	if count > 1:
		step = horizontal_span / float(count - 1)

	# Arc grows with hand size: tiny with 2 cards, full by around 9 cards.
	var arc_t: float = clampf(float(count - 2) / 7.0, 0.0, 1.0)
	var curve_height: float = lerpf(HAND_CURVE_HEIGHT_MIN, HAND_CURVE_HEIGHT_MAX, arc_t)
	var fan_angle: float = lerpf(HAND_MIN_ANGLE, HAND_MAX_ANGLE, arc_t)

	var center_x: float = area_size.x * 0.5
	var base_y: float = area_size.y * 0.58

	for i in range(count):
		var c: TextureRect = hand_cards[i]
		var t: float = 0.0
		if count > 1:
			t = (float(i) / float(count - 1)) * 2.0 - 1.0
		var is_hovered: bool = c == hovered_hand_card
		var is_selected: bool = c == selected_hand_card or payment_selected_cards.has(c)

		var x: float = center_x + (float(i) - float(count - 1) * 0.5) * step - (HAND_CARD_SIZE.x / 2.0)
		var y: float = base_y + absf(t) * curve_height - (HAND_CARD_SIZE.y / 2.0)
		if is_selected:
			y -= HAND_SELECTED_LIFT
		elif is_hovered:
			y -= HAND_HOVER_LIFT
		var target_pos: Vector2 = Vector2(x, y)
		var target_rot: float = t * fan_angle
		if is_hovered or is_selected:
			target_rot = lerpf(target_rot, 0.0, 0.65)

		var target_scale: Vector2 = Vector2.ONE
		if is_selected:
			target_scale = Vector2(HAND_SELECTED_SCALE, HAND_SELECTED_SCALE)
		elif is_hovered:
			target_scale = Vector2(HAND_HOVER_SCALE, HAND_HOVER_SCALE)

		c.z_index = i
		if is_hovered or is_selected:
			c.z_index = 100 + i
		if animated:
			var tween: Tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			tween.tween_property(c, "position", target_pos, 0.24)
			tween.parallel().tween_property(c, "rotation_degrees", target_rot, 0.24)
			tween.parallel().tween_property(c, "scale", target_scale, 0.24)
		else:
			c.position = target_pos
			c.rotation_degrees = target_rot
			c.scale = target_scale

func _on_hand_area_resized() -> void:
	_layout_hand(false)

func _on_hand_card_mouse_entered(card: TextureRect) -> void:
	hovered_hand_card = card
	_layout_hand(true)

func _on_hand_card_mouse_exited(card: TextureRect) -> void:
	if hovered_hand_card == card:
		hovered_hand_card = null
	_layout_hand(true)

func _on_hand_card_gui_input(event: InputEvent, card: TextureRect) -> void:
	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed:
			if build_confirm_dialog.visible:
				_on_payment_card_clicked(card)
				accept_event()
				return
			_request_build_from_hand(card)
			accept_event()

func _unhandled_input(event: InputEvent) -> void:
	if build_confirm_dialog.visible:
		return
	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed:
			if hovered_hand_card != null and hand_cards.has(hovered_hand_card):
				_request_build_from_hand(hovered_hand_card)

func _request_build_from_hand(card: TextureRect) -> void:
	if not hand_cards.has(card):
		return
	pending_build_card = card
	payment_selected_cards.clear()
	selected_hand_card = null
	selected_hand_card = card
	_update_build_confirm_dialog_ui()
	_update_build_confirm_dialog_state()
	build_confirm_dialog.popup_centered()
	_layout_hand(true)

func _on_build_confirm_dialog_confirmed() -> void:
	if pending_build_card == null or not hand_cards.has(pending_build_card):
		payment_selected_cards.clear()
		selected_hand_card = null
		return

	if not _can_pay_build_cost():
		_update_build_confirm_dialog_state()
		return

	for payment_card: TextureRect in payment_selected_cards.duplicate():
		_remove_card_from_hand(payment_card)

	_build_card_from_hand(pending_build_card)
	payment_selected_cards.clear()
	selected_hand_card = null
	pending_build_card = null

func _on_build_confirm_dialog_canceled() -> void:
	payment_selected_cards.clear()
	selected_hand_card = null
	pending_build_card = null
	_update_build_confirm_dialog_ui()
	_layout_hand(true)

func _on_payment_card_clicked(card: TextureRect) -> void:
	if pending_build_card == null:
		return
	if card == pending_build_card:
		return
	if not hand_cards.has(card):
		return

	if payment_selected_cards.has(card):
		payment_selected_cards.erase(card)
	else:
		payment_selected_cards.append(card)

	_update_build_confirm_dialog_state()
	_layout_hand(true)

func _can_pay_build_cost() -> bool:
	if pending_build_card == null:
		return false
	if not hand_cards.has(pending_build_card):
		return false
	var payment_ctx: Dictionary = _get_payment_context_for_pending_card()
	return payment_ctx.get("can_pay", false)

func _update_build_confirm_dialog_state() -> void:
	var ok_button: Button = build_confirm_dialog.get_ok_button()
	ok_button.disabled = not _can_pay_build_cost()
	_update_build_confirm_dialog_ui()

func _update_build_confirm_dialog_ui() -> void:
	if pending_build_card == null:
		build_card_preview.texture = null
		build_card_label.text = "Card to Build:"
		cost_label.text = "Cost:"
		crew_production_label.text = "Crew Production:"
		remaining_cost_label.text = "Remaining to Pay:"
		payment_status_label.text = "Select a card in your hand to start building."
		return

	build_card_preview.texture = pending_build_card.texture
	var card_name: String = _get_card_display_name(pending_build_card)
	build_card_label.text = "Card to Build: %s" % card_name

	var payment_ctx: Dictionary = _get_payment_context_for_pending_card()
	var required_counts: Dictionary = payment_ctx.get("required", {})
	var crew_covered_counts: Dictionary = payment_ctx.get("crew_covered", {})
	var remaining_counts: Dictionary = payment_ctx.get("remaining_after_crew", {})

	cost_label.text = "Cost: %s" % _format_resource_counts(required_counts)
	crew_production_label.text = "Crew Production Used: %s" % _format_resource_counts(crew_covered_counts)
	remaining_cost_label.text = "Remaining to Pay: %s" % _format_resource_counts(remaining_counts)

	var selected_count: int = payment_selected_cards.size()
	var can_pay: bool = payment_ctx.get("can_pay", false)
	if _resource_counts_total(remaining_counts) == 0:
		payment_status_label.text = "Crew production already covers full cost. Build is ready."
	elif can_pay:
		payment_status_label.text = "Discard selected: %d. Payment valid. Click Build to confirm." % selected_count
	else:
		var missing_count: int = payment_ctx.get("remaining_after_discard_total", 0)
		payment_status_label.text = "Discard selected: %d. Still missing %d resource(s). Select more hand cards to discard." % [selected_count, missing_count]

	build_confirm_dialog.dialog_text = ""

func _get_card_display_name(card: TextureRect) -> String:
	if card == null:
		return "this card"
	var card_path: String = _get_card_path(card)
	if card_path.is_empty():
		return "this card"
	var card_def: Dictionary = card_defs_by_path.get(card_path, {})
	var title: String = card_def.get("title", "")
	if not title.is_empty():
		return title
	return card_path.get_file().get_basename()

func _get_card_path(card: TextureRect) -> String:
	if card == null:
		return ""
	if card.has_meta("card_path"):
		return str(card.get_meta("card_path"))
	var texture: Texture2D = card.texture
	if texture == null:
		return ""
	return texture.resource_path

func _get_payment_context_for_pending_card() -> Dictionary:
	var required_counts: Dictionary = _get_required_cost_counts_for_card(_get_card_path(pending_build_card))
	var crew_slots: Array = _get_crew_production_slots()
	var crew_covered_counts: Dictionary = _compute_slot_coverage(required_counts, crew_slots)
	var remaining_after_crew: Dictionary = _subtract_resource_counts(required_counts, crew_covered_counts)

	var discard_options: Array = _get_discard_payment_options(payment_selected_cards)
	var can_pay_discard: bool = _can_discard_cover_remaining_cost(remaining_after_crew, discard_options)
	var remaining_after_discard_total: int = _remaining_after_best_discard_payment_total(remaining_after_crew, discard_options)

	return {
		"required": required_counts,
		"crew_covered": crew_covered_counts,
		"remaining_after_crew": remaining_after_crew,
		"can_pay": can_pay_discard,
		"remaining_after_discard_total": remaining_after_discard_total,
	}

func _get_required_cost_counts_for_card(card_path: String) -> Dictionary:
	var card_def: Dictionary = card_defs_by_path.get(card_path, {})
	var raw_cost: Array = card_def.get("cost", [])
	var required: Dictionary = _empty_resource_counts()
	for raw_token in raw_cost:
		var token: String = _normalize_resource_token(str(raw_token))
		if required.has(token):
			required[token] += 1
	return required

func _get_crew_production_slots() -> Array:
	var slots: Array = []
	for column_cards: Array in crew_column_cards:
		for crew_card: TextureRect in column_cards:
			var card_path: String = _get_card_path(crew_card)
			var card_def: Dictionary = card_defs_by_path.get(card_path, {})
			var raw_production: Array = card_def.get("production", [])
			for options: Array in _parse_production_slots(raw_production):
				slots.append(options)
	return slots

func _parse_production_slots(raw_tokens: Array) -> Array:
	var normalized_tokens: Array[String] = []
	for raw_token in raw_tokens:
		var token: String = _normalize_resource_token(str(raw_token))
		if token == "or":
			normalized_tokens.append(token)
		elif _empty_resource_counts().has(token):
			normalized_tokens.append(token)

	if normalized_tokens.is_empty():
		return []

	if normalized_tokens.has("or"):
		var options: Array = []
		for token in normalized_tokens:
			if token != "or" and not options.has(token):
				options.append(token)
		if options.is_empty():
			return []
		return [options]

	var slots: Array = []
	for token in normalized_tokens:
		slots.append([token])
	return slots

func _compute_slot_coverage(required_counts: Dictionary, slots: Array) -> Dictionary:
	var coverage: Dictionary = _empty_resource_counts()
	if slots.is_empty():
		return coverage

	var flex_slots: Array = []
	for slot in slots:
		var options: Array = slot
		if options.size() <= 1:
			if options.size() == 1:
				var single: String = str(options[0])
				if required_counts.get(single, 0) > coverage.get(single, 0):
					coverage[single] += 1
		else:
			flex_slots.append(options)

	if flex_slots.is_empty():
		return coverage

	var search_result: Dictionary = _search_best_flex_slot_coverage(required_counts, flex_slots, 0, coverage.duplicate(), coverage.duplicate())
	return search_result.get("best", coverage)

func _search_best_flex_slot_coverage(required_counts: Dictionary, flex_slots: Array, index: int, current: Dictionary, best: Dictionary) -> Dictionary:
	if index >= flex_slots.size():
		if _resource_counts_total(_subtract_resource_counts(required_counts, current)) < _resource_counts_total(_subtract_resource_counts(required_counts, best)):
			best = current.duplicate()
		return {"best": best}

	var options: Array = flex_slots[index]
	var best_local: Dictionary = best
	var result_skip: Dictionary = _search_best_flex_slot_coverage(required_counts, flex_slots, index + 1, current.duplicate(), best_local)
	best_local = result_skip.get("best", best_local)

	for option_value in options:
		var option: String = str(option_value)
		var next_counts: Dictionary = current.duplicate()
		next_counts[option] += 1
		var result_take: Dictionary = _search_best_flex_slot_coverage(required_counts, flex_slots, index + 1, next_counts, best_local)
		best_local = result_take.get("best", best_local)

	return {"best": best_local}

func _get_discard_payment_options(cards: Array[TextureRect]) -> Array:
	var options_per_card: Array = []
	for card: TextureRect in cards:
		if card == pending_build_card:
			continue
		if not hand_cards.has(card):
			continue
		var card_path: String = _get_card_path(card)
		var card_def: Dictionary = card_defs_by_path.get(card_path, {})
		var raw_discard: Array = card_def.get("discard", [])
		var options: Array = []
		for raw_token in raw_discard:
			var token: String = _normalize_resource_token(str(raw_token))
			if _empty_resource_counts().has(token) and not options.has(token):
				options.append(token)
		options_per_card.append(options)
	return options_per_card

func _can_discard_cover_remaining_cost(remaining: Dictionary, options_per_card: Array) -> bool:
	return _remaining_after_best_discard_payment_total(remaining, options_per_card) == 0

func _remaining_after_best_discard_payment_total(remaining: Dictionary, options_per_card: Array) -> int:
	var best_missing: int = _resource_counts_total(remaining)
	var start_counts: Dictionary = _empty_resource_counts()
	var search: Dictionary = _search_discard_assignments(remaining, options_per_card, 0, start_counts, 0, best_missing)
	return search.get("best_missing", best_missing)

func _search_discard_assignments(remaining: Dictionary, options_per_card: Array, index: int, direct_counts: Dictionary, wildcard_pool: int, best_missing: int) -> Dictionary:
	if index >= options_per_card.size():
		var remaining_after_direct: Dictionary = _subtract_resource_counts(remaining, direct_counts)
		var total_missing: int = _resource_counts_total(remaining_after_direct)
		var wildcard_resources: int = wildcard_pool / 2
		var unresolved: int = maxi(total_missing - wildcard_resources, 0)
		if unresolved < best_missing:
			best_missing = unresolved
		return {"best_missing": best_missing}

	var options: Array = options_per_card[index]
	var result_wild: Dictionary = _search_discard_assignments(remaining, options_per_card, index + 1, direct_counts.duplicate(), wildcard_pool + 1, best_missing)
	best_missing = result_wild.get("best_missing", best_missing)

	for opt in options:
		var token: String = str(opt)
		var next_counts: Dictionary = direct_counts.duplicate()
		next_counts[token] += 1
		var result_direct: Dictionary = _search_discard_assignments(remaining, options_per_card, index + 1, next_counts, wildcard_pool, best_missing)
		best_missing = result_direct.get("best_missing", best_missing)

	return {"best_missing": best_missing}

func _subtract_resource_counts(a: Dictionary, b: Dictionary) -> Dictionary:
	var out: Dictionary = _empty_resource_counts()
	for key in out.keys():
		out[key] = maxi(int(a.get(key, 0)) - int(b.get(key, 0)), 0)
	return out

func _resource_counts_total(counts: Dictionary) -> int:
	var total: int = 0
	for key in counts.keys():
		total += int(counts.get(key, 0))
	return total

func _format_resource_counts(counts: Dictionary) -> String:
	var parts: Array[String] = []
	for token in RESOURCE_ORDER:
		var value: int = int(counts.get(token, 0))
		if value > 0:
			parts.append("%s x%d" % [RESOURCE_LABELS.get(token, token), value])
	if parts.is_empty():
		return "none"
	return ", ".join(parts)

func _empty_resource_counts() -> Dictionary:
	return {
		"g": 0,
		"p": 0,
		"r": 0,
		"h": 0,
		"s": 0,
		"e": 0,
		"c": 0,
		"cs": 0,
	}

func _normalize_resource_token(raw_token: String) -> String:
	var token: String = raw_token.strip_edges().to_lower()
	token = token.replace("\"", "")
	token = token.replace("'", "")
	if RESOURCE_ALIASES.has(token):
		return str(RESOURCE_ALIASES[token])
	return token

func _load_card_definitions() -> void:
	card_defs_by_path.clear()
	var cards_file: FileAccess = FileAccess.open(CARDS_DATA_PATH, FileAccess.READ)
	if cards_file == null:
		push_warning("Could not open cards data file: %s" % CARDS_DATA_PATH)
		return
	var source_text: String = cards_file.get_as_text()
	var card_entries: Array = _parse_card_entries_from_js(source_text)
	var ordered_paths: Array[String] = []
	for p in all_infamy_cards:
		ordered_paths.append(p)
	for p in all_supply_cards:
		ordered_paths.append(p)

	var count: int = mini(card_entries.size(), ordered_paths.size())
	for i in range(count):
		var card_def: Dictionary = card_entries[i]
		card_defs_by_path[ordered_paths[i]] = card_def

	if card_entries.size() != ordered_paths.size():
		push_warning("Card data count mismatch: %d entries for %d deck cards" % [card_entries.size(), ordered_paths.size()])

func _parse_card_entries_from_js(source_text: String) -> Array:
	var clean_lines: Array[String] = []
	for raw_line in source_text.split("\n"):
		var line: String = raw_line
		var comment_index: int = line.find("//")
		if comment_index >= 0:
			line = line.substr(0, comment_index)
		clean_lines.append(line)
	var text: String = "\n".join(clean_lines)

	var entries: Array = []
	var depth: int = 0
	var start: int = -1
	for i in range(text.length()):
		var ch: String = text.substr(i, 1)
		if ch == "{":
			if depth == 0:
				start = i
			depth += 1
		elif ch == "}":
			if depth > 0:
				depth -= 1
				if depth == 0 and start >= 0:
					var block: String = text.substr(start, i - start + 1)
					var card_def: Dictionary = _parse_card_block(block)
					if not str(card_def.get("title", "")).is_empty():
						entries.append(card_def)
					start = -1
	return entries

func _parse_card_block(block: String) -> Dictionary:
	return {
		"title": _extract_string_field(block, "title"),
		"cost": _extract_array_field(block, "cost"),
		"discard": _extract_array_field(block, "discard"),
		"production": _extract_array_field(block, "production"),
	}

func _extract_string_field(block: String, field_name: String) -> String:
	var re: RegEx = RegEx.new()
	var pattern: String = '"%s"\\s*:\\s*"([^"]*)"' % field_name
	if re.compile(pattern) != OK:
		return ""
	var match: RegExMatch = re.search(block)
	if match == null:
		return ""
	return match.get_string(1)

func _extract_array_field(block: String, field_name: String) -> Array:
	var re: RegEx = RegEx.new()
	var pattern: String = '"%s"\\s*:\\s*\\[([^\\]]*)\\]' % field_name
	if re.compile(pattern) != OK:
		return []
	var match: RegExMatch = re.search(block)
	if match == null:
		return []
	var raw_content: String = match.get_string(1)
	var out: Array = []
	for raw_part in raw_content.split(","):
		var token: String = raw_part.strip_edges()
		token = token.trim_prefix("\"").trim_suffix("\"")
		token = token.trim_prefix("'").trim_suffix("'")
		if token.is_empty():
			continue
		out.append(token)
	return out

func _remove_card_from_hand(card: TextureRect) -> Texture2D:
	if not hand_cards.has(card):
		return null
	var card_path: String = _get_card_path(card)
	var card_texture: Texture2D = card.texture
	hand_cards.erase(card)
	payment_selected_cards.erase(card)
	if hovered_hand_card == card:
		hovered_hand_card = null
	if selected_hand_card == card:
		selected_hand_card = null
	card.queue_free()
	_layout_hand(true)
	call_deferred("_layout_hand_deferred")
	if pending_build_card == card:
		pending_build_card = null
	if card_path.is_empty() and card_texture != null:
		card_path = card_texture.resource_path
	if not card_path.is_empty():
		selected_hand_card = null
		build_card_preview.texture = null
	return card_texture

func _build_card_from_hand(card: TextureRect) -> void:
	var card_path: String = _get_card_path(card)
	var card_texture: Texture2D = _remove_card_from_hand(card)
	if card_texture == null:
		return

	var target_column_index: int = _pick_crew_column_index()
	var target_column: Control = crew_columns[target_column_index]

	var crew_card := TextureRect.new()
	crew_card.texture = card_texture
	if not card_path.is_empty():
		crew_card.set_meta("card_path", card_path)
	crew_card.mouse_filter = Control.MOUSE_FILTER_STOP
	crew_card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crew_card.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	crew_card.size = CREW_CARD_SIZE
	crew_card.pivot_offset = CREW_CARD_SIZE / 2.0
	crew_card.material = _create_card_display_material()
	crew_card.resized.connect(_on_card_rect_resized.bind(crew_card))
	crew_card.mouse_entered.connect(_on_crew_card_mouse_entered.bind(crew_card))
	crew_card.mouse_exited.connect(_on_crew_card_mouse_exited.bind(crew_card))
	target_column.add_child(crew_card)
	crew_column_cards[target_column_index].append(crew_card)
	_update_card_material_size(crew_card)
	_layout_crew_column(target_column_index)
	call_deferred("_layout_all_crew_columns")

func _layout_hand_deferred() -> void:
	_layout_hand(false)

func _pick_crew_column_index() -> int:
	var best_index: int = 0
	var best_size: int = crew_column_cards[0].size()
	for i in range(1, CREW_COLUMN_COUNT):
		var size_i: int = crew_column_cards[i].size()
		if size_i < best_size:
			best_size = size_i
			best_index = i
	return best_index

func _layout_crew_column(column_index: int) -> void:
	var column_cards: Array = crew_column_cards[column_index]
	if column_cards.is_empty():
		return

	var y_step: float = CREW_CARD_SIZE.y * CREW_VISIBLE_TOP_RATIO
	if column_cards.size() > 1:
		var max_fit_step: float = (crew_columns[column_index].size.y - CREW_CARD_SIZE.y) / float(column_cards.size() - 1)
		if max_fit_step > 0.0:
			y_step = minf(y_step, max_fit_step)
		y_step = maxf(y_step, CREW_CARD_SIZE.y * 0.1)

	# Increase horizontal stagger as stacks grow, capped for readability.
	var stagger_t: float = clampf(float(column_cards.size() - 1) / 11.0, 0.0, 1.0)
	var dynamic_stagger: float = lerpf(CREW_X_STAGGER, CREW_X_STAGGER * 2.0, stagger_t)

	for i in range(column_cards.size()):
		var card: TextureRect = column_cards[i]
		var center_x: float = (crew_columns[column_index].size.x - CREW_CARD_SIZE.x) * 0.5
		var x_offset: float = 0.0
		if column_cards.size() > 1:
			x_offset = (float(i % 3) - 1.0) * dynamic_stagger
		var pos := Vector2(center_x + x_offset, y_step * i)
		var card_scale := Vector2.ONE
		if card == hovered_crew_card:
			pos.y -= CREW_HOVER_LIFT
			card_scale = Vector2(CREW_HOVER_SCALE, CREW_HOVER_SCALE)

		card.position = pos
		card.rotation_degrees = 0.0
		card.scale = card_scale
		card.z_index = i
		if card == hovered_crew_card:
			card.z_index = 1000

func _layout_all_crew_columns() -> void:
	for i in range(CREW_COLUMN_COUNT):
		_layout_crew_column(i)

func _on_crew_column_resized() -> void:
	_layout_all_crew_columns()

func _on_infamy_row_card_mouse_entered(card: TextureRect) -> void:
	hovered_infamy_row_card = card
	_refresh_infamy_row_hover_visuals(true)

func _on_infamy_row_card_mouse_exited(card: TextureRect) -> void:
	if hovered_infamy_row_card == card:
		hovered_infamy_row_card = null
	_refresh_infamy_row_hover_visuals(true)

func _refresh_infamy_row_hover_visuals(animated: bool) -> void:
	for i in range(row_card_nodes.size()):
		var card: TextureRect = row_card_nodes[i]
		card.pivot_offset = card.size / 2.0
		var is_hovered: bool = card == hovered_infamy_row_card
		var target_scale: Vector2 = Vector2.ONE
		if is_hovered:
			target_scale = Vector2(CREW_HOVER_SCALE, CREW_HOVER_SCALE)
		card.z_index = i
		if is_hovered:
			card.z_index = 1000

		if animated:
			var tween: Tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			tween.tween_property(card, "scale", target_scale, 0.18)
		else:
			card.scale = target_scale

func _on_crew_card_mouse_entered(card: TextureRect) -> void:
	hovered_crew_card = card
	_layout_all_crew_columns()

func _on_crew_card_mouse_exited(card: TextureRect) -> void:
	if hovered_crew_card == card:
		hovered_crew_card = null
	_layout_all_crew_columns()

func _on_infamy_deck_button_pressed() -> void:
	if infamy_deck.is_empty():
		return
	var drawn_path: String = infamy_deck.pop_front()
	_set_last_drawn(drawn_path, "Infamy")
	_refresh_ui()

func _on_supply_deck_button_pressed() -> void:
	if supply_deck.is_empty():
		return
	var drawn_path: String = supply_deck.pop_front()
	_set_last_drawn(drawn_path, "Supply")
	_refresh_ui()

func _setup_new_game() -> void:
	var infamy_pool: Array[String] = all_infamy_cards.duplicate()
	var supply_pool: Array[String] = all_supply_cards.duplicate()
	infamy_pool.shuffle()
	supply_pool.shuffle()

	infamy_row_cards.clear()
	for _i in range(5):
		infamy_row_cards.append(infamy_pool.pop_back())

	var player_windfall: String = infamy_pool.pop_back()

	infamy_deck = infamy_pool
	supply_deck = supply_pool
	revealed_round_index = -1

	for c in hand_cards:
		c.queue_free()
	hand_cards.clear()
	for i in range(CREW_COLUMN_COUNT):
		for c in crew_column_cards[i]:
			c.queue_free()
		crew_column_cards[i].clear()
	pending_build_card = null
	payment_selected_cards.clear()
	if build_confirm_dialog.visible:
		build_confirm_dialog.hide()
	hovered_crew_card = null
	hovered_hand_card = null
	selected_hand_card = null
	_add_card_to_hand(player_windfall)
	call_deferred("_layout_hand_deferred")

	for row_card in row_card_nodes:
		row_card.texture = infamy_back_texture
	hovered_infamy_row_card = null
	_refresh_infamy_row_hover_visuals(false)

	_refresh_ui()

func _on_setup_button_pressed() -> void:
	_setup_new_game()

func _on_reveal_round_button_pressed() -> void:
	if revealed_round_index >= row_card_nodes.size() - 1:
		return

	revealed_round_index += 1
	row_card_nodes[revealed_round_index].texture = _load_texture_from_path(infamy_row_cards[revealed_round_index])
	_refresh_ui()
