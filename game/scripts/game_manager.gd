extends CanvasLayer

var score: int = 0

@onready var score_label: Label = $ScorePanel/ScoreRow/ScoreLabel

func _ready() -> void:
	$ScorePanel.visible = false
	if not LevelManager.score_changed.is_connected(_on_score_changed):
		LevelManager.score_changed.connect(_on_score_changed)
	_setup_score_display()
	_on_score_changed(LevelManager.get_score())

func _setup_score_display():
	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hbox.position = Vector2(15, 31)
	hbox.add_theme_constant_override("separation", 6)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(hbox)

	# Coin icon 16x16
	var coin_img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	coin_img.fill(Color(0, 0, 0, 0))
	for x in 16:
		for y in 16:
			var dist := Vector2(x, y).distance_to(Vector2(8.0, 8.0))
			if dist <= 6.5:
				coin_img.set_pixel(x, y, Color("f5c518"))
			elif dist <= 8.0:
				coin_img.set_pixel(x, y, Color("b8860b"))
	for p in [Vector2(5, 4), Vector2(6, 4), Vector2(5, 5)]:
		coin_img.set_pixel(int(p.x), int(p.y), Color("ffe87c"))

	var coin_icon := TextureRect.new()
	coin_icon.texture = ImageTexture.create_from_image(coin_img)
	coin_icon.custom_minimum_size = Vector2(16, 16)
	coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(coin_icon)

	# Score label
	var label := Label.new()
	label.text = "0"
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color("f5c518"))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1.0))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_constant_override("shadow_outline_size", 1)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.name = "LiveScoreLabel"
	hbox.add_child(label)

func add_point(amount: int = 1) -> void:
	LevelManager.add_score(amount)

func _on_score_changed(new_score: int) -> void:
	score = new_score
	if score_label != null:
		score_label.text = "%d" % score
	var live = get_node_or_null("LiveScoreLabel")
	if live == null:
		for child in get_children():
			live = child.get_node_or_null("LiveScoreLabel")
			if live:
				break
	if live:
		live.text = "%d" % score
