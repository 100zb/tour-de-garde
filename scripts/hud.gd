extends CanvasLayer
class_name HUD
## Interface : sante, munitions, ferraille, etat de la vague, sante du relais,
## reticule, messages, et ecran de fin. Tout est construit en code.

var crosshair: Crosshair

var _health_bar: ProgressBar
var _health_label: Label
var _ammo_label: Label
var _reload_label: Label
var _scrap_label: Label
var _wave_label: Label
var _status_label: Label
var _relay_bar: ProgressBar
var _relay_label: Label
var _notice_label: Label
var _vignette: ColorRect
var _game_over: Control
var _game_over_details: Label

var _player: Player
var _relay: Relay
var _waves: WaveManager

func _ready() -> void:
	layer = 10
	_build()
	Game.notice.connect(show_notice)
	Game.scrap_changed.connect(_on_scrap_changed)

## Branche le HUD sur les objets de la scene. Appele par main.gd.
func bind(player: Player, relay: Relay, waves: WaveManager) -> void:
	_player = player
	_relay = relay
	_waves = waves

	player.health_changed.connect(_on_health_changed)
	player.ammo_changed.connect(_on_ammo_changed)
	player.shot_landed.connect(_on_shot_landed)
	relay.health_changed.connect(_on_relay_health_changed)
	waves.wave_started.connect(_on_wave_started)

	_on_scrap_changed(Game.scrap)

func _process(_delta: float) -> void:
	if _player != null and is_instance_valid(_player):
		crosshair.set_spread(_player.current_spread())
		_reload_label.visible = _player.is_reloading
		crosshair.visible = not _player.is_dead

	if _waves == null or not is_instance_valid(_waves):
		return

	if Game.state == Game.State.INTERMISSION:
		_status_label.text = "Entracte  %d s   (Entree pour lancer)" % ceili(maxf(0.0, _waves.intermission_left))
		_status_label.add_theme_color_override("font_color", Color(0.55, 0.9, 0.6))
	elif Game.state == Game.State.WAVE:
		var left := _waves.enemies_alive + _waves.enemies_pending
		_status_label.text = "Ennemis restants : %d" % left
		_status_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.45))

# ---------------------------------------------------------------- construction
#
# Note importante : on utilise partout set_anchors_AND_OFFSETS_preset().
# set_anchors_preset() seul conserve les marges existantes ; applique a un
# controle encore vide (taille 0), il le laisse a 0x0 dans un coin de l'ecran.

func _build() -> void:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_vignette = ColorRect.new()
	_vignette.color = Color(0.7, 0.05, 0.05, 0.0)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_vignette)
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	crosshair = Crosshair.new()
	root.add_child(crosshair)

	_build_top(root)
	_build_scrap(root)
	_build_bottom_left(root)
	_build_bottom_right(root)
	_build_notice(root)
	_build_game_over(root)

func _build_top(root: Control) -> void:
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_BEGIN
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_wave_label = _make_label("VAGUE 0", 26, Color(1.0, 0.85, 0.5))
	_wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_wave_label)

	_status_label = _make_label("Preparation...", 16, Color(0.8, 0.8, 0.85))
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_status_label)

	_relay_label = _make_label("RELAIS", 13, Color(0.5, 0.8, 1.0))
	_relay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_relay_label)

	_relay_bar = _make_bar(Color(0.3, 0.75, 1.0), Vector2(420, 14))
	# Barre centree au lieu d'etre etiree sur toute la largeur.
	_relay_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_relay_bar)

	root.add_child(column)
	column.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	column.offset_top = 16
	column.offset_bottom = 170

func _build_scrap(root: Control) -> void:
	_scrap_label = _make_label("0 ferraille", 20, Color(1.0, 0.8, 0.35))
	_scrap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(_scrap_label)
	_scrap_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_scrap_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_scrap_label.position += Vector2(-26, 20)

func _build_bottom_left(root: Control) -> void:
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_health_label = _make_label("SANTE  100", 13, Color(0.75, 0.75, 0.8))
	column.add_child(_health_label)

	_health_bar = _make_bar(Color(0.35, 0.85, 0.4), Vector2(280, 20))
	column.add_child(_health_bar)

	root.add_child(column)
	column.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	column.grow_horizontal = Control.GROW_DIRECTION_END
	column.grow_vertical = Control.GROW_DIRECTION_BEGIN
	column.position += Vector2(26, -26)

func _build_bottom_right(root: Control) -> void:
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_END
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_reload_label = _make_label("RECHARGEMENT", 15, Color(1.0, 0.6, 0.3))
	_reload_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_reload_label.visible = false
	column.add_child(_reload_label)

	_ammo_label = _make_label("30 / 30", 34, Color(1.0, 1.0, 1.0))
	_ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	column.add_child(_ammo_label)

	root.add_child(column)
	column.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	column.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	column.grow_vertical = Control.GROW_DIRECTION_BEGIN
	column.position += Vector2(-26, -26)

func _build_notice(root: Control) -> void:
	_notice_label = _make_label("", 24, Color(1.0, 0.9, 0.6))
	_notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice_label.modulate.a = 0.0
	root.add_child(_notice_label)
	_notice_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_notice_label.offset_top = 196
	_notice_label.offset_bottom = 236

func _build_game_over(root: Control) -> void:
	_game_over = Control.new()
	_game_over.visible = false
	root.add_child(_game_over)
	_game_over.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.05, 0.02, 0.02, 0.85)
	_game_over.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Un CenterContainer centre son contenu tout seul, quelle que soit la
	# resolution : bien plus fiable que de calculer une position a la main.
	var centerer := CenterContainer.new()
	_game_over.add_child(centerer)
	centerer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	centerer.add_child(column)

	var title := _make_label("RELAIS PERDU", 54, Color(1.0, 0.35, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(title)

	_game_over_details = _make_label("", 22, Color(0.9, 0.9, 0.95))
	_game_over_details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_game_over_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_game_over_details)

	var hint := _make_label("Entree : rejouer      Echap : quitter", 17, Color(0.7, 0.7, 0.75))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(hint)

func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _make_bar(color: Color, bar_size: Vector2) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = bar_size
	bar.show_percentage = false
	bar.max_value = 100.0
	bar.value = 100.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.05, 0.05, 0.07, 0.75)
	background.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", background)

	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill)

	return bar

# ------------------------------------------------------------------- reactions

func _on_health_changed(current: int, maximum: int) -> void:
	_health_bar.value = float(current) / float(maximum) * 100.0
	_health_label.text = "SANTE  %d" % current
	_pulse_vignette(1.0 - float(current) / float(maximum))

func _on_ammo_changed(in_magazine: int, magazine_size: int) -> void:
	_ammo_label.text = "%d / %d" % [in_magazine, magazine_size]
	_ammo_label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.4, 0.35) if in_magazine <= 5 else Color(1.0, 1.0, 1.0)
	)

func _on_scrap_changed(total: int) -> void:
	_scrap_label.text = "%d ferraille" % total

func _on_shot_landed(was_kill: bool) -> void:
	crosshair.flash_hit(was_kill)

func _on_relay_health_changed(current: int, maximum: int) -> void:
	var ratio := float(current) / float(maximum)
	_relay_bar.value = ratio * 100.0
	_relay_label.text = "RELAIS  %d / %d" % [current, maximum]

	var fill: StyleBoxFlat = _relay_bar.get_theme_stylebox("fill")
	if ratio < 0.25:
		fill.bg_color = Color(1.0, 0.3, 0.25)
	elif ratio < 0.55:
		fill.bg_color = Color(1.0, 0.7, 0.25)
	else:
		fill.bg_color = Color(0.3, 0.75, 1.0)

func _on_wave_started(wave: int) -> void:
	_wave_label.text = "VAGUE %d" % wave
	show_notice("Vague %d" % wave)

func show_notice(text: String) -> void:
	_notice_label.text = text
	_notice_label.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(1.4)
	tween.tween_property(_notice_label, "modulate:a", 0.0, 0.6)

func _pulse_vignette(intensity: float) -> void:
	_vignette.color.a = clampf(intensity * 0.35, 0.0, 0.45)

func show_game_over(wave: int, scrap: int) -> void:
	var wave_word := "vague" if wave <= 1 else "vagues"
	_game_over_details.text = "Tu as tenu %d %s et recolte %d ferraille." % [wave, wave_word, scrap]
	_game_over.visible = true
	_status_label.text = ""
	crosshair.visible = false
