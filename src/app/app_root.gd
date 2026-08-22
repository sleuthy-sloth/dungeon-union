class_name AppRoot
extends Node

signal mode_changed(mode: StringName)

@export var content_catalog: ContentCatalog

var current_mode: StringName = &"boot"
var active_catalog: ContentCatalog
var boot_errors: Array[String] = []


func _ready() -> void:
    boot()


func boot() -> void:
    current_mode = &"boot"
    active_catalog = null
    boot_errors = []
    if content_catalog == null:
        content_catalog = ContentCatalog.new()

    content_catalog.clear_indexes()
    boot_errors = ContentValidator.validate(content_catalog)
    if not boot_errors.is_empty():
        current_mode = &"content_error"
        return

    content_catalog.rebuild_indexes()
    active_catalog = content_catalog

func change_mode(next_mode: StringName) -> void:
    if next_mode == current_mode:
        return
    current_mode = next_mode
    mode_changed.emit(current_mode)
