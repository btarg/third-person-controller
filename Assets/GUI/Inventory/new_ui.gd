extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    $"Inventory-01-stock".visible = true
    $"Inventory-02-item".visible = false
    $InfoBox.visible = true

func _input(event: InputEvent) -> void:
    if event is InputEventKey:
        if event.is_action_pressed("ui_select"):
            $"Inventory-01-stock".visible = not $"Inventory-01-stock".visible
            $"Inventory-02-item".visible = not $"Inventory-02-item".visible
        elif event.is_pressed() and event.keycode == KEY_I and not event.is_echo():
            $InfoBox.visible = not $InfoBox.visible