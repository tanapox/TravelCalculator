extends Node2D

const W: int = 1280
const H: int = 720
const TOP_H: int = H / 3  # 240 px — la sezione in alto

const SECTION_COLORS: Array = [
	Color(0.09, 0.06, 0.15),  # alto: indaco scuro
	Color(0.05, 0.09, 0.06),  # mezzo: foresta scura
	Color(0.10, 0.05, 0.05),  # basso: cremisi scuro
]

const BALL_COLORS: Array = [
	Color(0.95, 0.28, 0.28),  # rosso
	Color(0.28, 0.65, 0.95),  # blu
	Color(0.28, 0.90, 0.42),  # verde
	Color(0.95, 0.85, 0.18),  # giallo
	Color(0.95, 0.48, 0.08),  # arancione
	Color(0.72, 0.28, 0.95),  # viola
	Color(0.18, 0.88, 0.82),  # ciano
	Color(0.95, 0.38, 0.72),  # rosa
]

const BALL_COUNT_MIN: int = 6
const BALL_COUNT_MAX: int = 14
const BALL_RADIUS_MIN: float = 14.0
const BALL_RADIUS_MAX: float = 46.0

func _ready() -> void:
	_setup_background()
	_setup_walls()
	_spawn_balls()
	_add_boundary_visuals()
	_add_terrain()

# ── Terrain distruttibile ─────────────────────────────────────────────────────

func _add_terrain() -> void:
	var terrain := DestructibleArea.new()
	terrain.position = Vector2(0.0, TOP_H)
	add_child(terrain)

# ── Background ────────────────────────────────────────────────────────────────

func _setup_background() -> void:
	for i in 3:
		var rect := ColorRect.new()
		rect.position = Vector2(0.0, i * TOP_H)
		rect.size = Vector2(W, TOP_H)
		rect.color = SECTION_COLORS[i]
		rect.z_index = -10
		add_child(rect)

# ── Walls ─────────────────────────────────────────────────────────────────────
# Quattro muri chiudono la sezione superiore:
#   tetto, parete sinistra, parete destra, linea invalicabile in basso.

func _setup_walls() -> void:
	const T := 24  # spessore muri
	_make_wall(Vector2(W / 2.0,        -T / 2.0),          Vector2(W + T * 2, T))      # tetto
	_make_wall(Vector2(-T / 2.0,        TOP_H / 2.0),      Vector2(T, TOP_H + T))      # sinistra
	_make_wall(Vector2(W + T / 2.0,     TOP_H / 2.0),      Vector2(T, TOP_H + T))      # destra
	_make_wall(Vector2(W / 2.0,         TOP_H + T / 2.0),  Vector2(W + T * 2, T))      # linea invalicabile

func _make_wall(pos: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = pos

	var cshape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	cshape.shape = rect
	body.add_child(cshape)

	add_child(body)

# ── Balls ─────────────────────────────────────────────────────────────────────

func _spawn_balls() -> void:
	var count := randi_range(BALL_COUNT_MIN, BALL_COUNT_MAX)
	for _i in count:
		_create_ball()

func _create_ball() -> void:
	var r := randf_range(BALL_RADIUS_MIN, BALL_RADIUS_MAX)
	var c: Color = BALL_COLORS[randi() % BALL_COLORS.size()]

	var ball := Ball.new()
	ball.position = Vector2(
		randf_range(r + 4.0, W - r - 4.0),
		randf_range(r + 4.0, TOP_H - r - 8.0)
	)

	add_child(ball)
	ball.setup(r, c)

# ── Boundary visuals ──────────────────────────────────────────────────────────
# La linea invalicabile è visibile con un bagliore azzurro.

func _add_boundary_visuals() -> void:
	# Alone (glow)
	var glow := Line2D.new()
	glow.add_point(Vector2(0.0, TOP_H))
	glow.add_point(Vector2(W, TOP_H))
	glow.width = 14.0
	glow.default_color = Color(0.40, 0.75, 1.0, 0.22)
	glow.z_index = 50
	add_child(glow)

	# Linea principale
	var line := Line2D.new()
	line.add_point(Vector2(0.0, TOP_H))
	line.add_point(Vector2(W, TOP_H))
	line.width = 3.0
	line.default_color = Color(0.65, 0.90, 1.0, 0.95)
	line.z_index = 51
	add_child(line)

	# Separatore tra sezione media e bassa (sottile, decorativo)
	var divider := Line2D.new()
	divider.add_point(Vector2(0.0, TOP_H * 2))
	divider.add_point(Vector2(W, TOP_H * 2))
	divider.width = 2.0
	divider.default_color = Color(0.50, 0.50, 0.55, 0.35)
	divider.z_index = 50
	add_child(divider)
