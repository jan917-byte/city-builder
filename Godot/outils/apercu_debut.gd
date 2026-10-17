extends "res://outils/essai_ouverture.gd"
## --script res://outils/apercu_debut.gd -- --ouverture
## Alléger le début : rejoue l'ouverture et numérote chaque élément visible de
## l'interface aux moments clés ; un élément garde son numéro d'un écran à l'autre.
## → QGIS/rendus/wehrau_debut_N_*.png + wehrau_debut_legende.md

const Bulles := preload("res://scripts/bulles.gd")
const MOMENTS := {
	"01_relogement": "1_urgence",
	"02_camp": "2_camp_livre",
	"09_decouvrir_chantiers": "3_rives_coupees",
	"10_comparer_ponts": "4_liste_des_ponts",
	"11_fiche_pont": "5_fiche_du_pont",
	"12d_chantiers_vers_la_ville": "6_vers_la_ville",
	"12b_chemin_degage": "7_chemin_degage",
	"14_pont_rouvert": "8_pont_rouvert",
}
var _numeros := {}    # instance_id -> n°
var _textes := {}     # n° -> {écran: texte}


## ⚠️ Fenêtre ouverte pour les captures : la vraie souris volait les clics simulés
## malgré le passthrough (Mac, 2026-10-13). On appuie donc sans souris.
func cliquer(b: Button) -> void:
	await process_frame
	await process_frame
	if b.toggle_mode:
		b.button_pressed = not b.button_pressed
	b.pressed.emit()
	await process_frame
	await process_frame


func capture(nom: String) -> void:
	if not MOMENTS.has(nom):
		return
	var ecran: String = MOMENTS[nom]
	# ⚠️ Artefacts de l'essai, absents d'une partie : l'avis d'une reprise vieille
	# de moins de 8 s réelles, et la caméra restée collée au treillis (13c).
	var r = jeu.interface.retours
	for m in r._recent.duplicate():
		if m.begins_with("Partie reprise"):
			r._recent.erase(m)
	r.actualiser_affichage()
	if nom == "14_pont_rouvert":
		jeu.pivot.viser(Vector2(jeu.pivot.position.x, jeu.pivot.position.z), 900.0)
	jeu._rafraichir(false)
	await process_frame
	await process_frame
	if r._recent.is_empty():
		r.avis.hide()   # sinon un cadre vide reste à l'écran
	var calque := CanvasLayer.new()
	calque.layer = 128
	root.add_child(calque)
	for e in _elements(root):
		var id: int = e.get_instance_id()
		if not _numeros.has(id):
			_numeros[id] = _numeros.size() + 1
		var n: int = _numeros[id]
		if not _textes.has(n):
			_textes[n] = {}
		_textes[n][ecran] = _decrire(e)
		_pastille(calque, e, n)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var chemin := "res://../QGIS/rendus/wehrau_debut_%s.png" % ecran
	verifier(root.get_texture().get_image().save_png(chemin) == OK, "Capture " + ecran)
	calque.queue_free()
	await process_frame
	_ecrire_legende()


## Ce que le joueur voit et peut viser : boutons, curseurs, textes, pastilles.
func _elements(n: Node) -> Array:
	var r := []
	if n is CanvasItem and not (n as CanvasItem).is_visible_in_tree():
		return r
	if n is Bulles:
		return r   # chiffres qui montent puis s'effacent : rien à barrer
	if n is Control:
		var c := n as Control
		var rect := c.get_global_rect()
		var dedans := rect.size.x > 4 and rect.size.y > 4 \
			and Rect2(Vector2.ZERO, Vector2(root.size)).intersects(rect)
		if dedans:
			if c is BaseButton or c is Range \
					or c.get_parent() == jeu.interface.retours.rangee:
				r.append(c)
				return r
			if (c is Label and (c as Label).text.strip_edges() != "") \
					or (c is RichTextLabel and (c as RichTextLabel).get_parsed_text().strip_edges() != ""):
				r.append(c)
	for enfant in n.get_children():
		r.append_array(_elements(enfant))
	return r


func _decrire(c: Control) -> String:
	var t := ""
	if c is Button:
		t = (c as Button).text
		if t == "" or t.length() < 3:
			t = (t + " " + c.tooltip_text).strip_edges()
	elif c is Label:
		t = (c as Label).text
	elif c is RichTextLabel:
		t = (c as RichTextLabel).get_parsed_text()
	elif c is Range:
		t = "curseur"
	elif c.get_parent() == jeu.interface.retours.rangee:
		t = "pastille d'alerte en bas : " + ("pont coupé" if c == jeu.interface.retours.ponts_casses
			else "sans logement" if c == jeu.interface.retours.sans_logement else "camp mécontent")
	t = t.replace("\n", " · ").replace("|", "/").strip_edges()
	if t.length() > 80:
		t = t.left(78) + "…"
	return t if t != "" else "(%s)" % c.name


func _ecrire_legende() -> void:
	var ecrans: Array = MOMENTS.values()
	var l := PackedStringArray(["# Le début, élément par élément", "",
		"Un numéro = un élément, le même sur toutes les images. ● = visible sur cet écran.", "",
		"| n° | " + " | ".join(ecrans.map(func(e): return e.left(1))) + " | ce qu'on y lit |",
		"|---|" + "---|".repeat(ecrans.size()) + "---|"])
	var ns: Array = _textes.keys()
	ns.sort()
	for n in ns:
		var vus: Dictionary = _textes[n]
		var cases := ecrans.map(func(e): return "●" if vus.has(e) else "")
		var dernier: String = vus[vus.keys()[-1]]
		l.append("| %d | %s | %s |" % [n, " | ".join(cases), dernier])
	var f := FileAccess.open("res://../QGIS/rendus/wehrau_debut_legende.md", FileAccess.WRITE)
	f.store_string("\n".join(l) + "\n")


func _pastille(calque: CanvasLayer, c: Control, n: int) -> void:
	var rect := c.get_global_rect()
	var l := Label.new()
	l.text = str(n)
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color.WHITE)
	var fond := StyleBoxFlat.new()
	fond.bg_color = Color(0.85, 0.1, 0.1)
	fond.set_corner_radius_all(7)
	fond.content_margin_left = 3
	fond.content_margin_right = 3
	l.add_theme_stylebox_override("normal", fond)
	calque.add_child(l)
	# Juste à gauche de l'élément, pour ne pas couvrir son texte.
	var largeur := l.get_minimum_size().x
	l.position = Vector2(maxf(rect.position.x - largeur - 1.0, 0.0), rect.position.y - 2.0)
