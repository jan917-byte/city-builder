extends Node3D
# Wehrau — l'orchestrateur.
#
# Ce n'est plus une maquette : on clique, on décide, le temps passe. Le noyau
# est dans `ville.gd` et `chantiers.gd`, qui ne connaissent aucun nœud ; ici on
# ne fait que brancher les uns aux autres.
#
# Tout est construit en code : la scène ne contient qu'un nœud et ce script
# (`Génération procédurale.md:47`).
#
# CLAVIER
#   clic   sélectionner un îlot ou une rue
#   Espace lecture / pause          V B R   les trois points de vue
#   1..4   exagération verticale    Q / E   rotation de 90°
#   P      capture PNG              Échap   quitter
#
# ⚠️ Les 6 îlots de rivière ne sont pas cliquables : ils restent fusionnés dans
# un seul maillage d'eau, avec leur matériau. La rivière est hors sujet pour
# l'instant.

const Donnees := preload("res://scripts/donnees.gd")
const Constructeur := preload("res://scripts/constructeur.gd")
const Materiaux := preload("res://scripts/materiaux.gd")
const CameraAxo := preload("res://scripts/camera_axo.gd")
const Ville := preload("res://scripts/ville.gd")
const Chantiers := preload("res://scripts/chantiers.gd")
const Selection := preload("res://scripts/selection.gd")
const Interface := preload("res://scripts/interface.gd")

const RENDUS := "res://../QGIS/rendus/"
const EXAGERATIONS := [1.0, 1.5, 2.0, 3.0]

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
var chantiers: Chantiers
var selection: Selection
var interface: Interface
var mat_objet: ShaderMaterial

var noeuds := {"i": {}, "r": {}}
var mois := 0.0
var en_lecture := false
var vitesse := 4.0
var exageration := 1.0
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
	chantiers = Chantiers.new(ville)

	mat_objet = Materiaux.objet()
	monde = Node3D.new()
	monde.name = "Monde"
	add_child(monde)
	_construire()
	_decor()

	pivot = CameraAxo.new()
	pivot.name = "Pivot"
	add_child(pivot)
	_repere("vallee")

	selection = Selection.new()
	selection.name = "Selection"
	selection.camera = pivot.camera
	selection.survole.connect(_sur_survol)
	selection.choisi.connect(_sur_choix)
	add_child(selection)

	interface = Interface.new()
	interface.name = "Interface"
	interface.ville = ville
	interface.chantiers = chantiers
	add_child(interface)
	interface.batir()
	interface.decide.connect(_sur_decision)
	interface.temps_demande.connect(func(t: float) -> void: mois = t)
	interface.lecture_basculee.connect(func() -> void: en_lecture = not en_lecture)
	interface.vitesse_demandee.connect(func(v: float) -> void:
		vitesse = v
		en_lecture = true)
	interface.calque_demande.connect(_sur_calque)

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
	print("
ESSAI — la ville, sans décision")
	_repere("vallee")
	await get_tree().process_frame
	await _capturer("essai_vallee")

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
	get_tree().quit()


# ------------------------------------------------------------- construction

func _construire() -> void:
	var mat := Materiaux.surface()

	# `.srgb_to_linear()` : ces teintes finissent en couleur de SOMMET, comme
	# celles que 07 a déjà converties. Sans ça elles ressortent délavées.
	_fusionne("Terrain", Constructeur.terrain(donnees["terrain"],
		Donnees.teinte(donnees, "_mineral_clair").srgb_to_linear()), mat)
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
	if en_lecture:
		mois = minf(mois + delta * vitesse, Ville.HORIZON_MOIS)
		if mois >= Ville.HORIZON_MOIS:
			en_lecture = false
	_rafraichir(false)


func _rafraichir(force: bool) -> void:
	if not force and absf(mois - _dernier_peint) < 0.002:
		interface.maj(mois, en_lecture, ville.indicateurs(mois))
		return
	_dernier_peint = mois
	_peindre()
	interface.maj(mois, en_lecture, ville.indicateurs(mois))


# --------------------------------------------------------------- la couleur

func _sur_calque(couche: String, champ: String) -> void:
	calque_couche = couche
	calque_champ = champ
	if champ != "":
		# L'échelle est fixée sur l'état de DÉPART, pas sur l'état courant :
		# sinon chaque pas de temps recalculerait l'extrémum et rien ne
		# semblerait bouger. C'est la leçon de `parties.html`.
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
	# Les calques DÉRIVÉS (un `_` en tête) passeront par ici : la surchauffe le
	# faisait, la rentabilité solaire et le gain d'isolation le feront. Un champ
	# du `.gpkg` se lit directement, un champ calculé se branche ci-dessus.
	return ville.valeur(couche, fid, calque_champ, t)


func _peindre() -> void:
	for couche in ["i", "r"]:
		for fid in noeuds[couche]:
			var mi: MeshInstance3D = noeuds[couche][fid]
			var c := Color(1.0, 1.0, 1.0, 0.0)
			if calque_champ != "" and calque_couche == couche:
				c = _rampe(_val(couche, fid, mois))
				c.a = 0.88
			mi.set_instance_shader_parameter("calque", c)
			mi.set_instance_shader_parameter("teinte", _teinte(couche, fid))


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
	if selection.survol_fid >= 0:
		interface.montrer(selection.survol_couche, selection.survol_fid)
	_dernier_peint = -1.0


func _sur_choix(couche: String, fid: int) -> void:
	if fid >= 0:
		interface.montrer(couche, fid, false)
	_dernier_peint = -1.0


func _sur_decision(id: String, fids: Array) -> void:
	var r: Dictionary = chantiers.engager(id, fids, mois)
	if not r["ok"]:
		interface.dire(r["message"])
		return
	var cible := "1 tronçon" if fids.size() == 1 else "%d tronçons" % fids.size()
	interface.dire("%s sur %s : %.0f pts, capital %+.0f"
		% [chantiers.DECISIONS[id]["nom"], cible, r["cout"], r["capital"]])
	print("mois %.1f — %s ×%d : %.0f pts, capital %+.1f, %.0f m"
		% [mois, id, fids.size(), r["cout"], r["capital"], r["quantite"] * 100.0])
	_dernier_peint = -1.0
	_rafraichir(true)


# ------------------------------------------------------------------ le reste

func _repere(nom: String) -> void:
	var r: Dictionary = donnees["reperes"]
	if not r.has(nom):
		push_error("repère inconnu : %s" % nom)
		return
	var d: Dictionary = r[nom]
	var c: Array = d["cible"]
	pivot.viser(Vector2(float(c[0]), float(c[1])), float(d["taille"]))


## L'exagération s'applique à TOUT le modèle, terrain et bâti ensemble — c'est
## la convention d'une maquette de relief. Ne dilater que le sol ferait
## décoller les bâtiments.
##
## ⚠️ Constaté le 2026-08-12 : la vallée ne se lit à AUCUN des quatre facteurs.
## 9 m de relief sur 898 m de large, vus en axonométrie à angle fixe — le
## facteur n'y peut rien. Ça se réglera par l'ombre ou par la caméra.
func _exagerer(k: float) -> void:
	exageration = k
	monde.scale = Vector3(1.0, k, 1.0)


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not (e as InputEventKey).pressed \
			or (e as InputEventKey).echo:
		return
	match (e as InputEventKey).keycode:
		KEY_SPACE: en_lecture = not en_lecture
		KEY_V: _repere("vallee")
		KEY_B: _repere("barre")
		KEY_R: _repere("quai")
		KEY_1: _exagerer(EXAGERATIONS[0])
		KEY_2: _exagerer(EXAGERATIONS[1])
		KEY_3: _exagerer(EXAGERATIONS[2])
		KEY_4: _exagerer(EXAGERATIONS[3])
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
