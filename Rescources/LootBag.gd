extends ItemData
class_name LootBagData

@export_group("Rewards")
@export var gold_reward: int = 0
@export var exp_reward: float = 0.0

# This will hold the actual items rolled by the LootTable
var contents: Array[ItemData] = []
var is_instant_use: bool = true
