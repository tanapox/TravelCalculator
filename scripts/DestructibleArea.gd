class_name DestructibleArea
extends Node2D

# ── Layout ────────────────────────────────────────────────────────────────────

const CELL:       int = 4
const LAUNCHER_W: int = 80
const AREA_W:     int = 1280
const AREA_H:     int = 240
const GRID_X:     int = LAUNCHER_W                             # x dove inizia la griglia
const COLS:       int = (AREA_W - LAUNCHER_W * 2) / CELL      # 280
const TERRAIN_Y:  int = AREA_H / 2                            # y da cui parte il terreno (120)
var   ROWS:       int = 20   # letto da GameState.terrain_rows in _ready()

const LEFT_LAUNCHER:  Vector2 = Vector2(40.0,  120.0)
const RIGHT_LAUNCHER: Vector2 = Vector2(1240.0, 120.0)

# ── Palette ───────────────────────────────────────────────────────────────────
# Caricata da data/materials.cfg in _ready(). Struttura: [Color, hp:float, name:String]

var PALETTE: Array = [
	[Color(0.95, 0.95, 0.92),  10.0,   "Gesso"],
	[Color(0.85, 0.26, 0.26),  30.0,   "Mattone"],
	[Color(0.88, 0.58, 0.14),  55.0,   "Arenaria"],
	[Color(0.28, 0.72, 0.22),  90.0,   "Roccia"],
	[Color(0.18, 0.44, 0.88), 140.0,   "Granito"],
	[Color(0.52, 0.14, 0.82), 230.0,   "Marmo"],
	[Color(0.11, 0.11, 0.13), 9999.0,  "Acciaio"],
]

# ── Armi ─────────────────────────────────────────────────────────────────────

enum Weapon { BULLET, BOMB, MISSILE, FLAMETHROWER, ACID, WORM }

const WEAPONS: Dictionary = {
	Weapon.BULLET:       {key=KEY_1, name="Proiettile",    color=Color(1.0, 1.0, 0.3),  proj_r=5.0,  impact_r= 0.0, dmg=9999.0, speed=2.8, rate=1.2,  arc_h=25.0,  desc="distrugge 1 cella"},
	Weapon.BOMB:         {key=KEY_2, name="Bomba",         color=Color(1.0, 0.45, 0.1), proj_r=9.0,  impact_r=42.0, dmg= 180.0, speed=1.2, rate=3.0,  arc_h=110.0, desc="esplosione media"},
	Weapon.MISSILE:      {key=KEY_3, name="Missile",       color=Color(0.9, 0.9,  0.9), proj_r=7.0,  impact_r=85.0, dmg= 260.0, speed=1.6, rate=4.0,  arc_h=70.0,  desc="esplosione grande"},
	Weapon.FLAMETHROWER: {key=KEY_4, name="Lanciafiamme",  color=Color(1.0, 0.55, 0.0), proj_r=5.0,  impact_r=20.0, dmg=  40.0, speed=3.5, rate=0.12, arc_h=12.0,  desc="raffiche rapide"},
	Weapon.ACID:         {key=KEY_5, name="Acido",         color=Color(0.3, 1.0,  0.2), proj_r=6.0,  impact_r=14.0, dmg=   0.0, speed=1.2, rate=1.8,  arc_h=90.0,  desc="corrosivo + si espande"},
	Weapon.WORM:         {key=KEY_6, name="Verme",         color=Color(0.85, 0.5, 0.1), proj_r=7.0,  impact_r= 0.0, dmg=   0.0, speed=1.0, rate=5.0,  arc_h=40.0,  desc="mangia il terreno a caso"},
}

# ── Inner overlay node ────────────────────────────────────────────────────────

class OverlayNode extends Node2D:
	var area: DestructibleArea
	func _draw() -> void:
		if not area:
			return
		for fx in area._vfx:
			var alpha: float = (1.0 - float(fx.t) / float(fx.dur)) * 0.6
			draw_circle(fx.pos, float(fx.r),        Color(fx.color.r, fx.color.g, fx.color.b, alpha * 0.5))
			draw_circle(fx.pos, float(fx.r) * 0.55, Color(1.0, 0.95, 0.7, alpha))
		for proj in area._projectiles:
			var w: Dictionary = area.WEAPONS[proj.weapon]
			var pos: Vector2  = area._proj_pos(proj)
			for i in 6:
				var tt: float = float(proj.t) - float(i + 1) * 0.025
				if tt < 0.0:
					continue
				var tp: Vector2 = area._proj_pos_at(proj, tt)
				var a: float    = maxf(0.0, 0.28 - float(i) * 0.04)
				draw_circle(tp, float(w.proj_r) * (0.6 - float(i) * 0.08),
							Color(w.color.r, w.color.g, w.color.b, a))
			draw_circle(pos, float(w.proj_r), w.color)
			draw_circle(pos, float(w.proj_r) * 0.45, (w.color as Color).lightened(0.5))
		var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
		for worm in area._worms:
			var lp: Vector2 = area._cell_to_local(int(worm.col), int(worm.row))
			draw_circle(lp, 8.0 + pulse * 3.0, Color(0.9, 0.5, 0.1, 0.35))
			draw_circle(lp, 6.0, Color(1.0, 0.72, 0.2))
			draw_circle(lp, 3.0, Color(1.0, 1.0, 0.6))

# ── Stato ─────────────────────────────────────────────────────────────────────

signal weapon_fired

var current_weapon:   Weapon = Weapon.BULLET
var shots_available:  int    = 0   # impostato da Main ogni round

var _hp:       PackedFloat32Array
var _max_hp:   PackedFloat32Array
var _base_col: PackedColorArray

var _img:     Image
var _tex:     ImageTexture
var _sprite:  Sprite2D
var _overlay: OverlayNode

# Fisica per riga: ogni riga ha uno StaticBody2D con segmenti di celle vive.
# Quando una cella viene distrutta quella riga viene rigenerata.
var _physics_rows:  Array      = []   # Array[StaticBody2D]
var _dirty_rows:    Dictionary = {}   # row_index -> true

var _projectiles: Array = []
var _worms:       Array = []
var _acid_cells:  Dictionary = {}
var _vfx:         Array = []

var _placed_weapons: Array = []
var _shots_last:     int   = -1
var _active_rows:    int   = 0

var _label: Label

# ── Init ──────────────────────────────────────────────────────────────────────

func _load_palette() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("res://data/materials.cfg") != OK:
		push_warning("DestructibleArea: materials.cfg non trovato — uso palette predefinita")
		return
	var loaded: Array = []
	for section in cfg.get_sections():
		var r: float = float(cfg.get_value(section, "color_r", 0.5))
		var g: float = float(cfg.get_value(section, "color_g", 0.5))
		var b: float = float(cfg.get_value(section, "color_b", 0.5))
		var hp: float = float(cfg.get_value(section, "hp", 10.0))
		loaded.append([Color(r, g, b), hp, section])
	if loaded.size() > 0:
		PALETTE = loaded

func _ready() -> void:
	_load_palette()
	ROWS         = GameState.terrain_rows
	_active_rows = ROWS
	_hp       = PackedFloat32Array(); _hp.resize(COLS * ROWS)
	_max_hp   = PackedFloat32Array(); _max_hp.resize(COLS * ROWS)
	_base_col = PackedColorArray();   _base_col.resize(COLS * ROWS)

	# NON chiamare init_noise() qui: _hp è tutto 0 → immagine trasparente.
	# _start_round() in Main chiama set_active_rows() + reinit() prima del
	# primo frame visibile.

	_img = Image.create(COLS * CELL, ROWS * CELL, false, Image.FORMAT_RGBA8)
	_redraw_all()

	_tex             = ImageTexture.create_from_image(_img)
	_sprite          = Sprite2D.new()
	_sprite.centered = false
	_sprite.position = Vector2(GRID_X, float(TERRAIN_Y))
	_sprite.z_index  = 1
	_sprite.texture  = _tex
	_sprite.region_enabled = true
	_sprite.region_rect    = Rect2(0, 0, float(COLS * CELL), float(ROWS * CELL))
	add_child(_sprite)

	_overlay         = OverlayNode.new()
	_overlay.area    = self
	_overlay.z_index = 5
	add_child(_overlay)

	_label = Label.new()
	_label.position = Vector2(GRID_X + 8.0, float(TERRAIN_Y) + 4.0)
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.55, 0.92))
	_label.z_index = 10
	add_child(_label)
	_refresh_label()

	_setup_physics()

# ── Fisica ────────────────────────────────────────────────────────────────────
# Ogni riga del terrain ha uno StaticBody2D con rettangoli per le
# "strisce" di celle ancora vive. Quando una cella viene distrutta
# la riga viene ricalcolata a fine frame (_dirty_rows).

func _setup_physics() -> void:
	# Pareti dei pannelli laterali (indistruttibili)
	for x_center in [LAUNCHER_W / 2.0, AREA_W - LAUNCHER_W / 2.0]:
		var wall := StaticBody2D.new()
		wall.position = Vector2.ZERO
		var cs   := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size    = Vector2(LAUNCHER_W, AREA_H)
		cs.position  = Vector2(x_center, AREA_H / 2.0)
		cs.shape     = rect
		wall.add_child(cs)
		add_child(wall)

	# Un StaticBody2D per riga di terrain
	for row in ROWS:
		var body := StaticBody2D.new()
		body.position = Vector2.ZERO
		add_child(body)
		_physics_rows.append(body)

	_rebuild_all_rows()

func _rebuild_all_rows() -> void:
	for row in ROWS:
		_rebuild_row(row)

func _rebuild_row(row: int) -> void:
	var body: StaticBody2D = _physics_rows[row]
	for child in body.get_children():
		child.free()

	var col := 0
	while col < COLS:
		if _hp[row * COLS + col] <= 0.0:
			col += 1
			continue
		# Inizio di una striscia di celle vive
		var start_col := col
		while col < COLS and _hp[row * COLS + col] > 0.0:
			col += 1
		var end_col := col

		var span_w   := float(end_col - start_col) * CELL
		var center_x := GRID_X + float(start_col + end_col) * 0.5 * CELL
		var center_y := float(TERRAIN_Y) + float(row) * CELL + CELL * 0.5

		var cs   := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size   = Vector2(span_w, CELL)
		cs.position = Vector2(center_x, center_y)
		cs.shape    = rect
		body.add_child(cs)

# ── Modalità colore ───────────────────────────────────────────────────────────

func set_active_rows(n: int) -> void:
	_active_rows = clampi(n, 1, ROWS)
	_update_region()

func disable_all_physics() -> void:
	for body in _physics_rows:
		for child in (body as StaticBody2D).get_children():
			child.free()

func _update_region() -> void:
	if _sprite:
		_sprite.region_rect = Rect2(0, 0, float(COLS * CELL), float(_active_rows * CELL))

func init_noise(seed_val: int = -1) -> void:
	if seed_val < 0:
		seed_val = randi()

	# Azzera tutto prima — solo le righe attive verranno riempite
	for i in _hp.size():
		_hp[i]     = 0.0
		_max_hp[i] = 0.0

	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency  = 0.035
	noise.seed       = seed_val
	var hp_m := GameState.terrain_hp_mult()

	for row in _active_rows:          # itera solo 0 .. _active_rows-1
		for col: int in COLS:
			var idx := row * COLS + col
			var n:     float = (noise.get_noise_2d(col, row) + 1.0) / 2.0
			var depth: float = float(row) / ROWS
			var t:     float = clampf(n * 0.45 + depth * 0.65, 0.0, 1.0)
			_set_mat(col, row, int(t * PALETTE.size()))
			_hp[idx]     = _max_hp[idx] * hp_m
			_max_hp[idx] = _hp[idx]

	if _img:
		_redraw_all(); _tex.update(_img); _rebuild_all_rows()
		_update_region()

func init_random() -> void:
	for row: int in ROWS:
		for col: int in COLS:
			_set_mat(col, row, randi() % PALETTE.size())
	if _img:
		_redraw_all(); _tex.update(_img); _rebuild_all_rows()

func init_from_image(path: String) -> bool:
	var src: Image = Image.load_from_file(path)
	if not src:
		push_warning("DestructibleArea: file non trovato → " + path)
		return false
	src.resize(COLS, ROWS, Image.INTERPOLATE_NEAREST)
	for row: int in ROWS:
		for col: int in COLS:
			var px: Color = src.get_pixel(col, row)
			var idx := row * COLS + col
			_base_col[idx] = px
			var hp: float  = lerpf(230.0, 10.0, px.get_luminance())
			_max_hp[idx]   = hp
			_hp[idx]       = hp
	if _img:
		_redraw_all(); _tex.update(_img); _rebuild_all_rows()
	return true

func set_cell(col: int, row: int, palette_idx: int) -> void:
	if _in_bounds(col, row):
		_set_mat(col, row, palette_idx)

func flush_manual() -> void:
	_redraw_all(); _tex.update(_img); _rebuild_all_rows()

func reinit() -> void:
	_worms.clear()
	_projectiles.clear()
	_acid_cells.clear()
	_vfx.clear()
	_placed_weapons.clear()
	init_noise()
	queue_redraw()

func _set_mat(col: int, row: int, pal: int) -> void:
	pal = clampi(pal, 0, PALETTE.size() - 1)
	var idx := row * COLS + col
	_base_col[idx] = PALETTE[pal][0]
	_max_hp[idx]   = PALETTE[pal][1]
	_hp[idx]       = PALETTE[pal][1]

# ── Rendering terrain ─────────────────────────────────────────────────────────

func _redraw_all() -> void:
	for row: int in ROWS:
		for col: int in COLS:
			_draw_cell(col, row)

func _draw_cell(col: int, row: int) -> void:
	var idx  := row * COLS + col
	var hp: float = _hp[idx]
	var rect := Rect2i(col * CELL, row * CELL, CELL, CELL)
	if hp <= 0.0:
		_img.fill_rect(rect, Color(0, 0, 0, 0))
		return
	var ratio: float = hp / _max_hp[idx]
	var c := _base_col[idx].darkened(1.0 - ratio * 0.78)
	_img.fill_rect(rect, c)
	_img.fill_rect(Rect2i(col * CELL, row * CELL, CELL, 1), c.darkened(0.38))
	_img.fill_rect(Rect2i(col * CELL, row * CELL, 1, CELL), c.darkened(0.38))

# ── _draw: pannelli laterali (z sotto la texture) ────────────────────────────

func _draw() -> void:
	_draw_launcher_panel(LEFT_LAUNCHER,  Rect2(0,              0, LAUNCHER_W, AREA_H), true)
	_draw_launcher_panel(RIGHT_LAUNCHER, Rect2(AREA_W - LAUNCHER_W, 0, LAUNCHER_W, AREA_H), false)
	if shots_available > 0:
		var font: Font = ThemeDB.fallback_font
		var txt: String = "×%d" % shots_available
		var cy: float   = float(AREA_H) * 0.5 + 16.0
		draw_string(font, Vector2(0.0,                       cy), txt,
		            HORIZONTAL_ALIGNMENT_CENTER, float(LAUNCHER_W),   28, Color(1.0, 0.88, 0.2))
		draw_string(font, Vector2(float(AREA_W - LAUNCHER_W), cy), txt,
		            HORIZONTAL_ALIGNMENT_CENTER, float(LAUNCHER_W),   28, Color(1.0, 0.88, 0.2))
	for pw in _placed_weapons:
		var cx: float  = float(LAUNCHER_W) * 0.5 if not pw.from_right \
		                 else float(AREA_W) - float(LAUNCHER_W) * 0.5
		var cy: float  = float(pw.panel_y)
		var col: Color = WEAPONS[pw.weapon].color
		draw_circle(Vector2(cx, cy), 16.0, col.darkened(0.5))
		draw_circle(Vector2(cx, cy), 11.0, col)
		draw_circle(Vector2(cx, cy), 5.0,  col.lightened(0.6))

func _draw_launcher_panel(center: Vector2, rect: Rect2, faces_right: bool) -> void:
	draw_rect(rect, Color(0.13, 0.13, 0.16))
	for corner in [rect.position + Vector2(10, 10),
				   rect.position + Vector2(rect.size.x - 10, 10),
				   rect.position + Vector2(10, rect.size.y - 10),
				   rect.position + Vector2(rect.size.x - 10, rect.size.y - 10)]:
		draw_circle(corner, 5.0, Color(0.25, 0.25, 0.28))
		draw_circle(corner, 3.0, Color(0.35, 0.35, 0.38))
	var barrel_w := 32.0
	var barrel_h := 14.0
	var bx := center.x + (6.0 if faces_right else -barrel_w - 6.0)
	draw_rect(Rect2(bx, center.y - barrel_h * 0.5, barrel_w, barrel_h), Color(0.30, 0.30, 0.35))
	draw_rect(Rect2(bx, center.y - barrel_h * 0.5, barrel_w, 2), Color(0.40, 0.40, 0.45))
	draw_circle(center, 24.0, Color(0.18, 0.18, 0.21))
	draw_circle(center, 20.0, Color(0.26, 0.26, 0.30))
	draw_circle(center, 12.0, Color(0.38, 0.38, 0.43))
	draw_circle(center, 7.0,  WEAPONS[current_weapon].color)
	draw_circle(center, 3.5,  WEAPONS[current_weapon].color.lightened(0.5))


# ── Process ───────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if shots_available != _shots_last:
		_shots_last = shots_available
		queue_redraw()
		_refresh_label()

	var terrain_dirty := false
	var need_overlay  := false

	for proj in _projectiles:
		proj.t = minf(proj.t + proj.speed * delta, 1.0)
		if proj.t >= 1.0 and not proj.get("done", false):
			proj["done"] = true
			_on_impact(proj)
			terrain_dirty = true
		need_overlay = true
	_projectiles = _projectiles.filter(func(p): return not p.get("done", false))

	for pw in _placed_weapons:
		pw.timer -= delta
		if pw.timer <= 0.0:
			pw.timer += float(WEAPONS[pw.weapon].rate)
			_launch_from_panel(float(pw.panel_y), bool(pw.from_right), pw.weapon)
		need_overlay = true

	for worm in _worms:
		if worm.steps <= 0:
			continue
		worm.timer += delta
		while worm.timer >= 1.0 / 15.0 and worm.steps > 0:
			worm.timer -= 1.0 / 15.0
			_worm_step(worm)
			terrain_dirty = true
		need_overlay = true
	_worms = _worms.filter(func(w): return w.steps > 0)

	if not _acid_cells.is_empty():
		var to_spread: Dictionary = {}
		var to_remove: Array      = []
		for idx in _acid_cells.keys():
			var str: float = _acid_cells[idx]
			if _hp[idx] > 0.0:
				_dmg_idx(idx, str * delta * 22.0)
				terrain_dirty = true
			if randf() < 0.018 * str:
				for n in _neighbors(idx % COLS, idx / COLS):
					if _hp[n] > 0.0 and not _acid_cells.has(n):
						to_spread[n] = str * 0.52
			_acid_cells[idx] -= delta * 0.38
			if _acid_cells[idx] <= 0.0:
				to_remove.append(idx)
		for idx in to_remove:
			_acid_cells.erase(idx)
		for idx in to_spread:
			_acid_cells[idx] = to_spread[idx]
		need_overlay = true

	if not _vfx.is_empty():
		for fx in _vfx:
			fx.t += delta
			fx.r  = lerpf(0.0, fx.max_r, fx.t / fx.dur)
		_vfx = _vfx.filter(func(fx): return fx.t < fx.dur)
		need_overlay = true

	# Rigenera le righe di fisica che hanno avuto celle distrutte questo frame
	if not _dirty_rows.is_empty():
		for row in _dirty_rows:
			_rebuild_row(row)
		_dirty_rows.clear()

	if terrain_dirty:
		_tex.update(_img)
	if need_overlay or not _worms.is_empty():
		_overlay.queue_redraw()

# ── Input ─────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		for w in WEAPONS:
			if event.keycode == WEAPONS[w].key:
				current_weapon = w
				_refresh_label()
				queue_redraw()
				return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var local: Vector2 = (event as InputEventMouse).position - position
		var in_left_panel  := local.y >= 0.0 and local.y < float(AREA_H) \
		                      and local.x >= 0.0 and local.x < float(LAUNCHER_W)
		var in_right_panel := local.y >= 0.0 and local.y < float(AREA_H) \
		                      and local.x >= float(AREA_W - LAUNCHER_W) and local.x < float(AREA_W)
		if in_left_panel or in_right_panel:
			if shots_available <= 0:
				return
			shots_available -= 1
			weapon_fired.emit()
			_placed_weapons.append({
				"panel_y":    local.y,
				"from_right": in_right_panel,
				"weapon":     current_weapon,
				"timer":      0.0,
			})
			queue_redraw()

func stop_firing() -> void:
	_placed_weapons.clear()
	shots_available = 0
	queue_redraw()

# ── Lancio ────────────────────────────────────────────────────────────────────

func _pick_launcher(target: Vector2) -> Vector2:
	var positions := GameState.launcher_positions()
	# launcher_positions() uses y values that are local to this node (0-240 range)
	var pool: Array = positions.right if target.x < AREA_W * 0.5 else positions.left
	if pool.size() > 0:
		return pool[randi() % pool.size()]
	return RIGHT_LAUNCHER if target.x < AREA_W * 0.5 else LEFT_LAUNCHER

func _launch(target: Vector2, weapon: Weapon) -> void:
	var launcher := _pick_launcher(target)
	var spd: float = float(WEAPONS[weapon].speed) * GameState.projectile_speed_mult()
	_projectiles.append({
		"start":  launcher,
		"target": target,
		"arc_h":  launcher.distance_to(target) * 0.40,
		"t":      0.0,
		"speed":  spd,
		"weapon": weapon,
	})

func _launch_from_panel(panel_y: float, from_right: bool, weapon: Weapon) -> void:
	var launcher: Vector2
	if from_right:
		launcher = Vector2(float(AREA_W) - float(LAUNCHER_W) * 0.5, panel_y)
	else:
		launcher = Vector2(float(LAUNCHER_W) * 0.5, panel_y)
	var tx: float  = randf_range(float(GRID_X) + float(CELL) * 3,
	                             float(AREA_W - LAUNCHER_W) - float(CELL) * 3)
	var ty: float  = randf_range(float(TERRAIN_Y), float(TERRAIN_Y) + float(_active_rows * CELL))
	var spd: float = float(WEAPONS[weapon].speed) * GameState.projectile_speed_mult()
	_projectiles.append({
		"start":  launcher,
		"target": Vector2(tx, ty),
		"arc_h":  float(WEAPONS[weapon].arc_h),
		"t":      0.0,
		"speed":  spd,
		"weapon": weapon,
	})

func _proj_pos(proj: Dictionary) -> Vector2:
	return _proj_pos_at(proj, proj.t)

func _proj_pos_at(proj: Dictionary, t: float) -> Vector2:
	return Vector2(
		lerpf(proj.start.x, proj.target.x, t),
		lerpf(proj.start.y, proj.target.y, t) - proj.arc_h * sin(PI * t)
	)

# ── Impatto ───────────────────────────────────────────────────────────────────

func _on_impact(proj: Dictionary) -> void:
	var pos: Vector2 = proj.target
	var dmg_m  := GameState.weapon_damage_mult()
	var crit   := randf() < GameState.critical_chance()
	var crit_m := 3.0 if crit else 1.0
	match proj.weapon:
		Weapon.BULLET:
			var cell := _local_to_cell(pos)
			if _in_bounds(cell.x, cell.y):
				_dmg_idx(cell.y * COLS + cell.x, 9999.0)
				_add_vfx(pos, 20.0, Color(1.0, 0.95, 0.35), 0.22)
		Weapon.BOMB:
			_circle_dmg(pos, 42.0, 180.0 * dmg_m * crit_m)
			_add_vfx(pos, 42.0, Color(1.0, 0.5, 0.1), 0.45)
		Weapon.MISSILE:
			_circle_dmg(pos, 85.0, 260.0 * dmg_m * crit_m)
			_add_vfx(pos, 85.0, Color(1.0, 0.8, 0.3), 0.55)
		Weapon.FLAMETHROWER:
			_circle_dmg(pos, 20.0, 40.0 * dmg_m * crit_m)
		Weapon.ACID:
			_apply_acid(pos, 14.0)
		Weapon.WORM:
			_spawn_worm(pos)

func _add_vfx(pos: Vector2, max_r: float, color: Color, dur: float) -> void:
	_vfx.append({"pos": pos, "r": 0.0, "max_r": max_r, "dur": dur, "t": 0.0, "color": color})

# ── Azioni armi ───────────────────────────────────────────────────────────────

func _apply_acid(pos: Vector2, radius: float) -> void:
	var cr := int(ceil(radius / CELL))
	var cc := _local_to_cell(pos).x; var rc := _local_to_cell(pos).y
	for dy in range(-cr, cr + 1):
		for dx in range(-cr, cr + 1):
			var c := cc + dx; var r := rc + dy
			if not _in_bounds(c, r):
				continue
			if _cell_to_local(c, r).distance_to(pos) <= radius:
				var idx := r * COLS + c
				_acid_cells[idx] = maxf(_acid_cells.get(idx, 0.0), 2.8)

func _spawn_worm(pos: Vector2) -> void:
	var cell := _local_to_cell(pos)
	if _in_bounds(cell.x, cell.y):
		_worms.append({"col": cell.x, "row": cell.y,
			"steps": GameState.worm_steps(),
			"radius": GameState.worm_eat_radius(),
			"timer": 0.0})

func _worm_step(worm: Dictionary) -> void:
	var dirs := [[1,0],[-1,0],[0,1],[0,-1],[1,1],[1,-1],[-1,1],[-1,-1]]
	dirs.shuffle()
	var best_c := -1; var best_r := -1; var found_solid := false
	for d in dirs:
		var nc: int = int(worm.col) + int(d[0]); var nr: int = int(worm.row) + int(d[1])
		if not _in_bounds(nc, nr):
			continue
		if _hp[nr * COLS + nc] > 0.0:
			best_c = nc; best_r = nr; found_solid = true; break
		elif best_c < 0:
			best_c = nc; best_r = nr
	if best_c < 0:
		worm.steps = 0; return
	worm.col = best_c; worm.row = best_r; worm.steps -= 1
	var wr: float = worm.get("radius", 1.6)
	_circle_dmg(_cell_to_local(worm.col, worm.row), CELL * wr, 9999.0)

# ── Danno ─────────────────────────────────────────────────────────────────────

func _circle_dmg(center: Vector2, radius: float, damage: float) -> void:
	var cr := int(ceil(radius / CELL))
	var cc := _local_to_cell(center).x; var rc := _local_to_cell(center).y
	for dy in range(-cr, cr + 1):
		for dx in range(-cr, cr + 1):
			var c := cc + dx; var r := rc + dy
			if not _in_bounds(c, r):
				continue
			var dist := _cell_to_local(c, r).distance_to(center)
			if dist <= radius:
				_dmg_idx(r * COLS + c, damage * (0.25 + 0.75 * (1.0 - dist / radius)))

func _dmg_idx(idx: int, amount: float) -> void:
	if _hp[idx] <= 0.0:
		return
	_hp[idx] = maxf(0.0, _hp[idx] - amount)
	_draw_cell(idx % COLS, idx / COLS)
	if _hp[idx] <= 0.0:
		# Cella appena distrutta: rigenera la fisica di quella riga a fine frame
		_dirty_rows[idx / COLS] = true

# ── Coordinate ────────────────────────────────────────────────────────────────

func _local_to_cell(local: Vector2) -> Vector2i:
	return Vector2i(int((local.x - GRID_X) / CELL), int((local.y - float(TERRAIN_Y)) / CELL))

func _cell_to_local(col: int, row: int) -> Vector2:
	return Vector2(GRID_X + col * CELL + CELL * 0.5, float(TERRAIN_Y) + row * CELL + CELL * 0.5)

func _in_bounds(col: int, row: int) -> bool:
	return col >= 0 and col < COLS and row >= 0 and row < ROWS

func _neighbors(col: int, row: int) -> Array:
	var res: Array = []
	for d in [[1,0],[-1,0],[0,1],[0,-1]]:
		var nc: int = col + int(d[0]); var nr: int = row + int(d[1])
		if _in_bounds(nc, nr):
			res.append(nr * COLS + nc)
	return res

# ── UI ────────────────────────────────────────────────────────────────────────

func _refresh_label() -> void:
	var w: Dictionary = WEAPONS[current_weapon]
	var shots_txt: String
	if shots_available > 0:
		shots_txt = "   |   ◉ %d disponibili" % shots_available
	elif _placed_weapons.size() > 0:
		shots_txt = "   |   ✦ %d attive" % _placed_weapons.size()
	else:
		shots_txt = ""
	_label.text = (
		"[1]Proiettile [2]Bomba [3]Missile [4]Fiamma [5]Acido [6]Verme"
		+ "     ▶ %s — %s%s" % [w.name, w.desc, shots_txt]
	)
