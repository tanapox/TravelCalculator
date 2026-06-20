class_name UpgradeShop
extends CanvasLayer

# ── Layout albero ─────────────────────────────────────────────────────────────
# Posizione di ogni card: Vector2(MARGIN_X + grid_x * CELL_W, HEADER_Y + grid_y * CELL_H)

const CARD_W:   float = 340.0
const CARD_H:   float = 145.0
const CELL_W:   float = 380.0
const CELL_H:   float = 165.0
const MARGIN_X: float = 80.0
const HEADER_Y: float = 92.0

# ── Inner node per linee di connessione ──────────────────────────────────────

class LineNode extends Node2D:
	var shop: UpgradeShop
	func _draw() -> void:
		if shop:
			shop._draw_connections(self)

# ── Stato ─────────────────────────────────────────────────────────────────────

var _visible_flag:   bool       = false
var _money_lbl:      Label
var _level_lbl:      Label
var _bar_fill:       ColorRect
var _notif_lbl:      Label
var _notif_timer:    float      = 0.0
var _line_node:      LineNode
var _node_positions: Dictionary = {}   # id → Vector2 (angolo top-left card)
var _cards:          Dictionary = {}   # id → {bg, border, lvl_lbl, eff_lbl, btn}

# ── Init ──────────────────────────────────────────────────────────────────────

func _ready() -> void:
	layer   = 10
	visible = false
	_build_ui()
	GameState.money_changed.connect(_on_money_changed)
	GameState.upgrade_bought.connect(_on_upgrade_bought)
	GameState.level_up.connect(_on_level_up)

func _build_ui() -> void:
	# Sfondo opaco
	var bg := ColorRect.new()
	bg.color          = Color(0.04, 0.04, 0.06, 0.95)
	bg.anchors_preset = Control.PRESET_FULL_RECT
	add_child(bg)

	# Titolo centrato
	var title := Label.new()
	title.text       = "POTENZIAMENTI"
	title.position   = Vector2(0.0, 10.0)
	title.size       = Vector2(1280.0, 38.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	add_child(title)

	# Hint chiusura
	var hint := Label.new()
	hint.text     = "[TAB] chiudi"
	hint.position = Vector2(1108.0, 14.0)
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	add_child(hint)

	# Monete
	_money_lbl = Label.new()
	_money_lbl.position = Vector2(40.0, 10.0)
	_money_lbl.add_theme_font_size_override("font_size", 22)
	_money_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.22))
	add_child(_money_lbl)

	# Livello
	_level_lbl = Label.new()
	_level_lbl.position = Vector2(40.0, 40.0)
	_level_lbl.add_theme_font_size_override("font_size", 15)
	_level_lbl.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	add_child(_level_lbl)

	# Barra progresso
	var bar_bg := ColorRect.new()
	bar_bg.position = Vector2(40.0, 66.0)
	bar_bg.size     = Vector2(400.0, 8.0)
	bar_bg.color    = Color(0.15, 0.15, 0.20)
	add_child(bar_bg)

	_bar_fill = ColorRect.new()
	_bar_fill.position = Vector2(40.0, 66.0)
	_bar_fill.size     = Vector2(0.0, 8.0)
	_bar_fill.color    = Color(0.3, 0.8, 1.0)
	add_child(_bar_fill)

	# Linea divisore header
	var sep := ColorRect.new()
	sep.position = Vector2(0.0, 80.0)
	sep.size     = Vector2(1280.0, 1.0)
	sep.color    = Color(0.25, 0.25, 0.32)
	add_child(sep)

	# Node per connessioni (disegnato prima delle card = sotto)
	_line_node      = LineNode.new()
	_line_node.shop = self
	add_child(_line_node)

	# Card per ogni upgrade
	for upg in GameState.UPGRADES:
		var pos := Vector2(
			MARGIN_X + float(upg.grid_x) * CELL_W,
			HEADER_Y  + float(upg.grid_y) * CELL_H
		)
		_node_positions[upg.id] = pos
		_build_card(upg, pos)

	# Notifica livello (in basso)
	_notif_lbl = Label.new()
	_notif_lbl.position = Vector2(0.0, 620.0)
	_notif_lbl.size     = Vector2(1280.0, 60.0)
	_notif_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notif_lbl.add_theme_font_size_override("font_size", 38)
	_notif_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	_notif_lbl.visible = false
	add_child(_notif_lbl)

	_refresh_header()
	_refresh_all_cards()

func _build_card(upg: Dictionary, pos: Vector2) -> void:
	var card_bg := ColorRect.new()
	card_bg.position = pos
	card_bg.size     = Vector2(CARD_W, CARD_H)
	card_bg.color    = Color(0.10, 0.10, 0.14)
	add_child(card_bg)

	# Bordo superiore colorato
	var border := ColorRect.new()
	border.position = pos
	border.size     = Vector2(CARD_W, 2.0)
	border.color    = Color(0.35, 0.35, 0.45)
	add_child(border)

	var name_lbl := Label.new()
	name_lbl.text     = upg.name
	name_lbl.position = pos + Vector2(8.0, 5.0)
	name_lbl.size     = Vector2(CARD_W - 16.0, 26.0)
	name_lbl.add_theme_font_size_override("font_size", 17)
	name_lbl.add_theme_color_override("font_color", Color(0.95, 0.92, 0.75))
	add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text          = upg.desc
	desc_lbl.position      = pos + Vector2(8.0, 31.0)
	desc_lbl.size          = Vector2(CARD_W - 16.0, 38.0)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", Color(0.60, 0.60, 0.65))
	add_child(desc_lbl)

	var lvl_lbl := Label.new()
	lvl_lbl.position = pos + Vector2(8.0, 70.0)
	lvl_lbl.size     = Vector2(CARD_W - 16.0, 22.0)
	lvl_lbl.add_theme_font_size_override("font_size", 13)
	lvl_lbl.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
	add_child(lvl_lbl)

	var eff_lbl := Label.new()
	eff_lbl.position = pos + Vector2(8.0, 90.0)
	eff_lbl.size     = Vector2(CARD_W - 16.0, 20.0)
	eff_lbl.add_theme_font_size_override("font_size", 12)
	eff_lbl.add_theme_color_override("font_color", Color(0.70, 0.88, 1.0))
	add_child(eff_lbl)

	var btn := Button.new()
	btn.position = pos + Vector2(8.0, CARD_H - 38.0)
	btn.size     = Vector2(CARD_W - 16.0, 30.0)
	btn.add_theme_font_size_override("font_size", 14)
	btn.pressed.connect(_on_buy.bind(upg.id))
	add_child(btn)

	_cards[upg.id] = {
		"id":      upg.id,
		"bg":      card_bg,
		"border":  border,
		"lvl_lbl": lvl_lbl,
		"eff_lbl": eff_lbl,
		"btn":     btn,
	}

# ── Connessioni (chiamata da LineNode._draw) ─────────────────────────────────

func _draw_connections(node: Node2D) -> void:
	var drawn: Dictionary = {}
	for upg in GameState.UPGRADES:
		if not _node_positions.has(upg.id):
			continue
		var from := _node_positions[upg.id] + Vector2(CARD_W * 0.5, CARD_H * 0.5)
		for conn_id: String in upg.connect:
			if not _node_positions.has(conn_id):
				continue
			# Chiave canonica per evitare doppio disegno
			var pair := (upg.id + "|" + conn_id) if upg.id < conn_id else (conn_id + "|" + upg.id)
			if drawn.has(pair):
				continue
			drawn[pair] = true
			var to := _node_positions[conn_id] + Vector2(CARD_W * 0.5, CARD_H * 0.5)
			# Spessore e colore variano se almeno un lato è upgradato
			var a_owned := GameState.get_upg_level(upg.id) > 0
			var b_owned := GameState.get_upg_level(conn_id) > 0
			var col := Color(0.45, 0.55, 0.75, 0.80) if (a_owned or b_owned) \
					   else Color(0.25, 0.25, 0.35, 0.55)
			var w := 2.5 if (a_owned and b_owned) else 1.5
			node.draw_line(from, to, col, w)

# ── Refresh ───────────────────────────────────────────────────────────────────

func _refresh_header() -> void:
	_money_lbl.text = "$ %d" % GameState.money
	var lv   := GameState.level
	var cur  := GameState.total_earned
	var th   := GameState.level_threshold(lv + 1)
	var prev := GameState.level_threshold(lv)
	_level_lbl.text = "Livello %d / 100" % lv
	if lv < 100 and th > prev:
		_bar_fill.size.x = 400.0 * clampf(float(cur - prev) / float(th - prev), 0.0, 1.0)
	else:
		_bar_fill.size.x = 400.0

func _refresh_all_cards() -> void:
	for card in _cards.values():
		_refresh_card(card)
	if _line_node:
		_line_node.queue_redraw()

func _refresh_card(card: Dictionary) -> void:
	var id:     String     = card.id
	var upg:    Dictionary = GameState._find(id)
	if upg.is_empty():
		return
	var cur:    int = GameState.get_upg_level(id)
	var max_lv: int = int(upg.max_level)
	var cost:   int = GameState.next_cost(id)

	if cur >= max_lv:
		card.lvl_lbl.text = "Livello %d / %d  ★ MAX" % [cur, max_lv]
		card.btn.text     = "MAX"
		card.btn.disabled = true
		card.bg.color     = Color(0.09, 0.14, 0.09)
		card.border.color = Color(0.22, 0.55, 0.22)
	else:
		card.lvl_lbl.text = "Livello %d / %d" % [cur, max_lv]
		var can_buy := GameState.money >= cost
		card.btn.text     = "$ %d" % cost
		card.btn.disabled = not can_buy
		card.bg.color     = Color(0.10, 0.10, 0.14)
		card.border.color = Color(0.4, 0.7, 1.0) if can_buy else Color(0.30, 0.30, 0.40)

	card.eff_lbl.text = GameState.effect_text(id)

# ── Segnali GameState ─────────────────────────────────────────────────────────

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

# ── Tick ──────────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if _notif_timer > 0.0:
		_notif_timer -= delta
		var alpha := clampf(_notif_timer / 0.6, 0.0, 1.0)
		_notif_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2, alpha))
		if _notif_timer <= 0.0:
			_notif_lbl.visible = false

# ── Controllo ─────────────────────────────────────────────────────────────────

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
