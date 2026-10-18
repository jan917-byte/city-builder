extends PanelContainer
## 🎯 Les objectifs, en bas à gauche (auteur, 2026-10-18, « comme Frostpunk ») : le BUT,
## jamais le moyen — le guide garde « où cliquer ». Un objectif atteint se remplit, monte
## et s'efface ; il vaut un point de recherche (`Recherche.gains`). 🔴 Textes flaggables (90).

## L'ordre est celui de la partie ; un objectif atteint le reste (`ville._objectifs`).
## 🌳 Après les quatre de l'ouverture, un par action de l'institut : il paraît quand
## elle est achetée, et la faire une fois rend un des points qu'elle a coûtés.
const OBJECTIFS := {
	"abriter": "Abriter tout le monde",
	"pont": "Rouvrir un pont",
	"ilot": "Rebâtir un premier îlot",
	"logements": "Rebâtir les logements",
	"densifier": "Densifier un îlot",
	"berge": "Rendre une berge à l'Ilse",
	"pre": "Laisser un pré déborder",
	"permeable": "Rendre un parking perméable",
	"vert": "Verdir un toit plat",
	"solaire": "Poser des panneaux solaires",
	"rue": "Fermer une rue ou retirer des places",
	"arbres": "Planter des arbres",
}
const OUVERTURE := ["abriter", "pont", "ilot", "logements"]
const LIGNE := 30.0
const LARGEUR := 260.0
const SUIVANT_ALPHA := 0.45
const REMPLIR_S := 0.5
const TENIR_S := 0.9   # le cercle plein reste en place avant de monter
const MONTER_S := 0.6

var jeu
var _scene: Control
## id -> la ligne à l'écran ; une ligne qui monte n'y est plus.
var _lignes := {}


class Cercle extends Control:
	var encre := Color.WHITE
	var plein := Color.GREEN
	var remplissage := 0.0:
		set(v):
			remplissage = v
			queue_redraw()

	func _draw() -> void:
		var c := size / 2.0
		if remplissage > 0.0:
			draw_circle(c, 8.0 * remplissage, plein)
		draw_arc(c, 8.0, 0.0, TAU, 32, plein if remplissage >= 1.0 else encre, 2.0, true)


func batir(maquette) -> void:
	jeu = maquette
	var ui = jeu.interface
	name = "Objectifs"
	ui._poser_histoire(self)
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = 16
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scene = Control.new()
	_scene.clip_contents = true
	_scene.custom_minimum_size = Vector2(LARGEUR, 2.0 * LIGNE)
	_scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scene)
	ui.add_child(self)


## Les objectifs pas encore atteints qui ont paru, dans l'ordre. Fonction de la ville seule.
func _restants() -> Array:
	var out := []
	for id in OBJECTIFS:
		if not jeu.ville._objectifs.has(id) and paru(id):
			out.append(id)
	return out


## Ceux de l'ouverture tout de suite ; une action, une fois achetée à l'institut.
func paru(id: String) -> bool:
	return id in OUVERTURE or float(jeu.ville._recherche.get(id, INF)) <= jeu.mois


func atteint(id: String) -> bool:
	var v = jeu.ville
	var t: float = jeu.mois
	match id:
		"abriter":
			return v.sans_toit(t) < 0.5
		"pont":
			for p in v.ponts_coupes():
				if jeu.trafic.pont_fonctionnel(p, t):
					return true
			return false
		"ilot":
			return _rebatis() > 0
		"logements":
			return _rebatis() == _sinistres()
		"berge":
			return float(v._premieres.get("berge", INF)) <= t
		"vert":
			return float(v._premieres.get("toit vert", INF)) <= t
		"permeable":
			return float(v._premieres.get("sol perméable", INF)) <= t
		"pre":
			for fid in v._cultures:
				if float(v.CULTURES[v.champ_culture(fid, t)]["crue_m_ha"]) > 0.0 and not v.culture_en_cours(fid, t):
					return true
			return false
		"solaire":
			return _livre(v._solaire, t)
		"densifier":
			return _livre(v._dense, t)
		"arbres":
			return _livre(v._plantation, t)
		"rue":
			for fid in v._stationnement_supprime:
				if float(v._stationnement_supprime[fid]) <= t:
					return true
			return not jeu.trafic.exporter_fermetures().is_empty()
	return false


## Un chantier de cette table livré au mois `t` (`debut` + `duree`).
func _livre(chantiers: Dictionary, t: float) -> bool:
	for fid in chantiers:
		if float(chantiers[fid]["debut"]) + float(chantiers[fid]["duree"]) <= t:
			return true
	return false


func _sinistres() -> int:
	var n := 0
	for fid in jeu.ville.ilots:
		if jeu.ville.base("i", fid, "logements_sinistres") > 0.0:
			n += 1
	return n


func _rebatis() -> int:
	var n := 0
	for fid in jeu.ville.ilots:
		if jeu.ville.base("i", fid, "logements_sinistres") > 0.0 \
				and jeu.ville.reparation_finie("i", fid, jeu.mois):
			n += 1
	return n


func _texte(id: String) -> String:
	if id == "logements":
		return "%s (%d sur %d)" % [OBJECTIFS[id], _rebatis(), _sinistres()]
	return OBJECTIFS[id]


## Appelé par le guide à chaque actualisation : l'objectif courant se vérifie, une ligne par
## objectif s'anime. Un seul à la fois : le suivant attend que le premier soit monté.
func actualiser() -> void:
	var ui = jeu.interface
	# Caché pendant le récit, comme les compteurs ; au-dessus des boutons de caméra.
	visible = ui._menu_panneau.visible and not _restants().is_empty() or _scene.get_child_count() > _lignes.size()
	offset_bottom = -16.0 - ui._camera_panneau.size.y - 10.0
	var restants := _restants()
	var attente := 0.0
	# 🌳 Les actions se font dans l'ordre du joueur : le premier atteint, pas le premier listé.
	var fait := ""
	for id in restants:
		if atteint(id):
			fait = id
			break
	if fait != "" and visible:
		var id: String = fait
		jeu.ville._objectifs[id] = jeu.mois
		ui.retours.consigner("Objectif atteint : %s. Un point de recherche." % OBJECTIFS[id], jeu.mois)
		_reussir(id)
		restants = _restants()
		attente = TENIR_S
	for k in _lignes.keys():
		if not k in restants:
			_lignes.erase(k)
	for i in mini(2, restants.size()):
		var id: String = restants[i]
		if not _lignes.has(id):
			_lignes[id] = _ligne(id, i, attente)
		var l: HBoxContainer = _lignes[id]
		(l.get_child(1) as Label).text = _texte(id)


func _ligne(id: String, rang: int, attente: float) -> HBoxContainer:
	var ui = jeu.interface
	var l := HBoxContainer.new()
	l.add_theme_constant_override("separation", 10)
	l.size = Vector2(LARGEUR, LIGNE)
	var c := Cercle.new()
	c.custom_minimum_size = Vector2(20, LIGNE)
	c.encre = ui.ENCRE_HISTOIRE
	c.plein = ui.FAIT
	l.add_child(c)
	var t: Label = ui._label(_texte(id), 15, ui.ENCRE_HISTOIRE)
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	t.custom_minimum_size.y = LIGNE
	l.add_child(t)
	_scene.add_child(l)
	# Le nouveau suivant entre par le bas, pâle.
	l.position = Vector2(0, LIGNE * (rang + 1))
	l.modulate.a = 0.0
	_glisser(l, rang, attente)
	return l


func _glisser(l: Control, rang: int, attente: float) -> void:
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position:y", LIGNE * rang, MONTER_S).set_delay(attente)
	tw.tween_property(l, "modulate:a", 1.0 if rang == 0 else SUIVANT_ALPHA, MONTER_S).set_delay(attente)


## Le cercle se remplit, le point monte sous le compteur, la ligne monte et s'efface ;
## la suivante prend sa place.
func _reussir(id: String) -> void:
	var ui = jeu.interface
	var l: HBoxContainer = _lignes.get(id)
	_lignes.erase(id)
	if l == null:
		# Hors des deux lignes montrées : le point se dit quand même.
		ui.bulles.sous(ui._barre_valeurs.get("recherche"), "+1", "recherche", ui.FAIT_TEXTE)
		return
	(l.get_child(1) as Label).text = _texte(id)
	var tw := create_tween()
	tw.tween_property(l.get_child(0), "remplissage", 1.0, REMPLIR_S)
	tw.tween_callback(func() -> void:
		ui.bulles.sous(ui._barre_valeurs.get("recherche"), "+1", "recherche", ui.FAIT_TEXTE))
	tw.tween_interval(TENIR_S - REMPLIR_S)
	tw.set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(l, "position:y", -LIGNE, MONTER_S)
	tw.tween_property(l, "modulate:a", 0.0, MONTER_S)
	tw.chain().tween_callback(l.queue_free)
	for k in _lignes:
		_glisser(_lignes[k], 0, TENIR_S)
