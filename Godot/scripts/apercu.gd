extends SubViewport
# 🔎 LA MINIATURE DE LA FICHE (décision 12) : l'objet choisi, seul, montré dans
# l'état qui SERA livré. La ville, elle, garde son état réel jusqu'à la fin du
# chantier — c'est tout le partage entre les deux images.
#
# 🔴 UN ÎLOT EST LE MAILLAGE DE LA VILLE, repris par référence, avec le même
# matériau et les mêmes uniformes d'instance : une vignette dessinée à part
# mentirait dès la recette suivante.
# 🔄 UNE RUE ET UNE BERGE, NON, depuis le 2026-08-31 : elles sont montrées par
# un ÉCHANTILLON droit (`echantillon.gd`), aux largeurs mesurées et du bon
# type. Un morceau de ville en tenait mal la promesse — un ruban qui tourne,
# une berge sans eau ni sol autour. Ce qui est montré n'est plus l'endroit,
# c'est l'aménagement.
#
# Son monde est à lui (`own_world_3d`) : ni ville autour, ni thème, ni contour.

const Materiaux := preload("res://scripts/materiaux.gd")
const Constructeur := preload("res://scripts/constructeur.gd")
const Echantillon := preload("res://scripts/echantillon.gd")

## Le format de la miniature dans la fiche : 320 px de panneau moins ses deux
## marges de 12 px. La fiche s'y accorde — elle lit cette constante.
const TAILLE := Vector2i(296, 168)
## 🔴 RENDUE TROIS FOIS PLUS GRANDE, puis réduite par la fiche. Les fenêtres et
## les rangs de tuiles sont des motifs qui s'effacent sous ~1,5 px : à 296 px de
## large, un étage fait 6 px et la façade sortait nue.
const SURECHANTILLON := 3
## 🔷 L'ANGLE ISOMÉTRIQUE, atan(1/√2) : le cube y montre ses trois faces à
## parts égales. À 46° la miniature était une vue de dessus inclinée — les toits
## écrasaient les façades. Elle ne descend pas plus bas : les panneaux solaires
## sont sur les TOITS, et à 6° on ne verrait que des murs.
const HAUTEUR := 35.264
## 🔴 COURT, et c'est une contrainte d'OMBRE : la carte d'ombre part de la
## caméra, un recul de 900 m mettait l'objet hors de sa portée et la miniature
## n'avait aucune ombre portée. En ortho, reculer ne change rien à l'image.
const RECUL := 60.0
const MARGE := 1.15      # l'objet ne touche pas le bord du cadre
## 🔴 CE QUE LE CADRE MONTRE AU PLUS POUR UN ÎLOT, en mètres de large. Mesuré le
## 2026-08-26 : 110 m de diamètre à la médiane, 220 m au neuvième décile. Au-delà,
## l'îlot est montré par son milieu.
const CADRE_MAX_M := 240.0
## La plaque passe SOUS le sol dessiné par 07 : au-dessus elle le raye.
const SOUS_LE_SOL := -0.20

var _cam: Camera3D
var _soleil: DirectionalLight3D
## Les voitures du morceau montré. Deux MultiMesh posés une fois, remplis par
## `trafic.remplir_droit` : la fiche n'invente ni recette ni teinte.
var mm_gare: MultiMesh
var mm_roule: MultiMesh
var mm_pieton: MultiMesh
var mm_velo: MultiMesh
## 🌳 Les arbres du morceau montré. Un MultiMesh refait quand leur nombre
## change — c'est LA moitié visible de l'avant/après d'une rue plantée.
var _arbres_mi: MultiMeshInstance3D
var _arbres_n := -1
## 🌿 Ce qui pousse sur la rive du morceau montré. Deux nœuds, une essence
## chacun : un MultiMesh ne répète qu'un seul maillage.
var _rives := {}
var _sol: MeshInstance3D
var _objet: MeshInstance3D
var _futur: MeshInstance3D
## 🧩 L'ÉCHANTILLON : ce qui n'est pas l'objet cliquable — l'eau, le sol, la
## voie de berge — et qui n'est donc jamais teinté par la fiche.
var _decor: MeshInstance3D
var _eau: MeshInstance3D
var _palette := {}
var _lacet := 0.0
var _vise := false       # le premier appel cadre toujours
## L'échantillon en cours : sa couche, sa fiche, la chaussée de sa voie, et
## l'état de berge déjà bâti — la géométrie d'une berge dépend de son état.
var _ech_couche := ""
var _ech_fiche := {}
var _ech_voie := 0.0
var _ech_etat := -1
## Les deux cotes du morceau bâti, lues par la maquette pour y poser les
## voitures. À zéro, la miniature ne montre pas d'échantillon.
var ech_longueur := 0.0
var ech_chaussee := 0.0
## Ce que le cadre doit contenir. Les points de la PLAQUE, montés au faîtage :
## les huit coins de la boîte englobante cadrent un îlot en biais sur sa
## diagonale, et l'objet ne remplit plus que la moitié du cadre.
var _points := PackedVector3Array()
## Le cap de l'objet au sol, en degrés : il commande la vue de trois quarts.
var _cap := 0.0


func batir(mat_objet: Material, palette: Dictionary) -> void:
	_palette = palette
	size = TAILLE * SURECHANTILLON
	own_world_3d = true
	transparent_bg = true
	# 2× et non 4× : le suréchantillonnage fait déjà le plus gros du lissage.
	msaa_3d = Viewport.MSAA_2X
	# Rien à rendre tant que rien n'est choisi.
	render_target_update_mode = SubViewport.UPDATE_DISABLED

	var we := WorldEnvironment.new()
	we.environment = Materiaux.environnement(_teinte("_ciel"), _teinte("_ambiant"))
	# 🔴 SANS SSAO. Il travaille en espace vue : dans un cadre de 100 m son
	# rayon de 2 m couvre le tiers de l'image et noircit les façades entières.
	# L'occlusion bakée par 07 dans la couleur de sommet tient seule.
	we.environment.ssao_enabled = false
	add_child(we)
	# 🔴 LA PORTÉE DE L'OMBRE SUIT LE CADRE, réglée à chaque cadrage. La carte
	# d'ombre part de la caméra et couvre toujours la même distance : figée sur
	# le plus grand cadre, ses texels font des mètres, et dans une fenêtre de
	# 35 m la plaque plate se marbrait de son propre relief.
	_soleil = Materiaux.soleil(_teinte("_soleil"), RECUL + 2.0 * CADRE_MAX_M)
	add_child(_soleil)

	_cam = Camera3D.new()
	_cam.name = "CameraApercu"
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.near = 0.05
	_cam.far = 4000.0
	add_child(_cam)

	# La plaque au sol d'un îlot. Le sol d'un îlot bâti n'est dessiné nulle
	# part — c'est le terrain qui passe dessous —, et sans elle l'objet flotte
	# sur du vide. Un échantillon, lui, porte son propre sol.
	_sol = MeshInstance3D.new()
	_sol.name = "Plaque"
	_sol.position.y = SOUS_LE_SOL
	var m := Materiaux.surface()
	m.albedo_color = _teinte("_mineral")
	# 🔴 ELLE NE REÇOIT PAS L'OMBRE. Posée 20 cm sous la chaussée, elle prenait
	# celle du bord de rue sur toute sa longueur — deux bandes noires le long du
	# trottoir. Ce qu'elle doit faire, c'est fermer le vide, pas se dessiner.
	m.disable_receive_shadows = true
	_sol.material_override = m
	add_child(_sol)

	mm_gare = Constructeur.voitures(0)
	mm_roule = Constructeur.voitures(0, true)
	mm_pieton = Constructeur.pietons(0)
	mm_velo = Constructeur.cyclistes(0)
	for mm in [mm_gare, mm_roule, mm_pieton, mm_velo]:
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Usagers"
		mmi.multimesh = mm
		# Comme dans la ville : un usager ne porte pas d'ombre.
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)

	_arbres_mi = MultiMeshInstance3D.new()
	_arbres_mi.name = "Arbres"
	add_child(_arbres_mi)

	for essence in [Constructeur.ROSEAU, Constructeur.BUISSON]:
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Rives%d" % essence
		add_child(mmi)
		_rives[essence] = mmi

	_objet = MeshInstance3D.new()
	_objet.name = "Objet"
	_objet.material_override = mat_objet
	add_child(_objet)

	# Le futur livré : la géométrie de reconstruction, celle-là même que la
	# ville découvrira à la fin du chantier.
	_futur = MeshInstance3D.new()
	_futur.name = "Futur"
	_futur.material_override = mat_objet
	add_child(_futur)

	_decor = MeshInstance3D.new()
	_decor.name = "Decor"
	_decor.material_override = mat_objet
	add_child(_decor)

	_eau = MeshInstance3D.new()
	_eau.name = "Eau"
	_eau.material_override = Materiaux.eau(_teinte("riviere"))
	add_child(_eau)

	# La miniature ne joue ni le thème, ni le calque, ni la sélection : elle
	# montre l'objet tel qu'il sera. Posé une fois, jamais repeint.
	for mi in [_objet, _futur, _decor]:
		mi.set_instance_shader_parameter("teinte", Color.WHITE)
		mi.set_instance_shader_parameter("calque", Color(1.0, 1.0, 1.0, 0.0))
		mi.set_instance_shader_parameter("maquette_blanche", 0.0)


## 🏘️ UN ÎLOT : les maillages de la ville, tels quels. `sol` est sa plaque.
func montrer(objet: Mesh, futur: Mesh, sol: Mesh) -> void:
	_vider_echantillon()
	_objet.mesh = objet
	_futur.mesh = futur
	_sol.mesh = sol
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_semer_points()
	_cadrer()


## 🧩 UNE RUE, UNE BERGE : le morceau droit. `voie_m` n'est lu que pour une
## berge — c'est la chaussée de la voie qu'elle porte, mesurée sur ses rues.
## L'état de la berge arrive juste après par `regler`, à la même image.
func echantillon(couche: String, fiche: Dictionary, voie_m := 0.0) -> void:
	_ech_couche = couche
	_ech_fiche = fiche
	_ech_voie = voie_m
	_ech_etat = -1
	_sol.mesh = null
	_futur.mesh = null
	# 🔴 Les voitures du morceau précédent ne suivent pas : elles se sont déjà
	# retrouvées garées le long d'une berge.
	vider_voitures()
	_batir_echantillon(0)
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# 🔴 CADRÉ UNE FOIS, sur l'état d'asphalte : les trois états d'une berge
	# n'ont pas la même hauteur (un parapet, puis une pente), et un cadre qui
	# bougerait au survol rendrait les trois captures incomparables.
	_semer_points()
	_cadrer()


func _batir_echantillon(etat: int) -> void:
	var e := {}
	if _ech_couche == "r":
		e = Echantillon.rue(_ech_fiche, _palette)
	elif _ech_couche == "b":
		e = Echantillon.berge(_ech_fiche, _ech_voie, _palette, etat)
	else:
		return
	_ech_etat = etat
	_objet.mesh = e["objet"]
	_decor.mesh = e["decor"]
	_eau.mesh = e["eau"]
	ech_longueur = float(e["longueur"])
	ech_chaussee = float(e["chaussee"])
	_semer_rive(e.get("rive", []) as Array)


## 🌿 LE SEMIS DE LA MINIATURE : la même touffe et le même buisson que la
## ville. Sans lui, la fiche montrerait un aplat vert là où l'écran montre une
## rive plantée, et l'AVANT/APRÈS ne dirait plus la même chose que la ville.
##
## 🔴 TIRAGE FIXE (nombre d'or) : deux captures du même état doivent être
## identiques au pixel, sinon les trois images de contrôle ne se comparent pas.
func _semer_rive(rive: Array) -> void:
	if _rives.is_empty():
		return
	var liste := []
	if rive.size() == 4 and ech_longueur > 0.0:
		var z0 := float(rive[0])
		var y0 := float(rive[1])
		var z1 := float(rive[2])
		var y1 := float(rive[3])
		# Les mêmes pas qu'à l'export : 2,2 m de roseaux, 7,5 m de buissons.
		for genre in [Constructeur.ROSEAU, Constructeur.BUISSON]:
			var pas := 2.2 if genre == Constructeur.ROSEAU else 7.5
			var n := maxi(1, int(ech_longueur / pas))
			for k in n:
				var x := (float(k) + 0.5) / float(n) * ech_longueur \
					- ech_longueur * 0.5
				var t: float = fmod(float(k) * 0.6180339887, 1.0)
				t = 0.10 + 0.50 * t if genre == Constructeur.ROSEAU \
					else 0.55 + 0.35 * t
				liste.append([x, lerpf(y0, y1, t), lerpf(z0, z1, t),
					0.85 + 0.35 * fmod(float(k) * 0.3819660113, 1.0),
					float(k) * 1.7, genre])
	var vert := _teinte("_feuillage").srgb_to_linear()
	var brun := _teinte("_tronc")
	for essence in _rives:
		var f: float = 1.22 if essence == Constructeur.ROSEAU else 0.74
		(_rives[essence] as MultiMeshInstance3D).multimesh = \
			Constructeur.arbres(liste, essence,
				Color(vert.r * f, vert.g * f, vert.b * f), brun)


func _vider_echantillon() -> void:
	_ech_couche = ""
	_ech_etat = -1
	ech_longueur = 0.0
	ech_chaussee = 0.0
	_decor.mesh = null
	_eau.mesh = null
	_semer_rive([])
	vider_voitures()


## 🌳 LES ARBRES DU MORCEAU DROIT. `n` est un COMPTE, celui que la fiche
## annonce : l'échantillon n'invente pas de densité, il place ce qu'on paie.
## ⚠️ Alternés d'un côté puis de l'autre, alors que la ville tire le côté au
## hasard : sur 40 m de rue, six arbres tous du même bord se liraient comme une
## haie et non comme un alignement.
func planter(n: int) -> void:
	if _arbres_mi == null or ech_longueur <= 0.0:
		return
	if n == _arbres_n:
		return
	_arbres_n = n
	var bord := ech_chaussee * 0.5 + 1.2
	var liste := []
	for k in n:
		@warning_ignore("integer_division")
		var rang: int = k / 2
		var cote := -1.0 if k % 2 else 1.0
		# Répartis sur la longueur, jamais sur les bouts de coupe : un tronc à
		# cheval sur la tranche montrerait la moitié d'un arbre.
		var x: float = (float(rang) + 0.5) / maxf(ceil(n / 2.0), 1.0) \
			* ech_longueur - ech_longueur * 0.5
		liste.append([x, 0.0, cote * bord, 0.95 + 0.2 * float(k % 3) / 2.0,
			float(k) * 1.7, Constructeur.FEUILLU])
	var vert := _teinte("_feuillage").srgb_to_linear()
	_arbres_mi.multimesh = Constructeur.arbres(liste, Constructeur.FEUILLU,
		vert, _teinte("_tronc"))


## Ce qui coûte est la vue à part : sans sélection, elle s'éteint entièrement.
func vider_voitures() -> void:
	mm_gare.instance_count = 0
	mm_roule.instance_count = 0
	mm_pieton.instance_count = 0
	mm_velo.instance_count = 0
	_arbres_n = -1
	if _arbres_mi != null:
		_arbres_mi.multimesh = null


func eteindre() -> void:
	if render_target_update_mode == SubViewport.UPDATE_DISABLED:
		return
	_vider_echantillon()
	_objet.mesh = null
	_futur.mesh = null
	_sol.mesh = null
	render_target_update_mode = SubViewport.UPDATE_DISABLED


## La miniature tourne avec la ville : sans ça, l'objet du panneau ne ressemble
## plus à celui qu'on vient de cliquer à l'écran.
func viser(lacet: float) -> void:
	if _vise and absf(lacet - _lacet) < 0.05:
		return
	_vise = true
	_lacet = lacet
	_cadrer()


## 🔴 L'EFFET INSTANTANÉ (décision 12) : ces trois nombres sont l'état VISÉ, pas
## l'état de la ville. `equipe` et `verdi` sont les deux parts de toit posées
## — elles se partagent un 100 %, et `plate` dit ce que la pente autorise au
## vert. `futur` découvre
## la géométrie reconstruite, `berge` pousse les trois crans de la rive — et
## sur un échantillon il en REFAIT la coupe : le quai recule, la rive s'ouvre.
func regler(equipe: float, verdi: float, plate: float, futur: bool,
		berge: float) -> void:
	if _ech_couche == "b" and int(berge) != _ech_etat:
		_batir_echantillon(int(berge))
	_futur.visible = futur and _futur.mesh != null
	for mi in [_objet, _futur]:
		mi.set_instance_shader_parameter("equipe", equipe)
		mi.set_instance_shader_parameter("verdi", verdi)
		mi.set_instance_shader_parameter("part_plate", plate)
		mi.set_instance_shader_parameter("etat_berge", berge)


## Les points à contenir, calculés UNE FOIS par objet : le cadrage se refait à
## chaque quart de tour, il ne peut pas relire des milliers de sommets.
func _semer_points() -> void:
	_points = PackedVector3Array()
	_cap = 0.0
	var b := AABB()
	var premier := true
	for mi in [_objet, _futur, _sol, _decor, _eau]:
		if mi.mesh == null:
			continue
		var a: AABB = (mi.mesh as Mesh).get_aabb()
		b = a if premier else b.merge(a)
		premier = false
	if premier:
		return
	# 🧩 L'échantillon est bâti le long de X, centré sur l'origine : sa boîte
	# EST son cadre, et son cap vaut zéro. Rien à chercher.
	if _ech_couche != "":
		for k in 8:
			_points.append(b.get_endpoint(k))
		return
	var bas := b.position.y
	var haut := b.position.y + b.size.y
	# La plaque de l'îlot quand il y en a une, sinon le maillage lui-même.
	var source: Mesh = _sol.mesh if _sol.mesh != null else _objet.mesh
	if source != null and source.get_surface_count() > 0:
		var som: PackedVector3Array = source.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		# 🔴 UN SOMMET SUR `pas` : ces points ne servent qu'à cadrer — l'axe et
		# le milieu n'en bougent pas d'un mètre.
		var pas: int = maxi(1, som.size() / 1200)
		for k in range(0, som.size(), pas):
			var v: Vector3 = som[k]
			_points.append(Vector3(v.x, bas, v.z))
			_points.append(Vector3(v.x, haut, v.z))
	if _points.is_empty():
		for k in 8:
			_points.append(b.get_endpoint(k))
	_cap = _direction(_points)


## Le cap d'un nuage au sol, en degrés : direction principale, vecteur propre
## dominant de sa covariance 2×2, qui se résout sans itération. Sur un îlot
## carré la direction est indifférente, et n'importe laquelle fait l'affaire.
static func _direction(lot: PackedVector3Array) -> float:
	var n := float(lot.size())
	var mx := 0.0
	var mz := 0.0
	for p in lot:
		mx += p.x
		mz += p.z
	mx /= n
	mz /= n
	var sxx := 0.0
	var szz := 0.0
	var sxz := 0.0
	for p in lot:
		var dx := p.x - mx
		var dz := p.z - mz
		sxx += dx * dx
		szz += dz * dz
		sxz += dx * dz
	if absf(sxz) <= 1e-6 and absf(sxx - szz) <= 1e-6:
		return 0.0
	return rad_to_deg(0.5 * atan2(2.0 * sxz, sxx - szz))


## 🔷 TOUJOURS DE TROIS QUARTS. Le lacet vaut `45° − cap` modulo 90° : dans le
## plan, l'objet croise alors l'écran en diagonale, jamais de face. Sans ça, les
## quatre vues cardinales de `Q`/`E` mettaient la rue et la façade à plat.
## On garde le quart de tour le plus proche de la ville : le panneau montre donc
## l'îlot du côté d'où on le regarde, à moins d'un huitième de tour près.
##
## 🔴 UN ÉCHANTILLON NE TOURNE PAS. Il n'est nulle part dans la ville, il n'y a
## donc rien à reconnaître — et un quart de tour sur deux mettait la berge de
## dos : le mur de quai regarde l'eau, et l'eau serait passée derrière le bloc.
const QUART_ECHANTILLON := 135.0


func _trois_quarts() -> float:
	if _ech_couche != "":
		return QUART_ECHANTILLON
	var vise := 45.0 - _cap
	return vise + 90.0 * roundf((_lacet - vise) / 90.0)


func _cadrer() -> void:
	if _points.is_empty():
		return
	_cam.rotation_degrees = Vector3(-HAUTEUR, _trois_quarts(), 0.0)
	var base := _cam.transform.basis
	# Le centre est celui de l'IMAGE, pas celui du volume : un objet cadré sur
	# le milieu de sa boîte se décale dès qu'on le regarde en biais.
	var x0 := INF
	var x1 := -INF
	var y0 := INF
	var y1 := -INF
	var z1 := -INF
	for p in _points:
		var u := p.dot(base.x)
		var v := p.dot(base.y)
		x0 = minf(x0, u)
		x1 = maxf(x1, u)
		y0 = minf(y0, v)
		y1 = maxf(y1, v)
		z1 = maxf(z1, p.dot(base.z))
	_cam.position = base.x * ((x0 + x1) * 0.5) + base.y * ((y0 + y1) * 0.5) \
		+ base.z * (z1 + RECUL)
	# En ortho, `size` est la hauteur vue : la largeur en découle par le format.
	var format := float(TAILLE.x) / float(TAILLE.y)
	_cam.size = minf(maxf(y1 - y0, (x1 - x0) / format) * MARGE,
		CADRE_MAX_M / format)
	_regler_ombre()


## Ce que le cadre couvre au sol : sa largeur, ou sa profondeur `size / sin` —
## en ortho la seconde est la plus grande dès que la vue est rasante.
func _regler_ombre() -> void:
	var etendue := maxf(_cam.size * float(TAILLE.x) / float(TAILLE.y),
		_cam.size / sin(deg_to_rad(HAUTEUR)))
	_soleil.directional_shadow_max_distance = RECUL + 2.0 * etendue


func _teinte(role: String) -> Color:
	if not _palette.has(role):
		push_error("miniature : rôle `%s` absent de la palette" % role)
		return Color.MAGENTA
	return Color(_palette[role] as String)
