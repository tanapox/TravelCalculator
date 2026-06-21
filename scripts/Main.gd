extends Node2D

# ── Costanti layout ───────────────────────────────────────────────────────────

const W:     int = 1280
const H:     int = 720
const TOP_H: int = H / 3   # 240 px

const SECTION_COLORS: Array = [
	Color(0.09, 0.06, 0.15),
	Color(0.05, 0.09, 0.06),
	Color(0.10, 0.05, 0.05),
]

const BALL_COLORS: Array = [
	Color(0.95, 0.28, 0.28), Color(0.28, 0.65, 0.95),
	Color(0.28, 0.90, 0.42), Color(0.95, 0.85, 0.18),
	Color(0.95, 0.48, 0.08), Color(0.72, 0.28, 0.95),
	Color(0.18, 0.88, 0.82), Color(0.95, 0.38, 0.72),
]
const BALL_VALUES: Array     = [10, 20, 15, 25, 30, 50, 35, 40]
const BALL_COUNT_MIN: int    = 6
const BALL_COUNT_MAX: int    = 14
const BALL_RADIUS_MIN: float = 4.0
const BALL_RADIUS_MAX: float = 11.0

# ── Fasi del round ────────────────────────────────────────────────────────────

enum Phase { SHOOTING, COLLECTING, BETWEEN_ROUNDS, WAITING }

# ── Stato round ───────────────────────────────────────────────────────────────

var _phase:          Phase = Phase.BETWEEN_ROUNDS
var _round:          int   = 0

var _round_timer:    float = 0.0   # conto alla rovescia totale del round
var _shot_timer:     float = 0.0   # conto alla rovescia fino alla prossima arma
var _shots_to_give:  int   = 0     # armi ancora da sbloccare questo round
var _shots_total:    int   = 0     # armi totali del round corrente
var _collect_timer:  float = 0.0   # timeout raccolta palline

var _flash_text:     String = ""
var _flash_timer:    float  = 0.0
var _flash_color:    Color  = Color.WHITE

# ── Nodi ──────────────────────────────────────────────────────────────────────

var _terrain:     DestructibleArea
var _bucket:      BucketSection
var _shop:        UpgradeShop
var _barrier:     StaticBody2D = null
var _barrier_vis: Line2D       = null
var _balls:       Array        = []

# HUD
var _hud:          CanvasLayer
var _hud_timer:    Label
var _hud_shots:    Label
var _hud_weapon:   Label
var _hud_flash:    Label
var _hud_start:    Control

# ── Init ──────────────────────────────────────────────────────────────────────

func _ready() -> void:
	_setup_background()
	_setup_walls()
	_add_boundary_visuals()
	_add_terrain()
	_add_bucket_section()
	_add_upgrade_shop()
	_build_hud()

	GameState.level_up.connect(_on_level_up)
	_shop.shop_closed.connect(_on_shop_closed)
	_terrain.weapon_fired.connect(_on_weapon_fired)

	call_deferred("_start_round")

# ── Background ────────────────────────────────────────────────────────────────

func _setup_background() -> void:
	for i in 3:
		var rect := ColorRect.new()
		rect.position = Vector2(0.0, i * TOP_H)
		rect.size     = Vector2(W, TOP_H)
		rect.color    = SECTION_COLORS[i]
		rect.z_index  = -10
		add_child(rect)

# ── Pareti ────────────────────────────────────────────────────────────────────

func _setup_walls() -> void:
	const T := 24
	const LW := DestructibleArea.LAUNCHER_W   # 80
	# Soffitto
	_make_wall(Vector2(W / 2.0, -T / 2.0),       Vector2(W + T * 2, T))
	# Pareti esterne (coprono sezioni medie e basse)
	_make_wall(Vector2(-T / 2.0,   TOP_H),        Vector2(T, TOP_H * 2 + T * 2))
	_make_wall(Vector2(W + T / 2.0, TOP_H),       Vector2(T, TOP_H * 2 + T * 2))
	# Pareti interne nella zona palline (x=LW e x=W-LW) — stessa larghezza del terreno
	_make_wall(Vector2(LW - T / 2.0, TOP_H / 2),  Vector2(T, TOP_H + T))
	_make_wall(Vector2(W - LW + T / 2.0, TOP_H / 2), Vector2(T, TOP_H + T))

func _make_wall(pos: Vector2, size: Vector2) -> void:
	var body   := StaticBody2D.new()
	body.position = pos
	var cs     := CollisionShape2D.new()
	var rect   := RectangleShape2D.new()
	rect.size  = size
	cs.shape   = rect
	body.add_child(cs)
	add_child(body)

# ── Linee divisorie ───────────────────────────────────────────────────────────

func _add_boundary_visuals() -> void:
	var glow := Line2D.new()
	glow.add_point(Vector2(0.0, TOP_H)); glow.add_point(Vector2(W, TOP_H))
	glow.width = 14.0; glow.default_color = Color(0.40, 0.75, 1.0, 0.22)
	glow.z_index = 50; add_child(glow)

	var line := Line2D.new()
	line.add_point(Vector2(0.0, TOP_H)); line.add_point(Vector2(W, TOP_H))
	line.width = 3.0; line.default_color = Color(0.65, 0.90, 1.0, 0.95)
	line.z_index = 51; add_child(line)

	var divider := Line2D.new()
	divider.add_point(Vector2(0.0, TOP_H * 2)); divider.add_point(Vector2(W, TOP_H * 2))
	divider.width = 2.0; divider.default_color = Color(0.50, 0.50, 0.55, 0.35)
	divider.z_index = 50; add_child(divider)

# ── Terrain + Bucket + Shop ───────────────────────────────────────────────────

func _add_terrain() -> void:
	_terrain = DestructibleArea.new()
	_terrain.position = Vector2(0.0, float(TOP_H))
	add_child(_terrain)

func _add_bucket_section() -> void:
	_bucket = BucketSection.new()
	_bucket.position = Vector2(0.0, float(TOP_H * 2))
	add_child(_bucket)

func _add_upgrade_shop() -> void:
	_shop = UpgradeShop.new()
	add_child(_shop)

# ── HUD ───────────────────────────────────────────────────────────────────────

func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 5
	add_child(_hud)

	# Striscia opaca in alto
	var strip := ColorRect.new()
	strip.size  = Vector2(W, 34.0)
	strip.color = Color(0.0, 0.0, 0.0, 0.60)
	_hud.add_child(strip)

	# Timer (centrato)
	_hud_timer = Label.new()
	_hud_timer.size     = Vector2(float(W), 30.0)
	_hud_timer.position = Vector2(0.0, 3.0)
	_hud_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_timer.add_theme_font_size_override("font_size", 22)
	_hud_timer.add_theme_color_override("font_color", Color(1.0, 0.88, 0.22))
	_hud.add_child(_hud_timer)

	# Armi disponibili (destra)
	_hud_shots = Label.new()
	_hud_shots.size     = Vector2(420.0, 30.0)
	_hud_shots.position = Vector2(846.0, 3.0)
	_hud_shots.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hud_shots.add_theme_font_size_override("font_size", 18)
	_hud_shots.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	_hud.add_child(_hud_shots)

	# Arma corrente (sinistra)
	_hud_weapon = Label.new()
	_hud_weapon.size     = Vector2(380.0, 30.0)
	_hud_weapon.position = Vector2(14.0, 3.0)
	_hud_weapon.add_theme_font_size_override("font_size", 15)
	_hud_weapon.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	_hud.add_child(_hud_weapon)

	# Flash fase (centro schermo)
	_hud_flash = Label.new()
	_hud_flash.size     = Vector2(float(W), 70.0)
	_hud_flash.position = Vector2(0.0, 310.0)
	_hud_flash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_flash.add_theme_font_size_override("font_size", 52)
	_hud_flash.visible = false
	_hud.add_child(_hud_flash)

	# Pulsante START — Control puro per evitare problemi di tema di Godot
	# Click rilevato manualmente in _input(). SPAZIO funziona come scorciatoia.
	_hud_start = Control.new()
	_hud_start.position = Vector2(490.0, 380.0)
	_hud_start.size     = Vector2(300.0, 72.0)
	_hud_start.visible  = false

	var _start_bg := ColorRect.new()          # sfondo verde
	_start_bg.size  = Vector2(300.0, 72.0)
	_start_bg.color = Color(0.06, 0.52, 0.14)
	_hud_start.add_child(_start_bg)

	var _start_top := ColorRect.new()         # bordo superiore chiaro
	_start_top.size  = Vector2(300.0, 3.0)
	_start_top.color = Color(0.18, 0.90, 0.32)
	_hud_start.add_child(_start_top)

	var _start_lbl := Label.new()             # testo bianco
	_start_lbl.position = Vector2(0.0, 18.0)
	_start_lbl.size     = Vector2(300.0, 40.0)
	_start_lbl.text     = "▶  START  (SPAZIO)"
	_start_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_start_lbl.add_theme_font_size_override("font_size", 26)
	_start_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	_hud_start.add_child(_start_lbl)

	_hud.add_child(_hud_start)

# ── Sbarra ────────────────────────────────────────────────────────────────────

func _create_barrier() -> void:
	_remove_barrier()

	_barrier = StaticBody2D.new()
	_barrier.position = Vector2(W / 2.0, float(TOP_H))
	var cs   := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size   = Vector2(float(W) + 40.0, 12.0)
	cs.shape    = rect
	_barrier.add_child(cs)
	add_child(_barrier)

	# Visuale della sbarra
	_barrier_vis = Line2D.new()
	_barrier_vis.add_point(Vector2(0.0, float(TOP_H)))
	_barrier_vis.add_point(Vector2(float(W), float(TOP_H)))
	_barrier_vis.width         = 6.0
	_barrier_vis.default_color = Color(1.0, 0.75, 0.15, 0.95)
	_barrier_vis.z_index       = 60
	add_child(_barrier_vis)

func _remove_barrier() -> void:
	if _barrier:
		_barrier.queue_free()
		_barrier = null
	if _barrier_vis:
		_barrier_vis.queue_free()
		_barrier_vis = null

# ── Palline ───────────────────────────────────────────────────────────────────

func _clear_balls() -> void:
	for b in _balls:
		if is_instance_valid(b):
			b.queue_free()
	_balls = []

func _spawn_balls() -> void:
	var count := randi_range(BALL_COUNT_MIN, BALL_COUNT_MAX)
	for _i in count:
		var r         := randf_range(BALL_RADIUS_MIN, BALL_RADIUS_MAX)
		var color_idx := randi() % BALL_COLORS.size()
		var ball := Ball.new()
		const LW := DestructibleArea.LAUNCHER_W
		ball.position = Vector2(
			randf_range(LW + r + 4.0, W - LW - r - 4.0),
			randf_range(r + 4.0, TOP_H - r - 8.0)
		)
		add_child(ball)
		ball.setup(r, BALL_COLORS[color_idx], BALL_VALUES[color_idx])
		_balls.append(ball)

func _count_active_balls() -> int:
	var n := 0
	for b in _balls:
		if is_instance_valid(b):
			n += 1
	return n

# ── Gestione round ────────────────────────────────────────────────────────────

func _start_round() -> void:
	_round += 1

	_clear_balls()
	_terrain.set_active_rows(GameState.terrain_rows_at_level(_round))
	_terrain.reinit()
	_spawn_balls()
	_create_barrier()

	_phase = Phase.WAITING
	_update_hud()

func _begin_shooting() -> void:
	if _phase != Phase.WAITING:
		return
	var interval  := GameState.shot_interval()
	var duration  := float(GameState.round_duration_at_level(GameState.level))
	var shots     := maxi(1, int(duration / interval))
	_round_timer   = duration
	_shot_timer    = interval
	_shots_to_give = shots - 1
	_shots_total   = shots
	_terrain.shots_available = 1

	_phase = Phase.SHOOTING
	_show_flash("SPARA!", Color(1.0, 0.9, 0.2))
	_update_hud()

func _start_collecting() -> void:
	_phase = Phase.COLLECTING
	_collect_timer = 20.0
	_terrain.stop_firing()
	_remove_barrier()
	_show_flash("RACCOLTA!", Color(0.4, 1.0, 0.5))
	_update_hud()

func _end_round() -> void:
	_phase = Phase.BETWEEN_ROUNDS
	_clear_balls()
	_show_flash("Round %d completato!" % _round, Color(0.8, 0.6, 1.0))
	_shop.toggle()   # apre negozio automaticamente

func _on_shop_closed() -> void:
	if _phase == Phase.BETWEEN_ROUNDS:
		_start_round()

# ── Segnali ───────────────────────────────────────────────────────────────────

func _on_weapon_fired() -> void:
	_update_hud()

func _on_level_up(new_level: int) -> void:
	if _shop:
		_shop._on_level_up(new_level)
	if _terrain:
		_terrain.reinit()

# ── Input ─────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed and _phase == Phase.WAITING:
		var pos: Vector2 = (event as InputEventMouse).position
		if Rect2(490.0, 380.0, 300.0, 72.0).has_point(pos):
			_begin_shooting()
			return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_tree().quit()
		elif event.keycode == KEY_SPACE:
			_begin_shooting()
		elif event.keycode == KEY_F11:
			var win := get_window()
			win.mode = Window.MODE_WINDOWED if win.mode == Window.MODE_FULLSCREEN \
					   else Window.MODE_FULLSCREEN

# ── Process ───────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	# Flash testo fase
	if _flash_timer > 0.0:
		_flash_timer -= delta
		var alpha := clampf(_flash_timer / 0.5, 0.0, 1.0)
		_hud_flash.add_theme_color_override("font_color",
			Color(_flash_color.r, _flash_color.g, _flash_color.b, alpha))
		if _flash_timer <= 0.0:
			_hud_flash.visible = false

	match _phase:
		Phase.WAITING:
			pass

		Phase.SHOOTING:
			_round_timer -= delta
			_shot_timer  -= delta

			# Sblocca una nuova arma quando il timer dell'intervallo scade
			if _shot_timer <= 0.0 and _shots_to_give > 0:
				_shot_timer    += GameState.shot_interval()
				_shots_to_give -= 1
				_terrain.shots_available += 1

			_update_hud()

			if _round_timer <= 0.0:
				_start_collecting()

		Phase.COLLECTING:
			_collect_timer -= delta
			if _count_active_balls() == 0 or _collect_timer <= 0.0:
				_end_round()

# ── HUD ───────────────────────────────────────────────────────────────────────

func _update_hud() -> void:
	match _phase:
		Phase.WAITING:
			var duration := GameState.round_duration_at_level(GameState.level)
			_hud_timer.text  = "Round %d  —  %ds disponibili  —  premi START o SPAZIO" % [_round, duration]
			_hud_shots.text  = ""
			_hud_weapon.text = ""

		Phase.SHOOTING:
			var t       := maxi(0, int(ceil(_round_timer)))
			var given   := _shots_total - _shots_to_give
			var ready   := _terrain.shots_available
			var used    := given - ready
			var coming  := _shots_to_give

			_hud_timer.text = "Round %d  ⏱ %ds" % [_round, t]

			var parts: Array = []
			if ready  > 0: parts.append("◉ %d armi" % ready)
			if used   > 0: parts.append("✦ %d piazzate" % used)
			if coming > 0: parts.append("○ %d in arrivo" % coming)
			_hud_shots.text = "  ".join(parts)

			var wname: String = DestructibleArea.WEAPONS[_terrain.current_weapon].name
			_hud_weapon.text = "▶ " + wname

		Phase.COLLECTING:
			_hud_timer.text  = "RACCOLTA…"
			_hud_shots.text  = ""
			_hud_weapon.text = ""

		Phase.BETWEEN_ROUNDS:
			_hud_timer.text  = ""
			_hud_shots.text  = ""
			_hud_weapon.text = ""

	_hud_start.visible = (_phase == Phase.WAITING)

func _show_flash(text: String, color: Color) -> void:
	_hud_flash.text    = text
	_flash_color       = color
	_flash_timer       = 2.2
	_hud_flash.visible = true
	_hud_flash.add_theme_color_override("font_color", color)
