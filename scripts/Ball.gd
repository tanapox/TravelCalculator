class_name Ball
extends RigidBody2D

var radius:      float = 20.0
var ball_color:  Color = Color.RED
var money_value: int   = 10
var collected:   bool  = false

func setup(r: float, c: Color, m_val: int = 10) -> void:
	radius      = r
	ball_color  = c
	money_value = m_val

	var mat := PhysicsMaterial.new()
	mat.bounce   = randf_range(0.65, 0.90)
	mat.friction = 0.04
	physics_material_override = mat

	var cshape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	cshape.shape  = circle
	add_child(cshape)

	linear_velocity = Vector2(randf_range(-280.0, 280.0), randf_range(-200.0, 80.0))
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2(3.0, 5.0), radius * 0.95, Color(0.0, 0.0, 0.0, 0.22))
	draw_circle(Vector2.ZERO, radius, ball_color)
	draw_circle(Vector2.ZERO, radius * 0.82, ball_color.lightened(0.08))
	draw_circle(Vector2(-radius * 0.30, -radius * 0.32), radius * 0.26, Color(1.0, 1.0, 1.0, 0.52))
