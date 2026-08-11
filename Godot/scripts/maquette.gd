extends Node3D
# Wehrau à t0 — l'orchestrateur.
#
# Tout est construit en code : la scène ne contient qu'un nœud et ce script.
# Aucun état visuel n'est posé à la main dans une scène — c'est la règle
# générale du projet (`Génération procédurale.md:47`), et elle vaut aussi
# pour la maquette.
#
# CLAVIER
#   V      la vallée          }  une touche par critère de réussite :
#   B      la barre de 1974   }  on ne juge pas de mémoire
#   R      les rues à 20 et 22 m
#   1..4   exagération verticale ×1 ×1,5 ×2 ×3
#   Q / E  rotation de 90°      molette  zoom      clic droit  panoramique
#   P      capture PNG dans QGIS/rendus/
#
# Lancement avec capture automatique des trois points de vue :
#   Godot_..._console.exe --path Godot/ -- --capture

# `preload` plutôt que `class_name` : les classes globales n'existent qu'une
# fois le projet indexé par l'éditeur. Un clone frais lancé en ligne de
# commande ne les a pas, et échoue en « Identifier not declared ». Ceci marche
# toujours.
const Donnees := preload("res://scripts/donnees.gd")
const Constructeur := preload("res://scripts/constructeur.gd")
const Materiaux := preload("res://scripts/materiaux.gd")
const CameraAxo := preload("res://scripts/camera_axo.gd")

const RENDUS := "res://../QGIS/rendus/"
const EXAGERATIONS := [1.0, 1.5, 2.0, 3.0]

var donnees: Dictionary
var monde: Node3D
var pivot: CameraAxo
var exageration := 1.0


func _ready() -> void:
	donnees = Donnees.charger()
	if donnees.is_empty():
		get_tree().quit(1)
		return

	monde = Node3D.new()
	monde.name = "Monde"
	add_child(monde)

	_construire()
	_decor()

	pivot = CameraAxo.new()
	pivot.name = "Pivot"
	add_child(pivot)
	_repere("vallee")

	var c: Dictionary = donnees["controles"]
	print("Wehrau t0 — %d îlots, %d tronçons, %d triangles, %d arbres"
		% [int(c["ilots"]), int(c["routes"]), int(c["triangles"]),
		int(c["arbres"])])

	if "--capture" in OS.get_cmdline_user_args():
		_capturer_tout()


func _construire() -> void:
	var mat := Materiaux.surface()

	# `.srgb_to_linear()` : ces deux teintes finissent en couleur de SOMMET,
	# comme celles que 07 a déjà converties. Sans ça elles ressortent délavées.
	_ajouter("Terrain", Constructeur.terrain(donnees["terrain"],
		Donnees.teinte(donnees, "_mineral_clair").srgb_to_linear()), mat)
	_ajouter("Voirie", Constructeur.maillage(donnees["voirie"]), mat)
	_ajouter("Sols", Constructeur.maillage(donnees["sols"]), mat)
	_ajouter("Masses", Constructeur.maillage(donnees["masses"]), mat)
	_ajouter("Eau", Constructeur.maillage(donnees["eau"]),
		Materiaux.eau(Donnees.teinte(donnees, "riviere")))

	var liste: Array = donnees["arbres"]
	if liste.size() > 0:
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Arbres"
		mmi.multimesh = Constructeur.arbres(liste,
			Donnees.teinte(donnees, "_feuillage").srgb_to_linear())
		mmi.material_override = Materiaux.feuillage()
		monde.add_child(mmi)


func _ajouter(nom: String, m: ArrayMesh, mat: Material) -> void:
	# `-- --solo=Sols` n'affiche qu'une famille. Sert à répondre « est-ce
	# qu'elle se rend ? » par l'expérience plutôt que par le raisonnement.
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--solo=") and a.substr(7) != nom:
			print("  %-8s ignoré (--solo)" % nom)
			return
	var n := MeshInstance3D.new()
	n.name = nom
	n.mesh = m
	n.material_override = mat
	monde.add_child(n)
	# Contrôle imprimé, comme les scripts QGIS : un maillage vide ou hors
	# cadre doit se voir dans la console, pas se deviner à l'écran.
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


func _repere(nom: String) -> void:
	var r: Dictionary = donnees["reperes"]
	if not r.has(nom):
		push_error("repère inconnu : %s" % nom)
		return
	var d: Dictionary = r[nom]
	var c: Array = d["cible"]
	pivot.viser(Vector2(float(c[0]), float(c[1])), float(d["taille"]))
	print("→ %s" % d["libelle"])


## L'exagération s'applique à TOUT le modèle, terrain et bâti ensemble.
##
## C'est la convention d'une maquette de relief, et c'est volontaire : ne
## dilater que le sol ferait décoller les bâtiments. Le relief de Wehrau ne
## fait que 9 m sur 898 — 1:100 — contre 27 m pour la barre. À ×1 la vallée
## risque de ne pas se sentir ; c'est l'arbitrage du premier soir, et il se
## fait devant l'image, pas dans le vide.
func _exagerer(k: float) -> void:
	exageration = k
	monde.scale = Vector3(1.0, k, 1.0)
	print("exagération verticale ×%.1f" % k)


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not (e as InputEventKey).pressed \
			or (e as InputEventKey).echo:
		return
	match (e as InputEventKey).keycode:
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
	# La capture exige une fenêtre.
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var dossier := ProjectSettings.globalize_path(RENDUS)
	DirAccess.make_dir_recursive_absolute(dossier)
	var chemin := dossier + "maquette_%s.png" % nom
	var err := img.save_png(chemin)
	if err != OK:
		push_error("capture impossible : %s (erreur %d)" % [chemin, err])
	else:
		print("capture → %s" % chemin)


func _capturer_tout() -> void:
	for nom in ["vallee", "barre", "quai"]:
		_repere(nom)
		await get_tree().process_frame
		await _capturer(nom)
	get_tree().quit()
