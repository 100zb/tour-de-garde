extends Control
## Menu principal : premier ecran affiche au lancement, avant d'entrer dans
## la partie. Construit en code comme le reste de l'UI (voir shop.gd), meme
## identite visuelle (panneau sombre, bordure orange). Le bouton "Options"
## bascule vers un second panneau (memes principe que la boutique en jeu :
## un seul ecran, on montre/cache selon le contexte).

var _main_panel: PanelContainer
var _options_panel: PanelContainer
var _sensitivity_value_label: Label

func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build()

func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_gradient_background())

	var centerer := CenterContainer.new()
	add_child(centerer)
	centerer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_main_panel = _build_main_panel()
	centerer.add_child(_main_panel)

	_options_panel = _build_options_panel()
	_options_panel.visible = false
	centerer.add_child(_options_panel)

func _build_main_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	panel.add_theme_stylebox_override("panel", _panel_style())

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)

	var title := Label.new()
	title.text = "TOUR DE GARDE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.45))
	column.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Defends le relais au milieu du desert."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	column.add_child(subtitle)

	column.add_child(HSeparator.new())

	var play_button := Button.new()
	play_button.text = "Jouer"
	play_button.custom_minimum_size = Vector2(0, 48)
	play_button.add_theme_font_size_override("font_size", 20)
	_style_button(play_button, Color(1.0, 0.72, 0.3, 0.9))
	play_button.pressed.connect(_on_play_pressed)
	column.add_child(play_button)

	var options_button := Button.new()
	options_button.text = "Options"
	options_button.custom_minimum_size = Vector2(0, 40)
	_style_button(options_button, Color(0.45, 0.55, 0.65, 0.9))
	options_button.pressed.connect(_on_options_pressed)
	column.add_child(options_button)

	var quit_button := Button.new()
	quit_button.text = "Quitter"
	quit_button.custom_minimum_size = Vector2(0, 40)
	_style_button(quit_button, Color(0.4, 0.4, 0.46, 0.9))
	quit_button.pressed.connect(_on_quit_pressed)
	column.add_child(quit_button)

	return panel

func _build_options_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	panel.add_theme_stylebox_override("panel", _panel_style())

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)

	var title := Label.new()
	title.text = "OPTIONS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.45))
	column.add_child(title)

	column.add_child(HSeparator.new())

	# ----------------------------------------------------- sensibilite souris
	var sensitivity_row := HBoxContainer.new()
	sensitivity_row.add_theme_constant_override("separation", 10)
	column.add_child(sensitivity_row)

	var sensitivity_label := Label.new()
	sensitivity_label.text = "Sensibilite souris"
	sensitivity_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sensitivity_row.add_child(sensitivity_label)

	_sensitivity_value_label = Label.new()
	_sensitivity_value_label.text = "%.2fx" % Game.mouse_sensitivity
	_sensitivity_value_label.custom_minimum_size = Vector2(50, 0)
	sensitivity_row.add_child(_sensitivity_value_label)

	var sensitivity_slider := HSlider.new()
	sensitivity_slider.min_value = Game.MIN_MOUSE_SENSITIVITY
	sensitivity_slider.max_value = Game.MAX_MOUSE_SENSITIVITY
	sensitivity_slider.step = 0.05
	sensitivity_slider.value = Game.mouse_sensitivity
	sensitivity_slider.custom_minimum_size = Vector2(0, 24)
	sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	sensitivity_slider.drag_ended.connect(_on_sensitivity_drag_ended)
	column.add_child(sensitivity_slider)

	column.add_child(HSeparator.new())

	# ------------------------------------------------------------ plein ecran
	var fullscreen_row := HBoxContainer.new()
	fullscreen_row.add_theme_constant_override("separation", 10)
	column.add_child(fullscreen_row)

	var fullscreen_label := Label.new()
	fullscreen_label.text = "Plein ecran"
	fullscreen_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fullscreen_row.add_child(fullscreen_label)

	var fullscreen_check := CheckButton.new()
	fullscreen_check.button_pressed = Game.fullscreen
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	fullscreen_row.add_child(fullscreen_check)

	column.add_child(HSeparator.new())

	var back_button := Button.new()
	back_button.text = "Retour"
	back_button.custom_minimum_size = Vector2(0, 40)
	_style_button(back_button, Color(0.4, 0.4, 0.46, 0.9))
	back_button.pressed.connect(_on_back_pressed)
	column.add_child(back_button)

	return panel

## Degrade violet -> orange, memes couleurs que le ciel en jeu (Phase 6).
func _gradient_background() -> TextureRect:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.32, 0.24, 0.34))
	gradient.set_color(1, Color(0.95, 0.58, 0.32))

	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	texture.width = 2
	texture.height = 256

	var rect := TextureRect.new()
	rect.texture = texture
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return rect

## Donne un cadre visible a un bouton (le theme par defaut est trop discret
## sur un fond sombre) : bordure pleine au repos, remplie au survol.
func _style_button(button: Button, accent: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(accent.r, accent.g, accent.b, 0.12)
	normal.border_color = accent
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(4)
	button.add_theme_stylebox_override("normal", normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(accent.r, accent.g, accent.b, 0.32)
	hover.border_color = accent
	hover.set_border_width_all(2)
	hover.set_corner_radius_all(4)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.09, 0.12, 0.97)
	style.border_color = Color(1.0, 0.72, 0.3, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(28)
	return style

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_options_pressed() -> void:
	_main_panel.visible = false
	_options_panel.visible = true

func _on_back_pressed() -> void:
	_options_panel.visible = false
	_main_panel.visible = true

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_sensitivity_changed(value: float) -> void:
	Game.set_mouse_sensitivity(value)
	_sensitivity_value_label.text = "%.2fx" % value

## Sauvegarde sur disque uniquement au relachement du curseur, pas a
## chaque increment pendant le glissement (evite de spammer le disque).
func _on_sensitivity_drag_ended(_value_changed: bool) -> void:
	Game.save_settings()

func _on_fullscreen_toggled(pressed: bool) -> void:
	Game.set_fullscreen(pressed)
