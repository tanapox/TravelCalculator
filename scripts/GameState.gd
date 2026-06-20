extends Node

# ── Segnali ───────────────────────────────────────────────────────────────────

signal money_changed(amount: int)
signal level_up(new_level: int)
signal upgrade_bought(upgrade_id: String)

# ── Stato ─────────────────────────────────────────────────────────────────────

var money:        int = 0
var total_earned: int = 0
var level:        int = 1
var _up_lvls:     Dictionary = {}

# ── Catalogo potenziamenti ────────────────────────────────────────────────────

const UPGRADES: Array = [
	{"id": "weapon_power", "name": "Potenza Armi",      "desc": "Danno di tutte le armi +25% per livello",       "max_level": 10, "costs": [50,120,250,500,1000,2000,4000,8000,16000,32000]},
	{"id": "fire_rate",    "name": "Cadenza di Fuoco",   "desc": "Velocità proiettili e raffica +20% per livello","max_level": 8,  "costs": [80,160,320,650,1300,2500,5000,10000]},
	{"id": "critical",     "name": "Colpi Critici",      "desc": "Probabilità di infliggere 3× il danno",         "max_level": 5,  "costs": [200,500,1200,3000,8000]},
	{"id": "launchers",    "name": "Basi di Lancio",     "desc": "+2 posizioni di tiro aggiuntive per livello",   "max_level": 3,  "costs": [300,1500,6000]},
	{"id": "penetration",  "name": "Perforazione",       "desc": "HP celle terreno -15% per livello",             "max_level": 5,  "costs": [150,350,750,1800,4000]},
	{"id": "slots",        "name": "Slot Aggiuntivi",    "desc": "+3 caselle nella zona raccolta per livello",     "max_level": 3,  "costs": [500,2000,8000]},
	{"id": "multiplier",   "name": "Moltiplicatori",     "desc": "Tutti i moltiplicatori degli slot scalati",     "max_level": 5,  "costs": [400,1000,2500,6000,15000]},
	{"id": "worm_power",   "name": "Potenza Verme",      "desc": "Verme con più passi e raggio di mangiatura",    "max_level": 4,  "costs": [250,600,1500,4000]},
]

# ── API pubblica ──────────────────────────────────────────────────────────────

func add_money(amount: int) -> void:
	money        += amount
	total_earned += amount
	money_changed.emit(money)
	_check_level_up()

func buy_upgrade(id: String) -> bool:
	var upg := _find(id)
	if upg.is_empty():
		return false
	var cur := get_upg_level(id)
	if cur >= upg.max_level:
		return false
	var cost: int = upg.costs[cur]
	if money < cost:
		return false
	money -= cost
	_up_lvls[id] = cur + 1
	money_changed.emit(money)
	upgrade_bought.emit(id)
	return true

func get_upg_level(id: String) -> int:
	return _up_lvls.get(id, 0)

func next_cost(id: String) -> int:
	var upg := _find(id)
	if upg.is_empty():
		return 0
	var cur := get_upg_level(id)
	return 0 if cur >= int(upg.max_level) else int(upg.costs[cur])

func effect_text(id: String) -> String:
	var l := get_upg_level(id)
	match id:
		"weapon_power": return "+%d%% danno (ora ×%.2f)" % [l * 25, weapon_damage_mult()]
		"fire_rate":    return "+%d%% velocità (ora ×%.2f)" % [l * 20, projectile_speed_mult()]
		"critical":
			var pct := [0, 5, 10, 20, 35, 50]
			return "%d%% probabilità critico (×3)" % pct[l]
		"launchers":    return "%d cannoni attivi" % (2 + l * 2)
		"penetration":  return "-%d%% HP celle (mult ×%.2f)" % [l * 15, terrain_hp_mult()]
		"slots":        return "%d slot totali" % slot_count()
		"multiplier":   return "×%.1f su tutti i moltiplicatori" % multiplier_boost()
		"worm_power":   return "+%d passi, raggio ×%.1f" % [l * 80, worm_eat_radius()]
	return ""

# Soglia cumulativa di money_earned per raggiungere il livello lvl
func level_threshold(lvl: int) -> int:
	if lvl <= 1:
		return 0
	var n := lvl - 1
	return 500 * n * (n + 1)

# ── Getter effetti ────────────────────────────────────────────────────────────

func weapon_damage_mult() -> float:
	return 1.0 + get_upg_level("weapon_power") * 0.25

func projectile_speed_mult() -> float:
	return 1.0 + get_upg_level("fire_rate") * 0.20

func critical_chance() -> float:
	return ([0.0, 0.05, 0.10, 0.20, 0.35, 0.50] as Array)[get_upg_level("critical")]

func launcher_positions() -> Dictionary:
	var n := 1 + get_upg_level("launchers")   # 1..4 posizioni per lato
	var presets := {
		1: [120.0],
		2: [65.0, 175.0],
		3: [45.0, 120.0, 195.0],
		4: [35.0, 90.0, 150.0, 205.0]
	}
	var ys: Array = presets[n]
	var left: Array = []; var right: Array = []
	for y in ys:
		left.append(Vector2(40.0, y))
		right.append(Vector2(1240.0, y))
	return {"left": left, "right": right}

func terrain_hp_mult() -> float:
	var base       := 1.0 + float(level - 1) * 0.04
	var pen_factor := 1.0 - get_upg_level("penetration") * 0.15
	return maxf(0.05, base * pen_factor)

func flame_interval() -> float:
	return maxf(0.015, 0.07 / projectile_speed_mult())

func slot_count() -> int:
	return 10 + get_upg_level("slots") * 3

func multiplier_boost() -> float:
	return ([1.0, 1.5, 2.0, 3.0, 5.0, 8.0] as Array)[get_upg_level("multiplier")]

func worm_steps() -> int:
	return 240 + get_upg_level("worm_power") * 80

func worm_eat_radius() -> float:
	return 1.6 + get_upg_level("worm_power") * 0.4

# ── Privato ───────────────────────────────────────────────────────────────────

func _find(id: String) -> Dictionary:
	for upg in UPGRADES:
		if upg.id == id:
			return upg
	return {}

func _check_level_up() -> void:
	while level < 100 and total_earned >= level_threshold(level + 1):
		level += 1
		level_up.emit(level)
