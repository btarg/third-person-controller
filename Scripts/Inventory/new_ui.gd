extends Control


func _ready() -> void:
    $"Inventory-01-stock".visible = true
    $"Inventory-02-item".visible = false
    $InfoBox.visible = true

func _input(event: InputEvent) -> void:
    if event is InputEventKey and not event.is_echo():
        if event.is_pressed() and event.keycode == KEY_P:
            $"Inventory-01-stock".visible = not $"Inventory-01-stock".visible
            $"Inventory-02-item".visible = not $"Inventory-02-item".visible
        elif event.is_pressed() and event.keycode == KEY_I:
            $InfoBox.visible = not $InfoBox.visible