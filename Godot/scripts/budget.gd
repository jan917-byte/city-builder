extends Control
## 💶 LA FICHE DU VOTE ANNUEL (décision 101) : tous les douze mois le temps
## s'arrête, et la fiche dit ce que la ville a voté et pourquoi — l'écart à l'an
## dernier, ligne par ligne. Formule cachée ≠ causalité cachée (60b).
##
## 🔴 FLAGGABLE (90) : toutes les phrases de ce fichier sont PROVISOIRES — l'auteur
## les écrit (2026-10-01). Elles sont rangées dans `TEXTES`, et nulle part ailleurs.

const TEXTES := {
	"titre": "Budget de l'an {an}",
	"logements": "Logements habités",
	"rues": "Rues à entretenir",
	"verse": "Versé aujourd'hui",
	"avant_premier": "Au lendemain de la crue, la ville n'aurait voté que {ke}.",
	"avant": "L'an dernier : {ke}.",
	"entiere": "Une ville entièrement remise sur pied vote {ke}.",
	"prochain": "Prochain budget dans 12 mois.",
	"continuer": "Continuer",
	"journal": "Budget de l'an {an} voté : {ke} ({ecart} k€ sur l'an dernier).",
}

var jeu
var vote := {}
var _vitesse_reprise := 1.0
var _titre: Label
var _grille: GridContainer
var _verse: Label
var _notes: Label


func batir(maquette) -> void:
	jeu = maquette
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# La ville se regarde pendant le vote, elle ne se clique pas.
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var ui = jeu.interface
	theme = ui._theme_ui
	var boite := PanelContainer.new()
	ui._poser_boite(boite)
	boite.custom_minimum_size.x = 440
	# Même place que le récit : centrée, au-dessus des commandes du temps.
	boite.anchor_left = 0.5
	boite.anchor_right = 0.5
	boite.anchor_top = 1.0
	boite.anchor_bottom = 1.0
	boite.grow_horizontal = Control.GROW_DIRECTION_BOTH
	boite.grow_vertical = Control.GROW_DIRECTION_BEGIN
	boite.offset_bottom = -jeu.recit.HAUTEUR_BAS if jeu.recit != null else -104.0
	add_child(boite)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	boite.add_child(v)
	_titre = ui._titre("", 22, ui.TEXTE)
	v.add_child(_titre)
	_grille = GridContainer.new()
	_grille.columns = 3
	_grille.add_theme_constant_override("h_separation", 18)
	_grille.add_theme_constant_override("v_separation", 6)
	v.add_child(_grille)
	v.add_child(HSeparator.new())
	var total := HBoxContainer.new()
	v.add_child(total)
	var mot: Label = ui._label(TEXTES["verse"], 14, ui.TEXTE)
	mot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	total.add_child(mot)
	_verse = ui._titre("", 22, ui.ACCENT)
	total.add_child(_verse)
	_notes = ui._label("", 12, ui.GRIS)
	_notes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_notes)
	var bas := HBoxContainer.new()
	bas.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(bas)
	var bouton := Button.new()
	bouton.text = TEXTES["continuer"]
	bouton.pressed.connect(fermer)
	bas.add_child(bouton)
	ui._sans_focus(self)


func en_cours() -> bool:
	return visible


## Le vote n° `n` vient de tomber : la phrase au journal, puis la fiche, temps arrêté.
func ouvrir(n: int, vitesse: float) -> void:
	var ui = jeu.interface
	vote = jeu.ville.vote_budget(n)
	var avant: Dictionary = jeu.ville.vote_budget(n - 1)
	var ecart := float(vote["ke"]) - float(avant["ke"])
	ui.retours.notifier(TEXTES["journal"].format({"an": n + 1,
		"ke": _ke(vote["ke"]), "ecart": ("%+.0f" % ecart).replace("-", "−")}), float(vote["mois"]))
	_titre.text = TEXTES["titre"].format({"an": n + 1})
	for e in _grille.get_children():
		e.queue_free()
	var d_log := float(vote["logements"]) - float(avant["logements"])
	var d_m := float(vote["metres"]) - float(avant["metres"])
	_ligne(TEXTES["logements"], ui._milliers(vote["logements"]),
		_ecart(d_log, ui._milliers(absf(d_log)), d_log * jeu.ville.budget_ke_logement))
	_ligne(TEXTES["rues"], ui._nb(float(vote["metres"]) / 1000.0, 1) + " km",
		_ecart(d_m, ui._nb(absf(d_m) / 1000.0, 1) + " km", -d_m * jeu.ville.budget_ke_metre))
	_verse.text = _ke(vote["ke"])
	_notes.text = "\n".join([
		(TEXTES["avant_premier"] if n == 1 else TEXTES["avant"]).format({"ke": _ke(avant["ke"])}),
		TEXTES["entiere"].format({"ke": _ke(jeu.ville.BUDGET_VILLE_ENTIERE_KE_AN)}),
		TEXTES["prochain"]])
	if vitesse > 0.0:
		_vitesse_reprise = vitesse
	visible = true
	jeu._sur_vitesse(0.0)


func fermer() -> void:
	visible = false
	jeu._sur_vitesse(_vitesse_reprise)


func _ligne(quoi: String, valeur: String, ecart: String) -> void:
	var ui = jeu.interface
	_grille.add_child(ui._label(quoi, 14, ui.TEXTE))
	var l: Label = ui._label(valeur, 14, ui.TEXTE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_grille.add_child(l)
	var e: Label = ui._label(ecart, 12, ui.GRIS)
	e.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_grille.add_child(e)


## « +43 · +7,8 k€ » ; rien qui bouge, « = ».
func _ecart(delta: float, quantite: String, ke: float) -> String:
	if absf(delta) < 0.5:
		return "="
	return "%s%s · %s k€" % ["+" if delta > 0.0 else "−", quantite,
		jeu.interface._nb(ke, 1).replace("-", "−") if ke < 0.0 else "+" + jeu.interface._nb(ke, 1)]


func _ke(ke: Variant) -> String:
	return jeu.interface._milliers(float(ke)) + " k€"
