class_name Ball
extends RigidBody2D

var radius:      float = 10.0
var ball_color:  Color = Color.RED
var money_value: int   = 10
var collected:   bool  = false

const BOUNCE_START: float = 1.0
const BOUNCE_END:   float = 0.10
const BOUNCE_STEP:  float = 0.09  # decremento per ogni rimbalzo (~10 rimbalzi per fermarsi)

func setup(r: float, c: Color, m_val: int = 10) -> void:
	radius      = r
	ball_color  = c
	money_value = m_val

	can_sleep             = false
	gravity_scale         = 0.0   # immobile fino a start_falling()
	contact_monitor       = true
	max_contacts_reported = 4
	linear_damp           = 0.25

	var mat := PhysicsMaterial.new()
	mat.bounce   = BOUNCE_START
	mat.friction = 0.05
	physics_material_override = mat

	var cshape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	cshape.shape  = circle
	add_child(cshape)

	queue_redraw()

func start_falling() -> void:
	gravity_scale = 1.0

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if collected:
		return
	if state.get_contact_count() > 0:
		var b := physics_material_override.bounce
		physics_material_override.bounce = maxf(BOUNCE_END, b - BOUNCE_STEP)
		state.linear_velocity.x += randf_range(-90.0, 90.0)

func _draw() -> void:
	draw_circle(Vector2(3.0, 5.0), radius * 0.95, Color(0.0, 0.0, 0.0, 0.22))
	draw_circle(Vector2.ZERO, radius, ball_color)
	draw_circle(Vector2.ZERO, radius * 0.82, ball_color.lightened(0.08))
	draw_circle(Vector2(-radius * 0.30, -radius * 0.32), radius * 0.26, Color(1.0, 1.0, 1.0, 0.52))
