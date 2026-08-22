class_name AppRoot
extends Node

signal mode_changed(mode: StringName)

var current_mode: StringName = &"boot"

func change_mode(next_mode: StringName) -> void:
    if next_mode == current_mode:
        return
    current_mode = next_mode
    mode_changed.emit(current_mode)
