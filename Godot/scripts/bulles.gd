extends Control
## 🎈 Les chiffres qui montent (auteur, 2026-10-02) : la confiance au-dessus du lieu
## livré, la dépense sous la caisse à l'engagement. De l'affichage seul : rien ne
## se calcule ici, `retours.gd` dit quoi et où.

const DUREE := 2.6     # s
const MONTEE := 48.0   # px
const ECART := 0.7     # s entre deux bulles au même endroit : elles se suivent, pas l'une sur l'autre

var ui
var camera: Camera3D
## (couche, fid) -> Vector3 du dessus de l'objet, posé par la maquette.
var ancre_lieu: Callable
var _bulles := []   # {noeud, lieu: Vector3 | cible: Control, age}


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_preset(PRESET_FULL_RECT)
	set_process(false)


## Au-dessus d'un îlot, d'un champ ou d'une route.
func sur_lieu(couche: String, fid: int, texte: String, icone: String, couleur: Color) -> void:
	if not ancre_lieu.is_valid():
		return
	var p: Variant = ancre_lieu.call(couche, fid)
	if p is Vector3:
		_poser({"lieu": p}, texte, icone, couleur)


## Juste sous un compteur du haut.
func sous(cible: Control, texte: String, icone: String, couleur: Color) -> void:
	if cible != null:
		_poser({"cible": cible}, texte, icone, couleur)


func _poser(b: Dictionary, texte: String, icone: String, couleur: Color) -> void:
	var p := PanelContainer.new()
	p.mouse_filter = MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(ui.FOND, 0.9)
	sb.set_corner_radius_all(ui._r(6))
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 5)
	h.mouse_filter = MOUSE_FILTER_IGNORE
	p.add_child(h)
	var l: Label = ui._titre(texte, 18, couleur)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(l)
	if icone != "":
		var pic := TextureRect.new()
		pic.texture = ui._icone(icone, 20, couleur)
		pic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		pic.mouse_filter = MOUSE_FILTER_IGNORE
		h.add_child(pic)
	# 🐢 Porté par un Node2D : une Control s'arrondit au pixel, et 12 px en 2,6 s
	# sautaient alors un pixel tous les 0,2 s. Le Node2D glisse entre les pixels.
	var porteur := Node2D.new()
	porteur.modulate.a = 0.0
	porteur.add_child(p)
	add_child(porteur)
	# Au même endroit, la suivante attend que la précédente ait monté.
	var age := 0.0
	for autre in _bulles:
		if autre.get("lieu") == b.get("lieu") and autre.get("cible") == b.get("cible"):
			age = minf(age, float(autre["age"]) - ECART)
	b["noeud"] = porteur
	b["age"] = age
	_bulles.append(b)
	set_process(true)


func _process(delta: float) -> void:
	for b in _bulles.duplicate():
		b["age"] = float(b["age"]) + delta
		var p: Node2D = b["noeud"]
		var age: float = b["age"]
		if age >= DUREE:
			p.queue_free()
			_bulles.erase(b)
			continue
		var base := Vector2.INF
		if b.has("lieu"):
			if camera != null and not camera.is_position_behind(b["lieu"]):
				base = camera.unproject_position(b["lieu"])
		else:
			var c: Control = b["cible"]
			if is_instance_valid(c) and c.is_visible_in_tree():
				var r := c.get_global_rect()
				base = Vector2(r.get_center().x, r.end.y + 16.0)
		if age < 0.0 or base == Vector2.INF:
			p.modulate.a = 0.0
			continue
		var k := age / DUREE
		# Monte vite puis ralentit ; paraît en 0,15 s, s'efface sur le dernier tiers.
		var y := -MONTEE * (1.0 - pow(1.0 - k, 2.0))
		# Sous un compteur, elle descend peu : le bandeau des messages commence 30 px plus bas.
		if b.has("cible"):
			y = -y * 0.25
		var boite: PanelContainer = p.get_child(0)
		boite.reset_size()
		boite.position = (-boite.size * 0.5).round()
		p.position = base + Vector2(0.0, y)
		p.modulate.a = minf(age / 0.15, 1.0) * clampf((1.0 - k) * 3.0, 0.0, 1.0)
	set_process(not _bulles.is_empty())
