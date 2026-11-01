extends SceneTree
## Finds the order of the banners printed on each Infamy card (left to
## right), by matching each one's colour against the banner icons, and writes
## data/infamy_banners.json (card id -> banner names). The card data lists a
## card's banners in another order; the table needs the printed one to put a
## check on each banner you have.
##   godot --headless --path . -s res://tools/infamy_banners.gd

const SPACING := 0.152 # between banner centres, in card widths
const TOP := 0.83
const BOTTOM := 0.92

func _init() -> void:
	CardDB.ensure_loaded()
	var palette := {}
	for b in CardDB.BANNERS:
		palette[b] = _mean(Image.load_from_file("res://assets/icons/banner-%s.png" % b), Rect2i(Vector2i.ZERO, Vector2i(9999, 9999)))
	var out := {}
	var mismatches := 0
	for id in CardDB.ids_of_kind("infamy"):
		var card := CardDB.get_card(id)
		var img := Image.load_from_file(card.file)
		var n: int = card.cost.size()
		var left: Array = card.cost.duplicate()
		var order: Array[String] = []
		for i in n:
			var cx := 0.5 + (i - (n - 1) / 2.0) * SPACING
			var box := Rect2i(int((cx - 0.04) * img.get_width()), int(TOP * img.get_height()), int(0.08 * img.get_width()), int((BOTTOM - TOP) * img.get_height()))
			var seen := _mean(img, box)
			# The closest banner still to be placed.
			var best := ""
			for b: String in left:
				if best == "" or _distance(seen, palette[b]) < _distance(seen, palette[best]):
					best = b
			order.append(best)
			left.erase(best)
		out[str(id)] = order
		var counts_ok := true
		for b in CardDB.BANNERS:
			if order.count(b) != card.cost.count(b):
				counts_ok = false
		if not counts_ok:
			mismatches += 1
		print("%-20s data %-40s printed %s" % [card.title, str(card.cost), str(order)])
	var file := FileAccess.open("res://data/infamy_banners.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(out, "\t"))
	print("wrote data/infamy_banners.json (%d mismatches)" % mismatches)
	quit(0)

## Mean colour of the opaque pixels in `rect`.
func _mean(img: Image, rect: Rect2i) -> Color:
	rect = rect.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var sum := Color(0, 0, 0, 0)
	var n := 0
	for y in range(rect.position.y, rect.end.y, 3):
		for x in range(rect.position.x, rect.end.x, 3):
			var c := img.get_pixel(x, y)
			if c.a > 0.8:
				sum += c
				n += 1
	return sum / maxf(n, 1)

func _distance(a: Color, b: Color) -> float:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
