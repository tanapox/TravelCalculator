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

# ── Dati caricati da file ─────────────────────────────────────────────────────

# Array[Dictionary] — ogni entry ha: id, name, desc, max_level, costs, connect, grid_x, grid_y
var UPGRADES: Array = []

# Soglie cumulative per i livelli 2..100; indice 0 = soglia livello 2
var _thresholds: Array = []

# ── Init ──────────────────────────────────────────────────────────────────────

func _ready() -> void:
	_load_upgrades()
	_load_levels()

func _load_upgrades() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("res://data/upgrades.cfg") != OK:
		push_error("GameState: impossibile caricare data/upgrades.cfg")
		return
	UPGRADES = []
	for section in cfg.get_sections():
		var costs_raw: Array = cfg.get_value(section, "costs", [])
		var costs: Array = []
		for v in costs_raw:
			costs.append(int(v))
		UPGRADES.append({
			"id":        section,
			"name":      str(cfg.get_value(section, "name",      section)),
			"desc":      str(cfg.get_value(section, "desc",      "")),
			"max_level": int(cfg.get_value(section, "max_level", 1)),
			"costs":     costs,
			"connect":   cfg.get_value(section, "connect", []),
			"grid_x":    int(cfg.get_value(section, "grid_x",    0)),
			"grid_y":    int(cfg.get_value(section, "grid_y",    0)),
		})

func _load_levels() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("res://data/levels.cfg") != OK:
		push_warning("GameState: impossibile caricare data/levels.cfg — uso formula predefinita")
		_fallback_thresholds()
		return
	_thresholds = []
	for lvl in range(2, 101):
		var key := "l%d" % lvl
		var val = cfg.get_value("thresholds", key, null)
		if val == null:
			break
		_thresholds.append(int(val))
	if _thresholds.is_empty():
		_fallback_thresholds()

func _fallback_thresholds() -> void:
	_thresholds = []
	for n in range(1, 100):
		_thresholds.append(500 * n * (n + 1))

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
	if cur >= int(upg.max_level):
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
		"fire_rate":    return "+%d%% velocità, int. %.0fs" % [l * 20, shot_interval()]
		"critical":
			var pct := [0, 5, 10, 20, 35, 50]
			return "%d%% probabilità critico (×3)" % pct[l]
		"launchers":    return "%d cannoni attivi" % (2 + l * 2)
		"penetration":  return "-%d%% HP celle (mult ×%.2f)" % [l * 15, terrain_hp_mult()]
		"slots":        return "%d slot totali" % slot_count()
		"multiplier":   return "×%.1f su tutti i moltiplicatori" % multiplier_boost()
		"worm_power":   return "+%d passi, raggio ×%.1f" % [l * 80, worm_eat_radius()]
		"ammo":         return "%d armi/round, round %.0fs" % [shots_per_round(), shot_interval() * shots_per_round()]
	return ""

# Soglia di total_earned per raggiungere il livello lvl (caricata da file)
func level_threshold(lvl: int) -> int:
	if lvl <= 1:
		return 0
	var idx := lvl - 2   # livello 2 → indice 0
	if idx >= _thresholds.size():
		return 999999999
	return _thresholds[idx]

# ── Getter effetti ────────────────────────────────────────────────────────────

func weapon_damage_mult() -> float:
	return 1.0 + get_upg_level("weapon_power") * 0.25

func projectile_speed_mult() -> float:
	return 1.0 + get_upg_level("fire_rate") * 0.20

func critical_chance() -> float:
	return ([0.0, 0.05, 0.10, 0.20, 0.35, 0.50] as Array)[get_upg_level("critical")]

func launcher_positions() -> Dictionary:
	var n := 1 + get_upg_level("launchers")
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

# Secondi tra un'arma e la prossima (migliora con fire_rate)
func shot_interval() -> float:
	return maxf(0.5, 3.0 - float(get_upg_level("fire_rate")) * 0.5)

# Numero di armi disponibili per round (migliora con ammo)
func shots_per_round() -> int:
	return 2 + get_upg_level("ammo")

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
