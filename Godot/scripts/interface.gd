extends CanvasLayer
# L'interface du prologue climatique : adaptation, puis réduction.
# 🔄 Le verrou de l'urgence est tombé le 2026-08-31 (voir `ville.lancer_solaire`). Les
# réparations font avancer la jauge d'adaptation.

signal vitesse_demandee(vitesse: float)
signal temps_remis()
signal sauvegarde_demandee()
signal reprise_demandee()
signal nord_demande()
signal dessus_demande()
## "" ramène à la ville vivante, sinon c'est un `id` de `maquette.THEMES`.
signal theme_demande(id: String)
## 🔴 UNE SEULE DEMANDE, ET C'EST TOUT CE QUE LA FICHE ÉMET (2026-08-31). On
## règle, on compare l'avant et l'après, puis on met en place : les réglages
## posés partent ensemble, au format que `ville.commander` lit.
## 🔄 Cinq boutons émettaient cinq demandes AU CLIC — rien à essayer, rien à
## reprendre, et chacun disait « il manque 214 k€ » de son côté.
signal commande_demandee(couche: String, fid: int, reglages: Dictionary)
## ✕ La croix de la fiche : `maquette` efface la sélection.
signal fiche_fermee()
signal deblaiement_demande()
## 🎓 Les deux onglets de Dangers : "degats" ou "prochaine".
signal vue_crue_demandee(id: String)
## Ouvrir la fiche d'un lieu, déjà réglée — `maquette.examiner`.
signal examen_demande(couche: String, fid: int, reglage: String, valeur: Variant)
## 🏛️ L'écran du concours s'ouvre sur cet îlot : `maquette` le remonte au-dessus.
signal projets_ouverts(fid: int)
## 🛠️ Le mode choisi au lancement : histoire, ou auteur (chantiers livrés au clic).
signal mode_choisi(auteur: bool)

const Ville := preload("res://scripts/ville.gd")
## 🪜 Pour le seul remboursement de la tranche : la fiche annonce ce que la
## progressivité change, et le nombre se calcule là où sont les deux courbes.
const Energie := preload("res://scripts/energie.gd")
const Apercu := preload("res://scripts/apercu.gd")
const Recherche := preload("res://scripts/recherche.gd")
const Ouverture := preload("res://scripts/ouverture.gd")
const Politiques := preload("res://scripts/politiques.gd")
const Lieux := preload("res://scripts/lieux.gd")
const Livre := preload("res://scripts/livre.gd")
var lieux := Lieux.new()
var _reprendre: Button

## 🔤 LA POLICE, À TRANCHER DEVANT L'IMAGE. Trois candidates dans
## `Godot/polices/`, toutes sous licence SIL OFL (leur `*-OFL.txt` est à côté du
## fichier) — donc libres pour un jeu vendu. `-- --police <clé>` en essaie une
## sans toucher au fichier ; « godot » est la police d'origine.
const POLICES := {
	"godot": "",
	"rubik": "res://polices/Rubik.ttf",
	"grotesk": "res://polices/SpaceGrotesk.ttf",
	"barlow": "res://polices/BarlowSemiCondensed.ttf",
	"nunito": "res://polices/Nunito.ttf",
	"fredoka": "res://polices/Fredoka.ttf",
	"baloo": "res://polices/Baloo2.ttf",
}
const POLICE := "rubik"
## 🔲 HABILLAGE « VITRE », EN PLACE (auteur, 2026-10-02, après « trop IA, trop rempli ») :
## verre neutre à angles droits, liseré d'un pixel, sans ombre ; le temps en haut à droite.
## `-- --habillage bois` rend le brun et crème du 2026-09-28, `verre` le crème et vert d'avant.
## `_habiller()` écrase les couleurs ci-dessous.
var VITRE := true
var BOIS := false
const BOIS_CADRE := Color8(94, 62, 47)
const BOIS_LISERE := Color8(214, 192, 172)
## La planche du temps, et ce qui s'écrit dessus.
const BOIS_PLANCHE := Color8(124, 86, 63)
const BOIS_CREME := Color8(250, 238, 218)
## 🔷 VERRE CRÈME ET VERT (auteur, 2026-09-28, essai), après le bleu du 2026-09-20. Le fond
## des panneaux n'est plus une couleur mais la ville floutée (`shaders/verre`) ;
## `FOND` ne sert donc que de secours si le verre est coupé.
var VERRE := true
## 🔴 LEVEL DESIGN : à 0,66 le petit texte gris se perdait sur les toits rouges
## (2026-09-20). Sous 0,70 on ne lit plus, au-dessus de 0,85 ce n'est plus du verre.
## 🔄 0,90 → 0,84 et un blanc moins jaune (auteur, 2026-09-28).
var VERRE_TEINTE := Color(1.0, 0.993, 0.972, 0.84)
var FOND := Color8(250, 246, 236, 200)
var FOND_FORT := Color8(234, 226, 206, 170)
var TEXTE := Color8(36, 42, 33)
var GRIS := Color8(98, 96, 82)
## Le gris des ÉTIQUETTES : plus sombre que celui des phrases, parce qu'un
## mot de 11 px a moins de forme à offrir à l'œil.
var GRIS_FORT := Color8(74, 80, 62)
var ACCENT := Color8(40, 84, 48)
## Le vert des onglets ouverts et du bouton qui engage : c'est lui qui
## fait « jeu » plutôt que « document ». Jamais sous du texte long.
var ACCENT_VIF := Color8(62, 124, 70)
# Le seul refus du prototype : la caisse ne suit pas. Un bouton grisé sans
# raison écrite est une panne, pas une règle.
var ALERTE := Color8(198, 76, 66)
## 🟡 L'anneau de la tuile que le guide demande. Plus franc que le trait de
## sélection 3D (`maquette.CONTOUR_COULEUR`), qui se perdrait sur le verre clair.
var APPEL := Color8(240, 190, 40)
## ✓ Un chantier fini se DIT en vert, il ne se grise pas en bouton mort. Plus
## sombre que `FAIT`, qui est une couleur de jauge et ne se lit pas en texte.
var FAIT_TEXTE := Color8(39, 96, 22)
## 🔄 LE RAIL EST DU MÊME VERRE QUE LES PANNEAUX (auteur, 2026-09-28, image de
## référence) : icônes foncées sur crème, la vue active en vert plein. Il était
## bleu nuit depuis le 2026-09-03.
var RAIL_SURVOL := Color8(226, 236, 214, 220)
# 🔧 LES TROIS COULEURS DE LA VUE CHANTIERS, aussi dans le shader
# (`materiaux.objet`, en linéaire) : n'en changer qu'une fait mentir la légende.
const CASSE := Color8(220, 58, 48)
const EN_TRAVAUX := Color8(232, 170, 48)
const FAIT := Color8(91, 174, 117)
## Les genres de `ville.chantier` en clair, pour la barre de la fiche.
const CHANTIER_MOTS := {
	"reconstruction": "Reconstruction", "pont": "Tablier rebâti",
	"deblaiement": "Déblaiement", "deblaiement_groupe": "Déblaiement", "solaire": "Pose de panneaux",
	"berge": "Rive transformée", "stationnement": "Retrait des places",
	"densification": "Étages ajoutés",
	"relogement": "Installation des abris",
	"labour": "Labour",
	"culture": "Mise en culture",
	"amelioration": "Amélioration du campement",
	"concours": "Concours",
	"toit vert": "Toit végétalisé", "plantation": "Plantation",
	"sol perméable": "Sol rendu perméable",
}


## Ce qui est POSÉ, et vers quoi ça va. Un `ProgressBar` ne montre qu'un
## nombre : il en faut deux pour distinguer « 40 % posés » de « 40 % en route
## vers 72 % ». Elle ne se touche pas — le réglage est le curseur d'en dessous.
class Jauge extends Control:
	# `static var` : l'habillage bois les fonce, le crème clair les avalait.
	static var RESTE := Color8(224, 216, 196, 190)    # le toit encore nu
	const VISEE := Color8(174, 147, 74)          # l'objectif demandé, pas encore atteint
	const POSE := Color8(221, 171, 49)           # les panneaux réellement en place

	var pose := 0.0   # 0 → 1
	var cible := 0.0  # 0 → 1, toujours ≥ pose
	var couleur_reste := RESTE
	var couleur_visee := VISEE
	var couleur_pose := POSE
	# 🔄 EN PILULE depuis le 2026-09-03, et le filet qui l'entourait est parti
	# avec : sur le papier clair, la gouttière se voit toute seule. Les trois
	# boîtes sont refaites à `colorer()`, jamais dans `_draw()`. Droite en vitre.
	static var ARRONDI := 99
	var _sb_reste: StyleBoxFlat
	var _sb_visee: StyleBoxFlat
	var _sb_pose: StyleBoxFlat

	static func _pilule(coul: Color) -> StyleBoxFlat:
		var sb := StyleBoxFlat.new()
		sb.bg_color = coul
		sb.set_corner_radius_all(ARRONDI)
		return sb

	func _refaire() -> void:
		_sb_reste = _pilule(couleur_reste)
		_sb_visee = _pilule(couleur_visee)
		_sb_pose = _pilule(couleur_pose)

	func colorer(rempli: Color, vide := RESTE) -> void:
		if rempli == couleur_pose and vide == couleur_reste and _sb_pose != null:
			return
		couleur_pose = rempli
		couleur_visee = rempli.darkened(0.35)
		couleur_reste = vide
		_refaire()
		queue_redraw()

	func regler(p: float, c: float) -> void:
		if is_equal_approx(p, pose) and is_equal_approx(c, cible):
			return  # ⚠️ appelé à chaque image : ne repeindre que sur un vrai changement
		pose = p
		cible = c
		queue_redraw()

	func _draw() -> void:
		if _sb_reste == null:
			_refaire()
		draw_style_box(_sb_reste, Rect2(Vector2.ZERO, size))
		# ⚠️ Plancher à `size.y` : sous une largeur d'un rond, la pilule
		# s'écrase en trait et 2 % ressemble à 0 %.
		if cible > pose:
			draw_style_box(_sb_visee,
				Rect2(0.0, 0.0, maxf(size.y, size.x * cible), size.y))
		if pose > 0.0:
			draw_style_box(_sb_pose,
				Rect2(0.0, 0.0, maxf(size.y, size.x * pose), size.y))


## 🌊 LA JAUGE DE LA PROCHAINE CRUE (auteur, 2026-10-06), en mètres d'eau en
## moins au pire depuis l'étude : livré (plein), engagé (hachures), le réglage de
## la fiche (trait blanc), et le seuil où les premières maisons tiennent (trait
## sombre). En logements elle ne bougeait pas : sous ce seuil, aucun n'est sauvé.
class JaugeCrue extends Control:
	const EAU := Color8(38, 104, 168)
	const ENGAGE := Color8(120, 176, 214)
	const FOND := Color8(224, 216, 196, 190)
	const PLEINE_M := 1.5      # l'échelle : au-delà, la barre est pleine
	var livre := 0.0
	var engage := 0.0
	var apercu := -1.0
	var seuil := 0.0

	func regler(l: float, e: float, p: float, s: float) -> void:
		if is_equal_approx(l, livre) and is_equal_approx(e, engage) \
				and is_equal_approx(p, apercu) and is_equal_approx(s, seuil):
			return  # ⚠️ appelé à chaque image
		livre = l
		engage = e
		apercu = p
		seuil = s
		queue_redraw()

	func _x(m: float) -> float:
		return size.x * clampf(m / PLEINE_M, 0.0, 1.0)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), FOND)
		var x0 := _x(livre)
		var x1 := _x(engage)
		if x1 > x0 + 0.5:
			draw_rect(Rect2(x0, 0.0, x1 - x0, size.y), Color(ENGAGE, 0.45))
			var x := x0 - size.y
			while x < x1:
				var a := Vector2(maxf(x, x0), size.y - (maxf(x, x0) - x))
				var b := Vector2(minf(x + size.y, x1), size.y - (minf(x + size.y, x1) - x))
				draw_line(a, b, ENGAGE, 2.0)
				x += 6.0
		draw_rect(Rect2(0.0, 0.0, x0, size.y), EAU)
		var xs := _x(seuil)
		draw_line(Vector2(xs, -3.0), Vector2(xs, size.y + 3.0), Color8(60, 52, 40), 2.0)
		if apercu >= 0.0:
			var xp := _x(apercu)
			draw_line(Vector2(xp, -4.0), Vector2(xp, size.y + 4.0), Color.WHITE, 3.0)
			draw_line(Vector2(xp, -4.0), Vector2(xp, size.y + 4.0), Color8(30, 30, 30), 1.0)


## 🧭 LA COLONNE D'ICÔNES, ET LE PANNEAU QUI S'OUVRE À CÔTÉ (2026-09-03, demande
## de l'auteur). Elle remplace le bandeau de neuf tuiles ET la barre du bas : le
## mot d'une icône est passé en infobulle. Les trois abscisses tiennent ici et
## nulle part ailleurs — un panneau qui s'ancre tout seul se décale du rail.
const RAIL_X := 14.0
const RAIL_LARGEUR := 64.0
const DETAIL_X := RAIL_X + RAIL_LARGEUR + 10.0
const DETAIL_LARGEUR := 312.0
const HAUT := 14.0
## La colonne de droite : le temps en vitre, puis la fiche dessous.
const FICHE_LARGEUR := 320.0
const TEMPS_VITRE := 48.0


func _haut_fiche() -> float:
	return HAUT + TEMPS_VITRE if VITRE else HAUT


## Une quantité comptée en jetons plutôt qu'en phrase : dix pastilles, k
## allumées. La texture est dessinée EN BLANC — c'est la teinte qui la colore,
## sinon la modulation multiplierait deux couleurs.
class Pictos extends Control:
	const NB := 10
	static var PALE := Color8(222, 214, 196)

	var texture: Texture2D
	var teinte := Color.WHITE
	var part := 0.0

	func regler(p: float) -> void:
		p = clampf(p, 0.0, 1.0)
		if is_equal_approx(p, part):
			return
		part = p
		queue_redraw()

	func _draw() -> void:
		if texture == null:
			return
		var allumes := int(roundf(part * float(NB)))
		var pas := size.x / float(NB)
		for i in NB:
			draw_texture_rect(texture, Rect2(i * pas, 0.0, size.y, size.y),
				false, teinte if i < allumes else PALE)


var ville: Ville
var trafic
var ouverture
var retours := preload("res://scripts/retours.gd").new()
## 🎈 Les chiffres qui montent ; sous tous les panneaux.
var bulles := preload("res://scripts/bulles.gd").new()
var _debut: Button
## 🔎 La texture de la miniature, posée par `maquette.gd` avant `batir()`.
var apercu: Texture2D
## 🏛️ Façon → la miniature de sa carte au concours, rendue par la maquette.
var apercus_projets := {}
var themes := []     # `maquette.THEMES`, passée : pas d'import croisé
var rampe := []      # `maquette.RAMPE`, en sRGB
var rampe_eau := []  # `maquette.RAMPE_EAU`, en sRGB

var _ville_valeurs := {}
## 📊 La barre du haut : les mêmes nombres que le bilan, toujours sous les yeux.
var _barre: PanelContainer
var _barre_valeurs := {}
var _detail_panneau: PanelContainer
var _detail_liste: VBoxContainer
var _detail_sujet := ""         # "caisse", "capital" ou "" : le compteur dont on lit le détail
var _detail_lignes := []        # la dernière liste posée : on ne rebâtit que si elle change
var _historique_ouvert := false # « Depuis le mois 0 » replié par défaut (auteur, 2026-10-08)
var _ville_jauges := {}
## Le repère du mois 0 pour les deux seuls chiffres qui n'ont pas de part
## naturelle — la conso et le CO₂ —, mémorisé au premier `maj()`.
var _conso_zero := 0.0
var _co2_zero := 0.0
var _adaptation_jauge: Jauge
var _adaptation_valeur: Label
var _adaptation_pictos: Pictos
var _reduction_jauge: Jauge
var _reduction_valeur: Label
var _reduction_pictos: Pictos
var _fiche_valeurs := {}
var _fiche_titre: Label
## Le type de l'objet, sous son nom : une identité, jamais une mesure.
var _fiche_soustitre: Label
var _fiche_vide: Label
## 🗂️ LA FICHE EST À ONGLETS (auteur, 2026-09-18) : une ligne de résumé, puis
## une rangée d'icônes, et UN SEUL thème ouvert à la fois — ses chiffres ET son
## réglage. Ce qui suit est tout le mécanisme.
## `_dispo` dit quels onglets l'objet courant mérite ; `_bloc_onglet` range
## chaque bloc de réglage sous son thème ; `_bloc_dispo` garde son droit à
## s'afficher indépendamment de l'onglet ouvert — sans quoi la phrase de
## l'urgence ne saurait plus si le camp existe.
var _resume_ligne: HBoxContainer
var _resume_icone: TextureRect
var _resume_texte: Label
var _resume_dessin := ""
var _onglets: HBoxContainer
var _onglet_boutons := {}
var _onglet_grilles := {}
var _onglet_actif := ""
var _dispo := {}
var _bloc_onglet := {}
var _bloc_dispo := {}
var _chantier_bloc: VBoxContainer
var _chantier_quoi: Label
var _chantier_reste: Label
var _chantier_jauge: Jauge
var _solaire_bloc: VBoxContainer
var _solaire_valeur: Label
var _solaire_curseur: HSlider
var _solaire_jauge: Jauge
## 🌿 Le second usage du même toit. Bloc jumeau du solaire — même curseur, même
## jauge, même mémoire de position — parce que les deux se partagent un 100 %.
var _vert_bloc: VBoxContainer
var _dense_bloc: VBoxContainer
## 🅿️💧 Le sol de la place-parking (101).
var _permeable_bloc: VBoxContainer
var _permeable_texte: Label
var _permeable_bouton: Button
var _dense_valeur: Label
var _dense_boutons: Array[Button] = []
var _dense_curseur: HSlider
var _dense_jauge: Jauge
var _vert_valeur: Label
var _vert_curseur: HSlider
var _vert_jauge: Jauge
var _arbres_bloc: VBoxContainer
var _arbres_valeur: Label
var _arbres_curseur: HSlider
var _arbres_jauge: Jauge
## Le récapitulatif et LE bouton : ce que la commande coûte, ce qu'elle dure, et
## le seul refus du jeu quand la caisse ne suit pas.
var _recap_bloc: VBoxContainer
var _recap_texte: Label
var _recap_bouton: Button
var _recap_effets: HFlowContainer   # les conséquences en pictogrammes (auteur, 2026-09-26)
var _recap_annuler: Button
var _recap_cle := ""
## 🧪 Une deuxième ville, jamais montrée : on y engage le réglage pour mesurer
## ses conséquences sans rien payer. Posée par la maquette, sur SA copie des données.
var ville_essai: Ville
var _message: Label
var _camera_nord: Button
var _camera_dessus: Button
var _temps_label: Label
var _vitesses := {}
## 📖 Les deux panneaux du bas, rangés pendant le récit avec tout le reste.
var _temps_panneau: PanelContainer
var _camera_panneau: PanelContainer
var _ville_panneau: PanelContainer
var _menu_panneau: PanelContainer
var _menu_boutons := {}
## 🔒 Les tuiles de la mairie et de l'université, grisées pendant le verrou.
var _rail_lieux: Array[Button] = []
## 🎓🏛️ LES DEUX MENUS QUI ONT UN LIEU (décision 81). `_lieu_ouvert` vaut ""
## quand la fiche d'îlot est en place : les deux ne s'affichent jamais ensemble.
var _lieu_panneau: PanelContainer
var _lieu_titre: Label
var _lieu_intro: Label
var _lieu_message: Label
var _lieu_lignes := {}
var _lieu_ouvert := ""
var _lieu_bouton: Button
var _diagnostic_panneau: PanelContainer
var _chantiers_panneau: PanelContainer
var _calque_panneau: PanelContainer
var _calque_bas: Label
var _calque_haut: Label
var _calque_barre: TextureRect
var _calque_note: Label
## Les trois panneaux de thème portent le MÊME en-tête, tiré de la table :
## le nom et le résumé ne sont écrits qu'une fois, dans `maquette.THEMES`.
var _entetes := {}
## Rouvrir le diagnostic doit rendre le thème qu'on regardait, pas le premier
## de la liste : sinon comparer deux mois coûte deux clics au lieu d'un.
var _chantiers_valeurs := {}
var _chantiers_lignes := []
var _fiche_panneau: PanelContainer
var _depart_panneau: CenterContainer
var _fiche_defilement: ScrollContainer
var _fiche_contenu: VBoxContainer
var _apercu_cadre: PanelContainer

var _fiche_fid := -1
var _fiche_couche := "i"
var _rue_valeurs := {}
var _repare_bloc: VBoxContainer
var _camp_bloc: VBoxContainer
var _camp_texte: Label
var _camp_bouton: Button
var _labour_bouton: Button   # 🚜 rend le campement vidé au champ
var _demandes_bloc: VBoxContainer
var _demande_boutons := {}
## 🌾 Ce que porte le champ : un bouton par culture (auteur, 2026-09-29).
var _culture_bloc: VBoxContainer
var _culture_texte: Label
var _culture_boutons := []
var _repare_texte: Label
var _repare_bouton: Button
var _repare_provisoire: Button   # 🌉 l'autre choix d'un pont coupé (auteur, 2026-09-24)
## 🏗️ Les quatre façons de relever un îlot sinistré (`Ville.RECONSTRUCTIONS`).
var _rebatir_boutons := {}
## 🏛️ Le concours (104) : lancé une fois, puis l'écran des quatre projets de chaque îlot.
var _concours_bouton: Button
var _projets_bouton: Button
var _projets_panneau: PanelContainer
var _projets_titre: Label
var _projets_intro: Label
var _projets_cartes := {}   # façon -> {bouton, lignes}
var _projets_cle := ""
var _repare_etat: Label   # « Chantier en cours » : remplace le bouton grisé
## 🎚️ LES BASCULES POSÉES SUR L'OBJET COURANT, pas encore mises en place. Les
## deux curseurs gardent leur propre mémoire, plus bas, parce qu'ils doivent
## survivre à une image sans se replacer sous le doigt ; `_reglages()` réunit
## les trois et c'est LUI seul que la commande et la miniature lisent.
var _pose := {}
## [bouton, clé, valeur] des bascules : survolées, elles montrent leurs conséquences.
var _decisions := []
## Le bouton qu'on vient de presser ne se prévisualise plus tant que la souris y reste :
## sinon, décocher montrait encore l'après (auteur, 2026-09-30).
var _survol_ignore: Button
var _trafic_bloc: VBoxContainer
var _trafic_stationnement: Button
var _trafic_axe: Button
var _berge_valeurs := {}
var _berge_bloc: VBoxContainer
var _berge_texte: Label
var _berge_boutons := []
var _degats := {}
var _degats_valeurs := {}
var _vue_crue := "degats"
var _jauge_crue: JaugeCrue
## Les logements perdus une fois livrés les chantiers engagés : recalculé au jour.
var _a_venir_cle := ""
var _a_venir := 0.0
## L'eau au pire avec le réglage de la fiche ouverte, −1 sans réglage (`consequences`).
var _apercu_crue := -1.0
## La baisse où les premières maisons tiennent, mesurée une fois sur les courbes de `04e`.
var _seuil_crue := -1.0
var _onglets_crue := {}
var _vues_crue := {}
var _prochaine_valeurs := {}
var _etude_bloc: VBoxContainer
## 🎓 La fenêtre du campus (auteur, 2026-10-09) : au centre, la fiche d'îlot reste à côté.
var _campus_panneau: PanelContainer
## Les trois onglets, dans l'ordre de `CAMPUS`.
var _campus_bloc: HBoxContainer
var _campus_intro: Label
var _recherche_bloc: HBoxContainer
var _univ_vide: Label
## ⏸️ La vitesse d'avant la fenêtre, rendue à sa fermeture ; -1 fenêtre fermée.
var _vitesse_avant_campus := -1.0
var _vitesse_courante := 0.0
var _etude_valeurs := {}
## 📖 LA BIBLIOTHÈQUE (101) : la liste des pages, ou une page ouverte.
var _biblio_bloc: VBoxContainer
var _biblio_liste: VBoxContainer
var _page_bloc: VBoxContainer
var _page_titre: Label
var _page_chapitre: Label
var _page_texte: Label
var _page_leviers: VBoxContainer
var _page_voir: Button
var _page_ouverte := ""
var _biblio_cle := ""
## « Voir à Wehrau » : `maquette.voir_concept`.
signal concept_demande(id: String)
var _mois := 0.0
var _caisse_ke := Ville.CAISSE_DEPART_KE
var _capital := Ville.CAPITAL_DEPART
var _cout_en_alerte := false

# La position posée par l'auteur et pas encore validée ; -1 = la fiche commande.
# ⚠️ Sans ce souvenir, `_maj_fiche()` (à chaque image) reposait la valeur sous
# le doigt et la barre était intraînable (défaut du 2026-08-17).
var _solaire_choix := -1.0
## 🏢 En BÂTIMENTS, pas en pourcents : c'est ce que le curseur compte, et c'est
## ce qui monte à l'écran. −1 = l'auteur n'y a pas touché.
var _dense_choix := -1.0
## Même mémoire, même raison, pour le curseur des toits verts.
var _vert_choix := -1.0
## Même mémoire, même raison, pour le curseur des arbres.
var _arbres_choix := -1.0
# Vrai pendant que la fiche écrit dans le curseur : une montée de `min_value`
# déplacerait la valeur et émettrait le signal, donc inventerait un choix.
var _ecrit_curseur := false
## La vue courante et son panneau. 🔴 Recliquer l'icône active REFERME le
## panneau, et c'est ici que ça se décide : `maquette._sur_theme` sort tout de
## suite quand le thème ne change pas, donc il ne rappellera pas `montrer_theme`.
var _theme_courant := ""
var _theme_actuel := {}
var _detail_ouvert := true
var _theme_ui: Theme
var _fonte_grasse: FontVariation
var _police: Font
var _fonte_texte: FontVariation
var _fonte_titre: FontVariation
var _icones := {}


func batir() -> void:
	_habiller()
	_police = _charger_police()
	# 🔴 TOUT EST PLUS GRAS DEPUIS LE 2026-09-20 (auteur, sur captures) : sur du
	# verre, un texte maigre disparaît dès qu'un toit rouge passe dessous. Le
	# corps du texte est déjà en demi-gras, et les trois graisses se suivent.
	_fonte_texte = _peser(_fiche.graisse_texte if VITRE else 600, 0.16)
	_fonte_titre = _peser(_fiche.graisse_titres if VITRE else 750, 0.38)
	_fonte_titre.spacing_glyph = 1
	# Les nombres du bilan sont gras : dans un panneau sans mots, c'est le seul
	# poids typographique qui dit lequel des trois éléments d'une ligne compte.
	_fonte_grasse = _peser(_fiche.graisse_boutons if VITRE else 700, 0.34)
	_theme_ui = _creer_theme()
	bulles.ui = self
	add_child(bulles)
	_panneau_bilan()
	_panneau_ilot()
	_panneau_lieu()
	_panneau_projets()
	_panneau_rail()
	_batir_fleche()
	_panneau_diagnostic()
	_panneau_chantiers()
	_panneau_calque()
	_panneau_camera()
	_controles_temps()
	_barre_compteurs()
	retours.batir(self)
	_sans_focus(self)


## L'habillage demandé : « vitre » par défaut, « bois » ou « verre » pour comparer.
func _habiller() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--habillage")
	var nom := args[i + 1] if i >= 0 and i + 1 < args.size() else "vitre"
	BOIS = nom == "bois"
	VITRE = nom == "vitre"
	if VITRE:
		_habiller_vitre()
	elif BOIS:
		_habiller_bois()


## Un angle arrondi des deux anciens habillages ; en vitre, la fiche le dose (0 = droit).
func _r(rayon: int) -> int:
	return roundi(rayon * _fiche.arrondi) if VITRE else rayon


## 🎨 LA FICHE DE L'AUTEUR : il règle l'habillage vitre dans l'inspecteur, sans code.
## Ses valeurs d'origine sont dans `habillage.gd` ; une fiche absente les rend.
const FICHE := "res://habillage.tres"
const Habillage := preload("res://scripts/habillage.gd")
var _fiche: Habillage = Habillage.new()


## 🔲 Les mêmes rôles de couleur, sur un verre neutre : une encre presque noire, le
## vert réservé au bouton qui engage, le choix posé en encre pleine.
func _habiller_vitre() -> void:
	if ResourceLoader.exists(FICHE):
		_fiche = load(FICHE) as Habillage
	var f := _fiche
	# 🔴 LEVEL DESIGN : sous 0,70 le texte se perd sur les toits rouges (2026-09-20).
	VERRE_TEINTE = f.verre
	Jauge.ARRONDI = _r(99)
	# 🔄 205,208,204 se perdait sur le verre (auteur, 2026-10-02) : la barre n'était qu'un bout orange.
	Jauge.RESTE = f.jauge_vide
	Pictos.PALE = f.pictos_pales
	FOND = f.fond_bulles
	FOND_FORT = f.fond_cartes
	TEXTE = f.encre
	GRIS = f.gris
	GRIS_FORT = f.gris_etiquettes
	ACCENT = f.accent
	ACCENT_VIF = f.vert
	FAIT_TEXTE = f.fini
	ALERTE = f.alerte
	APPEL = f.appel
	RAIL_SURVOL = f.rail_survol


## 🪵 L'habillage du 2026-09-28 : les mêmes rôles de couleur, en brun sur crème.
func _habiller_bois() -> void:
	# 🔄 Un peu de verre sous le crème (auteur, 2026-09-28), plus couvrant que le verre seul.
	VERRE_TEINTE = Color(Color8(255, 252, 247), 0.86)
	Jauge.RESTE = Color8(210, 192, 170)
	Pictos.PALE = Color8(206, 188, 166)
	FOND = Color8(248, 241, 232)
	FOND_FORT = Color8(236, 222, 206)
	TEXTE = Color8(78, 52, 40)
	GRIS = Color8(128, 104, 88)
	GRIS_FORT = Color8(110, 82, 66)
	ACCENT = Color8(112, 70, 48)
	ACCENT_VIF = Color8(92, 146, 66)
	FAIT_TEXTE = Color8(62, 118, 36)
	RAIL_SURVOL = Color8(236, 222, 204)


## L'arc et son losange au-dessus du titre d'une fiche, comme sur la référence.
func _ornement() -> Control:
	var o := Control.new()
	o.custom_minimum_size = Vector2(0, 20)
	o.mouse_filter = Control.MOUSE_FILTER_IGNORE
	o.draw.connect(func() -> void:
		var w := o.size.x
		var pts := PackedVector2Array()
		for k in 41:
			var t := float(k) / 40.0
			var u := t * 2.0 - 1.0
			pts.append(Vector2(lerpf(0.0, w, t), 18.0 - 12.0 * (1.0 - u * u)))
		o.draw_polyline(pts, BOIS_LISERE, 2.0, true)
		var m := Vector2(w * 0.5, 6.0)
		o.draw_colored_polygon(PackedVector2Array([m + Vector2(0, -5), m + Vector2(5, 0),
			m + Vector2(0, 5), m + Vector2(-5, 0)]), BOIS_LISERE))
	return o


## La police demandée, ou celle de Godot si le fichier manque — une police
## absente ne doit pas empêcher la maquette de s'ouvrir.
func _charger_police() -> Font:
	var nom: String = _fiche.police if VITRE else POLICE
	var args := OS.get_cmdline_user_args()
	var i := args.find("--police")
	if i >= 0 and i + 1 < args.size():
		nom = args[i + 1]
	var chemin := str(POLICES.get(nom, ""))
	if chemin == "" or not ResourceLoader.exists(chemin):
		if chemin != "":
			push_warning("police introuvable : %s" % chemin)
		return ThemeDB.fallback_font
	return load(chemin) as Font


## ⚠️ DEUX FAÇONS DE GRAISSER, ET UNE SEULE EST BONNE PAR POLICE : une police
## variable porte ses vrais dessins de graisse (`wght`) ; une police fixe n'a
## que le grossissement du contour, qui empâte. Les appliquer toutes les deux
## donnerait un gras double.
## 🔴 PIÈGE PAYÉ LE 2026-09-20 : `variation_opentype` n'accepte PAS `{"wght": …}`,
## la clé doit être le TAG ENTIER — mesuré, « Densifier » en 60 px fait 235 px
## avec la chaîne quel que soit le poids, 293 px avec le tag à 900. La graisse
## était silencieusement ignorée, et Rubik se dessinait à son défaut, 300.
func _peser(poids: int, grossir: float) -> FontVariation:
	var f := FontVariation.new()
	f.base_font = _police
	if _police != null and not _police.get_supported_variation_list().is_empty():
		var tag := TextServerManager.get_primary_interface().name_to_tag("wght")
		f.variation_opentype = {tag: poids}
	else:
		f.variation_embolden = grossir
	return f


## 🔴 Un bouton qui garde le focus MANGE le clavier du jeu : Espace le
## represse au lieu de mettre en pause, les flèches sautent au bouton voisin
## au lieu de tourner la caméra. Aucun champ de saisie ici — personne n'a
## besoin du focus.
func _sans_focus(n: Node) -> void:
	if n is Control:
		(n as Control).focus_mode = Control.FOCUS_NONE
	for e in n.get_children():
		_sans_focus(e)


const RAYON := 16
## L'état choisi du thème, repris par `_posee` sur les boutons qui ne basculent pas.
var _sb_choisi: StyleBoxFlat
const Verre := preload("res://shaders/verre.gdshader")


func _boite() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	# ⚠️ AUCUN FOND QUAND LE VERRE EST LÀ : le `StyleBox` se dessine PAR-DESSUS
	# le verre, et un fond même à moitié transparent rebouche le flou.
	sb.bg_color = Color(FOND, 0.0) if VERRE else FOND
	# 🔄 Plus de liseré (auteur, 2026-09-28) : seule l'ombre détache le panneau.
	sb.set_corner_radius_all(_r(RAYON))
	sb.set_content_margin_all(13)
	# L'ombre portée est ce qui décolle le panneau de la ville : à 3 px elle
	# n'existait pas, et tout avait l'air imprimé sur la carte.
	sb.shadow_color = Color(0.12, 0.10, 0.05, 0.18)
	sb.shadow_size = 16
	sb.shadow_offset = Vector2(0, 6)
	if BOIS:
		sb.border_color = BOIS_LISERE
		sb.set_border_width_all(2)
		sb.set_content_margin_all(14)
		# ⚠️ L'ombre d'un `StyleBox` se dessine AUSSI sous son fond, donc par-dessus
		# le verre, et grisait le crème de 245 à 220 : elle passe sous le verre (`_vitrer`).
		sb.shadow_size = 0
	if VITRE:
		# Le bord du verre : un pixel clair, aucune ombre.
		sb.shadow_size = 0
		sb.border_color = _fiche.lisere
		sb.set_border_width_all(_fiche.lisere_epaisseur)
		sb.set_content_margin_all(_fiche.marge_interieure)
	return sb


## 🔷 Le fond flouté d'un panneau. ⚠️ PIÈGES DÉJÀ PAYÉS : le conteneur range le
## verre avec le contenu, donc on le replace APRÈS son tri (`sort_children`) ; et
## pas de `top_level` : en coordonnées d'écran, il restait en place quand la pile
## bas-droite bougeait (chantiers, 2026-10-02). Le `z_index` négatif le met sous le panneau.
func _vitrer(p: Control, teinte := Color(0, 0, 0, 0), rayon := RAYON) -> void:
	if not VERRE:
		return
	if teinte.a == 0.0:
		teinte = VERRE_TEINTE
	rayon = _r(rayon)
	var fond := ColorRect.new()
	fond.name = "Verre"
	fond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fond.z_index = -1
	var mat := ShaderMaterial.new()
	mat.shader = Verre
	mat.set_shader_parameter("teinte", teinte)
	mat.set_shader_parameter("rayon", float(rayon))
	fond.material = mat
	p.add_child(fond)
	p.move_child(fond, 0)
	var ombre: Panel
	if BOIS:
		ombre = Panel.new()
		ombre.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ombre.z_index = -2
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0)
		sb.set_corner_radius_all(rayon)
		sb.shadow_color = Color(0.25, 0.12, 0.05, 0.28)
		sb.shadow_size = 12
		sb.shadow_offset = Vector2(0, 4)
		ombre.add_theme_stylebox_override("panel", sb)
		p.add_child(ombre)
		p.move_child(ombre, 0)
	var suivre := func() -> void:
		fond.position = Vector2.ZERO
		fond.size = p.size
		mat.set_shader_parameter("taille", fond.size)
		if ombre != null:
			ombre.position = Vector2.ZERO
			ombre.size = p.size
	p.item_rect_changed.connect(suivre)
	if p is Container:
		(p as Container).sort_children.connect(suivre)
	suivre.call()


## Le fond et le verre d'un coup : les quatorze panneaux du jeu passent par là.
## `cadre` : une barre (rail, compteurs, temps), cerclée de brun en habillage bois.
func _poser_boite(p: Control, cadre := false) -> void:
	p.theme = _theme_ui
	var sb := _boite()
	if BOIS and cadre:
		sb.border_color = BOIS_CADRE
		sb.set_border_width_all(7)
	p.add_theme_stylebox_override("panel", sb)
	_vitrer(p)


func _creer_theme() -> Theme:
	var t := Theme.new()
	# La police de TOUT ce qui hérite du thème : les panneaux la posent en même
	# temps que leur fond (`_poser_boite`), donc un seul endroit à changer.
	t.default_font = _fonte_texte
	var normal := StyleBoxFlat.new()
	# Sur du verre, un bouton n'est pas un aplat : c'est une plaque un peu plus
	# claire que le panneau, sinon il disparaît dans le fond flouté.
	normal.bg_color = Color8(255, 255, 255, 150)
	normal.border_color = Color8(255, 255, 255, 170)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(_r(9))
	normal.set_content_margin_all(9)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	var survol := normal.duplicate()
	survol.bg_color = Color8(226, 236, 214, 210)
	survol.border_color = Color(ACCENT_VIF, 0.85)
	# 🔧 Un réglage CHOISI est un vert pâle, pas le vert plein : le seul vert
	# plein du jeu est le bouton qui engage la caisse (`_habiller_principal`),
	# et deux pleins côte à côte ne disent plus lequel paie.
	var presse := normal.duplicate()
	presse.bg_color = Color8(208, 226, 196, 235)
	presse.border_color = Color(ACCENT_VIF, 0.9)
	var inactif := normal.duplicate()
	inactif.bg_color = Color8(240, 236, 226, 90)
	inactif.border_color = Color8(255, 255, 255, 80)
	var encre_choisie := ACCENT.darkened(0.25)
	if BOIS:
		# 🔄 Bordés et plus foncés (auteur, 2026-09-29 : « pas assez visibles ») ; le
		# 2026-09-28, sans liseré et à peine plus foncés que la fiche, ils s'y perdaient.
		# Le choix est en brun plein, comme la vue active du rail.
		for sb: StyleBoxFlat in [normal, survol, inactif]:
			sb.set_border_width_all(1)
		normal.bg_color = Color8(232, 218, 200)
		normal.border_color = Color8(196, 168, 142)
		survol.bg_color = Color8(222, 204, 180)
		survol.border_color = ACCENT
		presse.set_border_width_all(0)
		presse.bg_color = ACCENT
		inactif.bg_color = Color8(242, 235, 226)
		inactif.border_color = Color8(214, 198, 180)
		encre_choisie = BOIS_CREME
	if VITRE:
		# Le choix posé est en encre pleine ; le vert reste au bouton qui engage.
		normal.bg_color = _fiche.fond
		normal.border_color = _fiche.bord
		survol.bg_color = _fiche.fond_survol
		survol.border_color = _fiche.bord_survol
		presse.bg_color = _fiche.fond_choisi
		presse.border_color = _fiche.fond_choisi
		inactif.bg_color = _fiche.fond_grise
		inactif.border_color = _fiche.bord_grise
		encre_choisie = _fiche.encre_choisi
	_sb_choisi = presse
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", survol)
	t.set_stylebox("pressed", "Button", presse)
	t.set_stylebox("hover_pressed", "Button", presse)
	t.set_stylebox("disabled", "Button", inactif)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXTE)
	t.set_color("font_hover_color", "Button", TEXTE)
	t.set_color("font_pressed_color", "Button", encre_choisie)
	t.set_color("font_hover_pressed_color", "Button", encre_choisie)
	t.set_color("icon_pressed_color", "Button", encre_choisie)
	t.set_color("icon_hover_pressed_color", "Button", encre_choisie)
	# ⚠️ Un bouton grisé doit rester lisible : il dit ce qui manque (« Mettre en place »).
	t.set_color("font_disabled_color", "Button", GRIS)
	t.set_font("font", "Button", _fonte_grasse)
	t.set_font_size("font_size", "Button", _fiche.taille if VITRE else 14)
	t.set_constant("h_separation", "Button", 8)
	t.set_constant("icon_max_width", "Button", 30)
	# 🔄 Plus de trait entre les blocs (auteur, 2026-10-08) : l'espace suffit.
	var ligne := StyleBoxEmpty.new()
	ligne.content_margin_top = 5
	ligne.content_margin_bottom = 5
	t.set_stylebox("separator", "HSeparator", ligne)
	return t


## 🔄 PLUS DE CAPITALES ESPACÉES DANS LES PANNEAUX (auteur, 2026-09-24 : « ça
## fait très IA ») : une étiquette est en casse normale, grasse et grise — c'est
## le gris et la taille qui la distinguent de la valeur. Le rail garde les siennes.
func _etiquette(txt: String, taille: int, coul: Color) -> Label:
	var l := _label(txt, taille, coul)
	l.add_theme_font_override("font", _fonte_grasse)
	return l


## L'autre moitié de la règle : ce qui NOMME. Casse normale, gras, plus grand.
func _titre(txt: String, taille: int, coul: Color) -> Label:
	var l := _label(txt, taille, coul)
	l.add_theme_font_override("font", _fonte_grasse)
	return l


## Le titre d'un panneau : le nom seul, vert foncé, sur le verre. 🔄 Plus de plaque
## ni de filet azur à gauche (auteur, 2026-09-24) : le filet se courbait dans
## le coin arrondi et décalait le nom du bord commun.
func _bandeau(parent: Control, txt: String) -> Label:
	var l := _titre(txt, 19, ACCENT)
	if BOIS:
		parent.add_child(_ornement())
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l


## Le titre d'un bloc DANS la fiche : l'étiquette seule, sans filet.
func _titre_section(parent: Control, txt: String) -> Label:
	var l := _etiquette(txt, 12, GRIS_FORT)
	parent.add_child(l)
	return l


# ==========================================================================
# 🗂️ LA FICHE À ONGLETS (auteur, 2026-09-18)
# ==========================================================================

## 🔴 L'ORDRE EST CELUI DE LA PRIORITÉ, pas seulement celui de la rangée : le
## premier onglet disponible s'ouvre, donc un îlot sinistré s'ouvre sur la crue
## et un champ sur la campagne. Trois colonnes : l'identifiant, le dessin, le
## mot de l'infobulle — l'onglet n'affiche que l'icône.
## 🔴 L'ORTHOGRAPHE DES TISSUS, ET RIEN D'AUTRE : la chaîne les exporte sans
## accent (`ilot_compact`), et « ilot compact » sous le nom d'un lieu se lit
## comme une faute. La TABLE des tissus, elle, est du level design et reste
## dans `QGIS/scripts/`. À corriger à la main si un mot ne convient pas.
const TISSUS := {
	"maisons_de_ville": "maisons de ville",
	"coeur_ancien": "cœur ancien",
	"front_commercant": "front commerçant",
	"ilot_compact": "îlot compact",
	"place_minerale": "place minérale",
	"friche_industrielle": "friche industrielle",
	"jardins_familiaux": "jardins familiaux",
	"equipement": "équipement",
	"riviere": "rivière",
}


const ONGLETS := [
	["crue", "dangers", "Après la crue"],
	["campagne", "nourriture", "Campagne"],
	["bati", "logement", "Bâti"],
	["trafic", "trafic", "Voitures"],
	["berge", "eau", "Berge"],
	["energie", "energie", "Énergie"],
	["vert", "feuille", "Vert"],
]


## 🗂️ UNE TUILE : l'étiquette au-dessus, le nombre en dessous, tout collé à
## gauche. 🔄 REMPLACE LA GRILLE « étiquette à gauche, valeur à droite » : sur
## 310 px, « Toit ········ 0 m² » creusait un vide au milieu de chaque ligne,
## et c'est ce vide que l'auteur a refusé le 2026-09-18.
func _tuile(parent: GridContainer, etiquette: String, valeurs: Dictionary,
		cle: String) -> void:
	# 🔄 Sur une plaque blanche (auteur, 2026-09-28, image de référence).
	var plaque := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color8(255, 255, 255, 150)
	sb.set_corner_radius_all(_r(10))
	sb.set_content_margin_all(8)
	if BOIS:
		sb.bg_color = Color8(255, 252, 247, 200)
		sb.border_color = Color8(224, 206, 186)
		sb.set_border_width_all(1)
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	plaque.add_theme_stylebox_override("panel", sb)
	plaque.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(plaque)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	plaque.add_child(v)
	v.add_child(_etiquette(etiquette, 11, GRIS_FORT))
	var l := _label("", 14, TEXTE)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
	valeurs[cle] = l


## La clé d'une grille est `onglet_couche` : « après la crue » ne dit pas la
## même chose d'un îlot et d'une rue.
func _grille_onglet(parent: Control, cle: String, colonnes: int,
		valeurs: Dictionary, lignes: Array) -> void:
	var g := GridContainer.new()
	g.columns = colonnes
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6)
	g.visible = false
	parent.add_child(g)
	for l in lignes:
		_tuile(g, l[1], valeurs, l[0])
	_onglet_grilles[cle] = g


func ouvrir_onglet(id: String) -> void:
	_onglet_actif = id
	_appliquer_onglets()
	_clamper_fiche()


## 🔄 UN SEUL TRAIT SOUS TOUTE LA RANGÉE (auteur, 2026-09-24) : l'onglet ouvert
## n'a pas de plaque, seulement la couleur de son icône et un soulignement de 2 px.
## ⚠️ Rangée à `separation` 0, sinon le trait se coupe entre deux onglets.
func _habiller_onglet(b: Button, ouvert: bool, dessin: String) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.set_content_margin_all(4)
	sb.border_width_bottom = 2 if ouvert else 1
	sb.border_color = ACCENT_VIF if ouvert else (BOIS_LISERE if BOIS else Color8(180, 170, 146, 160))
	var survol := sb.duplicate()
	survol.bg_color = Color(FOND_FORT, 0.5) if not ouvert else Color(0, 0, 0, 0)
	for etat in ["normal", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(etat, sb)
	b.add_theme_stylebox_override("hover", survol)
	b.add_theme_stylebox_override("hover_pressed", survol)
	b.icon = _icone(dessin, 27, ACCENT if ouvert else GRIS)


## Ce que l'objet courant mérite comme onglets. Un onglet qui ne dirait rien
## n'existe pas : il ne se grise pas — un onglet gris est une porte fermée,
## une absence est une priorité.
func _calculer_dispo() -> Dictionary:
	var d := {}
	var fid := _fiche_fid
	if _fiche_couche == "i":
		var champ := ville.est_champ(fid)
		d["crue"] = bool(_bloc_dispo.get(_repare_bloc, false))
		d["campagne"] = champ
		d["bati"] = not champ
		d["energie"] = ville.valeur("i", fid, "_toit_equipable_m2", _mois) > 0.0
		d["vert"] = ville.valeur("i", fid, "_part_plate", _mois) > 0.001 \
			or ville.permeable_possible(fid)
	elif _fiche_couche == "r":
		d["crue"] = bool(_bloc_dispo.get(_repare_bloc, false))
		d["trafic"] = true
		d["vert"] = ville.arbres_plantables(fid) > 0
	elif _fiche_couche == "b":
		d["berge"] = true
	# 🏕️ PENDANT L'URGENCE, IL N'Y A QU'UN THÈME : reloger. C'est ce qui rend
	# un îlot bâti muet et oriente vers les champs sans les désigner.
	# 🌉 Puis un seul : la crue, sur un pont coupé ou une rue qui y mène.
	var verrou := _verrou()
	var garde: String = {"reloger": "campagne", "pont": "crue"}.get(verrou, "")
	# 🚿 Le camp habité garde ses demandes pendant le chantier du pont.
	if verrou == "pont" and _fiche_couche == "i" and ville.camp_pose(fid):
		garde = "campagne"
	var permis := verrou == "" or _autorise(_fiche_couche, fid)
	for id in d.keys():
		if not d[id] or not permis or (garde != "" and id != garde):
			d.erase(id)
	return d


func _campement() -> bool:
	return _fiche_couche == "i" and _fiche_fid >= 0 and ville.est_campement(_fiche_fid, _mois)


## Ce qui s'affiche, une fois `_dispo` connu. Trois choses : les boutons, la
## grille de l'onglet ouvert, et les blocs de réglage rangés sous leur thème.
func _appliquer_onglets() -> void:
	# On GARDE l'onglet d'avant tant qu'il existe sur le nouvel objet : comparer
	# deux îlots sur l'énergie ne doit pas coûter un clic par îlot.
	if not _dispo.get(_onglet_actif, false):
		_onglet_actif = ""
		for ligne in ONGLETS:
			if _dispo.get(ligne[0], false):
				_onglet_actif = ligne[0]
				break
	for ligne in ONGLETS:
		var id: String = ligne[0]
		var b: Button = _onglet_boutons[id]
		b.visible = bool(_dispo.get(id, false))
		if b.visible:
			_habiller_onglet(b, id == _onglet_actif,
				"camp" if id == "campagne" and _campement() else ligne[1])
	# Un onglet seul n'est pas un choix : la rangée disparaît (la berge).
	_onglets.visible = _dispo.size() > 1
	var ouverte := "%s_%s" % [_onglet_actif, _fiche_couche]
	if ouverte == "campagne_i" and _campement():
		ouverte = "campement_i"
	for cle in _onglet_grilles:
		(_onglet_grilles[cle] as Control).visible = cle == ouverte
	for bloc in _bloc_onglet:
		(bloc as Control).visible = bool(_bloc_dispo.get(bloc, false)) 			and String(_bloc_onglet[bloc]) == _onglet_actif


## 🔢 CE QUE L'OBJET REND, EN UNE LIGNE. Un îlot compte des logements, un champ
## des repas, une rue des voitures : une unité, jamais deux à la fois.
func _maj_resume(dessin: String, texte: String) -> void:
	if dessin != _resume_dessin:
		_resume_dessin = dessin
		_resume_icone.texture = _icone(dessin, 23, ACCENT)
	_resume_texte.text = texte
	_resume_ligne.visible = true


## 🔴 LA TABLE DES DESSINS EST HORS DE `_icone` depuis le 2026-09-17 : les
## pastilles posées sur la ville (`pastilles.gd`) y puisent pour fabriquer leur
## propre image, contour compris. Deux tables finiraient par diverger.
const DESSINS := {
	"ville": "<path d='M3 21h18M5 21V9h5v12M10 21V4h6v17M16 21v-9h4v9M7 12h1m-1 3h1m-1 3h1m5-11h1m-1 4h1m-1 4h1m4 0h1m-1 3h1'/>",
	"diagnostic": "<path d='M4 20h16M6 18v-6h3v6m3 0V6h3v12m3 0v-9h3v9'/>",
	"adaptation": "<path d='M12 3l7 3v5c0 5-3 8-7 10-4-2-7-5-7-10V6l7-3zM8 12c2-2 6-2 8 0m-8 3c2-2 6-2 8 0'/>",
	"reduction": "<path d='M20 4C10 4 5 9 5 15c0 3 2 5 5 5 7 0 10-8 10-16zM5 20c3-6 7-9 12-12'/>",
	"conso": "<path d='M13 2L5 14h6l-1 8 9-13h-6V2z'/>",
	"production": "<circle cx='12' cy='12' r='4'/><path d='M12 2v3m0 14v3M2 12h3m14 0h3M5 5l2 2m10 10l2 2M19 5l-2 2M7 17l-2 2'/>",
	"achat": "<path d='M9 3v7m6-7v7m-8 0h10v2a5 5 0 01-5 5v4m-3 0h6'/>",
	"co2": "<path d='M7 18h11a4 4 0 000-8 6 6 0 00-11-2 5 5 0 000 10z'/>",
	# 🗳️ Lucide « vote » : le capital politique.
	"capital": "<path d='M9 12l2 2 4-4'/><path d='M5 7c0-1.1.9-2 2-2h10a2 2 0 012 2v12H5V7z'/><path d='M22 19H2'/>",
	"caisse": "<circle cx='12' cy='12' r='9'/><path d='M15 8c-1-1-5-1-5 1 0 3 5 1 5 4 0 2-4 3-6 1m3-9v14'/>",
	"dangers": "<path d='M12 3L2 21h20L12 3zm0 6v5m0 3v1'/>",
	"chantiers": "<rect x='2' y='6' width='20' height='8' rx='1'/><path d='M17 14v7M7 14v7M17 3v3M7 3v3M10 14L2.3 6.3M14 6l7.7 7.7M8 6l8 8'/>",
	"energie": "<path d='M13 2L5 14h6l-1 8 9-13h-6V2z'/>",
	# 🌾 Lucide « wheat » : ce que les champs nourrissent (sans dessin, l'onglet Campagne prenait le diagnostic).
	"nourriture": "<path d='M2 22L16 8'/><path d='M3.47 12.53L5 11l1.53 1.53a3.5 3.5 0 010 4.94L5 19l-1.53-1.53a3.5 3.5 0 010-4.94z'/><path d='M7.47 8.53L9 7l1.53 1.53a3.5 3.5 0 010 4.94L9 15l-1.53-1.53a3.5 3.5 0 010-4.94z'/><path d='M11.47 4.53L13 3l1.53 1.53a3.5 3.5 0 010 4.94L13 11l-1.53-1.53a3.5 3.5 0 010-4.94z'/><path d='M20 2h2v2a4 4 0 01-4 4h-2V6a4 4 0 014-4z'/><path d='M11.47 17.47L13 19l-1.53 1.53a3.5 3.5 0 01-4.94 0L5 19l1.53-1.53a3.5 3.5 0 014.94 0z'/><path d='M15.47 13.47L17 15l-1.53 1.53a3.5 3.5 0 01-4.94 0L9 15l1.53-1.53a3.5 3.5 0 014.94 0z'/><path d='M19.47 9.47L21 11l-1.53 1.53a3.5 3.5 0 01-4.94 0L13 11l1.53-1.53a3.5 3.5 0 014.94 0z'/>",
	# 🌉 Deux moignons de tablier cassés net au-dessus de l'eau : le pont emporté.
	"pont_casse": "<path fill='@' stroke-width='1' d='M0 6h10l-1.8 2.2 1.8 2.3H0zM24 6H14l1.8 2.2-1.8 2.3H24zM10.6 13.2l2.6.6-.6 2.6-2.6-.6z'/><path d='M4 10.5v5.5M20 10.5v5.5M1 20c1.8-1.3 3.7-1.3 5.5 0s3.7 1.3 5.5 0 3.7-1.3 5.5 0 3.7 1.3 5.5 0'/>",
	"pont": "<path d='M2 9h20M5 9v10M19 9v10M5 16c3-5 11-5 14 0'/>",
	# Lucide « clock » et « rotate-ccw » : la durée et l'annulation des réglages.
	"duree": "<circle cx='12' cy='12' r='9'/><path d='M12 7v5l3 2'/>",
	"annuler": "<path d='M3 12a9 9 0 109-9 9.75 9.75 0 00-6.74 2.74L3 8'/><path d='M3 3v5h5'/>",
	"trafic": "<path d='M5 17h14l-1-6-2-3H8l-2 3-1 6zm1 0v3m12-3v3M7 13h10M8 17h1m6 0h1'/>",
	"tissu": "<path d='M3 3h7v7H3zM14 3h7v7h-7zM3 14h7v7H3zM14 14h7v7h-7z'/>",
	# 💧 Lucide « droplets » : la carte des sols (101).
	"sols": "<path d='M7 16.3c2.2 0 4-1.83 4-4.05 0-1.16-.57-2.26-1.71-3.19S7.29 6.75 7 5.3c-.29 1.45-1.14 2.84-2.29 3.76S3 11.1 3 12.25c0 2.22 1.8 4.05 4 4.05z'/><path d='M12.56 6.6A10.97 10.97 0 0014 3.02c.5 2.5 2 4.9 4 6.5s3 3.5 3 5.5a6.98 6.98 0 01-11.91 4.97'/>",
	# 🏛️🎓 Les deux lieux du rail (Lucide « landmark », « graduation-cap ») :
	# sans dessin, ils prenaient celui du diagnostic, deux fois.
	# Lucide « book-open » : DÉBUT rouvre le récit des premiers pas.
	"debut": "<path d='M12 7v14M3 18a1 1 0 01-1-1V4a1 1 0 011-1h5a4 4 0 014 4 4 4 0 014-4h5a1 1 0 011 1v13a1 1 0 01-1 1h-6a3 3 0 00-3 3 3 3 0 00-3-3z'/>",
	"mairie": "<path d='M3 22h18M6 18v-7m4 7v-7m4 7v-7m4 7v-7M12 2l8 5H4z'/>",
	# Lucide « flask-conical » et « library » : l'institut et la bibliothèque du campus.
	"institut": "<path d='M14 2v6a2 2 0 00.245.96l5.51 10.08A2 2 0 0118 22H6a2 2 0 01-1.755-2.96l5.51-10.08A2 2 0 0010 8V2M6.453 15h11.094M8.5 2h7'/>",
	"bibliotheque": "<path d='M16 6l4 14M12 6v14M8 8v12M4 4v16'/>",
	"universite": "<path d='M21.42 10.922a1 1 0 00-.019-1.838L12.83 5.18a2 2 0 00-1.66 0L2.6 9.08a1 1 0 000 1.832l8.57 3.908a2 2 0 001.66 0zM22 10v6M6 12.5V16a6 3 0 0012 0v-3.5'/>",
	# 🗂️ LES TROIS DESSINS DES ONGLETS DE FICHE (auteur, 2026-09-18), repris de
	# Lucide (licence ISC) comme le reste de la table : même grille 24, même
	# trait. L'immeuble ne reprend pas « ville » — une silhouette de commune sur
	# la fiche d'UN îlot désignerait le mauvais objet.
	"logement": "<rect x='4' y='2' width='16' height='20' rx='2'/><path d='M9 22v-3a1 1 0 011-1h4a1 1 0 011 1v3'/><path d='M8 6h.01M12 6h.01M16 6h.01M8 10h.01M12 10h.01M16 10h.01M8 14h.01M12 14h.01M16 14h.01'/>",
	"feuille": "<path d='M11 20a10 10 0 0010-10 25.9 25.9 0 00-1.04-7.281 1 1 0 00-1.755-.325C15.833 5.5 13 5.5 9.8 6.1A7 7 0 0011 20'/><path d='M2 21a5 5 0 012.911-4.544C7.613 15.212 8.351 15.24 11 13'/>",
	"eau": "<path d='M2 6c.6.5 1.2 1 2.5 1 2.5 0 2.5-2 5-2 2.6 0 2.4 2 5 2 2.5 0 2.5-2 5-2 1.3 0 1.9.5 2.5 1'/><path d='M2 12c.6.5 1.2 1 2.5 1 2.5 0 2.5-2 5-2 2.6 0 2.4 2 5 2 2.5 0 2.5-2 5-2 1.3 0 1.9.5 2.5 1'/><path d='M2 18c.6.5 1.2 1 2.5 1 2.5 0 2.5-2 5-2 2.6 0 2.4 2 5 2 2.5 0 2.5-2 5-2 1.3 0 1.9.5 2.5 1'/>",
	# ⏯️ Les commandes du temps et de la caméra en icônes (auteur, 2026-09-28),
	# Lucide : pause, play, skip-back, save, folder-open, map, box, history.
	"pause": "<rect x='14' y='4' width='4' height='16' rx='1'/><rect x='6' y='4' width='4' height='16' rx='1'/>",
	"lecture": "<path fill='@' d='M6 3l14 9-14 9z'/>",
	"mois_zero": "<path d='M19 20L9 12l10-8zM5 19V5'/>",
	"sauver": "<path d='M15.2 3a2 2 0 011.4.6l3.8 3.8a2 2 0 01.6 1.4V19a2 2 0 01-2 2H5a2 2 0 01-2-2V5a2 2 0 012-2z'/><path d='M17 21v-7a1 1 0 00-1-1H8a1 1 0 00-1 1v7M7 3v4a1 1 0 001 1h7'/>",
	"ouvrir": "<path d='M6 14l1.5-2.9A2 2 0 019.24 10H20a2 2 0 011.94 2.5l-1.54 6a2 2 0 01-1.95 1.5H4a2 2 0 01-2-2V5a2 2 0 012-2h3.9a2 2 0 011.69.9l.81 1.2a2 2 0 001.67.9H18a2 2 0 012 2v2'/>",
	# L'aiguille : moitié nord pleine. `_icone(…, angle)` la tourne vers le nord.
	"boussole": "<path fill='@' d='M12 2l4.5 10h-9z'/><path d='M7.5 12L12 22l4.5-10'/>",
	"plan": "<path d='M14.1 5.55a2 2 0 001.8 0l3.65-1.83A1 1 0 0121 4.62v12.76a1 1 0 01-.55.9l-4.55 2.27a2 2 0 01-1.8 0L9.9 18.45a2 2 0 00-1.8 0l-3.65 1.83A1 1 0 013 19.38V6.62a1 1 0 01.55-.9l4.55-2.27a2 2 0 011.8 0zM15 5.76v15M9 3.24v15'/>",
	"cube": "<path d='M21 8a2 2 0 00-1-1.73l-7-4a2 2 0 00-2 0l-7 4A2 2 0 003 8v8a2 2 0 001 1.73l7 4a2 2 0 002 0l7-4A2 2 0 0021 16z'/><path d='M3.3 7L12 12l8.7-5M12 22V12'/>",
	"croix": "<path d='M18 6L6 18M6 6l12 12'/>",
	"camp": "<path d='M3.5 21L14 3M20.5 21L10 3M15.5 21L12 15l-3.5 6M2 21h20'/>",
	"journal": "<path d='M3 12a9 9 0 109-9 9.75 9.75 0 00-6.74 2.74L3 8'/><path d='M3 3v5h5'/><path d='M12 7v5l4 2'/>",
}


func _icone(nom: String, taille := 25, coul := TEXTE, angle := 0) -> Texture2D:
	var cle := "%s_%d_%s_%d" % [nom, taille, coul.to_html(false), angle]
	if _icones.has(cle):
		return _icones[cle]
	# 🎨 `@` = LA COULEUR DU TRAIT : c'est ce qui permet un aplat (`fill='@'`)
	# dans une table qui est sinon tout en traits.
	var corps: String = str(DESSINS.get(nom, DESSINS["diagnostic"])) 		.replace("@", "#" + coul.to_html(false))
	if angle != 0:
		corps = "<g transform='rotate(%d 12 12)'>%s</g>" % [angle, corps]
	var svg := "<svg xmlns='http://www.w3.org/2000/svg' width='24' height='24' viewBox='0 0 24 24' fill='none' stroke='#%s' stroke-width='2.0' stroke-linecap='round' stroke-linejoin='round'>%s</svg>" % [coul.to_html(false), corps]
	var img := Image.new()
	var erreur := img.load_svg_from_string(svg, float(taille) / 24.0)
	if erreur != OK:
		return null
	var texture := ImageTexture.create_from_image(img)
	_icones[cle] = texture
	return texture


## L'icône dans sa pastille teintée : c'est elle qui remplace le mot. Le fond
## reprend la couleur du compteur à 15 % — assez pour retrouver la caisse ou le
## CO₂ du coin de l'œil, trop peu pour concurrencer le nombre.
func _puce(nom: String, teinte: Color, taille := 26) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	# 🔲 Nue en vitre : la pastille teintée faisait partie du « trop IA ».
	sb.bg_color = Color(teinte, 0.0 if VITRE else 0.15)
	sb.set_corner_radius_all(_r(9))
	sb.set_content_margin_all(6)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pic := TextureRect.new()
	pic.texture = _icone(nom, taille, teinte)
	pic.custom_minimum_size = Vector2(taille, taille)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(pic)
	return p


## Tous les panneaux de détail occupent LA MÊME case, à droite du rail : ils se
## remplacent, ils ne s'empilent pas.
func _ancrer_detail(p: Control) -> void:
	p.offset_left = DETAIL_X
	p.offset_right = DETAIL_X + DETAIL_LARGEUR
	p.offset_top = HAUT


## Une tuile du rail : transparente, icône et mot. L'accent de l'état enfoncé
## est celui du bouton qui engage la caisse — un seul accent dans le jeu.
func _habiller_tuile_rail(b: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0)
	normal.set_corner_radius_all(_r(12))
	normal.set_content_margin_all(6)
	var survol := normal.duplicate() as StyleBoxFlat
	survol.bg_color = RAIL_SURVOL
	var presse := normal.duplicate() as StyleBoxFlat
	presse.bg_color = ACCENT_VIF
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", survol)
	b.add_theme_stylebox_override("pressed", presse)
	b.add_theme_stylebox_override("hover_pressed", presse)
	# ⚠️ Sans lui, le thème dessine un cadre pointillé autour de la mairie et
	# de l'université verrouillées : la tuile pâlit, elle ne change pas de forme.
	var eteint := normal.duplicate() as StyleBoxFlat
	eteint.bg_color = Color(0, 0, 0, 0)
	b.add_theme_stylebox_override("disabled", eteint)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var enfonce := Color.WHITE
	if BOIS:
		# 🔄 Le rail d'avant (auteur, 2026-09-28) : icônes nues, la vue active en brun plein.
		presse.bg_color = ACCENT
		enfonce = BOIS_CREME
	elif VITRE:
		presse.bg_color = TEXTE
	for etat in ["font_color", "font_hover_color", "icon_normal_color", "icon_hover_color"]:
		b.add_theme_color_override(etat, TEXTE)
	for etat in ["font_pressed_color", "font_hover_pressed_color", "icon_pressed_color",
			"icon_hover_pressed_color"]:
		b.add_theme_color_override(etat, enfonce)
	b.add_theme_color_override("font_disabled_color", Color(TEXTE, 0.3))
	b.add_theme_color_override("icon_disabled_color", Color(TEXTE, 0.3))
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 48)


## Le curseur par défaut de Godot est un trait gris sans remplissage : on y lit
## une position, pas une quantité.
func _habiller_curseur(s: HSlider) -> void:
	var gouttiere := StyleBoxFlat.new()
	gouttiere.bg_color = Jauge.RESTE
	gouttiere.set_corner_radius_all(_r(3))
	# ⚠️ Chez Slider, c'est la MARGE de la boîte qui fait l'épaisseur du rail :
	# il n'y a pas de hauteur à régler ailleurs.
	gouttiere.content_margin_top = 3.0
	gouttiere.content_margin_bottom = 3.0
	s.add_theme_stylebox_override("slider", gouttiere)

	var rempli := StyleBoxFlat.new()
	rempli.bg_color = Color(ACCENT_VIF, 0.75)
	rempli.set_corner_radius_all(_r(3))
	rempli.content_margin_top = 3.0
	rempli.content_margin_bottom = 3.0
	s.add_theme_stylebox_override("grabber_area", rempli)
	s.add_theme_stylebox_override("grabber_area_highlight", rempli)

	var poignee := _pastille(ACCENT)
	s.add_theme_icon_override("grabber", poignee)
	s.add_theme_icon_override("grabber_highlight", poignee)
	s.add_theme_icon_override("grabber_disabled", _pastille(GRIS.darkened(0.4)))


static func _pastille(coul: Color) -> ImageTexture:
	var img := Image.create_empty(7, 20, false, Image.FORMAT_RGBA8)
	img.fill(coul)
	return ImageTexture.create_from_image(img)


## Pour `retours.gd`, qui n'atteint pas la classe interne.
func _jauge_chantier() -> Control:
	var j := Jauge.new()
	j.custom_minimum_size = Vector2(0, 7)
	j.mouse_filter = Control.MOUSE_FILTER_IGNORE
	j.colorer(EN_TRAVAUX)
	return j


func _label(txt: String, taille: int, coul: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", coul)
	return l


## 🔄 LE BANDEAU DE NEUF TUILES EST DEVENU CE PANNEAU (2026-09-03) : il s'ouvre
## à côté du rail, sur l'icône VILLE. Une ligne = une pastille, une jauge, un
## nombre ; le mot est dans l'infobulle. Rien de neuf n'est mesuré — ce sont les
## sept mêmes chiffres, rangés.
func _panneau_bilan() -> void:
	var p := PanelContainer.new()
	p.theme = _theme_ui
	_poser_boite(p)
	_ancrer_detail(p)
	add_child(p)
	_ville_panneau = p

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 9)
	p.add_child(v)

	# 🔧 UNE TEINTE PAR COMPTEUR, et c'est ce qui distingue un tableau de bord
	# de jeu d'un tableau : on retrouve la caisse à la couleur, pas au mot.
	_titre_section(v, "Données")
	var adaptation := _ligne_bilan(v, "adaptation", Color8(46, 122, 146),
		"Adaptation — la part de la ville relevée après la crue.", true, "adaptation")
	_adaptation_jauge = adaptation["jauge"]
	_adaptation_valeur = adaptation["valeur"]
	_adaptation_pictos = adaptation["pictos"]
	var reduction := _ligne_bilan(v, "reduction", Color8(88, 128, 60),
		"Réduction — la part des émissions déjà évitées.", true, "reduction")
	_reduction_jauge = reduction["jauge"]
	_reduction_valeur = reduction["valeur"]
	_reduction_pictos = reduction["pictos"]

	_titre_section(v, "Énergie")
	for ligne in [
		["conso", "conso", Color8(198, 126, 32),
			"Ce que la ville consomme. La jauge se lit contre le mois 0."],
		["production", "production", Color8(214, 158, 44),
			"Ce que les panneaux produisent, sur la consommation de la ville."],
		["achat", "achat", Color8(122, 112, 96),
			"Ce qu'il faut encore acheter au réseau."],
		["co2", "co2", Color8(104, 116, 108),
			"Les émissions de l'électricité achetée. La jauge se lit contre le mois 0."],
	]:
		var l := _ligne_bilan(v, ligne[1], ligne[2], ligne[3], true)
		_ville_valeurs[ligne[0]] = l["valeur"]
		_ville_jauges[ligne[0]] = l["jauge"]

	# 🌾 LA CAMPAGNE : ce que les champs nourrissent, et ce que la ville achète
	# pour le reste. Un champ bâti ne se rend pas ; un champ recultivé, si.
	_titre_section(v, "Campagne")
	var nourriture := _ligne_bilan(v, "nourriture", Color8(150, 128, 44),
		"Ce que les champs de Wehrau nourrissent, sur les 5 350 habitants. Bâtir un champ le retire pour de bon ; le maraîchage et le verger en nourrissent plus.", true)
	_ville_valeurs["nourriture"] = nourriture["valeur"]
	_ville_jauges["nourriture"] = nourriture["jauge"]
	var achats := _ligne_bilan(v, "achat", Color8(122, 112, 96),
		"Ce que la ville paie chaque mois pour nourrir ceux que ses champs ne nourrissent pas. La dotation couvre déjà celui du mois 0 : la caisse ne voit que l'écart.", false)
	_ville_valeurs["achat_nourriture"] = achats["valeur"]

	var titre_caisse := _titre_section(v, "Caisse")
	# Pas de jauge : une caisse n'a pas de plein. Le nombre prend toute la
	# largeur, et la recette reste son petit écart, comme dans la référence.
	var caisse := _ligne_bilan(v, "caisse", Color8(78, 121, 67),
		"La caisse, et ce que le solaire lui rapporte chaque année.", false)
	_ville_valeurs["caisse"] = caisse["valeur"]
	(caisse["valeur"] as Label).add_theme_color_override("font_color", ACCENT)
	(caisse["valeur"] as Label).add_theme_font_size_override("font_size", 20)
	var recette := _label("", 11, Color8(78, 121, 67))
	recette.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	(caisse["colonne"] as VBoxContainer).add_child(recette)
	_ville_valeurs["recette"] = recette
	# 🗳️ Un compteur, pas une jauge (58) : un stock n'a pas de plein.
	var capital := _ligne_bilan(v, "capital", Color8(122, 84, 48),
		"La confiance des habitants. Retirer des places en coûte tout de suite ; des habitants qui rentrent chez eux, un pont rouvert en rendent à la livraison.", false)
	_ville_valeurs["capital"] = capital["valeur"]
	# 🔲 En vitre, la caisse et la confiance ne se lisent qu'en haut (auteur, 2026-10-02).
	if VITRE:
		for n: Control in [titre_caisse, (caisse["colonne"] as Control).get_parent(),
				(capital["colonne"] as Control).get_parent()]:
			n.visible = false

	# 🧪 LE BOUTON D'ESSAI, ET IL DIT QU'IL EN EST UN. Il sert à atteindre en un
	# clic un état que vingt ans de dotation mettraient à payer — donc à juger
	# une ville équipée, pas à juger l'économie.
	# À retirer en même temps que `ville.crediter_essai_ke`.
	var triche := Button.new()
	triche.text = "Essai · +1 000 k€"
	triche.theme = _theme_ui
	triche.focus_mode = Control.FOCUS_NONE
	triche.add_theme_font_size_override("font_size", 11)
	triche.add_theme_color_override("font_color", GRIS)
	triche.tooltip_text = "Outil d'essai : remplit la caisse, hors règles du jeu."
	triche.pressed.connect(func() -> void:
		ville.crediter_essai_ke(1000.0)
		_message.text = "Essai : 1 000 k€ versés.")
	v.add_child(triche)
	triche.visible = "--outils" in OS.get_cmdline_user_args()


## Une ligne du bilan : la pastille dit QUOI, la jauge dit OÙ ON EN EST, le
## nombre dit COMBIEN. Les pastilles du dessous comptent la même part en jetons
## — c'est ce qui remplace la phrase qui traînait sous les deux jauges de climat.
func _ligne_bilan(parent: VBoxContainer, icone: String, teinte: Color,
		bulle: String, avec_jauge := true, pictos := "") -> Dictionary:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.tooltip_text = bulle
	# 🔴 La ligne est la SEULE à prendre la souris : sans ça l'infobulle
	# n'existe pas, et avec elle sur les enfants elle clignoterait.
	h.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(h)
	h.add_child(_puce(icone, teinte))

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(col)

	var rang := HBoxContainer.new()
	rang.add_theme_constant_override("separation", 10)
	rang.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(rang)
	var jauge: Jauge = null
	if avec_jauge:
		jauge = Jauge.new()
		jauge.custom_minimum_size = Vector2(0, 6 if VITRE else 10)
		jauge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		jauge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		jauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		jauge.colorer(teinte)
		rang.add_child(jauge)
	var valeur := _label("—", 15, TEXTE)
	valeur.add_theme_font_override("font", _fonte_grasse)
	valeur.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# ⚠️ Sans jauge, le nombre prend la ligne ; avec, il garde 104 px fixes et
	# c'est la jauge qui s'étire — sinon les deux se partagent la place et
	# aucune colonne de nombres n'est alignée d'une ligne à l'autre.
	valeur.size_flags_horizontal = Control.SIZE_FILL if avec_jauge \
		else Control.SIZE_EXPAND_FILL
	valeur.custom_minimum_size.x = 104
	rang.add_child(valeur)

	var jetons: Pictos = null
	if pictos != "":
		jetons = Pictos.new()
		jetons.texture = _icone(pictos, 15, Color.WHITE)
		jetons.teinte = teinte
		jetons.custom_minimum_size = Vector2(0, 15)
		jetons.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# 🔲 Les jetons redisent la jauge : retirés en vitre.
		jetons.visible = not VITRE
		col.add_child(jetons)
	return {"valeur": valeur, "jauge": jauge, "pictos": jetons, "colonne": col}


# ============================================== LA DEUXIÈME VUE, ET SON MENU
#
# 🩶 La ville vivante d'un côté, le diagnostic de l'autre (2026-08-25). Le rail
# porte le choix, et un seul panneau de détail est ouvert à la fois : deux vues,
# jamais deux tableaux de bord à l'écran ensemble.


## 🔄 LA BARRE DU BAS EST DEVENUE UNE COLONNE À GAUCHE (2026-09-03) : icônes
## seules, mot en infobulle. Elle porte aussi les DEUX LIEUX (81) — mairie et
## université — qui étaient deux boutons de plus dans le bandeau du haut.
func _panneau_rail() -> void:
	_menu_panneau = PanelContainer.new()
	_poser_boite(_menu_panneau)
	(_menu_panneau.get_theme_stylebox("panel") as StyleBoxFlat).set_content_margin_all(8)
	_menu_panneau.offset_left = RAIL_X
	_menu_panneau.offset_right = RAIL_X + RAIL_LARGEUR
	_menu_panneau.offset_top = HAUT
	add_child(_menu_panneau)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_menu_panneau.add_child(v)

	# ⚠️ `allow_unpress` à false : sans lui, recliquer la vue active l'éteint
	# À L'ÉCRAN alors que la ville reste peinte — le rail mentirait. La
	# fermeture du panneau passe par `_sur_rail`, pas par le groupe.
	var groupe := ButtonGroup.new()
	groupe.allow_unpress = false

	# 🏙️ L'EN-TÊTE EST AUSSI LE BOUTON DE LA VILLE VIVANTE : accent quand on y est.
	var accueil := _tuile_rail("ville", "Ville",
		"Ville — retrouver la matière, les arbres et les voitures.")
	accueil.toggle_mode = true
	accueil.button_group = groupe
	accueil.pressed.connect(func() -> void: _sur_rail(""))
	v.add_child(accueil)
	_menu_boutons[""] = accueil

	for t in themes:
		var id := str(t["id"])
		var b := _tuile_rail(id, str(t.get("court", t["nom"])),
			"%s — %s" % [str(t["nom"]), str(t.get("resume", ""))])
		b.toggle_mode = true
		b.button_group = groupe
		b.pressed.connect(func() -> void: _sur_rail(id))
		v.add_child(b)
		_menu_boutons[id] = b

	# 🎓🏛️ LES DEUX PORTES PERMANENTES (81) : un menu s'ouvre sans aller sur
	# place. L'autre porte est le bouton de la fiche d'îlot ; le lieu est un
	# raccourci, jamais le seul chemin. Hors du groupe — un lieu n'est pas une
	# vue : il ouvre une fiche à droite et ne repeint pas la ville.
	v.add_child(_filet_rail())
	for lieu in LIEUX_ORDRE:
		var cle: String = lieu
		var b := _tuile_rail(cle, String(LIEUX[cle]["court"]), "%s (îlot %d) — %s" % [String(LIEUX[cle]["nom"]),
			int(LIEUX[cle]["fid"]), String(LIEUX[cle]["quoi"])])
		b.pressed.connect(func() -> void: ouvrir_lieu(cle))
		v.add_child(b)
		_rail_lieux.append(b)
	accueil.set_pressed_no_signal(true)
	v.add_child(_filet_rail())
	var debut := _tuile_rail("debut", "Début", "Revoir les premiers pas après la crue.")
	_debut = debut
	debut.pressed.connect(func() -> void:
		if ouverture != null:
			var ouvrir: bool = not ouverture.visible
			theme_demande.emit("")
			_detail_ouvert = false
			_placer_detail()
			ouverture.ouvert = ouvrir
			ouverture.actualiser(true))
	v.add_child(debut)


## 🔄 L'ICÔNE SEULE, le mot dans l'infobulle (auteur, 2026-09-28). Elle portait
## son mot en capitales dessous depuis le 2026-09-24 (décision 88).
func _tuile_rail(icone: String, _mot: String, bulle: String) -> Button:
	var b := Button.new()
	# Dessin BLANC : ce sont les couleurs d'état du bouton qui le teintent.
	b.icon = _icone(icone, 26, Color.WHITE)
	b.expand_icon = false
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	b.tooltip_text = bulle
	_habiller_tuile_rail(b)
	# 🧭 L'anneau de la tuile que le guide demande (`_maj_rail`).
	# 🟡 Jaune, comme tout ce que le jeu entoure (auteur, 2026-10-06) ; il était vert.
	var anneau := Panel.new()
	var cadre := StyleBoxFlat.new()
	# 🔄 La tuile s'allume en plein (auteur, 2026-10-08 : l'anneau seul ne se voyait pas).
	cadre.bg_color = Color(APPEL, 0.5)
	cadre.set_corner_radius_all(_r(12))
	cadre.set_border_width_all(3)
	cadre.border_color = APPEL
	anneau.add_theme_stylebox_override("panel", cadre)
	anneau.set_anchors_preset(Control.PRESET_FULL_RECT)
	anneau.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anneau.visible = false
	b.add_child(anneau)
	b.set_meta("anneau", anneau)
	return b


## 🧭 Grise tant que le guide ne l'a pas demandée, entourée quand il la demande.
func _maj_rail() -> void:
	var tuiles := _menu_boutons.duplicate()
	for i in LIEUX_ORDRE.size():
		tuiles[LIEUX_ORDRE[i]] = _rail_lieux[i]
	var appel: String = ouverture.rail_appel() if ouverture != null else ""
	# La tuile Ville est rangée sous "" : « ville » la désigne.
	var cle := "" if appel == "ville" else appel
	# 🔄 Clignote franchement (auteur, 2026-10-08) : il remplace « Ouvrez le trafic… ».
	var pouls := 0.15 + 0.85 * (0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008))
	for id in tuiles:
		var b: Button = tuiles[id]
		b.disabled = ouverture != null and not ouverture.rail_ouvert(id)
		b.visible = ouverture == null or ouverture.rail_visible(id)
		var anneau: Control = b.get_meta("anneau")
		anneau.visible = appel != "" and id == cle
		anneau.modulate.a = pouls
	var cible: Button = tuiles.get(cle) if appel != "" else null
	_fleche.visible = cible != null and cible.is_visible_in_tree()
	if _fleche.visible:
		var r := cible.get_global_rect()
		_fleche.global_position = Vector2(r.end.x + 6.0, r.get_center().y)


## 🔄 La flèche qui rebondit vers la tuile appelée (auteur, 2026-10-08), sans texte.
var _fleche: Control

func _batir_fleche() -> void:
	_fleche = Control.new()
	_fleche.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fleche.z_index = 2
	_fleche.visible = false
	add_child(_fleche)
	var pointe := Node2D.new()
	_fleche.add_child(pointe)
	var ombre := Polygon2D.new()
	ombre.polygon = PackedVector2Array([Vector2(-2, 0), Vector2(26, -17), Vector2(26, 17)])
	ombre.color = Color(0, 0, 0, 0.45)
	pointe.add_child(ombre)
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array([Vector2(1, 0), Vector2(23, -13), Vector2(23, 13)])
	p.color = APPEL
	pointe.add_child(p)
	var tw := _fleche.create_tween().set_loops()
	tw.tween_property(pointe, "position:x", 14.0, 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_property(pointe, "position:x", 0.0, 0.35).set_trans(Tween.TRANS_SINE)


## Le trait qui sépare les vues des lieux : sans lui, sept tuiles identiques
## laissent croire que la mairie repeint la ville.
func _filet_rail() -> Control:
	# `trait` est un mot réservé de GDScript : ne pas renommer la variable.
	var filet := ColorRect.new()
	filet.color = Color(TEXTE, 0.12)
	filet.custom_minimum_size = Vector2(0, 1)
	filet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return filet


## 🔴 LE SEUL ENDROIT OÙ LE PANNEAU SE FERME. `maquette._sur_theme` sort tout de
## suite quand le thème ne change pas, donc recliquer l'icône active ne
## rappellerait jamais `montrer_theme` : c'est ici, et pas là-bas.
func _sur_rail(id: String) -> void:
	# 🎓 Une vue choisie au rail referme la fenêtre du campus (auteur, 2026-10-09).
	if _campus_panneau != null and _campus_panneau.visible:
		_fermer_campus()
	if id == _theme_courant:
		_detail_ouvert = not _detail_ouvert
		_placer_detail()
		return
	_detail_ouvert = true
	theme_demande.emit(id)


## Un seul panneau de détail à l'écran, et il tombe par le `genre` du thème —
## un thème neuf n'écrit rien de plus ici.
func _placer_detail() -> void:
	var genre := str(_theme_actuel.get("genre", ""))
	if _theme_courant == "" and _bilan_differe():
		_detail_ouvert = false
	_ville_panneau.visible = _detail_ouvert and _theme_courant == ""
	_diagnostic_panneau.visible = _detail_ouvert and genre == "crue"
	_chantiers_panneau.visible = _detail_ouvert and genre == "chantiers"
	_calque_panneau.visible = _detail_ouvert and genre in ["calque", "tissu", "sols"]
	if ouverture != null:
		ouverture.visible = ouverture.paraitre()


## Les données générales attendent la fin de la découverte du premier pont.
func _bilan_differe() -> bool:
	return ouverture != null and not ouverture.pont_termine \
		and not ouverture.suite and not ouverture.termine


## Le panneau des thèmes CONTINUS — énergie, trafic — et du tissu. Un thème
## neuf n'écrit rien de plus : il tombe ici par son `genre`.
func _panneau_calque() -> void:
	_calque_panneau = PanelContainer.new()
	_calque_panneau.theme = _theme_ui
	_poser_boite(_calque_panneau)
	_ancrer_detail(_calque_panneau)
	_calque_panneau.visible = false
	add_child(_calque_panneau)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_calque_panneau.add_child(v)
	_entetes["_calque"] = _entete(v)
	v.add_child(HSeparator.new())
	_calque_barre = TextureRect.new()
	_calque_barre.custom_minimum_size = Vector2(0, 13)
	_calque_barre.stretch_mode = TextureRect.STRETCH_SCALE
	_calque_barre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_calque_barre)
	var h := HBoxContainer.new()
	_calque_bas = _label("", 12, GRIS)
	h.add_child(_calque_bas)
	_calque_haut = _label("", 12, GRIS)
	_calque_haut.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_calque_haut.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(_calque_haut)
	v.add_child(h)
	_calque_note = _label("", 11, GRIS)
	_calque_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_calque_note)
	# 🟫 Le pont engagé, la boue se déblaie depuis la ville (auteur, 2026-10-08). 🔴 Flaggable (90).
	_boue_ville = _label("Les rues boueuses se déblaient depuis la ville.", 13, TEXTE)
	_boue_ville.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_boue_ville.visible = false
	v.add_child(_boue_ville)
	# 💧 LA CARTE DES SOLS (101) : trois teintes et le chiffre qui les résume.
	# ⚠ Les teintes sont aussi dans `maquette.SOLS_*`, en sRGB.
	_sols_bloc = VBoxContainer.new()
	_sols_bloc.add_theme_constant_override("separation", 6)
	_sols_bloc.visible = false
	v.add_child(_sols_bloc)
	_legende(_sols_bloc, SOL_BOIT, "Boit la pluie · jardins, prés, toits verts")
	_legende(_sols_bloc, SOL_DUR, "La renvoie à l'Ilse · rues, toits, cours en dur")
	_legende(_sols_bloc, SOL_PARKING, "Parking · places de rue et place-parking")
	_sols_bloc.add_child(HSeparator.new())
	_sols_chiffre = _ligne_chiffre(_sols_bloc, "Sol de la ville qui boit")
	# 🧹 Tout déblayer d'un coup (auteur, 2026-10-05). 🔴 Texte de prototype, flaggable (90).
	_boue_bloc = VBoxContainer.new()
	_boue_bloc.add_theme_constant_override("separation", 6)
	_boue_bloc.visible = false
	v.add_child(_boue_bloc)
	_boue_bloc.add_child(HSeparator.new())
	_boue_texte = _label("", 13, TEXTE)
	_boue_texte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_boue_bloc.add_child(_boue_texte)
	_boue_bouton = Button.new()
	_boue_bouton.text = "Tout déblayer"
	_habiller_principal(_boue_bouton)
	_boue_bouton.pressed.connect(func() -> void: deblaiement_demande.emit())
	_boue_bloc.add_child(_boue_bouton)


var _boue_bloc: VBoxContainer
var _boue_texte: Label
var _boue_ville: Label
var _sols_bloc: VBoxContainer
var _sols_chiffre: Label
var _sols_depart := -1.0
const SOL_BOIT := Color8(92, 160, 92)
const SOL_DUR := Color8(112, 112, 118)
const SOL_PARKING := Color8(240, 150, 30)
var _boue_bouton: Button


## Les rues que « Tout déblayer » prendrait : celles que le guide laisse engager,
## celles qui barrent un pont engagé en tête, pour qu'il passe le plus tôt possible.
func rues_a_deblayer() -> Array:
	var rues := _rues_permises()
	var devant := []
	for p in ville.ponts_coupes():
		if ville.est_repare("r", p):
			devant += trafic.acces_pont(p, _mois)["obstacles"]
	rues.sort_custom(func(a, b) -> bool: return int(a in devant) > int(b in devant))
	return rues


func _rues_permises() -> Array:
	return ville.rues_boueuses().filter(func(f) -> bool: return _autorise("r", int(f)))


## Sans le tri : la colonne le demande à chaque image.
func deblaiement_propose() -> bool:
	return ville.rues_deblayees_main() >= Ville.DEBLAIEMENT_SEUIL and not _rues_permises().is_empty()


func _maj_boue() -> void:
	if _boue_bloc == null:
		return
	_boue_ville.visible = _calque_panneau.visible and _theme_courant == "trafic" and ouverture != null \
		and ouverture.etape == "pont_travaux" and not ouverture.acces_degage()
	_boue_bloc.visible = _calque_panneau.visible and _theme_courant == "trafic" and deblaiement_propose()
	if not _boue_bloc.visible:
		return
	var rues := rues_a_deblayer()
	var cout := 0.0
	for f in rues:
		cout += ville.cout_reparation_ke("r", int(f))
	_boue_texte.text = "%d rues sous la boue" % rues.size()
	_boue_bouton.text = "Tout déblayer · %s k€ · %s" % [
		_milliers(cout), _duree(Ville.DEBLAIEMENT_MOIS * rues.size())]
	_boue_bouton.disabled = cout > ville.caisse_ke(_mois) + 0.001


# 🔄 Le titre seul, sans la phrase dessous (auteur, 2026-10-08) ; l'infobulle du rail la garde.
func _entete(parent: VBoxContainer) -> Array:
	return [_bandeau(parent, "")]


func _ecrire_entete(e: Array, t: Dictionary) -> void:
	(e[0] as Label).text = str(t["nom"])


## La rampe des thèmes continus, dessinée une fois. ⚠ En sRGB : `maquette`
## convertit en linéaire pour le SHADER, jamais pour l'interface.
func _texture_rampe() -> Texture2D:
	var g := Gradient.new()
	var pos := PackedFloat32Array()
	var teintes := PackedColorArray()
	for i in rampe.size():
		pos.append(float(i) / maxf(1.0, float(rampe.size() - 1)))
		teintes.append(rampe[i])
	g.offsets = pos
	g.colors = teintes
	var t := GradientTexture1D.new()
	t.gradient = g
	t.width = 256
	return t


## L'unique entrée de la deuxième vue : `maquette` dit quel thème, l'interface
## en tire tout le reste. `id` vide = la ville vivante.
func montrer_theme(id: String, t: Dictionary) -> void:
	_theme_courant = id
	_theme_actuel = t
	# Changer de vue rouvre le panneau : on vient de demander à voir quelque
	# chose, et le refermer serait exactement le contraire du clic.
	_detail_ouvert = true
	# Les deux lieux sont dans le rail mais hors du groupe : ils n'ont pas de
	# bascule, donc pas d'état à remettre.
	for vue in _menu_boutons:
		var b := _menu_boutons[vue] as Button
		if b.toggle_mode:
			b.set_pressed_no_signal(vue == id)
	_placer_detail()
	var genre := str(t.get("genre", ""))
	if genre == "crue":
		_vue_crue = "degats"
		_habiller_onglets_crue()
	if id != "":
		var cle := "_calque" if _calque_panneau.visible else id
		_ecrire_entete(_entetes[cle], t)
	# 🎓 L'étude parue, Dangers s'ouvre sur la prochaine crue (auteur, 2026-10-02).
	if genre == "crue" and etude_publiee():
		choisir_vue_crue("prochaine")
	if _calque_panneau.visible:
		_calque_note.text = str(t.get("note", ""))
		_calque_note.visible = _calque_note.text != ""
		# Le tissu n'a pas d'échelle : une teinte par sous_type, donc ni rampe
		# ni bornes. C'est la seule différence entre les deux genres ici.
		var continu := genre == "calque"
		_sols_bloc.visible = genre == "sols"
		if continu and _calque_barre.texture == null:
			_calque_barre.texture = _texture_rampe()
		_calque_barre.visible = continu
		_calque_bas.visible = continu
		_calque_haut.visible = continu
		_calque_bas.text = str(t.get("bas", ""))
		_calque_haut.text = str(t.get("haut", ""))


func _panneau_diagnostic() -> void:
	_diagnostic_panneau = PanelContainer.new()
	_diagnostic_panneau.theme = _theme_ui
	_poser_boite(_diagnostic_panneau)
	_ancrer_detail(_diagnostic_panneau)
	_diagnostic_panneau.visible = false
	add_child(_diagnostic_panneau)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_diagnostic_panneau.add_child(v)
	_entetes["dangers"] = _entete(v)
	# 🎓 DEUX ONGLETS (auteur, 2026-09-30) : ce que l'eau a pris, ce qu'elle
	# reprendrait. Le second n'existe qu'une fois l'étude parue.
	var rangee := HBoxContainer.new()
	rangee.add_theme_constant_override("separation", 0)
	v.add_child(rangee)
	for o in [["degats", "Dégâts"], ["prochaine", "Prochaine crue"]]:
		var id: String = o[0]
		var b := Button.new()
		b.text = o[1]
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void: choisir_vue_crue(id))
		rangee.add_child(b)
		_onglets_crue[id] = b
		var boite := VBoxContainer.new()
		boite.add_theme_constant_override("separation", 6)
		v.add_child(boite)
		_vues_crue[id] = boite

	# 🌊 Le bleu fonce avec la profondeur (crue.gdshaderinc). Flaggable (90).
	var d: VBoxContainer = _vues_crue["degats"]
	_legende(d, Color8(38, 157, 196), "Passage de la crue · plus foncé, plus profond")
	_legende(d, Color8(232, 126, 48), "Bâtiments touchés par l'eau")
	_legende(d, Color8(140, 28, 40), "Bâtiments détruits")
	_legende(d, Color8(220, 58, 48), "Routes bloquées · franchissements coupés")
	d.add_child(HSeparator.new())
	# 🔧 CE QUE LA CRUE COÛTE ENCORE. Ces trois nombres BAISSENT quand on
	# répare : sans eux, reconstruire un îlot ne changerait rien de visible
	# ailleurs que sur cet îlot, et la décision n'aurait pas de contrepartie.
	for ligne in [
		["logements", "Logements perdus"],
		["ponts", "Franchissements coupés"],
		["reste", "Reste à réparer"],
	]:
		_degats_valeurs[ligne[0]] = _ligne_chiffre(d, ligne[1])
	_panneau_prochaine(_vues_crue["prochaine"])
	_habiller_onglets_crue()


func _ligne_chiffre(parent: VBoxContainer, etiquette: String) -> Label:
	var h := HBoxContainer.new()
	h.add_child(_label(etiquette, 12, GRIS))
	var val := _label("—", 14, TEXTE)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(val)
	parent.add_child(h)
	return val


## 🎓 LA PRÉVISION, toujours ouvrable (94) : où irait l'eau, ce qu'elle
## ruinerait, la jauge de ce qu'on a déjà fait, et les quatre gestes de la
## ville-éponge qui la font baisser (101).
func _panneau_prochaine(p: VBoxContainer) -> void:
	var barre := TextureRect.new()
	var g := Gradient.new()
	g.colors = PackedColorArray([rampe_eau[0], rampe_eau[1]])
	var tex := GradientTexture1D.new()
	tex.gradient = g
	tex.width = 128
	barre.texture = tex
	barre.custom_minimum_size = Vector2(0, 13)
	barre.stretch_mode = TextureRect.STRETCH_SCALE
	barre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(barre)
	var h := HBoxContainer.new()
	h.add_child(_label("10 cm d'eau", 12, GRIS))
	var haut := _label("au pire", 12, GRIS)
	haut.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	haut.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(haut)
	p.add_child(h)
	_legende(p, Color8(232, 126, 48), "Bâtiments qu'elle toucherait")
	_legende(p, Color8(140, 28, 40), "Bâtiments qu'elle détruirait")
	p.add_child(HSeparator.new())
	for ligne in [
		["quand", "Attendue"],
		["ilots", "Îlots sous l'eau"],
		["eau", "Eau au pire"],
	]:
		_prochaine_valeurs[ligne[0]] = _ligne_chiffre(p, ligne[1])
	_prochaine_valeurs["logements"] = _ligne_chiffre(p, "Logements qu'elle détruirait")
	p.add_child(HSeparator.new())
	_prochaine_valeurs["baisse"] = _ligne_chiffre(p, "Eau en moins depuis l'étude")
	_jauge_crue = JaugeCrue.new()
	_jauge_crue.custom_minimum_size = Vector2(0, 16)
	_jauge_crue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(_jauge_crue)
	# 🔄 Ni légende de la jauge, ni écart depuis l'étude, ni titre au-dessus des
	# leviers (auteur, 2026-10-08) : le joueur les lit seul.
	p.add_child(HSeparator.new())
	var berge_cm := 0.0
	for b in ville.berges:
		berge_cm = maxf(berge_cm, (ville.berge_largeur_rendue_m(b, Ville.BERGE_RENATUREE)
			- ville.berge_largeur_rendue_m(b, ville.berge_depart(b))) * Ville.BERGE_BAISSE_M_PAR_M * 100.0)
	var plat_ha := 0.0
	for f in ville.ilots:
		plat_ha += Energie.toit_plat_equipable_m2(ville, f) / 10000.0
	var pre_cm_ha: float = float(Ville.CULTURES[3]["crue_m_ha"]) * 100.0
	_levier(p, "Rendre un parking perméable",
		"−%d cm par hectare rendu, dans toute la ville ; les places restent." % int(roundf(
			Ville.PERMEABLE_BAISSE_M_PAR_HA * 100.0)),
		"Voir la place-parking", "i", Ouverture.PARKING, "permeable", true)
	_levier(p, "Rendre une berge à l'Ilse",
		"Jusqu'à −%d cm dans son quartier, sur les deux rives." % int(roundf(berge_cm)),
		"Voir la berge %d" % Ouverture.BERGE, "b", Ouverture.BERGE, "berge", Ville.BERGE_RENATUREE)
	_levier(p, "Verdir les toits plats",
		"−%d cm par hectare, dans toute la ville. Wehrau en a %s ha." % [
			int(roundf(Ville.TOIT_VERT_BAISSE_M_PAR_HA * 100.0)), _nb(plat_ha, 1)],
		"Voir un toit plat", "i", Ouverture.TOIT_PLAT, "vert", 1.0)
	_levier(p, "Laisser l'Ilse déborder dans un pré",
		"−%s cm par hectare, dans toute la ville ; le champ ne nourrit plus." % _nb(pre_cm_ha, 1),
		"Voir un champ", "i", Ouverture.PRE, "culture", 3)


func _levier(p: VBoxContainer, titre: String, effet: String, voir: String,
		couche: String, fid: int, reglage: String, valeur: Variant) -> void:
	# 🚪 Un levier fermé ne s'affiche pas ici (une livraison, une porte).
	var boite := VBoxContainer.new()
	p.add_child(boite)
	boite.add_child(_label(titre, 13, TEXTE))
	var e := _label(effet, 11, GRIS)
	e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	boite.add_child(e)
	var b := Button.new()
	b.text = voir
	b.focus_mode = Control.FOCUS_NONE
	_habiller_secondaire(b)
	b.pressed.connect(func() -> void: examen_demande.emit(couche, fid, reglage, valeur))
	boite.add_child(b)
	_prochaine_valeurs["levier_" + reglage] = b
	_leviers_crue[{"culture": "pre"}.get(reglage, reglage)] = boite


var _leviers_crue := {}


## L'étude est parue : sans guide (essais, mode auteur), elle l'est toujours.
func etude_publiee() -> bool:
	return ouverture == null or ouverture.etude_parue


func _mois_etude() -> float:
	return ouverture.etude_mois if ouverture != null else 0.0


func choisir_vue_crue(id: String) -> void:
	if id == "prochaine" and not etude_publiee():
		return
	_vue_crue = id
	_habiller_onglets_crue()
	vue_crue_demandee.emit(id)
	if id == "prochaine":
		_maj_prochaine()
		if ouverture != null:
			ouverture.prochaine_ouverte()
			_habiller_onglets_crue()   # efface « nouveau », vu à l'instant


## Même trait que les onglets de la fiche ; « nouveau » tant qu'on ne l'a pas vu.
func _habiller_onglets_crue() -> void:
	for id in _onglets_crue:
		var b: Button = _onglets_crue[id]
		var ouvert: bool = id == _vue_crue
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0)
		sb.set_content_margin_all(6)
		sb.border_width_bottom = 2 if ouvert else 1
		sb.border_color = ACCENT_VIF if ouvert else Color8(180, 170, 146, 160)
		for etat in ["normal", "pressed", "focus", "disabled", "hover", "hover_pressed"]:
			b.add_theme_stylebox_override(etat, sb)
		var coul := ACCENT if ouvert else GRIS
		for etat in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(etat, coul)
		b.add_theme_font_size_override("font_size", 13)
		(_vues_crue[id] as Control).visible = ouvert
	var nouveau: bool = ouverture != null and not ouverture.prochaine_vue
	(_onglets_crue["prochaine"] as Button).text = "Prochaine crue" + (" · nouveau" if nouveau else "")
	(_onglets_crue["prochaine"] as Button).visible = etude_publiee()


func _maj_prochaine() -> void:
	var p := ville.prochaine_crue(_mois)
	var a := ville.prochaine_crue(_mois_etude())
	# 6 à 8 ans depuis la parution ; aucune crue ne tombe au bout (question ouverte).
	var ecoule := (_mois - _mois_etude()) / 12.0
	var tot := int(ceil(maxf(6.0 - ecoule, 0.0)))
	var tard := int(ceil(maxf(8.0 - ecoule, 0.0)))
	var quand := "dans %d à %d ans" % [tot, tard]
	if tot == 0:
		quand = "d'ici %d ans" % tard if tard > 0 else "d'un mois à l'autre"
	(_prochaine_valeurs["quand"] as Label).text = quand
	(_prochaine_valeurs["ilots"] as Label).text = "%d · %d cette année" % [
		int(p["ilots_sous_eau"]), int(p["ilots_cette_annee"])]
	(_prochaine_valeurs["eau"] as Label).text = "%s m" % _nb(float(p["eau_pire_m"]), 2)
	(_prochaine_valeurs["logements"] as Label).text = _nb(float(p["logements_perdus"]), 0)
	for l in _leviers_crue:
		(_leviers_crue[l] as Control).visible = _levier_ferme(l) == ""
	var cle := "%d/%d/%d/%d" % [int(_mois * 30.0), ville._rampes_version,
		ville._repare.size(), ville._berge.size()]
	if cle != _a_venir_cle:
		_a_venir_cle = cle
		_a_venir = float(ville.prochaine_crue(_mois + Ville.HORIZON_MOIS)["eau_pire_m"])
	if _seuil_crue < 0.0:
		_seuil_crue = _premieres_maisons_m()
	var depart := float(a["eau_pire_m"])
	var livre := depart - float(p["eau_pire_m"])
	var engage := depart - _a_venir
	var apercu := depart - _apercu_crue if _apercu_crue >= 0.0 and _fiche_fid >= 0 \
		and _fiche_panneau.visible and not _reglages_vus().is_empty() else -1.0
	_jauge_crue.regler(livre, engage, apercu, _seuil_crue)
	(_prochaine_valeurs["baisse"] as Label).text = "%d cm" % int(roundf(livre * 100.0))


## La plus petite baisse, sur les paliers de `04e`, qui sauve une maison quelque
## part : en dessous, la crue baisse sans qu'aucun logement soit sauvé.
func _premieres_maisons_m() -> float:
	var paliers: Array = ville.crue.get("baisses_m", [])
	for k in range(1, paliers.size()):
		for fid in ville.ilots:
			var c: Array = ville.ilots[fid].get("ruine_apres_baisse", [])
			if c.size() == paliers.size() and float(c[k]) < float(c[0]) - 0.001 \
					and ville.base("i", fid, "logements") + ville.base("i", fid, "logements_sinistres") > 0.0:
				return float(paliers[k - 1])
	return 0.0


func _legende(parent: VBoxContainer, couleur: Color, texte: String) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var carre := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = couleur
	sb.set_corner_radius_all(_r(4))
	carre.add_theme_stylebox_override("panel", sb)
	carre.custom_minimum_size = Vector2(15, 15)
	carre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(carre)
	h.add_child(_label(texte, 12, TEXTE))
	parent.add_child(h)


# ===================================================== la ville en travaux
#
# 🔧 CE QUE LE THÈME « DANGERS » NE DIT PAS. Lui montre ce que l'eau A PRIS,
# une fois pour toutes ; celui-ci montre l'état COURANT — ce qui est encore
# cassé, ce qui est en travaux, ce qui est fait.

## Six chantiers listés, le septième dit combien débordent. Au-delà, le
## panneau couvrirait la ville qu'il commente.
const CHANTIERS_LIGNES := 7


func _panneau_chantiers() -> void:
	_chantiers_panneau = PanelContainer.new()
	_chantiers_panneau.theme = _theme_ui
	_poser_boite(_chantiers_panneau)
	_ancrer_detail(_chantiers_panneau)
	_chantiers_panneau.visible = false
	add_child(_chantiers_panneau)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_chantiers_panneau.add_child(v)
	_entetes["chantiers"] = _entete(v)
	v.add_child(HSeparator.new())
	_legende(v, CASSE, "Cassé · rien d'engagé")
	_legende(v, EN_TRAVAUX, "Chantier en cours")
	_legende(v, FAIT, "Fait · la ville est réparée là")
	v.add_child(HSeparator.new())
	for ligne in [
		["casses", "Encore cassé"],
		["reste", "Reste à payer"],
		["en_cours", "Chantiers en cours"],
		["faits", "Chantiers finis"],
	]:
		var h := HBoxContainer.new()
		h.add_child(_label(ligne[1], 12, GRIS))
		var val := _label("—", 14, TEXTE)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(val)
		_chantiers_valeurs[ligne[0]] = val
		v.add_child(h)
	v.add_child(HSeparator.new())
	# Les lignes sont créées UNE fois et remplies ensuite : bâtir des Labels à
	# chaque image ferait tomber la maquette pour un panneau de texte.
	for i in CHANTIERS_LIGNES:
		var l := _label("", 12, TEXTE)
		l.visible = false
		_chantiers_lignes.append(l)
		v.add_child(l)


## ⚠️ Appelé seulement quand le panneau est ouvert : `ville.chantiers` parcourt
## les 69 îlots et les 178 tronçons, et ce serait une troisième traversée par
## image pour un panneau que personne ne regarde.
func maj_chantiers(d: Dictionary) -> void:
	var g: Dictionary = d["casses_par_genre"]
	(_chantiers_valeurs["casses"] as Label).text = "%d îlots · %d ponts · %d rues" % [
		int(g["reconstruction"]), int(g["pont"]), int(g["deblaiement"])]
	(_chantiers_valeurs["reste"] as Label).text = _milliers(
		float(d["reste_ke"])) + " k€"
	var liste: Array = d["en_cours"]
	(_chantiers_valeurs["en_cours"] as Label).text = "%d" % liste.size()
	(_chantiers_valeurs["faits"] as Label).text = "%d" % int(d["faits"])
	for i in _chantiers_lignes.size():
		var texte := ""
		if liste.is_empty():
			texte = "Aucun chantier en cours." if i == 0 else ""
		elif i == CHANTIERS_LIGNES - 1 and liste.size() > CHANTIERS_LIGNES:
			texte = "… et %d de plus" % (liste.size() - i)
		elif i < liste.size():
			texte = _ligne_chantier(liste[i])
		var l: Label = _chantiers_lignes[i]
		if l.text != texte:
			l.text = texte
		l.visible = texte != ""


## Le même nom que la fiche pour retrouver un chantier dans la ville.
func _ligne_chantier(c: Dictionary) -> String:
	var genre: String = {"pont": "tablier", "deblaiement": "déblaiement",
		"solaire": "panneaux", "berge": "transformation"}.get(c["genre"], c["genre"])
	var nom: String = "%d rues" % int(c["rues"]) if c.has("rues") else lieux.nom(c["couche"], int(c["fid"]))
	return "%s · %s · encore %s" % [nom, genre, _duree(float(c["reste_mois"]))]


## 🔄 RETOUR EN ARRIÈRE SIGNALÉ, 2026-08-25 : la fiche se retirait dès qu'un
## panneau du haut s'ouvrait. Elle reste maintenant dans LES DEUX VUES — c'est
## elle qui porte les décisions, et le diagnostic ne change que ce qu'on voit.
## ⚠️ Elle croise le panneau de thème en dessous de ~1 100 px de large.
func _panneau_ilot() -> void:
	var p := PanelContainer.new()
	_fiche_panneau = p
	p.theme = _theme_ui
	_poser_boite(p)
	p.anchor_left = 1.0
	p.anchor_right = 1.0
	p.offset_left = -FICHE_LARGEUR - 16.0
	p.offset_right = -16
	p.offset_top = _haut_fiche()
	p.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(p)
	_croix(p, _fermer_fiche)

	# 🔴 LA FICHE DÉFILE, sinon son bouton d'engagement sort de l'écran : sept
	# réglages, le récapitulatif et la miniature dépassent 900 px de haut. Elle
	# épouse son contenu tant qu'il tient, et ne défile qu'au-delà (`_clamper`).
	var defil := ScrollContainer.new()
	defil.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(defil)
	_fiche_defilement = defil

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	defil.add_child(v)
	_fiche_contenu = v
	v.minimum_size_changed.connect(_clamper_fiche)
	get_viewport().size_changed.connect(_clamper_fiche)
	# Le nom et son type collés : ils ne font qu'un seul bloc.
	var en_tete := VBoxContainer.new()
	en_tete.add_theme_constant_override("separation", 0)
	v.add_child(en_tete)
	_fiche_titre = _bandeau(en_tete, "Sélection")
	# Le type se lit sous le nom, jamais dans les chiffres : « champ »,
	# « habitat collectif », « voie de desserte » sont une identité, pas une
	# mesure — et à cette place ils ne prennent aucune ligne de tuile.
	_fiche_soustitre = _label("", 12, GRIS)
	if BOIS:
		_fiche_soustitre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fiche_soustitre.visible = false
	en_tete.add_child(_fiche_soustitre)

	# 🎓🏛️ LA DEUXIÈME PORTE (81), et elle ne change rien à la fiche : celle-ci
	# reste la fiche de L'ÎLOT — surface, logements, toits, curseurs. Le menu
	# est une autre fiche, qui prend la place de celle-ci.
	_lieu_bouton = Button.new()
	_lieu_bouton.visible = false
	_lieu_bouton.theme = _theme_ui
	_lieu_bouton.focus_mode = Control.FOCUS_NONE
	_lieu_bouton.pressed.connect(func() -> void:
		ouvrir_lieu(String(_lieu_du_fid(_fiche_fid))))
	v.add_child(_lieu_bouton)

	# 🔎 LA MINIATURE (décision 12). Elle montre l'objet dans l'état qui SERA
	# livré — le réglage suit le curseur avant même d'être validé — pendant que
	# la ville derrière garde son état réel.
	_apercu_cadre = PanelContainer.new()
	# 🔄 SANS FOND (auteur, 2026-09-28) : la miniature est transparente, l'objet
	# se pose directement sur le verre. Il avait une plaque beige.
	_apercu_cadre.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_apercu_cadre.visible = false
	v.add_child(_apercu_cadre)
	var vue := TextureRect.new()
	vue.texture = apercu
	# 🔴 `EXPAND_IGNORE_SIZE` : sans lui le rectangle EXIGE la taille de sa
	# texture — rendue trois fois plus grande — et la miniature déborde la fiche
	# au lieu d'y être réduite.
	vue.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vue.custom_minimum_size = Vector2(0, Apercu.TAILLE.y)
	# ⚠️ Sans ça, la miniature avale les clics destinés à la ville derrière.
	vue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vue.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_apercu_cadre.add_child(vue)

	# 🔧 L'AVANCEMENT, SOUS LA MINIATURE : celle-ci montre l'objet LIVRÉ, la
	# barre dit combien il reste à attendre avant que la ville le montre aussi.
	# Ambre de la vue chantiers : la même chose se dit de la même couleur.
	_chantier_bloc = VBoxContainer.new()
	_chantier_bloc.add_theme_constant_override("separation", 2)
	_chantier_bloc.visible = false
	v.add_child(_chantier_bloc)
	var chantier_ligne := HBoxContainer.new()
	_chantier_bloc.add_child(chantier_ligne)
	_chantier_quoi = _label("Chantier", 11, ACCENT)
	_chantier_quoi.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chantier_ligne.add_child(_chantier_quoi)
	_chantier_reste = _label("", 12, GRIS)
	_chantier_reste.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	chantier_ligne.add_child(_chantier_reste)
	_chantier_jauge = Jauge.new()
	_chantier_jauge.custom_minimum_size = Vector2(0, 9)
	_chantier_jauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chantier_jauge.colorer(EN_TRAVAUX)
	_chantier_bloc.add_child(_chantier_jauge)

	_fiche_vide = _label("Cliquez un îlot.", 13, GRIS)
	_fiche_vide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_fiche_vide)

	# 🔢 LA LIGNE DU HAUT : UN SEUL CHIFFRE, celui qui dit ce que l'objet rend —
	# des logements, des repas, des voitures (auteur, 2026-09-18). Tout le reste
	# est rangé dans les onglets du dessous.
	_resume_ligne = HBoxContainer.new()
	_resume_ligne.add_theme_constant_override("separation", 9)
	_resume_ligne.visible = false
	v.add_child(_resume_ligne)
	_resume_icone = TextureRect.new()
	_resume_icone.custom_minimum_size = Vector2(23, 23)
	_resume_icone.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_resume_icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resume_ligne.add_child(_resume_icone)
	_resume_texte = _label("", 16, TEXTE)
	_resume_texte.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_resume_texte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_resume_ligne.add_child(_resume_texte)

	# 🗂️ LA RANGÉE D'ONGLETS. Une icône, pas un mot : cinq mots ne tiennent pas
	# sur 310 px, et le mot revient dans l'infobulle. L'ordre de `ONGLETS` est
	# aussi l'ordre de PRIORITÉ — c'est lui qui décide lequel s'ouvre en premier,
	# donc la crue passe avant l'énergie.
	_onglets = HBoxContainer.new()
	_onglets.add_theme_constant_override("separation", 0)
	_onglets.visible = false
	v.add_child(_onglets)
	for ligne in ONGLETS:
		var b := Button.new()
		b.tooltip_text = ligne[2]
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 40)
		var id: String = ligne[0]
		b.pressed.connect(func() -> void: ouvrir_onglet(id))
		_onglets.add_child(b)
		_onglet_boutons[id] = b

	# 🗂️ LES GRILLES DE TUILES, une par onglet ET par couche : « après la crue »
	# ne dit pas la même chose d'un îlot et d'une rue, « vert » non plus. La clé
	# est `onglet_couche`, et c'est elle qui décide laquelle s'affiche.
	# 🔴 AUCUNE TUILE NE REPÈTE LA LIGNE DU HAUT : les logements et les repas y
	# sont déjà, et deux fois le même nombre à deux lignes d'écart se lit comme
	# deux nombres. La rive est ici parce qu'elle décide qui peut atteindre le
	# champ une fois les ponts coupés.
	_grille_onglet(v, "bati_i", 3, _fiche_valeurs, [
		["surface", "Surface"], ["niveaux", "Niveaux"], ["emplois", "Emplois"]])
	_grille_onglet(v, "campagne_i", 3, _fiche_valeurs, [
		["culture", "Culture"], ["surface_champ", "Surface"], ["rive", "Rive"]])
	# 🏕️ Le champ devenu campement (auteur, 2026-10-08) : plus de culture, des containers.
	_grille_onglet(v, "campement_i", 3, _fiche_valeurs, [
		["containers", "Containers"], ["surface_camp", "Surface"], ["rive_camp", "Rive"]])
	_grille_onglet(v, "energie_i", 3, _fiche_valeurs, [
		["conso", "Conso./an"], ["production", "Solaire/an"], ["retour", "Retour"]])
	# 🌿 La part PLATE se lit ici et nulle part ailleurs : c'est elle qui décide
	# si l'onglet vert existe sur cet îlot.
	_grille_onglet(v, "vert_i", 3, _fiche_valeurs, [
		["toit", "Toit"], ["plat", "Dont plat"], ["verdi", "Verdi"]])
	_grille_onglet(v, "crue_i", 2, _fiche_valeurs, [
		["perdus", "Logements perdus"], ["detruits", "Bâtiments détruits"],
		["annonce", "Crue annoncée"], ["reprise", "Reprise annoncée"]])

	# 🔧 LA FICHE D'UNE RUE. La hiérarchie est passée sous le nom, la charge dans
	# la ligne de résumé : il ne reste ici que ce qu'une décision consomme.
	_grille_onglet(v, "trafic_r", 2, _rue_valeurs, [
		["largeur", "Largeur"], ["places", "Places"]])
	_grille_onglet(v, "vert_r", 2, _rue_valeurs, [
		["arbres", "Arbres"], ["canopee", "Canopée"]])
	_grille_onglet(v, "crue_r", 1, _rue_valeurs, [["etat", "Crue"]])

	# 🌊 LA FICHE D'UNE BERGE. 🔄 Le nombre qui portait la décision était les m²
	# d'asphalte posés au-dessus de l'Ilse ; il est tombé à ~0 le 2026-08-31,
	# quand le corridor des rues de berge est passé sur la terre. Ce qui reste
	# à montrer, c'est la RIVE : les mètres de quai entre la chaussée et l'eau.
	# Le bief se lit en îlots, pas en fil d'eau : « 7 îlots » décide, « 0,31 à
	# 0,61 » n'est qu'une coordonnée.
	_grille_onglet(v, "berge_b", 2, _berge_valeurs, [
		["mur", "Mur de quai"], ["rive", "Rive minérale"],
		["rues", "Voies portées"], ["crue", "Crue au pire"],
		["etat", "État"], ["bief", "Bief"]])

	# 🔴 DEUX BOUTONS, PAS TROIS : l'asphalte est l'état de départ et on n'y
	# revient pas. Démolir un mur de quai est irréversible dans le jeu comme
	# sur le terrain — c'est ce qui donne son poids à la décision.
	_berge_bloc = VBoxContainer.new()
	_berge_bloc.add_theme_constant_override("separation", 6)
	_berge_bloc.visible = false
	v.add_child(_berge_bloc)
	_berge_bloc.add_child(HSeparator.new())
	_berge_texte = _label("", 12, TEXTE)
	_berge_texte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_berge_bloc.add_child(_berge_texte)
	for cible in [Ville.BERGE_APAISEE, Ville.BERGE_RENATUREE]:
		var b := Button.new()
		# Exclusives : une berge n'a qu'un état visé. Reposer le même l'enlève.
		_decision(b, "berge", cible)
		_berge_bloc.add_child(b)
		_berge_boutons.append(b)

	# 🔧 LE BLOC DE RÉPARATION, le même pour un îlot et pour une rue.
	_repare_bloc = VBoxContainer.new()
	_repare_bloc.add_theme_constant_override("separation", 6)
	_repare_bloc.visible = false
	v.add_child(_repare_bloc)
	# 🔄 Ni trait ni titre « Crue » : l'onglet et la grille le disent déjà.
	_repare_texte = _label("", 12, TEXTE)
	_repare_texte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_repare_bloc.add_child(_repare_texte)
	_repare_bouton = Button.new()
	_decision(_repare_bouton, "reparer", true)
	_repare_provisoire = Button.new()
	_repare_provisoire.visible = false
	_decision(_repare_provisoire, "reparer", "provisoire")
	_repare_bloc.add_child(_repare_provisoire)
	for facon in Ville.RECONSTRUCTIONS_ORDRE:
		var b := Button.new()
		b.visible = false
		_decision(b, "reparer", facon)
		_repare_bloc.add_child(b)
		_rebatir_boutons[facon] = b
	_concours_bouton = Button.new()
	_concours_bouton.visible = false
	_decision(_concours_bouton, "concours", true)
	_repare_bloc.add_child(_concours_bouton)
	_projets_bouton = Button.new()
	_projets_bouton.visible = false
	_projets_bouton.pressed.connect(ouvrir_projets)
	_repare_bloc.add_child(_projets_bouton)
	_repare_bloc.add_child(_repare_bouton)
	_repare_etat = _etiquette("", 13, FAIT_TEXTE)
	_repare_etat.visible = false
	_repare_bloc.add_child(_repare_etat)
	# 🔄 Plus de « Voir les accès » ni d'« Examiner » (auteur, 2026-09-26) : le
	# joueur trouve lui-même la route envasée qui barre son pont.

	# 🏕️ ACCUEILLIR LES SINISTRÉS. Le bloc n'existe que sur un champ, et il ne
	# dit jamais non : un champ que personne ne peut atteindre se pose quand
	# même, avec l'avertissement au-dessus du bouton (auteur, 2026-09-17).
	_camp_bloc = VBoxContainer.new()
	_camp_bloc.add_theme_constant_override("separation", 6)
	_camp_bloc.visible = false
	v.add_child(_camp_bloc)
	_camp_bloc.add_child(HSeparator.new())
	# 🔄 Sans titre de section : le bouton suffit (auteur, 2026-10-06).
	_camp_texte = _label("", 12, TEXTE)
	_camp_texte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_camp_bloc.add_child(_camp_texte)
	_camp_bouton = Button.new()
	_camp_bouton.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_decision(_camp_bouton, "camp", true)
	_camp_bloc.add_child(_camp_bouton)
	# 🚿 Améliorer le campement (auteur, 2026-10-02). 🔴 Texte flaggable (90).
	_demandes_bloc = VBoxContainer.new()
	_demandes_bloc.add_theme_constant_override("separation", 6)
	_camp_bloc.add_child(_demandes_bloc)
	for d in Ville.DEMANDES_ORDRE:
		var b := Button.new()
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_decision(b, "demande_" + d, true)
		_demandes_bloc.add_child(b)
		_demande_boutons[d] = b
	_labour_bouton = Button.new()
	_decision(_labour_bouton, "labour", true)
	_labour_bouton.visible = false
	_camp_bloc.add_child(_labour_bouton)

	# 🔄 Les blocs de la fiche n'ont plus de titre : l'onglet porte l'icône (auteur, 2026-10-08).
	# 🌾 CE QUE PORTE LE CHAMP. Exclusifs, comme la berge : un seul usage visé
	# (77c). Reposer le même l'enlève.
	_culture_bloc = VBoxContainer.new()
	_culture_bloc.add_theme_constant_override("separation", 6)
	_culture_bloc.visible = false
	v.add_child(_culture_bloc)
	_culture_bloc.add_child(HSeparator.new())
	_culture_texte = _label("", 12, TEXTE)
	_culture_texte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_culture_bloc.add_child(_culture_texte)
	for k in Ville.CULTURES.size():
		var b := Button.new()
		_decision(b, "culture", k)
		_culture_bloc.add_child(b)
		_culture_boutons.append(b)

	_trafic_bloc = VBoxContainer.new()
	_trafic_bloc.add_theme_constant_override("separation", 6)
	_trafic_bloc.visible = false
	v.add_child(_trafic_bloc)
	_trafic_bloc.add_child(HSeparator.new())
	_trafic_stationnement = Button.new()
	_trafic_stationnement.text = "Retirer les places"
	_trafic_stationnement.icon = _icone("trafic", 22)
	_trafic_stationnement.set_meta("icone", "trafic")
	_decision(_trafic_stationnement, "places", true)
	_trafic_bloc.add_child(_trafic_stationnement)
	_trafic_axe = Button.new()
	_trafic_axe.text = "Fermer aux voitures"
	_decision(_trafic_axe, "axe", true)
	_trafic_bloc.add_child(_trafic_axe)

	# 🌳 PLANTER. Le curseur compte des ARBRES, pas des pourcents : c'est ce
	# qu'on paie et c'est exactement ce qui apparaît à l'écran. Il est ici et
	# pas sur l'îlot parce qu'un îlot bâti n'a pas de sol visible sous lui —
	# 8,78 ha de canopée que la maquette de masses ne peut pas dessiner.
	_arbres_bloc = VBoxContainer.new()
	_arbres_bloc.add_theme_constant_override("separation", 6)
	_arbres_bloc.visible = false
	v.add_child(_arbres_bloc)
	_arbres_bloc.add_child(HSeparator.new())
	_arbres_valeur = _label("", 13, TEXTE)
	_arbres_valeur.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_arbres_bloc.add_child(_arbres_valeur)
	_arbres_jauge = Jauge.new()
	_arbres_jauge.custom_minimum_size = Vector2(0, 15)
	_arbres_jauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arbres_jauge.colorer(FAIT)
	_arbres_bloc.add_child(_arbres_jauge)
	_arbres_curseur = HSlider.new()
	# Échelle fixe 0 → tous les emplacements, même raison que le solaire : un
	# même pixel doit garder son sens d'un bout à l'autre de la partie.
	_arbres_curseur.min_value = 0.0
	_arbres_curseur.max_value = 100.0
	_arbres_curseur.step = 1.0
	_arbres_curseur.focus_mode = Control.FOCUS_NONE
	_habiller_curseur(_arbres_curseur)
	_arbres_curseur.value_changed.connect(_sur_curseur_arbres)
	_arbres_bloc.add_child(_arbres_curseur)

	_solaire_bloc = VBoxContainer.new()
	_solaire_bloc.add_theme_constant_override("separation", 6)
	_solaire_bloc.visible = false
	v.add_child(_solaire_bloc)
	_solaire_bloc.add_child(HSeparator.new())
	_solaire_valeur = _label("", 13, TEXTE)
	_solaire_bloc.add_child(_solaire_valeur)

	# La lecture d'abord, le réglage ensuite. L'une est pleine et muette,
	# l'autre a une poignée : elles ne se ressemblent pas.
	_solaire_jauge = Jauge.new()
	_solaire_jauge.custom_minimum_size = Vector2(0, 15)
	_solaire_jauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_solaire_bloc.add_child(_solaire_jauge)

	_solaire_curseur = HSlider.new()
	# 🔴 Échelle FIXE 0→100. Monter `min_value` avec la pose faisait changer un
	# même pixel de sens en cours de partie ; le plancher se tient par un
	# rattrapage dans `_sur_curseur`.
	_solaire_curseur.min_value = 0.0
	_solaire_curseur.max_value = 100.0
	_solaire_curseur.step = 1.0
	# ⚠️ Sinon le curseur garde le focus après un clic et AVALE les flèches :
	# la caméra ne tourne plus tant qu'on n'a pas cliqué ailleurs.
	_solaire_curseur.focus_mode = Control.FOCUS_NONE
	_habiller_curseur(_solaire_curseur)
	_solaire_curseur.value_changed.connect(_sur_curseur)
	_solaire_bloc.add_child(_solaire_curseur)

	# 🌿 LE MÊME TOIT, L'AUTRE USAGE. Bloc jumeau du solaire, à trois détails
	# près : il ne rapporte rien, il est borné par la part plate du toit, et son
	# effet est celui de TOUTE la ville — d'où le total affiché en dessous.
	_vert_bloc = VBoxContainer.new()
	_vert_bloc.add_theme_constant_override("separation", 6)
	_vert_bloc.visible = false
	v.add_child(_vert_bloc)
	_vert_bloc.add_child(HSeparator.new())
	_vert_valeur = _label("", 13, TEXTE)
	_vert_valeur.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_vert_bloc.add_child(_vert_valeur)
	_vert_jauge = Jauge.new()
	_vert_jauge.custom_minimum_size = Vector2(0, 15)
	_vert_jauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vert_jauge.colorer(FAIT)
	_vert_bloc.add_child(_vert_jauge)
	_vert_curseur = HSlider.new()
	# 🔴 Échelle FIXE 0→100, la même que le solaire, et c'est tout le propos :
	# les deux curseurs mesurent LE MÊME toit, donc le même pixel dit la même
	# surface. Les plafonds se rattrapent dans les deux `_sur_curseur`.
	_vert_curseur.min_value = 0.0
	_vert_curseur.max_value = 100.0
	_vert_curseur.step = 1.0
	_vert_curseur.focus_mode = Control.FOCUS_NONE
	_habiller_curseur(_vert_curseur)
	_vert_curseur.value_changed.connect(_sur_curseur_vert)
	_vert_bloc.add_child(_vert_curseur)

	# 🏢 DENSIFIER. Deux boutons pour la HAUTEUR — « un étage ou deux » est un
	# choix —, un curseur pour COMBIEN DE BÂTIMENTS. 🪜 Un cran, un bâtiment :
	# le curseur compte des toits, comme celui des arbres compte des arbres, et
	# non des pourcents. Le bloc ne s'ouvre que là où quelque chose peut monter
	# — le patrimoine n'a donc jamais de bouton grisé à expliquer.
	# 🔴 LES ÉTAGES SE CHOISISSENT UNE FOIS PAR ÎLOT : le shader n'a qu'une
	# hauteur pour tout l'îlot. Les deux boutons se verrouillent au premier
	# chantier, le curseur, lui, reprend au cran atteint.
	_dense_bloc = VBoxContainer.new()
	_dense_bloc.add_theme_constant_override("separation", 6)
	_dense_bloc.visible = false
	v.add_child(_dense_bloc)
	_dense_bloc.add_child(HSeparator.new())
	_dense_valeur = _label("", 13, TEXTE)
	_dense_valeur.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dense_bloc.add_child(_dense_valeur)
	var etages_ligne := HBoxContainer.new()
	etages_ligne.add_theme_constant_override("separation", 6)
	_dense_bloc.add_child(etages_ligne)
	for n in [1, 2]:
		var b := Button.new()
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_decision(b, "dense", n)
		etages_ligne.add_child(b)
		_dense_boutons.append(b)
	_dense_jauge = Jauge.new()
	_dense_jauge.custom_minimum_size = Vector2(0, 15)
	_dense_jauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dense_jauge.colorer(FAIT)
	_dense_bloc.add_child(_dense_jauge)
	_dense_curseur = HSlider.new()
	# ⚠️ L'échelle n'est PAS fixe ici, au contraire des trois autres curseurs :
	# elle compte des bâtiments, et chaque îlot n'en a pas le même nombre. Le
	# pas d'un cran garde son sens — un toit —, ce qui est le propos.
	_dense_curseur.min_value = 0.0
	_dense_curseur.step = 1.0
	_dense_curseur.focus_mode = Control.FOCUS_NONE
	_habiller_curseur(_dense_curseur)
	_dense_curseur.value_changed.connect(_sur_curseur_dense)
	_dense_bloc.add_child(_dense_curseur)

	# 🅿️💧 LE SOL RENDU PERMÉABLE (101) : un bouton, les places restent.
	_permeable_bloc = VBoxContainer.new()
	_permeable_bloc.add_theme_constant_override("separation", 6)
	_permeable_bloc.visible = false
	v.add_child(_permeable_bloc)
	_permeable_bloc.add_child(HSeparator.new())
	_permeable_texte = _label("", 12, TEXTE)
	_permeable_texte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_permeable_bloc.add_child(_permeable_texte)
	_permeable_bouton = Button.new()
	_permeable_bouton.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_decision(_permeable_bouton, "permeable", true)
	_permeable_bloc.add_child(_permeable_bouton)

	# 🔄 Un levier fermé ne s'annonce plus dans la fiche (auteur, 2026-10-08).

	# 🗂️ CHAQUE BLOC DE RÉGLAGE SOUS SON THÈME. C'est ce qui fait qu'un onglet
	# porte les chiffres ET la décision : `vert` en tient deux, parce qu'un toit
	# et un alignement d'arbres sont le même thème sur deux couches.
	_bloc_onglet = {
		_repare_bloc: "crue", _camp_bloc: "campagne", _culture_bloc: "campagne",
		_dense_bloc: "bati",
		_solaire_bloc: "energie", _vert_bloc: "vert", _arbres_bloc: "vert",
		_permeable_bloc: "vert",
		_trafic_bloc: "trafic", _berge_bloc: "berge",
	}

	# 🔴 LE RÉCAPITULATIF ET LE BOUTON, EN BAS ET UNE SEULE FOIS. Tous les
	# réglages posés y arrivent : un prix, une durée, un refus. C'est aussi le
	# seul endroit où le jeu dit non — un bouton grisé sans phrase est une
	# panne, sous « il manque 214 k€ » c'est une règle.
	_recap_bloc = VBoxContainer.new()
	_recap_bloc.add_theme_constant_override("separation", 6)
	_recap_bloc.visible = false
	v.add_child(_recap_bloc)
	# 🔄 Les conséquences se lisent en pictogrammes, plus en phrase (auteur,
	# 2026-09-26) : prix, durée, puis ce qui bouge dans la ville.
	var cadre := PanelContainer.new()
	var fond_effets := StyleBoxFlat.new()
	fond_effets.bg_color = Color8(255, 255, 255, 70)
	fond_effets.set_corner_radius_all(_r(9))
	fond_effets.set_content_margin_all(8)
	cadre.add_theme_stylebox_override("panel", fond_effets)
	_recap_bloc.add_child(cadre)
	_recap_effets = HFlowContainer.new()
	_recap_effets.add_theme_constant_override("h_separation", 12)
	_recap_effets.add_theme_constant_override("v_separation", 6)
	cadre.add_child(_recap_effets)
	# Caché : gardé pour `_alerter_cout`, le refus s'écrit dans la pastille du prix.
	_recap_texte = _label("", 12, GRIS_FORT)
	_recap_texte.visible = false
	_recap_bloc.add_child(_recap_texte)
	var boutons := HBoxContainer.new()
	boutons.add_theme_constant_override("separation", 6)
	_recap_bloc.add_child(boutons)
	_recap_annuler = Button.new()
	_recap_annuler.icon = _icone("annuler", 18)
	_recap_annuler.tooltip_text = "Tout remettre comme avant"
	_habiller_secondaire(_recap_annuler)
	_recap_annuler.pressed.connect(func() -> void:
		_vider_pose()
		_maj_fiche())
	boutons.add_child(_recap_annuler)
	_recap_bouton = Button.new()
	_recap_bouton.text = "Mettre en place"
	_recap_bouton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_habiller_principal(_recap_bouton)
	_recap_bouton.pressed.connect(_mettre_en_place)
	boutons.add_child(_recap_bouton)

	_message = _label("", 12, GRIS)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_message)
	_clamper_fiche()


## 📖 TANT QUE LES CARTES DU DÉBUT PASSENT, IL N'Y A PAS DE JEU À L'ÉCRAN
## (auteur, 2026-09-18) : ni compteurs, ni rail, ni commandes du temps. On
## regarde Wehrau, on ne lit pas encore un tableau de bord — et surtout on ne
## voit pas de quoi poser des panneaux avant d'avoir su ce qui s'est passé.
## Les panneaux qui s'ouvrent au clic (fiche, diagnostic, chantiers, calque)
## se referment et reviendront par leur propre chemin.
func montrer_jeu(oui: bool) -> void:
	for panneau in [_ville_panneau, _menu_panneau, _camera_panneau,
			_temps_panneau, retours.compteur, _barre]:
		if panneau != null:
			(panneau as Control).visible = oui
	if oui:
		_placer_detail()
	retours.actualiser_affichage()
	if not oui:
		for panneau in [_fiche_panneau, _diagnostic_panneau,
				_chantiers_panneau, _calque_panneau, _lieu_panneau, _campus_panneau, _detail_panneau]:
			if panneau != null:
				(panneau as Control).visible = false
		_detail_sujet = ""


## 🛠️ L'ÉCRAN DE DÉPART, ET IL NE PROPOSE QUE DEUX CHOSES. « Auteur » ne
## change ni les prix ni la caisse : il livre les chantiers au clic, pour qu'on
## puisse juger la vingtième minute sans la jouer vingt fois.
## Refermer l'écran de départ : le mode a été choisi, au clic ou en drapeau.
func cacher_depart() -> void:
	if _depart_panneau != null:
		_depart_panneau.visible = false
		montrer_jeu(true)


func montrer_depart() -> void:
	# 📖 L'écran de choix fait partie de l'ouverture : pas de compteurs
	# derrière lui non plus, ni le guide, que le récit rouvre à sa fin.
	montrer_jeu(false)
	if ouverture != null:
		ouverture.ouvert = false
		ouverture.actualiser(true)
	if _depart_panneau != null:
		_depart_panneau.visible = true
		return
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(centre)
	_depart_panneau = centre
	var p := PanelContainer.new()
	p.theme = _theme_ui
	_poser_boite(p)
	p.custom_minimum_size.x = 380
	centre.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	v.add_child(_titre("Wehrau, après la crue", 17, ACCENT))
	for choix in [["Mode histoire", false], ["Mode auteur", true]]:
		var b := Button.new()
		b.text = String(choix[0])
		b.focus_mode = Control.FOCUS_NONE
		if not bool(choix[1]):
			_habiller_principal(b)
		var auteur: bool = choix[1]
		b.pressed.connect(func() -> void:
			centre.visible = false
			mode_choisi.emit(auteur))
		v.add_child(b)
	_sans_focus(centre)


## La fiche hésite entre deux besoins : hugger son contenu quand il est court,
## ne jamais dépasser le bas de l'écran quand il est long. Le ScrollContainer
## n'a pas de hauteur propre, donc on la lui donne ici — 26 px de marges de
## boîte, 16 px de bord bas.
func _clamper_fiche() -> void:
	if _fiche_defilement == null or _fiche_contenu == null:
		return
	# La colonne bas-droite (chantiers + compteur) grandit : la fiche lui cède la place.
	var bas := 166.0
	if retours.compteur != null and retours.compteur.visible:
		bas = maxf(bas, retours.pile.get_combined_minimum_size().y + 54.0)
	var dispo: float = get_viewport().get_visible_rect().size.y - _haut_fiche() - bas
	_fiche_defilement.custom_minimum_size.y = minf(
		_fiche_contenu.get_combined_minimum_size().y, maxf(160.0, dispo))


# Le lacet 0 place la caméra AU SUD : repère fixé par « Z vers le sud » dans
# `07_exporter_godot.py:680`, pas ici.
const AZIMUTS := ["du sud", "du sud-est", "de l'est", "du nord-est",
	"du nord", "du nord-ouest", "de l'ouest", "du sud-ouest"]


## LE bouton du jeu, et il se voit : jaune plein, texte sombre, pleine largeur.
## Les autres boutons sont du papier ; celui-là engage la caisse.
func _habiller_principal(b: Button) -> void:
	var plein := StyleBoxFlat.new()
	plein.bg_color = ACCENT_VIF
	plein.border_color = Color8(38, 86, 44)
	plein.set_border_width_all(1)
	plein.set_corner_radius_all(_r(9))
	plein.set_content_margin_all(11)
	if BOIS:
		plein.set_border_width_all(0)
		plein.set_corner_radius_all(10)
	var survol := plein.duplicate()
	survol.bg_color = Color8(104, 160, 78) if BOIS else Color8(78, 142, 86)
	var presse := plein.duplicate()
	presse.bg_color = Color8(78, 128, 56) if BOIS else Color8(46, 100, 54)
	# Grisé, il reste LE bouton vert, éteint : le crème du thème l'effaçait (2026-09-29).
	var eteint := plein.duplicate()
	eteint.bg_color = Color8(204, 212, 188)
	var encre_eteinte := Color8(96, 114, 80)
	var taille := 15
	if VITRE:
		for sb: StyleBoxFlat in [plein, survol, presse, eteint]:
			sb.border_color = _fiche.bord_engage
		survol.bg_color = _fiche.survol_engage
		presse.bg_color = _fiche.appuye_engage
		eteint.bg_color = _fiche.eteint_engage
		encre_eteinte = _fiche.encre_eteint_engage
		taille = _fiche.taille_engage
	b.add_theme_stylebox_override("normal", plein)
	b.add_theme_stylebox_override("hover", survol)
	b.add_theme_stylebox_override("pressed", presse)
	b.add_theme_stylebox_override("disabled", eteint)
	b.add_theme_color_override("font_disabled_color", encre_eteinte)
	b.add_theme_color_override("icon_disabled_color", encre_eteinte)
	b.add_theme_font_size_override("font_size", taille)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)


# ==========================================================================
# 🎓🏛️ L'UNIVERSITÉ ET LA MAIRIE — deux menus, deux portes (79 · 80 · 81)
# ==========================================================================
# Les deux îlots restent des îlots ordinaires : leurs toits, leurs curseurs et
# leur part dans les totaux ne changent pas. Seul un bouton s'ajoute à leur
# fiche, et le menu qu'il ouvre est une AUTRE fiche.

# 🎓 Le campus en trois îlots (auteur, 2026-10-08) : l'université publie, l'institut
# met au point, la bibliothèque range. Un nom et un verbe, rien d'autre. 🔴 Flaggable (90).
const LIEUX := {
	"mairie": {"fid": 20, "nom": "Mairie", "court": "Mairie", "article": "la mairie",
		"quoi": "Une politique n'est pas un chantier : elle dure, et elle se paie tous les mois tant qu'elle tient."},
	"universite": {"fid": 36, "nom": "Université", "court": "Univ.", "article": "l'université",
		"quoi": "Publie les études."},
	"institut": {"fid": 78, "nom": "Institut de recherche", "court": "Institut", "article": "l'institut",
		"quoi": "Met au point de nouvelles façons de bâtir."},
	"bibliotheque": {"fid": 77, "nom": "Bibliothèque", "court": "Biblio.", "article": "la bibliothèque",
		"quoi": "Range les concepts."},
}
const LIEUX_ORDRE := ["mairie", "universite", "institut", "bibliotheque"]
const CAMPUS := ["universite", "institut", "bibliotheque"]
const CAMPUS_TAILLE := Vector2(880, 560)
## 🎓🏛️ Sujets de recherche et subventions arriveront plus tard (auteur, 2026-10-02) :
## l'institut ne montre que les pilotis (`Recherche.SUJETS_OUVERTURE`). Les essais le rouvrent.
var financements_ouverts := false


func _lieu_du_fid(fid: int) -> String:
	for cle in LIEUX_ORDRE:
		if int(LIEUX[cle]["fid"]) == fid:
			return cle
	return ""


func _panneau_lieu() -> void:
	# Même gabarit et même place que la fiche d'îlot : c'est une fiche, et elle
	# prend la place de l'autre plutôt que de s'ajouter à côté (53).
	var p := PanelContainer.new()
	_lieu_panneau = p
	p.theme = _theme_ui
	_poser_boite(p)
	p.anchor_left = 1.0
	p.anchor_right = 1.0
	p.offset_left = -FICHE_LARGEUR - 16.0
	p.offset_right = -16
	p.offset_top = _haut_fiche()
	p.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	p.visible = false
	add_child(p)
	_croix(p, _fermer_lieu)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	_lieu_titre = _bandeau(v, "Mairie")
	_lieu_intro = _label("", 12, GRIS)
	_lieu_intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_lieu_intro)

	# 🎓 LA FENÊTRE DU CAMPUS (auteur, 2026-10-09) : grande, au milieu de la place que
	# laissent la colonne et la fiche, comme le concours ; un onglet par lieu.
	var c := PanelContainer.new()
	_campus_panneau = c
	_poser_boite(c)
	c.anchor_left = 0.5
	c.anchor_right = 0.5
	c.anchor_top = 0.5
	c.anchor_bottom = 0.5
	c.grow_horizontal = Control.GROW_DIRECTION_BOTH
	c.grow_vertical = Control.GROW_DIRECTION_BOTH
	c.offset_left = -FICHE_LARGEUR / 2.0
	c.offset_right = -FICHE_LARGEUR / 2.0
	c.custom_minimum_size = CAMPUS_TAILLE
	# ⚠️ Le verre est à z −1 : sans ce cran, le texte des autres panneaux passe par-dessus.
	c.z_index = 1
	c.visible = false
	add_child(c)
	_croix(c, _fermer_campus)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 10)
	c.add_child(cv)
	_bandeau(cv, "Campus")
	_campus_bloc = HBoxContainer.new()
	_campus_bloc.add_theme_constant_override("separation", 6)
	cv.add_child(_campus_bloc)
	var groupe := ButtonGroup.new()
	for cle in CAMPUS:
		var b := Button.new()
		b.text = String(LIEUX[cle]["nom"])
		# Icône blanche teintée par l'état : sur l'onglet actif, foncé, elle reste lisible.
		b.icon = _icone(cle, 18, Color.WHITE)
		b.toggle_mode = true
		b.button_group = groupe
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_habiller_secondaire(b)
		var actif := StyleBoxFlat.new()
		actif.bg_color = TEXTE
		actif.set_corner_radius_all(_r(9))
		actif.set_content_margin_all(9)
		for etat in ["pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(etat, actif)
			b.add_theme_color_override("font_%s_color" % etat, Color.WHITE)
			b.add_theme_color_override("icon_%s_color" % etat, Color.WHITE)
		for etat in ["normal", "hover"]:
			b.add_theme_color_override("font_%s_color" % etat, TEXTE)
			b.add_theme_color_override("icon_%s_color" % etat, TEXTE)
		b.pressed.connect(ouvrir_lieu.bind(cle))
		_campus_bloc.add_child(b)
	_campus_intro = _label("", 12, GRIS)
	_campus_intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cv.add_child(_campus_intro)
	var defile := ScrollContainer.new()
	defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	defile.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cv.add_child(defile)
	var contenu := VBoxContainer.new()
	contenu.add_theme_constant_override("separation", 8)
	contenu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	defile.add_child(contenu)
	# 🔴 Flaggable (90).
	_univ_vide = _label("Aucune étude publiée.", 12, GRIS)
	contenu.add_child(_univ_vide)

	# 🎓 L'ÉTUDE DE LA PROCHAINE CRUE (auteur, 2026-09-30) : l'université annonce,
	# le diagnostic tient la prévision (n°32). 🔴 Texte de prototype, flaggable (90).
	_etude_bloc = VBoxContainer.new()
	_etude_bloc.add_theme_constant_override("separation", 3)
	contenu.add_child(_etude_bloc)
	_etude_bloc.add_child(HSeparator.new())
	_etude_bloc.add_child(_label("Nouvelle étude · la prochaine crue", 14, TEXTE))
	# 🔄 Quatre tuiles au lieu du paragraphe (auteur, 2026-10-08).
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6)
	_etude_bloc.add_child(g)
	for l in [["dans", "Attendue dans"], ["ilots", "Îlots sous l'eau"],
			["forgerons", "Aux Forgerons"], ["ruines", "Logements ruinés"]]:
		_tuile(g, l[1], _etude_valeurs, l[0])
	var ou := _label("La carte de l'étude est dans Dangers.", 11, GRIS)
	ou.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_etude_bloc.add_child(ou)


	for cle in Politiques.ORDRE:
		_lieu_lignes[cle] = _ligne_lieu(v, "politique",
			String(Politiques.POLITIQUES[cle]["nom"]),
			String(Politiques.POLITIQUES[cle]["quoi"]))
	# 🎓 L'institut range ses sujets par domaine, une colonne chacun ; un domaine
	# sans sujet garde son nom, grisé.
	_recherche_bloc = HBoxContainer.new()
	_recherche_bloc.add_theme_constant_override("separation", 14)
	contenu.add_child(_recherche_bloc)
	for d in Recherche.DOMAINES:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 4)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_recherche_bloc.add_child(col)
		var titre := _titre_section(col, String(d[1]))
		for cle in Recherche.ORDRE:
			if String(Recherche.SUJETS[cle]["domaine"]) == d[0]:
				_lieu_lignes[cle] = _ligne_lieu(col, "recherche",
					String(Recherche.SUJETS[cle]["nom"]),
					String(Recherche.SUJETS[cle]["quoi"]))
		if col.get_child_count() == 1:
			titre.modulate.a = 0.45

	# 📖 LA BIBLIOTHÈQUE (101, A : celle de l'université), sous les sujets. 🔴 Textes flaggables (90).
	_biblio_bloc = VBoxContainer.new()
	_biblio_bloc.add_theme_constant_override("separation", 6)
	contenu.add_child(_biblio_bloc)
	_biblio_liste = VBoxContainer.new()
	_biblio_liste.add_theme_constant_override("separation", 4)
	_biblio_bloc.add_child(_biblio_liste)
	_page_bloc = VBoxContainer.new()
	_page_bloc.add_theme_constant_override("separation", 6)
	_page_bloc.visible = false
	_biblio_bloc.add_child(_page_bloc)
	_page_chapitre = _label("", 11, GRIS)
	_page_bloc.add_child(_page_chapitre)
	_page_titre = _label("", 15, TEXTE)
	_page_bloc.add_child(_page_titre)
	_page_texte = _label("", 12, TEXTE)
	_page_texte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_page_bloc.add_child(_page_texte)
	_page_leviers = VBoxContainer.new()
	_page_leviers.add_theme_constant_override("separation", 3)
	_page_bloc.add_child(_page_leviers)
	_page_voir = Button.new()
	_page_voir.text = "Voir à Wehrau"
	_page_voir.focus_mode = Control.FOCUS_NONE
	_habiller_principal(_page_voir)
	_page_voir.pressed.connect(func() -> void: concept_demande.emit(_page_ouverte))
	_page_bloc.add_child(_page_voir)
	var retour := Button.new()
	retour.text = "Toutes les pages"
	retour.focus_mode = Control.FOCUS_NONE
	_habiller_secondaire(retour)
	retour.pressed.connect(func() -> void: ouvrir_page(""))
	_page_bloc.add_child(retour)

	_lieu_message = _label("", 11, GRIS)
	_lieu_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_lieu_message)


## Une ligne de menu : ce que c'est, ce que ça fait, où ça en est, et LE bouton.
func _ligne_lieu(parent: VBoxContainer, genre: String, nom: String,
		quoi: String) -> Dictionary:
	var bloc := VBoxContainer.new()
	bloc.add_theme_constant_override("separation", 3)
	parent.add_child(bloc)
	bloc.add_child(HSeparator.new())
	bloc.add_child(_label(nom, 14, TEXTE))
	var l_quoi := _label(quoi, 11, GRIS)
	l_quoi.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bloc.add_child(l_quoi)
	var jauge := Jauge.new()
	jauge.custom_minimum_size = Vector2(0, 9)
	jauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	jauge.colorer(ACCENT_VIF)
	jauge.visible = genre == "recherche"
	bloc.add_child(jauge)
	var etat := _label("", 12, TEXTE)
	etat.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bloc.add_child(etat)
	var b := Button.new()
	_habiller_principal(b)
	b.focus_mode = Control.FOCUS_NONE
	bloc.add_child(b)
	return {"bloc": bloc, "genre": genre, "etat": etat, "jauge": jauge, "bouton": b}


func ouvrir_lieu(cle: String, page := "") -> void:
	if not LIEUX.has(cle):
		return
	_page_ouverte = page if _page_ok(page) else ""
	if _page_ouverte != "" and ouverture != null:
		ouverture.page_lue(_page_ouverte)
	_biblio_cle = ""
	var campus: bool = cle in CAMPUS
	if campus:
		_pause_campus()
	elif _campus_panneau.visible:
		_campus_panneau.visible = false
		_reprendre_campus()
	_lieu_ouvert = cle
	_lieu_panneau.visible = not campus
	_campus_panneau.visible = campus
	if campus:
		_campus_intro.text = String(LIEUX[cle]["quoi"])
	else:
		_fiche_panneau.visible = false
		_lieu_titre.text = String(LIEUX[cle]["nom"])
		_lieu_intro.text = String(LIEUX[cle]["quoi"])
	_brancher_lieu()
	_maj_lieu()


## 🎓 Le campus trouvé sur la carte : la fenêtre s'ouvre sur l'université et l'étude.
func ouvrir_campus() -> void:
	ouvrir_lieu("universite")
	if ouverture != null:
		ouverture.campus_ouvert()


## 🎓 Un îlot du campus cliqué ouvre aussi sa fenêtre, une fois le campus trouvé.
func ouvrir_lieu_clique(couche: String, fid: int) -> void:
	var cle := _lieu_du_fid(fid) if couche == "i" else ""
	if cle in CAMPUS and _verrou() == "" and (ouverture == null or ouverture.rail_visible(cle)):
		ouvrir_lieu(cle)


## ⏸️ La fenêtre ouverte, le temps s'arrête (auteur, 2026-10-09).
func _pause_campus() -> void:
	if _vitesse_avant_campus >= 0.0:
		return
	_vitesse_avant_campus = _vitesse_courante
	if _vitesse_courante > 0.0:
		vitesse_demandee.emit(0.0)
		_vitesse_courante = 0.0


## ▶️ Fermée, il repart à sa vitesse d'avant, sauf si le joueur l'a relancé entre-temps.
func _reprendre_campus() -> void:
	if _vitesse_avant_campus > 0.0 and _vitesse_courante == 0.0:
		vitesse_demandee.emit(_vitesse_avant_campus)
		_vitesse_courante = _vitesse_avant_campus
	_vitesse_avant_campus = -1.0


# ==========================================================================
# 🏛️ LE CONCOURS (104) — les quatre projets d'un îlot, côte à côte
# ==========================================================================
# Le même concours vaut pour toute la zone : ce qui change d'un îlot à l'autre,
# ce sont les chiffres (l'eau n'y monte pas pareil), pas les projets.

## 🔴 Textes flaggables (90).
const PROJETS_QUOI := {
	"tradition": "Les maisons d'avant, au même endroit.",
	"moderne": "Plus de logements, isolés, sous un toit plat.",
	"pilotis": "Le rez sur poteaux : l'eau passe dessous.",
	"parc": "Personne ne revient : une prairie qui boit la crue.",
}


func _panneau_projets() -> void:
	var p := PanelContainer.new()
	_projets_panneau = p
	p.theme = _theme_ui
	_poser_boite(p)
	# Au milieu de la place que laissent la colonne et la fiche, en bas : l'îlot reste visible.
	p.anchor_left = 0.5
	p.anchor_right = 0.5
	p.anchor_top = 1.0
	p.anchor_bottom = 1.0
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	p.offset_left = -FICHE_LARGEUR / 2.0
	p.offset_right = -FICHE_LARGEUR / 2.0
	p.offset_bottom = -20.0
	p.visible = false
	add_child(p)
	_croix(p, fermer_projets)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	_projets_titre = _bandeau(v, "")
	_projets_intro = _label("", 12, GRIS)
	v.add_child(_projets_intro)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	v.add_child(h)
	for f in Ville.RECONSTRUCTIONS_ORDRE:
		var carte := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = FOND_FORT
		sb.set_corner_radius_all(_r(9))
		sb.set_content_margin_all(10)
		carte.add_theme_stylebox_override("panel", sb)
		carte.custom_minimum_size = Vector2(218, 0)
		h.add_child(carte)
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 5)
		carte.add_child(cv)
		cv.add_child(_label(str(Ville.RECONSTRUCTIONS[f]["nom"]), 16, TEXTE))
		# L'îlot livré, comme la miniature de la fiche (auteur, 2026-10-06).
		var vue := TextureRect.new()
		vue.texture = apercus_projets.get(f)
		vue.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		vue.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		vue.custom_minimum_size = Vector2(0, Apercu.TAILLE_PROJET.y)
		vue.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cv.add_child(vue)
		var quoi := _label(PROJETS_QUOI[f], 11, GRIS)
		quoi.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cv.add_child(quoi)
		cv.add_child(HSeparator.new())
		var lignes := VBoxContainer.new()
		lignes.add_theme_constant_override("separation", 4)
		lignes.size_flags_vertical = Control.SIZE_EXPAND_FILL
		cv.add_child(lignes)
		var b := Button.new()
		_habiller_principal(b)
		b.focus_mode = Control.FOCUS_NONE
		# Le choix se pose comme un bouton de la fiche, puis l'écran se retire.
		_decision(b, "reparer", f)
		b.pressed.connect(fermer_projets)
		cv.add_child(b)
		_projets_cartes[f] = {"bouton": b, "lignes": lignes}


func ouvrir_projets() -> void:
	if _fiche_couche != "i" or _fiche_fid < 0 or not ville.concours_rendu(_mois) \
			or not ville.concours_utile(_fiche_fid):
		return
	_projets_cle = ""
	_projets_panneau.visible = true
	_maj_projets()
	retours.actualiser_affichage()
	projets_ouverts.emit(_fiche_fid)


## L'îlot dont l'écran du concours est ouvert, sinon -1 : la maquette y règle les miniatures.
func projets_fid() -> int:
	return _fiche_fid if _projets_panneau != null and _projets_panneau.visible else -1


func fermer_projets() -> void:
	if _projets_panneau != null:
		_projets_panneau.visible = false
		retours.actualiser_affichage()


## Appelé à chaque image avec la fiche : les boutons suivent la pose, les chiffres
## ne se remesurent qu'au changement d'îlot ou de mois (quatre villes d'essai).
func _maj_projets() -> void:
	if not _projets_panneau.visible:
		return
	if _fiche_couche != "i" or _fiche_fid < 0 or not ville.concours_rendu(_mois) \
			or ville.est_repare("i", _fiche_fid):
		fermer_projets()
		return
	for f in _projets_cartes:
		var b: Button = _projets_cartes[f]["bouton"]
		_posee(b, "reparer", "Choisir", f)
		if str(_pose.get("reparer", "")) == f:
			b.text = "✓ Choisi"
	var cle := "%d %d" % [_fiche_fid, int(_mois)]
	if cle == _projets_cle:
		return
	_projets_cle = cle
	_projets_titre.text = "Concours · %s" % lieux.nom("i", _fiche_fid)
	_projets_intro.text = "%.0f logements perdus. La prochaine crue y mettrait %s m d'eau." % [
		ville.base("i", _fiche_fid, "logements_sinistres"),
		_nb(ville.valeur("i", _fiche_fid, "hauteur_eau_annonce", _mois), 1)]
	for f in _projets_cartes:
		var lignes: VBoxContainer = _projets_cartes[f]["lignes"]
		for c in lignes.get_children():
			lignes.remove_child(c)
			c.queue_free()
		for e in _projet(f):
			_effet(e[0], e[1], e[2], lignes)
	# La ville d'essai a servi aux quatre : le récapitulatif se remesure.
	_recap_cle = ""


## Les mêmes cinq lignes pour les quatre projets, dans le même ordre : c'est ce qui
## les rend comparables. Mesurées comme `consequences`, sur la ville d'essai.
func _projet(f: String) -> Array:
	var r := {"reparer": f}
	var cout := ville.cout_commande_ke("i", _fiche_fid, r, _mois)
	var duree := ville.duree_commande_mois("i", _fiche_fid, r, _mois)
	var out := [["caisse", "%s k€" % _milliers(cout), 0],
		["duree", _duree(duree), 0]]
	if ville_essai == null:
		return out
	var t := _mois + duree + 0.05
	ville_essai.importer_partie(ville.exporter_partie())
	ville_essai.crediter_essai_ke(cout)
	ville_essai.commander("i", _fiche_fid, r, _mois)
	var logements := ville_essai.valeur("i", _fiche_fid, "logements", t) \
		- ville.valeur("i", _fiche_fid, "logements", t)
	out.append(["logement", "+%d logements" % int(roundf(logements)), 1] if logements >= 1.0
		else ["logement", "Personne ne rentre", -1])
	var k0 := ville_essai.capital(_mois) - ville.capital(_mois)
	var k1 := ville_essai.capital(t) - ville.capital(t) - k0
	if absf(k0) >= 0.5:
		out.append(["capital", "%+d confiance tout de suite" % int(roundf(k0)), _sens(k0)])
	if absf(k1) >= 0.5:
		out.append(["capital", "%+d confiance à la livraison" % int(roundf(k1)), _sens(k1)])
	var exposes := float(ville_essai.prochaine_crue(t)["logements_perdus"]) \
		- float(ville.prochaine_crue(t)["logements_perdus"])
	var eau := (float(ville_essai.degats(t).get("eau_prochaine_m", 0.0))
		- float(ville.degats(t).get("eau_prochaine_m", 0.0))) * 100.0
	if exposes >= 1.0:
		out.append(["eau", "%d perdus à la prochaine crue" % int(roundf(exposes)), -1])
	elif eau <= -0.1:
		out.append(["eau", "%s cm de crue dans toute la ville" % (
			"%+d" % int(roundf(eau)) if eau <= -1.0 else ("%+.1f" % eau).replace(".", ",")), 1])
	else:
		out.append(["eau", "Rien de perdu à la prochaine crue", 1])
	return out


## ✕ En haut à droite d'une fiche (auteur, 2026-09-28) ; remplace le bouton « Fermer ».
## ⚠️ `top_level`, sinon le `PanelContainer` l'étire sur toute la fiche.
func _croix(p: Control, action: Callable) -> void:
	var b := Button.new()
	b.name = "Croix"
	b.icon = _icone("croix", 16, GRIS)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.tooltip_text = "Fermer"
	b.focus_mode = Control.FOCUS_NONE
	b.set_as_top_level(true)
	b.size = Vector2(26, 26)
	var nu := StyleBoxFlat.new()
	nu.bg_color = Color(0, 0, 0, 0)
	nu.set_corner_radius_all(_r(13))
	var survol := nu.duplicate() as StyleBoxFlat
	survol.bg_color = Color(FOND_FORT, 0.9)
	b.add_theme_stylebox_override("normal", nu)
	b.add_theme_stylebox_override("hover", survol)
	b.add_theme_stylebox_override("pressed", survol)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(action)
	p.add_child(b)
	var suivre := func() -> void:
		b.global_position = p.global_position + Vector2(p.size.x - 32.0, 6.0)
	p.item_rect_changed.connect(suivre)
	suivre.call()


func _fermer_fiche() -> void:
	fermer_projets()
	_vider_pose()
	_message.text = ""
	_fiche_fid = -1
	_fiche_panneau.visible = false
	fiche_fermee.emit()


func _fermer_lieu() -> void:
	var campus: bool = _lieu_ouvert in CAMPUS
	_lieu_ouvert = ""
	_lieu_panneau.visible = false
	if campus:
		_campus_panneau.visible = false
		_reprendre_campus()
	else:
		_fiche_panneau.visible = true


## ✕ de la fenêtre : un îlot du campus en fiche se referme avec elle, la ville
## nue laisse clignoter les îlots à rebâtir.
func _fermer_campus() -> void:
	_fermer_lieu()
	if _fiche_couche == "i" and _lieu_du_fid(_fiche_fid) in CAMPUS:
		_fermer_fiche()


## Les boutons ne se rebranchent qu'au changement de menu : une connexion posée
## à chaque image en empilerait soixante par seconde.
func _brancher_lieu() -> void:
	for cle in _lieu_lignes:
		var l: Dictionary = _lieu_lignes[cle]
		var b: Button = l["bouton"]
		for c in b.pressed.get_connections():
			b.pressed.disconnect(c["callable"])
		var k: String = cle
		if String(l["genre"]) == "recherche":
			b.pressed.connect(func() -> void:
				if ville.financer_recherche(k, _mois):
					var sujet: Dictionary = Recherche.SUJETS[k]
					retours.consigner("%s : financement engagé, %s k€/mois pendant %s." % [sujet["nom"], _milliers(sujet["ke_mois"]), _duree(sujet["mois"])], _mois)
					retours.actualiser(_mois)
				_maj_lieu())
		else:
			b.pressed.connect(func() -> void:
				if ville.basculer_politique(k, _mois):
					var politique: Dictionary = Politiques.POLITIQUES[k]
					retours.consigner("%s : %s" % [politique["nom"], "%s k€/mois · %s" % [_milliers(politique["ke_mois"]), politique["quoi"]] if Politiques.active(ville, k) else "subvention arrêtée, prélèvements terminés."], _mois)
				_maj_lieu())


func _maj_lieu() -> void:
	if _lieu_ouvert == "":
		return
	_lieu_intro.visible = financements_ouverts
	_campus_intro.visible = _page_ouverte == ""
	for i in CAMPUS.size():
		(_campus_bloc.get_child(i) as Button).set_pressed_no_signal(CAMPUS[i] == _lieu_ouvert)
	_etude_bloc.visible = _lieu_ouvert == "universite" and etude_publiee()
	_univ_vide.visible = _lieu_ouvert == "universite" and not etude_publiee()
	_recherche_bloc.visible = _lieu_ouvert == "institut"
	_biblio_bloc.visible = _lieu_ouvert == "bibliotheque"
	if _biblio_bloc.visible:
		_maj_bibliotheque()
	if _etude_bloc.visible:
		var p := ville.prochaine_crue(_mois)
		var forgerons := ville.base("i", Ouverture.MAISONS, "hauteur_eau_max")
		(_etude_valeurs["dans"] as Label).text = "6 à 8 ans"
		(_etude_valeurs["ilots"] as Label).text = "%d (%d cette fois)" % [
			int(p["ilots_sous_eau"]), int(p["ilots_cette_annee"])]
		(_etude_valeurs["forgerons"] as Label).text = "%s m (%s m)" % [
			_nb(ville.valeur("i", Ouverture.MAISONS, "hauteur_eau_annonce", _mois), 1), _nb(forgerons, 1)]
		(_etude_valeurs["ruines"] as Label).text = _nb(float(p["logements_perdus"]), 0)
	for cle in _lieu_lignes:
		var l: Dictionary = _lieu_lignes[cle]
		var bloc: VBoxContainer = l["bloc"]
		var recherche: bool = String(l["genre"]) == "recherche"
		bloc.visible = _lieu_ouvert == "institut" if recherche \
			else (_lieu_ouvert == "mairie" and financements_ouverts)
		if not bloc.visible:
			continue
		if recherche:
			# 🏗️ Les pilotis dès l'ouverture ; le reste garde son nom, grisé, jusqu'aux financements.
			var ouvert: bool = cle in Recherche.SUJETS_OUVERTURE or financements_ouverts
			bloc.modulate.a = 1.0 if ouvert else 0.45
			(l["jauge"] as Control).visible = ouvert
			(l["etat"] as Control).visible = ouvert
			(l["bouton"] as Control).visible = ouvert
			if ouvert:
				_maj_ligne_recherche(String(cle), l)
		else:
			_maj_ligne_politique(String(cle), l)
	# 🔴 Ce qui manque est DIT, pas simulé à moitié : une règle ne coûte pas de
	# capital, elle en demande un seuil (auteur, 2026-09-30) ; aucune n'est écrite.
	_lieu_message.text = "" if _lieu_ouvert != "mairie" else \
		"Les règles — stationnement payant, toit vert obligatoire au neuf — " \
		+ "s'ouvriront à partir d'un certain niveau de confiance, sans la dépenser."


## 📖 Une page existe dès qu'elle a un texte ; elle s'ouvre quand la ville l'a rencontrée.
func _page_ok(id: String) -> bool:
	return Livre.CONCEPTS.has(id) and str(Livre.CONCEPTS[id]["texte"]) != "" \
		and (ouverture == null or ouverture.concept_ouvert(id))


func ouvrir_page(id: String) -> void:
	_page_ouverte = id if _page_ok(id) else ""
	if _page_ouverte != "" and ouverture != null:
		ouverture.page_lue(_page_ouverte)
	_biblio_cle = ""
	_maj_lieu()


## Refait seulement quand ce qu'elle montre change : appelée à chaque image.
func _maj_bibliotheque() -> void:
	var etats := []
	for id in Livre.ORDRE:
		etats.append("%s%s%s" % [id, _page_ok(id),
			ouverture != null and ouverture.page_nouvelle(id)])
	for l in Livre.LEVIERS:
		etats.append(_levier_ferme(l))
	var cle := "%s|%s" % [_page_ouverte, "/".join(etats)]
	if cle == _biblio_cle:
		return
	_biblio_cle = cle
	_biblio_liste.visible = _page_ouverte == ""
	_page_bloc.visible = _page_ouverte != ""
	for c in _biblio_liste.get_children():
		_biblio_liste.remove_child(c)
		c.queue_free()
	if _page_ouverte == "":
		for id in Livre.ORDRE:
			var c: Dictionary = Livre.CONCEPTS[id]
			var ouverte := _page_ok(id)
			var b := Button.new()
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			b.focus_mode = Control.FOCUS_NONE
			var nouveau: bool = ouverte and ouverture != null and ouverture.page_nouvelle(id)
			b.text = ("%s · %s" % [c["chapitre"], c["titre"]] if c["chapitre"] != c["titre"]
				else str(c["titre"])) + (" · nouveau" if nouveau else "")
			_habiller_secondaire(b)
			b.disabled = not ouverte
			var k: String = id
			b.pressed.connect(func() -> void: ouvrir_page(k))
			# 🔄 Une page fermée garde son nom, grisé, sans ce qui l'ouvrira (auteur, 2026-10-08).
			_biblio_liste.add_child(b)
		return
	var p: Dictionary = Livre.CONCEPTS[_page_ouverte]
	_page_chapitre.text = str(p["chapitre"]).to_upper()
	_page_titre.text = str(p["titre"])
	_page_texte.text = str(p["texte"])
	for c in _page_leviers.get_children():
		_page_leviers.remove_child(c)
		c.queue_free()
	_titre_section(_page_leviers, "Ses leviers")
	for l in p["leviers"]:
		var ferme := _levier_ferme(l)
		_page_leviers.add_child(_label(("✓ " if ferme == "" else "○ ") + str(Livre.LEVIERS[l]),
			12, TEXTE if ferme == "" else GRIS))
	_page_voir.visible = str(p["voir"]) != ""


func _maj_ligne_recherche(cle: String, l: Dictionary) -> void:
	var s: Dictionary = Recherche.SUJETS[cle]
	var etat: Label = l["etat"]
	var b: Button = l["bouton"]
	var jauge: Jauge = l["jauge"]
	if Recherche.acquis(ville, cle, _mois):
		jauge.regler(1.0, 1.0)
		etat.text = "Acquis au mois %d · vaut pour toute la ville." % \
			int(roundf(Recherche.mois_palier(ville, cle)))
		b.visible = false
	elif ville.recherche_engagee(cle):
		var reste: float = Recherche.reste_mois(ville, cle, _mois)
		jauge.regler(1.0 - reste / float(s["mois"]), 1.0)
		etat.text = "En cours · %s · %s k€/mois" % [
			_duree(reste), _milliers(float(s["ke_mois"]))]
		b.visible = false
	else:
		jauge.regler(0.0, 0.0)
		etat.text = "%s k€/mois pendant %d mois · %s k€ en tout" % [
			_milliers(float(s["ke_mois"])), int(float(s["mois"])),
			_milliers(Recherche.cout_total_ke(cle))]
		b.visible = true
		b.disabled = _caisse_ke < float(s["ke_mois"])
		b.text = "Financer" if not b.disabled else "Caisse insuffisante"


func _maj_ligne_politique(cle: String, l: Dictionary) -> void:
	var pol: Dictionary = Politiques.POLITIQUES[cle]
	var etat: Label = l["etat"]
	var b: Button = l["bouton"]
	var ke_mois := float(pol["ke_mois"])
	var verse := Politiques.mois_actifs(ville, cle, _mois) * ke_mois
	b.visible = true
	if Politiques.active(ville, cle):
		etat.text = "En vigueur · %s k€/mois · %s k€ déjà versés" % [
			_milliers(ke_mois), _milliers(verse)]
		b.disabled = false
		b.text = "Retirer"
	else:
		etat.text = "%s k€/mois dès la signature" % _milliers(ke_mois)
		if verse > 0.0:
			etat.text += " · %s k€ versés avant retrait" % _milliers(verse)
		b.disabled = _caisse_ke < ke_mois
		b.text = "Signer" if not b.disabled else "Caisse insuffisante"


func _panneau_camera() -> void:
	# Les gestes de caméra ne se devinent pas, et un jeu qui oblige à ouvrir un
	# fichier pour les connaître n'en est pas un.
	var p := PanelContainer.new()
	p.theme = _theme_ui
	_poser_boite(p)
	p.anchor_top = 1.0
	p.anchor_bottom = 1.0
	p.offset_left = 16
	# Le coin est libre depuis que le temps est passé au centre (2026-09-28).
	p.offset_bottom = -16
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(p)
	_camera_panneau = p

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	p.add_child(v)
	# 🔄 « vue du sud-est, 42° au-dessus » est passé dans la bulle de la
	# boussole : la flèche dit déjà où est le nord.
	var boutons := HBoxContainer.new()
	v.add_child(boutons)
	_camera_nord = Button.new()
	_camera_nord.name = "Boussole"
	_camera_nord.custom_minimum_size = Vector2(44, 36)
	_camera_nord.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_camera_nord.focus_mode = Control.FOCUS_NONE
	_camera_nord.pressed.connect(func(): nord_demande.emit())
	boutons.add_child(_camera_nord)
	_camera_dessus = Button.new()
	_camera_dessus.name = "VueDessus"
	_camera_dessus.custom_minimum_size = Vector2(44, 36)
	_camera_dessus.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_camera_dessus.focus_mode = Control.FOCUS_NONE
	_camera_dessus.pressed.connect(func(): dessus_demande.emit())
	boutons.add_child(_camera_dessus)
	var aide := ["Glisser : déplacer · Ctrl : tourner", "Molette : zoom · V : toute la ville"]
	# 🔲 En vitre, l'aide passe en infobulle du panneau (auteur, 2026-10-02 : « du bruit »).
	if VITRE:
		p.tooltip_text = "\n".join(aide)
		(p.get_theme_stylebox("panel") as StyleBoxFlat).set_content_margin_all(5)
		return
	for ligne in aide:
		v.add_child(_label(ligne, 12, GRIS))


func maj_camera(lacet: float, hauteur: float) -> void:
	if _camera_nord == null:
		return
	var l := fmod(fmod(lacet, 360.0) + 360.0, 360.0)
	var i := int(roundf(l / 45.0)) % 8
	_camera_nord.tooltip_text = "Vue %s, %d° au-dessus. Remettre le nord en haut." % [
		AZIMUTS[i], int(roundf(hauteur))]
	# L'aiguille montre où est le nord à l'écran, en huit crans.
	_camera_nord.icon = _icone("boussole", 20, TEXTE, i * 45)
	var dessus := hauteur >= 89.5
	_camera_dessus.icon = _icone("cube" if dessus else "plan", 20)
	_camera_dessus.tooltip_text = "Revenir à la vue en 3D." if dessus \
		else "Vue de dessus, comme un plan."


## 📊 LA BARRE DES COMPTEURS (auteur, 2026-09-28, image de référence) : caisse,
## énergie et CO₂ au centre du haut. Aucun nombre neuf — ceux du bilan, recopiés
## par `maj`. Elle attend, comme le bilan, la fin du premier pont.
func _barre_compteurs() -> void:
	var p := PanelContainer.new()
	_poser_boite(p, true)
	var sb := p.get_theme_stylebox("panel") as StyleBoxFlat
	sb.content_margin_top = 12 if BOIS else 8
	sb.content_margin_bottom = 12 if BOIS else 8
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	p.anchor_left = 0.5
	p.anchor_right = 0.5
	p.offset_top = HAUT
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.visible = false
	add_child(p)
	_barre = p
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	p.add_child(h)
	var lignes := [
		["caisse", "caisse", Color8(78, 121, 67), "Caisse"],
		["capital", "capital", Color8(122, 84, 48), "Confiance"],
		["conso", "conso", Color8(198, 126, 32), "Consommation"],
		["production", "production", Color8(214, 158, 44), "Solaire"],
		["co2", "co2", Color8(104, 116, 108), "CO₂"],
	]
	# 🔲 En vitre, l'argent et la confiance seuls (auteur, 2026-10-02) : l'énergie est à gauche.
	if VITRE:
		lignes.resize(2)
	for ligne in lignes:
		if h.get_child_count() > 0:
			var filet := ColorRect.new()
			filet.color = Color(TEXTE, 0.12)
			filet.custom_minimum_size = Vector2(1, 0)
			h.add_child(filet)
		# 🔄 Le mot sous le nombre est passé dans l'infobulle (auteur, 2026-09-28).
		var bloc := HBoxContainer.new()
		bloc.add_theme_constant_override("separation", 8)
		bloc.tooltip_text = ligne[3]
		bloc.mouse_filter = Control.MOUSE_FILTER_STOP
		h.add_child(bloc)
		# 🧾 Au clic, pourquoi le compteur monte ou baisse (auteur, 2026-10-02).
		if ligne[0] in ["caisse", "capital"]:
			bloc.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			bloc.gui_input.connect(_clic_compteur.bind(ligne[0]))
		var pic := TextureRect.new()
		pic.texture = _icone(ligne[1], 22, ligne[2])
		pic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bloc.add_child(pic)
		var valeur := _titre("—", 15, TEXTE)
		valeur.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		bloc.add_child(valeur)
		_barre_valeurs[ligne[0]] = valeur
	_detail_panneau = PanelContainer.new()
	_poser_boite(_detail_panneau)
	_detail_panneau.anchor_left = 0.5
	_detail_panneau.anchor_right = 0.5
	_detail_panneau.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_detail_panneau.custom_minimum_size.x = 360
	_detail_panneau.visible = false
	add_child(_detail_panneau)
	_detail_liste = VBoxContainer.new()
	_detail_liste.add_theme_constant_override("separation", 3)
	_detail_panneau.add_child(_detail_liste)


func _clic_historique(e: InputEvent) -> void:
	if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		return
	_historique_ouvert = not _historique_ouvert
	_detail_lignes = []
	_maj_detail.call_deferred(ville.indicateurs(_mois), _mois)


func _clic_compteur(e: InputEvent, sujet: String) -> void:
	if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		return
	ouvrir_detail("" if _detail_sujet == sujet else sujet)


## "caisse", "capital", ou "" pour fermer. Public : `--interface` le capture.
func ouvrir_detail(sujet: String) -> void:
	_detail_sujet = sujet
	_detail_lignes = []
	_historique_ouvert = false
	_detail_panneau.offset_top = _barre.position.y + _barre.size.y + 6.0
	_maj_detail(ville.indicateurs(_mois), _mois)
	retours.actualiser_affichage()


const HISTORIQUE := "Depuis le mois 0"
const GENRES_DEPENSE := {
	"camp": "Camps", "demande": "Campement amélioré", "pont": "Ponts",
	"rue": "Rues déblayées", "ilot": "Îlots relevés", "solaire": "Panneaux solaires",
	"vert": "Toits verts", "dense": "Étages ajoutés", "berge": "Berges",
	"plantation": "Arbres plantés", "culture": "Cultures", "concours": "Concours",
	"labour": "Labours",
	"autres": "Autres chantiers",
}


## Une ligne du détail : [texte, valeur affichée, signe, gras]. Valeur nulle = titre de bloc.
static func _ligne_ke(txt: String, ke: float) -> Array:
	return [txt, ("+" if ke >= 0.0 else "−") + _milliers(absf(ke)) + " k€", signf(ke), false]


## 🧾 LE DÉTAIL D'UN COMPTEUR : ce qui le fait bouger chaque mois, puis tout ce
## qui l'a fait bouger depuis le mois 0 — la somme retombe sur le compteur.
func _maj_detail(indic: Dictionary, mois: float) -> void:
	if not _barre.visible:
		_detail_sujet = ""
	_detail_panneau.visible = _detail_sujet != ""
	if _detail_sujet == "":
		return
	var lignes := _lignes_caisse(indic, mois) if _detail_sujet == "caisse" else _lignes_capital(mois)
	if lignes == _detail_lignes:
		return
	_detail_lignes = lignes
	for c in _detail_liste.get_children():
		_detail_liste.remove_child(c)
		c.queue_free()
	var replie := false
	for l in lignes:
		if l[1] == null:
			if _detail_liste.get_child_count() > 0:
				var marge := Control.new()
				marge.custom_minimum_size.y = 6
				_detail_liste.add_child(marge)
			replie = l[0] == HISTORIQUE and not _historique_ouvert
			if l[0] == HISTORIQUE:
				# Des mots plutôt qu'un chevron : aucune police du jeu n'est sûre d'avoir ▸.
				var t := _titre_section(_detail_liste,
					"Voir l'historique" if replie else "Masquer l'historique")
				t.add_theme_color_override("font_color", ACCENT)
				t.mouse_filter = Control.MOUSE_FILTER_STOP
				t.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				t.tooltip_text = "Tout ce qui a fait bouger le compteur depuis le mois 0"
				t.gui_input.connect(_clic_historique)
			else:
				_titre_section(_detail_liste, l[0])
			continue
		if replie:
			continue
		if l[3]:
			_detail_liste.add_child(HSeparator.new())
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		_detail_liste.add_child(h)
		var mot := _titre(l[0], 13, TEXTE) if l[3] else _label(l[0], 13, TEXTE)
		mot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		mot.custom_minimum_size.x = 220
		h.add_child(mot)
		var coul := TEXTE
		if not l[3]:
			coul = FAIT_TEXTE if l[2] > 0 else (ALERTE if l[2] < 0 else GRIS)
		var val := _titre(str(l[1]), 13, coul)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(val)


## 🧾 Ce qui rentre et ce qui part chaque mois, en deux blocs totalisés (auteur, 2026-10-08).
## `flux` : [texte, montant signé par mois] ; `fmt` met en forme un montant absolu.
static func _blocs_mensuels(flux: Array, fmt: Callable, seuil: float) -> Array:
	var out := []
	var solde := 0.0
	for sens in [1.0, -1.0]:
		out.append(["Rentre chaque mois" if sens > 0.0 else "Part chaque mois", null, 0, false])
		var tot := 0.0
		for f in flux:
			if absf(f[1]) >= seuil and signf(f[1]) == sens:
				out.append([f[0], ("+" if sens > 0.0 else "−") + fmt.call(absf(f[1])), sens, false])
				tot += f[1]
		if tot == 0.0:
			out.append(["Rien pour l'instant", fmt.call(0.0), 0, false])
		else:
			out.append(["Total", ("+" if sens > 0.0 else "−") + fmt.call(absf(tot)), sens, true])
		solde += tot
	out.append(["Solde du mois", ("+" if solde >= 0.0 else "−") + fmt.call(absf(solde)), signf(solde), true])
	return out


func _lignes_caisse(indic: Dictionary, mois: float) -> Array:
	var out := []
	var dense_mois := 0.0
	if mois > 0.01:
		dense_mois = (ville.solde_dense_ke(mois) - ville.solde_dense_ke(mois - 0.01)) / 0.01
	var nourriture := (ville.nourriture_depart() - ville.nourriture_personnes(mois)) \
		* Ville.NOURRITURE_KE_PERSONNE_MOIS
	var flux := [
		["Dotation de la transition", Ville.DOTATION_KE_MOIS],
		["Électricité solaire vendue", float(indic["recette_ke_an"]) / 12.0],
		["Loyers des étages ajoutés", dense_mois],
		["Aide aux personnes sans abri", -ville.aide_mensuelle_ke(mois)],
		["Nourriture achetée en plus" if nourriture > 0.0 else "Nourriture économisée", -nourriture],
		["Université et mairie", -ville.charge_mensuelle_ke(mois)],
	]
	out.append_array(_blocs_mensuels(flux, func(v): return _nb(v, 1) + " k€/mois", 0.05))
	out.append([HISTORIQUE, null, 0, false])
	var cumul := [
		["Caisse de départ", Ville.CAISSE_DEPART_KE],
		["Dotation, %s mois" % _nb(mois, 0), Ville.DOTATION_KE_MOIS * mois],
		["Électricité solaire vendue", ville.recette_cumulee_ke(mois)],
		["Loyers des étages ajoutés", ville.solde_dense_ke(mois)],
		["Crédit d'essai", ville._credit_essai_ke],
	]
	var genres := ville.depenses_par_genre()
	var cles := genres.keys()
	cles.sort_custom(func(a, b): return float(genres[a]) > float(genres[b]))
	for g in cles:
		cumul.append([str(GENRES_DEPENSE.get(g, g)), -float(genres[g])])
	var achat := ville.achat_nourriture_cumule_ke(mois)
	cumul.append_array([
		["Aide aux personnes sans abri", -ville.aide_cumulee_ke(mois)],
		["Nourriture achetée en plus" if achat > 0.0 else "Nourriture économisée", -achat],
		["Université", -Recherche.depense_ke(ville, mois)],
		["Mairie", -Politiques.depense_ke(ville, mois)],
	])
	for c in cumul:
		if absf(c[1]) >= 0.5:
			out.append(_ligne_ke(c[0], c[1]))
	out.append(["Argent aujourd'hui", _millions(ville.caisse_ke(mois)), 0, true])
	return out


func _lignes_capital(mois: float) -> Array:
	var out := []
	var usure := ville.usure_camp_mois(mois)
	# La confiance n'a aucune entrée fixe : seul le camp la fait bouger chaque mois.
	if usure >= 0.05:
		out.append_array(_blocs_mensuels([["Le camp use la confiance ; l'améliorer l'arrête", -usure]],
			func(v): return _nb(v, 1) + "/mois", 0.05))
	out.append([HISTORIQUE, null, 0, false])
	var passes := [["Confiance de départ", Ville.CAPITAL_DEPART]]
	var a_venir := []
	for m in ville.capital_mouvements():
		if float(m["mois"]) > mois:
			a_venir.append(m)
		else:
			passes.append([_phrase_mouvement(m), float(m["montant"])])
	var use := ville.usure_camp_cumulee(mois)
	if use >= 0.5:
		passes.append(["Le camp, mois après mois", -use])
	# Les plus anciens se regroupent : la liste ne doit pas sortir de l'écran.
	if passes.size() > 9:
		var tot := 0.0
		for p in passes.slice(1, passes.size() - 7):
			tot += float(p[1])
		passes = [passes[0], ["Plus tôt", tot]] + passes.slice(passes.size() - 7)
	for i in passes.size():
		var k := int(roundf(float(passes[i][1])))
		if k != 0 or i == 0:
			out.append([passes[i][0], ("%d" % k) if i == 0 else ("%+d" % k).replace("-", "−"),
				0 if i == 0 else signi(k), false])
	out.append(["Confiance aujourd'hui", _nb(ville.capital(mois), 0), 0, true])
	var venir := []
	var debut := ville.usure_debut()
	if debut > mois and debut < INF:
		venir.append(["Le camp commence à user la confiance, mois %s" % _nb(debut, 0),
			"−%s/mois" % _nb(ville.usure_camp_mois(debut), 1), -1, false])
	for m in a_venir:
		var v := ("%+d" % int(roundf(float(m["montant"])))).replace("-", "−")
		if str(m["quoi"]) == "places_retour":
			v = "selon la rue"
		venir.append(["%s, mois %s" % [_phrase_mouvement(m), _nb(float(m["mois"]), 0)],
			v, signf(float(m["montant"])), false])
	if not venir.is_empty():
		out.append(["À venir", null, 0, false])
		out.append_array(venir.slice(0, 5))
	return out


func _phrase_mouvement(m: Dictionary) -> String:
	var txt: String
	match str(m["quoi"]):
		"places":
			txt = "%s : places retirées" % lieux.nom("r", int(m["fid"]))
		"places_retour":
			txt = "%s, un an après" % lieux.nom("r", int(m["fid"])) \
				if float(m["mois"]) > _mois else retours.phrase_capital(m)
		_:
			txt = retours.phrase_capital(m)
	return txt.left(1).to_upper() + txt.substr(1)


func _controles_temps() -> void:
	var p := PanelContainer.new()
	p.theme = _theme_ui
	if BOIS:
		p.add_theme_stylebox_override("panel", _planche())
		_vitrer(p, Color(BOIS_PLANCHE, 0.84), PLANCHE_RAYON)
	else:
		_poser_boite(p)
	# 🔄 AU CENTRE DU BAS (auteur, 2026-09-28, image de référence) ; il tenait
	# le coin bas-gauche depuis le 2026-09-01.
	p.anchor_top = 1.0
	p.anchor_bottom = 1.0
	p.anchor_left = 0.5
	p.anchor_right = 0.5
	# Largeur nulle et croissance des deux côtés : le panneau épouse ses boutons,
	# centré. À ±206 px il débordait à droite dès que les boutons dépassaient.
	p.offset_left = 0
	p.offset_right = 0
	p.offset_top = -72
	p.offset_bottom = -16
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	# 🪵 Collée au bas de l'écran (auteur, 2026-09-28) : le bas arrondi passe SOUS
	# l'écran, seuls les deux coins du haut se voient.
	var encre := TEXTE
	if BOIS:
		p.offset_bottom = PLANCHE_RAYON
		encre = BOIS_CREME
	# 🔲 EN HAUT À DROITE, AU-DESSUS DE LA FICHE ET DE SA LARGEUR (auteur, 2026-10-02).
	var cote := 40.0
	var dessin := 18
	if VITRE:
		p.anchor_top = 0.0
		p.anchor_bottom = 0.0
		p.anchor_left = 1.0
		p.anchor_right = 1.0
		p.offset_left = -FICHE_LARGEUR - 16.0
		p.offset_right = -16
		p.offset_top = HAUT
		p.offset_bottom = HAUT
		p.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		p.grow_vertical = Control.GROW_DIRECTION_END
		var sb := p.get_theme_stylebox("panel") as StyleBoxFlat
		sb.set_content_margin_all(5)
		sb.content_margin_left = 12
		cote = 30.0
		dessin = 15
	add_child(p)
	_temps_panneau = p

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	p.add_child(h)
	_temps_label = _etiquette("Mois 0", 12, encre)
	# ⚠️ En vitre, les icônes sont dessinées en blanc et teintées par l'état : une
	# icône foncée restait foncée sur la vitesse enfoncée, donc invisible.
	if VITRE:
		encre = Color.WHITE
	_temps_label.custom_minimum_size.x = 76
	if VITRE:
		h.add_theme_constant_override("separation", 2)
		_temps_label.custom_minimum_size.x = 64
		_temps_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_temps_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(_temps_label)
	# 🔄 Pause et lecture en icônes (auteur, 2026-09-28) ; ×2 et ×4 restent
	# écrits, une icône ne dirait pas le chiffre. Plus de ×12 (auteur, 2026-10-09).
	for choix in [["pause", 0.0, "Pause"], ["lecture", 1.0, "Lecture"],
			["×2", 2.0, "Accélérer ×2"], ["×4", 4.0, "Accélérer ×4"]]:
		var b := Button.new()
		if DESSINS.has(choix[0]):
			b.icon = _icone(choix[0], dessin, encre)
			b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		else:
			b.text = choix[0]
		b.tooltip_text = choix[2]
		b.custom_minimum_size = Vector2(cote + 2.0, cote)
		b.add_theme_font_size_override("font_size", 13 if VITRE else 15)
		var v: float = choix[1]
		# ⏯️ La vitesse en cours est ENFONCÉE, pas grisée : grisée, elle se lisait
		# comme un bouton en panne, et on ne savait plus si le temps courait.
		b.toggle_mode = true
		b.pressed.connect(_demander_vitesse.bind(v))
		h.add_child(b)
		_vitesses[v] = b

	# Rejouer un geste demandait trois secondes de rechargement. Le bouton remet
	# le temps ET la ville : un temps qui recule seul laisserait des toits noirs
	# sous un compteur à « Mois 0 ».
	var raz := Button.new()
	raz.icon = _icone("mois_zero", dessin, encre)
	raz.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	raz.custom_minimum_size = Vector2(cote, cote)
	raz.tooltip_text = "Remet le temps au mois 0 et annule les poses décidées."
	raz.pressed.connect(func() -> void: temps_remis.emit())
	h.add_child(raz)

	for action in [["sauver", "Sauvegarder la partie", "F5"],
			["ouvrir", "Reprendre la partie sauvegardée", "F9"]]:
		var bouton := Button.new()
		bouton.icon = _icone(action[0], dessin, encre)
		bouton.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bouton.tooltip_text = "%s (%s)" % [action[1], action[2]]
		bouton.custom_minimum_size = Vector2(cote, cote)
		h.add_child(bouton)
		if action[2] == "F5":
			bouton.pressed.connect(func() -> void: sauvegarde_demandee.emit())
		else:
			_reprendre = bouton
			bouton.pressed.connect(func() -> void: reprise_demandee.emit())
	if BOIS:
		for b in h.get_children():
			if b is Button:
				_habiller_planche(b)
	elif VITRE:
		for b in h.get_children():
			if b is Button:
				_habiller_nu(b)


## 🔲 Un bouton du temps en vitre : sans plaque, la vitesse en cours en encre pleine.
func _habiller_nu(b: Button) -> void:
	var nu := StyleBoxFlat.new()
	nu.bg_color = Color(0, 0, 0, 0)
	nu.set_content_margin_all(4)
	var survol := nu.duplicate() as StyleBoxFlat
	survol.bg_color = Color(1, 1, 1, 0.7)
	var plein := nu.duplicate() as StyleBoxFlat
	plein.bg_color = TEXTE
	b.add_theme_stylebox_override("normal", nu)
	b.add_theme_stylebox_override("hover", survol)
	b.add_theme_stylebox_override("pressed", plein)
	b.add_theme_stylebox_override("hover_pressed", plein)
	b.add_theme_stylebox_override("disabled", nu)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("icon_disabled_color", Color(TEXTE, 0.3))
	for etat in ["icon_normal_color", "icon_hover_color"]:
		b.add_theme_color_override(etat, TEXTE)
	for etat in ["font_pressed_color", "font_hover_pressed_color", "icon_pressed_color",
			"icon_hover_pressed_color"]:
		b.add_theme_color_override(etat, Color.WHITE)


## 🪵 La planche : verre brun uni, très arrondi ; `PLANCHE_RAYON` de plus en
## bas, puisque ce bas-là est hors de l'écran. 🔄 Les veines de bois sont retirées (auteur, 2026-09-28).
const PLANCHE_RAYON := 26
func _planche() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = Color(BOIS_CADRE, 0.7)
	sb.border_width_top = 2
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.set_corner_radius_all(PLANCHE_RAYON)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8 + PLANCHE_RAYON
	return sb


## Un bouton sur la planche : sans plaque, l'état choisi creusé dans le bois.
func _habiller_planche(b: Button) -> void:
	var nu := StyleBoxFlat.new()
	nu.bg_color = Color(0, 0, 0, 0)
	nu.set_corner_radius_all(8)
	nu.set_content_margin_all(8)
	var survol := nu.duplicate() as StyleBoxFlat
	survol.bg_color = Color(1, 0.92, 0.8, 0.12)
	var creuse := nu.duplicate() as StyleBoxFlat
	creuse.bg_color = Color(0.12, 0.05, 0.02, 0.30)
	b.add_theme_stylebox_override("normal", nu)
	b.add_theme_stylebox_override("hover", survol)
	b.add_theme_stylebox_override("pressed", creuse)
	b.add_theme_stylebox_override("hover_pressed", creuse)
	b.add_theme_stylebox_override("disabled", nu)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for etat in ["font_color", "font_hover_color", "font_pressed_color",
			"font_hover_pressed_color"]:
		b.add_theme_color_override(etat, BOIS_CREME)
	b.add_theme_color_override("font_disabled_color", Color(BOIS_CREME, 0.35))
	b.add_theme_color_override("icon_disabled_color", Color(1, 1, 1, 0.35))


## 💾 Le message passe par le bandeau des retours : un seul bandeau en haut.
func informer_partie(message: String, disponible: bool) -> void:
	if message != "" and retours != null:
		retours.signaler(message)
	_reprendre.disabled = not disponible


func _titre_lieu(couche: String) -> void:
	# 🌾 Un champ s'appelle « Champ », pas « Îlot » : les 88 champs n'ont pas de
	# nom écrit, donc c'est ce mot de secours qu'on lit à l'écran.
	var genre := "Champ" if couche == "i" and ville.est_champ(_fiche_fid) else ""
	var nom := lieux.nom(couche, _fiche_fid, genre)
	# 🏕️ « Champ des Luzernes » devient « Campement des Luzernes » jusqu'au labour.
	if _campement() and nom.begins_with("Champ"):
		nom = "Campement" + nom.substr(5)
	_fiche_titre.text = nom
	_fiche_titre.tooltip_text = lieux.repere(couche, _fiche_fid, genre)
	_fiche_titre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _demander_vitesse(v: float) -> void:
	vitesse_demandee.emit(v)


func maj(indic: Dictionary, mois: float, vitesse: float) -> void:
	_vitesse_courante = vitesse
	retours.actualiser_affichage()
	if indic.is_empty():
		return
	_mois = mois
	_maj_boue()
	var conso: float = indic["conso_mwh"]
	var prod: float = indic["production_mwh"]
	var achat: float = indic["achat_mwh"]
	var co2: float = indic["co2_kt"]
	_ville_valeurs["conso"].text = _nb(conso / 1000.0, 1) + " GWh/an"
	_ville_valeurs["production"].text = _nb(prod / 1000.0, 1) + " GWh/an"
	_ville_valeurs["achat"].text = _nb(achat / 1000.0, 1) + " GWh/an"
	_ville_valeurs["co2"].text = _nb(co2, 1) + " kt/an"
	# 🔴 CE QUE MESURENT LES QUATRE JAUGES, et c'est le seul endroit où c'est
	# écrit : le solaire et l'achat se lisent sur la consommation ; la conso et
	# le CO₂ n'ont pas de plein, donc ils se lisent contre le MOIS 0, mémorisé
	# au premier appel. Aucun nouveau chiffre — la même mesure, en image.
	if _conso_zero <= 0.0:
		_conso_zero = maxf(conso, 1.0)
		_co2_zero = maxf(co2, 0.001)
	_regler_jauge("conso", conso / _conso_zero)
	_regler_jauge("production", prod / maxf(conso, 1.0))
	_regler_jauge("achat", achat / maxf(conso, 1.0))
	_regler_jauge("co2", co2 / _co2_zero)
	# 🌾 Le nombre est en personnes, la jauge en part de la ville : les deux
	# disent la même mesure, et c'est la jauge qui rend visible ce qu'un champ
	# bâti coûte.
	var nourris: float = indic["nourriture_personnes"]
	_ville_valeurs["nourriture"].text = _nb(nourris, 0) + " pers."
	_regler_jauge("nourriture", indic["nourriture_part"])
	_ville_valeurs["achat_nourriture"].text = "achats %s k€/mois" % _nb(indic["achat_nourriture_ke_mois"], 1)
	# ⚠️ Mémorisée ici : `_maj_fiche()` en a besoin à chaque image, et la
	# recalculer parcourrait la ville une seconde fois par image.
	_caisse_ke = indic["caisse_ke"]
	_ville_valeurs["caisse"].text = _millions(_caisse_ke)
	_ville_valeurs["recette"].text = "+" + _milliers(indic["recette_ke_an"]) + " k€/an"
	_capital = ville.capital(mois)
	# 🚿 La baisse se voit (auteur, 2026-10-02) : le rythme à côté du nombre, en rouge.
	var usure := ville.usure_camp_mois(mois)
	var baisse := usure >= 0.05
	_ville_valeurs["capital"].text = _nb(_capital, 0) \
		+ (" · −%s/mois" % _nb(usure, 1) if baisse else "")
	if _barre_valeurs.has("capital"):
		var l: Label = _barre_valeurs["capital"]
		# ⚠️ Remplacer, jamais retirer : sans sa couleur, le nombre passe au blanc du thème.
		var teinte: Color = ALERTE if baisse else TEXTE
		if l.get_theme_color("font_color") != teinte:
			l.add_theme_color_override("font_color", teinte)
		l.get_parent().tooltip_text = ("Confiance · le camp en use %s par mois ; l'améliorer l'arrête."
			% _nb(usure, 1)) if baisse else "Confiance"
	_maj_durabilite(indic)
	_temps_label.text = "Mois %s" % _nb(mois, 1)
	# 🚿 Dès le premier camp, la confiance se lit en haut (auteur, 2026-10-02).
	_barre.visible = _menu_panneau.visible and (not _bilan_differe() or not ville._camps.is_empty())
	if _barre.visible:
		for cle in _barre_valeurs:
			(_barre_valeurs[cle] as Label).text = (_ville_valeurs[cle] as Label).text
		if VITRE:
			(_barre_valeurs["caisse"] as Label).get_parent().tooltip_text = "Caisse · %s" \
				% _ville_valeurs["recette"].text
	_maj_detail(indic, mois)
	# Calculés par la maquette au rythme du bandeau : 2,5 ms par appel.
	maj_degats(indic["degats"] if indic.has("degats") else ville.degats(mois))
	if _diagnostic_panneau.visible:
		(_onglets_crue["prochaine"] as Button).visible = etude_publiee()
		if _vue_crue == "prochaine":
			_maj_prochaine()
	if _chantiers_panneau.visible:
		maj_chantiers(ville.chantiers(mois))
	if _sols_bloc.visible and _calque_panneau.visible:
		var part := ville.part_sol_permeable(mois)
		if _sols_depart < 0.0:
			_sols_depart = ville.part_sol_permeable(0.0)
		var ecart := (part - _sols_depart) * 100.0
		_sols_chiffre.text = "%d %%%s" % [int(roundf(part * 100.0)),
			" · %+d depuis le début" % int(roundf(ecart)) if absf(ecart) >= 0.5 else ""]
	_maj_rail()
	for v in _vitesses:
		(_vitesses[v] as Button).set_pressed_no_signal(is_equal_approx(float(v), vitesse))
	if _fiche_fid >= 0:
		_maj_fiche()
	if _lieu_ouvert != "":
		_maj_lieu()


func _regler_jauge(cle: String, part: float) -> void:
	var p := clampf(part, 0.0, 1.0)
	(_ville_jauges[cle] as Jauge).regler(p, p)


## 🔄 LES DEUX PHRASES SOUS LES JAUGES SONT PARTIES le 2026-09-03 — elles
## étaient déjà invisibles depuis que le bandeau les avait perdues, et les
## jetons disent la même part sans mot.
func _maj_durabilite(indic: Dictionary) -> void:
	var adaptation := float(indic["adaptation_part"])
	_adaptation_jauge.regler(adaptation, adaptation)
	_adaptation_valeur.text = "%d %%" % int(roundf(adaptation * 100.0))
	_adaptation_pictos.regler(adaptation)

	var reduction := float(indic["reduction_part"])
	_reduction_jauge.regler(reduction, reduction)
	_reduction_valeur.text = "%d %%" % int(roundf(reduction * 100.0))
	_reduction_pictos.regler(reduction)


func montrer(couche: String, fid: int, _garder := true) -> void:
	# 🔄 LA FICHE S'OUVRE AUSSI SUR UNE RUE depuis le 2026-08-21. Elle
	# n'appartenait qu'à l'îlot ; la crue a mis deux décisions sur la voirie —
	# déblayer, rebâtir — et une décision qu'on ne peut pas cliquer n'existe pas.
	if fid < 0 or (couche != "i" and couche != "r" and couche != "b"):
		return
	# 🎓🏛️ Cliquer la ville referme le menu : jamais deux fiches ensemble (81).
	_fermer_lieu()
	_fiche_panneau.visible = true
	var lieu := _lieu_du_fid(fid) if couche == "i" else ""
	_lieu_bouton.visible = lieu != ""
	if lieu != "":
		_lieu_bouton.text = "Ouvrir %s" % String(LIEUX[lieu]["article"])
	if fid != _fiche_fid or couche != _fiche_couche:
		_vider_pose()   # changer d'objet abandonne tout ce qui était posé
		fermer_projets()
		_message.text = ""
	_fiche_fid = fid
	_fiche_couche = couche
	_fiche_vide.visible = false
	_apercu_cadre.visible = apercu != null
	_fiche_soustitre.visible = true
	# 🗂️ CE QUI PEUT S'AFFICHER SUR CET OBJET, onglet ouvert mis à part. Les deux
	# blocs de la crue se remettent à zéro ici : une berge ne passe jamais par
	# `_maj_reparation`, donc sans cette ligne elle hériterait du dernier îlot.
	_bloc_dispo[_repare_bloc] = false
	_bloc_dispo[_camp_bloc] = false
	# ☀️ VERROUILLÉ JUSQU'À L'ÉCRAN « investir » (auteur, 2026-09-18) : la ville
	# reloge et relève d'abord ; les panneaux ne s'ouvrent qu'ensuite.
	# 🏢 Un îlot dont rien ne peut monter n'a pas de bloc : le cœur ancien,
	# le front commerçant, et tout ce qui n'est pas bâti.
	_bloc_dispo[_dense_bloc] = couche == "i" and ville.dense_logements_etage(fid) > 0
	_leviers_sig = ""
	_maj_fiche()


## 📖 Les blocs que le livre ouvre (101). Refait quand une page s'ouvre, fiche
## ouverte comprise : sinon le bloc n'apparaîtrait qu'au clic suivant.
var _leviers_sig := ""


func _dispo_leviers() -> void:
	var sig := ""
	for l in Livre.LEVIERS:
		sig += "1" if _levier_ferme(l) == "" else "0"
	if sig == _leviers_sig:
		return
	_leviers_sig = sig
	var couche := _fiche_couche
	var fid := _fiche_fid
	_bloc_dispo[_solaire_bloc] = couche == "i" and _levier_ferme("solaire") == ""
	# 🌿 Un îlot tout en versants ne verra JAMAIS ce bloc : un curseur qui ne
	# peut rien poser n'est pas une décision grisée, c'est du bruit.
	_bloc_dispo[_vert_bloc] = couche == "i" and _levier_ferme("vert") == "" \
		and ville.valeur("i", fid, "_part_plate", _mois) > 0.001
	_bloc_dispo[_permeable_bloc] = couche == "i" and _levier_ferme("permeable") == "" \
		and ville.permeable_possible(fid)
	_bloc_dispo[_trafic_bloc] = couche == "r" and _levier_ferme("rue") == ""
	# 🌳 Seulement là où il y a la place d'un arbre entre la chaussée et la
	# limite d'emprise : `07` l'a tranché, les ruelles du cœur ancien n'en ont
	# aucune. Un curseur qui ne planterait rien n'a pas à s'afficher.
	_bloc_dispo[_arbres_bloc] = couche == "r" and _levier_ferme("arbres") == "" \
		and ville.arbres_plantables(fid) > 0
	_bloc_dispo[_berge_bloc] = couche == "b" and _levier_ferme("berge") == ""
	# ⚠️ Pas `{}` : une fiche muette calcule `{}`, et les blocs d'avant resteraient.
	_dispo = {"_refaire": true}


func reprendre_fiche(couche: String, fid: int) -> void:
	_vider_pose()
	_fermer_lieu()
	_message.text = ""
	_fiche_fid = -1
	_fiche_panneau.visible = fid >= 0
	if fid >= 0:
		montrer(couche, fid)


## 🏕️ TANT QUE PERSONNE N'EST RELOGÉ, LA FICHE NE PROPOSE QUE LE CAMP
## (auteur, 2026-09-17). Le joueur clique où il veut, mais la ville n'ouvre
## aucun autre chantier pendant que les sinistrés dorment dehors : c'est ce qui
## oriente vers les champs sans les désigner.
var _message_urgence := false


## 🔒 « reloger », « pont » ou "" : le verrou des premières minutes, tenu par le
## guide (`ouverture.verrou`). Sans guide (contrôles), rien n'est verrouillé.
func _verrou() -> String:
	return ouverture.verrou() if ouverture != null else ""


func _autorise(couche: String, fid: int) -> bool:
	return ouverture == null or ouverture.autorise(couche, fid)


## 📖 "" si le levier est ouvert, sinon ce qui l'ouvrira (101). Sans guide, tout l'est.
func _levier_ferme(levier: String) -> String:
	return ouverture.levier_ferme(levier) if ouverture != null else ""


func _maj_permeable() -> void:
	var fid := _fiche_fid
	if _fiche_couche != "i" or not ville.permeable_possible(fid):
		return
	var dur := int(roundf(ville.valeur("i", fid, "impermeabilise", _mois) * 100.0))
	_permeable_texte.text = "%d %% du sol en dur" % dur
	_permeable_bouton.visible = not ville._permeable.has(fid) or ville.permeable_en_cours(fid, _mois)
	if ville.permeable_en_cours(fid, _mois):
		_permeable_bouton.text = "Chantier en cours"
		_permeable_bouton.disabled = true
		_marquer(_permeable_bouton, false)
	elif ville._permeable.has(fid):
		_permeable_bouton.text = "Le sol boit l'eau"
		_permeable_bouton.disabled = true
		_marquer(_permeable_bouton, false)
	else:
		_posee(_permeable_bouton, "permeable", "Rendre le sol perméable · %s k€" % _milliers(ville.cout_permeable_ke(fid)))
		_permeable_bouton.disabled = false


func _maj_fiche() -> void:
	_dispo_leviers()
	_maj_fiche_contenu()
	_maj_projets()
	_repare_texte.visible = _repare_texte.text != ""
	_camp_texte.visible = _camp_texte.text != ""
	var verrou := _verrou()
	# 🎓 La fenêtre du campus ouverte, « Ouvrir … » se tait ; refermée, il revient.
	_lieu_bouton.visible = verrou == "" and not _campus_panneau.visible 		and _fiche_couche == "i" and _lieu_du_fid(_fiche_fid) != ""
	# 🗂️ `_maj_fiche_contenu` vient de dire ce qui existe ; on en déduit les
	# onglets. On ne les repeint QUE s'ils ont changé : on passe ici à chaque
	# image, et refaire sept boîtes de style par image pour rien se verrait.
	# Une berge n'a pas de sous-titre : sans ça, elle garderait une ligne vide.
	_fiche_soustitre.visible = _fiche_soustitre.text != ""
	var dispo := _calculer_dispo()
	if dispo != _dispo:
		_dispo = dispo
		_appliquer_onglets()
	# La phrase de l'urgence s'efface dès qu'elle est fausse : sans ça, elle
	# survivait sous la fiche du champ qui, lui, peut accueillir.
	var muet := verrou != "" and not _autorise(_fiche_couche, _fiche_fid)
	if muet:
		_message.text = "Rien à engager ici avant d'avoir abrité les sinistrés." \
			if verrou == "reloger" else "Rien à engager ici avant d'avoir rouvert un pont et ses accès."
		if verrou == "pont" and _fiche_couche == "i" and ville.base("i", _fiche_fid, "cout_reparation_ke") > 0.0:
			_message.text = "Relevable une fois un pont rouvert."
	elif _message_urgence:
		_message.text = ""
	_message_urgence = muet
	# Vide, il creusait une ligne sous « Mettre en place » (auteur, 2026-09-28).
	_message.visible = _message.text != ""


func _maj_fiche_contenu() -> void:
	_maj_chantier()
	_maj_camp()
	_maj_culture()
	_maj_permeable()
	if _fiche_couche == "r":
		_maj_fiche_rue()
		return
	if _fiche_couche == "b":
		_maj_fiche_berge()
		return
	var o: Dictionary = ville.ilots.get(_fiche_fid, {})
	if o.is_empty():
		return
	_titre_lieu("i")
	_maj_reparation(o)

	var conso := ville.valeur("i", _fiche_fid, "_conso_mwh", _mois)
	var prod := ville.valeur("i", _fiche_fid, "_production_mwh", _mois)
	var toit := ville.valeur("i", _fiche_fid, "_toit_equipable_m2", _mois)
	var etat := ville.etat_solaire(_fiche_fid, _mois)
	var pct := float(etat["actuel"]) * 100.0
	var cible_pct := float(etat["cible"]) * 100.0
	# 🌾 Un champ porte déjà « Champ » dans son nom : le répéter dessous ne dit
	# rien. Les autres tissus, si — « îlot compact » n'est pas dans le nom.
	var tissu := str(o.get("sous_type", "?"))
	_fiche_soustitre.text = "" if tissu in ["champ", "equipement"]		else str(TISSUS.get(tissu, tissu.replace("_", " ")))
	var champ := ville.est_champ(_fiche_fid)
	# 🔄 Par `ville.valeur` depuis le 2026-08-21, plus par la fiche brute :
	# `logements` BOUGE maintenant — la crue en a retiré 417, une
	# reconstruction les rend, et la base seule affichait toujours 0.
	var loges := ville.valeur("i", _fiche_fid, "logements", _mois)
	var nourris := ville.champ_rendement(_fiche_fid, _mois)
	var hectares := float(o.get("surface_m2", 0.0)) / 10000.0
	if _campement():
		var loges_camp := int(ville.camp_occupants(_fiche_fid, _mois))
		_maj_resume("camp", "personne n'y vit" if loges_camp == 0
			else ("1 personne logée" if loges_camp == 1 else "%d personnes logées" % loges_camp))
		(_fiche_valeurs["containers"] as Label).text = str(ville.camp_abris(_fiche_fid, _mois)
			if ville.camp_livre(_fiche_fid, _mois) else ville.camp_taille(_fiche_fid, _mois))
		(_fiche_valeurs["surface_camp"] as Label).text = "%s ha" % _nb(hectares, 2)
		(_fiche_valeurs["rive_camp"] as Label).text = str(o.get("rive", "?"))
	elif champ:
		# 🌾 CE QUE CE CHAMP-LÀ NOURRIT, en clair et avant toute décision.
		var recolte := ville.recolte_dans_mois(_fiche_fid, _mois)
		var resume := "ne produit plus de nourriture"
		if nourris >= 1.5:
			resume = "%s personnes nourries" % _nb(nourris, 0)
		elif ville.champ_cultive(_fiche_fid, _mois) and recolte > 0.0:
			resume = "première récolte dans %s" % _duree(recolte)
		_maj_resume("nourriture", resume)
		var nom: String = Ville.CULTURES[ville.champ_culture(_fiche_fid, _mois)]["nom"]
		(_fiche_valeurs["culture"] as Label).text = "labour" if ville.labour_en_cours(_fiche_fid, _mois) \
			else nom.substr(0, 1).to_upper() + nom.substr(1)
		(_fiche_valeurs["surface_champ"] as Label).text = "%s ha" % _nb(hectares, 2)
		(_fiche_valeurs["rive"] as Label).text = str(o.get("rive", "?"))
	else:
		# 🌊 Les perdus dans la même ligne : sans eux, un îlot en ruine se lisait intact pendant l'urgence.
		var perdus := 0.0 if ville.reparation_finie("i", _fiche_fid, _mois) 			else float(o.get("logements_sinistres", 0))
		_maj_resume("logement", ("aucun logement" if loges < 0.5
			else ("1 logement" if loges < 1.5 else "%s logements" % _nb(loges, 0)))
			+ (" · %s perdus" % _nb(perdus, 0) if perdus >= 0.5 else ""))
		(_fiche_valeurs["surface"] as Label).text = "%s ha" % _nb(hectares, 2)
		(_fiche_valeurs["niveaux"] as Label).text = _nb(
			float(o.get("hauteur", 0.0)), 0)
		(_fiche_valeurs["emplois"] as Label).text = _nb(
			float(o.get("emplois", 0)), 0)

	# 🔴 « MWh/an » COUPE LA TUILE EN DEUX sur trois colonnes : le « par an » est
	# passé dans l'étiquette, et les milliers prennent leur espace comme
	# partout ailleurs.
	(_fiche_valeurs["conso"] as Label).text = _milliers(conso) + " MWh"
	(_fiche_valeurs["production"] as Label).text = _milliers(prod) + " MWh"
	(_fiche_valeurs["toit"] as Label).text = _milliers(toit) + " m²"
	var plate := ville.valeur("i", _fiche_fid, "_part_plate", _mois)
	(_fiche_valeurs["plat"] as Label).text = "%d %%" % int(roundf(plate * 100.0))
	(_fiche_valeurs["verdi"] as Label).text = _milliers(
		ville.valeur("i", _fiche_fid, "_toit_vert_m2", _mois)) + " m²"
	# L'amortissement est une propriété de l'îlot, pas de la part visée
	# (`energie.rentabilite_annees`).
	var ans := ville.valeur("i", _fiche_fid, "_rentabilite_annees", _mois)
	(_fiche_valeurs["retour"] as Label).text = 		"—" if is_inf(ans) else "%d ans" % int(roundf(ans))

	# 🌊 CE QUE LA CRUE A PRIS. La reprise annoncée est par le noyau et non par
	# la fiche brute : une berge livrée en aval a pu la faire baisser.
	# Relevé, l'îlot n'a plus rien de perdu : les chiffres de l'export restaient.
	var releve := ville.reparation_finie("i", _fiche_fid, _mois)
	(_fiche_valeurs["perdus"] as Label).text = "0" if releve else _nb(
		float(o.get("logements_sinistres", 0)), 0)
	(_fiche_valeurs["detruits"] as Label).text = "0" if releve else _nb(
		float(o.get("batiments_ruines", 0)), 0)
	(_fiche_valeurs["annonce"] as Label).text = "%s m" % _nb(
		ville.valeur("i", _fiche_fid, "hauteur_eau_annonce", _mois), 2)
	(_fiche_valeurs["reprise"] as Label).text = "%d %%" % int(roundf(
		100.0 * ville.valeur("i", _fiche_fid, "part_ruinee_apres", _mois)))

	# 🔴 On passe ici À CHAQUE IMAGE : le curseur ne se repositionne que sans
	# choix en cours, sinon on garde la position de l'auteur, remontée au
	# niveau déjà posé.
	# ⚠️ Il se VERROUILLE pendant les travaux : une pose engagée est payée, et
	# ce verrou permet aux rampes de s'additionner sans réécrire l'histoire
	# d'un toit (`ville.lancer_solaire`).
	# 🌿 LE PLAFOND, ET IL BOUGE : ce que les toits verts prennent, les panneaux
	# ne l'ont plus. Il compte la CIBLE et non le réalisé, donc un chantier vert
	# engagé ferme la part tout de suite.
	var plafond_pct := ville.part_solaire_max(_fiche_fid, _mois) * 100.0
	if _vert_choix >= 0.0:
		plafond_pct = minf(plafond_pct, 100.0 - _vert_choix)
	_ecrit_curseur = true
	_solaire_curseur.editable = toit > 0.0 and pct < plafond_pct - 0.5 \
		and not etat["en_cours"]
	if _solaire_choix < 0.0:
		_solaire_curseur.set_value_no_signal(maxf(pct, cible_pct))
	else:
		_solaire_choix = clampf(_solaire_choix, pct, maxf(plafond_pct, pct))
		_solaire_curseur.set_value_no_signal(_solaire_choix)
	_ecrit_curseur = false
	# L'objectif visé est celui du curseur tant qu'il n'est pas validé, celui de
	# la pose en cours sinon.
	_solaire_jauge.regler(pct / 100.0,
		maxf(pct, _solaire_choix if _solaire_choix >= 0.0 else cible_pct) / 100.0)

	var recette := ville.valeur("i", _fiche_fid, "_recette_ke_an", _mois)
	if toit <= 0.0:
		_solaire_valeur.text = "Bâtiment protégé." \
			if int(o.get("solaire_possible", 1)) == 0 else "Aucun toit."
	elif _solaire_choix >= 0.0:
		_afficher_choix(pct, _solaire_choix)
	elif etat["en_cours"]:
		_solaire_valeur.text = "%d %% → %d %% · %s · %s k€ engagés" % [
			int(roundf(pct)), int(roundf(cible_pct)),
			_duree(float(etat["reste_mois"])), _milliers(float(etat["cout_ke"]))]
	else:
		_solaire_valeur.text = "%d %% équipé · +%s k€/an" % [int(roundf(pct)),
			_milliers(recette)] if pct > 0.0 else "Aucun panneau."
		if etat["a_commence"]:
			_message.text = "Pose terminée."
	_maj_vert()
	_maj_dense()
	_maj_recap()


# ==========================================================================
# LES RÉGLAGES POSÉS — on essaie, puis on met en place (2026-08-31)
# ==========================================================================

## Le libellé d'une bascule, et le bouton passe en brun plein quand le réglage est
## posé. 🔄 Plus de coche devant le texte (auteur, 2026-09-29 : il ne l'aime pas).
func _posee(b: Button, cle: String, texte: String, valeur: Variant = true) -> void:
	b.text = texte
	_marquer(b, _pose.has(cle) and typeof(_pose[cle]) == typeof(valeur)
		and _pose[cle] == valeur)


## L'état choisi sur un bouton qui ne bascule pas : le même brun que `pressed`.
func _marquer(b: Button, choisi: bool) -> void:
	for etat in ["normal", "hover"]:
		if choisi:
			b.add_theme_stylebox_override(etat, _sb_choisi)
		else:
			b.remove_theme_stylebox_override(etat)
	var encre: Color = _theme_ui.get_color("font_pressed_color", "Button")
	for etat in ["font_color", "font_hover_color"]:
		if choisi:
			b.add_theme_color_override(etat, encre)
		else:
			b.remove_theme_color_override(etat)
	# ⚠️ L'icône est cuite dans sa couleur (`_icone`) : la moduler ne l'éclaircit pas.
	if b.has_meta("icone"):
		b.icon = _icone(str(b.get_meta("icone")), 22, encre if choisi else TEXTE)


## 🏢 CE QUE DENSIFIER DONNE, EN LOGEMENTS ET JAMAIS EN MÈTRES. La hauteur
## se voit à l'écran ; ce qui décide, c'est le parc que l'îlot gagne — et la
## consommation qui vient avec.
func _maj_dense() -> void:
	# 🗂️ L'onglet fermé n'a rien à remettre à jour ; ce qui décide reste
	# `_bloc_dispo`, et non la visibilité, qui suit l'onglet ouvert.
	if not bool(_bloc_dispo.get(_dense_bloc, false)):
		return
	var etat := ville.etat_dense(_fiche_fid, _mois)
	var n := int(etat["batiments"])
	var montes := int(etat["montes"])
	var etages := _dense_etages()
	# Les deux boutons donnent la HAUTEUR, et ils marchent en couple : l'un des
	# deux est toujours coché, parce qu'un curseur seul doit suffire à
	# densifier. Ils se figent au premier chantier — la hauteur d'un îlot ne se
	# choisit qu'une fois.
	for k in _dense_boutons.size():
		var b: Button = _dense_boutons[k]
		b.text = "+%d étage%s" % [k + 1, "s" if k else ""]
		_marquer(b, k + 1 == etages)
		b.disabled = ville.dense_engage(_fiche_fid)

	# 🪜 Le curseur compte des BÂTIMENTS. Il repart du cran atteint : on ne
	# redescend pas un étage.
	_ecrit_curseur = true
	_dense_curseur.max_value = float(n)
	_dense_curseur.editable = montes < n and not etat["en_cours"]
	if _dense_choix < 0.0:
		_dense_curseur.set_value_no_signal(float(maxi(montes, int(etat["vises"]))))
	else:
		_dense_choix = clampf(_dense_choix, float(montes), float(n))
		_dense_curseur.set_value_no_signal(_dense_choix)
	_ecrit_curseur = false
	var vise: float = _dense_choix if _dense_choix >= 0.0 else float(etat["vises"])
	_dense_jauge.regler(float(montes) / maxf(float(n), 1.0),
		maxf(float(montes), vise) / maxf(float(n), 1.0))

	# 🏢 CE QUE DENSIFIER DONNE, EN LOGEMENTS ET JAMAIS EN MÈTRES.
	if _dense_choix >= 0.0 and _dense_choix > float(montes) + 0.01:
		var de := float(montes) / float(n)
		var vers := _dense_choix / float(n)
		_dense_valeur.text = "%d → %d bâtiments · +%d logements · %s" % [
			montes, int(_dense_choix),
			int(roundf(ville.dense_logements_tranche(_fiche_fid, de, vers, etages))),
			_duree(ville.duree_dense_mois(etages, de, vers))]
	elif etat["en_cours"]:
		_dense_valeur.text = "%d → %d bâtiments · +%d étage%s · encore %s" % [
			montes, int(etat["vises"]), etages, "s" if etages > 1 else "",
			_duree(float(etat["reste_mois"]))]
	elif montes > 0:
		_dense_valeur.text = "%d bâtiments sur %d montés · +%d logements" % [
			montes, n, int(roundf(float(etat["logements"])))]
	else:
		_dense_valeur.text = "%d bâtiments peuvent monter · %d logements par étage" % [
				n, ville.dense_logements_etage(_fiche_fid)]


## La hauteur retenue pour cet îlot : celle déjà engagée, sinon celle des
## boutons, sinon un étage — le curseur seul doit suffire à densifier.
func _dense_etages() -> int:
	var engage := ville.dense_etages(_fiche_fid)
	if engage > 0:
		return engage
	return int(_pose.get("dense", 1))


## 🌿 Le bloc des toits verts. Même mécanique que le solaire, à une chose près :
## ce qu'il annonce est l'effet de TOUTE la ville, parce que c'est là qu'il a
## lieu — un toit seul rachète des centimètres, le programme rachète des mètres.
func _maj_vert() -> void:
	# 🗂️ L'onglet fermé n'a rien à remettre à jour ; ce qui décide reste
	# `_bloc_dispo`, et non la visibilité, qui suit l'onglet ouvert.
	if not bool(_bloc_dispo.get(_vert_bloc, false)):
		return
	var etat := ville.etat_vert(_fiche_fid, _mois)
	var pct := float(etat["actuel"]) * 100.0
	var cible_pct := float(etat["cible"]) * 100.0
	var plafond_pct := ville.part_vert_max(_fiche_fid, _mois) * 100.0
	if _solaire_choix >= 0.0:
		plafond_pct = minf(plafond_pct, 100.0 - _solaire_choix)
	_ecrit_curseur = true
	_vert_curseur.editable = pct < plafond_pct - 0.5 and not etat["en_cours"]
	if _vert_choix < 0.0:
		_vert_curseur.set_value_no_signal(maxf(pct, cible_pct))
	else:
		_vert_choix = clampf(_vert_choix, pct, maxf(plafond_pct, pct))
		_vert_curseur.set_value_no_signal(_vert_choix)
	_ecrit_curseur = false
	_vert_jauge.regler(pct / 100.0,
		maxf(pct, _vert_choix if _vert_choix >= 0.0 else cible_pct) / 100.0)

	var ville_m := ville.baisse_crue_toits_m(_mois)
	var reste := "%s m² de toit plat libre" % _milliers(
		ville.valeur("i", _fiche_fid, "_toit_plat_equipable_m2", _mois)
		- ville.valeur("i", _fiche_fid, "_toit_vert_m2", _mois))
	if _vert_choix >= 0.0 and _vert_choix > pct + 0.01:
		_vert_valeur.text = "%d %% → %d %% · %s" % [int(roundf(pct)),
			int(roundf(_vert_choix)),
			_duree(ville.duree_vert_mois(pct / 100.0, _vert_choix / 100.0))]
	elif etat["en_cours"]:
		_vert_valeur.text = "%d %% → %d %% · %s · %s k€ engagés" % [
			int(roundf(pct)), int(roundf(cible_pct)),
			_duree(float(etat["reste_mois"])), _milliers(float(etat["cout_ke"]))]
	elif pct > 0.0:
		_vert_valeur.text = "%s m² verdis. La ville retient %s cm de crue." % [
			_milliers(ville.valeur("i", _fiche_fid, "_toit_vert_m2", _mois)),
			_nb(ville_m * 100.0, 0)]
	elif plafond_pct < 0.5:
		_vert_valeur.text = "Les panneaux prennent tout le toit plat."
	else:
		_vert_valeur.text = "%s." % reste


## 🌳 Le curseur des arbres, remis à jour à chaque image comme celui du solaire
## et avec le même verrou : sans choix en cours la fiche commande, sinon on
## garde la position de l'auteur, remontée au nombre déjà en terre.
func _maj_arbres() -> void:
	# 🗂️ L'onglet fermé n'a rien à remettre à jour ; ce qui décide reste
	# `_bloc_dispo`, et non la visibilité, qui suit l'onglet ouvert.
	if not bool(_bloc_dispo.get(_arbres_bloc, false)):
		return
	var plafond := Ville.PLANTATION_CANOPEE_MAX
	var cano := ville.valeur("r", _fiche_fid, "canopee", _mois)
	var pct := cano / plafond * 100.0
	var en_terre := ville.arbres_a(_fiche_fid, cano)
	var tous := ville.arbres_plantables(_fiche_fid)
	var en_cours := ville.plantation_en_cours(_fiche_fid, _mois)
	_ecrit_curseur = true
	_arbres_curseur.editable = not en_cours and en_terre < tous
	if _arbres_choix < 0.0:
		_arbres_curseur.set_value_no_signal(pct)
	else:
		_arbres_choix = maxf(_arbres_choix, pct)
		_arbres_curseur.set_value_no_signal(_arbres_choix)
	_ecrit_curseur = false
	var vise: float = maxf(pct, _arbres_choix if _arbres_choix >= 0.0 else pct)
	_arbres_jauge.regler(pct / 100.0, vise / 100.0)
	(_rue_valeurs["arbres"] as Label).text = "%d sur %d" % [en_terre, tous]
	(_rue_valeurs["canopee"] as Label).text = "%d %%" % int(roundf(cano * 100.0))
	if en_cours:
		_arbres_valeur.text = "%d arbres · reprise dans %s" % [
			ville.arbres_a(_fiche_fid, _arbres_choix / 100.0 * plafond) if
			_arbres_choix >= 0.0 else en_terre,
			_duree(ville.plantation_reste_mois(_fiche_fid, _mois))]
	elif _arbres_choix >= 0.0 and _arbres_choix > pct + 0.01:
		var cible := _arbres_choix / 100.0 * plafond
		_arbres_valeur.text = "%d arbres → %d · %s" % [en_terre,
			ville.arbres_a(_fiche_fid, cible), _duree(Ville.PLANTATION_MOIS)]
	elif en_terre >= tous:
		_arbres_valeur.text = "%d arbres · la rue est plantée de bout en bout" % en_terre
	else:
		_arbres_valeur.text = "%d arbres sur %d emplacements" % [en_terre, tous]


## Ce que l'objet courant a de posé, au format que `ville.commander` lit. UN
## SEUL endroit l'assemble : la miniature, le récapitulatif et la commande
## doivent parler du même réglage, sinon l'image promet autre chose que le prix.
func _reglages() -> Dictionary:
	var r: Dictionary = _pose.duplicate()
	if _fiche_couche == "i" and _solaire_choix >= 0.0:
		var actuel := ville.valeur("i", _fiche_fid, "part_toit_equipe", _mois) * 100.0
		if _solaire_choix > actuel + 0.01:
			r["solaire"] = _solaire_choix / 100.0
	if _fiche_couche == "i" and _vert_choix >= 0.0:
		var actuel_v := ville.valeur("i", _fiche_fid, "part_toit_vert", _mois) * 100.0
		if _vert_choix > actuel_v + 0.01:
			r["vert"] = _vert_choix / 100.0
	# 🏢 La densification part du curseur, et les boutons ne portent que la
	# hauteur : `dense` est un couple, pas un nombre d'étages.
	if _fiche_couche == "i":
		r.erase("dense")
		var ed := ville.etat_dense(_fiche_fid, _mois)
		if _dense_choix > float(ed["montes"]) + 0.01 and not ed["en_cours"]:
			r["dense"] = {
				"part": _dense_choix / maxf(float(ed["batiments"]), 1.0),
				"etages": _dense_etages(),
			}
	# 🅿️ Fermer aux voitures emporte les places : les deux réglages
	# ensemble feraient deux lignes de récapitulatif pour un seul chantier.
	if r.has("axe"):
		r.erase("places")
	if _fiche_couche == "r" and _arbres_choix >= 0.0:
		var cible := _arbres_choix / 100.0 * Ville.PLANTATION_CANOPEE_MAX
		if ville.arbres_a(_fiche_fid, cible) > ville.arbres_a(
				_fiche_fid, ville.valeur("r", _fiche_fid, "canopee", _mois)):
			r["arbres"] = cible
	return r


func _decision(b: Button, cle: String, valeur: Variant) -> void:
	b.pressed.connect(func() -> void:
		_survol_ignore = b
		_basculer(cle, valeur))
	b.mouse_exited.connect(func() -> void:
		if _survol_ignore == b:
			_survol_ignore = null)
	_decisions.append([b, cle, valeur])


func _survole(b: Button) -> bool:
	return b != _survol_ignore and not b.disabled and b.is_hovered() and b.is_visible_in_tree()


## 🖱️ Les réglages posés, plus la bascule sous la souris (auteur, 2026-09-30) :
## les conséquences se lisent avant le clic. Un bouton déjà posé ne s'enlève pas au survol.
func _reglages_vus() -> Dictionary:
	for d in _decisions:
		var b: Button = d[0]
		if not _survole(b):
			continue
		var sauve := _pose.duplicate()
		_pose[d[1]] = d[2]
		var r := _reglages()
		_pose = sauve
		return r
	return _reglages()


## Une bascule : reposer le même réglage l'enlève. C'est ce qui rend l'essai
## réversible — et la berge est exclusive, un seul état visé à la fois.
func _basculer(cle: String, valeur) -> void:
	# Le type d'abord : `true == "provisoire"` est une erreur en GDScript.
	if _pose.has(cle) and typeof(_pose[cle]) == typeof(valeur) and _pose[cle] == valeur:
		_pose.erase(cle)
	else:
		_pose[cle] = valeur
	_maj_fiche()


## Changer d'objet, ou avoir commandé : rien ne se garde. Un réglage posé sur
## l'îlot 32 qui survivrait au clic sur le 33 se paierait sur le mauvais toit.
func _vider_pose() -> void:
	_pose.clear()
	_solaire_choix = -1.0
	_vert_choix = -1.0
	_arbres_choix = -1.0
	_dense_choix = -1.0


func _mettre_en_place() -> void:
	var r := _reglages()
	if r.is_empty():
		return
	commande_demandee.emit(_fiche_couche, _fiche_fid, r)


## 🔴 LE RÉCAPITULATIF, et le seul refus du jeu. Il porte le total de TOUS les
## réglages posés : le prix se calcule dans le noyau (`cout_commande_ke`), pas
## ici — deux additions dans deux fichiers finissent par diverger.
func _maj_recap() -> void:
	# Les boutons suivent ce qui est POSÉ ; les conséquences, ce qui est vu.
	var pose := _reglages()
	var r := _reglages_vus()
	# 🔄 Caché tant que rien n'est réglé (auteur, 2026-10-08) ; il était là, grisé.
	_recap_bloc.visible = _fiche_fid >= 0 and not (pose.is_empty() and r.is_empty())
	(_recap_effets.get_parent() as Control).visible = not r.is_empty()
	_recap_annuler.disabled = pose.is_empty()
	_recap_bouton.text = "Mettre en place"
	var refus := pose.is_empty() or _manque(pose) > 0.001
	refus = refus or ville.capital_commande(_fiche_couche, _fiche_fid, pose, _mois) > _capital + 0.001
	_recap_bouton.disabled = refus
	if r.is_empty():
		_alerter_cout(false)
		_recap_cle = ""
		return
	var cout := ville.cout_commande_ke(_fiche_couche, _fiche_fid, r, _mois)
	var duree := ville.duree_commande_mois(_fiche_couche, _fiche_fid, r, _mois)
	var manque := cout - _caisse_ke
	var capital := ville.capital_commande(_fiche_couche, _fiche_fid, r, _mois)
	var manque_capital := capital - _capital
	_alerter_cout(manque > 0.001)
	# ⚠️ Mesurer rejoue la ville entière : une fois par réglage et par mois, pas par image.
	var cle := "%s%d %s %d %d %d" % [_fiche_couche, _fiche_fid, r, int(_mois),
		int(manque > 0.001), int(manque_capital > 0.001)]
	if cle == _recap_cle:
		return
	_recap_cle = cle
	for c in _recap_effets.get_children():
		_recap_effets.remove_child(c)
		c.queue_free()
	_effet("caisse", ("manque %s k€" % _milliers(manque)) if manque > 0.001
		else "%s k€" % _milliers(cout), -1 if manque > 0.001 else 0)
	if manque_capital > 0.001:
		_effet("capital", "manque %s de confiance" % _nb(manque_capital, 0), -1)
	_effet("duree", _duree(duree), 0)
	for e in consequences(r, duree):
		_effet(e[0], e[1], e[2])


func _manque(r: Dictionary) -> float:
	return ville.cout_commande_ke(_fiche_couche, _fiche_fid, r, _mois) - _caisse_ke


## 🧪 LES CONSÉQUENCES, MESURÉES ET NON ANNONCÉES : la ville d'essai reçoit la
## partie en cours, engage le réglage, et on compare les deux villes une fois le
## chantier livré. [pictogramme, texte, +1 bon / −1 mauvais / 0 neutre].
func consequences(r: Dictionary, duree: float) -> Array:
	var out := []
	if ville_essai == null:
		return out
	var t := _mois + duree + 0.05
	ville_essai.importer_partie(ville.exporter_partie())
	# L'essai ne dit pas non : le refus est déjà sur le bouton.
	ville_essai.crediter_essai_ke(ville.cout_commande_ke(_fiche_couche, _fiche_fid, r, _mois))
	ville_essai.commander(_fiche_couche, _fiche_fid, r, _mois)
	_apercu_crue = float(ville_essai.prochaine_crue(_mois + Ville.HORIZON_MOIS)["eau_pire_m"]) \
		if etude_publiee() else -1.0
	var a := ville.indicateurs(t)
	var b := ville_essai.indicateurs(t)
	# 🗳️ La décision et la livraison ; l'année d'après n'est dite que pour les places
	# retirées. 🔄 L'usure du camp n'y passe plus : sa carte la dit (auteur, 2026-10-02).
	var k0 := ville_essai.capital(_mois) - ville.capital(_mois)
	var k1 := ville_essai.capital(t) - ville.capital(t) - k0
	# 🔄 Une ligne, sans « à la livraison » (auteur, 2026-10-08).
	if absf(k0 + k1) >= 0.5:
		out.append(["capital", "%+d confiance" % int(roundf(k0 + k1)), _sens(k0 + k1)])
	# 🚶 Le retour des places se juge sur la rue (99) : la fiche ne peut pas le
	# connaître, elle annonce la fourchette.
	if absf(k0) >= 0.5 and (r.has("places") or r.has("axe")):
		out.append(["capital", "+%d à +%d confiance un an après, selon la rue" % [
			int(roundf(-k0 * Ville.CAPITAL_RETOUR_PLACES_X_MIN)),
			int(roundf(-k0 * Ville.CAPITAL_RETOUR_PLACES_X_MAX))], 0])
	var da := ville.degats(t)
	var db := ville_essai.degats(t)
	# Sur un îlot, ses propres logements ; ailleurs, ceux que la crue a pris. Les deux
	# ensemble comptaient deux fois un îlot relevé.
	var logements := float(da["logements_perdus"]) - float(db["logements_perdus"])
	if _fiche_couche == "i":
		logements = ville_essai.valeur("i", _fiche_fid, "logements", t) \
			- ville.valeur("i", _fiche_fid, "logements", t)
	if absf(logements) >= 1.0:
		out.append(["logement", "%+d logements" % int(roundf(logements)), _sens(logements)])
	# 🏗️ Ce que la prochaine crue emporterait : c'est ce qui départage les façons de rebâtir.
	if etude_publiee():
		var exposes := float(ville_essai.prochaine_crue(t)["logements_perdus"]) \
			- float(ville.prochaine_crue(t)["logements_perdus"])
		if absf(exposes) >= 1.0:
			out.append(["eau", "%+d logements perdus à la prochaine crue" % int(roundf(exposes)),
				-_sens(exposes)])
	var abrites := ville.sans_toit(t) - ville_essai.sans_toit(t)
	if r.has("camp") and _fiche_couche == "i":
		out.append(["camp", "%d personnes" % (ville.camp_taille(_fiche_fid, _mois)
			* Ville.CAMP_PERSONNES_LOGEMENT), 1])
	elif abrites >= 1.0:
		out.append(["logement", "+%d abrités" % int(roundf(abrites)), 1])
	var ponts := int(da["franchissements_coupes"]) - int(db["franchissements_coupes"])
	if ponts > 0:
		out.append(["pont", "+%d pont" % ponts, 1])
	# 🌉 Ce qui sépare le provisoire du pont en dur : le trafic qu'il porte, rouge s'il sature.
	if r.has("reparer") and _fiche_couche == "r" and trafic != null \
			and _fiche_fid in ville.ponts_coupes():
		var charge := float(trafic.prevoir_pont(_fiche_fid, _mois,
			str(r["reparer"]) == "provisoire")["charge_pont"])
		out.append(["trafic", "%d %% de trafic" % int(roundf(charge * 100.0)),
			-1 if charge >= 1.0 else 0])
	var eau := (float(db.get("eau_prochaine_m", 0.0)) - float(da.get("eau_prochaine_m", 0.0))) * 100.0
	if absf(eau) >= 1.0:
		out.append(["eau", "%+d cm de crue" % int(roundf(eau)), -_sens(eau)])
	elif absf(eau) >= 0.1:
		# 🌾 Une prairie retient quelques millimètres : sous le centimètre, une décimale.
		out.append(["eau", "%s cm de crue" % ("%+.1f" % eau).replace(".", ","), -_sens(eau)])
	var prod := float(b["production_mwh"]) - float(a["production_mwh"])
	if absf(prod) >= 1.0:
		out.append(["production", "%+d MWh/an" % int(roundf(prod)), _sens(prod)])
	var conso := float(b["conso_mwh"]) - float(a["conso_mwh"])
	if absf(conso) >= 1.0:
		out.append(["conso", "%+d MWh/an" % int(roundf(conso)), -_sens(conso)])
	var co2 := (float(b["co2_kt"]) - float(a["co2_kt"])) * 1000.0
	if absf(co2) >= 1.0:
		out.append(["co2", "%+d t/an" % int(roundf(co2)), -_sens(co2)])
	var nourris := float(b["nourriture_personnes"]) - float(a["nourriture_personnes"])
	if absf(nourris) >= 1.0:
		out.append(["feuille", "%+d nourris" % int(roundf(nourris)), _sens(nourris)])
	# 🌾 Le verger ne rend rien avant cinq ans : sa promesse se lit à la récolte.
	if r.has("culture") and _fiche_couche == "i":
		var attente := ville_essai.recolte_dans_mois(_fiche_fid, t)
		if attente > 0.0:
			var plus_tard := ville_essai.champ_nourriture(_fiche_fid, t) \
				- ville.champ_rendement(_fiche_fid, t)
			out.append(["feuille", "%+d nourris dans %s" % [int(roundf(plus_tard)),
				_duree(attente)], _sens(plus_tard)])
	var achats := float(b["achat_nourriture_ke_mois"]) - float(a["achat_nourriture_ke_mois"])
	if absf(achats) >= 0.05:
		out.append(["achat", "%s k€/mois d'achats" % ("%+.1f" % achats).replace(".", ","), -_sens(achats)])
	if r.has("arbres"):
		out.append(["feuille", "+%d arbres" % (ville.arbres_a(_fiche_fid, float(r["arbres"]))
			- ville.arbres_a(_fiche_fid, ville.valeur("r", _fiche_fid, "canopee", _mois))), 1])
	return out


static func _sens(x: float) -> int:
	return 1 if x > 0.0 else -1


func _effet(nom: String, texte: String, sens: int, parent: Control = null) -> void:
	var coul: Color = TEXTE if sens == 0 else (FAIT_TEXTE if sens > 0 else ALERTE)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	var ic := TextureRect.new()
	ic.texture = _icone(nom, 16, coul)
	ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	h.add_child(ic)
	var l := _label(texte, 13, coul)
	if parent != null:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	(parent if parent != null else _recap_effets).add_child(h)


## Ce que le curseur solaire annonce. 🔄 Le prix et le refus ont quitté cette
## fonction le 2026-08-31 : ils sont dans le récapitulatif, où ils portent aussi
## les autres réglages.
func _afficher_choix(actuel: float, cible: float) -> void:
	# 🪜 LE REMBOURSEMENT DE LA TRANCHE QU'ON POSE, et c'est là que la
	# progressivité se voit : sur le même toit, les premiers pour cent se
	# remboursent deux fois plus vite que les derniers.
	var ans := Energie.rentabilite_tranche_annees(ville, _fiche_fid,
		actuel / 100.0, cible / 100.0, _mois)
	_solaire_valeur.text = "%d %% → %d %% · %s%s" % [
		int(roundf(actuel)), int(roundf(cible)),
		_duree(ville.duree_solaire_mois(actuel / 100.0, cible / 100.0)),
		"" if is_inf(ans) else " · remboursé en %d ans" % int(roundf(ans))]


## 🔎 CE QUE LA MINIATURE DOIT MONTRER (décision 12) : l'ÉTAT QUI SERA LIVRÉ —
## les réglages posés devant le chantier engagé, lui-même devant l'état réel.
## Survoler un bouton montre en plus ce qu'il livrerait, avant qu'on le presse.
## 🔄 Plus de mode « avant » (auteur, 2026-09-30) : l'avant, c'est la ville.
## Lu à chaque image par `maquette._maj_apercu` : ne rien y calculer de lourd.
func apercu_demande() -> Dictionary:
	var equipe := 0.0
	var verdi := 0.0
	var plate := 0.0
	var futur := false
	var berge := 0.0
	var places := true
	var roule := true
	var arbres := 0.0
	# 🏕️ Le nombre d'abris que la miniature doit poser sur le champ.
	var camp := 0
	# 🏢 (avancement, part d'un bâtiment, mètres) — ce que le shader attend.
	# ⚠️ Un Vector4, pas une Color : une couleur passerait en espace linéaire.
	var dense := Vector4(0.0, 1.0, 0.0, 0.0)
	var culture := 0.0
	var rebati := Vector2.ZERO
	if _fiche_fid < 0:
		return {"couche": _fiche_couche, "fid": _fiche_fid, "equipe": equipe,
			"verdi": verdi, "plate": plate,
			"futur": futur, "berge": berge, "places": places, "roule": roule,
			"arbres": arbres, "dense": dense, "camp": camp}
	var r := _reglages()
	if _fiche_couche == "i":
		plate = ville.valeur("i", _fiche_fid, "_part_plate", _mois)
		var ed := ville.etat_dense(_fiche_fid, _mois)
		dense = Vector4(float(ed["avancement"]), float(ed["pas"]),
			float(ed["metres"]), 0.0)
		equipe = maxf(ville.etat_solaire(_fiche_fid, _mois)["cible"],
			float(r.get("solaire", 0.0)))
		verdi = maxf(ville.etat_vert(_fiche_fid, _mois)["cible"],
			float(r.get("vert", 0.0)))
		# 🏢 La miniature promet l'état LIVRÉ : les bâtiments VISÉS déjà
		# montés, pas la moitié d'un chantier. 🪜 Et « visés » n'est plus
		# « tous » — c'est le cran du curseur, sinon l'image promet un îlot
		# entier pour le prix de trois toits.
		var e := int(ed["etages"])
		var vise := float(ed["cible"])
		if r.has("dense"):
			e = int(r["dense"]["etages"])
			vise = maxf(vise, float(r["dense"]["part"]))
		if e > 0 and vise > 0.0:
			dense = Vector4(vise, float(ed["pas"]),
				float(e) * Ville.DENSE_ETAGE_M, 0.0)
		# 🏕️ LE CAMP DANS LA MINIATURE (auteur, 2026-09-18) : il manquait, et
		# c'était le seul chantier qu'on payait sans l'avoir vu. Même règle que
		# les autres réglages — au survol du bouton comme une fois posé.
		# 🌾 La culture LIVRÉE, arbres adultes : la miniature promet l'état final.
		culture = ville.parcelle_code(_fiche_fid, _mois)
		var visee := int(r.get("culture", -1))
		for k in _culture_boutons.size():
			if _survole(_culture_boutons[k]):
				visee = k
		if visee < 0 and (ville.culture_en_cours(_fiche_fid, _mois)
				or ville.recolte_dans_mois(_fiche_fid, _mois) > 0.0):
			visee = ville.champ_culture(_fiche_fid, _mois)
		if visee >= 0:
			culture = ville.parcelle_code(_fiche_fid, _mois, visee)
		if ville.camp_possible(_fiche_fid) and (ville.est_campement(_fiche_fid, _mois)
				or r.has("camp")
				or _survole(_camp_bouton)) and not r.has("labour") and not _survole(_labour_bouton):
			camp = ville.camp_abris(_fiche_fid, _mois) if ville.camp_livre(_fiche_fid, _mois) \
				else ville.camp_taille(_fiche_fid, _mois)
			culture = Ville.PARCELLE_CAMP
		# 🚜 Le labour promet le champ rendu, en céréales.
		if r.has("labour") or _survole(_labour_bouton):
			culture = ville.parcelle_code(_fiche_fid, _mois, Ville.CEREALES)
	if _fiche_couche != "b":
		futur = ville.reparation_finie(_fiche_couche, _fiche_fid, _mois) \
			or r.has("reparer") or _survole(_repare_bouton) \
			or _survole(_repare_provisoire)
		# 🌿 Un parc ne promet aucune maison.
		var facon := ville.facon_reparation(_fiche_fid, str(r.get("reparer", "")))
		for f in _rebatir_boutons:
			if _survole(_rebatir_boutons[f]) or (_projets_cartes.has(f)
					and _survole(_projets_cartes[f]["bouton"])):
				futur = true
				facon = f
		# 🏗️ L'allure promise (95) : moderne, pilotis, ou la ruine rendue en parc.
		if _fiche_couche == "i" and futur:
			rebati = Ville.rendu_rebati(facon)
		if _fiche_couche == "i" and facon == "parc":
			futur = false
	# 🌉 Quel pont la miniature promet : le choix posé, sinon le bouton survolé.
	var provisoire := _fiche_couche == "r" and ville.pont_provisoire(_fiche_fid)
	if _fiche_couche == "r":
		if _survole(_repare_provisoire) or _survole(_repare_bouton):
			provisoire = _survole(_repare_provisoire)
		elif r.has("reparer"):
			provisoire = str(r["reparer"]) == "provisoire"
	if _fiche_couche == "b":
		var e := maxi(ville.berge_cible(_fiche_fid), int(r.get("berge", 0)))
		for k in _berge_boutons.size():
			if _survole(_berge_boutons[k]):
				e = k + Ville.BERGE_APAISEE
		# La même règle que la ville : une berge de campagne naît renaturée, et la
		# teinte dit un CHANGEMENT, pas un état.
		berge = 0.0 if e == ville.berge_depart(_fiche_fid) else float(e)
	if _fiche_couche == "r":
		# La bordure se vide et la chaussée aussi — au survol comme une fois le
		# réglage posé. Un bouton grisé, lui, ne promet rien.
		places = ville.valeur("r", _fiche_fid, "stationnement", _mois) >= 0.5 \
			and not r.has("places") \
			and not _survole(_trafic_stationnement)
		roule = (trafic == null or not trafic.axe_ferme(_fiche_fid)) \
			and not r.has("axe") \
			and not _survole(_trafic_axe)
		# 🅿️ La règle, en une ligne : pas de voitures, pas de places. Au
		# survol du bouton de fermeture comme une fois le réglage posé.
		places = places and roule
		# 🌳 La canopée du moment, ou celle que la commande livrerait : c'est
		# elle qui décide combien d'arbres l'échantillon plante.
		arbres = maxf(ville.valeur("r", _fiche_fid, "canopee", _mois),
			float(r.get("arbres", 0.0)))
	return {"couche": _fiche_couche, "fid": _fiche_fid, "equipe": equipe,
		"verdi": verdi, "plate": plate,
		"futur": futur, "berge": berge, "places": places, "roule": roule,
		"arbres": arbres, "dense": dense, "camp": camp, "provisoire": provisoire,
		"culture": culture, "rebati": rebati}


## ⚠️ Appelé à chaque image : reposer un `theme_color_override` identique fait
## retraiter le thème du Label pour rien.
func _alerter_cout(alerte: bool) -> void:
	if alerte == _cout_en_alerte:
		return
	_cout_en_alerte = alerte
	_recap_texte.add_theme_color_override("font_color", ALERTE if alerte else GRIS)


## Les trois entrées de l'essai automatisé. Elles passent toutes par le chemin
## d'un doigt — `value_changed` pour un curseur, `_basculer` pour une bascule :
## la capture prouve ce que le joueur verra, pas ce que le code croit.
func viser(pct: float) -> void:
	_solaire_curseur.value = pct


func viser_vert(pct: float) -> void:
	_vert_curseur.value = pct


func viser_arbres(pct: float) -> void:
	_arbres_curseur.value = pct


## 🏢 En BÂTIMENTS. Lu par `--essai`, qui pose un cran puis un autre pour
## montrer que le premier coûte moins cher que le dernier.
func viser_dense(batiments: int) -> void:
	_dense_curseur.value = float(batiments)


## ⚠️ `valeur` N'EST PAS UN BOOLÉEN. Écrite `valeur := true`, elle était typée
## bool par inférence : `poser("dense", 2)` posait 1, et la capture d'essai
## annonçait deux étages en en montrant un. Corrigé le 2026-09-03.
func poser(cle: String, valeur: Variant = true) -> void:
	_basculer(cle, valeur)


func _sur_curseur(v: float) -> void:
	if _fiche_fid < 0 or _ecrit_curseur:
		return
	var actuel := ville.valeur("i", _fiche_fid, "part_toit_equipe", _mois) * 100.0
	# Déposer des panneaux n'est pas une décision de ce prototype (`Énergie` §1).
	# Rattrapé ici plutôt qu'en montant `min_value`, pour garder l'échelle fixe.
	# 🌿 Deux rattrapages et non un : on ne DÉPLANTE pas de panneaux, et on ne
	# pose rien sur un mètre carré que les toits verts ont déjà pris.
	var plafond := ville.part_solaire_max(_fiche_fid, _mois) * 100.0
	if _vert_choix >= 0.0:
		plafond = minf(plafond, 100.0 - _vert_choix)
	v = clampf(v, actuel, maxf(plafond, actuel))
	if not is_equal_approx(v, _solaire_curseur.value):
		_ecrit_curseur = true
		_solaire_curseur.set_value_no_signal(v)
		_ecrit_curseur = false
	_solaire_choix = v
	_solaire_jauge.regler(actuel / 100.0, v / 100.0)
	_afficher_choix(actuel, v)
	_maj_recap()


## 🌿 Le curseur des toits verts. Même règle que le solaire, plus le plafond de
## la pente : un substrat ne tient pas sur un versant.
func _sur_curseur_vert(v: float) -> void:
	if _fiche_fid < 0 or _ecrit_curseur:
		return
	var actuel := ville.valeur("i", _fiche_fid, "part_toit_vert", _mois) * 100.0
	var plafond := ville.part_vert_max(_fiche_fid, _mois) * 100.0
	if _solaire_choix >= 0.0:
		plafond = minf(plafond, 100.0 - _solaire_choix)
	v = clampf(v, actuel, maxf(plafond, actuel))
	if not is_equal_approx(v, _vert_curseur.value):
		_ecrit_curseur = true
		_vert_curseur.set_value_no_signal(v)
		_ecrit_curseur = false
	_vert_choix = v
	_vert_jauge.regler(actuel / 100.0, v / 100.0)
	_maj_recap()


## 🏢 Le curseur de la densification. Même règle que les trois autres — on ne
## DÉMOLIT pas un étage —, à ceci près qu'il compte des bâtiments entiers.
func _sur_curseur_dense(v: float) -> void:
	if _fiche_fid < 0 or _ecrit_curseur:
		return
	var etat := ville.etat_dense(_fiche_fid, _mois)
	v = clampf(roundf(v), float(etat["montes"]), float(etat["batiments"]))
	if not is_equal_approx(v, _dense_curseur.value):
		_ecrit_curseur = true
		_dense_curseur.set_value_no_signal(v)
		_ecrit_curseur = false
	_dense_choix = v
	_maj_fiche()


## 🌳 Le curseur des arbres. Même règle que le solaire : on ne DÉPLANTE pas, et
## le rattrapage se fait ici pour garder une échelle fixe de bout en bout.
func _sur_curseur_arbres(v: float) -> void:
	if _fiche_fid < 0 or _ecrit_curseur:
		return
	var plafond := Ville.PLANTATION_CANOPEE_MAX
	var actuel := ville.valeur("r", _fiche_fid, "canopee", _mois) / plafond * 100.0
	if v < actuel:
		v = actuel
		_ecrit_curseur = true
		_arbres_curseur.set_value_no_signal(v)
		_ecrit_curseur = false
	_arbres_choix = v
	_arbres_jauge.regler(actuel / 100.0, v / 100.0)
	_maj_recap()


## Après un retour au mois 0 : réglages posés et compte rendu périmés.
func remis_a_zero() -> void:
	_vider_pose()
	_fermer_lieu()
	_message.text = "Retour au mois 0, caisse à %s." \
		% _millions(Ville.CAISSE_DEPART_KE)
	if _fiche_fid >= 0:
		_maj_fiche()


## Le compte rendu d'une commande partie. 🔄 S'appelait `confirmer_solaire` et
## ne parlait que des panneaux ; elle vaut pour les cinq réglages depuis le
## 2026-08-31. Le nom reste : `--essai` l'appelle.
func confirmer_solaire(_cout_ke := 0.0) -> void:
	_vider_pose()   # la commande est partie : la fiche reprend la main
	_message.text = "" # Le constat reste dans la notification et le journal de son lieu.
	_maj_fiche()


static func _duree(mois: float) -> String:
	if mois < 1.0:
		var j := int(ceil(mois * 30.0))
		return "1 jour" if j <= 1 else "%d jours" % j
	# Le dixième ne s'écrit que s'il n'est pas nul : « 6,0 mois » annonce une
	# précision qu'on n'a pas.
	return "%s mois" % _nb(mois, 0 if is_equal_approx(mois, roundf(mois)) else 1)


static func _nb(v: float, dec: int) -> String:
	return (("%%.%df" % dec) % v).replace(".", ",")


## Le budget se lit en M€ (auteur, 2026-09-29) ; les prix et la recette restent en k€.
static func _millions(ke: float) -> String:
	var m := ke / 1000.0
	return _nb(m, 2 if absf(m) < 10.0 else 1).replace("-", "−") + " M€"


## Avec l'espace des milliers : la caisse passe les 10 000 k€ en vingt ans, et
## « 10240 » se lit de travers.
static func _milliers(v: float) -> String:
	var s := "%d" % int(roundf(absf(v)))
	var out := ""
	for i in s.length():
		if i > 0 and (s.length() - i) % 3 == 0:
			out += " "
		out += s[i]
	return ("−" if v < -0.5 else "") + out


# ------------------------------------------------- après la crue (04e · 23b)

## La fiche d'une rue. Elle n'a qu'un sujet : ce que la crue lui a fait.
## La barre du haut de fiche. Elle vaut pour les trois couches : c'est
## `ville.chantier` qui sait lequel des chantiers de l'objet finit le dernier.
func _maj_chantier() -> void:
	var c := ville.chantier(_fiche_couche, _fiche_fid, _mois)
	_chantier_bloc.visible = bool(c["actif"])
	if not _chantier_bloc.visible:
		return
	_chantier_quoi.text = "Pont provisoire" if str(c["quoi"]) == "pont" \
		and _fiche_couche == "r" and ville.pont_provisoire(_fiche_fid) \
		else CHANTIER_MOTS.get(str(c["quoi"]), "Chantier")
	_chantier_reste.text = "encore %s" % _duree(float(c["reste_mois"]))
	var part := float(c["part"])
	_chantier_jauge.regler(part, part)


func _maj_fiche_rue() -> void:
	var o: Dictionary = ville.routes.get(_fiche_fid, {})
	if o.is_empty():
		return
	_titre_lieu("r")
	var etat := str(o.get("etat_crue", "intact"))
	if ville.est_repare("r", _fiche_fid):
		etat = "repare"
	_fiche_soustitre.text = ("provisoire" if ville.pont_provisoire(_fiche_fid) else "") \
		if _fiche_fid in ville.ponts_coupes() \
		else str(o.get("hierarchie", "?"))
	# 🚗 CE QU'UNE RUE REND, c'est le trafic qu'elle porte : c'est lui qui decide
	# si la fermer se paie, et il est le seul chiffre de sa ligne du haut.
	_maj_resume("trafic", "%d %% de trafic" % int(roundf(
		ville.trafic_vu(_fiche_fid, _mois) * 100.0)))
	(_rue_valeurs["largeur"] as Label).text = "%s m" % _nb(
		float(o.get("largeur_m", 0.0)), 0)
	(_rue_valeurs["places"] as Label).text = _nb(
		ville.valeur("r", _fiche_fid, "stationnement", _mois), 0)
	_bloc_dispo[_trafic_bloc] = true
	var stationnement_engage := ville.stationnement_en_suppression(_fiche_fid)
	var axe_ferme: bool = trafic != null and trafic.axe_ferme(_fiche_fid)
	var stationnement_fini := stationnement_engage and ville.valeur(
		"r", _fiche_fid, "stationnement", _mois) < 0.5
	var a_des_places := ville.valeur("r", _fiche_fid, "stationnement", _mois) >= 0.5
	# 🅿️ Le bouton s'efface derriere la fermeture, qui emporte deja les places.
	var emportees: bool = _pose.has("axe") and a_des_places
	if stationnement_engage:
		_trafic_stationnement.text = "Places retirées" if stationnement_fini else "Places · 2 mois"
		_marquer(_trafic_stationnement, false)
	elif emportees:
		_trafic_stationnement.text = "Places emportées par la fermeture"
		_marquer(_trafic_stationnement, false)
	else:
		_posee(_trafic_stationnement, "places", "Retirer les places")
	_trafic_stationnement.disabled = stationnement_engage or emportees 		or not a_des_places
	if axe_ferme:
		_trafic_axe.text = "Fermée · report" if trafic.report_en_cours(_fiche_fid, _mois) 			else "Fermée"
		_marquer(_trafic_axe, false)
	else:
		_posee(_trafic_axe, "axe", "Fermer aux voitures")
	_trafic_axe.disabled = axe_ferme or not ville.route_praticable(_fiche_fid, _mois) 		or ville.trafic_vu(_fiche_fid, _mois) < 0.20
	_maj_arbres()
	# 🌳 Le verger se NOMME sur la fiche : c'est là qu'on comprend pourquoi
	# la rue est vide. Déblayée, elle le reste tant que le quartier l'est.
	var boue := float(o.get("part_boue", 0.0))
	var sous_boue := boue > 0.0 and etat != "repare"
	(_rue_valeurs["etat"] as Label).text = {
		"coupe": "franchissement emporté",
		"fragile": "pile déchaussée",
		"repare": "verger déblayé" if boue > 0.0 else "remise en service",
	}.get(etat, "le verger · %d %% sous la boue" % int(roundf(boue * 100.0))
		if sous_boue else ("%s m d'eau" % _nb(float(o.get("hauteur_eau", 0.0)), 1)
		if float(o.get("hauteur_eau", 0.0)) > 0.1 else "intacte"))
	if etat == "repare" and _fiche_fid in ville.ponts_coupes():
		(_rue_valeurs["etat"] as Label).text = ("liaison provisoire" if ville.pont_provisoire(_fiche_fid)
			else "liaison ouverte") if trafic.pont_fonctionnel(_fiche_fid, _mois) \
			else "pont livré · accès coupé"
		# Engagé n'est pas livré : la fiche disait « pont livré » pendant le chantier.
		if not ville.reparation_finie("r", _fiche_fid, _mois):
			(_rue_valeurs["etat"] as Label).text = "en chantier · chemin dégagé" \
				if trafic.acces_pont(_fiche_fid, _mois)["obstacles"].is_empty() else "en chantier · boue sur le chemin"
	var l_etat := _rue_valeurs["etat"] as Label
	l_etat.text = l_etat.text.substr(0, 1).to_upper() + l_etat.text.substr(1)
	_maj_reparation(o)
	_maj_recap()


## 🌊 LA FICHE D'UNE BERGE. Le bloc de réparation ne s'ouvre pas ici : la crue
## n'a rien chiffré sur une berge, et un bouton grisé de plus n'apprendrait rien.
func _maj_fiche_berge() -> void:
	var o: Dictionary = ville.berges.get(_fiche_fid, {})
	if o.is_empty():
		return
	var etat := ville.berge_etat(_fiche_fid, _mois)
	_titre_lieu("b")
	# Le nom de la berge porte déjà sa rive : un sous-titre la répéterait.
	_fiche_soustitre.text = ""
	# 🌊 CE QU'UNE BERGE REND, c'est sa longueur : c'est elle qu'on paie au metre.
	_maj_resume("eau", "%s m de berge" % _nb(float(o.get("longueur_m", 0.0)), 0))
	(_berge_valeurs["mur"] as Label).text = "%s m" % _nb(
		float(o.get("mur_m", 0.0)), 0)
	(_berge_valeurs["rive"] as Label).text = "%s m" % _nb(
		float(o.get("rive_m", 0.0)), 1)
	var rues: Array = o.get("rues", [])
	(_berge_valeurs["rues"] as Label).text = "aucune" if rues.is_empty() 		else "%d" % rues.size()
	# 🌊 CE QU'ELLE RACHETE. Le bief se lit en ilots, pas en fil d'eau : « 7
	# ilots » decide, « 0,31 a 0,61 » n'est qu'une coordonnee.
	var bief: Array = ville.ilots_du_bief(_fiche_fid)
	(_berge_valeurs["bief"] as Label).text = "aucun îlot exposé" if bief.is_empty() 		else "%d îlot%s, dont le %d" % [bief.size(),
			"s" if bief.size() > 1 else "", int(bief[0])]
	var pire := 0.0
	for f in bief:
		pire = maxf(pire, ville.valeur("i", int(f), "hauteur_eau_annonce", _mois))
	(_berge_valeurs["crue"] as Label).text = "%s m" % _nb(pire, 2)
	var reste := ville.berge_reste_mois(_fiche_fid, _mois)
	# 🔎 L'état RÉALISÉ, et lui seul : la barre du haut de fiche porte déjà le
	# chantier en cours et ce qu'il reste à attendre.
	(_berge_valeurs["etat"] as Label).text = Ville.BERGE_NOMS[etat]

	# 🔄 Plus de phrase sous la berge (auteur, 2026-10-08) : la tuile État la dit.
	_berge_texte.text = ""
	_berge_texte.visible = _berge_texte.text != ""
	for k in _berge_boutons.size():
		var cible: int = Ville.BERGE_APAISEE + k
		var bouton: Button = _berge_boutons[k]
		var nom: String = Ville.BERGE_NOMS[cible]
		bouton.disabled = cible <= etat or reste > 0.0
		# ⚠️ Pas de `capitalize()` : il met une majuscule à CHAQUE mot, et le
		# bouton sortait « Quai Apaisé ».
		var titre := nom.substr(0, 1).to_upper() + nom.substr(1)
		bouton.visible = cible > etat
		if cible <= etat:
			bouton.text = "%s · fait" % titre
			_marquer(bouton, false)
		else:
			# 🔄 Un bouton de choix ne porte que son nom (auteur, 2026-09-29) :
			# prix, durée et effets se lisent dans les conséquences.
			_posee(bouton, "berge", titre, cible)
	_maj_recap()


## LE BLOC DE RÉPARATION, et c'est le seul endroit où le jeu dit non deux fois :
## une fois parce que la caisse ne suit pas, une fois parce qu'il n'y a rien à
## réparer. Un bouton grisé sans phrase est une panne ; sous « il manque 214 k€ »
## c'est une règle.
func _maj_reparation(o: Dictionary) -> void:
	var couche := _fiche_couche
	var pont := couche == "r" and _fiche_fid in ville.ponts_coupes()
	# ⚠️ Jamais caché puis remontré dans la même image : Godot perd le clic entre
	# l'appui et le relâchement, et le bouton ne répondait plus (2026-09-26).
	_repare_provisoire.visible = pont and not ville.est_repare(couche, _fiche_fid) \
		and float(o.get("cout_reparation_ke", 0.0)) > 0.0
	# 🏗️ Un îlot sinistré se relève de quatre façons ; elles remplacent le bouton.
	var rebatir := couche == "i" and float(o.get("logements_sinistres", 0.0)) > 0.0 \
		and not ville.est_repare(couche, _fiche_fid) and float(o.get("cout_reparation_ke", 0.0)) > 0.0
	# 🏛️ Avant le concours (104), comme avant ou le concours ; après, l'écran des projets.
	# Sans maison détruite, comme avant seulement.
	var rendu := ville.concours_rendu(_mois)
	var concours: bool = rebatir and ville.concours_utile(_fiche_fid) \
		and (ouverture == null or ouverture.concours_ouvert())
	# 🏗️ Sur pilotis dès que l'institut l'a mis au point (auteur, 2026-10-08), sans concours ;
	# avant, grisé : il dit où il se met au point.
	var pilotis_vu: bool = rebatir and not (concours and rendu)
	var pilotis: bool = pilotis_vu and ville.facon_permise(_fiche_fid, "pilotis", _mois)
	for facon in _rebatir_boutons:
		(_rebatir_boutons[facon] as Button).visible = rebatir and facon == "tradition" \
			and not (concours and rendu) or facon == "pilotis" and pilotis_vu
	(_rebatir_boutons["pilotis"] as Button).disabled = not pilotis
	_concours_bouton.visible = concours and not rendu
	_projets_bouton.visible = concours and rendu
	_repare_etat.visible = false
	_repare_bouton.visible = not rebatir
	var prix := float(o.get("cout_reparation_ke", 0.0))
	if prix <= 0.0:
		_bloc_dispo[_repare_bloc] = false
		return
	_bloc_dispo[_repare_bloc] = true
	var fini: bool = ville.reparation_finie(couche, _fiche_fid, _mois)
	var engage: bool = ville.est_repare(couche, _fiche_fid)
	var verbe := _verbe_reparation(couche, o)
	if fini:
		# 🔄 Ni « Remis en état » ni « ✓ Chantier terminé » (auteur, 2026-10-08) : la tuile Crue le dit.
		_repare_texte.text = ""
		if couche == "i" and float(o.get("logements_sinistres", 0.0)) > 0.0:
			_repare_texte.text = FAIT_REBATI[ville.facon_reparation(_fiche_fid)]
		if pont:
			_repare_texte.text = ouverture.description_pont(_fiche_fid) if ouverture != null else "Pont reconstruit."
		_repare_bouton.visible = false
		return
	if engage:
		# La barre du haut de fiche dit déjà le temps qui reste.
		_repare_texte.text = ""
		if pont and ouverture != null:
			_repare_texte.text = ouverture.description_pont(_fiche_fid)
		_repare_bouton.visible = false
		_repare_etat.visible = true
		_repare_etat.add_theme_color_override("font_color", GRIS_FORT)
		_repare_etat.text = "Pont provisoire en cours" if pont and ville.pont_provisoire(_fiche_fid) \
			else "Chantier en cours"
		if couche == "i" and float(o.get("logements_sinistres", 0.0)) > 0.0:
			_repare_etat.text += " · " + String(Ville.RECONSTRUCTIONS[
				ville.facon_reparation(_fiche_fid)]["nom"]).to_lower()
		return
	# 🔄 Le prix ne dit plus non ici depuis le 2026-08-31 : le refus est dans le
	# récapitulatif, où il porte le TOTAL. Réparer et poser des panneaux séparément
	# tenaient dans la caisse ; ensemble, non — et seul le total peut le dire.
	_repare_texte.text = _degat_en_clair(couche, o)
	if couche == "r" and str(o.get("etat_crue", "")) == "coupe" and ouverture != null:
		# Le dégât est dans la grille, ce qui manque en caisse dans les conséquences.
		_repare_texte.text = ouverture.description_pont(_fiche_fid)
	_posee(_repare_bouton, "reparer", verbe)
	_repare_bouton.disabled = false
	if rebatir:
		# ⚖️ Aucune n'est conseillée (95) : le prix et les effets se lisent dans les conséquences.
		# 🔴 Textes flaggables (90).
		_posee(_rebatir_boutons["tradition"], "reparer", "Comme avant", "tradition")
		if pilotis:
			_posee(_rebatir_boutons["pilotis"], "reparer", "Sur pilotis", "pilotis")
		else:
			# 🔴 Flaggable (90).
			_rebatir_boutons["pilotis"].text = "Sur pilotis · en recherche à l'institut" \
				if ville.recherche_engagee(Recherche.PILOTIS) else "Sur pilotis · à mettre au point à l'institut"
		var choisi := str(_pose.get("reparer", ""))
		if concours and rendu:
			_projets_bouton.text = "Voir les quatre projets" if choisi == "" \
				else "Projet : %s · revoir" % String(Ville.RECONSTRUCTIONS[choisi]["nom"]).to_lower()
		elif concours and ville.concours_lance():
			_concours_bouton.text = "Concours en cours"
			_concours_bouton.disabled = true
			_marquer(_concours_bouton, false)
		elif concours:
			_posee(_concours_bouton, "concours", "Lancer un concours")
			_concours_bouton.disabled = false
	if pont:
		# 🌉 DEUX CHOIX, jamais les deux (auteur, 2026-09-24) : vite et sur une
		# voie, ou en dur et plus long. Reposer l'autre remplace le premier.
		_posee(_repare_provisoire, "reparer", "Pont provisoire", "provisoire")


## 🏗️ Ce que la fiche dit d'un îlot relevé, selon la façon.
const FAIT_REBATI := {"tradition": "Relevé comme avant.", "moderne": "Rebâti en moderne.",
	"pilotis": "Rebâti sur pilotis.", "parc": "Rendu à l'eau : un parc inondable."}


## Un bouton qui MONTRE sans engager : un contour, sans plaque, pour ne pas
## peser autant que celui qui paie.
func _habiller_secondaire(b: Button) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = Color8(200, 174, 152) if BOIS else Color8(120, 112, 90, 190)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(_r(9))
	sb.set_content_margin_all(9)
	var survol := sb.duplicate()
	survol.bg_color = Color8(255, 255, 255, 90)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", survol)
	b.add_theme_stylebox_override("pressed", survol)


## 🏕️ LE BLOC DU RELOGEMENT. Il ne dit jamais non : un champ inaccessible se
## pose et se paie, et l'avertissement est au-dessus du bouton. L'erreur coûte
## du temps et de l'argent, elle ne ferme aucune porte — un pont réparé
## remplira le camp plus tard.
## 🌾 Ce que le champ cesse de nourrir n'est que dans les conséquences (auteur, 2026-10-07).
func _maj_camp() -> void:
	if _fiche_couche != "i" or not ville.camp_possible(_fiche_fid):
		_bloc_dispo[_camp_bloc] = false
		return
	_bloc_dispo[_camp_bloc] = true
	_camp_texte.visible = true
	var fid := _fiche_fid
	# 🚿 Le bouton attend la plainte (auteur, 2026-10-02).
	_demandes_bloc.visible = ville.camp_livre(fid, _mois) and ville.camp_accessible(fid, _mois) \
		and _mois >= ville.usure_debut()
	if _demandes_bloc.visible:
		_maj_demandes()
	if ville.camp_pose(fid):
		# 🚜 Labouré : redevenu champ, le bloc du camp n'a plus rien à dire.
		if not ville.est_campement(fid, _mois):
			_bloc_dispo[_camp_bloc] = false
			return
		# 🌉 Le camp promis, et personne dedans : c'est la carte, elle peut changer.
		# Le reste (logés, containers) est dans le résumé et les tuiles.
		_camp_texte.text = "" if ville.camp_accessible(fid, _mois) or not ville.camp_livre(fid, _mois) \
			else "Camp vide : aucun pont n'y mène."
		_camp_bouton.disabled = true
		_camp_bouton.visible = false
		_marquer(_camp_bouton, false)
		_labour_bouton.visible = ville.labour_possible(fid, _mois)
		if _labour_bouton.visible:
			_posee(_labour_bouton, "labour", "Labourer")
		return
	_labour_bouton.visible = false
	# Sur les places COMMANDÉES : un second champ ne se propose plus quand les
	# camps en route suffisent.
	var besoin: float = ville.besoin_non_couvert(_mois)
	if besoin <= 0.0:
		_camp_texte.text = ""
		_camp_bouton.text = "Rien à reloger"
		_camp_bouton.disabled = true
		_camp_bouton.visible = false
		_marquer(_camp_bouton, false)
		return
	var places: int = ville.camp_taille(fid, _mois)
	# 🔄 Ce que le camp abrite est passé dans les conséquences (auteur, 2026-10-08).
	_camp_texte.text = "" if ville.camp_accessible(fid, _mois) else "⚠ Autre rive : inaccessible"
	_posee(_camp_bouton, "camp", "Installer %d containers" % places)
	_camp_bouton.disabled = false
	_camp_bouton.visible = true


func _maj_demandes() -> void:
	for d in Ville.DEMANDES_ORDRE:
		var b: Button = _demande_boutons[d]
		var info: Dictionary = Ville.DEMANDES[d]
		b.visible = not ville.demande_livree(d, _mois)
		if ville.demande_livree(d, _mois):
			b.text = str(info["fait"])
			b.disabled = true
			_marquer(b, false)
		elif ville.demande_engagee(d):
			b.text = "%s · en cours" % info["nom"]
			b.disabled = true
			_marquer(b, false)
		else:
			_posee(b, "demande_" + d, "%s · %s k€" % [info["nom"], _milliers(float(info["ke"]))])
			b.disabled = false


## 🌾 LE BLOC DES CULTURES. Fermé pendant l'urgence (comme le solaire) et sous
## un camp ; un chantier en cours grise les quatre boutons.
func _maj_culture() -> void:
	var fid := _fiche_fid
	if _fiche_couche != "i" or not ville.est_champ(fid) \
			or (ville.camp_pose(fid) and not ville.labour_fini(fid, _mois)) \
			or _levier_ferme("pre") != "":
		_bloc_dispo[_culture_bloc] = false
		return
	_bloc_dispo[_culture_bloc] = true
	var actuelle := ville.champ_culture(fid, _mois)
	var en_cours := ville.culture_en_cours(fid, _mois)
	var recolte := ville.recolte_dans_mois(fid, _mois)
	_culture_texte.text = "Première récolte dans %s." % _duree(recolte) \
		if not en_cours and recolte > 0.0 else ""
	_culture_texte.visible = _culture_texte.text != ""
	for k in _culture_boutons.size():
		var b: Button = _culture_boutons[k]
		var c: Dictionary = Ville.CULTURES[k]
		var nom: String = c["nom"]
		var titre := nom.substr(0, 1).to_upper() + nom.substr(1)
		b.disabled = k == actuelle or en_cours
		b.visible = k != actuelle or en_cours
		if k == actuelle:
			b.text = "%s · %s" % [titre, "en chantier" if en_cours else "en place"]
			_marquer(b, false)
		else:
			_posee(b, "culture", titre, k)


func _verbe_reparation(couche: String, o: Dictionary) -> String:
	if couche == "i":
		return "Reconstruire l'îlot"
	if str(o.get("etat_crue", "")) == "coupe":
		return "Rebâtir en dur"
	return "Déblayer la rue"

## Ce que la crue a pris à CET objet, en une phrase. Sans elle, le prix n'a
## pas de contrepartie et le joueur choisit à l'aveugle.
func _degat_en_clair(couche: String, o: Dictionary) -> String:
	if couche == "i":
		# 🔄 Rien sous les tuiles de l'îlot (auteur, 2026-10-08) : elles disent tout.
		return ""
	if str(o.get("etat_crue", "")) == "coupe":
		return "Le tablier est parti ; la rive droite n'a plus d'accès routier."
	return "La rue a gardé %s m de limon." % _nb(
		float(o.get("hauteur_eau", 0.0)), 1)


## Ce que la crue coûte encore à la ville. Trois nombres, et ils baissent quand
## on répare : c'est la seule contrepartie visible d'une reconstruction tant que
## le budget ne dépend pas de `logements` (dette nommée du prototype).
func maj_degats(d: Dictionary) -> void:
	_degats = d
	if _degats_valeurs.is_empty():
		return
	(_degats_valeurs["logements"] as Label).text = _nb(
		float(d["logements_perdus"]), 0)
	(_degats_valeurs["ponts"] as Label).text = "%d sur 3" % int(
		d["franchissements_coupes"])
	(_degats_valeurs["reste"] as Label).text = _milliers(
		float(d["a_reparer_ke"])) + " k€"
