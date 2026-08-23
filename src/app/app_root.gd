class_name AppRoot
extends Node

const EventDefinitionScript = preload("res://src/events/event_definition.gd")
const FixedTickEventCommandScript = preload("res://src/events/fixed_tick_event_command.gd")
const WorkplaceEventRuntimeScript = preload("res://src/events/workplace_event_runtime.gd")

signal mode_changed(mode: StringName)

const DEFAULT_CAMPAIGN_SAVE_PATH := "user://dungeon_union/campaign.save"

@export var content_catalog: ContentCatalog
@export var event_seed := 0
@export var campaign_save_path := DEFAULT_CAMPAIGN_SAVE_PATH
@export var recover_campaign_on_startup := true

var current_mode: StringName = &"boot"
var active_catalog: ContentCatalog
var boot_errors: Array[String] = []
var event_runtime: WorkplaceEventRuntimeScript
var accessibility_settings := AccessibilitySettings.new()


func _ready() -> void:
    boot()
    if has_node("TitleScreen"):
        $TitleScreen.continue_requested.connect(func() -> void: begin_shift(true))
        $TitleScreen.new_shift_requested.connect(func() -> void: begin_shift(false))
        $TitleScreen.accessibility_changed.connect(_apply_accessibility)
        $TitleScreen.set_accessibility(accessibility_settings)
    if has_node("WorkplaceView"):
        $WorkplaceView.hide()
    if active_catalog != null:
        change_mode(&"title")


func begin_shift(recover_campaign: bool) -> void:
    if active_catalog == null or not has_node("WorkplaceView"):
        return
    $WorkplaceView.configure(self, active_catalog, event_seed, _resolved_save_path(), recover_campaign)
    $WorkplaceView.show()
    if has_node("TitleScreen"):
        $TitleScreen.hide()
    change_mode(&"workplace")


func _resolved_save_path() -> String:
    var resolved_save_path := campaign_save_path
    var test_path_override := OS.get_environment("DUNGEON_UNION_SAVE_PATH")
    if campaign_save_path == DEFAULT_CAMPAIGN_SAVE_PATH and not test_path_override.is_empty():
        resolved_save_path = "" if test_path_override == "disabled" else test_path_override
    return resolved_save_path


func _apply_accessibility(settings: AccessibilitySettings) -> void:
    accessibility_settings = settings.normalized_copy()
    if has_node("TitleScreen"):
        $TitleScreen.set_accessibility(accessibility_settings)
    if has_node("WorkplaceView"):
        $WorkplaceView.apply_accessibility(accessibility_settings)


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


func event_progress_view() -> Dictionary:
    return event_runtime.durable_snapshot() if event_runtime != null else {}


func restore_event_progress(view: Dictionary) -> void:
    if event_runtime != null:
        event_runtime.restore_progress(view)

func change_mode(next_mode: StringName) -> void:
    if next_mode == current_mode:
        return
    current_mode = next_mode
    mode_changed.emit(current_mode)
