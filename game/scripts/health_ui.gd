extends CanvasLayer

@onready var player_health_bar: ProgressBar = $PlayerHealthPanel/Margin/VBox/HealthBar
@onready var player_health_value: Label = $PlayerHealthPanel/Margin/VBox/Value
@onready var player_name_label: Label = $PlayerHealthPanel/Margin/VBox/Name
@onready var npc_panel: PanelContainer = $NPCHealthPanel

var _player = null
var _player_tween: Tween = null
var _heart_texture: ImageTexture = null

var _boss = null
var _boss_bar: ProgressBar = null
var _boss_tween: Tween = null
var _boss_hbox: HBoxContainer = null

const COLOR_HEALTHY  := Color("4ade80")
const COLOR_LOW      := Color("fbbf24")
const COLOR_CRITICAL := Color("f87171")
const COLOR_BOSS     := Color("e63946")

func _ready():
	player_name_label.visible = false
	player_health_value.visible = false
	npc_panel.visible = false

	var panel_style := StyleBoxEmpty.new()
	$PlayerHealthPanel.add_theme_stylebox_override("panel", panel_style)
	$PlayerHealthPanel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	$PlayerHealthPanel.position = Vector2(8, 8)

	player_health_bar.custom_minimum_size = Vector2(200, 16)

	_add_heart_icon()
	_setup_bar_style()
	_connect_player()
	_update_player_bar()
	_setup_boss_bar()

func _process(_delta):
	_try_connect_boss()

func _add_heart_icon():
	var heart_size := 16
	var img := Image.create(heart_size, heart_size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var pixels := [
		Vector2(1,0), Vector2(2,0), Vector2(4,0), Vector2(5,0),
		Vector2(0,1), Vector2(1,1), Vector2(2,1), Vector2(3,1),
		Vector2(4,1), Vector2(5,1), Vector2(6,1),
		Vector2(0,2), Vector2(1,2), Vector2(2,2), Vector2(3,2),
		Vector2(4,2), Vector2(5,2), Vector2(6,2),
		Vector2(1,3), Vector2(2,3), Vector2(3,3), Vector2(4,3), Vector2(5,3),
		Vector2(2,4), Vector2(3,4), Vector2(4,4),
		Vector2(3,5)
	]

	var scale := 2
	var heart_color := Color("e63946")
	var dark_color  := Color("9b1b2a")

	for p in pixels:
		for dx in scale:
			for dy in scale:
				var px := int(p.x) * scale + dx
				var py := int(p.y) * scale + dy
				if px < heart_size and py < heart_size:
					img.set_pixel(px, py, heart_color)

	for p in [Vector2(1,0), Vector2(4,0)]:
		for dx in scale:
			for dy in scale:
				var px := int(p.x) * scale + dx
				var py := int(p.y) * scale + dy
				if px < heart_size and py < heart_size:
					img.set_pixel(px, py, dark_color)

	_heart_texture = ImageTexture.create_from_image(img)

	var heart_rect := TextureRect.new()
	heart_rect.texture = _heart_texture
	heart_rect.custom_minimum_size = Vector2(16, 16)
	heart_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	heart_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var bar_parent = player_health_bar.get_parent()
	bar_parent.remove_child(player_health_bar)
	bar_parent.add_child(hbox)
	player_health_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(heart_rect)
	hbox.add_child(player_health_bar)

func _setup_bar_style():
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.08, 0.08, 0.08, 0.85)
	bg_style.border_width_left   = 2
	bg_style.border_width_right  = 2
	bg_style.border_width_top    = 2
	bg_style.border_width_bottom = 2
	bg_style.border_color = Color(0, 0, 0, 1.0)
	bg_style.corner_radius_top_left     = 4
	bg_style.corner_radius_top_right    = 4
	bg_style.corner_radius_bottom_left  = 4
	bg_style.corner_radius_bottom_right = 4
	player_health_bar.add_theme_stylebox_override("background", bg_style)

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = COLOR_HEALTHY
	fill_style.border_width_left   = 1
	fill_style.border_width_right  = 0
	fill_style.border_width_top    = 1
	fill_style.border_width_bottom = 1
	fill_style.border_color = Color(0, 0, 0, 0.6)
	fill_style.corner_radius_top_left     = 3
	fill_style.corner_radius_top_right    = 3
	fill_style.corner_radius_bottom_left  = 3
	fill_style.corner_radius_bottom_right = 3
	player_health_bar.add_theme_stylebox_override("fill", fill_style)

func _connect_player():
	_player = get_tree().root.find_child("Player", true, false)
	if _player and _player.has_signal("health_changed"):
		if not _player.health_changed.is_connected(_on_player_health_changed):
			_player.health_changed.connect(_on_player_health_changed)

func _on_player_health_changed(_current: int, _max: int):
	_update_player_bar()

func _update_player_bar():
	if _player == null:
		return

	var ratio: float = float(_player.current_health) / float(_player.max_health) if _player.max_health > 0 else 0.0

	if _player_tween and _player_tween.is_valid():
		_player_tween.kill()
	_player_tween = create_tween()
	_player_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_player_tween.tween_property(player_health_bar, "value", float(_player.current_health), 0.35)
	player_health_bar.max_value = _player.max_health

	var fill_style := player_health_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if ratio <= 0.25:
		fill_style.bg_color = COLOR_CRITICAL
	elif ratio <= 0.5:
		fill_style.bg_color = COLOR_LOW
	else:
		fill_style.bg_color = COLOR_HEALTHY

	var flash := create_tween()
	flash.tween_property(player_health_bar, "modulate", Color(2.0, 2.0, 2.0), 0.0)
	flash.tween_property(player_health_bar, "modulate", Color(1, 1, 1), 0.2)

func _setup_boss_bar():
	_boss_hbox = HBoxContainer.new()
	_boss_hbox.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_boss_hbox.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_boss_hbox.position = Vector2(-8, 8)
	_boss_hbox.add_theme_constant_override("separation", 6)
	_boss_hbox.visible = false
	add_child(_boss_hbox)

	var icon_img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	icon_img.fill(Color(0.008, 0.0, 0.0, 0.0))
	var flame_orange := Color("791f00ff")
	var flame_yellow := Color("ffcc00")
	var flame_red    := Color("cc0000")

	var flame_pixels := [
		Vector2(7,0), Vector2(8,0),
		Vector2(6,1), Vector2(7,1), Vector2(8,1), Vector2(9,1),
		Vector2(5,2), Vector2(6,2), Vector2(7,2), Vector2(8,2), Vector2(9,2), Vector2(10,2),
		Vector2(4,3), Vector2(5,3), Vector2(6,3), Vector2(7,3), Vector2(8,3), Vector2(9,3), Vector2(10,3), Vector2(11,3),
		Vector2(4,4), Vector2(5,4), Vector2(6,4), Vector2(7,4), Vector2(8,4), Vector2(9,4), Vector2(10,4), Vector2(11,4),
		Vector2(3,5), Vector2(4,5), Vector2(5,5), Vector2(6,5), Vector2(7,5), Vector2(8,5), Vector2(9,5), Vector2(10,5), Vector2(11,5), Vector2(12,5),
		Vector2(3,6), Vector2(4,6), Vector2(5,6), Vector2(6,6), Vector2(7,6), Vector2(8,6), Vector2(9,6), Vector2(10,6), Vector2(11,6), Vector2(12,6),
		Vector2(3,7), Vector2(4,7), Vector2(5,7), Vector2(6,7), Vector2(7,7), Vector2(8,7), Vector2(9,7), Vector2(10,7), Vector2(11,7), Vector2(12,7),
		Vector2(4,8), Vector2(5,8), Vector2(6,8), Vector2(7,8), Vector2(8,8), Vector2(9,8), Vector2(10,8), Vector2(11,8),
		Vector2(5,9), Vector2(6,9), Vector2(7,9), Vector2(8,9), Vector2(9,9), Vector2(10,9),
		Vector2(6,10), Vector2(7,10), Vector2(8,10), Vector2(9,10),
		Vector2(7,11), Vector2(8,11),
	]
	var inner_pixels := [
		Vector2(7,2), Vector2(8,2),
		Vector2(6,3), Vector2(7,3), Vector2(8,3), Vector2(9,3),
		Vector2(6,4), Vector2(7,4), Vector2(8,4), Vector2(9,4),
		Vector2(6,5), Vector2(7,5), Vector2(8,5), Vector2(9,5),
		Vector2(7,6), Vector2(8,6),
	]

	for p in flame_pixels:
		var px := int(p.x)
		var py := int(p.y)
		if px >= 0 and px < 16 and py >= 0 and py < 16:
			icon_img.set_pixel(px, py, flame_orange)

	for p in inner_pixels:
		var px := int(p.x)
		var py := int(p.y)
		if px >= 0 and px < 16 and py >= 0 and py < 16:
			icon_img.set_pixel(px, py, flame_yellow)

	icon_img.set_pixel(7, 0, flame_red)
	icon_img.set_pixel(8, 0, flame_red)
	icon_img.set_pixel(7, 1, flame_red)
	icon_img.set_pixel(8, 1, flame_red)

	var icon_tex := ImageTexture.create_from_image(icon_img)
	var icon_rect := TextureRect.new()
	icon_rect.texture = icon_tex
	icon_rect.custom_minimum_size = Vector2(16, 16)
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	_boss_bar = ProgressBar.new()
	_boss_bar.custom_minimum_size = Vector2(200, 16)
	_boss_bar.show_percentage = false
	_boss_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.08, 0.08, 0.08, 0.85)
	bg_style.border_width_left   = 2
	bg_style.border_width_right  = 2
	bg_style.border_width_top    = 2
	bg_style.border_width_bottom = 2
	bg_style.border_color = Color(0, 0, 0, 1.0)
	bg_style.corner_radius_top_left     = 4
	bg_style.corner_radius_top_right    = 4
	bg_style.corner_radius_bottom_left  = 4
	bg_style.corner_radius_bottom_right = 4
	_boss_bar.add_theme_stylebox_override("background", bg_style)

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = COLOR_BOSS
	fill_style.border_width_left   = 1
	fill_style.border_width_right  = 0
	fill_style.border_width_top    = 1
	fill_style.border_width_bottom = 1
	fill_style.border_color = Color(0, 0, 0, 0.6)
	fill_style.corner_radius_top_left     = 3
	fill_style.corner_radius_top_right    = 3
	fill_style.corner_radius_bottom_left  = 3
	fill_style.corner_radius_bottom_right = 3
	_boss_bar.add_theme_stylebox_override("fill", fill_style)

	_boss_hbox.add_child(_boss_bar)
	_boss_hbox.add_child(icon_rect)

func _try_connect_boss():
	if _boss != null and is_instance_valid(_boss):
		_update_boss_bar_visibility()
		return

	var boss = get_tree().root.find_child("FinalBoss", true, false)
	if boss == null:
		if _boss_hbox != null:
			_boss_hbox.visible = false
		return

	_boss = boss

	var npc = _boss.get_node_or_null("NPC")
	if npc and npc.has_signal("health_changed"):
		if not npc.health_changed.is_connected(_on_boss_health_changed):
			npc.health_changed.connect(_on_boss_health_changed)

	if npc and npc.has_signal("died"):
		if not npc.died.is_connected(_on_boss_died):
			npc.died.connect(_on_boss_died)

	if _boss_bar != null and npc != null:
		_boss_bar.max_value = int(npc.get("max_health"))
		_boss_bar.value = int(npc.get("current_health"))

	_update_boss_bar_visibility()

func _on_boss_health_changed(current: int, max_health: int):
	if _boss_bar == null:
		return
	_boss_bar.max_value = max_health
	if _boss_tween and _boss_tween.is_valid():
		_boss_tween.kill()
	_boss_tween = create_tween()
	_boss_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_boss_tween.tween_property(_boss_bar, "value", float(current), 0.35)

	var flash := create_tween()
	flash.tween_property(_boss_bar, "modulate", Color(2.0, 2.0, 2.0), 0.0)
	flash.tween_property(_boss_bar, "modulate", Color(1, 1, 1), 0.2)

	_update_boss_bar_visibility()

func _on_boss_died():
	if _boss_hbox != null:
		var tween := create_tween()
		tween.tween_property(_boss_hbox, "modulate:a", 0.0, 0.5)
		await tween.finished
		_boss_hbox.visible = false

func _update_boss_bar_visibility():
	if _boss_hbox == null or _boss == null:
		return
	var npc = _boss.get_node_or_null("NPC")
	if npc == null:
		_boss_hbox.visible = false
		return
	var boss_fight_active = _boss.get("_combat_engaged")
	_boss_hbox.visible = bool(boss_fight_active)
