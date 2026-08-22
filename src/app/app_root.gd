class_name AppRoot
extends Node

const EventDefinitionScript = preload("res://src/events/event_definition.gd")
const FixedTickEventCommandScript = preload("res://src/events/fixed_tick_event_command.gd")
const WorkplaceEventRuntimeScript = preload("res://src/events/workplace_event_runtime.gd")

signal mode_changed(mode: StringName)

@export var content_catalog: ContentCatalog
@export var event_seed := 0

var current_mode: StringName = &"boot"
var active_catalog: ContentCatalog
var boot_errors: Array[String] = []
var event_runtime: WorkplaceEventRuntimeScript


func _ready() -> void:
    boot()
    if has_node("WorkplaceView") and active_catalog != null:
        $WorkplaceView.configure(self, active_catalog, event_seed)
        change_mode(&"workplace")


func boot() -> void:
    current_mode = &"boot"
    active_catalog = null
    event_runtime = null
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
    if not active_catalog.workplace_items.is_empty():
        event_runtime = WorkplaceEventRuntimeScript.new(
            active_catalog,
            active_catalog.workplace_items[0],
            event_seed
        )


func apply_fixed_tick(command: FixedTickEventCommandScript) -> EventDefinitionScript:
    if event_runtime == null:
        return null
    return event_runtime.apply_fixed_tick(command)


func complete_event(event_id: StringName) -> bool:
    if event_runtime == null:
        return false
    return event_runtime.complete_event(event_id)

func change_mode(next_mode: StringName) -> void:
    if next_mode == current_mode:
        return
    current_mode = next_mode
    mode_changed.emit(current_mode)
