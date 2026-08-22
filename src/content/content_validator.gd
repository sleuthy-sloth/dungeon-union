class_name ContentValidator
extends RefCounted


static func validate(catalog: ContentCatalog) -> Array[String]:
    var errors: Array[String] = []
    var worker_ids: Dictionary[StringName, bool] = {}
    var job_ids: Dictionary[StringName, bool] = {}
    var workplace_ids: Dictionary[StringName, bool] = {}

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

    return errors
