extends CanvasLayer

const SLOT_SIZE := 64
const GAP := 6
const MARGIN := 20
const BORDER := 2
const ICONS := ["⚡", "🔥", "", ""]

const GAUGE_W := 200
const GAUGE_H := 22
const GAUGE_INNER_W := 196

var _overlays: Array[ColorRect] = []
var _player: Node = null
var _hp_gauge_fill: ColorRect
var _hp_gauge_label: Label
var _sp_gauge_fill: ColorRect
var _sp_gauge_label: Label


func _ready() -> void:
	_player = get_node("../Player")

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", GAP)
	hbox.anchor_left = 1.0
	hbox.anchor_right = 1.0
	hbox.anchor_top = 1.0
	hbox.anchor_bottom = 1.0
	var total_w: float = SLOT_SIZE * 4 + GAP * 3
	hbox.offset_left = -(total_w + MARGIN)
	hbox.offset_right = -MARGIN
	hbox.offset_top = -(SLOT_SIZE + MARGIN)
	hbox.offset_bottom = -MARGIN
	root.add_child(hbox)

	for i in 4:
		hbox.add_child(_create_slot(i))

	# HP/SP gauges (bottom-left)
	var hp_result := _create_gauge(root, -(MARGIN + GAUGE_H * 2 + 4), Color(0.2, 0.8, 0.2, 0.9), "HP")
	_hp_gauge_fill = hp_result[0]
	_hp_gauge_label = hp_result[1]
	var sp_result := _create_gauge(root, -(MARGIN + GAUGE_H), Color(0.2, 0.4, 0.9, 0.9), "SP")
	_sp_gauge_fill = sp_result[0]
	_sp_gauge_label = sp_result[1]


func _create_gauge(parent: Control, y_pos: float, fill_color: Color, label_prefix: String) -> Array:
	var bg := ColorRect.new()
	bg.color = Color(0.15, 0.15, 0.2, 0.85)
	bg.anchor_left = 0
	bg.anchor_top = 1
	bg.anchor_right = 0
	bg.anchor_bottom = 1
	bg.offset_left = MARGIN
	bg.offset_right = MARGIN + GAUGE_W
	bg.offset_top = y_pos
	bg.offset_bottom = y_pos + GAUGE_H
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)
	var fill := ColorRect.new()
	fill.color = fill_color
	fill.position = Vector2(2, 2)
	fill.size = Vector2(GAUGE_INNER_W, GAUGE_H - 4)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(fill)
	var label := Label.new()
	label.text = label_prefix + ": 0 / 0"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2(2, 0)
	label.size = Vector2(GAUGE_INNER_W, GAUGE_H)
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(label)
	return [fill, label]


func _create_slot(index: int) -> Control:
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Border
	var border := ColorRect.new()
	border.color = Color(0.5, 0.5, 0.6, 0.9)
	border.size = Vector2(SLOT_SIZE, SLOT_SIZE)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(border)

	# Background
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.12, 0.2, 0.85)
	bg.position = Vector2(BORDER, BORDER)
	bg.size = Vector2(SLOT_SIZE - BORDER * 2, SLOT_SIZE - BORDER * 2)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(bg)

	# Icon
	if ICONS[index] != "":
		var icon := Label.new()
		icon.text = ICONS[index]
		icon.add_theme_font_size_override("font_size", 30)
		icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon.size = Vector2(SLOT_SIZE, SLOT_SIZE)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)

	# Cooldown overlay
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.position = Vector2(BORDER, BORDER)
	overlay.size = Vector2(SLOT_SIZE - BORDER * 2, SLOT_SIZE - BORDER * 2)
	overlay.visible = false
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(overlay)
	_overlays.append(overlay)

	# Key number
	var key_label := Label.new()
	key_label.text = str(index + 1)
	key_label.add_theme_font_size_override("font_size", 13)
	key_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 0.7))
	key_label.position = Vector2(5, SLOT_SIZE - 20)
	key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(key_label)

	return slot


func _process(_delta: float) -> void:
	if not _player:
		return
	var inner := SLOT_SIZE - BORDER * 2
	for i in 4:
		var cd: float = _player.skill_cooldowns[i]
		var max_cd: float = _player.skill_max_cooldowns[i]
		if max_cd > 0.0 and cd > 0.0:
			_overlays[i].visible = true
			var ratio := cd / max_cd
			_overlays[i].size.y = inner * ratio
		else:
			_overlays[i].visible = false

	# HP gauge
	var hp_ratio := clampf(_player.current_hp / _player.max_hp, 0.0, 1.0)
	_hp_gauge_fill.size.x = GAUGE_INNER_W * hp_ratio
	_hp_gauge_label.text = "HP: %d / %d" % [ceili(maxf(_player.current_hp, 0.0)), int(_player.max_hp)]

	# SP gauge
	var sp_ratio := clampf(_player.current_sp / _player.max_sp, 0.0, 1.0)
	_sp_gauge_fill.size.x = GAUGE_INNER_W * sp_ratio
	_sp_gauge_label.text = "SP: %d / %d" % [ceili(maxf(_player.current_sp, 0.0)), int(_player.max_sp)]
