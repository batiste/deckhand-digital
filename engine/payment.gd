class_name Payment
extends RefCounted
## Build cost resolution.
##
## A "source" supplies exactly one resource token, chosen from its options.
## Sources come from crew production (each slot once per build) and from
## discarded hand cards:
##   - 1 card (face down): a silver or gold coin
##   - 1 card (revealed): one resource that card produces
##   - 2 cards: any resource
##   - Windfall: 2 silver coins, or 1 gold + 1 silver; or, being a hand card,
##     one of the 2 cards of a pair
## Which discarded cards are paired is chosen automatically to cover the most.

const ANY: Array[String] = ["g", "p", "r", "h", "s", "e", "c", "cs"]

## Returns {ok: bool, covered: int, missing: Array[String]} for paying `cost`
## with `crew_slots` plus the given discards.
static func evaluate(cost: Array, crew_slots: Array, discards: Array, use_windfall: bool) -> Dictionary:
	var best_covered := -1
	var best_sources: Array = []
	var n := discards.size()
	# The windfall, if used, is one more discard (index n).
	var total := n + (1 if use_windfall else 0)
	# Try every split of the discards into singles and pairs (hands are small).
	for mask in range(1 << total):
		var paired := 0
		var sources: Array = crew_slots.duplicate()
		for i in range(total):
			if mask & (1 << i):
				paired += 1
			elif i == n:
				sources.append(["cs"])
				sources.append(["cs", "c"])
			else:
				sources.append(_single_discard_options(discards[i]))
		if paired % 2 == 1:
			continue
		for _w in range(paired / 2):
			sources.append(ANY)
		var covered := _max_matching(cost, sources)
		if covered > best_covered:
			best_covered = covered
			best_sources = sources
		if covered == cost.size():
			break

	return {
		"ok": best_covered == cost.size(),
		"covered": best_covered,
		"missing": _unmatched(cost, best_sources),
	}

## What crew production alone leaves unpaid.
static func missing_after_crew(cost: Array, crew_slots: Array) -> Array[String]:
	return _unmatched(cost, crew_slots)

## Picks discards to pay `cost`, preferring cards with low `keep_value`.
## `candidates` are hand card ids (the card being built must be excluded).
## Returns {ok, discards: Array[int], windfall: bool}.
static func plan(cost: Array, crew_slots: Array, candidates: Array, keep_value: Callable, windfall_value: float = INF) -> Dictionary:
	var chosen: Array[int] = []
	var use_windfall := false
	if evaluate(cost, crew_slots, chosen, false).ok:
		return {"ok": true, "discards": chosen, "windfall": false}

	var pool: Array = candidates.duplicate()
	pool.sort_custom(func(a: int, b: int) -> bool: return keep_value.call(a) < keep_value.call(b))

	var covered: int = evaluate(cost, crew_slots, chosen, false).covered
	while covered < cost.size():
		var best_gain := 0.0
		var best_pick: Array = []
		var best_windfall := false
		var best_covered := covered
		# One card that adds coverage.
		for id: int in pool:
			var trial := chosen.duplicate()
			trial.append(id)
			var c: int = evaluate(cost, crew_slots, trial, use_windfall).covered
			if c > covered:
				var gain: float = float(c - covered) / maxf(keep_value.call(id), 0.05)
				if gain > best_gain:
					best_gain = gain
					best_pick = [id]
					best_windfall = use_windfall
					best_covered = c
			# One card paired with the windfall.
			if not use_windfall and windfall_value < INF:
				var c2: int = evaluate(cost, crew_slots, trial, true).covered
				if c2 > covered:
					var gain2: float = float(c2 - covered) / maxf(keep_value.call(id) + windfall_value, 0.05)
					if gain2 > best_gain:
						best_gain = gain2
						best_pick = [id]
						best_windfall = true
						best_covered = c2
		# The windfall.
		if not use_windfall and windfall_value < INF:
			var c: int = evaluate(cost, crew_slots, chosen, true).covered
			if c > covered:
				var gain: float = float(c - covered) / maxf(windfall_value, 0.05)
				if gain > best_gain:
					best_gain = gain
					best_pick = []
					best_windfall = true
					best_covered = c
		# Two cheapest unused cards as a wildcard pair.
		if best_pick.is_empty() and not best_windfall:
			var spare: Array = pool.filter(func(id: int) -> bool: return not chosen.has(id))
			if spare.size() >= 2:
				var trial := chosen.duplicate()
				trial.append(spare[0])
				trial.append(spare[1])
				var c: int = evaluate(cost, crew_slots, trial, use_windfall).covered
				if c > covered:
					best_pick = [spare[0], spare[1]]
					best_covered = c
		if best_pick.is_empty() and not best_windfall:
			return {"ok": false, "discards": chosen, "windfall": use_windfall}
		for id: int in best_pick:
			chosen.append(id)
			pool.erase(id)
		use_windfall = use_windfall or best_windfall
		covered = best_covered

	# Drop anything that turned out to be unnecessary, most valuable first.
	var by_value := chosen.duplicate()
	by_value.sort_custom(func(a: int, b: int) -> bool: return keep_value.call(a) > keep_value.call(b))
	for id: int in by_value:
		var trial := chosen.duplicate()
		trial.erase(id)
		if evaluate(cost, crew_slots, trial, use_windfall).ok:
			chosen = trial
	if use_windfall and evaluate(cost, crew_slots, chosen, false).ok:
		use_windfall = false
	return {"ok": true, "discards": chosen, "windfall": use_windfall}

static func _single_discard_options(id: int) -> Array:
	var options: Array = ["cs", "c"]
	for token in CardDB.production_tokens(id):
		if not options.has(token):
			options.append(token)
	return options

## Kuhn's augmenting-path bipartite matching: cost tokens -> sources.
static func _max_matching(cost: Array, sources: Array) -> int:
	return _matching(cost, sources).count

static func _matching(cost: Array, sources: Array) -> Dictionary:
	var source_owner: Array[int] = []
	source_owner.resize(sources.size())
	source_owner.fill(-1)
	var count := 0
	for i in range(cost.size()):
		var seen: Array[bool] = []
		seen.resize(sources.size())
		seen.fill(false)
		if _augment(i, cost, sources, source_owner, seen):
			count += 1
	return {"count": count, "owner": source_owner}

static func _augment(i: int, cost: Array, sources: Array, owner: Array[int], seen: Array[bool]) -> bool:
	for j in range(sources.size()):
		if seen[j] or not (sources[j] as Array).has(cost[i]):
			continue
		seen[j] = true
		if owner[j] == -1 or _augment(owner[j], cost, sources, owner, seen):
			owner[j] = i
			return true
	return false

static func _unmatched(cost: Array, sources: Array) -> Array[String]:
	var owner: Array[int] = _matching(cost, sources).owner
	var matched: Array[bool] = []
	matched.resize(cost.size())
	matched.fill(false)
	for j in range(owner.size()):
		if owner[j] >= 0:
			matched[owner[j]] = true
	var out: Array[String] = []
	for i in range(cost.size()):
		if not matched[i]:
			out.append(cost[i])
	return out
