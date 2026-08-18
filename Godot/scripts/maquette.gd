extends Node3D
# Wehrau — l'orchestrateur.
#
# Le prototype énergie tient provisoirement en un seul geste : cliquer un îlot
# et augmenter sa part de panneaux. La pose avance avec le temps ; budget et
# capital restent hors du test.
#
# Tout est construit en code : la scène ne contient qu'un nœud et ce script
# (`Génération procédurale.md:47`).
#
# CLAVIER
#   clic   sélectionner un îlot ou une rue
#                                  V B R I   les quatre points de vue
#   Q / E  quart de tour            P        capture PNG
#   ← → ↑ ↓  orienter la caméra     T        vue de dessus
#   Échap  quitter
#
# 🔄 Depuis le 2026-08-17 la caméra tourne librement (clic droit glissé) et son
# angle de site se règle : `camera_axo.gd` dit ce que ça préserve et ce que ça
# coûte. Le clic droit ne déplace donc plus la vue — c'est le clic milieu.
#
# 🔄 Les touches 1..4 exagéraient le relief. La carte est plate depuis le
# 2026-08-12 : il n'y a plus rien à exagérer.
#
# ⚠️ Les 6 îlots de rivière ne sont pas cliquables : ils restent fusionnés dans
# un seul maillage d'eau, avec leur matériau. La rivière est hors sujet pour
# l'instant.

const Donnees := preload("res://scripts/donnees.gd")
const Constructeur := preload("res://scripts/constructeur.gd")
const Materiaux := preload("res://scripts/materiaux.gd")
const CameraAxo := preload("res://scripts/camera_axo.gd")
const Ville := preload("res://scripts/ville.gd")
const Selection := preload("res://scripts/selection.gd")
const Interface := preload("res://scripts/interface.gd")

const RENDUS := "res://../QGIS/rendus/"

# 🔄 2026-08-17 — le temps allait soixante fois trop vite. Jusqu'ici `_process`
# ajoutait `delta * vitesse` aux mois : à ×1 une seconde valait un mois, donc
# les 240 mois du jeu défilaient en quatre minutes et la pose de trois mois
# passait avant qu'on ait relâché la souris. L'échelle de base est maintenant
# UNE MINUTE POUR UN MOIS ; `vitesse` garde son sens de multiplicateur, donc
# ×12 fait un an par minute et l'horizon complet vingt minutes.
const MOIS_PAR_SECONDE := 1.0 / 60.0

# La rampe des calques thématiques : bleu froid → jaune → rouge. La même que
# `06_etat_zero.py` et `parties.html`, pour qu'un calque se lise pareil dans
# les trois outils.
const RAMPE := [
	Color8(42, 74, 110), Color8(90, 140, 150),
	Color8(214, 190, 110), Color8(196, 84, 62),
]
# Des facteurs, pas des couleurs : ils multiplient la teinte de l'objet. Assez
# forts pour se voir sur un pastel clair, assez faibles pour ne pas le brûler.
const SURVOL := Color(1.15, 1.15, 1.08)
const CHOISI := Color(1.42, 1.38, 1.06)

var donnees: Dictionary
var monde: Node3D
var pivot: CameraAxo
var ville: Ville
var selection: Selection
var interface: Interface
var mat_objet: ShaderMaterial

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
	mat_objet = Materiaux.objet()
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

	var c: Dictionary = donnees["controles"]
	print("Wehrau — %d îlots, %d tronçons, %d cliquables, %d triangles"
		% [int(c["ilots"]), int(c["routes"]),
		noeuds["i"].size() + noeuds["r"].size(), int(c["triangles"])])
	_rafraichir(true)

	if "--essai" in OS.get_cmdline_user_args():
		await _essai()


## Une passe sans souris, pour juger sur des captures plutôt que de mémoire.
##
## ⚠️ Ce n'était pas ça avant le 2026-08-12 : c'était le CONTRÔLE DE
## RECOUPEMENT entre Godot et `08_jouer.py`, et il est parti avec D07 dans
## `Godot/archive/essai_d07.gd.txt`. Ce qui reste ici ne compare plus deux
## moteurs — ça regarde la ville, et ça vérifie qu'elle est toujours cliquable.
##
##   Godot_console.exe --path Godot -- --essai
func _essai() -> void:
	# Les captures doivent tomber à des mois reproductibles, quelle que soit la
	# vitesse réelle de la machine qui lance l'essai.
	vitesse = 0.0
	print("
ESSAI — la ville, sans décision")
	_repere("ville")
	pivot.caler(30.0, 32.0)
	await get_tree().process_frame
	await _capturer("essai_ville")

	# La même ville sous deux autres angles : c'est le contrôle de la caméra
	# ouverte du 2026-08-17. À 10° on doit voir une SILHOUETTE (et des façades
	# nues, c'est attendu) ; à 90° un plan, où le grain du parcellaire se lit.
	pivot.caler(210.0, 10.0)
	await get_tree().process_frame
	await _capturer("essai_silhouette")
	pivot.caler(30.0, 90.0)
	await get_tree().process_frame
	await _capturer("essai_dessus")
	pivot.caler(30.0, 32.0)

	# De près, sur la barre de 1974 : c'est là qu'on vérifie que les volumes
	# sont toujours des volumes après le découpage en nœuds — et que le clic
	# retrouve bien l'objet sous le curseur.
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

	# L'Ilse : le lit est creuse, la nappe doit etre nettement sous la
	# ville et les tabliers passer au-dessus sans y plonger.
	_repere("ilse")
	await get_tree().process_frame
	await _capturer("essai_ilse")

	var trop_cher := _essai_economie()

	# La capture du REFUS. Un bouton grisé ne prouve rien tout seul : ce qu'on
	# vient regarder ici, c'est la phrase rouge qui dit combien il manque.
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

	# Le seul geste du prototype, vérifié sur la barre : une capture à mi-pose
	# prouve que la jauge et les toits progressent, puis une autre à 100 %.
	var caisse_avant := ville.caisse_ke(mois)
	ville.lancer_solaire(32, 1.0, mois)
	var etat32 := ville.etat_solaire(32, mois)
	var cout32: float = etat32["cout_ke"]
	# La pose se paie COMPTANT, au mois de la décision : la caisse doit tomber
	# exactement du coût annoncé, ni plus (pas d'intérêt) ni moins (pas de
	# subvention). Si les deux ne collent pas, c'est que la dépense a été
	# comptée ailleurs qu'au moment où l'auteur a cliqué.
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
	# montrait PAS le toit dont elle prouvait la progression. Corrigé le
	# 2026-08-17, en même temps que le motif bleu des panneaux.
	_repere("barre")
	_dernier_peint = -1.0
	_rafraichir(true)
	var mi_pose := ville.etat_solaire(32, mois)
	# ⚠ Le reste attendu se DÉDUIT de la durée : il était écrit « 1,5 » en dur,
	# et raccourcir la pose faisait échouer l'essai sans que rien ne soit cassé.
	var reste_attendu := Ville.SOLAIRE_MOIS_POUR_100 / 2.0
	if absf(float(mi_pose["actuel"]) - 0.5) > 0.001 \
			or absf(float(mi_pose["reste_mois"]) - reste_attendu) > 0.001:
		push_error("pose solaire à mi-parcours incorrecte : %s" % mi_pose)
		get_tree().quit(1)
		return
	print("  mi-pose : 50 %% réalisés · %.2f mois restant ✅" % reste_attendu)
	# Un chantier engagé ne se révise pas. C'est ce verrou qui autorise les
	# rampes à s'additionner sans jamais réécrire l'histoire d'un toit — et
	# donc la recette encaissée, qui est l'intégrale de cette histoire.
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

	# Le retour au mois 0 doit tout défaire : le compteur, la part posée de
	# l'îlot 32 et la production de ville. Un seul de ces trois qui reste en
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

	get_tree().quit()


## Le tableau de la petite économie, au mois 0. C'est LE compte rendu qui sert
## à régler `CAISSE_DEPART_KE` et `DOTATION_KE_MOIS` : sans lui, les deux se
## règlent à l'aveugle, et on ne sait pas si le jeu est « dur mais possible »
## ou simplement bloqué.
##
## Les amortissements sont rangés par tissu parce que c'est LÀ qu'est la
## décision : une barre de 1974 et un cœur ancien ne se remboursent pas dans le
## même siècle, et c'est ce qui donne au joueur une raison de choisir.
##
## Rend le fid de l'îlot que la caisse ne peut PAS payer, ou −1 s'ils passent
## tous — c'est celui dont on capture le refus.
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

	# Le seul refus que le prototype sache prononcer, éprouvé plutôt que promis :
	# l'îlot le plus cher doit rester impossible, et la caisse ne doit pas
	# bouger d'un centime pendant qu'on essaie.
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

	# 🔄 Le terrain était un CHAMP D'ALTITUDE déplié ici en grille. La carte est
	# plate depuis le 2026-08-12 : c'est un maillage comme les autres, troué là
	# où passe le chenal de l'Ilse, et il porte ses couleurs comme le reste.
	# Les murs de quai et le fond du chenal sont dedans — pas dans l'eau, dont
	# le matériau est lisse et d'une seule teinte.
	_fusionne("Terrain", Constructeur.maillage(donnees["terrain"]), mat)
	_fusionne("Eau", Constructeur.maillage(donnees["eau"]),
		Materiaux.eau(Donnees.teinte(donnees, "riviere")))

	# Un nœud par objet : c'est ce qui rend la ville cliquable, surlignable et
	# teintable. On passe de 5 draw calls à ~250 — invisible sur 40 000
	# triangles, et sans ça il n'y a pas de jeu, seulement une image.
	_par_objet("Ilots", [donnees["masses"], donnees["sols"]], "i")
	_par_objet("Routes", [donnees["voirie"]], "r")

	var liste: Array = donnees["arbres"]
	if liste.size() > 0 and not _ignore("Arbres"):
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Arbres"
		mmi.multimesh = Constructeur.arbres(liste,
			Donnees.teinte(donnees, "_feuillage").srgb_to_linear())
		mmi.material_override = Materiaux.feuillage()
		monde.add_child(mmi)


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
	# Contrôle imprimé, comme les scripts QGIS : un maillage vide ou hors cadre
	# doit se voir dans la console, pas se deviner à l'écran.
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
	# Fixe et calme. Assez haute pour qu'aucune ombre ne noie un îlot, assez
	# basse pour que les volumes se détachent.
	l.rotation_degrees = Vector3(-48.0, -125.0, 0.0)
	l.light_color = Donnees.teinte(donnees, "_soleil")
	l.light_energy = 1.15
	l.shadow_enabled = true
	l.directional_shadow_max_distance = 3000.0
	add_child(l)


# ------------------------------------------------------------------ le temps

func _process(delta: float) -> void:
	mois = minf(mois + delta * vitesse * MOIS_PAR_SECONDE, Ville.HORIZON_MOIS)
	_rafraichir(false)


func _rafraichir(force: bool) -> void:
	if not force and absf(mois - _dernier_peint) < 0.002:
		interface.maj(ville.indicateurs(mois), mois, vitesse)
		return
	_dernier_peint = mois
	_peindre()
	interface.maj(ville.indicateurs(mois), mois, vitesse)


# --------------------------------------------------------------- la couleur

# Les calques dont l'échelle ne se MESURE pas : elle est connue d'avance.
# `_classe_solaire` peint quatre classes entières sur les quatre couleurs de la
# rampe, sans interpolation — un min/max sur les données mentirait si une
# classe est vide à t0, et c'est le recul de la zone rouge qu'on veut voir.
const ETENDUES_FIXES := {
	"_classe_solaire": [0.0, 3.0],
	"part_toit_equipe": [0.0, 1.0],
}

# Là où la décision est INDISPONIBLE, le calque ne peint rien. Un champ sans
# toit n'est pas « jamais rentable », il est HORS JEU — le peindre en rouge
# dirait le contraire de la table (« pas de toit, décision indisponible »).
# La disponibilité se juge sur l'état de DÉPART : un îlot entièrement isolé
# reste peint, son gain est simplement tombé au bleu froid.
const DISPO := {
	"_classe_solaire": "_toit_equipable_m2",
	"part_toit_equipe": "_toit_equipable_m2",
	"_gain_isolation_mwh": "_gain_isolation_mwh",
}


func _sur_calque(couche: String, champ: String) -> void:
	calque_couche = couche
	calque_champ = champ
	if ETENDUES_FIXES.has(champ):
		_etendue = ETENDUES_FIXES[champ]
	elif champ != "":
		# L'échelle est fixée sur l'état de DÉPART, pas sur l'état courant :
		# sinon chaque pas de temps recalculerait l'extrémum et rien ne
		# semblerait bouger. C'est la leçon de `parties.html`. La PEINTURE,
		# elle, reste au mois courant : c'est elle qui bouge sur l'échelle.
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
	# Les champs dérivés (un `_` en tête) sont servis par `ville.valeur`, qui
	# les délègue à l'énergie : la fiche, le ciblage des décisions et les
	# calques voient LE MÊME nombre par LE MÊME chemin. Rien à brancher ici.
	return ville.valeur(couche, fid, calque_champ, t)


func _peindre() -> void:
	for couche in ["i", "r"]:
		for fid in noeuds[couche]:
			var mi: MeshInstance3D = noeuds[couche][fid]
			var c := Color(1.0, 1.0, 1.0, 0.0)
			if calque_champ != "" and calque_couche == couche \
					and _disponible(couche, fid):
				c = _rampe(_val(couche, fid, mois))
				c.a = 0.88
			mi.set_instance_shader_parameter("calque", c)
			mi.set_instance_shader_parameter("teinte", _teinte(couche, fid))
			if couche == "i":
				# La preuve que quelque chose s'est passé, sans ouvrir un
				# menu : les toits noircissent au fil de la pose (le shader
				# ne touche que les faces hautes tournées vers le ciel).
				mi.set_instance_shader_parameter("equipe",
					ville.valeur("i", fid, "part_toit_equipe", mois))


func _disponible(couche: String, fid: int) -> bool:
	if not DISPO.has(calque_champ):
		return true
	return ville.valeur(couche, fid, DISPO[calque_champ], 0.0) > 0.0


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
	# Les couleurs de la rampe sont écrites en sRGB ; le shader les multiplie
	# par une occlusion LINÉAIRE et les rend en ALBEDO linéaire.
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


## Le retour au mois 0. La pause est volontaire : sans elle, un retour demandé
## en ×12 recommencerait à défiler avant qu'on ait eu le temps de regarder.
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
