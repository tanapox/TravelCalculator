extends Control

# Left panel refs
var cookie_count_label: Label
var cps_label: Label
var cpc_label: Label
var cookie_button: Button
var total_label: Label

# Right panel refs
var buildings_list: VBoxContainer
var upgrades_list: VBoxContainer

var building_buttons: Dictionary = {}
var upgrade_buttons: Dictionary = {}

func _ready() -> void:
	_build_ui()
	_connect_signals()

	if SaveManager.load_game():
		_refresh_all()
	else:
		_refresh_all()

func _build_ui() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0

	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.12, 0.08, 0.05)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Main HBox
	var hbox = HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 0)
	add_child(hbox)

	# --- Left Panel ---
	var left_panel = _make_panel(Color(0.18, 0.11, 0.06), 420)
	hbox.add_child(left_panel)

	var left_vbox = VBoxContainer.new()
	left_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	left_vbox.add_theme_constant_override("separation", 16)
	left_panel.add_child(left_vbox)

	# Title
	var title = _make_label("Incremental Biscotti", 28, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	left_vbox.add_child(title)

	# Cookie count
	cookie_count_label = _make_label("0 biscotti", 36, true)
	cookie_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cookie_count_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))
	left_vbox.add_child(cookie_count_label)

	# CPS
	cps_label = _make_label("Per secondo: 0", 18)
	cps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cps_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	left_vbox.add_child(cps_label)

	# CPC
	cpc_label = _make_label("Per click: 1", 16)
	cpc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cpc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	left_vbox.add_child(cpc_label)

	# Cookie Button
	cookie_button = Button.new()
	cookie_button.text = "🍪"
	cookie_button.custom_minimum_size = Vector2(180, 180)
	cookie_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cookie_button.add_theme_font_size_override("font_size", 80)
	left_vbox.add_child(cookie_button)

	# Total cookies
	total_label = _make_label("Totale: 0", 14)
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	total_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	left_vbox.add_child(total_label)

	# Save / Reset buttons row
	var save_row = HBoxContainer.new()
	save_row.alignment = BoxContainer.ALIGNMENT_CENTER
	save_row.add_theme_constant_override("separation", 8)
	left_vbox.add_child(save_row)

	var save_btn = Button.new()
	save_btn.text = "Salva"
	save_btn.pressed.connect(func(): SaveManager.save_game())
	save_row.add_child(save_btn)

	var reset_btn = Button.new()
	reset_btn.text = "Reset"
	reset_btn.pressed.connect(_on_reset_pressed)
	save_row.add_child(reset_btn)

	# --- Right Panel ---
	var right_panel = _make_panel(Color(0.10, 0.07, 0.04))
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(right_panel)

	var scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	right_panel.add_child(scroll)

	var right_vbox = VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(right_vbox)

	# Upgrades section
	var up_title = _make_label("Potenziamenti", 20, true)
	up_title.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
	right_vbox.add_child(up_title)

	upgrades_list = VBoxContainer.new()
	upgrades_list.add_theme_constant_override("separation", 4)
	right_vbox.add_child(upgrades_list)

	var separator = HSeparator.new()
	right_vbox.add_child(separator)

	# Buildings section
	var build_title = _make_label("Edifici", 20, true)
	build_title.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	right_vbox.add_child(build_title)

	buildings_list = VBoxContainer.new()
	buildings_list.add_theme_constant_override("separation", 4)
	right_vbox.add_child(buildings_list)

	_create_building_buttons()
	_create_upgrade_buttons()

func _make_panel(color: Color, min_width: int = 0) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if min_width > 0:
		panel.custom_minimum_size.x = min_width
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _make_label(text: String, size: int = 16, bold: bool = false) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	return lbl

func _create_building_buttons() -> void:
	for id in GameManager.building_order:
		var b = GameManager.buildings[id]
		var btn = _make_shop_btn()
		btn.pressed.connect(func(): _on_buy_building(id))
		buildings_list.add_child(btn)
		building_buttons[id] = btn
	_refresh_building_buttons()

func _create_upgrade_buttons() -> void:
	for id in GameManager.upgrades:
		var btn = _make_shop_btn()
		btn.pressed.connect(func(): _on_buy_upgrade(id))
		btn.visible = false
		upgrades_list.add_child(btn)
		upgrade_buttons[id] = btn
	_refresh_upgrade_buttons()

func _make_shop_btn() -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(0, 64)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	return btn

func _connect_signals() -> void:
	GameManager.cookies_changed.connect(_on_cookies_changed)
	GameManager.cps_changed.connect(_on_cps_changed)
	GameManager.building_bought.connect(func(_id): _refresh_building_buttons())
	GameManager.upgrade_bought.connect(func(_id): _refresh_upgrade_buttons())
	GameManager.upgrade_unlocked.connect(_on_upgrade_unlocked)
	cookie_button.pressed.connect(GameManager.click)

func _on_cookies_changed(_amount: float) -> void:
	cookie_count_label.text = GameManager.format_number(GameManager.cookies) + " biscotti"
	total_label.text = "Totale guadagnati: " + GameManager.format_number(GameManager.total_cookies)
	_refresh_building_buttons()
	_refresh_upgrade_buttons()

func _on_cps_changed(_amount: float) -> void:
	cps_label.text = "Per secondo: " + GameManager.format_number(GameManager.cookies_per_second)

func _on_upgrade_unlocked(id: String) -> void:
	if upgrade_buttons.has(id):
		upgrade_buttons[id].visible = true

func _refresh_building_buttons() -> void:
	for id in building_buttons:
		var b = GameManager.buildings[id]
		var btn: Button = building_buttons[id]
		var affordable = GameManager.can_afford(b.cost)
		btn.disabled = not affordable
		btn.text = " %s  [x%d]\n  Costo: %s  |  +%s/s" % [
			b.name,
			b.count,
			GameManager.format_number(b.cost),
			GameManager.format_number(b.base_cps * b.cps_multiplier)
		]

func _refresh_upgrade_buttons() -> void:
	for id in upgrade_buttons:
		var u = GameManager.upgrades[id]
		var btn: Button = upgrade_buttons[id]
		if u.bought:
			btn.visible = false
			continue
		if not GameManager.is_upgrade_unlocked(id):
			continue
		btn.disabled = not GameManager.can_afford(u.cost)
		btn.text = " %s\n  %s  |  Costo: %s" % [
			u.name,
			u.description,
			GameManager.format_number(u.cost)
		]

func _refresh_all() -> void:
	cookie_count_label.text = GameManager.format_number(GameManager.cookies) + " biscotti"
	total_label.text = "Totale guadagnati: " + GameManager.format_number(GameManager.total_cookies)
	cps_label.text = "Per secondo: " + GameManager.format_number(GameManager.cookies_per_second)
	cpc_label.text = "Per click: " + GameManager.format_number(GameManager.cookies_per_click)
	_refresh_building_buttons()
	_refresh_upgrade_buttons()

	# Re-show already-unlocked upgrades after load
	for id in GameManager.upgrades:
		if not GameManager.upgrades[id].bought and GameManager.is_upgrade_unlocked(id):
			if upgrade_buttons.has(id):
				upgrade_buttons[id].visible = true

func _on_buy_building(id: String) -> void:
	GameManager.buy_building(id)

func _on_buy_upgrade(id: String) -> void:
	if GameManager.buy_upgrade(id):
		cpc_label.text = "Per click: " + GameManager.format_number(GameManager.cookies_per_click)

func _on_reset_pressed() -> void:
	SaveManager.delete_save()
	get_tree().reload_current_scene()
