class_name ContentValidator
extends RefCounted

const EventDefinitionScript = preload("res://src/events/event_definition.gd")


static func validate(catalog: ContentCatalog) -> Array[String]:
    var errors: Array[String] = []
    var worker_ids: Dictionary[StringName, bool] = {}
    var job_ids: Dictionary[StringName, bool] = {}
    var workplace_ids: Dictionary[StringName, bool] = {}
    var event_ids: Dictionary[StringName, bool] = {}

    for worker in catalog.worker_items:
        if worker == null or worker.id.is_empty():
            errors.append("worker has empty id")
        elif worker_ids.has(worker.id):
            errors.append("duplicate worker id: %s" % worker.id)
        else:
            worker_ids[worker.id] = true

    for job in catalog.job_items:
        if job == null or job.id.is_empty():
            errors.append("job has empty id")
        elif job_ids.has(job.id):
            errors.append("duplicate job id: %s" % job.id)
        else:
            job_ids[job.id] = true

    for workplace in catalog.workplace_items:
        if workplace == null or workplace.id.is_empty():
            errors.append("workplace has empty id")
        elif workplace_ids.has(workplace.id):
            errors.append("duplicate workplace id: %s" % workplace.id)
        else:
            workplace_ids[workplace.id] = true

    for event in catalog.event_items:
        if event == null or event.id.is_empty():
            errors.append("event has empty id")
        elif event_ids.has(event.id):
            errors.append("duplicate event id: %s" % event.id)
        else:
            event_ids[event.id] = true
        if event != null and event.family.is_empty():
            errors.append("event %s has empty family" % event.id)

    for worker in catalog.worker_items:
        if worker != null and not worker.job_id.is_empty() and not job_ids.has(worker.job_id):
            errors.append("worker %s references missing job id: %s" % [worker.id, worker.job_id])

    for workplace in catalog.workplace_items:
        if workplace == null or workplace.id.is_empty():
            continue
        for worker_id in workplace.worker_ids:
            if not worker_ids.has(worker_id):
                errors.append("workplace %s references missing worker id: %s" % [workplace.id, worker_id])
        for job_id in workplace.job_ids:
            if not job_ids.has(job_id):
                errors.append("workplace %s references missing job id: %s" % [workplace.id, job_id])
        var worker_tags: Dictionary[StringName, bool] = {}
        for worker_id in workplace.worker_ids:
            for worker in catalog.worker_items:
                if worker != null and worker.id == worker_id:
                    for worker_tag in worker.event_role_tags:
                        worker_tags[worker_tag] = true
                    break
        for event_id in workplace.event_ids:
            if not event_ids.has(event_id):
                errors.append("workplace %s references missing event id: %s" % [workplace.id, event_id])
                continue
            var event: EventDefinitionScript = _event_for(catalog, event_id)
            if event == null:
                continue
            if not event.issue.is_empty() and not workplace.dispute_ids.has(event.issue):
                errors.append("event %s references missing dispute id in workplace %s: %s" % [event.id, workplace.id, event.issue])
            for required_tag in event.required_worker_tags:
                if not worker_tags.has(required_tag):
                    errors.append("event %s requires unavailable worker role in workplace %s: %s" % [event.id, workplace.id, required_tag])

    return errors


static func _event_for(catalog: ContentCatalog, event_id: StringName) -> EventDefinitionScript:
    for event in catalog.event_items:
        if event != null and event.id == event_id:
            return event
    return null
