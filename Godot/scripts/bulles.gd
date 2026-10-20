extends Control
## 🎈 Les chiffres qui montent (auteur, 2026-10-02) : la confiance au-dessus du lieu
## livré, la dépense sous la caisse à l'engagement. De l'affichage seul : rien ne
## se calcule ici, `retours.gd` dit quoi et où.

const DUREE := 2.6     # s
const MONTEE := 48.0   # px
const ECART := 0.7     # s entre deux bulles au même endroit : elles se suivent, pas l'une sur l'autre

const PERTE := Color8(255, 72, 60)
const CONTOUR := 2     # px de noir autour du texte
const ENVOL := 0.8     # s : le gain se lit, puis son icône part vers le compteur
const VOLER_S := 0.8   # s, comme l'étoile des objectifs
## 🪙 Combien d'icônes volent : une par tranche, huit au plus (auteur, 2026-10-20 : « 2 M€, plusieurs pièces »).
const TRANCHE := {"caisse": 250.0, "capital": 10.0, "recherche": 1.0}
const ICONES_MAX := 8
const CADENCE := 0.08   # s entre deux icônes
const PARTIR := 0.25    # s : le « −80 k€ » paraît sous le compteur, puis les pièces en partent

## Ce qui vole encore : cle -> montant, positif vers le compteur, négatif pas encore parti.
## La barre le retranche (`actualiser_compteur`).
var en_vol := {}

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
func sur_lieu(couche: String, fid: int, texte: String, icone: String) -> void:
	if not ancre_lieu.is_valid():
		return
	var p: Variant = ancre_lieu.call(couche, fid)
	if p is Vector3:
		_poser({"lieu": p}, texte, icone)


## Juste sous un compteur du haut.
func sous(cible: Control, texte: String, icone: String) -> void:
	if cible != null:
		_poser({"cible": cible}, texte, icone)


## ✈️ Un gain rejoint son compteur, comme l'étoile des objectifs (auteur, 2026-10-20) : le chiffre
## monte là où il naît, puis son icône vole au compteur, qui n'avance qu'à l'arrivée.
func gain_lieu(couche: String, fid: int, cle: String, texte: String, montant: float) -> void:
	var p: Variant = ancre_lieu.call(couche, fid) if ancre_lieu.is_valid() else null
	if p is Vector3:
		_poser({"lieu": p, "vol": cle, "montant": montant}, texte, cle)
	else:
		gain_ecran(get_viewport_rect().size * 0.5, cle, texte, montant)


## Un gain sans lieu : il naît sur un bouton, ou au milieu de l'écran.
func gain_ecran(depart: Vector2, cle: String, texte: String, montant: float) -> void:
	_poser({"ecran": depart, "vol": cle, "montant": montant}, texte, cle)


## 💸 Une dépense décidée quelque part (auteur, 2026-10-20) : le chiffre rouge descend sous le
## compteur, et ses icônes en partent vers le lieu ; le compteur baisse à chaque départ.
func perte_lieu(couche: String, fid: int, cle: String, texte: String, montant: float) -> void:
	var p: Variant = ancre_lieu.call(couche, fid) if ancre_lieu.is_valid() else null
	sous(ui._barre_valeurs.get(cle), texte, "" if cle == "caisse" else cle)
	if p is Vector3:
		_perdre(cle, montant, _projeter.bind(p))


## Une dépense sans lieu sur la carte : ses icônes vont au bouton cliqué.
func perte_ecran(arrivee: Vector2, cle: String, texte: String, montant: float) -> void:
	sous(ui._barre_valeurs.get(cle), texte, "" if cle == "caisse" else cle)
	_perdre(cle, montant, func() -> Vector2: return arrivee)


func _projeter(p: Vector3) -> Vector2:
	if camera == null or camera.is_position_behind(p):
		return get_viewport_rect().size * Vector2(0.5, 1.1)
	return camera.unproject_position(p)


func _perdre(cle: String, montant: float, vers: Callable) -> void:
	var bloc := _bloc(cle)
	if bloc == null:
		return
	var icone: Vector2 = bloc.get_child(0).get_global_rect().get_center()
	_retenir(cle, -montant, false)
	_gerbe(ui._icone(cle, 20, Color.BLACK), cle, montant, func() -> Vector2:
		var b := _bloc(cle)
		return b.get_child(0).get_global_rect().get_center() if b != null else icone, vers, PARTIR, false)


func _poser(b: Dictionary, texte: String, icone: String) -> void:
	# 🔄 Plus de plaque de fond (auteur, 2026-10-20) : blanc si on gagne, rouge si on perd, cerné de noir ;
	# l'icône garde son aplat, seul son trait passe au noir.
	var couleur := PERTE if texte.begins_with("−") or texte.begins_with("-") else Color.WHITE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 5)
	h.mouse_filter = MOUSE_FILTER_IGNORE
	var l: Label = ui._titre(texte, 18, couleur)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_constant_override("outline_size", CONTOUR * 2)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	h.add_child(l)
	if icone != "":
		var pic := TextureRect.new()
		pic.texture = ui._icone(icone, 20, Color.BLACK)
		pic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		pic.mouse_filter = MOUSE_FILTER_IGNORE
		h.add_child(pic)
	# 🐢 Porté par un Node2D : une Control s'arrondit au pixel, et 12 px en 2,6 s
	# sautaient alors un pixel tous les 0,2 s. Le Node2D glisse entre les pixels.
	var porteur := Node2D.new()
	porteur.modulate.a = 0.0
	porteur.add_child(h)
	add_child(porteur)
	# Au même endroit, la suivante attend que la précédente ait monté.
	var age := 0.0
	for autre in _bulles:
		if autre.get("lieu") == b.get("lieu") and autre.get("cible") == b.get("cible") \
				and autre.get("ecran") == b.get("ecran"):
			age = minf(age, float(autre["age"]) - ECART)
	b["noeud"] = porteur
	b["age"] = age
	_bulles.append(b)
	if b.has("vol"):
		_retenir(b["vol"], b["montant"], false)
	set_process(true)


func _process(delta: float) -> void:
	for b in _bulles.duplicate():
		b["age"] = float(b["age"]) + delta
		var p: Node2D = b["noeud"]
		var age: float = b["age"]
		if age >= DUREE:
			if b.has("vol"):
				_retenir(b["vol"], -b["montant"], false)
			p.queue_free()
			_bulles.erase(b)
			continue
		var base := Vector2.INF
		if b.has("lieu"):
			if camera != null and not camera.is_position_behind(b["lieu"]):
				base = camera.unproject_position(b["lieu"])
		elif b.has("ecran"):
			base = b["ecran"]
		else:
			var c: Control = b["cible"]
			if is_instance_valid(c) and c.is_visible_in_tree():
				var r := c.get_global_rect()
				base = Vector2(r.get_center().x, r.end.y + 16.0)
		if age < 0.0 or base == Vector2.INF:
			p.modulate.a = 0.0
			# ⚠️ Hors champ, le compteur avance quand même : un gain jamais arrivé le fausserait.
			if age >= ENVOL and b.has("vol"):
				_retenir(b["vol"], -b["montant"], false)
				b.erase("vol")
			continue
		var k := age / DUREE
		# Monte vite puis ralentit ; paraît en 0,15 s, s'efface sur le dernier tiers.
		var y := -MONTEE * (1.0 - pow(1.0 - k, 2.0))
		# Sous un compteur, elle descend peu : le bandeau des messages commence 30 px plus bas.
		if b.has("cible"):
			y = -y * 0.25
		var boite: Control = p.get_child(0)
		boite.reset_size()
		boite.position = (-boite.size * 0.5).round()
		p.position = base + Vector2(0.0, y)
		p.modulate.a = minf(age / 0.15, 1.0) * clampf((1.0 - k) * 3.0, 0.0, 1.0)
		if age >= ENVOL and b.has("vol"):
			var pic: TextureRect = boite.get_child(1)
			_voler(pic.texture, p.position + boite.position + pic.position + pic.size * 0.5, b["vol"], b["montant"])
			pic.modulate.a = 0.0
			b.erase("vol")
	set_process(not _bulles.is_empty())


func _bloc(cle: String) -> Control:
	var l: Control = ui._barre_valeurs.get(cle)
	return l.get_parent() if l != null and l.is_visible_in_tree() else null


func _voler(texture: Texture2D, depart: Vector2, cle: String, montant: float) -> void:
	if _bloc(cle) == null:
		_retenir(cle, -montant, false)
		return
	_gerbe(texture, cle, montant, func() -> Vector2: return depart, func() -> Vector2:
		var b := _bloc(cle)
		return b.get_child(0).get_global_rect().get_center() if b != null else depart, 0.0, true)


## La trajectoire de l'étoile des objectifs (`objectifs.gd`) ; les deux bouts se relisent (la caméra bouge).
## Chaque icône porte sa part : le compteur bouge par à-coups, une icône à la fois — à l'arrivée
## d'un gain, au départ d'une dépense.
func _gerbe(texture: Texture2D, cle: String, montant: float, de: Callable, vers: Callable,
		attente: float, gain: bool) -> void:
	var n := clampi(ceili(absf(montant) / float(TRANCHE.get(cle, INF)) - 0.001), 1, ICONES_MAX)
	for i in n:
		var f := Sprite2D.new()
		f.texture = texture
		f.visible = false
		ui.add_child(f)
		# En gerbe côté lieu (angle d'or : jamais deux au même endroit), et des arcs un peu différents.
		var ecart := Vector2.from_angle(i * 2.4) * (0.0 if i == 0 else 14.0)
		var bosse := (float(i % 3) - 1.0) * 24.0
		var tw := f.create_tween()
		tw.tween_interval(attente + i * CADENCE)
		tw.tween_callback(func() -> void:
			f.show()
			if not gain:
				_retenir(cle, montant / n, true))
		tw.tween_method(func(t: float) -> void:
			var a: Vector2 = de.call() + (ecart if gain else Vector2.ZERO)
			var b: Vector2 = vers.call() + (Vector2.ZERO if gain else ecart)
			var haut := Vector2(lerpf(a.x, b.x, 0.3) + bosse, minf(a.y, b.y) + 0.35 * absf(b.y - a.y))
			var u := 1.0 - t
			f.position = u * u * a + 2.0 * u * t * haut + t * t * b
			f.scale = Vector2.ONE * lerpf(1.0, 1.3, sin(t * PI)) * (1.0 if gain else 1.0 - 0.4 * t * t)
			f.modulate.a = 1.0 if gain else clampf((1.0 - t) * 5.0, 0.0, 1.0),
			0.0, 1.0, VOLER_S).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_callback(func() -> void:
			f.queue_free()
			if gain:
				_retenir(cle, -montant / n, true))


## `delta` s'ajoute à ce qui vole encore ; le compteur se relit.
func _retenir(cle: String, delta: float, bondir: bool) -> void:
	en_vol[cle] = float(en_vol.get(cle, 0.0)) + delta
	if absf(en_vol[cle]) < 0.001:
		en_vol.erase(cle)
	ui.actualiser_compteur(cle)
	var bloc := _bloc(cle)
	if bondir and bloc != null:
		bloc.pivot_offset = bloc.size / 2.0
		bloc.scale = Vector2.ONE * 1.3
		bloc.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT) \
			.tween_property(bloc, "scale", Vector2.ONE, 0.35)
