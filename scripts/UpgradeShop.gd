class_name UpgradeShop
extends CanvasLayer

signal shop_closed

var _visible_flag: bool = false
var _money_lbl:    Label
var _level_lbl:    Label
var _bar:          ColorRect
var _bar_fill:     ColorRect
var _cards:        Array = []   # Array[Dictionary] per upgrade card
var _notif_lbl:    Label
var _notif_timer:  float = 0.0

func _ready() -> void:
	layer = 10
	visible = false
	_build_ui()
	GameState.money_changed.connect(_on_money_changed)
	GameState.upgrade_bought.connect(_on_upgrade_bought)
	GameState.level_up.connect(_on_level_up)

func _build_ui() -> void:
	# Sfondo semi-trasparente
	var bg := ColorRect.new()
	bg.color         = Color(0.04, 0.04, 0.06, 0.94)
	bg.anchors_preset = Control.PRESET_FULL_RECT
	add_child(bg)

	# Titolo
	var title := Label.new()
	title.text       = "POTENZIAMENTI"
	title.position   = Vector2(0.0, 14.0)
	title.size       = Vector2(1280.0, 40.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	add_child(title)

	# Hint chiusura
	var hint := Label.new()
	hint.text     = "[TAB] chiudi"
	hint.position = Vector2(1120.0, 18.0)
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	add_child(hint)

	# Money label
	_money_lbl = Label.new()
	_money_lbl.position = Vector2(40.0, 18.0)
	_money_lbl.add_theme_font_size_override("font_size", 22)
	_money_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.22))
	add_child(_money_lbl)

	# Level label
	_level_lbl = Label.new()
	_level_lbl.position = Vector2(40.0, 48.0)
	_level_lbl.add_theme_font_size_override("font_size", 16)
	_level_lbl.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	add_child(_level_lbl)

	# Barra progresso livello
	var bar_bg := ColorRect.new()
	bar_bg.position = Vector2(40.0, 70.0)
	bar_bg.size     = Vector2(400.0, 10.0)
	bar_bg.color    = Color(0.18, 0.18, 0.22)
	add_child(bar_bg)

	_bar_fill = ColorRect.new()
	_bar_fill.position = Vector2(40.0, 70.0)
	_bar_fill.size     = Vector2(0.0, 10.0)
	_bar_fill.color    = Color(0.3, 0.8, 1.0)
	add_child(_bar_fill)

	# Notifica livello
	_notif_lbl = Label.new()
	_notif_lbl.position = Vector2(0.0, 320.0)
	_notif_lbl.size     = Vector2(1280.0, 60.0)
	_notif_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notif_lbl.add_theme_font_size_override("font_size", 36)
	_notif_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	_notif_lbl.visible = false
	add_child(_notif_lbl)

	# Griglia upgrade cards: 4 per riga, 2 righe
	const CARD_W: float = 290.0
	const CARD_H: float = 150.0
	const GAP:    float = 14.0
	const START_X: float = (1280.0 - (CARD_W * 4 + GAP * 3)) / 2.0
	const START_Y: float = 96.0

	for i in GameState.UPGRADES.size():
		var upg: Dictionary = GameState.UPGRADES[i]
		var col := i % 4
		var row := i / 4
		var cx  := START_X + col * (CARD_W + GAP)
		var cy  := START_Y + row * (CARD_H + GAP)

		var card_bg := ColorRect.new()
		card_bg.position = Vector2(cx, cy)
		card_bg.size     = Vector2(CARD_W, CARD_H)
		card_bg.color    = Color(0.10, 0.10, 0.14)
		add_child(card_bg)

		var border := ColorRect.new()
		border.position = Vector2(cx, cy)
		border.size     = Vector2(CARD_W, 2.0)
		border.color    = Color(0.35, 0.35, 0.45)
		add_child(border)

		var name_lbl := Label.new()
		name_lbl.text     = upg.name
		name_lbl.position = Vector2(cx + 8.0, cy + 6.0)
		name_lbl.size     = Vector2(CARD_W - 16.0, 26.0)
		name_lbl.add_theme_font_size_override("font_size", 17)
		name_lbl.add_theme_color_override("font_color", Color(0.95, 0.92, 0.75))
		add_child(name_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text          = upg.desc
		desc_lbl.position      = Vector2(cx + 8.0, cy + 32.0)
		desc_lbl.size          = Vector2(CARD_W - 16.0, 36.0)
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		desc_lbl.add_theme_font_size_override("font_size", 12)
		desc_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.70))
		add_child(desc_lbl)

		var lvl_lbl := Label.new()
		lvl_lbl.position = Vector2(cx + 8.0, cy + 68.0)
		lvl_lbl.size     = Vector2(CARD_W - 16.0, 22.0)
		lvl_lbl.add_theme_font_size_override("font_size", 13)
		lvl_lbl.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
		add_child(lvl_lbl)

		var eff_lbl := Label.new()
		eff_lbl.position = Vector2(cx + 8.0, cy + 88.0)
		eff_lbl.size     = Vector2(CARD_W - 16.0, 20.0)
		eff_lbl.add_theme_font_size_override("font_size", 12)
		eff_lbl.add_theme_color_override("font_color", Color(0.75, 0.90, 1.0))
		add_child(eff_lbl)

		var btn := Button.new()
		btn.position = Vector2(cx + 8.0, cy + CARD_H - 38.0)
		btn.size     = Vector2(CARD_W - 16.0, 30.0)
		btn.add_theme_font_size_override("font_size", 14)
		btn.pressed.connect(_on_buy.bind(upg.id))
		add_child(btn)

		_cards.append({
			"id":      upg.id,
			"bg":      card_bg,
			"border":  border,
			"lvl_lbl": lvl_lbl,
			"eff_lbl": eff_lbl,
			"btn":     btn,
		})

	_refresh_all_cards()
	_refresh_header()

func _refresh_header() -> void:
	_money_lbl.text = "$ %d" % GameState.money
	var lv  := GameState.level
	var cur := GameState.total_earned
	var th  := GameState.level_threshold(lv + 1)
	var prev := GameState.level_threshold(lv)
	_level_lbl.text = "Livello %d / 100" % lv
	if lv < 100 and th > prev:
		var ratio := float(cur - prev) / float(th - prev)
		_bar_fill.size.x = 400.0 * clampf(ratio, 0.0, 1.0)
	else:
		_bar_fill.size.x = 400.0

func _refresh_all_cards() -> void:
	for card in _cards:
		_refresh_card(card)

func _refresh_card(card: Dictionary) -> void:
	var id:  String     = card.id
	var upg: Dictionary = GameState._find(id)
	var cur: int        = GameState.get_upg_level(id)
	var max_lv: int     = int(upg.max_level)
	var cost: int       = GameState.next_cost(id)

	if cur >= max_lv:
		card.lvl_lbl.text = "Livello %d / %d  ★ MAX" % [cur, max_lv]
		card.btn.text     = "MAX"
		card.btn.disabled = true
		card.bg.color     = Color(0.10, 0.14, 0.10)
		card.border.color = Color(0.25, 0.55, 0.25)
	else:
		card.lvl_lbl.text = "Livello %d / %d" % [cur, max_lv]
		var can_buy := GameState.money >= cost
		card.btn.text     = "$ %d" % cost
		card.btn.disabled = not can_buy
		card.bg.color     = Color(0.10, 0.10, 0.14)
		card.border.color = Color(0.35, 0.35, 0.45) if not can_buy else Color(0.4, 0.7, 1.0)

	card.eff_lbl.text = GameState.effect_text(id)

func _on_buy(id: String) -> void:
	GameState.buy_upgrade(id)

func _on_money_changed(_amt: int) -> void:
	_refresh_header()
	_refresh_all_cards()

func _on_upgrade_bought(_id: String) -> void:
	_refresh_all_cards()

func _on_level_up(new_level: int) -> void:
	_refresh_header()
	_notif_lbl.text    = "LIVELLO %d!" % new_level
	_notif_lbl.visible = true
	_notif_timer       = 2.5

func _process(delta: float) -> void:
	if _notif_timer > 0.0:
		_notif_timer -= delta
		var alpha := clampf(_notif_timer / 0.6, 0.0, 1.0)
		_notif_lbl.add_theme_color_override("font_color",
			Color(1.0, 0.9, 0.2, alpha))
		if _notif_timer <= 0.0:
			_notif_lbl.visible = false

func toggle() -> void:
	_visible_flag = not _visible_flag
	visible = _visible_flag
	if _visible_flag:
		_refresh_header()
		_refresh_all_cards()

func show_notif(msg: String) -> void:
	_notif_lbl.text    = msg
	_notif_lbl.visible = true
	_notif_timer       = 2.5

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			toggle()
			get_viewport().set_input_as_handled()
