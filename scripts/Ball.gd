class_name Ball
extends RigidBody2D

var radius:      float = 20.0
var ball_color:  Color = Color.RED
var money_value: int   = 10
var collected:   bool  = false

const MIN_SPEED: float = 120.0

func setup(r: float, c: Color, m_val: int = 10) -> void:
	radius      = r
	ball_color  = c
	money_value = m_val

	var mat := PhysicsMaterial.new()
	mat.bounce              = 0.92
	mat.bounce_combine_mode = 1  # COMBINE_MAX: vince sempre il valore più alto
	mat.friction              = 0.0
	mat.friction_combine_mode = 2  # COMBINE_MIN
	physics_material_override = mat

	var cshape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	cshape.shape  = circle
	add_child(cshape)

	linear_velocity = Vector2(randf_range(-280.0, 280.0), randf_range(-180.0, 60.0))
	queue_redraw()

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if collected:
		return
	if state.linear_velocity.length_squared() < MIN_SPEED * MIN_SPEED:
		var angle := randf() * TAU
		state.linear_velocity = Vector2(cos(angle), sin(angle)) * MIN_SPEED

func _draw() -> void:
	draw_circle(Vector2(3.0, 5.0), radius * 0.95, Color(0.0, 0.0, 0.0, 0.22))
	draw_circle(Vector2.ZERO, radius, ball_color)
	draw_circle(Vector2.ZERO, radius * 0.82, ball_color.lightened(0.08))
	draw_circle(Vector2(-radius * 0.30, -radius * 0.32), radius * 0.26, Color(1.0, 1.0, 1.0, 0.52))
