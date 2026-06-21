class_name Ball
extends RigidBody2D

var radius:      float = 20.0
var ball_color:  Color = Color.RED
var money_value: int   = 10
var collected:   bool  = false

const BOUNCE_START:      float = 1.0   # rimbalzo iniziale
const BOUNCE_END:        float = 0.15  # rimbalzo minimo (non raggiunge zero)
const BOUNCE_DECAY_TIME: float = 18.0  # secondi per passare da START a END

var _elapsed: float = 0.0

func setup(r: float, c: Color, m_val: int = 10) -> void:
	radius      = r
	ball_color  = c
	money_value = m_val

	linear_damp  = 0.25   # lieve attrito dell'aria

	var mat := PhysicsMaterial.new()
	mat.bounce   = BOUNCE_START
	mat.friction = 0.05
	physics_material_override = mat

	var cshape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	cshape.shape  = circle
	add_child(cshape)

	linear_velocity = Vector2(randf_range(-280.0, 280.0), randf_range(-180.0, 60.0))
	queue_redraw()

func _physics_process(delta: float) -> void:
	if collected:
		return
	_elapsed += delta
	var t := minf(_elapsed / BOUNCE_DECAY_TIME, 1.0)
	physics_material_override.bounce = lerpf(BOUNCE_START, BOUNCE_END, t)

func _draw() -> void:
	draw_circle(Vector2(3.0, 5.0), radius * 0.95, Color(0.0, 0.0, 0.0, 0.22))
	draw_circle(Vector2.ZERO, radius, ball_color)
	draw_circle(Vector2.ZERO, radius * 0.82, ball_color.lightened(0.08))
	draw_circle(Vector2(-radius * 0.30, -radius * 0.32), radius * 0.26, Color(1.0, 1.0, 1.0, 0.52))
