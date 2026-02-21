extends Node2D

@export var warrior_scene: PackedScene # Drag Warrior.tscn here in Inspector

func _ready():
	GameManager.start_game(warrior_scene, $".", Vector2(500, 300))
