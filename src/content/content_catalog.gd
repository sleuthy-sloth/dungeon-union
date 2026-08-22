class_name ContentCatalog
extends Resource

@export var worker_items: Array[WorkerDefinition]
@export var job_items: Array[JobDefinition]
@export var workplace_items: Array[WorkplaceDefinition]

var workers: Dictionary[StringName, WorkerDefinition] = {}
var jobs: Dictionary[StringName, JobDefinition] = {}
var workplaces: Dictionary[StringName, WorkplaceDefinition] = {}


func rebuild_indexes() -> void:
    workers.clear()
    jobs.clear()
    workplaces.clear()

    for item in worker_items:
        if item != null and not item.id.is_empty():
            workers[item.id] = item
    for item in job_items:
        if item != null and not item.id.is_empty():
            jobs[item.id] = item
    for item in workplace_items:
        if item != null and not item.id.is_empty():
            workplaces[item.id] = item
