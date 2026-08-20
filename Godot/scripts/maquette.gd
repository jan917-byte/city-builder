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
#   C      recolorer par tissu
#   F3     afficher / masquer les performances
#   Échap  quitter
#
# 🔄 Caméra libre depuis le 2026-08-17 (clic droit glissé) : le déplacement est
# passé au clic milieu. Voir `camera_axo.gd` pour ce que ça coûte.
# 🔄 Les touches 1..4 exagéraient le relief ; la carte est plate depuis le
# 2026-08-12.
#
# ⚠️ Les 6 îlots de rivière ne sont pas cliquables : fusionnés dans le maillage
# d'eau, avec son matériau.

const Donnees := preload("res://scripts/donnees.gd")
const Constructeur := preload("res://scripts/constructeur.gd")
const Materiaux := preload("res://scripts/materiaux.gd")
const CameraAxo := preload("res://scripts/camera_axo.gd")
const Ville := preload("res://scripts/ville.gd")
const Selection := preload("res://scripts/selection.gd")
const Interface := preload("res://scripts/interface.gd")
const MoniteurPerformances := preload("res://scripts/moniteur_performances.gd")

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
# 🔴 CE QUI FAIT QU'UN TRONÇON EST UN SEUL BLOC : une rue est faite de morceaux
# disjoints (chaussée, trottoirs à 10 cm, un bout par riverain) et le trait
# entourait chacun. Élargir le masque referme toute couture plus étroite.
# Voir `Materiaux.contour`.
const CONTOUR_BOUCHE_PX := 2.0
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
var mat_objet: ShaderMaterial
var masque: SubViewport
var cam_masque: Camera3D
var maille_masque: MeshInstance3D
var maille_emprise: MeshInstance3D
var rect_contour: ColorRect
var _contour_fid := -1
var _contour_couche := ""
var _couloirs := {}
var _plaques := {}

var noeuds := {"i": {}, "r": {}}
var mois := 0.0
var vitesse := 1.0
var _derniere_vitesse := 1.0
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
	_decor()

	pivot = CameraAxo.new()
	pivot.name = "Pivot"
	add_child(pivot)
	_repere("ville")

	selection = Selection.new()
	selection.name = "Selection"
	selection.camera = pivot.camera
	selection.survole.connect(_sur_survol)
	selection.choisi.connect(_sur_choix)
	add_child(selection)

	interface = Interface.new()
	interface.name = "Interface"
	interface.ville = ville
	add_child(interface)
	interface.batir()
	interface.solaire_demande.connect(_sur_solaire)
	interface.vitesse_demandee.connect(_sur_vitesse)
	interface.temps_remis.connect(_sur_reset)
	pivot.vue_changee.connect(interface.maj_camera)
	interface.maj_camera(pivot.lacet, pivot.hauteur)

	moniteur_performances = MoniteurPerformances.new()
	moniteur_performances.name = "MoniteurPerformances"
	add_child(moniteur_performances)
	# Les captures jugent la ville, pas l'ordinateur qui les prend.
	moniteur_performances.batir(not "--essai" in OS.get_cmdline_user_args())

	_batir_contour()

	var c: Dictionary = donnees["controles"]
	print("Wehrau — %d îlots, %d tronçons, %d cliquables, %d triangles"
		% [int(c["ilots"]), int(c["routes"]),
		noeuds["i"].size() + noeuds["r"].size(), int(c["triangles"])])
	_rafraichir(true)

	if "--essai" in OS.get_cmdline_user_args():
		await _essai()


## Une passe sans souris, pour juger sur des captures plutôt que de mémoire.
##
## 🔄 C'était le CONTRÔLE DE RECOUPEMENT avec `08_jouer.py` avant le
## 2026-08-12 ; il est parti avec D07 dans `Godot/archive/essai_d07.gd.txt`.
## Ce qui reste regarde la ville et vérifie qu'elle est cliquable.
##
##   Godot_console.exe --path Godot -- --essai
func _essai() -> void:
	# Des mois reproductibles, quelle que soit la vitesse de la machine.
	vitesse = 0.0
	print("
ESSAI — la ville, sans décision")
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

	# Le seul geste du prototype, vérifié sur la barre : mi-pose puis 100 %.
	var caisse_avant := ville.caisse_ke(mois)
	ville.lancer_solaire(32, 1.0, mois)
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
	_sur_reset()

	# 🎨 LE CALQUE « TISSU », capturé plutôt que décrit : deux images d'affilée,
	# la ville en matériaux puis repeinte par tissu, sont le seul moyen de juger
	# si l'échange vaut le coup.
	# On DÉSÉLECTIONNE d'abord : sur une paire destinée à juger des MATÉRIAUX,
	# un objet éclairci passerait pour un matériau de plus.
	selection.sel_fid = -1
	selection.sel_couche = ""
	_repere("ville")
	pivot.caler(30.0, 55.0)
	_dernier_peint = -1.0
	_rafraichir(true)
	await get_tree().process_frame
	await _capturer("essai_materiaux")
	_sur_tissu()
	print("  calque tissu (touche C) : %d îlots repeints par sous_type"
		% _teintes_tissu.size())
	await get_tree().process_frame
	await _capturer("essai_tissu")
	_sur_tissu()

	get_tree().quit()


## 🎚️ LE compte rendu qui sert à régler `CAISSE_DEPART_KE` et
## `DOTATION_KE_MOIS` : sans lui les deux se règlent à l'aveugle.
## Les amortissements sont rangés par tissu parce que c'est LÀ qu'est la
## décision — une barre de 1974 et un cœur ancien ne se remboursent pas dans le
## même siècle.
##
## Rend le fid de l'îlot que la caisse ne peut PAS payer, ou −1 : c'est celui
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
	_par_objet("Ilots", [donnees["masses"], donnees["sols"]], "i")
	_par_objet("Routes", [donnees["voirie"]], "r")

	var liste: Array = (donnees["arbres"] as Array).duplicate()

	# 🌳 Les arbres d'alignement avaient disparu de l'écran avec D07 (66) alors
	# qu'ils n'en dépendent pas : leur seuil se compare à `routes.canopee`, une
	# donnée de départ. On n'affiche que ceux dont le seuil est atteint à t0.
	var rts: Dictionary = donnees["objets"]["routes"]
	for f in (donnees["alignements"] as Dictionary):
		var cano: float = float(rts[f]["canopee"]) if rts.has(f) else 0.0
		for a in (donnees["alignements"][f] as Array):
			if float(a[5]) <= cano:
				# Un alignement est d'une seule essence, et feuillu : personne
				# ne plante une haie d'épicéas en ville.
				liste.append([a[0], a[1], a[2], a[3], a[4],
					Constructeur.FEUILLU])

	if liste.size() > 0 and not _ignore("Arbres"):
		var vert := Donnees.teinte(donnees, "_feuillage").srgb_to_linear()
		var brun := Donnees.teinte(donnees, "_tronc")
		for essence in [Constructeur.FEUILLU, Constructeur.CONIFERE]:
			# Variation de VALEUR sur la même teinte, pas une deuxième couleur
			# dans la palette (Direction artistique l.67).
			var t := vert if essence == Constructeur.FEUILLU \
				else Color(vert.r * 0.70, vert.g * 0.80, vert.b * 0.76)
			var mm := Constructeur.arbres(liste, essence, t, brun)
			if mm.instance_count == 0:
				continue
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "Arbres%d" % essence
			# ⚠️ PAS de `material_override` : il écraserait les deux surfaces
			# de l'arbre et le tronc ressortirait vert.
			mmi.multimesh = mm
			monde.add_child(mmi)
			print("  arbres   %-8s %5d instances"
				% ["conifère" if essence == Constructeur.CONIFERE
					else "feuillu", mm.instance_count])


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
			mi.name = "%s%d" % ["I" if couche == "i" else "R", fid]
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

	var l := DirectionalLight3D.new()
	l.name = "Soleil"
	# Assez haute pour qu'aucune ombre ne noie un îlot, assez basse pour que
	# les volumes se détachent.
	l.rotation_degrees = Vector3(-48.0, -125.0, 0.0)
	l.light_color = Donnees.teinte(donnees, "_soleil")
	# 🔄 Monté le 2026-08-18 pendant que l'ambiant baissait : la somme ne bouge
	# presque pas, c'est le PARTAGE soleil/ciel qui change. Ce contraste est ce
	# qui fait lire un enduit crème comme crème et non comme gris.
	l.light_energy = 1.45
	l.shadow_enabled = true
	l.directional_shadow_max_distance = 3000.0
	add_child(l)


# ------------------------------------------------------------------ le temps

func _process(delta: float) -> void:
	mois = minf(mois + delta * vitesse * MOIS_PAR_SECONDE, Ville.HORIZON_MOIS)
	_rafraichir(false)


func _rafraichir(force: bool) -> void:
	# Hors du raccourci ci-dessous : le trait suit la CAMÉRA, qui bouge même
	# quand le temps est en pause.
	_maj_contour()
	if not force and absf(mois - _dernier_peint) < 0.002:
		interface.maj(ville.indicateurs(mois), mois, vitesse)
		return
	_dernier_peint = mois
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


# 🎨 LE CALQUE « TISSU », touche C — 2026-08-18. Depuis que les bâtiments sont
# rendus par MATÉRIAU, la couleur ne dit plus la typologie : cette touche
# repeint la ville avec la palette d'avant, le temps d'un coup d'œil.
# Il passe par le MÊME uniforme `calque` que les calques thématiques, donc
# l'AO bakée survit et deux repeints ne peuvent pas se superposer.
var calque_tissu := false
var _teintes_tissu := {}


func _sur_tissu() -> void:
	calque_tissu = not calque_tissu
	if calque_tissu:
		calque_couche = ""
		calque_champ = ""
		if _teintes_tissu.is_empty():
			for f in (donnees["objets"]["ilots"] as Dictionary):
				var st: String = donnees["objets"]["ilots"][f]["sous_type"]
				# ⚠ Palette en sRGB, uniforme en LINÉAIRE : sans conversion le
				# repeint ressort délavé (cf. `vers_lineaire` côté Python).
				_teintes_tissu[int(f)] = Donnees.teinte(
					donnees, st, Color.MAGENTA).srgb_to_linear()
	_dernier_peint = -1.0
	_rafraichir(true)


func _sur_calque(couche: String, champ: String) -> void:
	calque_tissu = false
	calque_couche = couche
	calque_champ = champ
	if ETENDUES_FIXES.has(champ):
		_etendue = ETENDUES_FIXES[champ]
	elif champ != "":
		# Échelle fixée sur l'état de DÉPART (leçon de `parties.html`) : sinon
		# chaque pas de temps recalcule l'extrémum et rien ne semble bouger.
		# La PEINTURE, elle, reste au mois courant.
		var lo := INF
		var hi := -INF
		for fid in noeuds[couche]:
			var v := _val(couche, fid, 0.0)
			lo = minf(lo, v)
			hi = maxf(hi, v)
		_etendue = [lo, hi if hi > lo else lo + 1.0]
	_dernier_peint = -1.0
	_rafraichir(true)


func _val(couche: String, fid: int, t: float) -> float:
	# `ville.valeur` sert aussi les champs dérivés (`_`) : fiche, ciblage et
	# calques voient le même nombre par le même chemin.
	return ville.valeur(couche, fid, calque_champ, t)


func _peindre() -> void:
	for couche in ["i", "r"]:
		for fid in noeuds[couche]:
			var mi: MeshInstance3D = noeuds[couche][fid]
			var c := Color(1.0, 1.0, 1.0, 0.0)
			if calque_tissu and couche == "i":
				c = _teintes_tissu.get(fid, Color.MAGENTA)
				# 1,0 et pas 0,88 : ce calque REMPLACE la matière. À 0,92 le
				# rouge des tuiles transparaît et le cœur ancien sort orange.
				c.a = 1.0
			elif calque_champ != "" and calque_couche == couche \
					and _disponible(couche, fid):
				c = _rampe(_val(couche, fid, mois))
				c.a = 0.88
			mi.set_instance_shader_parameter("calque", c)
			mi.set_instance_shader_parameter("teinte", _teinte(couche, fid))
			if couche == "i":
				# La preuve que quelque chose s'est passé sans ouvrir un menu :
				# les toits se couvrent au fil de la pose.
				mi.set_instance_shader_parameter("equipe",
					ville.valeur("i", fid, "part_toit_equipe", mois))


func _disponible(couche: String, fid: int) -> bool:
	if not DISPO.has(calque_champ):
		return true
	return ville.valeur(couche, fid, DISPO[calque_champ], 0.0) > 0.0


## ✏️ LE CONTOUR DE SÉLECTION, en trois pièces.
##
## ① une petite vue à part (`masque`) où l'îlot choisi est redessiné SEUL, en
##   blanc plat sur du vide, avec la même caméra que l'image principale ;
## ② un rectangle plein écran (`rect_contour`) dont le shader allume les
##   pixels qui touchent le bord de ce masque — voir `Materiaux.contour` ;
## ③ la synchronisation de la caméra, faite à chaque image dans `_maj_contour`.
##
## ⚠️ La vue a SON PROPRE MONDE (`own_world_3d`) : ni ciel, ni lumière, ni
## reste de la ville, donc un fond vraiment transparent. Le maillage n'est pas
## copié — la même ressource, avec un matériau qui la peint en blanc.
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


## Un îlot se détoure tel qu'il est rendu ; une RUE, non — seule exception du
## fichier.
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
		rect_contour.material.set_shader_parameter("bouche", CONTOUR_BOUCHE_PX)

	# LA caméra recopiée : c'est ça, et rien d'autre, qui fait que le trait
	# épouse la vue.
	cam_masque.global_transform = pivot.camera.global_transform
	cam_masque.size = pivot.camera.size
	cam_masque.near = pivot.camera.near
	cam_masque.far = pivot.camera.far


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


func _sur_solaire(fid: int, part: float) -> void:
	if not ville.lancer_solaire(fid, part, mois):
		return
	var etat := ville.etat_solaire(fid, mois)
	print("îlot %d · panneaux solaires → %.0f %% en %.1f mois · %.0f k€ · caisse %.0f k€"
		% [fid, part * 100.0, etat["reste_mois"], etat["cout_ke"], ville.caisse_ke(mois)])
	interface.confirmer_solaire(float(etat["cout_ke"]))
	_dernier_peint = -1.0
	_rafraichir(true)


## La pause est volontaire : sans elle, un retour demandé en ×12 recommence à
## défiler avant qu'on ait regardé.
func _sur_reset() -> void:
	ville.reinitialiser()
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
		KEY_C: _sur_tissu()
		KEY_F3: moniteur_performances.basculer()
		KEY_P: _capturer("vue")
		KEY_ESCAPE: get_tree().quit()


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
