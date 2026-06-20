class_name BucketSection
extends Node2D

# ── Dimensioni fisse ──────────────────────────────────────────────────────────

const AREA_W: int   = 1280
const AREA_H: int   = 240
const SLOT_Y: float = 155.0
const PEG_R:  float = 6.0

# ── Palette colori slot per moltiplicatore ────────────────────────────────────

const MULT_COLORS: Dictionary = {
	1:  Color(0.45, 0.45, 0.45),
	2:  Color(0.20, 0.55, 0.20),
	3:  Color(0.20, 0.38, 0.82),
	5:  Color(0.80, 0.48, 0.10),
	10: Color(0.82, 0.12, 0.12),
}

# ── Stato ─────────────────────────────────────────────────────────────────────

var _num_slots:     int   = 10
var _slot_w:        float = 128.0
var _multipliers:   Array = []
var _slot_colors:   Array = []

var _peg_positions: Array = []
var _float_texts:   Array = []
var _money_label:   Label
var _dyn:           Node2D   # container per pegs + slots (ricreabile)

# ── Init ──────────────────────────────────────────────────────────────────────

func _ready() -> void:
	_setup_background()
	_setup_floor()
	_setup_ui()
	_build_dynamic()
	queue_redraw()
	GameState.upgrade_bought.connect(_on_upgrade_bought)

func _setup_background() -> void:
	var bg := ColorRect.new()
	bg.position = Vector2.ZERO
	bg.size     = Vector2(AREA_W, AREA_H)
	bg.color    = Color(0.07, 0.05, 0.10)
	bg.z_index  = -5
	add_child(bg)

func _setup_floor() -> void:
	var body := StaticBody2D.new()
	body.position = Vector2(AREA_W / 2.0, AREA_H + 12.0)
	var cs   := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(AREA_W + 40.0, 24.0)
	cs.shape  = rect
	body.add_child(cs)
	add_child(body)

func _setup_ui() -> void:
	_money_label = Label.new()
	_money_label.text     = "$ 0"
	_money_label.position = Vector2(8.0, 6.0)
	_money_label.add_theme_font_size_override("font_size", 22)
	_money_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.22))
	_money_label.z_index = 20
	add_child(_money_label)

# ── Costruzione dinamica (pegs + slot) ───────────────────────────────────────

func _build_dynamic() -> void:
	_num_slots   = GameState.slot_count()
	_slot_w      = float(AREA_W) / float(_num_slots)
	_multipliers = _compute_multipliers(_num_slots)
	_slot_colors = []
	for m in _multipliers:
		var closest := _nearest_mult_key(m)
		_slot_colors.append(MULT_COLORS.get(closest, Color(0.45, 0.45, 0.45)))

	_peg_positions = []

	if _dyn:
		_dyn.queue_free()
	_dyn = Node2D.new()
	add_child(_dyn)

	_build_pegs()
	_build_slots()

func _compute_multipliers(n: int) -> Array:
	const BASE: Array = [1, 2, 3, 5, 10, 10, 5, 3, 2, 1]
	if n <= 10:
		return BASE
	var result: Array = BASE.duplicate()
	var extra  := n - 10
	var left_n := extra / 2
	var right_n := extra - left_n
	for _i in left_n:
		result.push_front(1)
	for _i in right_n:
		result.push_back(1)
	return result

func _nearest_mult_key(val: int) -> int:
	var keys  := MULT_COLORS.keys()
	var best  := keys[0]
	var bdiff := abs(val - best)
	for k in keys:
		var d := abs(val - k)
		if d < bdiff:
			best = k; bdiff = d
	return best

# ── Pegs ──────────────────────────────────────────────────────────────────────

func _build_pegs() -> void:
	const PEG_ROWS:    int   = 4
	const ROW_SPACING: float = 35.0
	const FIRST_ROW_Y: float = 28.0

	for row_i in PEG_ROWS:
		var y := FIRST_ROW_Y + row_i * ROW_SPACING
		var offset_x := (_slot_w / 2.0) if (row_i % 2 == 1) else 0.0
		var num_pegs := (_num_slots - 1) if (row_i % 2 == 1) else _num_slots

		for peg_i in num_pegs:
			var x := _slot_w / 2.0 + offset_x + peg_i * _slot_w
			_make_peg(Vector2(x, y))

func _make_peg(pos: Vector2) -> void:
	_peg_positions.append(pos)
	var body   := StaticBody2D.new()
	body.position = pos
	var cs     := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = PEG_R
	cs.shape = circle
	body.add_child(cs)
	_dyn.add_child(body)

# ── Slot ──────────────────────────────────────────────────────────────────────

func _build_slots() -> void:
	for i in _num_slots:
		var slot_x := i * _slot_w

		var bg_rect := ColorRect.new()
		bg_rect.position = Vector2(slot_x, SLOT_Y)
		bg_rect.size     = Vector2(_slot_w, AREA_H - SLOT_Y)
		bg_rect.color    = _slot_colors[i].darkened(0.55)
		bg_rect.z_index  = -4
		_dyn.add_child(bg_rect)

		var lbl := Label.new()
		lbl.text       = "%dx" % _multipliers[i]
		lbl.position   = Vector2(slot_x, AREA_H - 38.0)
		lbl.size       = Vector2(_slot_w, 36.0)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", clamp(int(_slot_w * 0.18), 13, 24))
		lbl.add_theme_color_override("font_color", _slot_colors[i].lightened(0.45))
		_dyn.add_child(lbl)

		if i > 0:
			_make_divider(Vector2(slot_x, SLOT_Y + (AREA_H - SLOT_Y) / 2.0),
						  Vector2(5.0, AREA_H - SLOT_Y))

		var area := Area2D.new()
		area.position = Vector2.ZERO
		var cs   := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size   = Vector2(_slot_w - 6.0, 28.0)
		cs.position = Vector2(slot_x + _slot_w * 0.5, AREA_H - 14.0)
		cs.shape    = rect
		area.add_child(cs)
		area.body_entered.connect(_on_ball_in_slot.bind(i))
		_dyn.add_child(area)

	_make_divider(Vector2(2.5, SLOT_Y + (AREA_H - SLOT_Y) / 2.0),
				  Vector2(5.0, AREA_H - SLOT_Y))
	_make_divider(Vector2(AREA_W - 2.5, SLOT_Y + (AREA_H - SLOT_Y) / 2.0),
				  Vector2(5.0, AREA_H - SLOT_Y))

func _make_divider(pos: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = pos
	var cs   := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	cs.shape  = rect
	body.add_child(cs)
	_dyn.add_child(body)

# ── Raccolta pallina ──────────────────────────────────────────────────────────

func _on_ball_in_slot(body: Node2D, slot_idx: int) -> void:
	if not body is Ball:
		return
	var ball := body as Ball
	if ball.collected:
		return
	ball.collected = true

	var base_mult := _multipliers[slot_idx] if slot_idx < _multipliers.size() else 1
	var boost     := GameState.multiplier_boost()
	var earned    := int(float(ball.money_value * base_mult) * boost)
	GameState.add_money(earned)
	_money_label.text = "$ %d" % GameState.money

	var slot_cx := slot_idx * _slot_w + _slot_w * 0.5
	var col     := _slot_colors[slot_idx] if slot_idx < _slot_colors.size() else Color.WHITE
	_spawn_float_text("+%d" % earned, Vector2(slot_cx, SLOT_Y - 10.0), col.lightened(0.4))

	ball.call_deferred("queue_free")

# ── Refresh (called on upgrade) ───────────────────────────────────────────────

func refresh() -> void:
	_build_dynamic()
	_money_label.text = "$ %d" % GameState.money
	queue_redraw()

func _on_upgrade_bought(id: String) -> void:
	if id == "slots" or id == "multiplier":
		refresh()

# ── Testo fluttuante ─────────────────────────────────────────────────────────

func _spawn_float_text(text: String, pos: Vector2, color: Color) -> void:
	var lbl := Label.new()
	lbl.text     = text
	lbl.position = pos
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", color)
	lbl.z_index  = 20
	add_child(lbl)
	_float_texts.append({"label": lbl, "timer": 0.0, "color": color})

func _process(delta: float) -> void:
	var done: Array = []
	for ft in _float_texts:
		ft.timer      += delta
		ft.label.position.y -= 45.0 * delta
		var alpha := maxf(0.0, 1.0 - ft.timer / 1.4)
		ft.label.add_theme_color_override("font_color",
			Color(ft.color.r, ft.color.g, ft.color.b, alpha))
		if ft.timer >= 1.4:
			ft.label.queue_free()
			done.append(ft)
	for ft in done:
		_float_texts.erase(ft)

# ── _draw: pioli e linea separatrice ─────────────────────────────────────────

func _draw() -> void:
	draw_line(Vector2(0.0, SLOT_Y), Vector2(AREA_W, SLOT_Y),
			  Color(0.45, 0.45, 0.55, 0.6), 2.0)

	for pos in _peg_positions:
		draw_circle(pos, PEG_R + 2.5, Color(0.12, 0.12, 0.18))
		draw_circle(pos, PEG_R,       Color(0.58, 0.58, 0.70))
		draw_circle(pos + Vector2(-1.8, -1.8), PEG_R * 0.32, Color(0.88, 0.88, 1.0, 0.65))

	for i in range(1, _num_slots):
		var x := i * _slot_w
		draw_line(Vector2(x, SLOT_Y), Vector2(x, AREA_H),
				  Color(0.42, 0.42, 0.48), 4.0)
	draw_line(Vector2(2.0, SLOT_Y),         Vector2(2.0, AREA_H),         Color(0.42, 0.42, 0.48), 4.0)
	draw_line(Vector2(AREA_W - 2.0, SLOT_Y), Vector2(AREA_W - 2.0, AREA_H), Color(0.42, 0.42, 0.48), 4.0)
