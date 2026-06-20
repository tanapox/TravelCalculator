class_name BucketSection
extends Node2D

# ── Dimensioni ────────────────────────────────────────────────────────────────

const AREA_W:    int   = 1280
const AREA_H:    int   = 240   # altezza sezione (y 480-720 in world space)
const NUM_SLOTS: int   = 10
const SLOT_W:    float = float(AREA_W) / NUM_SLOTS  # 128 px

# y locale da cui inizia la zona slot (divisa da quella dei pegs)
const SLOT_Y:    float = 155.0
const PEG_R:     float = 6.0

# ── Moltiplicatori e colori (simmetrico, centro più alto) ────────────────────

const MULTIPLIERS: Array = [1, 2, 3,  5, 10, 10, 5,  3, 2, 1]
const SLOT_COLORS: Array = [
	Color(0.45, 0.45, 0.45),  # 1x  grigio
	Color(0.20, 0.55, 0.20),  # 2x  verde
	Color(0.20, 0.38, 0.82),  # 3x  blu
	Color(0.80, 0.48, 0.10),  # 5x  arancione
	Color(0.82, 0.12, 0.12),  # 10x rosso
	Color(0.82, 0.12, 0.12),  # 10x rosso
	Color(0.80, 0.48, 0.10),  # 5x  arancione
	Color(0.20, 0.38, 0.82),  # 3x  blu
	Color(0.20, 0.55, 0.20),  # 2x  verde
	Color(0.45, 0.45, 0.45),  # 1x  grigio
]

# ── Stato ─────────────────────────────────────────────────────────────────────

var total_money: int = 0

var _peg_positions: Array = []
var _float_texts:   Array = []   # [{label, vel, timer}]
var _money_label:   Label
var _score_label:   Label

# ── Init ──────────────────────────────────────────────────────────────────────

func _ready() -> void:
	_setup_background()
	_setup_pegs()
	_setup_slots()
	_setup_floor()
	_setup_ui()
	queue_redraw()

func _setup_background() -> void:
	var bg := ColorRect.new()
	bg.position = Vector2.ZERO
	bg.size     = Vector2(AREA_W, AREA_H)
	bg.color    = Color(0.07, 0.05, 0.10)
	bg.z_index  = -5
	add_child(bg)

# ── Pegs Plinko ───────────────────────────────────────────────────────────────
# 4 righe di pioli sfalsati che distribuiscono le palline negli slot.

func _setup_pegs() -> void:
	const PEG_ROWS:    int   = 4
	const ROW_SPACING: float = 35.0
	const FIRST_ROW_Y: float = 28.0

	for row_i in PEG_ROWS:
		var y := FIRST_ROW_Y + row_i * ROW_SPACING
		var offset_x := (SLOT_W / 2.0) if (row_i % 2 == 1) else 0.0
		var num_pegs := (NUM_SLOTS - 1) if (row_i % 2 == 1) else NUM_SLOTS

		for peg_i in num_pegs:
			var x := SLOT_W / 2.0 + offset_x + peg_i * SLOT_W
			_make_peg(Vector2(x, y))

func _make_peg(pos: Vector2) -> void:
	_peg_positions.append(pos)
	var body := StaticBody2D.new()
	body.position = pos
	var cs     := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = PEG_R
	cs.shape = circle
	body.add_child(cs)
	add_child(body)

# ── Slot ──────────────────────────────────────────────────────────────────────

func _setup_slots() -> void:
	for i in NUM_SLOTS:
		var slot_x := i * SLOT_W

		# Sfondo colorato dello slot
		var bg_rect := ColorRect.new()
		bg_rect.position = Vector2(slot_x, SLOT_Y)
		bg_rect.size     = Vector2(SLOT_W, AREA_H - SLOT_Y)
		bg_rect.color    = SLOT_COLORS[i].darkened(0.55)
		bg_rect.z_index  = -4
		add_child(bg_rect)

		# Etichetta moltiplicatore
		var lbl := Label.new()
		lbl.text       = "%dx" % MULTIPLIERS[i]
		lbl.position   = Vector2(slot_x, AREA_H - 38.0)
		lbl.size       = Vector2(SLOT_W, 36.0)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 24)
		lbl.add_theme_color_override("font_color", SLOT_COLORS[i].lightened(0.45))
		add_child(lbl)

		# Etichetta colore pallina → valore (piccola, in alto nello slot)
		# non necessaria ma lascia spazio per futuri upgrade

		# Divisore fisico verticale tra slot (eccetto il bordo sinistro)
		if i > 0:
			_make_divider(Vector2(slot_x, SLOT_Y + (AREA_H - SLOT_Y) / 2.0),
						  Vector2(5.0, AREA_H - SLOT_Y))

		# Area2D raccoglitrice a fondo slot
		var area := Area2D.new()
		area.position = Vector2.ZERO
		var cs   := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size   = Vector2(SLOT_W - 6.0, 28.0)
		cs.position = Vector2(slot_x + SLOT_W * 0.5, AREA_H - 14.0)
		cs.shape    = rect
		area.add_child(cs)
		area.body_entered.connect(_on_ball_in_slot.bind(i))
		add_child(area)

	# Bordi laterali della zona slot
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
	add_child(body)

func _setup_floor() -> void:
	# Pavimento fisico a fondo schermo
	var body := StaticBody2D.new()
	body.position = Vector2(AREA_W / 2.0, AREA_H + 12.0)
	var cs   := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(AREA_W + 40.0, 24.0)
	cs.shape  = rect
	body.add_child(cs)
	add_child(body)

# ── UI ────────────────────────────────────────────────────────────────────────

func _setup_ui() -> void:
	_money_label = Label.new()
	_money_label.text     = "$ 0"
	_money_label.position = Vector2(8.0, 6.0)
	_money_label.add_theme_font_size_override("font_size", 22)
	_money_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.22))
	add_child(_money_label)

# ── Raccolta pallina ──────────────────────────────────────────────────────────

func _on_ball_in_slot(body: Node2D, slot_idx: int) -> void:
	if not body is Ball:
		return
	var ball := body as Ball
	if ball.collected:
		return
	ball.collected = true

	var mult    := MULTIPLIERS[slot_idx]
	var earned  := ball.money_value * mult
	total_money += earned
	_money_label.text = "$ %d" % total_money

	# Testo fluttuante
	var slot_cx := slot_idx * SLOT_W + SLOT_W * 0.5
	_spawn_float_text("+%d" % earned, Vector2(slot_cx, SLOT_Y - 10.0),
					  SLOT_COLORS[slot_idx].lightened(0.4))

	ball.call_deferred("queue_free")

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
	# Linea separatrice tra zona pegs e zona slot
	draw_line(Vector2(0.0, SLOT_Y), Vector2(AREA_W, SLOT_Y),
			  Color(0.45, 0.45, 0.55, 0.6), 2.0)

	# Pioli
	for pos in _peg_positions:
		draw_circle(pos, PEG_R + 2.5, Color(0.12, 0.12, 0.18))
		draw_circle(pos, PEG_R,       Color(0.58, 0.58, 0.70))
		draw_circle(pos + Vector2(-1.8, -1.8), PEG_R * 0.32, Color(0.88, 0.88, 1.0, 0.65))

	# Linee verticali dei divisori (solo visuale, fisica separata)
	for i in range(1, NUM_SLOTS):
		var x := i * SLOT_W
		draw_line(Vector2(x, SLOT_Y), Vector2(x, AREA_H),
				  Color(0.42, 0.42, 0.48), 4.0)
	draw_line(Vector2(2.0, SLOT_Y),        Vector2(2.0, AREA_H),        Color(0.42, 0.42, 0.48), 4.0)
	draw_line(Vector2(AREA_W - 2.0, SLOT_Y), Vector2(AREA_W - 2.0, AREA_H), Color(0.42, 0.42, 0.48), 4.0)
