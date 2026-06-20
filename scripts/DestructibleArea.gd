class_name DestructibleArea
extends Node2D

# ── Layout ────────────────────────────────────────────────────────────────────

const CELL: int  = 8          # pixel per cella
const COLS: int  = 1280 / CELL  # 160
const ROWS: int  = 240  / CELL  # 30
const AREA_W: int = COLS * CELL
const AREA_H: int = ROWS * CELL

# ── Palette: [Color, hp_max, nome] ───────────────────────────────────────────
# Colori chiari = fragili, colori scuri = resistenti.

const PALETTE: Array = [
	[Color(0.95, 0.95, 0.92),  10.0,   "Gesso"],
	[Color(0.85, 0.26, 0.26),  30.0,   "Mattone"],
	[Color(0.88, 0.58, 0.14),  55.0,   "Arenaria"],
	[Color(0.28, 0.72, 0.22),  90.0,   "Roccia"],
	[Color(0.18, 0.44, 0.88), 140.0,   "Granito"],
	[Color(0.52, 0.14, 0.82), 230.0,   "Marmo"],
	[Color(0.11, 0.11, 0.13), 9999.0,  "Acciaio"],
]

# ── Armi ─────────────────────────────────────────────────────────────────────

enum Weapon { BULLET, BOMB, MISSILE, FLAMETHROWER, ACID }

const WEAPONS: Dictionary = {
	Weapon.BULLET:       {key = KEY_1, name = "Proiettile",    r =  0.0, dmg = 9999.0, desc = "distrugge 1 cella"},
	Weapon.BOMB:         {key = KEY_2, name = "Bomba",         r = 42.0, dmg =  180.0, desc = "esplosione circolare"},
	Weapon.MISSILE:      {key = KEY_3, name = "Missile",       r = 85.0, dmg =  260.0, desc = "esplosione grande"},
	Weapon.FLAMETHROWER: {key = KEY_4, name = "Lanciafiamme",  r = 24.0, dmg =    7.0, desc = "tieni premuto"},
	Weapon.ACID:         {key = KEY_5, name = "Acido",         r = 14.0, dmg =    0.0, desc = "corrosivo + si espande"},
}

# ── Stato ─────────────────────────────────────────────────────────────────────

var current_weapon: Weapon = Weapon.BULLET

var _hp:        PackedFloat32Array
var _max_hp:    PackedFloat32Array
var _base_col:  PackedColorArray

var _img: Image
var _tex: ImageTexture
var _sprite: Sprite2D

var _acid_cells: Dictionary = {}   # idx -> forza rimanente (float)
var _flame_on:  bool = false

var _label: Label

# ── Inizializzazione ──────────────────────────────────────────────────────────

func _ready() -> void:
	_hp      = PackedFloat32Array(); _hp.resize(COLS * ROWS)
	_max_hp  = PackedFloat32Array(); _max_hp.resize(COLS * ROWS)
	_base_col = PackedColorArray();  _base_col.resize(COLS * ROWS)

	init_noise()   # modalità default

	_img = Image.create(AREA_W, AREA_H, false, Image.FORMAT_RGBA8)
	_redraw_all()

	_tex = ImageTexture.create_from_image(_img)
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.texture  = _tex
	add_child(_sprite)

	_label = Label.new()
	_label.position = Vector2(8.0, 4.0)
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.55, 0.92))
	add_child(_label)
	_refresh_label()

# ── Modalità colore ───────────────────────────────────────────────────────────

# RUMORE: distribuzione naturale a strati (default)
func init_noise(seed_val: int = -1) -> void:
	if seed_val < 0:
		seed_val = randi()
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency  = 0.07
	noise.seed       = seed_val

	for row in ROWS:
		for col in COLS:
			var n: float = (noise.get_noise_2d(col, row) + 1.0) / 2.0
			# bias per profondità: più in basso = materiale più duro
			var depth: float = float(row) / ROWS
			var t: float = clampf(n * 0.45 + depth * 0.65, 0.0, 1.0)
			_set_mat(col, row, int(t * PALETTE.size()))

# CASUALE: ogni cella ha un materiale completamente random
func init_random() -> void:
	for row in ROWS:
		for col in COLS:
			_set_mat(col, row, randi() % PALETTE.size())

# IMMAGINE: pixel scuri = resistenti, pixel chiari = fragili
# Supporta qualsiasi immagine (PNG, JPG…); viene ridimensionata a 160×30.
func init_from_image(path: String) -> bool:
	var src := Image.load_from_file(path)
	if not src:
		push_warning("DestructibleArea: file non trovato → " + path)
		return false
	src.resize(COLS, ROWS, Image.INTERPOLATE_NEAREST)
	for row in ROWS:
		for col in COLS:
			var px  := src.get_pixel(col, row)
			var idx := row * COLS + col
			_base_col[idx] = px
			var lum: float  = px.get_luminance()
			var hp: float   = lerpf(230.0, 10.0, lum)   # scuro→duro, chiaro→fragile
			_max_hp[idx]    = hp
			_hp[idx]        = hp
	_redraw_all()
	if _tex:
		_tex.update(_img)
	return true

# MANUALE: assegna materiale palette a singola cella (per tool esterno / editor)
func set_cell(col: int, row: int, palette_idx: int) -> void:
	if _in_bounds(col, row):
		_set_mat(col, row, palette_idx)

func flush_manual() -> void:
	_redraw_all()
	_tex.update(_img)

func _set_mat(col: int, row: int, pal: int) -> void:
	pal = clampi(pal, 0, PALETTE.size() - 1)
	var idx := row * COLS + col
	_base_col[idx] = PALETTE[pal][0]
	_max_hp[idx]   = PALETTE[pal][1]
	_hp[idx]       = PALETTE[pal][1]

# ── Rendering ─────────────────────────────────────────────────────────────────

func _redraw_all() -> void:
	for row in ROWS:
		for col in COLS:
			_draw_cell(col, row)

func _draw_cell(col: int, row: int) -> void:
	var idx  := row * COLS + col
	var hp   := _hp[idx]
	var rect := Rect2i(col * CELL, row * CELL, CELL, CELL)

	if hp <= 0.0:
		_img.fill_rect(rect, Color(0, 0, 0, 0))
		return

	var ratio: float = hp / _max_hp[idx]
	var c := _base_col[idx].darkened(1.0 - ratio * 0.78)

	_img.fill_rect(rect, c)
	# bordo griglia sottile
	_img.fill_rect(Rect2i(col * CELL, row * CELL, CELL, 1), c.darkened(0.38))
	_img.fill_rect(Rect2i(col * CELL, row * CELL, 1, CELL), c.darkened(0.38))

# ── Process ───────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	var dirty := false

	# Lanciafiamme: danno continuo nella posizione del mouse
	if _flame_on:
		var local := get_viewport().get_mouse_position() - position
		_circle_dmg(local, WEAPONS[Weapon.FLAMETHROWER].r,
					WEAPONS[Weapon.FLAMETHROWER].dmg * delta * 60.0)
		dirty = true

	# Acido: corrosione + espansione
	if not _acid_cells.is_empty():
		var to_spread: Dictionary = {}
		var to_remove: Array      = []

		for idx in _acid_cells.keys():
			var strength: float = _acid_cells[idx]

			if _hp[idx] > 0.0:
				_dmg_idx(idx, strength * delta * 22.0)
				dirty = true

			if randf() < 0.018 * strength:
				for n in _neighbors(idx % COLS, idx / COLS):
					if _hp[n] > 0.0 and not _acid_cells.has(n):
						to_spread[n] = strength * 0.52

			_acid_cells[idx] -= delta * 0.38
			if _acid_cells[idx] <= 0.0:
				to_remove.append(idx)

		for idx in to_remove:
			_acid_cells.erase(idx)
		for idx in to_spread:
			_acid_cells[idx] = to_spread[idx]

	if dirty:
		_tex.update(_img)

# ── Input ─────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	# Tasti 1-5: cambio arma
	if event is InputEventKey and event.pressed and not event.echo:
		for w in WEAPONS:
			if event.keycode == WEAPONS[w].key:
				current_weapon = w
				_refresh_label()
				return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var local := event.position - position
		var in_area := local.x >= 0.0 and local.x < AREA_W \
					and local.y >= 0.0 and local.y < AREA_H

		if event.pressed and in_area:
			match current_weapon:
				Weapon.BULLET:       _fire_bullet(local)
				Weapon.BOMB:         _fire_bomb(local)
				Weapon.MISSILE:      _fire_missile(local)
				Weapon.FLAMETHROWER: _flame_on = true
				Weapon.ACID:         _fire_acid(local)
		else:
			_flame_on = false

	if event is InputEventMouseMotion and _flame_on:
		var local := event.position - position
		if local.y < 0.0 or local.y >= AREA_H:
			_flame_on = false

# ── Armi ─────────────────────────────────────────────────────────────────────

func _fire_bullet(pos: Vector2) -> void:
	var col := int(pos.x / CELL)
	var row := int(pos.y / CELL)
	if _in_bounds(col, row):
		_dmg_idx(row * COLS + col, 9999.0)
	_tex.update(_img)

func _fire_bomb(pos: Vector2) -> void:
	_circle_dmg(pos, WEAPONS[Weapon.BOMB].r, WEAPONS[Weapon.BOMB].dmg)
	_tex.update(_img)

func _fire_missile(pos: Vector2) -> void:
	_circle_dmg(pos, WEAPONS[Weapon.MISSILE].r, WEAPONS[Weapon.MISSILE].dmg)
	_tex.update(_img)

func _fire_acid(pos: Vector2) -> void:
	var acid_r := WEAPONS[Weapon.ACID].r
	var cr := int(ceil(acid_r / CELL))
	var cc := int(pos.x / CELL)
	var rc := int(pos.y / CELL)
	for dy in range(-cr, cr + 1):
		for dx in range(-cr, cr + 1):
			var c := cc + dx
			var r := rc + dy
			if not _in_bounds(c, r):
				continue
			var cx := float(c * CELL + CELL / 2)
			var cy := float(r * CELL + CELL / 2)
			if Vector2(cx, cy).distance_to(pos) <= acid_r:
				var idx := r * COLS + c
				_acid_cells[idx] = maxf(_acid_cells.get(idx, 0.0), 2.8)

# ── Utilità danno ─────────────────────────────────────────────────────────────

func _circle_dmg(center: Vector2, radius: float, damage: float) -> void:
	var cr := int(ceil(radius / CELL))
	var cc := int(center.x / CELL)
	var rc := int(center.y / CELL)
	for dy in range(-cr, cr + 1):
		for dx in range(-cr, cr + 1):
			var col := cc + dx
			var row := rc + dy
			if not _in_bounds(col, row):
				continue
			var cx := float(col * CELL + CELL / 2)
			var cy := float(row * CELL + CELL / 2)
			var dist := Vector2(cx, cy).distance_to(center)
			if dist <= radius:
				var falloff := 1.0 - (dist / radius)
				_dmg_idx(row * COLS + col, damage * (0.25 + 0.75 * falloff))

func _dmg_idx(idx: int, amount: float) -> void:
	if _hp[idx] <= 0.0:
		return
	_hp[idx] = maxf(0.0, _hp[idx] - amount)
	_draw_cell(idx % COLS, idx / COLS)

func _neighbors(col: int, row: int) -> Array:
	var res: Array = []
	for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
		var nc := col + d[0]
		var nr := row + d[1]
		if _in_bounds(nc, nr):
			res.append(nr * COLS + nc)
	return res

func _in_bounds(col: int, row: int) -> bool:
	return col >= 0 and col < COLS and row >= 0 and row < ROWS

# ── UI ────────────────────────────────────────────────────────────────────────

func _refresh_label() -> void:
	var w := WEAPONS[current_weapon]
	_label.text = (
		"[1] Proiettile  [2] Bomba  [3] Missile  [4] Lanciafiamme  [5] Acido"
		+ "     ▶  %s — %s" % [w.name, w.desc]
	)
