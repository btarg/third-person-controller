# This class is extended by specific enemy AI implementations.
# Generic shared AI logic should go here.

class_name EnemyThinkState extends State

@onready var battle_character := state_machine.get_owner().get_node("BattleCharacter") as BattleCharacter

@export_group("Behavior Weights")
@export var base_attack_weight: float = 1.0
@export var base_spell_weight: float = 0.9
@export var base_move_weight: float = 0.8
@export var base_heal_weight: float = 0.7
@export var base_draw_spell_weight: float = 0.6
@export var base_defend_weight: float = 0.5

@export_group("Health Thresholds")
@export var critical_health_threshold: float = 0.25
@export var low_health_threshold: float = 0.4
@export var good_health_threshold: float = 0.6

@export_group("Aggression Settings")
@export var base_aggression: float = 0.5
@export var min_aggression: float = 0.1
@export var max_aggression: float = 1.0

var current_aggression: float = 0.5
var last_player_hp_ratio: float = 1.0
var last_damage_dealt: int = 0

var best_damage_spell: Item = null
var best_heal_spell: Item = null
var best_spell_to_cast: Item = null

# TODO: replace this with an array so we can have multiple targets (e.g. for AOE spells)
var target_character: BattleCharacter = null
var ally_target_character: BattleCharacter = null


var available_actions: Array[AIActionData] = []

func _get_best_spell_range() -> float:
	var max_range := 0.0

	if best_damage_spell:
		max_range = max(max_range, best_damage_spell.effective_range)
	if best_heal_spell:
		max_range = max(max_range, best_heal_spell.effective_range)

	# If no spells are available, return 0 so spell range checks will fail
	# This ensures the enemy will prioritize other actions like moving or defending
	return max_range

func _find_closest_player() -> BattleCharacter:
	var players := get_tree().get_nodes_in_group("Player")
	if players.is_empty():
		return battle_character.battle_state.current_character

	var enemy_pos: Vector3 = battle_character.get_parent().global_position
	var closest_player: Node = null
	var closest_distance := INF

	for player in players:
		var distance := enemy_pos.distance_to((player as Node3D).global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_player = player

	return closest_player.get_node("BattleCharacter") as BattleCharacter	

func _find_most_injured_ally() -> BattleCharacter:
	var all_enemies := get_tree().get_nodes_in_group("BattleCharacter")
	var most_injured_ally: BattleCharacter = null
	var lowest_health_ratio := 1.0

	for node in all_enemies:
		var battle_char := node as BattleCharacter
		if not battle_char:
			continue

		# Skip ourselves and non-enemies
		if battle_char == battle_character or battle_char.character_type != BattleEnums.ECharacterType.ENEMY:
			continue

		var current_hp := battle_char.current_hp
		var max_hp := battle_char.stats.get_stat(CharacterStatEntry.ECharacterStat.MaxHP)

		if max_hp <= 0:
			continue

		var health_ratio := current_hp / max_hp

		if health_ratio < lowest_health_ratio:
			lowest_health_ratio = health_ratio
			most_injured_ally = battle_char

	return most_injured_ally

func _get_context() -> AIDecisionContext:
	var current_hp := battle_character.current_hp
	var max_hp: float = max(0.0, battle_character.stats.get_stat(CharacterStatEntry.ECharacterStat.MaxHP))
	var current_mp := battle_character.current_mp
	var max_mp: float = max(0.0, battle_character.stats.get_stat(CharacterStatEntry.ECharacterStat.MaxMP))

	var attack_range: float = battle_character.stats.get_stat(CharacterStatEntry.ECharacterStat.AttackRange)
	var spell_range: float = _get_best_spell_range()

	# Find closest player as target
	# NOTE: this should never be null, since there will always be at least one player in the battle.
	target_character = _find_closest_player()

	# Find most injured ally for healing decisions
	ally_target_character = _find_most_injured_ally()

	var current_player_hp := target_character.current_hp
	var current_player_max_hp: float = max(0.0, target_character.stats.get_stat(CharacterStatEntry.ECharacterStat.MaxHP))

	var health_ratio := current_hp / max_hp
	var mana_ratio := current_mp / max_mp
	var player_health_ratio := current_player_hp / current_player_max_hp
	var distance_to_target: float = battle_character.get_parent().global_position.distance_to(
							target_character.get_parent().global_position)

	var in_attack_range: bool = distance_to_target <= attack_range
	var in_spell_range: bool = distance_to_target <= spell_range

	# Check if we can reach allies with heal spells
	var ally_in_heal_range := false
	if ally_target_character and best_heal_spell:
		var ally_distance: float = battle_character.get_parent().global_position.distance_to(
									   ally_target_character.get_parent().global_position)
		ally_in_heal_range = ally_distance <= best_heal_spell.effective_range

	# Extend spell range check to include ally healing range
	in_spell_range = in_spell_range or ally_in_heal_range    # Ally healing context
	var ally_needs_healing := false
	var ally_health_ratio := 1.0

	if ally_target_character:
		var ally_current_hp := ally_target_character.current_hp
		var ally_max_hp: float = max(0.0, ally_target_character.stats.get_stat(CharacterStatEntry.ECharacterStat.MaxHP))
		ally_health_ratio = ally_current_hp / ally_max_hp
		ally_needs_healing = ally_health_ratio < low_health_threshold

	print("=== %s Decision Context ===" % battle_character.character_name)
	print("HP: %d/%d (%.1f%%)" % [current_hp, max_hp, current_hp / max_hp * 100])
	print("MP: %d/%d (%.1f%%)" % [current_mp, max_mp, current_mp / max_mp * 100])
	print("Actions Left: %d/%d" % [battle_character.actions_left, battle_character.battle_state.START_ACTIONS])
	print("Aggression: %.2f" % current_aggression)

	if best_damage_spell:
		print("Best damage spell: %s (MP: %d, Range: %.1f, Actions: %d)" % [best_damage_spell.item_name, best_damage_spell.mp_cost, best_damage_spell.effective_range, best_damage_spell.actions_cost])
	if best_heal_spell:
		print("Best heal spell: %s (MP: %d, Range: %.1f, Actions: %d)" % [best_heal_spell.item_name, best_heal_spell.mp_cost, best_heal_spell.effective_range, best_heal_spell.actions_cost])

	print("Distance to target: %.1f" % distance_to_target)
	print("In attack range: %s | In spell range: %s" % [in_attack_range, in_spell_range])

	if ally_target_character:
		print("Most injured ally: %s (%.1f%% HP)" % [ally_target_character.character_name, ally_health_ratio * 100])

	print("=============================")

	return AIDecisionContext.new(
		health_ratio,
		mana_ratio,
		player_health_ratio,
		distance_to_target,
		in_attack_range,
		in_spell_range,
		current_aggression,
		ally_needs_healing,
		ally_target_character,
		ally_health_ratio
	)