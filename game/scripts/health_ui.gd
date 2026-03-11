extends CanvasLayer

@onready var player_name_label: Label = $PlayerHealthPanel/Margin/VBox/Name
@onready var player_health_bar: ProgressBar = $PlayerHealthPanel/Margin/VBox/HealthBar
@onready var player_health_value: Label = $PlayerHealthPanel/Margin/VBox/Value

@onready var npc_panel: PanelContainer = $NPCHealthPanel
@onready var npc_name_label: Label = $NPCHealthPanel/Margin/VBox/Name
@onready var npc_health_bar: ProgressBar = $NPCHealthPanel/Margin/VBox/HealthBar
@onready var npc_health_value: Label = $NPCHealthPanel/Margin/VBox/Value

var _player = null
var _tracked_npc = null

func _ready():
	_connect_player()
	_connect_npcs()
	_connect_dialogue_ui()
	_update_player_bar()
	_select_active_npc()
	get_tree().node_added.connect(_on_node_added)

func _connect_player():
	_player = get_tree().root.find_child("Player", true, false)
	if _player and _player.has_signal("health_changed"):
		if not _player.health_changed.is_connected(_on_player_health_changed):
			_player.health_changed.connect(_on_player_health_changed)

func _connect_npcs():
	for npc in get_tree().get_nodes_in_group("health_npcs"):
		_register_npc(npc)

func _connect_dialogue_ui():
	var dialogue_ui = get_tree().root.find_child("DialogueUI", true, false)
	if dialogue_ui == null:
		return

	if dialogue_ui.has_signal("dialogue_opened") and not dialogue_ui.dialogue_opened.is_connected(_on_dialogue_opened):
		dialogue_ui.dialogue_opened.connect(_on_dialogue_opened)

	if dialogue_ui.has_signal("dialogue_closed") and not dialogue_ui.dialogue_closed.is_connected(_on_dialogue_closed):
		dialogue_ui.dialogue_closed.connect(_on_dialogue_closed)

func _register_npc(npc):
	if not npc.has_signal("health_changed"):
		return

	var health_changed_callable = _on_npc_health_changed.bind(npc)
	if not npc.health_changed.is_connected(health_changed_callable):
		npc.health_changed.connect(health_changed_callable)

	if npc.has_signal("interaction_state_changed") and not npc.interaction_state_changed.is_connected(_on_npc_state_changed):
		npc.interaction_state_changed.connect(_on_npc_state_changed)

	if npc.has_signal("boss_fight_state_changed") and not npc.boss_fight_state_changed.is_connected(_on_npc_state_changed):
		npc.boss_fight_state_changed.connect(_on_npc_state_changed)

	var died_callable = _on_npc_died.bind(npc)
	if npc.has_signal("died") and not npc.died.is_connected(died_callable):
		npc.died.connect(died_callable)

func _on_node_added(node):
	if node.is_in_group("health_npcs"):
		_register_npc(node)
		_select_active_npc()

func _on_player_health_changed(_current_health: int, _max_health: int):
	_update_player_bar()

func _update_player_bar():
	if _player == null:
		return

	if _player.has_method("is_dead") and _player.is_dead():
		player_name_label.text = "Player (Defeated)"
	else:
		player_name_label.text = "Player"

	player_health_bar.max_value = _player.max_health
	player_health_bar.value = _player.current_health
	player_health_value.text = "%d / %d" % [_player.current_health, _player.max_health]

func _on_dialogue_opened(_npc):
	_select_active_npc()

func _on_dialogue_closed(_npc):
	_select_active_npc()

func _on_npc_state_changed(_active: bool):
	_select_active_npc()

func _on_npc_health_changed(_current_health: int, _max_health: int, npc):
	if _tracked_npc == npc:
		_update_npc_bar(npc)

func _on_npc_died(npc):
	if _tracked_npc == npc:
		_tracked_npc = null
	_select_active_npc()

func _select_active_npc():
	var npcs = get_tree().get_nodes_in_group("health_npcs")
	var interacting_npc = null
	var boss_npc = null

	for npc in npcs:
		if npc.has_method("is_dead") and npc.is_dead():
			continue
		if npc.is_interacting_with_player:
			interacting_npc = npc
			break

	if interacting_npc == null:
		for npc in npcs:
			if npc.has_method("is_dead") and npc.is_dead():
				continue
			if npc.is_enemy and npc.is_boss and npc.boss_fight_active:
				boss_npc = npc
				break

	_tracked_npc = interacting_npc if interacting_npc != null else boss_npc
	if _tracked_npc == null:
		npc_panel.visible = false
		return

	_update_npc_bar(_tracked_npc)

func _update_npc_bar(npc):
	var show_for_interaction = npc.is_interacting_with_player
	var show_for_boss_fight = npc.is_enemy and npc.is_boss and npc.boss_fight_active
	npc_panel.visible = show_for_interaction or show_for_boss_fight
	if not npc_panel.visible:
		return

	npc_name_label.text = npc.npc_name
	npc_health_bar.max_value = npc.max_health
	npc_health_bar.value = npc.current_health
	npc_health_value.text = "%d / %d" % [npc.current_health, npc.max_health]
