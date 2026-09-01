extends Node3D
# Wehrau — l'orchestrateur.
#
# Le prototype énergie tient en un seul geste : cliquer un îlot et augmenter sa
# part de panneaux. Budget et capital restent hors du test.
#
# Tout est construit en code : la scène ne contient qu'un nœud et ce script
# (`Génération procédurale.md:47`).
#
# CLAVIER
#   clic   sélectionner un îlot ou une rue
#                                V B R I G   les cinq points de vue
#   Q / E  quart de tour            P        capture PNG
#   ← → ↑ ↓  orienter la caméra     T        vue de dessus
#   F3     afficher / masquer les performances
#   Échap  quitter
#
# 🩶 Les deux vues — la ville vivante et le diagnostic — se prennent au MENU,
# pas au clavier : voir THEMES plus bas.
#
# 🔄 Caméra libre depuis le 2026-08-17 (clic droit glissé) : le déplacement est
# passé au clic milieu. Voir `camera_axo.gd` pour ce que ça coûte.
# 🔄 Les touches 1..4 exagéraient le relief ; la carte est plate depuis le
# 2026-08-12.
#
# ⚠️ Les 6 îlots de rivière ne sont pas cliquables : fusionnés dans le maillage
# d'eau, avec son matériau. La BERGE, elle, est un objet depuis le 2026-08-26 —
# 8 morceaux, un par rive et par bief, couche "b".

const Donnees := preload("res://scripts/donnees.gd")
const Constructeur := preload("res://scripts/constructeur.gd")
const Materiaux := preload("res://scripts/materiaux.gd")
const CameraAxo := preload("res://scripts/camera_axo.gd")
const Ville := preload("res://scripts/ville.gd")
const Selection := preload("res://scripts/selection.gd")
const Interface := preload("res://scripts/interface.gd")
const MoniteurPerformances := preload("res://scripts/moniteur_performances.gd")
const Trafic := preload("res://scripts/trafic.gd")
const Apercu := preload("res://scripts/apercu.gd")
const Echantillon := preload("res://scripts/echantillon.gd")

const RENDUS := "res://../QGIS/rendus/"

# 🔄 2026-08-17 : le temps allait 60× trop vite (une seconde = un mois à ×1),
# et une pose passait avant qu'on ait relâché la souris. UNE MINUTE POUR UN
# MOIS, donc ×12 fait un an par minute et l'horizon vingt minutes.
const MOIS_PAR_SECONDE := 1.0 / 60.0

# La même rampe que `06_etat_zero.py` et `parties.html` : un calque se lit
# pareil dans les trois outils.
const RAMPE := [
	Color8(42, 74, 110), Color8(90, 140, 150),
	Color8(214, 190, 110), Color8(196, 84, 62),
]
# Des facteurs, pas des couleurs : assez forts pour se voir sur un pastel
# clair, assez faibles pour ne pas le brûler.
const SURVOL := Color(1.15, 1.15, 1.08)
# 🔄 Moins jaune depuis le 2026-08-18 : sur un enduit gris neutre l'ancien
# 1,42/1,38/1,06 virait à l'olive, et l'îlot avait l'air d'un autre matériau
# au lieu d'avoir l'air éclairé.
## 🌊 LES TROIS CRANS D'UNE BERGE, et l'asphalte n'en porte aucune : à l'état de
## départ le mur de quai garde le minéral que 07 lui a donné. Une teinte de plus
## aurait fait croire à une quatrième chose à faire.
const BERGE_TEINTES := [Color(1.0, 1.0, 1.0, 0.0),
	Color8(214, 198, 168, 235), Color8(126, 158, 96, 255)]
const CHOISI := Color(1.34, 1.32, 1.16)

# ✏️ LE TRAIT AUTOUR DE L'OBJET CHOISI — 2026-08-18. L'éclaircissement seul ne
# suffit pas : sur un îlot clair, ou sous un calque, « plus lumineux » ne se
# distingue pas d'une variation de matériau.
#
# 🔄 RETOUR EN ARRIÈRE SIGNALÉ, le même jour : c'était un ruban posé au sol
# (`Constructeur.contour`, disparu) qui n'entourait que l'emprise, donc les
# bâtiments dépassaient. Le trait vient maintenant de la SILHOUETTE RENDUE,
# sous l'angle où on regarde — voir `_batir_contour`.
#
# 🔄 Corrigé le soir même : la silhouette seule laissait le trait TROUÉ (un
# îlot bâti ne dessine pas son sol). Le masque a DEUX pièces, la silhouette et
# l'emprise exportée par 07 ; le trait suit leur union.
#
# L'épaisseur est en PIXELS et le reste : le trait vit dans l'image.
const CONTOUR_PX := 3.0
# Légèrement jaune, comme l'éclaircissement (2026-08-18) : un blanc pur à côté
# d'un îlot réchauffé se lisait comme deux retours pour une seule sélection.
const CONTOUR_COULEUR := Color(1.0, 0.95, 0.66)

var donnees: Dictionary
var monde: Node3D
var pivot: CameraAxo
var ville: Ville
var selection: Selection
var interface: Interface
var moniteur_performances: MoniteurPerformances
var trafic: Trafic
var horloge_trafic: Timer
var mat_objet: ShaderMaterial
var masque: SubViewport
var cam_masque: Camera3D
var maille_masque: MeshInstance3D
var maille_emprise: MeshInstance3D
var rect_contour: ColorRect
var _contour_fid := -1
var _contour_couche := ""
var apercu: Apercu
var _apercu_fid := -1
var _apercu_couche := ""
var _apercu_voitures := ""
var _couloirs := {}
var _plaques := {}
var _berges_contour := {}
var _diagnostic_marqueurs: Node3D

var noeuds := {"i": {}, "r": {}, "b": {}}
## L'épaisseur de la dalle de la miniature, en mètres. Assez pour se voir dans
## une fenêtre de 35 m, assez peu pour ne pas faire un gâteau sous un îlot.
const EPAISSEUR_SOCLE := 1.6
var _socles := {}
# 🔧 LA VILLE RÉPARÉE, cachée au chargement. Un nœud par îlot ruiné et par
# tronçon abîmé ; il apparaît quand le chantier payé arrive à son terme. C'est
# la seule géométrie qui se montre en cours de partie — elle est CALCULÉE par
# 07 comme tout le reste, Godot ne fabrique rien.
var reparations := {"i": {}, "r": {}, "b": {}}
# 🅿️ Les files de stationnement peintes, un nœud par tronçon : elles se cachent
# quand la rue n'a plus de places (fid de tronçon -> MeshInstance3D).
var places_rue := {}
# 🌳 LES ARBRES SE REBÂTISSENT quand la canopée bouge. Le semis des îlots est
# figé ; les emplacements d'alignement portent leur tronçon et leur seuil, et
# `_montrer_arbres` refait les deux MultiMesh quand le compte visible change.
# ⚠️ Refait, pas mis à jour : un MultiMesh ne se réordonne pas, et 1 700 arbres
# se reconstruisent en moins d'une image. Le compte sert de garde-fou.
var _arbres_semis := []
var _arbres_slots := []      # [x, y, z, échelle, lacet, fid tronçon, seuil]
var _arbres_noeuds := {}     # essence -> MultiMeshInstance3D
var _arbres_compte := -1
var mois := 0.0
var vitesse := 1.0
var _derniere_vitesse := 1.0
# Dérivés du thème actif par `_sur_theme` — jamais réglés ailleurs.
var calque_couche := ""
var calque_champ := ""
var _etendue := [0.0, 1.0]
var _dernier_peint := -1.0


func _ready() -> void:
	donnees = Donnees.charger()
	if donnees.is_empty():
		get_tree().quit(1)
		return

	ville = Ville.new()
	ville.charger(donnees)
	# 🪟 Des DONNÉES, pas d'une constante recopiée : c'est ce qui aligne les
	# rangées de fenêtres sur les planchers que 07 a empilés.
	mat_objet = Materiaux.objet(float(donnees["meta"]["etage_m"]))
	monde = Node3D.new()
	monde.name = "Monde"
	add_child(monde)
	_construire()
	trafic = Trafic.new()
	trafic.name = "Trafic"
	monde.add_child(trafic)
	trafic.batir(donnees, ville)
	_batir_marqueurs_crue()
	_decor()

	pivot = CameraAxo.new()
	pivot.name = "Pivot"
	add_child(pivot)
	_repere("ville")
	trafic.regler_detail(pivot.taille)

	selection = Selection.new()
	selection.name = "Selection"
	selection.camera = pivot.camera
	selection.survole.connect(_sur_survol)
	selection.choisi.connect(_sur_choix)
	add_child(selection)

	# 🔎 Avant l'interface : c'est sa TEXTURE que la fiche affiche.
	apercu = Apercu.new()
	apercu.name = "Apercu"
	add_child(apercu)
	apercu.batir(mat_objet, donnees["palette"])

	interface = Interface.new()
	interface.name = "Interface"
	interface.ville = ville
	interface.trafic = trafic
	interface.apercu = apercu.get_texture()
	# Passées plutôt que preloadées : `interface.gd` importerait `maquette.gd`,
	# qui l'importe déjà.
	interface.themes = THEMES
	interface.rampe = RAMPE
	add_child(interface)
	interface.batir()
	interface.commande_demandee.connect(_sur_commande)
	interface.vitesse_demandee.connect(_sur_vitesse)
	interface.temps_remis.connect(_sur_reset)
	interface.theme_demande.connect(_sur_theme)
	pivot.vue_changee.connect(interface.maj_camera)
	pivot.vue_changee.connect(_sur_vue_changee)
	interface.maj_camera(pivot.lacet, pivot.hauteur)
	horloge_trafic = Timer.new()
	horloge_trafic.wait_time = 0.25
	horloge_trafic.autostart = true
	horloge_trafic.timeout.connect(_sur_pulsation_trafic)
	add_child(horloge_trafic)

	moniteur_performances = MoniteurPerformances.new()
	moniteur_performances.name = "MoniteurPerformances"
	add_child(moniteur_performances)
	# Les captures jugent la ville, pas l'ordinateur qui les prend.
	moniteur_performances.batir(not ("--essai" in OS.get_cmdline_user_args()
		or "--interface" in OS.get_cmdline_user_args()))

	_batir_contour()

	var c: Dictionary = donnees["controles"]
	print("Wehrau — %d îlots, %d tronçons, %d cliquables, %d triangles"
		% [int(c["ilots"]), int(c["routes"]),
		noeuds["i"].size() + noeuds["r"].size() + noeuds["b"].size(),
		int(c["triangles"])])
	_rafraichir(true)

	if "--interface" in OS.get_cmdline_user_args():
		await _essai_interface()
	elif "--banc" in OS.get_cmdline_user_args():
		await _banc()
	elif "--essai" in OS.get_cmdline_user_args():
		await _essai()


## Des images rapides pour juger l'interface sans rejouer toute la partie : la
## fiche entière, puis la MINIATURE SEULE — à 296 px dans une capture d'écran,
## son cadrage ne se juge pas.
func _essai_interface() -> void:
	vitesse = 0.0
	_viser_route(55, 90.0)
	pivot.caler(35.0, 28.0)
	await _fiche("r", 55)
	await _capturer("interface_rue")
	await _capturer_apercu("apercu_rue")
	_sur_theme("trafic")
	await get_tree().process_frame
	await _capturer("interface_diagnostic")
	_sur_theme("")
	# Les trois formes que la miniature doit tenir : une rue, un îlot bâti, une
	# berge. Même cadrage voulu, trois objets aux proportions incomparables.
	_viser_objet("i", 49, 150.0)
	await _fiche("i", 49)
	await _capturer("interface_ilot")
	await _capturer_apercu("apercu_ilot")
	_viser_objet("b", 6, 260.0)
	await _fiche("b", 6)
	await _capturer("interface_berge")
	await _capturer_apercu("apercu_berge")
	# 🌊 LES DEUX TYPES DE RIVE, et c'est un contrôle : la 4 n'a pas un mètre de
	# mur, son échantillon doit sortir en talus d'herbe, sans voie ni parapet.
	_viser_objet("b", 4, 260.0)
	await _fiche("b", 4)
	await _capturer_apercu("apercu_berge_talus")
	# 🌿 LES DEUX CURSEURS SE PARTAGENT UN 100 %, et ça se prouve PAR LE DOIGT,
	# pas par le noyau : l'îlot compact est plat de bout en bout, on demande
	# 70 % de panneaux puis 60 % de sédum — le second se rabote à 30.
	_viser_objet("i", 49, 150.0)
	await _fiche("i", 49)
	interface.viser(70.0)
	interface.viser_vert(60.0)
	await _fiche("i", 49)
	var d49: Dictionary = interface.apercu_demande()
	print("  îlot 49 · 70 % de panneaux puis 60 % de sédum demandés : le toit"
		+ " en accepte %.0f %%  %s" % [float(d49["verdi"]) * 100.0,
		"✅" if absf(float(d49["verdi"]) - 0.30) < 0.011 else "❌"])
	await _capturer("interface_toit_partage")
	await _capturer_apercu("apercu_toit_partage")
	# 🎚️ LES RÉGLAGES POSÉS, ET L'AVANT/APRÈS (2026-08-31). Trois captures au
	# MÊME cadrage : la fiche réglée, puis la miniature dans ses deux états.
	# C'est le critère du geste — si les deux images se ressemblent, il n'y a
	# rien à comparer et la fiche ment.
	_viser_route(55, 90.0)
	pivot.caler(35.0, 28.0)
	await _fiche("r", 55)
	interface.poser("places")
	interface.viser_arbres(100.0)
	await _fiche("r", 55)
	await _capturer("interface_reglages")
	await _capturer_apercu("apercu_rue_apres")
	interface.regarder_avant(true)
	await _fiche("r", 55)
	await _capturer_apercu("apercu_rue_avant")
	interface.regarder_avant(false)

	# 🔴 LE CONTRÔLE DE LA COMMANDE : deux réglages partent ENSEMBLE, la caisse
	# tombe exactement du total annoncé, et l'objet n'a qu'UN chantier.
	var av := ville.caisse_ke(0.0)
	var reglages := {"places": true,
		"arbres": Ville.PLANTATION_CANOPEE_MAX}
	var total := ville.cout_commande_ke("r", 55, reglages, 0.0)
	var r := ville.commander("r", 55, reglages, 0.0)
	var chantier := ville.chantier("r", 55, 0.0)
	print("  rue 55 · %d arbres + places : %.0f k€ annoncés, caisse %.0f → %.0f  %s"
		% [ville.arbres_plantables(55) - ville.arbres_a(55,
			ville.base("r", 55, "canopee")), total, av, ville.caisse_ke(0.0),
		"✅" if absf(av - ville.caisse_ke(0.0) - total) < 0.01 else "❌"])
	print("  un seul chantier · %s, encore %.1f mois  %s"
		% [chantier["quoi"], chantier["reste_mois"],
		"✅" if bool(chantier["actif"]) and (r["faits"] as Array).size() == 2
			else "❌ %s" % str(r["faits"])])
	_sur_reset()

	# 🎚️ LE REPÈRE DE LEVEL DESIGN DE LA PLANTATION : ce que TOUTE la ville
	# plantée coûterait et épargnerait. C'est ce rapport-là, et pas le prix d'une
	# rue, qui dit si planter est une décision ou une décoration.
	var fentes := 0
	var t0 := 0
	var plantables := 0
	for f in ville.routes:
		var tous := ville.arbres_plantables(f)
		fentes += tous
		t0 += ville.arbres_a(f, ville.base("r", f, "canopee"))
		if tous > 0:
			plantables += 1
	var neufs := fentes - t0
	var mwh := float(neufs) * Ville.PLANTATION_MWH_ARBRE_AN
	var conso: float = ville.indicateurs(0.0)["conso_mwh"]
	print("\nPLANTATION — le repère de level design")
	print("  %d emplacements sur %d tronçons plantables, %d arbres en terre au mois 0"
		% [fentes, plantables, t0])
	print("  tout planter : %d arbres · %.0f k€ · %.0f mois"
		% [neufs, float(neufs) * Ville.PLANTATION_PRIX_KE_ARBRE,
		Ville.PLANTATION_MOIS])
	print("  et cela épargnerait %.0f MWh/an sur %.0f — soit %.2f %% de la ville"
		% [mwh, conso, 100.0 * mwh / maxf(conso, 1.0)])

	# 🔧 LA BARRE DE CHANTIER ne se voit qu'en travaux : on en engage un et on se
	# place à mi-parcours. La berge 6 met 6 mois à devenir un quai apaisé.
	ville.transformer_berge(6, Ville.BERGE_APAISEE, 0.0)
	mois = 3.0
	await _fiche("b", 6)
	await _capturer("interface_chantier")
	get_tree().quit()


## Ouvre la fiche ET pose la sélection : sans elle, la capture n'a pas le trait.
func _fiche(couche: String, fid: int) -> void:
	selection.sel_couche = couche
	selection.sel_fid = fid
	interface.montrer(couche, fid, false)
	_rafraichir(true)
	await get_tree().process_frame
	await get_tree().process_frame


## Une passe sans souris, pour juger sur des captures plutôt que de mémoire.
##
## 🔄 C'était le CONTRÔLE DE RECOUPEMENT avec `08_jouer.py` avant le
## 2026-08-12 ; il est parti avec D07 dans `Godot/archive/essai_d07.gd.txt`.
## Ce qui reste regarde la ville et vérifie qu'elle est cliquable.
##
##   Godot_console.exe --path Godot -- --essai
## 📊 LE BANC — ce que coûte une image, et OÙ part le temps. Trois cadrages
## qui n'ont pas la même charge, la pulsation du trafic mesurée à part, et le
## verrou d'écran levé : sous vsync tout tient 60 ips et rien ne se voit.
##   Godot --path Godot -- --banc
const BANC_IMAGES := 180


func _banc() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	# 🔴 Un banc doit se rejouer à l'identique : la molette de la souris qui
	# traîne au-dessus de la fenêtre changeait le cadrage en cours de mesure.
	pivot.set_process_unhandled_input(false)
	print("\n--- BANC · %s · %s ---" % [
		RenderingServer.get_video_adapter_name(),
		str(DisplayServer.window_get_size())])

	var vues := [
		["ville entière (trafic éteint)", 0], ["l'axe 55, de près", 55],
		["le cœur ancien", -1], ["la place-parking", -2],
	]
	for v in vues:
		var quoi: int = v[1]
		if quoi == 0:
			_repere("ville")
		elif quoi == -1:
			_repere("compact")
		elif quoi == -2:
			_repere("place")
		else:
			_viser_route(quoi, 90.0)
			pivot.caler(35.0, 28.0)
		_rafraichir(true)
		for i in 10:
			await get_tree().process_frame
		var t0 := Time.get_ticks_usec()
		for i in BANC_IMAGES:
			await get_tree().process_frame
		var ms := float(Time.get_ticks_usec() - t0) / 1000.0 / float(BANC_IMAGES)
		print(("  %-30s %5.1f m de cadrage · %6.2f ms/image (%3d ips)"
			+ " · %d appels · %d triangles") % [v[0], pivot.taille, ms,
			roundi(1000.0 / maxf(ms, 0.001)),
			int(Performance.get_monitor(
				Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			int(Performance.get_monitor(
				Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))])

	# Le trafic est mesuré de PRÈS : de loin ses familles sont éteintes et la
	# pulsation sort tout de suite — on mesurerait zéro.
	_viser_route(55, 90.0)
	pivot.caler(35.0, 28.0)
	await get_tree().process_frame
	print("\n  la pulsation du trafic, en microsecondes par passage (4/s) :")
	var b: Dictionary = trafic.banc(mois, 20)
	for cle in b:
		print("    %-26s %8.0f µs" % [cle, float(b[cle])])

	# Ce que coûte une image HORS trafic, part par part. C'est `_process` qui
	# paie ça, donc à l'image et non 4×/s : ce tableau est le vrai budget.
	print("\n  ce que coûte une image, en microsecondes :")
	for m in [["le contour de l'objet choisi", _maj_contour],
			["la miniature de la fiche", _maj_apercu],
			["les réparations livrées", _montrer_reparations],
			["les arbres plantés", _montrer_arbres],
			["repeindre les objets", _peindre]]:
		var t2 := Time.get_ticks_usec()
		for i in 20:
			(m[1] as Callable).call()
		print("    %-26s %8.0f µs" % [m[0],
			float(Time.get_ticks_usec() - t2) / 20.0])
	var t3 := Time.get_ticks_usec()
	for i in 20:
		ville.indicateurs(mois)
	print("    %-26s %8.0f µs" % ["  les indicateurs de ville",
		float(Time.get_ticks_usec() - t3) / 20.0])
	t3 = Time.get_ticks_usec()
	for i in 20:
		ville.degats(mois)
	print("    %-26s %8.0f µs" % ["  les dégâts de la crue",
		float(Time.get_ticks_usec() - t3) / 20.0])
	var indic := ville.indicateurs(mois)
	t3 = Time.get_ticks_usec()
	for i in 20:
		interface.maj(indic, mois, vitesse)
	print("    %-26s %8.0f µs" % ["le bandeau et la fiche",
		float(Time.get_ticks_usec() - t3) / 20.0])
	var t1 := Time.get_ticks_usec()
	for i in 20:
		_rafraichir(true)
	print("    %-26s %8.0f µs" % ["— l'image entière",
		float(Time.get_ticks_usec() - t1) / 20.0])
	print("--- fin du banc ---\n")
	get_tree().quit(0)


func _essai() -> void:
	# Des mois reproductibles, quelle que soit la vitesse de la machine.
	# `mois` AUSSI : l'horloge tourne pendant le chargement, et deux passes de
	# la même version tombaient sur 417 puis 508 logements perdus « au mois 0 ».
	vitesse = 0.0
	mois = 0.0
	print("
ESSAI — la ville, sans décision")
	var routes_endommagees := 0
	for fid in ville.routes:
		if ville.route_praticable(fid, 0.0):
			continue
		routes_endommagees += 1
		var voitures: Array = trafic.voitures_visibles_sur(fid)
		if voitures != [0, 0]:
			push_error("rue endommagée %d : %d voiture(s) roulante(s), %d garée(s)" \
				% [fid, voitures[0], voitures[1]])
			get_tree().quit(1)
			return
		var doux: Array = trafic.doux_visibles_sur(fid)
		if doux != [0, 0]:
			push_error("rue endommagée %d : %d piéton(s), %d cycliste(s)" \
				% [fid, doux[0], doux[1]])
			get_tree().quit(1)
			return
	print("  %d routes endommagées sans aucune voiture ni usager ✅"
		% routes_endommagees)
	_repere("ville")
	pivot.caler(30.0, 32.0)
	await get_tree().process_frame
	await _capturer("essai_ville")

	# Le contrôle de la caméra ouverte (2026-08-17) : à 10° une SILHOUETTE, à
	# 90° un plan où le grain du parcellaire se lit.
	# 🔄 Les façades ne sont plus nues depuis le 2026-08-18, mais à 10° les
	# fenêtres sont sous le pixel : c'est `essai_facades` qui juge le percement.
	pivot.caler(210.0, 10.0)
	await get_tree().process_frame
	await _capturer("essai_silhouette")
	pivot.caler(30.0, 90.0)
	await get_tree().process_frame
	await _capturer("essai_dessus")
	pivot.caler(30.0, 32.0)

	# Le critère de l'étape 5 : deux rues, sans calque et assez près pour lire
	# l'espacement, la vitesse et le stationnement.
	_viser_route(55, 90.0)
	pivot.caler(35.0, 28.0)
	interface.montrer("r", 55, false)
	await get_tree().process_frame
	await _capturer("essai_axe")
	# 🔄 LE MÊME CADRAGE DEUX SECONDES PLUS TARD, et rien d'autre n'a bougé :
	# c'est la seule image qui montre qu'une voiture PASSE le carrefour au lieu
	# de revenir au début de son segment.
	await _laisser_rouler(2.0)
	await _capturer("essai_axe_2s")
	var doux_charge: Array = trafic.doux_visibles_sur(55)
	print("  axe 55 à charge %.2f : %d piétons et %d cyclistes visibles"
		% [ville.valeur("r", 55, "charge", mois), doux_charge[0], doux_charge[1]])
	var calme := _route_calme()
	# 45 m et non 70 : à 70 la bordure vidée ne pesait que 8 % de l'image et
	# l'avant/après du stationnement ne se voyait pas (mesuré le 2026-08-25).
	_viser_route(calme, 45.0)
	interface.montrer("r", calme, false)
	await get_tree().process_frame
	await _capturer("essai_rue_calme")
	ville.supprimer_stationnement(calme, 0.0)
	mois = 2.1
	trafic.avancer(mois)
	await get_tree().process_frame
	await _capturer("essai_stationnement_retire")
	_sur_reset()
	# La charge VUE à l'écran, pas `base` : au chargement l'affectation reporte
	# déjà les 37 rues coupées, et 55 y monte à 1,00 quand la source dit 0,88.
	var charge_avant := ville.valeur("r", 55, "charge", mois)
	var total_avant := 0.0
	for f in ville.routes:
		total_avant += float(ville.valeur("r", f, "charge", mois))
	trafic.retirer_axe(55, 0.0)
	trafic.avancer(0.0)
	var fermees: Array = trafic.voitures_visibles_sur(55)
	if int(fermees[0]) != 0:
		push_error("axe 55 fermé mais %d voiture(s) y roulent encore" % fermees[0])
		get_tree().quit(1)
		return
	print("  fermeture de l'axe 55 visible dès le clic ✅")
	_viser_route(55, 90.0)
	pivot.caler(35.0, 28.0)
	interface.montrer("r", 55, false)
	await get_tree().process_frame
	await _capturer("essai_axe_ferme")
	mois = 6.1
	trafic.avancer(mois)
	# 🚶🚲 Ce que la fermeture LIVRE, au même cadrage que `essai_axe` : la
	# charge est retombée, donc la foule est revenue. C'est là que se juge si
	# les usagers doux disent quelque chose ou décorent.
	await get_tree().process_frame
	await _capturer("essai_axe_rendu")
	var doux_55: Array = trafic.doux_visibles_sur(55)
	print("  axe 55 rendu : %d piétons et %d cyclistes visibles ✅"
		% [doux_55[0], doux_55[1]])
	var ville_repere: Dictionary = donnees["reperes"]["ville"]
	var centre: Array = ville_repere["cible"]
	pivot.viser(Vector2(float(centre[0]), float(centre[1])), 650.0)
	pivot.caler(30.0, 32.0)
	await get_tree().process_frame
	await _capturer("essai_report_trafic")
	print("  retrait de l'axe 55 : charge %.2f → %.2f ✅"
		% [charge_avant, ville.valeur("r", 55, "charge", mois)])
	# 🚗 Ce que le report ne rattrape pas : la part qui renonce à la voiture.
	var total_apres := 0.0
	var montent := 0
	for f in ville.routes:
		var q := float(ville.valeur("r", f, "charge", mois))
		total_apres += q
		if f != 55 and q > float(ville.valeur("r", f, "charge", 0.0)) + 0.005:
			montent += 1
	print(("  report : %d rues voisines plus chargées, total de charge"
		+ " %.1f → %.1f (−%.1f %% renoncent à la voiture) ✅")
		% [montent, total_avant, total_apres,
			100.0 * (total_avant - total_apres) / maxf(total_avant, 0.001)])
	_sur_reset()

	await _essai_berge()

	# De près, sur la barre de 1974 : les volumes tiennent-ils après le
	# découpage en nœuds, et le clic retrouve-t-il l'objet sous le curseur.
	_repere("barre")
	await get_tree().process_frame
	await get_tree().physics_frame
	var touche: Array = selection.sonder(
		get_viewport().get_visible_rect().size * 0.5)
	print("  clic au centre de la vue « barre » → %s %d %s"
		% [touche[0], touche[1], "✅" if touche == ["i", 32] else "❌ attendu i 32"])
	if touche[1] >= 0:
		selection.sel_couche = touche[0]
		selection.sel_fid = touche[1]
		interface.montrer(touche[0], touche[1], false)
		_dernier_peint = -1.0
		_rafraichir(true)
	await get_tree().process_frame
	await _capturer("essai_barre")

	# L'Ilse : nappe nettement sous la ville, tabliers au-dessus sans y plonger.
	_repere("ilse")
	await get_tree().process_frame
	await _capturer("essai_ilse")

	# 🌊 LE FAUBOURG SINISTRÉ (23b). Ce qu'il faut y voir : des murs SANS TOIT
	# le long de l'eau, le limon qui s'arrête quelque part au lieu de couvrir
	# toute la rive gauche, et la ville d'en face intacte. À 40° : de plus haut
	# on perd les toits manquants, de plus bas on perd l'emprise du limon.
	_repere("faubourg")
	pivot.caler(120.0, 40.0)
	await get_tree().process_frame
	await _capturer("essai_faubourg")

	# Le pont emporté, de profil : la chaussée doit s'arrêter au bord de l'eau
	# des DEUX côtés, sans tablier ni parapet en l'air au-dessus du vide.
	_repere("pont_casse")
	pivot.caler(200.0, 14.0)
	await get_tree().process_frame
	await _capturer("essai_pont_casse")

	# 🔧 LES TROIS RÉPARATIONS, ÉPROUVÉES PLUTÔT QUE PROMISES. On paie, on
	# avance le temps jusqu'à la fin du chantier, et on REGARDE : un tablier
	# doit avoir repoussé au-dessus de l'eau, un îlot doit avoir retrouvé ses
	# toits. Si la ruine ressort À TRAVERS le bâtiment neuf, c'est RUINE_PANS
	# qui est monté trop haut (voir 07).
	await _essai_reparation()
	pivot.caler(30.0, 32.0)

	# 🌉 LE FRANCHISSEMENT DE PRES (2026-08-18) : a 260 m d'etendue, `ilse` ne
	# donne pas deux pixels a un tablier de 70 cm. De profil (12°), on doit
	# voir l'eau passer SOUS le tablier et la pile s'y poser.
	_repere("pont")
	pivot.caler(200.0, 12.0)
	await get_tree().process_frame
	await _capturer("essai_pont")

	# Le quai de profil : le mur qui tient la chaussee, et le metre de parapet.
	_repere("quai")
	pivot.caler(200.0, 10.0)
	await get_tree().process_frame
	await _capturer("essai_quai")
	pivot.caler(30.0, 32.0)

	# La berge des champs, seul endroit non plat de la carte : sans ce repere
	# le talus ne se voit sur aucune capture. De profil (18°).
	_repere("berge")
	pivot.caler(200.0, 18.0)
	await get_tree().process_frame
	await _capturer("essai_berge")
	pivot.caler(30.0, 32.0)

	# 🅿️ LA PLACE-PARKING (2026-08-19) : une place fait 2,5 m, soit un demi
	# pixel au cadrage par défaut — les 123 places ne se voient sur aucune des
	# autres captures. 68° : un marquage au sol ne se lit que de dessus, sinon
	# la trame vire au moiré.
	_repere("place")
	pivot.caler(30.0, 68.0)
	await get_tree().process_frame
	await _capturer("essai_place")
	pivot.caler(30.0, 32.0)

	# 🏢 LES DEUX ÉPOQUES RÉCENTES, À TOIT PLAT (auteur, 2026-08-25). Une
	# terrasse ne se lit que d'en haut : à 32° elle passe pour un pan court.
	# 62° montre aussi les cinq percées de 9 m du mur mitoyen.
	_repere("compact")
	pivot.caler(30.0, 62.0)
	await get_tree().process_frame
	await _capturer("essai_compact")
	pivot.caler(30.0, 32.0)

	# 🪟 LA CAPTURE QUI JUGE LES FENÊTRES (2026-08-18) : les six autres
	# regardent la ville de haut, où un percement tient sur deux pixels et où
	# le shader a rendu la main à l'aplat. 150 m et 14°, la hauteur d'un piéton
	# au bout de la rue, la seule d'où un rez-de-chaussée se lit.
	var q: Array = (donnees["reperes"]["quai"] as Dictionary)["cible"]
	pivot.viser(Vector2(float(q[0]), float(q[1])), 150.0)
	pivot.caler(210.0, 14.0)
	await get_tree().process_frame
	await _capturer("essai_facades")
	pivot.caler(30.0, 32.0)


	# L'église protégée : la preuve doit être dans la fiche, pas seulement vraie
	# dans le noyau — curseur verrouillé, raison patrimoniale écrite.
	_repere("ville")
	selection.sel_couche = "i"
	selection.sel_fid = 16
	interface.montrer("i", 16, false)
	_dernier_peint = -1.0
	_rafraichir(true)
	await get_tree().process_frame
	await _capturer("essai_eglise")

	var trop_cher := _essai_economie()

	# La capture du REFUS : un bouton grisé ne prouve rien, la phrase rouge qui
	# dit combien il manque, si.
	if trop_cher >= 0:
		selection.sel_couche = "i"
		selection.sel_fid = trop_cher
		interface.montrer("i", trop_cher, false)
		interface.viser(100.0)
		_dernier_peint = -1.0
		_rafraichir(true)
		await get_tree().process_frame
		await _capturer("essai_caisse")
		selection.sel_fid = 32
		interface.montrer("i", 32, false)
		_dernier_peint = -1.0
		_rafraichir(true)

	# 🔄 Le verrou d'urgence est tombé le 2026-08-31, et c'est l'inverse qu'il
	# faut prouver : la pose est disponible AU MOIS 0, la ville encore en ruine,
	# et elle se dispute la caisse avec les réparations.
	var degats0: Dictionary = ville.degats(mois)
	if float(degats0["logements_perdus"]) <= 0.0 \
			or ville.part_solaire_max(32, mois) < 0.999:
		push_error("la pose devrait être disponible dès le mois 0, ville en ruine")
		get_tree().quit(1)
		return
	print("  pose disponible au mois 0 : %d logements encore à terre, caisse %.0f k€ ✅"
		% [int(degats0["logements_perdus"]), ville.caisse_ke(mois)])

	# Le seul geste du prototype, vérifié sur la barre : mi-pose puis 100 %.
	var caisse_avant := ville.caisse_ke(mois)
	if not ville.lancer_solaire(32, 1.0, mois):
		push_error("l'îlot 32 refuse la pose après le déverrouillage")
		get_tree().quit(1)
		return
	var etat32 := ville.etat_solaire(32, mois)
	var cout32: float = etat32["cout_ke"]
	# La pose se paie COMPTANT : la caisse tombe exactement du coût annoncé, ni
	# plus (intérêt) ni moins (subvention). Sinon la dépense a été comptée
	# ailleurs qu'au moment du clic.
	if absf(ville.caisse_ke(mois) - (caisse_avant - cout32)) > 0.001:
		push_error("la caisse n'a pas payé la pose : %.1f → %.1f pour %.1f k€"
			% [caisse_avant, ville.caisse_ke(mois), cout32])
		get_tree().quit(1)
		return
	print("  îlot 32 · pose 0 → 100 %% : %.0f k€ · caisse %.0f → %.0f k€ ✅"
		% [cout32, caisse_avant, ville.caisse_ke(mois)])
	interface.confirmer_solaire(cout32)
	mois += Ville.SOLAIRE_MOIS_POUR_100 / 2.0
	# ⚠ Sans ce recadrage la capture « mi-pose » restait sur l'Ilse, donc ne
	# montrait pas le toit dont elle prouve la progression.
	_repere("barre")
	_dernier_peint = -1.0
	_rafraichir(true)
	var mi_pose := ville.etat_solaire(32, mois)
	# ⚠ DÉDUIT de la durée : écrit « 1,5 » en dur, raccourcir la pose faisait
	# échouer l'essai sans que rien soit cassé.
	var reste_attendu := Ville.SOLAIRE_MOIS_POUR_100 / 2.0
	if absf(float(mi_pose["actuel"]) - 0.5) > 0.001 \
			or absf(float(mi_pose["reste_mois"]) - reste_attendu) > 0.001:
		push_error("pose solaire à mi-parcours incorrecte : %s" % mi_pose)
		get_tree().quit(1)
		return
	print("  mi-pose : 50 %% réalisés · %.2f mois restant ✅" % reste_attendu)
	# Un chantier engagé ne se révise pas : c'est ce verrou qui autorise les
	# rampes à s'additionner sans réécrire l'histoire d'un toit.
	if ville.lancer_solaire(32, 1.0, mois):
		push_error("une pose en cours a accepté une seconde commande")
		get_tree().quit(1)
		return
	await get_tree().process_frame
	await _capturer("essai_solaire_pose")

	mois += Ville.SOLAIRE_MOIS_POUR_100 / 2.0
	var ind := ville.indicateurs(mois)
	print("  îlot 32 : panneaux 0 → 100 %% en %.0f mois · production ville %.1f GWh/an"
		% [Ville.SOLAIRE_MOIS_POUR_100, ind["production_mwh"] / 1000.0])
	print("  caisse %.0f k€ · recette solaire +%.0f k€/an · amortissement %.0f ans"
		% [ind["caisse_ke"], ind["recette_ke_an"],
		ville.valeur("i", 32, "_rentabilite_annees", mois)])
	_repere("barre")
	_dernier_peint = -1.0
	_rafraichir(true)
	await get_tree().process_frame
	await _capturer("essai_solaire_100")

	# Le retour au mois 0 doit tout défaire. Un seul des trois qui reste en
	# arrière signerait une décision figée en base et jamais rendue.
	_sur_reset()
	var prod_apres: float = ville.indicateurs(mois)["production_mwh"]
	var part_apres := ville.valeur("i", 32, "part_toit_equipe", mois)
	var caisse_apres := ville.caisse_ke(mois)
	if mois != 0.0 or part_apres > 0.0001 or prod_apres > 0.001 \
			or absf(caisse_apres - Ville.CAISSE_DEPART_KE) > 0.001:
		push_error("retour au mois 0 incomplet : mois %s · îlot 32 %s · production %s · caisse %s"
			% [mois, part_apres, prod_apres, caisse_apres])
		get_tree().quit(1)
		return
	print("  retour au mois 0 : îlot 32 à 0 %%, production 0,0 GWh/an, caisse %.0f k€ ✅"
		% caisse_apres)
	await get_tree().process_frame
	await _capturer("essai_reset")

	# 🌞 LA PREUVE DU PAN DE TOIT — la barre ci-dessus est plate. À 50 %, un
	# toit à deux pentes doit avoir un pan entier équipé et l'autre en tuile,
	# jamais deux demi-pans mouchetés.
	selection.sel_couche = "i"
	selection.sel_fid = 22
	interface.montrer("i", 22, false)
	if not ville.lancer_solaire(22, 1.0, mois):
		push_error("l'îlot 22 refuse la pose de contrôle pan par pan")
		get_tree().quit(1)
		return
	mois = Ville.SOLAIRE_MOIS_POUR_100 / 2.0
	_repere("pans_solaire")
	_dernier_peint = -1.0
	_rafraichir(true)
	await get_tree().process_frame
	await _capturer("essai_solaire_pans")
	print("  contrôle visuel : îlot 22 à 50 % — premier pan entier, second nu")
	# 🌿 LE PLAFOND DE LA PENTE, sur ce même îlot : 4 volumes concaves sur 22
	# retombent au toit plat, donc le cœur ancien peut verdir un cinquième de
	# son toit et pas un mètre de plus.
	var plat22 := ville.valeur("i", 22, "_part_plate", mois)
	if plat22 <= 0.01 or plat22 >= 0.99:
		push_error("l'îlot 22 devrait être partiellement plat, il est à %.2f" % plat22)
		get_tree().quit(1)
		return
	print("  îlot 22 : %.0f %% de toit plat — le reste ne peut pas verdir ✅"
		% (plat22 * 100.0))
	_sur_reset()

	# 🌿 LE TOIT PARTAGÉ. La barre 32 est plate de bout en bout : c'est la seule
	# image où les deux poses se voient côte à côte, et où l'on peut vérifier
	# qu'aucun mètre carré n'est compté deux fois.
	selection.sel_couche = "i"
	selection.sel_fid = 32
	interface.montrer("i", 32, false)
	if not ville.lancer_solaire(32, 0.6, mois):
		push_error("l'îlot 32 refuse 60 % de panneaux")
		get_tree().quit(1)
		return
	# LE partage : ce que les panneaux ont pris n'est plus offert au sédum.
	var reste_vert := ville.part_vert_max(32, mois)
	if absf(reste_vert - 0.4) > 0.001:
		push_error("le toit devrait laisser 40 %% au vert, il en laisse %.2f" % reste_vert)
		get_tree().quit(1)
		return
	# On en demande 90 % : le noyau rabote à ce qui reste, il ne refuse pas.
	if not ville.lancer_vert(32, 0.9, mois):
		push_error("l'îlot 32 refuse le toit vert")
		get_tree().quit(1)
		return
	var cible_v: float = ville.etat_vert(32, mois)["cible"]
	if absf(cible_v - 0.4) > 0.001:
		push_error("le toit vert a dépassé le partage : %.2f" % cible_v)
		get_tree().quit(1)
		return
	mois += Ville.TOIT_VERT_MOIS_POUR_100
	print("  îlot 32 : 60 % de panneaux + 40 % de sédum = 100 % du toit ✅")
	print("  %.0f m² verdis dans la ville · la prochaine crue baisse de %.0f cm"
		% [ville.toit_vert_ha(mois) * 10000.0,
		ville.baisse_crue_toits_m(mois) * 100.0])
	_repere("barre")
	_dernier_peint = -1.0
	_rafraichir(true)
	await get_tree().process_frame
	await _capturer("essai_toit_vert")
	_sur_reset()

	# 🩶 LES DEUX VUES, DEPUIS LE MÊME POINT DE VUE. Une image de la ville
	# vivante, puis une par thème, toutes au même cadrage : c'est la seule
	# façon de juger si le changement de registre est franc et si chaque thème
	# se lit sur le carton. La caméra ne bouge plus d'elle-même, ces captures
	# le prouvent aussi.
	# On DÉSÉLECTIONNE d'abord : un objet éclairci passerait pour un thème.
	selection.sel_fid = -1
	selection.sel_couche = ""
	_repere("ville")
	pivot.caler(30.0, 55.0)
	_dernier_peint = -1.0
	_rafraichir(true)
	await get_tree().process_frame
	await _capturer("essai_materiaux")

	# 🌊 Le thème « dangers » doit prouver ses trois lectures sur UNE image :
	# emprise, bâti touché et coupures. Un signal vide échoue avant la capture.
	var diag := [0, 0, 0]
	for o in ville.ilots.values():
		diag[0] += int(float(o.get("hauteur_eau_max", 0.0)) > 0.10)
		diag[1] += int(float(o.get("part_sinistree", 0.0)) > 0.0)
	for o in ville.routes.values():
		diag[2] += int(str(o.get("etat_crue", "")) == "coupe")
	if diag.min() <= 0:
		push_error("thème dangers incomplet : %s" % [diag])
		get_tree().quit(1)
		return
	print("  dangers : %d îlots noyés, %d avec bâti touché, %d routes bloquées"
		% diag)

	for th in THEMES:
		var id := str(th["id"])
		if id == "chantiers":
			continue    # capturé plus haut, sur une partie déjà jouée
		_sur_theme(id)
		# Un thème qui ne peint RIEN sort une ville de carton uni, et ça ne se
		# voit pas sur une capture qu'on ne compare à rien. « dangers » a déjà
		# ses trois comptes ci-dessus, d'où le −1 qui le laisse passer.
		var peints := -1    # −1 = compté autrement, jamais « rien de peint »
		if _genre() == "tissu":
			peints = _teintes_tissu.size()
		elif _genre() == "calque":
			peints = 0
			for fid in noeuds[calque_couche]:
				peints += int(_disponible(calque_couche, fid))
		if peints == 0:
			push_error("thème %s : aucun objet peint" % id)
			get_tree().quit(1)
			return
		await get_tree().process_frame
		await _capturer("essai_diag_%s" % id)
		print("  thème %-9s : %s → essai_diag_%s.png" % [id,
			"%4d objets peints" % peints if peints >= 0
			else "compté par ses trois signaux", id])
	_sur_theme("")
	await get_tree().process_frame
	await _capturer("essai_retour_ville")

	get_tree().quit()


## Déverrouille la réduction sans passe-droit : au mois 600 la dotation peut
## payer les réparations essentielles, puis on attend leur vraie durée. Ce
## mois n'est pas du level design ; c'est seulement la caisse de l'essai.
## 🌊 CE QUE LA BERGE CHANGE À LA CRUE, en une ligne : l'îlot témoin et la ville.
## ❌ si la berge renaturée ne déplace RIEN — c'est exactement le défaut que la
## question 24 nommait.
func _journal_crue(bief: Array, quand: String) -> void:
	var d: Dictionary = ville.degats(mois)
	if bief.is_empty():
		print("  %-16s ville : la prochaine crue monte à %.2f m"
			% [quand, float(d["eau_prochaine_m"])])
		return
	# ⚠️ DEUX ÎLOTS, PAS UN. Le plus enfoncé garde 100 % quoi qu'on fasse — il
	# faudrait 3 m de baisse pour l'en sortir. C'est celui qui BASCULE qui dit
	# si la berge sert à quelque chose.
	var temoin: int = int(bief[0])
	var bascule := temoin
	var chute := -1.0
	for f in bief:
		var v := ville.base("i", int(f), "part_ruinee_apres") \
			- ville.valeur("i", int(f), "part_ruinee_apres", mois)
		if v > chute:
			chute = v
			bascule = int(f)
	print(("  %-16s îlot %d : eau %.2f m · aléa %.2f · reprise %3.0f %%"
		+ "   |   îlot %d : reprise %3.0f %%   |   ville %.2f m")
		% [quand, temoin,
		ville.valeur("i", temoin, "hauteur_eau_annonce", mois),
		ville.valeur("i", temoin, "alea", mois),
		100.0 * ville.valeur("i", temoin, "part_ruinee_apres", mois),
		bascule, 100.0 * ville.valeur("i", bascule, "part_ruinee_apres", mois),
		float(d["eau_prochaine_m"])])


## 🌊 LE CRITÈRE DE LA BERGE : cliquer une berge, la passer d'asphalte à berge
## renaturée, et voir la rive changer. Trois captures au MÊME cadrage — c'est
## l'écart entre elles qui juge, pas leur beauté.
func _essai_berge() -> void:
	print("
BERGE — trois états francs")
	# La plus minéralisée : celle qui a le plus d'asphalte au-dessus de l'Ilse.
	var fid := -1
	for f in ville.berges:
		if fid < 0 or ville.base("b", f, "debord_m2") \
				> ville.base("b", fid, "debord_m2"):
			fid = f
	if fid < 0:
		push_error("aucune berge : la couche `b` est vide")
		get_tree().quit(1)
		return
	_viser_objet("b", fid, 260.0)
	# ⚠️ PAS DE PROFIL ICI. À 14° le rayon du centre de l'écran traverse la rive
	# d'EN FACE avant d'arriver sur celle qu'on vise : le contrôle du clic
	# renvoyait la berge 2 en visant la 6. À 34°, il tombe sur ce qu'on regarde.
	pivot.caler(200.0, 34.0)
	selection.sel_couche = "b"
	selection.sel_fid = fid
	interface.montrer("b", fid, false)
	await get_tree().process_frame
	await get_tree().physics_frame
	# Le clic doit tomber sur la berge visée : sans ce contrôle, une capture
	# verte ne prouverait que la peinture, pas l'objet.
	var touche: Array = selection.sonder(
		get_viewport().get_visible_rect().size * 0.5)
	print(("  berge %d · rive %s · %.0f m dont %.0f m de mur · %.0f m²"
		+ " d'asphalte sur l'eau")
		% [fid, ville.berges[fid].get("rive", "?"),
		ville.base("b", fid, "longueur_m"), ville.base("b", fid, "mur_m"),
		ville.base("b", fid, "debord_m2")])
	print("  clic au centre → %s %d %s"
		% [touche[0], touche[1],
		"✅" if touche == ["b", fid] else "❌ attendu b %d" % fid])
	# 🌊 CE QU'ELLE RACHÈTE, avant/après. Sans ces trois lignes, la seule
	# contrepartie visible d'une berge resterait la caisse — question 24.
	var bief: Array = ville.ilots_du_bief(fid)
	print("  bief : %d îlots exposés, le plus enfoncé est le %d"
		% [bief.size(), int(bief[0]) if not bief.is_empty() else -1])
	_journal_crue(bief, "avant")
	await _capturer("essai_berge_asphalte")

	for cible in [Ville.BERGE_APAISEE, Ville.BERGE_RENATUREE]:
		# 🔴 On ATTEND que la caisse suive au lieu de la remplir : le prix d'une
		# berge est le seul chiffre qui dise si la décision est jouable.
		var cout := ville.cout_berge_ke(fid, cible, mois)
		while ville.caisse_ke(mois) < cout and mois < Ville.HORIZON_MOIS:
			mois += 1.0
		if not ville.transformer_berge(fid, cible, mois):
			push_error("berge %d : %s refusée au mois %.0f"
				% [fid, Ville.BERGE_NOMS[cible], mois])
			get_tree().quit(1)
			return
		print("  mois %3.0f · %-16s %5.0f k€ · %2.0f mois · caisse %.0f k€"
			% [mois, Ville.BERGE_NOMS[cible], cout,
			ville.berge_reste_mois(fid, mois), ville.caisse_ke(mois)])
		mois += ville.berge_reste_mois(fid, mois) + 0.1
		var vu := ville.berge_etat(fid, mois)
		if vu != cible:
			push_error("berge %d livrée au mois %.0f mais toujours en %s"
				% [fid, mois, Ville.BERGE_NOMS[vu]])
			get_tree().quit(1)
			return
		_dernier_peint = -1.0
		_rafraichir(true)
		await get_tree().process_frame
		_journal_crue(bief, Ville.BERGE_NOMS[cible])
		await _capturer("essai_berge_%s" % ["", "apaisee", "renaturee"][cible])
	print("  livrée au mois %.0f — 3 captures au même cadrage" % mois)
	_sur_reset()
	mois = 0.0
	_rafraichir(true)
	pivot.caler(30.0, 32.0)


## 🎚️ LE compte rendu qui sert à régler `CAISSE_DEPART_KE` et
## `DOTATION_KE_MOIS` : sans lui les deux se règlent à l'aveugle.
## Les amortissements sont rangés par tissu parce que c'est LÀ qu'est la
## décision — une barre de 1974 et un cœur ancien ne se remboursent pas dans le
## même siècle.
##
## Rend le fid de l'îlot que la caisse ne peut PAS payer, ou −1 : c'est celui
## 🔧 Payer, attendre, regarder. Le seul contrôle qui prouve que la géométrie
## neuve existe et qu'elle recouvre bien la ruine.
func _essai_reparation() -> void:
	print("
RÉPARATION — ce que la crue laisse à payer")
	var d0: Dictionary = ville.degats(mois)
	print("  au mois 0 : %d logements perdus · %d franchissement(s) coupé(s)"
		% [int(d0["logements_perdus"]), int(d0["franchissements_coupes"])])
	print("  tout réparer coûterait %.0f k€, la caisse en a %.0f"
		% [d0["a_reparer_ke"], ville.caisse_ke(mois)])

	# Le pont le moins cher, puis l'îlot le moins cher : ce sont les deux que
	# la caisse de départ peut effectivement payer.
	var pont := -1
	var ilot := -1
	for fid in ville.routes:
		if str(ville.routes[fid].get("etat_crue", "")) != "coupe":
			continue
		var c_pont := ville.cout_reparation_ke("r", fid)
		if pont < 0 or c_pont < ville.cout_reparation_ke("r", pont):
			pont = fid
	for fid in ville.ilots:
		# ⚠️ Il faut un îlot QUI A DES RUINES : un îlot seulement sinistré porte
		# un prix (le rez à refaire) mais aucune géométrie neuve, et le contrôle
		# « bâti neuf visible » sortirait faux sans qu'il y ait de défaut.
		if ville.base("i", fid, "batiments_ruines") <= 0.0:
			continue
		var c := ville.cout_reparation_ke("i", fid)
		if ilot < 0 or c < ville.cout_reparation_ke("i", ilot):
			ilot = fid

	# 🔴 LE REFUS, ÉPROUVÉ : le pont le moins cher dépasse la caisse de départ,
	# et l'essayer ne doit pas bouger un centime.
	var avant := ville.caisse_ke(mois)
	if pont >= 0 and ville.cout_reparation_ke("r", pont) > avant:
		var lance := ville.reparer("r", pont, mois)
		if lance or absf(ville.caisse_ke(mois) - avant) > 0.001:
			push_error("pont %d rebâti sans la caisse" % pont)
			get_tree().quit(1)
			return
		print("  refus vérifié : le pont %d coûte %.0f k€, la caisse en a %.0f ✅"
			% [pont, ville.cout_reparation_ke("r", pont), avant])

	if ilot >= 0 and ville.reparer("i", ilot, mois):
		print("  îlot %d reconstruit : %.0f k€ · caisse %.0f → %.0f k€"
			% [ilot, avant - ville.caisse_ke(mois), avant, ville.caisse_ke(mois)])
		mois = Ville.RECONSTRUCTION_MOIS + 0.1
		_dernier_peint = -1.0
		_rafraichir(true)
		var noeud: MeshInstance3D = reparations["i"].get(ilot)
		print("  au mois %.1f : bâti neuf visible %s · logements %d · toit %.0f m²"
			% [mois, "✅" if noeud != null and noeud.visible else "❌",
			int(ville.valeur("i", ilot, "logements", mois)),
			ville.valeur("i", ilot, "_toit_equipable_m2", mois)])
		selection.sel_couche = "i"
		selection.sel_fid = ilot
		interface.montrer("i", ilot, false)
		_repere("faubourg")
		pivot.caler(120.0, 40.0)
		_rafraichir(true)
		await get_tree().process_frame
		await _capturer("essai_reconstruit")

	# Le temps a passé : la dotation a coulé, le pont devient payable.
	mois = 96.0
	_rafraichir(true)
	if pont >= 0 and ville.reparer("r", pont, mois):
		# 🔧 LE MOMENT OÙ LA VUE CHANTIERS A SES TROIS ÉTATS : l'îlot relevé
		# est fini, le pont vient d'être engagé, le reste du faubourg attend.
		await _capturer_chantiers()
		mois += Ville.PONT_MOIS + 0.1
		_dernier_peint = -1.0
		_rafraichir(true)
		var n2: MeshInstance3D = reparations["r"].get(pont)
		var reste: Dictionary = ville.degats(mois)
		print("  pont %d rebâti au mois %.0f : tablier visible %s · %d franchissement(s) encore coupé(s)"
			% [pont, mois, "✅" if n2 != null and n2.visible else "❌",
			int(reste["franchissements_coupes"])])
		selection.sel_couche = "r"
		selection.sel_fid = pont
		interface.montrer("r", pont, false)
		# ⚠️ Visé sur le tablier NEUF lui-même, pas sur le repère « pont_casse » :
		# celui-ci vise le barycentre des TROIS coupures, et le seul ouvrage
		# rebâti tombait hors cadre.
		if n2 != null:
			var b := n2.get_aabb()
			pivot.viser(Vector2(b.get_center().x, b.get_center().z), 130.0)
		pivot.caler(200.0, 26.0)
		_rafraichir(true)
		await get_tree().process_frame
		await _capturer("essai_pont_rebati")
	# On repart d'une ville intacte : les captures suivantes jugent le rendu,
	# pas une partie déjà jouée.
	mois = 0.0
	ville.reinitialiser()
	_dernier_peint = -1.0
	_rafraichir(true)


## 🔧 La vue chantiers, prouvée sur UNE image. Les trois états doivent être
## présents ensemble : un état vide est une couleur que personne n'a jamais vue.
func _capturer_chantiers() -> void:
	_sur_theme("chantiers")
	_repere("ville")
	var c := ville.chantiers(mois)
	var en_cours: Array = c["en_cours"]
	var compte := [int(c["casses"]), en_cours.size(), int(c["faits"])]
	if compte.min() <= 0:
		push_error("vue chantiers incomplète : %s" % [compte])
		get_tree().quit(1)
		return
	pivot.caler(30.0, 55.0)
	_rafraichir(true)
	await get_tree().process_frame
	await _capturer("essai_chantiers")
	print("  vue chantiers : %d cassés, %d en cours, %d fini(s) · %.0f k€ à payer"
		% [compte[0], compte[1], compte[2], c["reste_ke"]])
	_sur_theme("")


## dont on capture le refus.
func _essai_economie() -> int:
	var cout_ville := 0.0
	var recette_ville := 0.0
	var payables := 0
	var cher_fid := -1
	var cher_cout := 0.0
	var par_tissu := {}          # sous_type -> [nombre, coût k€, années cumulées]
	for fid in ville.fids_batis():
		var cout: float = ville.valeur("i", fid, "_cout_total_ke", 0.0)
		var ans: float = ville.valeur("i", fid, "_rentabilite_annees", 0.0)
		if cout <= 0.0 or is_inf(ans):
			continue
		cout_ville += cout
		recette_ville += cout / ans        # k€/an, sans passer par l'énergie
		if cout <= Ville.CAISSE_DEPART_KE:
			payables += 1
		if cout > cher_cout:
			cher_cout = cout
			cher_fid = fid
		var st := str(ville.ilots[fid].get("sous_type", "?"))
		if not par_tissu.has(st):
			par_tissu[st] = [0, 0.0, 0.0]
		par_tissu[st][0] += 1
		par_tissu[st][1] += cout
		par_tissu[st][2] += ans

	print("
ÉCONOMIE — au mois 0")
	print("  caisse de départ        %8.0f k€" % Ville.CAISSE_DEPART_KE)
	print("  dotation                %8.0f k€/mois (%.0f k€/an)"
		% [Ville.DOTATION_KE_MOIS, Ville.DOTATION_KE_MOIS * 12.0])
	print("  équiper toute la ville  %8.0f k€  → %.0f k€/an de recette"
		% [cout_ville, recette_ville])
	print("  payables au mois 0      %8d îlots sur %d équipables"
		% [payables, par_tissu.values().reduce(func(a, l): return a + l[0], 0)])
	print("  %-22s %8s %8s %8s" % ["tissu", "îlots", "k€", "ans"])
	for st in par_tissu:
		var l: Array = par_tissu[st]
		print("  %-22s %8d %8.0f %8.0f" % [st, l[0], l[1], l[2] / float(l[0])])

	# Le refus, éprouvé plutôt que promis : l'îlot le plus cher doit rester
	# impossible, et la caisse ne doit pas bouger pendant qu'on essaie.
	if cher_cout > ville.caisse_ke(mois):
		var avant := ville.caisse_ke(mois)
		if ville.lancer_solaire(cher_fid, 1.0, mois) \
				or absf(ville.caisse_ke(mois) - avant) > 0.001:
			push_error("îlot %d posé à %.0f k€ avec %.0f k€ en caisse"
				% [cher_fid, cher_cout, avant])
			get_tree().quit(1)
			return -1
		print("  refus vérifié : l'îlot %d coûte %.0f k€, la caisse en a %.0f ✅"
			% [cher_fid, cher_cout, avant])
		return cher_fid
	print("  ⚠ aucun îlot ne dépasse la caisse : le refus n'est pas éprouvé")
	return -1


# ------------------------------------------------------------- construction

func _construire() -> void:
	var mat := Materiaux.surface()

	# 🔄 Le terrain était un CHAMP D'ALTITUDE déplié en grille ; la carte est
	# plate depuis le 2026-08-12. Murs de quai et fond du chenal sont dedans,
	# pas dans l'eau, dont le matériau est lisse et d'une seule teinte.
	_fusionne("Terrain", Constructeur.maillage(donnees["terrain"]), mat)
	_fusionne("Eau", Constructeur.maillage(donnees["eau"]),
		Materiaux.eau(Donnees.teinte(donnees, "riviere")))

	# Un nœud par objet, donc une ville cliquable : 5 draw calls deviennent
	# ~250, invisible sur 40 000 triangles.
	# 🌊 La berge avant les îlots, pour que l'ordre des nœuds suive celui du
	# terrain : son corps est le mur de quai, et il borde tout le reste.
	_par_objet("Berges", [donnees["berges"]], "b")
	_par_objet("Ilots", [donnees["masses"], donnees["sols"]], "i")
	_par_objet("Routes", [donnees["voirie"]], "r")
	_par_reparation("Reparation", donnees["repare"], "i")
	_par_reparation("ReparationVoirie", donnees["repare_voirie"], "r")
	_par_places(donnees["places"])

	# 🌳 Le semis des îlots de sol ne bouge pas : aucune décision ne plante DANS
	# un îlot — un îlot bâti n'a pas de sol visible sous lui.
	_arbres_semis = (donnees["arbres"] as Array).duplicate()
	# Les emplacements d'alignement, avec le tronçon qui les porte et leur
	# seuil : c'est cette liste-là que la plantation fait apparaître.
	for f in (donnees["alignements"] as Dictionary):
		for a in (donnees["alignements"][f] as Array):
			_arbres_slots.append([a[0], a[1], a[2], a[3], a[4], int(f),
				float(a[5])])

	if not _ignore("Arbres"):
		for essence in [Constructeur.FEUILLU, Constructeur.CONIFERE]:
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "Arbres%d" % essence
			# ⚠️ PAS de `material_override` : il écraserait les deux surfaces
			# de l'arbre et le tronc ressortirait vert.
			monde.add_child(mmi)
			_arbres_noeuds[essence] = mmi
		_montrer_arbres()
		for essence in _arbres_noeuds:
			var mm: MultiMesh = (_arbres_noeuds[essence] as MultiMeshInstance3D).multimesh
			print("  arbres   %-8s %5d instances"
				% ["conifère" if essence == Constructeur.CONIFERE
					else "feuillu", 0 if mm == null else mm.instance_count])


func _ignore(nom: String) -> bool:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--solo=") and a.substr(7) != nom:
			return true
	return false


func _fusionne(nom: String, m: ArrayMesh, mat: Material) -> void:
	if _ignore(nom):
		return
	var n := MeshInstance3D.new()
	n.name = nom
	n.mesh = m
	n.material_override = mat
	monde.add_child(n)
	_dire(nom, m)


func _par_objet(nom: String, sources: Array, couche: String) -> void:
	if _ignore(nom):
		return
	var parent := Node3D.new()
	parent.name = nom
	monde.add_child(parent)
	var tris := 0
	for d in sources:
		for g in (d["g"] as Array):
			var gr: Array = g
			var fid := int(gr[0])
			var mi := MeshInstance3D.new()
			mi.name = "%s%d" % [{"i": "I", "r": "R", "b": "B"}[couche], fid]
			mi.mesh = Constructeur.maillage_groupe(d, int(gr[1]), int(gr[2]))
			mi.material_override = mat_objet
			mi.set_meta("fid", fid)
			mi.set_meta("couche", couche)
			parent.add_child(mi)
			# Le corps de collision devient un ENFANT du MeshInstance3D.
			# `selection.gd` remonte au parent pour retrouver le fid.
			mi.create_trimesh_collision()
			noeuds[couche][fid] = mi
			@warning_ignore("integer_division")
			var t3: int = int(gr[2]) / 3
			tris += t3
	print("  %-8s %3d objets, %6d triangles" % [nom, parent.get_child_count(), tris])


## 🅿️ LES PLACES PEINTES, un nœud par tronçon. Elles partent VISIBLES et se
## cachent quand la rue n'a plus de stationnement (`_peindre`) : sans elles,
## « retirer les places » ne retirait que les voitures, et la rue gardait ses
## tirets. Aucun corps de collision — cliquer une place, c'est cliquer la rue.
func _par_places(source: Dictionary) -> void:
	if _ignore("Routes"):
		return
	var parent := Node3D.new()
	parent.name = "PlacesRue"
	monde.add_child(parent)
	for g in (source["g"] as Array):
		var gr: Array = g
		var fid := int(gr[0])
		var mi := MeshInstance3D.new()
		mi.name = "P%d" % fid
		mi.mesh = Constructeur.maillage_groupe(source, int(gr[1]), int(gr[2]))
		mi.material_override = mat_objet
		mi.set_meta("fid", fid)
		mi.set_meta("couche", "r")
		parent.add_child(mi)
		places_rue[fid] = mi
	print("  %-8s %3d rues marquées" % ["Places", parent.get_child_count()])


## Les nœuds de réparation. Même recette que `_par_objet`, trois différences :
## ils partent CACHÉS, leur corps de collision part désactivé, et ils ne
## remplacent personne — une ruine tient tout entière SOUS le bâtiment neuf qui
## la couvre (voir RUINE_RETRAIT dans 07), donc rien n'est à retirer.
func _par_reparation(nom: String, source: Dictionary, couche: String) -> void:
	if _ignore("Ilots" if couche == "i" else "Routes"):
		return
	var parent := Node3D.new()
	parent.name = nom
	monde.add_child(parent)
	for g in (source["g"] as Array):
		var gr: Array = g
		var fid := int(gr[0])
		var mi := MeshInstance3D.new()
		mi.name = "%s%d" % ["N" if couche == "i" else "T", fid]
		mi.mesh = Constructeur.maillage_groupe(source, int(gr[1]), int(gr[2]))
		mi.material_override = mat_objet
		mi.set_meta("fid", fid)
		mi.set_meta("couche", couche)
		mi.visible = false
		parent.add_child(mi)
		mi.create_trimesh_collision()
		_corps(mi, false)
		reparations[couche][fid] = mi
	print("  %-8s %3d objets prêts à réparer" % [nom, parent.get_child_count()])


## Un corps de collision caché reste TOUCHÉ par le raycast : masquer le
## maillage ne suffit pas, il faut sortir le corps du calque.
func _corps(mi: MeshInstance3D, actif: bool) -> void:
	for e in mi.get_children():
		if e is StaticBody3D:
			(e as StaticBody3D).collision_layer = 1 if actif else 0


## Montre ce qui vient d'être fini. Une géométrie qui apparaîtrait à
## l'ENGAGEMENT dirait qu'un pont se rebâtit en une image.
func _montrer_reparations() -> void:
	for couche in ["i", "r"]:
		for fid in reparations[couche]:
			var mi: MeshInstance3D = reparations[couche][fid]
			var fini: bool = ville.reparation_finie(couche, fid, mois)
			if fini == mi.visible:
				continue
			mi.visible = fini
			_corps(mi, fini)


## 🌳 Un arbre planté sort de terre au rythme de la canopée de sa rue. Le
## compte visible sert de signature : tant qu'il ne bouge pas, on ne refait
## rien — et il ne bouge qu'aux mois où un seuil est franchi.
func _montrer_arbres() -> void:
	if _arbres_noeuds.is_empty():
		return
	var liste: Array = _arbres_semis.duplicate()
	for a in _arbres_slots:
		if float(a[6]) <= ville.valeur("r", int(a[5]), "canopee", mois):
			# Un alignement est d'une seule essence, et feuillu : personne ne
			# plante une haie d'épicéas en ville.
			liste.append([a[0], a[1], a[2], a[3], a[4], Constructeur.FEUILLU])
	if liste.size() == _arbres_compte:
		return
	_arbres_compte = liste.size()
	var vert := Donnees.teinte(donnees, "_feuillage").srgb_to_linear()
	var brun := Donnees.teinte(donnees, "_tronc")
	for essence in _arbres_noeuds:
		# Variation de VALEUR sur la même teinte, pas une deuxième couleur dans
		# la palette (Direction artistique l.67).
		var t := vert if essence == Constructeur.FEUILLU \
			else Color(vert.r * 0.70, vert.g * 0.80, vert.b * 0.76)
		(_arbres_noeuds[essence] as MultiMeshInstance3D).multimesh = \
			Constructeur.arbres(liste, essence, t, brun)


func _dire(nom: String, m: ArrayMesh) -> void:
	# Comme les scripts QGIS : un maillage vide ou hors cadre doit se voir dans
	# la console, pas se deviner à l'écran.
	var bb := m.get_aabb()
	print("  %-8s %2d surface(s) %7d sommets  y %6.1f→%6.1f  étendue %.0f × %.0f"
		% [nom, m.get_surface_count(),
		(0 if m.get_surface_count() == 0 else m.surface_get_array_len(0)),
		bb.position.y, bb.position.y + bb.size.y, bb.size.x, bb.size.z])


func _decor() -> void:
	var we := WorldEnvironment.new()
	we.environment = Materiaux.environnement(
		Donnees.teinte(donnees, "_ciel"), Donnees.teinte(donnees, "_ambiant"))
	add_child(we)

	# 🔎 La même recette que la miniature de la fiche : voir `Materiaux.soleil`.
	add_child(Materiaux.soleil(Donnees.teinte(donnees, "_soleil")))


# ------------------------------------------------------------------ le temps

func _process(delta: float) -> void:
	# L'essai pousse artificiellement la caisse au-delà des vingt ans pour
	# éprouver le déverrouillage avec les prix non calibrés de la crue. En jeu,
	# l'horizon reste strictement celui du projet.
	if "--essai" in OS.get_cmdline_user_args():
		mois += delta * vitesse * MOIS_PAR_SECONDE
	else:
		mois = minf(mois + delta * vitesse * MOIS_PAR_SECONDE, Ville.HORIZON_MOIS)
	_rafraichir(false)


func _sur_vue_changee(_lacet: float, _hauteur: float) -> void:
	trafic.regler_detail(pivot.taille)


func _sur_pulsation_trafic() -> void:
	trafic.avancer(mois)


## 🔄 RETOUR EN ARRIÈRE SIGNALÉ, 2026-09-01 : le bandeau a été rafraîchi 10 fois
## par seconde au lieu de 60, pour économiser les deux sommes de ville qu'il
## demande. Ça ne gagnait RIEN à l'écran — l'image est tenue par la carte
## graphique, pas par le script — et le contrôle du clic de `--essai` tombait à
## côté de la berge 6. Ne pas le refaire sans avoir compris ce lien.
func _rafraichir(force: bool) -> void:
	# Hors du raccourci ci-dessous : le trait suit la CAMÉRA, qui bouge même
	# quand le temps est en pause.
	_maj_contour()
	_maj_apercu()
	if not force and absf(mois - _dernier_peint) < 0.002:
		interface.maj(ville.indicateurs(mois), mois, vitesse)
		return
	_dernier_peint = mois
	_montrer_reparations()
	_montrer_arbres()
	_peindre()
	interface.maj(ville.indicateurs(mois), mois, vitesse)


# --------------------------------------------------------------- la couleur

# Échelles connues d'avance, pas mesurées : un min/max mentirait si une classe
# est vide à t0, et c'est le recul de la zone rouge qu'on veut voir.
const ETENDUES_FIXES := {
	"_classe_solaire": [0.0, 3.0],
	"part_toit_equipe": [0.0, 1.0],
}

# Là où la décision est INDISPONIBLE, le calque ne peint rien : un champ sans
# toit n'est pas « jamais rentable », il est HORS JEU. Jugé sur l'état de
# DÉPART, donc un îlot entièrement isolé reste peint, au bleu froid.
const DISPO := {
	"_classe_solaire": "_toit_equipable_m2",
	"part_toit_equipe": "_toit_equipable_m2",
	"_gain_isolation_mwh": "_gain_isolation_mwh",
}


# ================================================= LES DEUX VUES, ET LES THÈMES
#
# 🩶 DEUX VUES, décidées le 2026-08-25. ① la ville vivante — matière, ciel,
# voitures, arbres ; ② le diagnostic — la MAQUETTE BLANCHE (`materiaux.gd`),
# où seul le thème choisi est en couleur. Le temps continue dans les deux, et
# la fiche reste : le diagnostic change ce qu'on VOIT, jamais ce qu'on peut
# faire.
#
# 🔄 RETOUR EN ARRIÈRE SIGNALÉ : c'étaient quatre drapeaux indépendants
# (`calque_tissu`, `diagnostic_crue`, `vue_chantiers`, `calque_champ`) qui
# s'éteignaient l'un l'autre À LA MAIN, touches C · D · H · X. Un cinquième
# thème coûtait quatre modifications ; il en coûte une ligne ici. Les quatre
# touches sont parties avec eux : le choix se fait AU MENU (décision de
# l'auteur, 2026-08-25).
#
# 🧩 UN THÈME EN TROIS PIÈCES, et c'est le critère de l'étape 6 : ① une ligne
# ici ; ② son `genre` de peinture ; ③ s'il en a besoin, un panneau dans
# `interface.gd`. Un thème `calque` n'a rien d'autre à écrire qu'une ligne.
#
#   genre "calque"    un champ + la rampe. La voie normale d'un thème neuf.
#   genre "tissu"     une teinte par sous_type, pas une échelle continue.
#   genre "crue"      trois signaux de l'eau + les croix des routes coupées.
#   genre "chantiers" l'état d'avancement de l'objet entier.
const THEMES := [
	{"id": "dangers", "nom": "Dangers naturels", "genre": "crue",
		"resume": "Ce que la crue a laissé dans la ville"},
	{"id": "chantiers", "nom": "Chantiers", "genre": "chantiers",
		"resume": "Ce qui est cassé, ce qui est en travaux"},
	# `_classe_solaire` et non `part_toit_equipe` : un diagnostic répond « où
	# agir ? », et la part posée vaut 0 partout au mois 0.
	{"id": "energie", "nom": "Énergie", "genre": "calque",
		"couche": "i", "champ": "_classe_solaire",
		"resume": "Où le solaire s'amortit dans la partie",
		"bas": "Amorti vite", "haut": "Jamais rentable",
		"note": "Gris : pas de toit équipable — hors jeu, pas mauvais."},
	{"id": "trafic", "nom": "Trafic", "genre": "calque",
		"couche": "r", "champ": "charge",
		"resume": "La charge des rues, après la crue",
		"bas": "Rue calme", "haut": "Saturée"},
	{"id": "tissu", "nom": "Tissu urbain", "genre": "tissu",
		"resume": "Une teinte par type de tissu"},
]

## "" = la ville vivante. Sinon l'`id` d'un thème de THEMES.
var theme := ""


func _theme_actif() -> Dictionary:
	for t in THEMES:
		if t["id"] == theme:
			return t
	return {}


func _genre() -> String:
	return str(_theme_actif().get("genre", ""))


# 🎨 LE THÈME « TISSU » — 2026-08-18. Depuis que les bâtiments sont rendus par
# MATÉRIAU, la couleur ne dit plus la typologie : ce thème repeint la ville
# avec la palette d'avant, le temps d'un coup d'œil. Il passe par le MÊME
# uniforme `calque` que les thèmes continus, donc l'AO bakée survit et deux
# repeints ne peuvent pas se superposer.
var _teintes_tissu := {}


## Le seul aiguillage des deux vues. `id` vide ramène à la ville vivante ;
## sinon c'est un `id` de THEMES, et il chasse le précédent parce qu'il n'y a
## qu'une case — l'exclusion mutuelle n'est plus écrite nulle part.
func _sur_theme(id: String) -> void:
	if id == theme:
		return
	theme = id
	var t := _theme_actif()
	if id != "" and t.is_empty():
		push_error("thème inconnu : %s" % id)
		theme = ""
		t = {}
	var genre := str(t.get("genre", ""))

	if genre == "tissu" and _teintes_tissu.is_empty():
		for f in (donnees["objets"]["ilots"] as Dictionary):
			var st: String = donnees["objets"]["ilots"][f]["sous_type"]
			# ⚠ Palette en sRGB, uniforme en LINÉAIRE : sans conversion le
			# repeint ressort délavé (cf. `vers_lineaire` côté Python).
			_teintes_tissu[int(f)] = Donnees.teinte(
				donnees, st, Color.MAGENTA).srgb_to_linear()

	calque_couche = str(t.get("couche", ""))
	calque_champ = str(t.get("champ", ""))
	if calque_champ != "":
		_calibrer_echelle()

	# La ville vivante n'entre pas dans la maquette blanche : arbres, voitures,
	# eau et terrain la quittent ensemble, sinon le thème se lit sur un décor.
	_habiller_monde(id != "")
	_diagnostic_marqueurs.visible = genre == "crue"
	interface.montrer_theme(id, t)
	# 🔄 RETOUR EN ARRIÈRE SIGNALÉ : ouvrir la crue ou les chantiers recadrait
	# sur la ville entière. La caméra NE BOUGE PLUS — c'est ce qui rend les
	# deux vues comparables, et un avant/après lisible sans recadrer à la main.
	_dernier_peint = -1.0
	_rafraichir(true)


## Échelle fixée sur l'état de DÉPART (leçon de `parties.html`) : sinon chaque
## pas de temps recalcule l'extrémum et rien ne semble bouger. La PEINTURE,
## elle, reste au mois courant.
func _calibrer_echelle() -> void:
	if ETENDUES_FIXES.has(calque_champ):
		_etendue = ETENDUES_FIXES[calque_champ]
		return
	var lo := INF
	var hi := -INF
	for fid in noeuds[calque_couche]:
		var v := _val(calque_couche, fid, 0.0)
		lo = minf(lo, v)
		hi = maxf(hi, v)
	_etendue = [lo, hi if hi > lo else lo + 1.0]


## Ce que la maquette blanche éteint. Le TERRAIN et l'EAU restent — sans eux
## les deux rives disparaissent et le thème « dangers » n'a plus de sujet —
## mais ils passent au gris, comme le carton du reste.
func _habiller_monde(diagnostic: bool) -> void:
	trafic.visible = not diagnostic
	for n in monde.get_children():
		if n is MultiMeshInstance3D and str(n.name).begins_with("Arbres"):
			n.visible = not diagnostic
	var terrain := monde.get_node_or_null("Terrain") as MeshInstance3D
	if terrain != null:
		# `surface()` peint par couleur de sommet ; l'albédo la MULTIPLIE.
		(terrain.material_override as StandardMaterial3D).albedo_color = \
			Color(0.66, 0.66, 0.66) if diagnostic else Color.WHITE
	var eau := monde.get_node_or_null("Eau") as MeshInstance3D
	if eau != null:
		(eau.material_override as StandardMaterial3D).albedo_color = \
			Color(0.30, 0.33, 0.36) if diagnostic \
			else Donnees.teinte(donnees, "riviere")


func _val(couche: String, fid: int, t: float) -> float:
	# `ville.valeur` sert aussi les champs dérivés (`_`) : fiche, ciblage et
	# calques voient le même nombre par le même chemin.
	return ville.valeur(couche, fid, calque_champ, t)


func _peindre() -> void:
	var genre := _genre()
	var blanche := theme != ""
	for couche in ["i", "r", "b"]:
		for fid in noeuds[couche]:
			var mi: MeshInstance3D = noeuds[couche][fid]
			var diagnostic_sol := 0.0
			var diagnostic_bati := 0.0
			if genre == "crue":
				var o: Dictionary = ville.objets(couche).get(fid, {})
				if couche == "i":
					if float(o.get("hauteur_eau_max", 0.0)) > 0.10:
						diagnostic_sol = 1.0
					if float(o.get("part_sinistree", 0.0)) > 0.0:
						diagnostic_bati = 1.0
				else:
					diagnostic_sol = 2.0 if str(o.get("etat_crue", "")) == "coupe" \
						else (1.0 if float(o.get("hauteur_eau", 0.0)) > 0.10 else 0.0)
			var c := Color(1.0, 1.0, 1.0, 0.0)
			# 🌊 L'ÉTAT D'UNE BERGE SE VOIT SANS OUVRIR SA FICHE, et c'est tout
			# l'intérêt d'en avoir fait un objet. Le calque est libre sur cette
			# couche : aucun thème ne la peint.
			if couche == "b":
				c = BERGE_TEINTES[ville.berge_etat(fid, mois)]
			elif genre == "tissu" and couche == "i":
				c = _teintes_tissu.get(fid, Color.MAGENTA)
				# 1,0 et pas 0,88 : ce thème REMPLACE le carton. Une opacité
				# partielle laisserait le gris teinter chaque sous_type.
				c.a = 1.0
			elif genre == "calque" and calque_couche == couche \
					and _disponible(couche, fid):
				c = _rampe(_val(couche, fid, mois))
				c.a = 1.0
			var etat_travaux := ville.etat_chantier(couche, fid, mois) \
				if genre == "chantiers" else 0
			# Le nœud réparé prend les MÊMES paramètres que celui qu'il
			# recouvre : sans ça un îlot reconstruit sortirait du thème, ne se
			# surlignerait plus au survol, n'accepterait plus de panneaux — et
			# sortirait vert par le dessus, rouge par le dessous.
			# 🅿️ La file peinte s'efface AVEC la décision, pas à la livraison :
			# `stationnement` descend en rampe, et la rue se dégarnit.
			if couche == "r" and places_rue.has(fid):
				(places_rue[fid] as MeshInstance3D).visible = \
					ville.valeur("r", fid, "stationnement", mois) > 0.5
			for mj in [mi, reparations[couche].get(fid),
					places_rue.get(fid) if couche == "r" else null]:
				if mj == null:
					continue
				mj.set_instance_shader_parameter("maquette_blanche",
					1.0 if blanche else 0.0)
				mj.set_instance_shader_parameter("diagnostic_sol", diagnostic_sol)
				mj.set_instance_shader_parameter("diagnostic_bati", diagnostic_bati)
				mj.set_instance_shader_parameter("chantier_etat", float(etat_travaux))
				mj.set_instance_shader_parameter("calque", c)
				mj.set_instance_shader_parameter("teinte", _teinte(couche, fid))
				if couche == "b":
					# 🔴 LA TEINTE DIT UN CHANGEMENT, PAS UN ÉTAT. Une berge de
					# campagne naît « renaturée » : la peindre en vert dessinait
					# un ruban le long des champs, alors que rien n'a été fait.
					var e := ville.berge_etat(fid, mois)
					mj.set_instance_shader_parameter("etat_berge",
						0.0 if e == ville.berge_depart(fid) else float(e))
				if couche == "i":
					# La preuve que quelque chose s'est passé sans ouvrir un
					# menu : les toits se couvrent au fil de la pose.
					mj.set_instance_shader_parameter("equipe",
						ville.valeur("i", fid, "part_toit_equipe", mois))
					# 🌿 Le second usage du même toit. `part_plate` dit au
					# shader ce qui est plat dans CET îlot : sans elle il
					# poserait du substrat sur les versants.
					mj.set_instance_shader_parameter("verdi",
						ville.valeur("i", fid, "part_toit_vert", mois))
					mj.set_instance_shader_parameter("part_plate",
						ville.valeur("i", fid, "_part_plate", mois))



func _batir_marqueurs_crue() -> void:
	_diagnostic_marqueurs = Node3D.new()
	_diagnostic_marqueurs.name = "RoutesBloquees"
	_diagnostic_marqueurs.visible = false
	monde.add_child(_diagnostic_marqueurs)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color8(220, 58, 48)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for fid in ville.routes:
		if str(ville.routes[fid].get("etat_crue", "")) != "coupe":
			continue
		var cle := str(fid)
		if not (donnees["couloirs"] as Dictionary).has(cle):
			continue
		var parties: Array = donnees["couloirs"][cle][1]
		if parties.is_empty():
			continue
		var axe: Array = parties[0]
		var k := int(axe.size() / 4) * 2
		var marqueur := Node3D.new()
		marqueur.name = "Route%d" % fid
		marqueur.position = Vector3(float(axe[k]), 7.0, float(axe[k + 1]))
		_diagnostic_marqueurs.add_child(marqueur)
		for angle in [-45.0, 45.0]:
			var barre := MeshInstance3D.new()
			var boite := BoxMesh.new()
			boite.size = Vector3(22.0, 0.9, 2.0)
			barre.mesh = boite
			barre.material_override = mat
			barre.rotation_degrees.y = angle
			marqueur.add_child(barre)


func _disponible(couche: String, fid: int) -> bool:
	if not DISPO.has(calque_champ):
		return true
	return ville.valeur(couche, fid, DISPO[calque_champ], 0.0) > 0.0


## ✏️ LE CONTOUR DE SÉLECTION, en trois pièces.
##
## ① une petite vue à part (`masque`) où l'objet choisi est redessiné SEUL, en
##   blanc plat sur du vide, avec la même caméra que l'image principale ;
## ② un rectangle plein écran (`rect_contour`) dont le shader allume les
##   pixels qui touchent le bord de ce masque — voir `Materiaux.contour` ;
## ③ la synchronisation de la caméra, faite à chaque image dans `_maj_contour`.
##
## ⚠️ La vue a SON PROPRE MONDE (`own_world_3d`) : ni ciel, ni lumière, ni
## reste de la ville, donc un fond vraiment transparent.
##
## 🔴 Calque à 0, sous l'interface (1) : un trait par-dessus les fiches se
## lirait comme un défaut d'affichage.
func _batir_contour() -> void:
	masque = SubViewport.new()
	masque.name = "MasqueSelection"
	masque.own_world_3d = true
	masque.transparent_bg = true
	# Adouci ici une fois, plutôt que dans le shader : sinon le trait sort en
	# escalier sur les diagonales, et un pignon à 45° est le cas le plus courant.
	masque.msaa_3d = Viewport.MSAA_4X
	# Rien à rendre tant que rien n'est choisi.
	masque.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(masque)

	cam_masque = Camera3D.new()
	cam_masque.name = "CameraMasque"
	cam_masque.projection = Camera3D.PROJECTION_ORTHOGONAL
	masque.add_child(cam_masque)

	maille_masque = MeshInstance3D.new()
	maille_masque.name = "Silhouette"
	maille_masque.material_override = Materiaux.masque()
	masque.add_child(maille_masque)

	# L'emprise au sol, pour les îlots seuls. Deux nœuds plutôt qu'un maillage
	# fusionné : la silhouette change à chaque sélection, la plaque est gardée.
	maille_emprise = MeshInstance3D.new()
	maille_emprise.name = "Emprise"
	maille_emprise.material_override = maille_masque.material_override
	masque.add_child(maille_emprise)

	var calque := CanvasLayer.new()
	calque.name = "Contour"
	calque.layer = 0
	add_child(calque)

	rect_contour = ColorRect.new()
	rect_contour.name = "Trait"
	rect_contour.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect_contour.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect_contour.visible = false
	rect_contour.material = Materiaux.contour(masque.get_texture(), CONTOUR_COULEUR)
	calque.add_child(rect_contour)


## Un îlot se détoure tel qu'il est rendu ; les deux objets linéaires prennent
## une emprise simple : le couloir pour une rue, la projection pour une berge.
##
## 🔴 Un tronçon n'est pas une surface : chaussée + mètres libres + un bout de
## trottoir par riverain, trois choses disjointes séparées de 2,6 m sur le
## tronçon 120, donc trois bandes parallèles au lieu d'une rue. `07` exporte
## pour ça le COULOIR (axe et largeur façade à façade), dont on fait un ruban
## plat jamais affiché. Le maillage est gardé : il ne dépend que de la carte.
##
## ⚠️ Pas rattrapable dans le shader : l'écart est en MÈTRES et le trait en
## PIXELS, donc un rebouchage tiendrait à un zoom et lâcherait au suivant.
func _silhouette(couche: String, fid: int) -> Mesh:
	if couche == "b":
		if not _berges_contour.has(fid):
			_berges_contour[fid] = _aplatir(
				(noeuds[couche][fid] as MeshInstance3D).mesh)
		return _berges_contour[fid]
	if couche != "r":
		return (noeuds[couche][fid] as MeshInstance3D).mesh
	if _couloirs.has(fid):
		return _couloirs[fid]
	var tous: Dictionary = donnees["couloirs"]
	var cle := str(fid)
	if not tous.has(cle):
		# Les quatre tronçons `rive` font 0 m de large : ni couloir, ni trait,
		# et pas cliquables non plus.
		return null
	var c: Array = tous[cle]
	# Posé à 0 : dans son propre monde, le ruban n'a aucune profondeur à
	# disputer.
	var m := Constructeur.couloir(c[1] as Array, float(c[0]), 0.0)
	_couloirs[fid] = m
	return m


## Le mur et le parapet d'une berge se décalent à l'écran avec leur hauteur et
## donnaient plusieurs traits. Leur projection au sol garde une seule emprise.
func _aplatir(source: Mesh) -> ArrayMesh:
	var resultat := ArrayMesh.new()
	for surface in range(source.get_surface_count()):
		var tableaux := source.surface_get_arrays(surface)
		var sommets: PackedVector3Array = tableaux[Mesh.ARRAY_VERTEX]
		for i in range(sommets.size()):
			sommets[i].y = 0.0
		tableaux[Mesh.ARRAY_VERTEX] = sommets
		resultat.add_surface_from_arrays(
			source.surface_get_primitive_type(surface), tableaux)
	return resultat


## Posée à plat dans le masque À CÔTÉ de la silhouette rendue, elle ferme les
## trous : le sol d'un îlot bâti n'est dessiné nulle part (c'est la plaque de
## terrain qui passe dessous), donc le trait laissait le gris dehors.
## Le maillage est gardé : il ne dépend que de la carte.
func _emprise(fid: int) -> Mesh:
	if _plaques.has(fid):
		return _plaques[fid]
	var tous: Dictionary = donnees["emprises"]
	var cle := str(fid)
	# Les îlots d'eau n'en ont pas : ni cliquables ni sélectionnables.
	var m: Mesh = null if not tous.has(cle) else Constructeur.emprise(tous[cle])
	_plaques[fid] = m
	return m


## 🧱 LE SOCLE DE LA MINIATURE : la plaque de la fiche, épaisse. Gardé À PART de
## celle du masque — une jupe déborderait le trait de sélection — et gardé tout
## court : il ne dépend que de la carte. Une berge n'en a pas.
func _socle(couche: String, fid: int) -> Mesh:
	var cle := "%s%d" % [couche, fid]
	if _socles.has(cle):
		return _socles[cle]
	var m: Mesh = null
	if couche == "i":
		var tous: Dictionary = donnees["emprises"]
		if tous.has(str(fid)):
			m = Constructeur.socle_anneau(tous[str(fid)], EPAISSEUR_SOCLE)
	elif couche == "r":
		var tous: Dictionary = donnees["couloirs"]
		if tous.has(str(fid)):
			var c: Array = tous[str(fid)]
			m = Constructeur.socle_ruban(c[1] as Array, float(c[0]),
				EPAISSEUR_SOCLE)
	_socles[cle] = m
	return m


## Appelé à chaque image. Ce qui coûte est la vue à part, d'où son extinction
## complète (`UPDATE_DISABLED` + rectangle caché) sans sélection.
func _maj_contour() -> void:
	if rect_contour == null or pivot == null or selection == null:
		return
	var couche: String = selection.sel_couche
	var fid: int = selection.sel_fid
	if fid < 0 or not noeuds.has(couche) or not noeuds[couche].has(fid):
		if _contour_fid != -1:
			_contour_fid = -1
			_contour_couche = ""
			maille_masque.mesh = null
			maille_emprise.mesh = null
			rect_contour.visible = false
			masque.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return

	if fid != _contour_fid or couche != _contour_couche:
		_contour_fid = fid
		_contour_couche = couche
		maille_masque.mesh = _silhouette(couche, fid)
		# Une rue n'a pas d'emprise : son couloir EST déjà d'un seul tenant.
		maille_emprise.mesh = _emprise(fid) if couche == "i" else null
		rect_contour.visible = true
		masque.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	# Exactement la taille de l'image, sinon le trait se décale du bâtiment au
	# redimensionnement.
	var taille: Vector2i = get_viewport().get_visible_rect().size
	if masque.size != taille:
		masque.size = taille
		rect_contour.material.set_shader_parameter("pas",
			Vector2(1.0 / maxf(float(taille.x), 1.0),
			1.0 / maxf(float(taille.y), 1.0)))
		rect_contour.material.set_shader_parameter("rayon", CONTOUR_PX)

	# LA caméra recopiée : c'est ça, et rien d'autre, qui fait que le trait
	# épouse la vue.
	cam_masque.global_transform = pivot.camera.global_transform
	cam_masque.size = pivot.camera.size
	cam_masque.near = pivot.camera.near
	cam_masque.far = pivot.camera.far


## 🔎 LA MINIATURE SUIT LA FICHE, PAS LA SÉLECTION : c'est la fiche qui porte le
## réglage pas encore validé, et c'est lui que la miniature doit montrer.
##
## 🔴 Elle ne reçoit que des maillages DÉJÀ construits — celui de la ville, celui
## de la reconstruction, la plaque de l'emprise. Rien n'est fabriqué ici.
func _maj_apercu() -> void:
	if apercu == null or interface == null:
		return
	var d := interface.apercu_demande()
	var couche: String = d["couche"]
	var fid: int = d["fid"]
	if fid < 0 or not noeuds.has(couche) or not noeuds[couche].has(fid):
		apercu.eteindre()
		_apercu_fid = -1
		_apercu_couche = ""
		return
	if fid != _apercu_fid or couche != _apercu_couche:
		_apercu_fid = fid
		_apercu_couche = couche
		_apercu_voitures = ""   # changer d'objet repose les voitures
		# 🔧 UN PONT CASSÉ RESTE MONTRÉ PAR LA VILLE : un morceau droit ne sait
		# pas dire une travée tombée, et c'est justement ce que la fiche propose
		# de rebâtir. Tout le reste de la voirie passe par l'échantillon.
		var casse: bool = couche == "r" \
			and str(ville.routes[fid].get("etat_crue", "")) == "coupe"
		if couche == "i" or casse:
			var neuf: MeshInstance3D = reparations[couche].get(fid)
			apercu.montrer((noeuds[couche][fid] as MeshInstance3D).mesh,
				neuf.mesh if neuf != null else null, _socle(couche, fid))
		else:
			apercu.echantillon(couche, ville.objets(couche).get(fid, {}),
				_voie_de_berge(fid) if couche == "b" else 0.0)
	apercu.viser(pivot.lacet)
	apercu.regler(float(d["equipe"]), float(d["verdi"]), float(d["plate"]),
		bool(d["futur"]), float(d["berge"]))
	# Les voitures du morceau montré. La signature évite de les reposer à chaque
	# image : elles ne changent qu'au survol ou au mois. Un pont cassé n'en a
	# pas — sa miniature est un bout de ville, pas un échantillon.
	if couche != "r" or trafic == null or apercu.ech_longueur <= 0.0:
		return
	# 🌳 Les arbres du morceau, à la MÊME densité au mètre que la rue réelle —
	# la règle des places de stationnement, appliquée aux troncs. C'est ce qui
	# fait que la miniature promet ce que la ville livrera.
	var lg: float = maxf(float(ville.routes[fid].get("longueur_m", 0.0)), 1.0)
	apercu.planter(int(roundf(float(ville.arbres_a(fid, float(d["arbres"])))
		/ lg * apercu.ech_longueur)))
	var signe := "%d %d %d %d" % [fid, int(d["places"]), int(d["roule"]),
		int(mois * 4.0)]
	if signe == _apercu_voitures:
		return
	_apercu_voitures = signe
	trafic.remplir_droit(apercu.mm_gare, apercu.mm_roule, apercu.mm_pieton,
		apercu.mm_velo, fid, mois,
		bool(d["places"]), bool(d["roule"]), apercu.ech_longueur,
		apercu.ech_chaussee)


## 🌊 La chaussée de la voie qu'une berge porte : la moyenne de ses tronçons.
## C'est elle que l'échantillon pose derrière la rive — mesurée, pas choisie.
func _voie_de_berge(fid: int) -> float:
	var total := 0.0
	var n := 0
	for r in (ville.berges.get(fid, {}).get("rues", []) as Array):
		if ville.routes.has(int(r)):
			total += Echantillon.chaussee(ville.routes[int(r)])
			n += 1
	return total / float(n) if n > 0 else float(
		Echantillon.EMPRISE_CIRCULATION["rive"])


func _teinte(couche: String, fid: int) -> Color:
	if selection and couche == selection.sel_couche and fid == selection.sel_fid:
		return CHOISI
	if selection and couche == selection.survol_couche and fid == selection.survol_fid:
		return SURVOL
	return Color.WHITE


func _rampe(v: float) -> Color:
	var t: float = clampf((v - _etendue[0]) / (_etendue[1] - _etendue[0]), 0.0, 1.0)
	var x: float = t * (RAMPE.size() - 1)
	var j: int = mini(int(floor(x)), RAMPE.size() - 2)
	# Rampe écrite en sRGB, shader en LINÉAIRE.
	return RAMPE[j].lerp(RAMPE[j + 1], x - j).srgb_to_linear()


# ------------------------------------------------------------- les décisions

func _sur_survol(_couche: String, _fid: int) -> void:
	_dernier_peint = -1.0


func _sur_choix(couche: String, fid: int) -> void:
	if fid >= 0:
		interface.montrer(couche, fid, false)
	_dernier_peint = -1.0


## 🔴 LE SEUL GESTE DE DÉCISION DU JEU. La fiche a laissé poser des réglages,
## la miniature a montré l'avant et l'après ; ici on engage tout d'un coup. Le
## noyau vérifie la caisse UNE FOIS et dit non une fois — c'est lui qui refuse,
## jamais l'interface.
##
## 🔧 La géométrie neuve, elle, n'apparaît qu'à la FIN du chantier : c'est
## `_montrer_reparations` qui la découvre, au fil du temps. Même règle pour la
## berge, dont la teinte porte les trois crans, et pour les arbres, qui sortent
## de terre au rythme de la canopée.
func _sur_commande(couche: String, fid: int, reglages: Dictionary) -> void:
	var r := ville.commander(couche, fid, reglages, mois)
	if not bool(r["ok"]):
		print("%s %d · refusé : %.0f k€ demandés, il manque %.0f k€"
			% [_nom_couche(couche), fid, r["cout_ke"], r["manque"]])
		return
	# ⚠️ Le report de trafic vit dans `trafic.gd`, qui touche des nœuds : le
	# noyau le renvoie au lieu de l'appliquer.
	if bool(r["axe"]):
		trafic.retirer_axe(fid, mois)
	print("%s %d · %s engagé%s : %.0f k€ · %.0f mois · caisse %.0f k€"
		% [_nom_couche(couche), fid, ", ".join(PackedStringArray(r["faits"]))
			+ (", axe fermé" if bool(r["axe"]) else ""),
		"s" if (r["faits"] as Array).size() + int(bool(r["axe"])) > 1 else "",
		r["cout_ke"], ville.duree_commande_mois(couche, fid, reglages, mois),
		ville.caisse_ke(mois)])
	interface.confirmer_solaire(float(r["cout_ke"]))
	_dernier_peint = -1.0
	_rafraichir(true)


static func _nom_couche(couche: String) -> String:
	return {"i": "îlot", "r": "rue", "b": "berge"}.get(couche, couche)


## La pause est volontaire : sans elle, un retour demandé en ×12 recommence à
## défiler avant qu'on ait regardé.
func _sur_reset() -> void:
	ville.reinitialiser()
	trafic.reinitialiser()
	mois = 0.0
	_sur_vitesse(0.0)
	interface.remis_a_zero()
	print("retour au mois 0 · poses annulées, ville comme au chargement")
	_dernier_peint = -1.0
	_rafraichir(true)


func _sur_vitesse(nouvelle: float) -> void:
	vitesse = nouvelle
	if nouvelle > 0.0:
		_derniere_vitesse = nouvelle


# ------------------------------------------------------------------ le reste

func _repere(nom: String) -> void:
	var r: Dictionary = donnees["reperes"]
	if not r.has(nom):
		push_error("repère inconnu : %s" % nom)
		return
	var d: Dictionary = r[nom]
	var c: Array = d["cible"]
	pivot.viser(Vector2(float(c[0]), float(c[1])), float(d["taille"]))


## 🔴 UN SOMMET DU MAILLAGE, PAS LE CENTRE DE SA BOÎTE : une berge est une ligne
## courbe, et le centre de son AABB tombe au milieu de l'Ilse — le rayon du
## contrôle du clic n'y touchait rien du tout.
## ⚠️ Le sommet le plus proche du barycentre, et pas « celui du milieu » :
## l'ordre des sommets suit l'émission (mur, puis bande), donc le milieu du
## tableau tombait ailleurs dès qu'on ajoutait une surface.
func _viser_objet(couche: String, fid: int, taille: float) -> void:
	var mi: MeshInstance3D = noeuds[couche][fid]
	var sommets: PackedVector3Array = (mi.mesh as ArrayMesh).surface_get_arrays(
		0)[Mesh.ARRAY_VERTEX]
	var moy := Vector3.ZERO
	for v in sommets:
		moy += v
	moy /= float(sommets.size())
	var c: Vector3 = sommets[0]
	for v in sommets:
		if v.distance_squared_to(moy) < c.distance_squared_to(moy):
			c = v
	c += mi.global_position
	pivot.viser(Vector2(c.x, c.z), taille)


## Laisser passer du temps D'ÉCRAN sans avancer le mois : les voitures roulent,
## la ville ne change pas.
func _laisser_rouler(secondes: float) -> void:
	var reste := secondes
	while reste > 0.0:
		await get_tree().process_frame
		reste -= get_process_delta_time()


func _viser_route(fid: int, taille: float) -> void:
	var parties: Array = donnees["couloirs"][str(fid)][1]
	var axe: Array = parties[0]
	var k := int(axe.size() / 4) * 2
	pivot.viser(Vector2(float(axe[k]), float(axe[k + 1])), taille)


func _route_calme() -> int:
	for fid in ville.routes:
		var o: Dictionary = ville.routes[fid]
		var q := ville.valeur("r", fid, "charge", 0.0)
		if str(o.get("hierarchie", "")) == "rue" and q >= 0.10 and q <= 0.18 \
				and ville.valeur("r", fid, "stationnement", 0.0) >= 10.0 \
				and donnees["couloirs"].has(str(fid)):
			return fid
	return 55


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not (e as InputEventKey).pressed \
			or (e as InputEventKey).echo:
		return
	match (e as InputEventKey).keycode:
		KEY_SPACE: _sur_vitesse(_derniere_vitesse if vitesse == 0.0 else 0.0)
		KEY_V: _repere("ville")
		KEY_B: _repere("barre")
		KEY_R: _repere("quai")
		KEY_I: _repere("ilse")
		KEY_G: _repere("berge")
		KEY_O: _repere("pont")
		KEY_M: _repere("place")
		KEY_K: _repere("compact")
		# 🌊 La crue (23b) : le faubourg sinistré, et le pont qu'elle a emporté.
		KEY_F: _repere("faubourg")
		KEY_N: _repere("pont_casse")
		KEY_F3: moniteur_performances.basculer()
		KEY_P: _capturer("vue")
		KEY_ESCAPE: get_tree().quit()


## La miniature de la fiche, à sa taille de rendu.
func _capturer_apercu(nom: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := apercu.get_texture().get_image()
	var dossier := ProjectSettings.globalize_path(RENDUS)
	DirAccess.make_dir_recursive_absolute(dossier)
	var chemin := dossier + "wehrau_%s.png" % nom
	var err := img.save_png(chemin)
	if err != OK:
		push_error("capture impossible : %s (erreur %d)" % [chemin, err])
	else:
		print("capture → %s" % chemin)


func _capturer(nom: String) -> void:
	# ⚠ `--headless` a un pilote de rendu factice : aucune image n'en sortira.
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var dossier := ProjectSettings.globalize_path(RENDUS)
	DirAccess.make_dir_recursive_absolute(dossier)
	var chemin := dossier + "wehrau_%s.png" % nom
	var err := img.save_png(chemin)
	if err != OK:
		push_error("capture impossible : %s (erreur %d)" % [chemin, err])
	else:
		print("capture → %s" % chemin)
