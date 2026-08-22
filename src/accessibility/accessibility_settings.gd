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
