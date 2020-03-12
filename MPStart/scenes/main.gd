extends Node

const PORT = 27015
const MAX_PLAYERS = 32

onready var message = $ui/message
onready var world = $world

var spawn_points = []

var level_generated = false
var player_generated = []
var player_buffer = []

func _ready():
	var server = NetworkedMultiplayerENet.new()
	server.create_server(PORT, MAX_PLAYERS)
	get_tree().set_network_peer(server)
	
	var _client_connected = get_tree().connect("network_peer_connected", self, "_on_client_connected")
	var _client_disconnected = get_tree().connect("network_peer_disconnected", self, "_on_client_disconnected")
	
	# Get spawn points for players
	game.spawn_points = get_node("world/map/spawn_points").get_children()


func _on_client_connected(id):
	message.text = "Client " + str(id) + " connected."
	var player = load("res://scenes/player/player.tscn").instance()
	player.set_name(str(id))
	world.get_node("players").add_child(player)
	player.global_transform.origin = game.spawn_points[randi() % game.spawn_points.size()].global_transform.origin

func _on_client_disconnected(id):
	message.text = "Client " + str(id) + " disconnected."
	for p in world.get_node("players").get_children():
		if int(p.name) == id:
			world.get_node("players").remove_child(p)
			p.queue_free()

