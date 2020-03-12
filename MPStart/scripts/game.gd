extends Node

onready var main_scene = get_tree().root.get_child(get_tree().root.get_child_count() - 1)
onready var world = main_scene.get_node("world")

var spawn_points = []
var interest_points = []

func _ready():
	pass
