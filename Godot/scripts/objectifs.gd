extends PanelContainer
## 🎯 Les objectifs, en bas à gauche (auteur, 2026-10-18, « comme Frostpunk ») : le BUT,
## jamais le moyen — le guide garde « où cliquer ». Un objectif atteint se remplit et monte
## avec les atteints, pâlissant vers le haut ; il vaut un point de recherche (`Recherche.gains`). 🔴 Textes flaggables (90).

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
	"places": "Retirer des places",
	"rue": "Fermer une rue aux voitures",
	"arbres": "Planter des arbres",
}
const OUVERTURE := ["abriter", "pont", "ilot", "logements"]
const LIGNE := 24.0
const LARGEUR := 260.0
const MONTRES := 2   # le courant et le suivant
const GARDES := 3    # atteints gardés au-dessus (auteur, 2026-10-19)
const SUIVANT_ALPHA := 0.55
## Le plus récent des atteints, puis plus pâle à chaque rang vers le haut.
const ATTEINT_ALPHA := [0.45, 0.28, 0.15]
const REMPLIR_S := 0.5
const TENIR_S := 0.9   # le cercle plein reste en place avant de monter
const MONTER_S := 0.6
const VOLER_S := 0.8
## Le bleu du compteur de recherche, éclairci pour se lire sur la carte.
const BLEU := Color8(165, 192, 240)

var jeu
var _scene: Control
## id -> la ligne à l'écran, atteinte ou non ; une ligne qui s'efface n'y est plus.
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
		# Sans fond : un liseré sombre détache le cercle des champs clairs.
		draw_arc(c, 6.0, 0.0, TAU, 32, Color(0, 0, 0, 0.45), 3.5, true)
		if remplissage > 0.0:
			draw_circle(c, 6.0 * remplissage, plein)
		draw_arc(c, 6.0, 0.0, TAU, 32, plein if remplissage >= 1.0 else encre, 1.5, true)


## La fiole : posée au bout d'une ligne (ce que l'objectif rapporte), puis en vol vers le
## compteur. Node2D : une Control s'arrondit au pixel et le vol saccaderait (`bulles.gd`).
class Fiole extends Node2D:
	var icone: Texture2D

	func _draw() -> void:
		var o := -icone.get_size() / 2.0
		draw_texture(icone, o + Vector2(1, 1), Color(0, 0, 0, 0.5))
		draw_texture(icone, o)


func batir(maquette) -> void:
	jeu = maquette
	var ui = jeu.interface
	name = "Objectifs"
	# Discret (auteur, 2026-10-19) : pas de boîte, le texte posé sur la carte.
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = 16
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scene = Control.new()
	_scene.clip_contents = true
	_scene.custom_minimum_size = Vector2(LARGEUR, (GARDES + MONTRES) * LIGNE)
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
		"places":
			for fid in v._stationnement_supprime:
				if float(v._stationnement_supprime[fid]) <= t:
					return true
			return false
		"rue":
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


## Les derniers atteints, du plus ancien au plus récent.
func _atteints() -> Array:
	var faits: Dictionary = jeu.ville._objectifs
	var ordre: Array = OBJECTIFS.keys()
	var ids: Array = faits.keys()
	ids.sort_custom(func(a, b) -> bool:
		if float(faits[a]) != float(faits[b]):
			return float(faits[a]) < float(faits[b])
		return ordre.find(a) < ordre.find(b))
	return ids.slice(maxi(0, ids.size() - GARDES))


## Appelé par le guide à chaque actualisation : l'objectif courant se vérifie, les lignes se
## rangent. Les atteints au-dessus, de plus en plus pâles ; le courant ; le suivant, pâle.
## ⏱️ Le guetteur, 10×/s au plus hors `force` : à chaque image il pesait 0,6 ms (2026-10-19).
const GUET_MS := 100
var _guet_ms := -GUET_MS


func actualiser(force := false) -> void:
	var ui = jeu.interface
	# Caché pendant le récit, comme les compteurs ; au-dessus des boutons de caméra.
	visible = ui._menu_panneau.visible
	offset_bottom = -16.0 - ui._camera_panneau.size.y - 10.0
	var attente := 0.0
	var guet := force or Time.get_ticks_msec() - _guet_ms >= GUET_MS
	if guet:
		_guet_ms = Time.get_ticks_msec()
	# 🌳 Les actions se font dans l'ordre du joueur : le premier atteint, pas le premier listé.
	for id in _restants() if guet else []:
		if visible and atteint(id):
			jeu.ville._objectifs[id] = jeu.mois
			ui.retours.consigner("Objectif atteint : %s. Un point de recherche." % OBJECTIFS[id], jeu.mois)
			_reussir(id)
			attente = TENIR_S
			break
	var atteints := _atteints()
	var restants := _restants().slice(0, MONTRES)
	for k in _lignes.keys():
		if not k in atteints and not k in restants:
			_effacer(_lignes[k], attente)
			_lignes.erase(k)
	for i in atteints.size():
		var j := atteints.size() - 1 - i
		_ranger(atteints[i], (GARDES - 1 - j) * LIGNE, ATTEINT_ALPHA[j], attente, true)
	for r in restants.size():
		_ranger(restants[r], (GARDES + r) * LIGNE, 1.0 if r == 0 else SUIVANT_ALPHA, attente, false)


func _ranger(id: String, y: float, alpha: float, attente: float, fait: bool) -> void:
	var l: HBoxContainer = _lignes.get(id)
	if l == null:
		l = _ligne(id, fait)
		# Un nouveau suivant entre par le bas ; un atteint repris d'une sauvegarde, sur place.
		l.position = Vector2(0, y if fait else y + LIGNE)
		_lignes[id] = l
	(l.get_child(1) as Label).text = _texte(id)
	# Atteint sans passer par `_reussir` (sauvegarde, recommencer) : le cercle se pose plein.
	var c: Cercle = l.get_child(0)
	if fait and c.remplissage == 0.0 and not l.has_meta("remplit"):
		c.remplissage = 1.0
		l.get_child(2).visible = false
	elif not fait:
		c.remplissage = 0.0
		l.get_child(2).visible = true
	# Appelé à chaque actualisation : on ne relance que si la place change, sinon l'attente
	# du cercle plein serait écrasée.
	if l.get_meta("cible", Vector2(-1, -1)) == Vector2(y, alpha):
		return
	l.set_meta("cible", Vector2(y, alpha))
	if l.has_meta("tw"):
		(l.get_meta("tw") as Tween).kill()
	var tw := l.create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position:y", y, MONTER_S).set_delay(attente)
	tw.tween_property(l, "modulate:a", alpha, MONTER_S).set_delay(attente)
	l.set_meta("tw", tw)


func _ligne(id: String, fait: bool) -> HBoxContainer:
	var ui = jeu.interface
	var l := HBoxContainer.new()
	l.add_theme_constant_override("separation", 8)
	l.size = Vector2(LARGEUR, LIGNE)
	l.modulate.a = 0.0
	var c := Cercle.new()
	c.custom_minimum_size = Vector2(16, LIGNE)
	c.encre = ui.ENCRE_HISTOIRE
	c.plein = ui.FAIT
	c.remplissage = 1.0 if fait else 0.0
	l.add_child(c)
	var t: Label = ui._label(_texte(id), 13, ui.ENCRE_HISTOIRE)
	t.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	t.add_theme_constant_override("outline_size", 4)
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	t.custom_minimum_size.y = LIGNE
	l.add_child(t)
	# A (auteur, 2026-10-19) : ce que l'objectif rapporte, au bout de la ligne.
	var gain := HBoxContainer.new()
	gain.add_theme_constant_override("separation", 1)
	gain.visible = not fait
	var plus: Label = ui._label("+1", 13, BLEU)
	plus.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	plus.add_theme_constant_override("outline_size", 4)
	plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plus.custom_minimum_size.y = LIGNE
	gain.add_child(plus)
	var place := Control.new()
	place.custom_minimum_size = Vector2(14, LIGNE)
	var f := Fiole.new()
	f.icone = ui._icone("recherche", 14, BLEU)
	f.position = Vector2(7, LIGNE / 2.0)
	place.add_child(f)
	gain.add_child(place)
	l.add_child(gain)
	_scene.add_child(l)
	return l


## Le plus ancien des atteints sort par le haut.
func _effacer(l: Control, attente: float) -> void:
	if l.has_meta("tw"):
		(l.get_meta("tw") as Tween).kill()
	var tw := l.create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(l, "position:y", l.position.y - LIGNE, MONTER_S).set_delay(attente)
	tw.tween_property(l, "modulate:a", 0.0, MONTER_S).set_delay(attente)
	tw.chain().tween_callback(l.queue_free)


## Le cercle se remplit, puis la fiole du bout de la ligne vole jusqu'au compteur (B, auteur,
## 2026-10-19) ; `actualiser` range ensuite la ligne avec les atteints.
func _reussir(id: String) -> void:
	var ui = jeu.interface
	# Le compteur n'avance qu'à l'arrivée de la fiole.
	ui.points_en_vol += 1
	var l: HBoxContainer = _lignes.get(id)
	if l == null:
		# Hors des lignes montrées : la fiole part du bas du bloc.
		_voler(global_position + Vector2(LARGEUR * 0.5, size.y), 0.0)
		return
	l.set_meta("remplit", true)
	var gain: Control = l.get_child(2)
	var tw := l.create_tween()
	tw.tween_property(l.get_child(0), "remplissage", 1.0, REMPLIR_S)
	tw.tween_callback(func() -> void:
		var depart: Vector2 = gain.get_child(1).get_global_rect().get_center()
		gain.visible = false
		_voler(depart, 0.0))


func _voler(depart: Vector2, attente: float) -> void:
	var ui = jeu.interface
	var f := Fiole.new()
	f.icone = ui._icone("recherche", 22, BLEU)
	f.position = depart
	ui.add_child(f)
	var tw := f.create_tween()
	tw.tween_interval(attente)
	# Le compteur peut paraître pendant le vol (premier objectif) : la cible se relit à chaque pas.
	tw.tween_method(func(t: float) -> void:
		var bloc: Control = ui._barre_valeurs["recherche"].get_parent()
		var cible: Vector2 = bloc.get_child(0).get_global_rect().get_center()
		var haut := Vector2(lerpf(depart.x, cible.x, 0.3), minf(depart.y, cible.y) + 0.35 * absf(cible.y - depart.y))
		var u := 1.0 - t
		f.position = u * u * depart + 2.0 * u * t * haut + t * t * cible
		f.scale = Vector2.ONE * lerpf(1.0, 1.3, sin(t * PI)),
		0.0, 1.0, VOLER_S).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func() -> void:
		f.queue_free()
		ui.points_en_vol = maxi(0, ui.points_en_vol - 1)
		ui.actualiser_points(jeu.mois)
		var bloc: Control = ui._barre_valeurs["recherche"].get_parent()
		bloc.pivot_offset = bloc.size / 2.0
		var bond := bloc.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		bloc.scale = Vector2.ONE * 1.3
		bond.tween_property(bloc, "scale", Vector2.ONE, 0.35)
		ui.bulles.sous(bloc, "+1", "recherche", ui.FAIT_TEXTE))
