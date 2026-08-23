class_name TitleScreen
extends Control

signal continue_requested
signal new_shift_requested
signal accessibility_changed(settings: AccessibilitySettings)

var _settings := AccessibilitySettings.new()


func _ready() -> void:
	var key_art := Image.load_from_file(ProjectSettings.globalize_path("res://assets/title/dungeon-union-bone-and-pick-key-art-v1.png"))
	if not key_art.is_empty():
		$KeyArt.texture = ImageTexture.create_from_image(key_art)
	$ContinueShift.pressed.connect(func() -> void: continue_requested.emit())
	$NewShift.pressed.connect(func() -> void: new_shift_requested.emit())
	$Accessibility.pressed.connect(_toggle_accessibility)
	$AccessibilityDrawer/ReducedMotion.toggled.connect(_set_reduced_motion)
	$AccessibilityDrawer/HighContrast.toggled.connect(_set_high_contrast)
	$AccessibilityDrawer/ReadableFont.toggled.connect(_set_readable_font)
	$AccessibilityDrawer/UIScale.value_changed.connect(_set_ui_scale)
	set_accessibility(_settings)


func set_accessibility(settings: AccessibilitySettings) -> void:
	_settings = settings.normalized_copy()
	$AccessibilityDrawer/ReducedMotion.button_pressed = _settings.reduced_motion
	$AccessibilityDrawer/HighContrast.button_pressed = _settings.high_contrast
	$AccessibilityDrawer/ReadableFont.button_pressed = _settings.dyslexia_friendly_font
	$AccessibilityDrawer/UIScale.value = _settings.ui_scale
	var readable_font := SystemFont.new()
	readable_font.font_names = PackedStringArray(["Atkinson Hyperlegible", "Avenir Next", "Arial"] if _settings.dyslexia_friendly_font else ["Avenir Next", "Helvetica Neue", "Arial"])
	for control in [$ContinueShift, $NewShift, $Accessibility, $AccessibilityDrawer/ReducedMotion, $AccessibilityDrawer/HighContrast, $AccessibilityDrawer/ReadableFont]:
		control.add_theme_font_override("font", readable_font)
		control.add_theme_font_size_override("font_size", maxi(14, int(18.0 * _settings.ui_scale)))
	$Scrim.color = Color("0b1114", 0.54 if _settings.high_contrast else 0.38)
	$Masthead.modulate = Color("ffffff") if _settings.high_contrast else Color("e8d9b5")


func _toggle_accessibility() -> void:
	$AccessibilityDrawer.visible = not $AccessibilityDrawer.visible


func _set_reduced_motion(value: bool) -> void:
	_settings.reduced_motion = value
	_publish_settings()


func _set_high_contrast(value: bool) -> void:
	_settings.high_contrast = value
	_publish_settings()


func _set_readable_font(value: bool) -> void:
	_settings.dyslexia_friendly_font = value
	_publish_settings()


func _set_ui_scale(value: float) -> void:
	_settings.ui_scale = value
	_publish_settings()


func _publish_settings() -> void:
	set_accessibility(_settings)
	accessibility_changed.emit(_settings.normalized_copy())
