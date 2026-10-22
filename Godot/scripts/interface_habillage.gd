extends CanvasLayer
# L'habillage de l'interface : thème, polices, tailles, icônes, nombres écrits.
# Ne connaît ni la ville ni la fiche ; `interface.gd` en hérite et seul lui est instancié.

## 🔤 LA POLICE : Jost (auteur, 2026-10-22), Cabin avant. Toutes dans `Godot/polices/`, sous
## licence SIL OFL (leur `*-OFL.txt` est à côté) — donc libres pour un jeu vendu.
## `-- --police <clé>` en essaie une sans toucher au fichier ; « godot » est la police d'origine.
const POLICES := {
	"godot": "",
	"rubik": "res://polices/Rubik.ttf",
	"grotesk": "res://polices/SpaceGrotesk.ttf",
	"barlow": "res://polices/BarlowSemiCondensed.ttf",
	"nunito": "res://polices/Nunito.ttf",
	"fredoka": "res://polices/Fredoka.ttf",
	"baloo": "res://polices/Baloo2.ttf",
	"cabin": "res://polices/Cabin-Regular.ttf",
	# La jumelle libre de Futura (2026-10-22).
	"jost": "res://polices/Jost.ttf",
}
const POLICE := "rubik"
## 🧪 Essai du 2026-10-22, polices du système et non du dossier : aucune n'est sous OFL
## (Helvetica, DIN = Monotype ; Acumin = Adobe Fonts, sans droit d'embarquer dans un jeu).
## Windows rend Arial pour Helvetica, Bahnschrift (sa DIN 1451) pour DIN ; Acumin n'existe
## que si Creative Cloud l'a activée, sinon Windows rend une autre police (le `print` la nomme).
## `CORPS_MAIGRE` : corps en 400, titres et monnaies en 700 ; au 600 de la fiche, Arial n'a que du 700.
const POLICES_SYSTEME := {
	"helvetica": ["Helvetica Neue", "Helvetica", "Arial"],
	"acumin": ["Acumin Pro", "Acumin Variable Concept", "Acumin Pro SemiCondensed"],
	"din": ["DIN Next LT Pro", "DIN Pro", "DIN", "Bahnschrift"],
}
## 🔴 PIÈGE PAYÉ LE 2026-10-17 : Cabin variable (wght + wdth) perdait sa graisse
## au fil de la partie d'essai et tout sortait en 400. Elle vient donc en
## fichiers fixes, un par graisse ; `_peser` prend le plus proche.
const GRAISSES := {
	"cabin": {400: "res://polices/Cabin-Regular.ttf", 600: "res://polices/Cabin-SemiBold.ttf",
		700: "res://polices/Cabin-Bold.ttf"},
}
var _nom_police := ""
## 🔲 HABILLAGE « VITRE », EN PLACE (auteur, 2026-10-02, après « trop IA, trop rempli ») :
## verre neutre à angles droits, liseré d'un pixel, sans ombre ; le temps en haut à droite.
## `-- --habillage bois` rend le brun et crème du 2026-09-28, `verre` le crème et vert d'avant.
## `_habiller()` écrase les couleurs ci-dessous.
var VITRE := true
var BOIS := false
const BOIS_CADRE := Color8(94, 62, 47)
const BOIS_LISERE := Color8(214, 192, 172)
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
## 🪙 L'argent est jaune orangé, partout où il se lit (auteur, 2026-10-18).
var ARGENT := Color8(206, 132, 16)
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
const EN_TRAVAUX := Color8(232, 170, 48)


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
var _theme_ui: Theme
## 📖 L'HISTOIRE PARLE EN SOMBRE, LES OUTILS RESTENT CLAIRS (auteur, 2026-10-14) : le
## récit, le guide des premiers pas et ses annonces, rien d'autre — sinon le sombre ne dit plus rien.
var _theme_histoire: Theme
var ENCRE_HISTOIRE := TEXTE
var GRIS_HISTOIRE := GRIS
var _fonte_grasse: FontVariation
var _police: Font
var _fonte_texte: FontVariation
var _icones := {}


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
	if not VITRE:
		ENCRE_HISTOIRE = TEXTE
		GRIS_HISTOIRE = GRIS


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
	ENCRE_HISTOIRE = f.encre_histoire
	GRIS_HISTOIRE = f.gris_histoire


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
	_nom_police = nom
	if POLICES_SYSTEME.has(nom):
		var sf := SystemFont.new()
		sf.font_names = PackedStringArray(POLICES_SYSTEME[nom])
		print("police %s → %s" % [nom, sf.get_font_name()])
		return sf
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
	if GRAISSES.has(_nom_police):
		var fichiers: Dictionary = GRAISSES[_nom_police]
		var proche: int = fichiers.keys()[0]
		for p in fichiers:
			if absi(p - poids) < absi(proche - poids):
				proche = p
		f.base_font = load(fichiers[proche])
	elif _police is SystemFont:
		var sf := (_police as SystemFont).duplicate() as SystemFont
		sf.font_weight = poids
		f.base_font = sf
	elif _police != null and not _police.get_supported_variation_list().is_empty():
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
const Ombre := preload("res://shaders/ombre.gdshader")


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
		# Le bord du verre : un pixel clair ; l'ombre passe sous le verre (`_vitrer`).
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
	var ombre: ColorRect
	var marge := 0.0
	# 🔄 L'ombre revient sous la vitre (auteur, 2026-10-14) : sans elle, un panneau
	# clair se perdait sur le papier blanc des diagnostics.
	if BOIS or (VITRE and _fiche.ombre.a > 0.0):
		ombre = ColorRect.new()
		ombre.name = "Ombre"
		ombre.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ombre.z_index = -2
		var taille: float = _fiche.ombre_taille if VITRE else 12.0
		var mo := ShaderMaterial.new()
		mo.shader = Ombre
		mo.set_shader_parameter("couleur", _fiche.ombre if VITRE else Color(0.25, 0.12, 0.05, 0.40))
		mo.set_shader_parameter("rayon", float(rayon))
		mo.set_shader_parameter("chute", maxf(taille / 3.0, 0.5))
		# Au-delà de cinq fois la chute du voile, l'ombre vaut moins d'un millième.
		marge = ceilf(taille * 5.0)
		mo.set_shader_parameter("marge", marge)
		ombre.material = mo
		p.add_child(ombre)
		p.move_child(ombre, 0)
	var suivre := func() -> void:
		fond.position = Vector2.ZERO
		fond.size = p.size
		mat.set_shader_parameter("taille", fond.size)
		if ombre != null:
			ombre.position = -Vector2(marge, marge)
			ombre.size = p.size + 2.0 * Vector2(marge, marge)
			ombre.material.set_shader_parameter("taille", p.size)
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


## Un panneau qui raconte : verre sombre, texte clair. Hors vitre, c'est un panneau comme les autres.
func _poser_histoire(p: Control) -> void:
	if not VITRE:
		_poser_boite(p)
		return
	p.theme = _theme_histoire
	var sb := _boite()
	sb.border_color = _fiche.lisere_histoire
	if not VERRE:
		sb.bg_color = Color(_fiche.verre_histoire, 1.0)
	p.add_theme_stylebox_override("panel", sb)
	_vitrer(p, _fiche.verre_histoire)


## Le thème des panneaux clairs, recoloré pour le sombre : mêmes marges, mêmes polices.
func _creer_theme_histoire() -> Theme:
	if not VITRE:
		return _theme_ui
	var t: Theme = _theme_ui.duplicate()
	var f := _fiche
	var couleurs := {
		"normal": [f.fond_bouton_histoire, f.bord_bouton_histoire],
		"hover": [f.survol_bouton_histoire, Color(f.encre_histoire, 0.6)],
		# Un choix posé s'inverse : plaque claire, encre sombre.
		"pressed": [f.encre_histoire, f.encre_histoire],
		"hover_pressed": [f.encre_histoire, f.encre_histoire],
		"disabled": [Color(f.fond_bouton_histoire, f.fond_bouton_histoire.a * 0.5),
			Color(f.bord_bouton_histoire, f.bord_bouton_histoire.a * 0.4)],
	}
	for etat in couleurs:
		var sb: StyleBoxFlat = t.get_stylebox(etat, "Button").duplicate()
		sb.bg_color = couleurs[etat][0]
		sb.border_color = couleurs[etat][1]
		t.set_stylebox(etat, "Button", sb)
	for c in ["font_color", "font_hover_color"]:
		t.set_color(c, "Button", f.encre_histoire)
	for c in ["font_pressed_color", "font_hover_pressed_color", "icon_pressed_color",
			"icon_hover_pressed_color"]:
		t.set_color(c, "Button", Color(f.verre_histoire, 1.0))
	t.set_color("font_disabled_color", "Button", Color(f.gris_histoire, 0.6))
	return t


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
	t.set_font_size("font_size", "Button", _taille(14))
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


## 🔴 QUATRE TAILLES, JAMAIS SOUS 14 (auteur, 2026-10-22) : toute taille demandée s'y range.
func _taille(t: int) -> int:
	return _fiche.taille_texte if t <= 14 else _fiche.taille_forte if t <= 16 		else _fiche.taille_bloc if t <= 18 else _fiche.taille_titre


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
	var l := _etiquette(txt, 18, TEXTE)
	parent.add_child(l)
	return l


## 🔴 LA TABLE DES DESSINS EST HORS DE `_icone` depuis le 2026-09-17 : les
## pastilles posées sur la ville (`pastilles.gd`) y puisent pour fabriquer leur
## propre image, contour compris. Deux tables finiraient par diverger.
## 🎨 L'APLAT DES ICÔNES D'OBJETS (auteur, 2026-10-19 : « le trait, plus une couleur ») :
## le dessin rempli dessous, le trait par-dessus. Les teintes sont celles des compteurs
## et des jauges ; les commandes (pause, croix, sauver…) restent en trait seul.
const TEINTES := {
	"ville": Color8(216, 147, 147), "dangers": Color8(198, 76, 66), "chantiers": Color8(232, 170, 48),
	"energie": Color8(214, 158, 44), "trafic": Color8(122, 112, 150), "nourriture": Color8(150, 128, 44),
	"sols": Color8(100, 196, 105), "mairie": Color8(176, 150, 110), "universite": Color8(70, 98, 150),
	"bibliotheque": Color8(70, 98, 150), "institut": Color8(70, 98, 150), "recherche": Color8(70, 98, 150),
	"caisse": Color8(78, 121, 67), "capital": Color8(122, 84, 48), "conso": Color8(198, 126, 32),
	"production": Color8(214, 158, 44), "achat": Color8(122, 112, 96), "co2": Color8(104, 116, 108),
	"adaptation": Color8(46, 122, 146), "reduction": Color8(88, 128, 60), "logement": Color8(196, 120, 96),
	"feuille": Color8(88, 128, 60), "eau": Color8(46, 122, 146), "camp": Color8(140, 123, 107),
	"personnes": Color8(196, 120, 96), "pont": Color8(150, 140, 120),
}


## 💶 Les monnaies : trait BLANC partout, aplat plein et une petite ombre (auteur, 2026-10-22).
const MONNAIES := ["caisse", "capital", "recherche"]
const OMBRE := "<g transform='translate(0.7 1.1)' opacity='0.4'>%s</g>"


## Le remplissage pastel, opaque : il se lit pareil sur le crème et sur la tuile enfoncée.
static func aplat(nom: String) -> String:
	if not TEINTES.has(nom):
		return ""
	var pastel: Color = (TEINTES[nom] as Color).lerp(Color.WHITE, 0.0 if nom in MONNAIES else 0.45)
	return "<g fill='#%s' stroke='none'>%s</g>" % [pastel.to_html(false), str(DESSINS[nom]).replace("@", "none")]


const DESSINS := {
	"ville": "<path d='M3 21h18M5 21V9h5v12M10 21V4h6v17M16 21v-9h4v9M7 12h1m-1 3h1m-1 3h1m5-11h1m-1 4h1m-1 4h1m4 0h1m-1 3h1'/>",
	"diagnostic": "<path d='M4 20h16M6 18v-6h3v6m3 0V6h3v12m3 0v-9h3v9'/>",
	"adaptation": "<path d='M12 3l7 3v5c0 5-3 8-7 10-4-2-7-5-7-10V6l7-3zM8 12c2-2 6-2 8 0m-8 3c2-2 6-2 8 0'/>",
	"reduction": "<path d='M20 4C10 4 5 9 5 15c0 3 2 5 5 5 7 0 10-8 10-16zM5 20c3-6 7-9 12-12'/>",
	"conso": "<path d='M13 2L5 14h6l-1 8 9-13h-6V2z'/>",
	"production": "<circle cx='12' cy='12' r='4'/><path d='M12 2v3m0 14v3M2 12h3m14 0h3M5 5l2 2m10 10l2 2M19 5l-2 2M7 17l-2 2'/>",
	"achat": "<path d='M9 3v7m6-7v7m-8 0h10v2a5 5 0 01-5 5v4m-3 0h6'/>",
	"co2": "<path d='M7 18h11a4 4 0 000-8 6 6 0 00-11-2 5 5 0 000 10z'/>",
	# 🌡️ Lucide « thermometer » : la saison et sa température (décision 92).
	"temperature": "<path d='M14 4v10.54a4 4 0 11-4 0V4a2 2 0 014 0z'/>",
	# 🗳️ Lucide « vote » : le capital politique.
	"capital": "<path d='M9 12l2 2 4-4'/><path d='M5 7c0-1.1.9-2 2-2h10a2 2 0 012 2v12H5V7z'/><path d='M22 19H2'/>",
	# ⭐ Lucide « star » : les points de recherche (113) — une étoile, pas une fiole (auteur, 2026-10-20).
	"recherche": "<path d='M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01z'/>",
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
	# 💧 Lucide « droplets » : la carte des sols (101).
	"sols": "<path d='M7 16.3c2.2 0 4-1.83 4-4.05 0-1.16-.57-2.26-1.71-3.19S7.29 6.75 7 5.3c-.29 1.45-1.14 2.84-2.29 3.76S3 11.1 3 12.25c0 2.22 1.8 4.05 4 4.05z'/><path d='M12.56 6.6A10.97 10.97 0 0014 3.02c.5 2.5 2 4.9 4 6.5s3 3.5 3 5.5a6.98 6.98 0 01-11.91 4.97'/>",
	# 🏛️🎓 Les deux lieux du rail (Lucide « landmark », « graduation-cap ») :
	# sans dessin, ils prenaient celui du diagnostic, deux fois.
	# GUIDE rouvre les premiers pas ; dessin de l'auteur dans `icones/guide.svg`, ce trait en secours.
	"guide":"<path d='M12 7v14M3 18a1 1 0 01-1-1V4a1 1 0 011-1h5a4 4 0 014 4 4 4 0 014-4h5a1 1 0 011 1v13a1 1 0 01-1 1h-6a3 3 0 00-3 3 3 3 0 00-3-3z'/>",
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
	# Lucide : pause, play, skip-back, save, folder-open, map, box.
	"pause": "<rect x='14' y='4' width='4' height='16' rx='1'/><rect x='6' y='4' width='4' height='16' rx='1'/>",
	"lecture": "<path fill='@' d='M6 3l14 9-14 9z'/>",
	"mois_zero": "<path d='M19 20L9 12l10-8zM5 19V5'/>",
	"sauver": "<path d='M15.2 3a2 2 0 011.4.6l3.8 3.8a2 2 0 01.6 1.4V19a2 2 0 01-2 2H5a2 2 0 01-2-2V5a2 2 0 012-2z'/><path d='M17 21v-7a1 1 0 00-1-1H8a1 1 0 00-1 1v7M7 3v4a1 1 0 001 1h7'/>",
	"ouvrir": "<path d='M6 14l1.5-2.9A2 2 0 019.24 10H20a2 2 0 011.94 2.5l-1.54 6a2 2 0 01-1.95 1.5H4a2 2 0 01-2-2V5a2 2 0 012-2h3.9a2 2 0 011.69.9l.81 1.2a2 2 0 001.67.9H18a2 2 0 012 2v2'/>",
	# L'aiguille : moitié nord pleine. `_icone(…, angle)` la tourne vers le nord.
	"boussole": "<path fill='@' d='M12 2l4.5 10h-9z'/><path d='M7.5 12L12 22l4.5-10'/>",
	# Lucide « settings-2 » : les réglages graphiques (`graphismes.gd`).
	"graphismes": "<path d='M20 7h-9M14 17H5'/><circle cx='17' cy='17' r='3'/><circle cx='7' cy='7' r='3'/>",
	"plan": "<path d='M14.1 5.55a2 2 0 001.8 0l3.65-1.83A1 1 0 0121 4.62v12.76a1 1 0 01-.55.9l-4.55 2.27a2 2 0 01-1.8 0L9.9 18.45a2 2 0 00-1.8 0l-3.65 1.83A1 1 0 013 19.38V6.62a1 1 0 01.55-.9l4.55-2.27a2 2 0 011.8 0zM15 5.76v15M9 3.24v15'/>",
	"cube": "<path d='M21 8a2 2 0 00-1-1.73l-7-4a2 2 0 00-2 0l-7 4A2 2 0 003 8v8a2 2 0 001 1.73l7 4a2 2 0 002 0l7-4A2 2 0 0021 16z'/><path d='M3.3 7L12 12l8.7-5M12 22V12'/>",
	"croix": "<path d='M18 6L6 18M6 6l12 12'/>",
	"camp": "<path d='M3.5 21L14 3M20.5 21L10 3M15.5 21L12 15l-3.5 6M2 21h20'/>",
	# 👥 Lucide « users » : des personnes, là où la tente se lisait mal (auteur, 2026-10-18).
	"personnes": "<path d='M16 21v-2a4 4 0 00-4-4H6a4 4 0 00-4 4v2'/><circle cx='9' cy='7' r='4'/><path d='M22 21v-2a4 4 0 00-3-3.87M16 3.13a4 4 0 010 7.75'/>",
}


func _icone(nom: String, taille := 25, coul := TEXTE, angle := 0) -> Texture2D:
	var cle := "%s_%d_%s_%d" % [nom, taille, coul.to_html(false), angle]
	if _icones.has(cle):
		return _icones[cle]
	# ✏️ Un dessin de l'auteur dans `res://icones/` passe avant la table, en ses couleurs.
	var dessin := _icone_dessinee(nom, taille)
	if dessin != null:
		_icones[cle] = dessin
		return dessin
	if nom in MONNAIES:
		coul = Color.WHITE
	# 🎨 `@` = LA COULEUR DU TRAIT : c'est ce qui permet un aplat (`fill='@'`)
	# dans une table qui est sinon tout en traits.
	var corps: String = aplat(nom) + str(DESSINS.get(nom, DESSINS["diagnostic"])) 		.replace("@", "#" + coul.to_html(false))
	if nom in MONNAIES:
		# La silhouette en noir, décalée dessous.
		corps = OMBRE % ("<g fill='#000' stroke='#000'>%s</g>" % str(DESSINS[nom]).replace("@", "#000")) + corps
	if angle != 0:
		corps = "<g transform='rotate(%d 12 12)'>%s</g>" % [angle, corps]
	return _rendre_icone(cle, corps, taille, coul)


## 🌡️ Le thermomètre se remplit avec la température : vide à 0 °C, plein à 22 °C,
## l'écart des normales de `calendrier.gd` : plus large, on ne voyait plus la différence ;
## le tube pâli, sinon son trait se confond avec la colonne à 22 px.
func _thermometre(celsius: float, taille: int, coul: Color) -> Texture2D:
	var degre := int(roundf(celsius))
	var cle := "thermometre_%d_%d_%s" % [degre, taille, coul.to_html(false)]
	if _icones.has(cle):
		return _icones[cle]
	var haut := lerpf(15.5, 5.0, clampf(degre / 22.0, 0.0, 1.0))
	var corps := "<g stroke-opacity='0.35'>%s</g>" % DESSINS["temperature"] + 		"<path stroke-width='2.4' d='M12 18V%.1f'/><circle cx='12' cy='18' r='1.8' fill='@'/>" % haut
	return _rendre_icone(cle, corps.replace("@", "#" + coul.to_html(false)), taille, coul)


static func _icone_dessinee(nom: String, taille: int) -> Texture2D:
	var svg := _svg_dessine(nom)
	return _vectorielle(svg, taille / _cote_svg(svg)) if svg != "" else null


## Les icônes dessinées par l'auteur (`res://icones/⟨nom⟩.svg`, gabarit `_gabarit.svg`) :
## la plus grande dimension du viewBox tient dans `taille`, le groupe « gabarit » est retiré.
## ⚠️ Lu en fichier brut : c'est `addons/icones_export` qui le glisse dans le jeu exporté.
static func image_dessinee(nom: String, taille: int) -> Image:
	var svg := _svg_dessine(nom)
	if svg == "":
		return null
	var img := Image.new()
	if img.load_svg_from_string(svg, taille / _cote_svg(svg)) != OK:
		return null
	return img


static func _svg_dessine(nom: String) -> String:
	var chemin := "res://icones/%s.svg" % nom
	if not FileAccess.file_exists(chemin):
		return ""
	var svg := _sans_gabarit(FileAccess.get_file_as_string(chemin))
	if nom in MONNAIES:
		svg = svg.replace("stroke:black", "stroke:white").replace("fill:black", "fill:white")
		# ⚠️ Un tracé sans style est rempli de noir par défaut : l'anneau de `caisse.svg`.
		svg = RegEx.create_from_string(r'<(path|rect|circle)\b((?:(?!style=)[^>])*?)/>') \
			.sub(svg, '<$1$2 style="fill:white;"/>', true)
	return _avec_lisere(svg, nom in MONNAIES)


## ⬜ LE LISERÉ BLANC autour des dessins de l'auteur, partout (auteur, 2026-10-20) : 4 % du dessin.
const LISERE := 0.04


## La silhouette recopiée dessous en blanc, décalée de `LISERE` dans 16 directions ; le viewBox
## s'élargit d'autant. 🔄 Elle était au trait épaissi : un groupe étiré (le cadre de `chantiers.svg`,
## ×16 en largeur) étirait le trait en grand rectangle (auteur, 2026-10-21). Vectoriel, pour rester
## net en DPITexture. ⚠️ Les `<use>` (ombres en image) ne se recopient pas.
static func _avec_lisere(svg: String, ombre := false) -> String:
	var vb := RegEx.create_from_string(r'viewBox="([-\d.]+) ([-\d.]+) ([\d.]+) ([\d.]+)"').search(svg)
	var ouvre := svg.find(">", svg.find("<svg")) + 1
	var fin := svg.find("<defs")
	fin = fin if fin >= 0 else svg.rfind("</svg>")
	if vb == null or ouvre <= 0 or fin < ouvre:
		return svg
	var x := float(vb.get_string(1))
	var y := float(vb.get_string(2))
	var w := float(vb.get_string(3))
	var h := float(vb.get_string(4))
	var m := maxf(w, h) * LISERE
	var copie := RegEx.create_from_string(r'<use[^>]*/>').sub(svg.substr(ouvre, fin - ouvre), "", true)
	copie = RegEx.create_from_string(r'<(path|rect|circle)\b((?:(?!style=)[^>])*?)/>') \
		.sub(copie, '<$1$2 style=""/>', true)
	var morceaux := ""
	var depuis := 0
	var couleur := RegEx.create_from_string(r'\b(fill|stroke):(?!none)[^;]*')
	var opacite := RegEx.create_from_string(r'(fill-|stroke-)?opacity:[^;]*;?')
	for s in RegEx.create_from_string(r'style="([^"]*)"').search_all(copie):
		var style := s.get_string(1)
		# Invisible dans le dessin, invisible dans le liseré.
		var cache := RegEx.create_from_string(r'fill-opacity:0(\.0*)?(;|$)').search(style) != null
		style = opacite.sub(couleur.sub(style, "$1:white", true), "", true)
		if cache:
			style = "fill:none;" + style
		elif not style.contains("fill:"):
			style = "fill:white;" + style
		morceaux += copie.substr(depuis, s.get_start() - depuis) + 'style="%s"' % style
		depuis = s.get_end()
	copie = morceaux + copie.substr(depuis)
	var halo := copie
	for i in 16:
		var a := TAU * i / 16.0
		halo += '<g transform="translate(%.3f %.3f)">%s</g>' % [cos(a) * m, sin(a) * m, copie]
	if ombre:
		# 💶 Une monnaie : son trait est déjà blanc, la silhouette noire décalée fait l'ombre.
		halo = '<g transform="translate(%.3f %.3f)" opacity="0.4">%s</g>' % [m * 0.6, m, copie.replace("white", "black")]
	copie = halo
	var cadre := 'viewBox="%.2f %.2f %.2f %.2f"' % [x - m, y - m, w + 2.0 * m, h + 2.0 * m]
	var tete := svg.substr(0, ouvre).replace(vb.get_string(0), cadre)
	tete = RegEx.create_from_string(r'(<svg[^>]*?) width="[^"]*" height="[^"]*"') \
		.sub(tete, '$1 width="%.0f" height="%.0f"' % [w + 2.0 * m, h + 2.0 * m])
	return tete + copie + svg.substr(ouvre)


static func _cote_svg(svg: String) -> float:
	var vb := RegEx.create_from_string("viewBox=\"[-\\d.]+ [-\\d.]+ ([\\d.]+) ([\\d.]+)\"").search(svg)
	return maxf(float(vb.get_string(1)), float(vb.get_string(2))) if vb else 24.0


## 🔍 DPITexture, pas ImageTexture : Godot la repixellise au grossissement réel de la
## fenêtre (stretch `canvas_items`, Retina) ; une image figée à 1600 × 900 s'étirait floue.
static func _vectorielle(svg: String, echelle: float) -> Texture2D:
	var texture := DPITexture.create_from_string(svg, echelle)
	return texture if texture.get_width() > 0 else null


## Le groupe « gabarit » retiré en entier, groupes imbriqués compris (Illustrator en ajoute).
static func _sans_gabarit(svg: String) -> String:
	var debut := svg.find("<g id=\"gabarit\"")
	if debut < 0:
		return svg
	var i := debut
	var niveau := 0
	while i < svg.length():
		var ouvre := svg.find("<g", i + 1)
		var ferme := svg.find("</g>", i + 1)
		if ferme < 0:
			return svg
		if ouvre >= 0 and ouvre < ferme:
			niveau += 1
			i = ouvre
		elif niveau > 0:
			niveau -= 1
			i = ferme
		else:
			return svg.substr(0, debut) + svg.substr(ferme + 4)
	return svg


static func est_dessinee(nom: String) -> bool:
	return FileAccess.file_exists("res://icones/%s.svg" % nom)


func _rendre_icone(cle: String, corps: String, taille: int, coul: Color) -> Texture2D:
	var svg := "<svg xmlns='http://www.w3.org/2000/svg' width='24' height='24' viewBox='0 0 24 24' fill='none' stroke='#%s' stroke-width='2.0' stroke-linecap='round' stroke-linejoin='round'>%s</svg>" % [coul.to_html(false), corps]
	var texture := _vectorielle(svg, taille / 24.0)
	if texture == null:
		return null
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
	b.custom_minimum_size = Vector2(0, 40)


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
	l.add_theme_font_size_override("font_size", _taille(taille))
	l.add_theme_color_override("font_color", coul)
	return l


## 💶 LE CODE DES CLICS (auteur, 2026-10-20) : bleu = ça coûte, et le prix est dessus
## (`_poser_bouton_verbe`) ; encre pleine = gratuit (`_habiller_gratuit`). Angles droits. Pas de bleu sur un clic gratuit.
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
		plein.bg_color = _fiche.fond_engage
		survol.bg_color = _fiche.survol_engage
		presse.bg_color = _fiche.appuye_engage
		eteint.bg_color = _fiche.eteint_engage
		encre_eteinte = _fiche.encre_eteint_engage
	b.add_theme_stylebox_override("normal", plein)
	b.add_theme_stylebox_override("hover", survol)
	b.add_theme_stylebox_override("pressed", presse)
	b.add_theme_stylebox_override("disabled", eteint)
	b.add_theme_color_override("font_disabled_color", encre_eteinte)
	b.add_theme_color_override("icon_disabled_color", encre_eteinte)
	b.add_theme_font_size_override("font_size", _taille(taille))
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)


## Le clic gratuit qui compte : plein d'encre ; sur le verre sombre de l'histoire, plein de blanc.
func _habiller_gratuit(b: Button, sur_sombre := false) -> void:
	var fond: Color = Color8(244, 245, 243) if sur_sombre else TEXTE
	var encre: Color = TEXTE if sur_sombre else Color.WHITE
	var plein := StyleBoxFlat.new()
	plein.bg_color = fond
	plein.set_content_margin_all(11)
	var survol := plein.duplicate() as StyleBoxFlat
	survol.bg_color = fond.lerp(Color.BLACK if sur_sombre else Color.WHITE, 0.16)
	var presse := plein.duplicate() as StyleBoxFlat
	presse.bg_color = fond.lerp(Color.BLACK, 0.2)
	var eteint := plein.duplicate() as StyleBoxFlat
	eteint.bg_color = Color(fond, 0.22)
	b.add_theme_stylebox_override("normal", plein)
	b.add_theme_stylebox_override("hover", survol)
	b.add_theme_stylebox_override("pressed", presse)
	b.add_theme_stylebox_override("disabled", eteint)
	b.add_theme_color_override("font_disabled_color", Color(encre if sur_sombre else fond, 0.55))
	b.add_theme_color_override("icon_disabled_color", Color(encre if sur_sombre else fond, 0.55))
	b.add_theme_font_size_override("font_size", _taille(15))
	for etat in ["font_color", "font_hover_color", "font_pressed_color", "icon_normal_color",
			"icon_hover_color", "icon_pressed_color"]:
		b.add_theme_color_override(etat, encre)


## 💶 Les trois monnaies, la teinte de leur compteur en haut de l'écran.
func _teinte_monnaie(m: String) -> Color:
	match m:
		"capital": return Color8(122, 84, 48)
		"recherche": return Color8(70, 98, 150)
	return ARGENT


## Une ligne du détail : [texte, valeur affichée, signe, gras]. Valeur nulle = titre de bloc.
static func _ligne_ke(txt: String, ke: float) -> Array:
	return [txt, ("+" if ke >= 0.0 else "−") + _milliers(absf(ke)) + " k€", signf(ke), false]


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


static func _sens(x: float) -> int:
	return 1 if x > 0.0 else -1


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
