class_name ContentCatalog
extends Resource

const EventDefinitionScript = preload("res://src/events/event_definition.gd")

@export var worker_items: Array[WorkerDefinition]
@export var job_items: Array[JobDefinition]
@export var workplace_items: Array[WorkplaceDefinition]
@export var event_items: Array[EventDefinitionScript]

var workers: Dictionary[StringName, WorkerDefinition] = {}
var jobs: Dictionary[StringName, JobDefinition] = {}
var workplaces: Dictionary[StringName, WorkplaceDefinition] = {}
var events: Dictionary[StringName, EventDefinitionScript] = {}


func rebuild_indexes() -> void:
    clear_indexes()

    for item in worker_items:
        if item != null and not item.id.is_empty():
            workers[item.id] = item
    for item in job_items:
        if item != null and not item.id.is_empty():
            jobs[item.id] = item
    for item in workplace_items:
        if item != null and not item.id.is_empty():
            workplaces[item.id] = item
    for item in event_items:
        if item != null and not item.id.is_empty():
            events[item.id] = item


func clear_indexes() -> void:
    workers.clear()
    jobs.clear()
    workplaces.clear()
    events.clear()
