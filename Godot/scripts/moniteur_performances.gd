extends CanvasLayer
## Le thermomètre de la maquette, visible avec F3. Rafraîchi 4×/s : assez pour
## voir une chute, sans fausser ce qu'on mesure.

const INTERVALLE := 0.25
const OCTETS_PAR_MIO := 1024.0 * 1024.0

var _etiquette: Label
var _fermer: Button
var _attente := 0.0


func batir(visible_au_depart: bool = true) -> void:
	layer = 100

	var panneau := PanelContainer.new()
	panneau.name = "Performances"
	panneau.anchor_left = 0.5
	panneau.anchor_right = 0.5
	panneau.offset_left = -190.0
	panneau.offset_right = 190.0
	panneau.offset_top = 16.0
	panneau.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var fond := StyleBoxFlat.new()
	fond.bg_color = Color(0.035, 0.045, 0.055, 0.90)
	fond.border_color = Color(0.30, 0.36, 0.40, 0.9)
	fond.set_border_width_all(1)
	fond.set_corner_radius_all(5)
	fond.content_margin_left = 12.0
	fond.content_margin_right = 12.0
	fond.content_margin_top = 8.0
	fond.content_margin_bottom = 8.0
	panneau.add_theme_stylebox_override("panel", fond)
	add_child(panneau)

	_etiquette = Label.new()
	_etiquette.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_etiquette.add_theme_font_size_override("font_size", 14)
	_etiquette.add_theme_color_override("font_color", Color(0.88, 0.91, 0.92))
	panneau.add_child(_etiquette)

	# Posee sur la couche, pas dans le panneau : le PanelContainer n'accepte
	# qu'un enfant, et une croix logee dedans decalerait le texte centre.
	_fermer = Button.new()
	_fermer.name = "Fermer"
	_fermer.text = "✕"
	_fermer.flat = true
	_fermer.focus_mode = Control.FOCUS_NONE
	_fermer.tooltip_text = "Masquer les performances (F3)"
	_fermer.anchor_left = 0.5
	_fermer.anchor_right = 0.5
	_fermer.offset_left = 158.0
	_fermer.offset_right = 182.0
	_fermer.offset_top = 20.0
	_fermer.offset_bottom = 44.0
	_fermer.add_theme_font_size_override("font_size", 13)
	_fermer.add_theme_color_override("font_color", Color(0.62, 0.68, 0.72))
	_fermer.add_theme_color_override("font_hover_color", Color(1.0, 0.72, 0.68))
	_fermer.pressed.connect(func() -> void: visible = false)
	add_child(_fermer)

	visible = visible_au_depart
	_rafraichir()


func basculer() -> void:
	visible = not visible
	if visible:
		_rafraichir()


func _process(delta: float) -> void:
	if not visible:
		return
	_attente += delta
	if _attente >= INTERVALLE:
		_attente = fmod(_attente, INTERVALLE)
		_rafraichir()


func _rafraichir() -> void:
	if _etiquette == null:
		return
	var ips := float(Performance.get_monitor(Performance.TIME_FPS))
	var image_ms := 1000.0 / ips if ips > 0.0 else 0.0
	var cpu_ms := 1000.0 * (
		float(Performance.get_monitor(Performance.TIME_PROCESS))
		+ float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)))
	var appels := int(Performance.get_monitor(
		Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var triangles := int(Performance.get_monitor(
		Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var noeuds := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var memoire_mio := float(Performance.get_monitor(
		Performance.MEMORY_STATIC)) / OCTETS_PAR_MIO
	var video_mio := float(Performance.get_monitor(
		Performance.RENDER_VIDEO_MEM_USED)) / OCTETS_PAR_MIO

	_etiquette.text = ("PERFORMANCES  ·  F3\n"
		+ "%d ips  ·  %.1f ms/image  ·  CPU %.1f ms\n"
		+ "%s triangles  ·  %s appels  ·  %s nœuds\n"
		+ "mémoire %.0f Mio  ·  vidéo %.0f Mio") % [
			roundi(ips), image_ms, cpu_ms,
			_nombre(triangles), _nombre(appels), _nombre(noeuds),
			memoire_mio, video_mio,
		]

	var couleur := Color(0.52, 0.88, 0.64)
	if ips < 30.0:
		couleur = Color(1.0, 0.42, 0.38)
	elif ips < 55.0:
		couleur = Color(1.0, 0.78, 0.35)
	_etiquette.add_theme_color_override("font_color", couleur)


func _nombre(valeur: int) -> String:
	var texte := str(valeur)
	var debut := texte.length() % 3
	if debut == 0:
		debut = 3
	var morceaux := [texte.left(debut)]
	var position := debut
	while position < texte.length():
		morceaux.append(texte.substr(position, 3))
		position += 3
	return " ".join(morceaux)
