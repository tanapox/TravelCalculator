class_name Ball
extends RigidBody2D

var radius:      float = 10.0
var ball_color:  Color = Color.RED
var money_value: int   = 10
var collected:   bool  = false
var _falling:    bool  = false
var _settled:    bool  = false

const BOUNCE_START: float = 1.0
const BOUNCE_END:   float = 0.0
const BOUNCE_STEP:  float = 0.30  # bounce azzerato in ~4 rimbalzi

func setup(r: float, c: Color, m_val: int = 10) -> void:
	radius      = r
	ball_color  = c
	money_value = m_val

	can_sleep             = false
	contact_monitor       = true
	max_contacts_reported = 4
	linear_damp           = 1.2
	angular_damp          = 4.0

	var mat := PhysicsMaterial.new()
	mat.bounce   = BOUNCE_START
	mat.friction = 0.85
	physics_material_override = mat

	var cshape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	cshape.shape  = circle
	add_child(cshape)

	queue_redraw()

func start_falling() -> void:
	_falling = true

func _physics_process(_delta: float) -> void:
	if collected or _settled:
		return
	if _falling and linear_velocity.length_squared() < 36.0:
		_settle()

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if collected:
		return
	if _settled:
		state.linear_velocity = Vector2.ZERO
		state.angular_velocity = 0.0
		return
	if state.get_contact_count() > 0:
		var b := physics_material_override.bounce
		physics_material_override.bounce = maxf(BOUNCE_END, b - BOUNCE_STEP)
		if _falling:
			state.linear_velocity.x += randf_range(-6.0, 6.0)
		if physics_material_override.bounce <= BOUNCE_END:
			_settle()
			state.linear_velocity = Vector2.ZERO
			state.angular_velocity = 0.0

func _settle() -> void:
	_settled = true
	physics_material_override.bounce = 0.0

func _draw() -> void:
	draw_circle(Vector2(3.0, 5.0), radius * 0.95, Color(0.0, 0.0, 0.0, 0.22))
	draw_circle(Vector2.ZERO, radius, ball_color)
	draw_circle(Vector2.ZERO, radius * 0.82, ball_color.lightened(0.08))
	draw_circle(Vector2(-radius * 0.30, -radius * 0.32), radius * 0.26, Color(1.0, 1.0, 1.0, 0.52))
