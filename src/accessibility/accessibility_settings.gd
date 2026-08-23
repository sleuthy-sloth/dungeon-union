class_name AccessibilitySettings
extends Resource

@export_range(0.75, 2.0, 0.05) var ui_scale := 1.0
@export var auto_pause_major_events := true
@export var reduced_motion := false
@export var high_contrast := false
@export var dyslexia_friendly_font := false


func normalized_copy() -> AccessibilitySettings:
	var copied := AccessibilitySettings.new()
	copied.ui_scale = clampf(snappedf(ui_scale, 0.05), 0.75, 2.0)
	copied.auto_pause_major_events = auto_pause_major_events
	copied.reduced_motion = reduced_motion
	copied.high_contrast = high_contrast
	copied.dyslexia_friendly_font = dyslexia_friendly_font
	return copied


func to_dictionary() -> Dictionary:
	var normalized := normalized_copy()
	return {
		"ui_scale": normalized.ui_scale,
		"auto_pause_major_events": normalized.auto_pause_major_events,
		"reduced_motion": normalized.reduced_motion,
		"high_contrast": normalized.high_contrast,
		"dyslexia_friendly_font": normalized.dyslexia_friendly_font,
	}


static func restore(view: Dictionary) -> AccessibilitySettings:
	var settings := AccessibilitySettings.new()
	settings.ui_scale = float(view.get("ui_scale", 1.0))
	settings.auto_pause_major_events = bool(view.get("auto_pause_major_events", true))
	settings.reduced_motion = bool(view.get("reduced_motion", false))
	settings.high_contrast = bool(view.get("high_contrast", false))
	settings.dyslexia_friendly_font = bool(view.get("dyslexia_friendly_font", false))
	return settings.normalized_copy()
