extends CanvasLayer

const SLOT_SIZE := 80
const GAP := 8
const BORDER := 3
const PANEL_W := 420
const PANEL_H := 500
const GRID_COLS := 4
const GRID_ROWS := 2

var _player: Node = null
var _panel: Control
var _visible := false
var _grid_slots: Array[Control] = []
var _grid_icons: Array[TextureRect] = []
var _grid_labels: Array[Label] = []
var _equip_slot: Control
var _equip_icon: TextureRect
var _equip_label: Label
var _trash_slot: Control
var _pistol_icon: Texture2D


func _ready() -> void:
	_player = get_node("../Player")
	_pistol_icon = preload("res://models/pistol_preview.png")
	_build_ui()
	_panel.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if _player and _player.is_dead:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			_toggle()
			get_viewport().set_input_as_handled()


func _toggle() -> void:
	_visible = not _visible
	_panel.visible = _visible
	_player.inventory_open = _visible
	if _visible:
		_refresh_all()


func _build_ui() -> void:
	_panel = Control.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	# Dark overlay background
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_child(overlay)

	# Panel border (behind bg)
	var border := ColorRect.new()
	border.color = Color(0.5, 0.5, 0.6, 1.0)
	border.set_anchors_preset(Control.PRESET_CENTER)
	border.offset_left = -PANEL_W / 2.0 - 3
	border.offset_right = PANEL_W / 2.0 + 3
	border.offset_top = -PANEL_H / 2.0 - 3
	border.offset_bottom = PANEL_H / 2.0 + 3
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(border)

	# Center panel bg
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.14, 0.97)
	bg.set_anchors_preset(Control.PRESET_CENTER)
	bg.offset_left = -PANEL_W / 2.0
	bg.offset_right = PANEL_W / 2.0
	bg.offset_top = -PANEL_H / 2.0
	bg.offset_bottom = PANEL_H / 2.0
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_child(bg)

	var content := VBoxContainer.new()
	content.set_anchors_preset(Control.PRESET_CENTER)
	content.offset_left = -PANEL_W / 2.0 + 20
	content.offset_right = PANEL_W / 2.0 - 20
	content.offset_top = -PANEL_H / 2.0 + 16
	content.offset_bottom = PANEL_H / 2.0 - 16
	content.add_theme_constant_override("separation", 14)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(content)

	# Title
	var title := Label.new()
	title.text = "INVENTORY"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	title.add_theme_constant_override("outline_size", 3)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(title)

	# Subtitle
	var subtitle := Label.new()
	subtitle.text = "Backpack"
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(subtitle)

	# Grid (4x2)
	var grid := GridContainer.new()
	grid.columns = GRID_COLS
	grid.add_theme_constant_override("h_separation", GAP)
	grid.add_theme_constant_override("v_separation", GAP)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(grid)

	for i in GRID_COLS * GRID_ROWS:
		var slot := _create_slot(Color(0.18, 0.18, 0.25, 1.0))
		grid.add_child(slot)
		_grid_slots.append(slot)
		var icon := _create_icon(slot)
		_grid_icons.append(icon)
		var lbl := _create_slot_label(slot)
		_grid_labels.append(lbl)
		var idx := i
		slot.gui_input.connect(func(event: InputEvent):
			_on_grid_slot_input(event, idx)
		)

	# Separator line
	var sep_line := ColorRect.new()
	sep_line.color = Color(0.35, 0.35, 0.45, 0.6)
	sep_line.custom_minimum_size = Vector2(0, 2)
	sep_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(sep_line)

	# Equipment section label
	var equip_title := Label.new()
	equip_title.text = "Equipment"
	equip_title.add_theme_font_size_override("font_size", 14)
	equip_title.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65))
	equip_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	equip_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(equip_title)

	# Equipment row
	var equip_row := HBoxContainer.new()
	equip_row.add_theme_constant_override("separation", 16)
	equip_row.alignment = BoxContainer.ALIGNMENT_CENTER
	equip_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(equip_row)

	# Right hand slot group
	var rh_group := VBoxContainer.new()
	rh_group.add_theme_constant_override("separation", 4)
	rh_group.alignment = BoxContainer.ALIGNMENT_CENTER
	rh_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	equip_row.add_child(rh_group)

	_equip_slot = _create_slot(Color(0.12, 0.22, 0.32, 1.0))
	rh_group.add_child(_equip_slot)
	_equip_icon = _create_icon(_equip_slot)
	_equip_label = _create_slot_label(_equip_slot)
	_equip_slot.gui_input.connect(_on_equip_slot_input)

	var rh_label := Label.new()
	rh_label.text = "Right Hand"
	rh_label.add_theme_font_size_override("font_size", 12)
	rh_label.add_theme_color_override("font_color", Color(0.6, 0.75, 1.0))
	rh_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rh_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rh_group.add_child(rh_label)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(40, 0)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	equip_row.add_child(spacer)

	# Trash slot group
	var trash_group := VBoxContainer.new()
	trash_group.add_theme_constant_override("separation", 4)
	trash_group.alignment = BoxContainer.ALIGNMENT_CENTER
	trash_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	equip_row.add_child(trash_group)

	_trash_slot = _create_slot(Color(0.32, 0.1, 0.1, 1.0))
	trash_group.add_child(_trash_slot)
	var trash_x := Label.new()
	trash_x.text = "X"
	trash_x.add_theme_font_size_override("font_size", 36)
	trash_x.add_theme_color_override("font_color", Color(0.8, 0.25, 0.2, 0.7))
	trash_x.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	trash_x.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	trash_x.size = Vector2(SLOT_SIZE - BORDER * 2, SLOT_SIZE - BORDER * 2)
	trash_x.position = Vector2(BORDER, BORDER)
	trash_x.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_trash_slot.add_child(trash_x)

	var trash_label := Label.new()
	trash_label.text = "Trash"
	trash_label.add_theme_font_size_override("font_size", 12)
	trash_label.add_theme_color_override("font_color", Color(0.8, 0.4, 0.4))
	trash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	trash_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trash_group.add_child(trash_label)

	# Hint bar
	var hint := Label.new()
	hint.text = "Left-click = Equip / Unequip    Right-click = Trash"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.45, 0.45, 0.55))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(hint)

	# Close hint
	var close_hint := Label.new()
	close_hint.text = "[E] Close"
	close_hint.add_theme_font_size_override("font_size", 13)
	close_hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.4))
	close_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	close_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(close_hint)


func _create_slot(bg_color: Color) -> Control:
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	slot.mouse_filter = Control.MOUSE_FILTER_STOP

	var border_rect := ColorRect.new()
	border_rect.color = Color(0.45, 0.45, 0.55, 0.8)
	border_rect.size = Vector2(SLOT_SIZE, SLOT_SIZE)
	border_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(border_rect)

	var bg_rect := ColorRect.new()
	bg_rect.color = bg_color
	bg_rect.position = Vector2(BORDER, BORDER)
	bg_rect.size = Vector2(SLOT_SIZE - BORDER * 2, SLOT_SIZE - BORDER * 2)
	bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(bg_rect)

	return slot


func _create_icon(slot: Control) -> TextureRect:
	var icon := TextureRect.new()
	icon.position = Vector2(BORDER + 6, BORDER + 6)
	icon.size = Vector2(SLOT_SIZE - BORDER * 2 - 12, SLOT_SIZE - BORDER * 2 - 12)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.visible = false
	slot.add_child(icon)
	return icon


func _create_slot_label(slot: Control) -> Label:
	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 0.8))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override("outline_size", 2)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	lbl.position = Vector2(BORDER, SLOT_SIZE - 18)
	lbl.size = Vector2(SLOT_SIZE - BORDER * 2, 16)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.visible = false
	slot.add_child(lbl)
	return lbl


func _get_item_name(item_id: String) -> String:
	if item_id == "pistol":
		return "Pistol"
	return item_id


func _on_grid_slot_input(event: InputEvent, index: int) -> void:
	if not event is InputEventMouseButton or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		if _player.inventory[index] != "":
			var item: String = _player.inventory[index]
			if _player.equipped_right_hand != "":
				_player.inventory[index] = _player.equipped_right_hand
				_player.equip_to_right_hand(item)
			else:
				_player.inventory[index] = ""
				_player.equip_to_right_hand(item)
			_refresh_all()
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		if _player.inventory[index] != "":
			_player.inventory[index] = ""
			_refresh_all()


func _on_equip_slot_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		if _player.equipped_right_hand != "":
			var item: String = _player.unequip_right_hand()
			for i in _player.inventory.size():
				if _player.inventory[i] == "":
					_player.inventory[i] = item
					break
			_refresh_all()
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		if _player.equipped_right_hand != "":
			_player.equipped_right_hand = ""
			_player._clear_right_hand_model()
			_refresh_all()


func _get_item_icon(item_id: String) -> Texture2D:
	if item_id == "pistol":
		return _pistol_icon
	return null


func _refresh_all() -> void:
	for i in _grid_slots.size():
		var item_id: String = _player.inventory[i] if i < _player.inventory.size() else ""
		if item_id != "":
			_grid_icons[i].texture = _get_item_icon(item_id)
			_grid_icons[i].visible = true
			_grid_labels[i].text = _get_item_name(item_id)
			_grid_labels[i].visible = true
		else:
			_grid_icons[i].visible = false
			_grid_labels[i].visible = false

	if _player.equipped_right_hand != "":
		_equip_icon.texture = _get_item_icon(_player.equipped_right_hand)
		_equip_icon.visible = true
		_equip_label.text = _get_item_name(_player.equipped_right_hand)
		_equip_label.visible = true
	else:
		_equip_icon.visible = false
		_equip_label.visible = false
