extends Node2D

const W: int    = 1280
const H: int    = 720
const TOP_H: int = H / 3   # 240 px

const SECTION_COLORS: Array = [
	Color(0.09, 0.06, 0.15),
	Color(0.05, 0.09, 0.06),
	Color(0.10, 0.05, 0.05),
]

const BALL_COLORS: Array = [
	Color(0.95, 0.28, 0.28),
	Color(0.28, 0.65, 0.95),
	Color(0.28, 0.90, 0.42),
	Color(0.95, 0.85, 0.18),
	Color(0.95, 0.48, 0.08),
	Color(0.72, 0.28, 0.95),
	Color(0.18, 0.88, 0.82),
	Color(0.95, 0.38, 0.72),
]

const BALL_VALUES: Array    = [10, 20, 15, 25, 30, 50, 35, 40]
const BALL_COUNT_MIN: int   = 6
const BALL_COUNT_MAX: int   = 14
const BALL_RADIUS_MIN: float = 14.0
const BALL_RADIUS_MAX: float = 46.0

var _terrain: DestructibleArea
var _bucket:  BucketSection
var _shop:    UpgradeShop

func _ready() -> void:
	_setup_background()
	_setup_walls()
	_spawn_balls()
	_add_boundary_visuals()
	_add_terrain()
	_add_bucket_section()
	_add_upgrade_shop()
	GameState.level_up.connect(_on_level_up)

# ── Background ────────────────────────────────────────────────────────────────

func _setup_background() -> void:
	for i in 3:
		var rect := ColorRect.new()
		rect.position = Vector2(0.0, i * TOP_H)
		rect.size     = Vector2(W, TOP_H)
		rect.color    = SECTION_COLORS[i]
		rect.z_index  = -10
		add_child(rect)

# ── Walls ─────────────────────────────────────────────────────────────────────

func _setup_walls() -> void:
	const T := 24
	_make_wall(Vector2(W / 2.0, -T / 2.0),       Vector2(W + T * 2, T))
	_make_wall(Vector2(-T / 2.0,   TOP_H),        Vector2(T, TOP_H * 2 + T * 2))
	_make_wall(Vector2(W + T / 2.0, TOP_H),       Vector2(T, TOP_H * 2 + T * 2))

func _make_wall(pos: Vector2, size: Vector2) -> void:
	var body   := StaticBody2D.new()
	body.position = pos
	var cshape := CollisionShape2D.new()
	var rect   := RectangleShape2D.new()
	rect.size  = size
	cshape.shape = rect
	body.add_child(cshape)
	add_child(body)

# ── Balls ─────────────────────────────────────────────────────────────────────

func _spawn_balls() -> void:
	var count := randi_range(BALL_COUNT_MIN, BALL_COUNT_MAX)
	for _i in count:
		_create_ball()

func _create_ball() -> void:
	var r         := randf_range(BALL_RADIUS_MIN, BALL_RADIUS_MAX)
	var color_idx := randi() % BALL_COLORS.size()
	var ball := Ball.new()
	ball.position = Vector2(
		randf_range(r + 4.0, W - r - 4.0),
		randf_range(r + 4.0, TOP_H - r - 8.0)
	)
	add_child(ball)
	ball.setup(r, BALL_COLORS[color_idx], BALL_VALUES[color_idx])

# ── Boundary visuals ──────────────────────────────────────────────────────────

func _add_boundary_visuals() -> void:
	var glow := Line2D.new()
	glow.add_point(Vector2(0.0, TOP_H))
	glow.add_point(Vector2(W,   TOP_H))
	glow.width         = 14.0
	glow.default_color = Color(0.40, 0.75, 1.0, 0.22)
	glow.z_index       = 50
	add_child(glow)

	var line := Line2D.new()
	line.add_point(Vector2(0.0, TOP_H))
	line.add_point(Vector2(W,   TOP_H))
	line.width         = 3.0
	line.default_color = Color(0.65, 0.90, 1.0, 0.95)
	line.z_index       = 51
	add_child(line)

	var divider := Line2D.new()
	divider.add_point(Vector2(0.0, TOP_H * 2))
	divider.add_point(Vector2(W,   TOP_H * 2))
	divider.width         = 2.0
	divider.default_color = Color(0.50, 0.50, 0.55, 0.35)
	divider.z_index       = 50
	add_child(divider)

# ── Terrain + Bucket ──────────────────────────────────────────────────────────

func _add_terrain() -> void:
	_terrain = DestructibleArea.new()
	_terrain.position = Vector2(0.0, float(TOP_H))
	add_child(_terrain)

func _add_bucket_section() -> void:
	_bucket = BucketSection.new()
	_bucket.position = Vector2(0.0, float(TOP_H * 2))
	add_child(_bucket)

# ── Upgrade Shop ──────────────────────────────────────────────────────────────

func _add_upgrade_shop() -> void:
	_shop = UpgradeShop.new()
	add_child(_shop)

# ── Level up ──────────────────────────────────────────────────────────────────

func _on_level_up(new_level: int) -> void:
	# Notify shop (shows "LIVELLO N!" banner)
	if _shop:
		_shop._on_level_up(new_level)
	# Regenerate terrain with new HP multiplier
	if _terrain:
		_terrain.reinit()
