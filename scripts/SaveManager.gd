extends Node

const SAVE_PATH = "user://save.json"
const AUTOSAVE_INTERVAL = 30.0

var _autosave_timer: float = 0.0

func _process(delta: float) -> void:
	_autosave_timer += delta
	if _autosave_timer >= AUTOSAVE_INTERVAL:
		_autosave_timer = 0.0
		save_game()

func save_game() -> void:
	var data: Dictionary = {
		"cookies": GameManager.cookies,
		"total_cookies": GameManager.total_cookies,
		"cookies_per_click": GameManager.cookies_per_click,
		"buildings": {},
		"upgrades": {}
	}

	for id in GameManager.buildings:
		var b = GameManager.buildings[id]
		data.buildings[id] = {
			"count": b.count,
			"cost": b.cost,
			"cps_multiplier": b.cps_multiplier
		}

	for id in GameManager.upgrades:
		data.upgrades[id] = {
			"bought": GameManager.upgrades[id].bought
		}

	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return false

	var json = JSON.new()
	var err = json.parse(file.get_as_text())
	file.close()

	if err != OK:
		return false

	var data = json.get_data()

	GameManager.cookies = float(data.get("cookies", 0.0))
	GameManager.total_cookies = float(data.get("total_cookies", 0.0))
	GameManager.cookies_per_click = float(data.get("cookies_per_click", 1.0))

	if data.has("buildings"):
		for id in data.buildings:
			if GameManager.buildings.has(id):
				var saved = data.buildings[id]
				GameManager.buildings[id].count = int(saved.get("count", 0))
				GameManager.buildings[id].cost = float(saved.get("cost", GameManager.buildings[id].base_cost))
				GameManager.buildings[id].cps_multiplier = float(saved.get("cps_multiplier", 1.0))

	if data.has("upgrades"):
		for id in data.upgrades:
			if GameManager.upgrades.has(id):
				GameManager.upgrades[id].bought = bool(data.upgrades[id].get("bought", false))

	GameManager._recalculate_cps()
	return true

func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
