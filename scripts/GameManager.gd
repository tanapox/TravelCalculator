extends Node

var cookies: float = 0.0
var total_cookies: float = 0.0
var cookies_per_second: float = 0.0
var cookies_per_click: float = 1.0

var buildings: Dictionary = {
	"cursor": {
		"name": "Cursore",
		"description": "Clicca automaticamente ogni 10 secondi.",
		"base_cost": 15.0,
		"base_cps": 0.1,
		"cps_multiplier": 1.0,
		"count": 0,
		"cost": 15.0
	},
	"grandma": {
		"name": "Nonna",
		"description": "Una gentile nonna che cuoce biscotti.",
		"base_cost": 100.0,
		"base_cps": 0.5,
		"cps_multiplier": 1.0,
		"count": 0,
		"cost": 100.0
	},
	"farm": {
		"name": "Fattoria",
		"description": "Coltiva biscotti in modo naturale.",
		"base_cost": 500.0,
		"base_cps": 2.0,
		"cps_multiplier": 1.0,
		"count": 0,
		"cost": 500.0
	},
	"mine": {
		"name": "Miniera",
		"description": "Estrae pepite di biscotti dalla terra.",
		"base_cost": 2000.0,
		"base_cps": 10.0,
		"cps_multiplier": 1.0,
		"count": 0,
		"cost": 2000.0
	},
	"factory": {
		"name": "Fabbrica",
		"description": "Produce biscotti industrialmente.",
		"base_cost": 10000.0,
		"base_cps": 50.0,
		"cps_multiplier": 1.0,
		"count": 0,
		"cost": 10000.0
	},
	"laboratory": {
		"name": "Laboratorio",
		"description": "Ricerca nuove formule di biscotti.",
		"base_cost": 75000.0,
		"base_cps": 260.0,
		"cps_multiplier": 1.0,
		"count": 0,
		"cost": 75000.0
	}
}

# order in which buildings appear in the shop
var building_order: Array = ["cursor", "grandma", "farm", "mine", "factory", "laboratory"]

var upgrades: Dictionary = {
	"better_click": {
		"name": "Click Potenziato",
		"description": "I tuoi click producono il doppio.",
		"cost": 100.0,
		"bought": false,
		"unlock_condition": "total_cookies:10"
	},
	"cursor_boost": {
		"name": "Cursori Veloci",
		"description": "I cursori producono il doppio.",
		"cost": 500.0,
		"bought": false,
		"unlock_condition": "building:cursor:1"
	},
	"grandma_recipes": {
		"name": "Ricette Segrete",
		"description": "Le nonne producono il doppio.",
		"cost": 2000.0,
		"bought": false,
		"unlock_condition": "building:grandma:1"
	},
	"mega_click": {
		"name": "Mega Click",
		"description": "Ogni click vale 10x tanto.",
		"cost": 50000.0,
		"bought": false,
		"unlock_condition": "better_click:bought"
	},
	"farm_fertilizer": {
		"name": "Fertilizzante Speciale",
		"description": "Le fattorie producono il doppio.",
		"cost": 10000.0,
		"bought": false,
		"unlock_condition": "building:farm:1"
	},
	"deep_mining": {
		"name": "Scavo Profondo",
		"description": "Le miniere producono il doppio.",
		"cost": 40000.0,
		"bought": false,
		"unlock_condition": "building:mine:1"
	},
	"automation": {
		"name": "Automazione",
		"description": "Le fabbriche producono il doppio.",
		"cost": 200000.0,
		"bought": false,
		"unlock_condition": "building:factory:1"
	}
}

signal cookies_changed(amount: float)
signal cps_changed(amount: float)
signal building_bought(building_id: String)
signal upgrade_bought(upgrade_id: String)
signal upgrade_unlocked(upgrade_id: String)

var _unlocked_upgrades: Dictionary = {}

func _process(delta: float) -> void:
	if cookies_per_second > 0.0:
		var earned = cookies_per_second * delta
		cookies += earned
		total_cookies += earned
		emit_signal("cookies_changed", cookies)
	_check_upgrade_unlocks()

func click() -> void:
	cookies += cookies_per_click
	total_cookies += cookies_per_click
	emit_signal("cookies_changed", cookies)

func can_afford(cost: float) -> bool:
	return cookies >= cost

func buy_building(id: String) -> bool:
	if not buildings.has(id):
		return false
	var b = buildings[id]
	if not can_afford(b.cost):
		return false

	cookies -= b.cost
	b.count += 1
	b.cost = b.base_cost * pow(1.15, b.count)
	_recalculate_cps()
	emit_signal("building_bought", id)
	emit_signal("cookies_changed", cookies)
	return true

func buy_upgrade(id: String) -> bool:
	if not upgrades.has(id):
		return false
	var u = upgrades[id]
	if u.bought or not can_afford(u.cost):
		return false

	cookies -= u.cost
	u.bought = true
	_apply_upgrade(id)
	emit_signal("upgrade_bought", id)
	emit_signal("cookies_changed", cookies)
	return true

func is_upgrade_unlocked(id: String) -> bool:
	return _unlocked_upgrades.get(id, false)

func _check_upgrade_unlocks() -> void:
	for id in upgrades:
		if upgrades[id].bought or _unlocked_upgrades.get(id, false):
			continue
		if _evaluate_unlock_condition(upgrades[id].unlock_condition):
			_unlocked_upgrades[id] = true
			emit_signal("upgrade_unlocked", id)

func _evaluate_unlock_condition(condition: String) -> bool:
	var parts = condition.split(":")
	match parts[0]:
		"total_cookies":
			return total_cookies >= float(parts[1])
		"building":
			return buildings[parts[1]].count >= int(parts[2])
		_:
			var upg_id = parts[0]
			return upgrades.get(upg_id, {}).get("bought", false)
	return false

func _apply_upgrade(id: String) -> void:
	match id:
		"better_click":
			cookies_per_click *= 2.0
		"mega_click":
			cookies_per_click *= 10.0
		"cursor_boost":
			buildings["cursor"].cps_multiplier *= 2.0
		"grandma_recipes":
			buildings["grandma"].cps_multiplier *= 2.0
		"farm_fertilizer":
			buildings["farm"].cps_multiplier *= 2.0
		"deep_mining":
			buildings["mine"].cps_multiplier *= 2.0
		"automation":
			buildings["factory"].cps_multiplier *= 2.0
	_recalculate_cps()

func _recalculate_cps() -> void:
	var total: float = 0.0
	for id in buildings:
		var b = buildings[id]
		total += b.base_cps * b.cps_multiplier * b.count
	cookies_per_second = total
	emit_signal("cps_changed", cookies_per_second)

func format_number(n: float) -> String:
	if n < 0.0:
		return "0"
	if n >= 1_000_000_000_000.0:
		return "%.2f T" % (n / 1_000_000_000_000.0)
	elif n >= 1_000_000_000.0:
		return "%.2f B" % (n / 1_000_000_000.0)
	elif n >= 1_000_000.0:
		return "%.2f M" % (n / 1_000_000.0)
	elif n >= 1_000.0:
		return "%.2f K" % (n / 1_000.0)
	else:
		return "%.1f" % n
