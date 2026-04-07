extends Node

const SAVE_FILE = "user://leaderboard.save"

var top_score: int = 0

func load_score():
	if FileAccess.file_exists(SAVE_FILE):
		var file = FileAccess.open(SAVE_FILE, FileAccess.READ)
		top_score = file.get_var()
		file.close()

func save_score():
	var file = FileAccess.open(SAVE_FILE, FileAccess.WRITE)
	file.store_var(top_score)
	file.close()

func update_score(score: int):
	if score > top_score:
		top_score = score
		save_score()
