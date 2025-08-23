extends Control
class_name ButtonScrollMenu

var buttons: Array[Control] = []
var _buttons_count: Array[float] = []

var index: int = 0
var selected_button: Control = null

var _scroll: float = 1
var _current_mouse_input_cooldown: float = 0
@export var mouse_input_cooldown: float = 0.40

## How long the UI waits before scrolling again when auto scrolling
@export var SCROLL_INTERVAL: float = 0.1
## How long a UI navigation button needs to be held for before auto scrolling starts
@export var HOLD_INTERVAL: float = 0.25

@export_group("Spacing")
@export var button_spacing_offset := 0
var button_spacing: int = -1
@export var margin_x := 16

@export var button_scene = preload("res://Assets/GUI/Inventory/InventoryElements/InventoryItemButtonPaint.tscn") as PackedScene
@onready var scrollbar_visual := $ClipControl/ColorRect/scroll as ColorRect
@onready var SCROLLBAR_BOTTOM := scrollbar_visual.position.y

# Used for spells that don't have a proper icon
@onready var placeholder_texture := preload("res://Assets/GUI/Icons/Items/item_misc.png") as Texture

@onready var scroll_timer := Timer.new()
@onready var hold_timer := Timer.new()

@onready var description_label := %InfoDescription as Label
@onready var dc_label := description_label.get_node("InfoDC") as Label

@onready var battle_state := GameModeStateMachine.get_node("BattleState") as BattleState

var item_inventory: Inventory:
    get:
        return item_inventory
    set(new_inventory):
        # If it's the same inventory, just update labels and return
        if item_inventory == new_inventory:
            update_labels()
            return
            
        # disconnect existing signal
        if item_inventory:
            item_inventory.inventory_updated.disconnect(_update_inventory_item)
        # connect new signal for item updates
        new_inventory.inventory_updated.connect(_update_inventory_item)

        if not buttons.is_empty():
            delete_all_buttons()

        # FIX: we get a list of items but not a copy of the inventory!
        var filtered_inventory_items := new_inventory.get_items()
        filtered_inventory_items.sort_custom(SpellHelper.sort_items_by_usefulness)

        for item_entry in filtered_inventory_items:
            _update_inventory_item(item_entry, new_inventory.get_item_count(item_entry.item_id), true)

        item_inventory = new_inventory

# Map item id to button
var item_button_map: Dictionary[int, InventoryItemButtonPaint] = {}

signal item_button_pressed(item: Item)
signal item_button_hovered(item: Item)

func _ready() -> void:

    hold_timer.wait_time = HOLD_INTERVAL
    hold_timer.one_shot = true
    add_child(hold_timer)

    scroll_timer.wait_time = SCROLL_INTERVAL
    scroll_timer.one_shot = false
    scroll_timer.timeout.connect(_on_scroll_timer_timeout)
    add_child(scroll_timer)


func _update_inventory_item(item: Item, item_count: int, is_new_item: bool) -> void:
    if item_count == 0:
        print("Item count is 0. Removing item.")
        _remove_item_button(item)
    else:
        if is_new_item:
            _add_button(item, item_count)
        else:
            _update_count_label(item)

func _add_button(item: Item, item_count: int) -> void:
    var new_button := button_scene.instantiate() as InventoryItemButtonPaint
    
    # initialize button spacing
    if button_spacing == -1:
        button_spacing = round(new_button.size.y) + button_spacing_offset
        print("New button spacing: " + str(button_spacing))
    
    new_button.mouse_entered.connect(_handle_button_focus.bind(new_button))
    new_button.pressed_item.connect(_handle_button_pressed.bind(new_button))

    buttons.append(new_button)
    _buttons_count.append(0)
    $ClipControl.add_child(new_button)

    new_button.set_item_count(item_count)
    new_button.set_item_name(item.item_name)

    var tex: Texture = null
    var icon_path = item.get_icon_path()
    if icon_path and ResourceLoader.exists(icon_path):
        var loaded_resource = load(icon_path)
        if loaded_resource is Texture:
            tex = loaded_resource as Texture
    new_button.set_item_icon(tex if tex else placeholder_texture)

    item_button_map[item.item_id] = new_button

    new_button.position.x = margin_x

func _update_count_label(item: Item) -> void:
    var button = item_button_map.get(item.item_id)
    print("[DEBUG UI] _update_count_label for %s (ID: %s)" % [item.item_name, item.item_id])
    if button:
        if item.has_count:
            var count = item_inventory.get_item_count(item.item_id)
            print("[DEBUG UI] Setting button count to: %d" % count)
            button.set_item_count(count)
        else:
            button.set_item_count(0)
    else:
        print("[DEBUG UI] Button not found for item ID: %s" % item.item_id)  

func _remove_item_button(item: Item) -> void:
    var button = item_button_map.get(item.item_id)
    if button:
        _delete_button(button)
        item_button_map.erase(item.item_id)

func update_index(new_index: int = -1, wraparound: bool = true, add: bool = true) -> void:
    if index < 0 or buttons.is_empty():
        return
    
    _current_mouse_input_cooldown = mouse_input_cooldown

    if add:
        index += new_index
    else:
        index = new_index

    if wraparound:
        if index >= buttons.size():
            index = 0
        elif index < 0:
            index = buttons.size() - 1
    else:
        index = clamp(index, 0, buttons.size() - 1)

    _scroll = clamp((index - 2) * -button_spacing, -button_spacing * (buttons.size() - 1), 0)

    # Update focus
    for i in range(buttons.size()):
        buttons[i].release_focus()
    
    buttons[index].grab_focus()
    update_labels()

func update_labels() -> void:
    if not item_inventory:
        return

    for item_id in item_button_map.keys():
        if item_button_map[item_id] == buttons[index]:
            var item := item_inventory.get_item(item_id)
            if not item:
                description_label.text = "Your inventory is empty.\nObtain spells from enemies by using DRAW."
                dc_label.text = ""
                continue
            description_label.text = item.get_item_description()

            if item.item_type in [Item.ItemType.BATTLE_ITEM, Item.ItemType.FIELD_ITEM]:
                var spell_use_roll: DiceRoll = item.get_spell_use_roll(battle_state.current_character, battle_state.player_selected_character)
                if spell_use_roll.difficulty_class > 1:
                    dc_label.text = "Roll: %s" % spell_use_roll.to_string()
                else:
                    dc_label.text = "No Difficulty Class"
            else:
                dc_label.text = ""

func _unhandled_input(event: InputEvent) -> void:
    if (not visible
    or event is InputEventMouseMotion):
        return

    if button_spacing == -1:
        return

    if Input.is_action_just_pressed("ui_up"):
        update_index(-1)
        hold_timer.start()
        await hold_timer.timeout

        if !scroll_timer.is_stopped():
            scroll_timer.stop()
        scroll_timer.start()
    elif Input.is_action_just_pressed("ui_down"):
        update_index(1)
        hold_timer.start()
        await hold_timer.timeout

        if !scroll_timer.is_stopped():
            scroll_timer.stop()
        scroll_timer.wait_time = SCROLL_INTERVAL
        scroll_timer.start()
    elif Input.is_action_just_pressed("arrow_left"):
        update_index(0, false, false)
    elif Input.is_action_just_pressed("arrow_right"):
        update_index(buttons.size() - 1, false, false)

    elif event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.is_pressed():
            update_index(-1, false)
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.is_pressed():
            update_index(1, false)

    if Input.is_action_just_released("ui_up") or Input.is_action_just_released("ui_down"):
        hold_timer.stop()
        scroll_timer.stop()

func _on_scroll_timer_timeout() -> void:
    if Input.is_action_pressed("ui_up"):
        update_index(-1, false)
    elif Input.is_action_pressed("ui_down"):
        update_index(1, false)

func _physics_process(delta: float) -> void:
    if (buttons.size() == 0
    or not is_visible_in_tree()):
        scrollbar_visual.hide()
        return

    selected_button = buttons[index]
    if not is_instance_valid(selected_button):
        return

    selected_button.grab_focus()

    for i in range(buttons.size()):
        _buttons_count[i] -= delta
        if _buttons_count[i] < 0:
            var target_position := Vector2(margin_x, i * button_spacing + _scroll)
            if i == 0:
                target_position.y = _scroll

            if is_instance_valid(buttons[i]):
                buttons[i].position = buttons[i].position.lerp(target_position, delta * 20)

    scrollbar_visual.show()
    scrollbar_visual.position.y = lerp(scrollbar_visual.position.y, 2 + (float(index) / float(buttons.size() - 1)) * 188.00, 0.1) if buttons.size() > 1 else 2
    scrollbar_visual.position.y = clamp(scrollbar_visual.position.y, 2, SCROLLBAR_BOTTOM)

    _current_mouse_input_cooldown -= delta
    if _current_mouse_input_cooldown < 0:
        _current_mouse_input_cooldown = 0

func _handle_button_focus(focused_button: Control) -> void:
    if _current_mouse_input_cooldown > 0:
        return

    index = buttons.find(focused_button)

    # New signal for hovering: used for moving the camera to the target in the inventory screen
    for id in item_button_map.keys():
        if item_button_map[id] == focused_button:
            item_button_hovered.emit(item_inventory.get_item(id))
            break

    update_labels()

func _handle_button_pressed(pressed_button: InventoryItemButtonPaint) -> void:
    for item_id in item_button_map.keys():
        if item_button_map[item_id] == pressed_button:
            item_button_pressed.emit(item_inventory.get_item(item_id))
            return

func _delete_button(to_delete: InventoryItemButtonPaint) -> void:
    to_delete.mouse_entered.disconnect(_handle_button_focus.bind(to_delete))
    to_delete.pressed_item.disconnect(_handle_button_pressed)

    var delete_index := buttons.find(to_delete)
    buttons.remove_at(delete_index)
    _buttons_count.erase(delete_index)
    to_delete.queue_free()

    # go back one index to keep the same index
    if index > 0:
        update_index(-1, false, true)

func delete_all_buttons() -> void:
    for btn in buttons:
        if btn is InventoryItemButtonPaint:
            btn.queue_free()
    buttons.clear()
    _buttons_count.clear()
    item_button_map.clear()

    index = 0
    _scroll = 1
    _current_mouse_input_cooldown = 0