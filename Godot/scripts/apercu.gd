extends SubViewport
# 🔎 LA MINIATURE DE LA FICHE (décision 12) : l'objet choisi, seul, montré dans
# l'état qui SERA livré. La ville, elle, garde son état réel jusqu'à la fin du
# chantier — c'est tout le partage entre les deux images.
#
# 🔴 AUCUNE GÉOMÉTRIE N'EST RECRÉÉE : les maillages sont CEUX de la ville,
# repris par référence, avec le même matériau et les mêmes uniformes
# d'instance. Une vignette dessinée à part mentirait dès la recette suivante.
#
# Son monde est à lui (`own_world_3d`) : ni ville autour, ni thème, ni contour.

const Materiaux := preload("res://scripts/materiaux.gd")
const Constructeur := preload("res://scripts/constructeur.gd")

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
## 🛣️ UNE RUE ET UNE BERGE NE SE CADRENT PAS EN ENTIER — c'est le seul moyen d'y
## lire un aménagement. Mesuré le 2026-08-28 : le tronçon médian fait 63 m de
## long pour 14,6 m de large (max 273 m), une berge 400 m sur quelques mètres ;
## cadrés en entier, ce sont des rubans. Le cadre prend donc une fenêtre carrée
## posée au MILIEU de l'objet, large de sa largeur en travers × ce facteur.
const ETALEMENT := 1.8
const FENETRE_MIN_M := 18.0
## 🔴 40 ET NON 60 : au-delà, aucun morceau de berge ne reste droit — le cadre
## remontrerait le virage qu'il cherche justement à éviter.
const FENETRE_MAX_M := 40.0
## 🛣️ CE QU'ON APPELLE DROIT : deux bouts d'axe ne s'écartent pas de plus de
## ça. Le cadre ne montre jamais un morceau qui tourne davantage — il montre un
## morceau plus court.
const ANGLE_DROIT := 6.0
## La tranche dans laquelle on range les sommets QUAND ON N'A PAS L'AXE — une
## berge n'en exporte pas. Plus fine, elle tombe sur des tranches vides ; plus
## large, elle avale le coude qu'elle doit voir.
const TRANCHE_M := 4.0
## La plaque passe SOUS le sol dessiné par 07 : au-dessus elle le raye.
const SOUS_LE_SOL := -0.20

var _cam: Camera3D
var _soleil: DirectionalLight3D
## Les voitures du tronçon montré. Deux MultiMesh posés une fois, remplis par
## `trafic.remplir` : la fiche n'invente ni recette ni teinte.
var mm_gare: MultiMesh
var mm_roule: MultiMesh
var _sol: MeshInstance3D
var _objet: MeshInstance3D
var _futur: MeshInstance3D
var _lacet := 0.0
var _vise := false       # le premier appel cadre toujours
## Un bout d'objet plutôt que l'objet entier : vrai pour une rue et une berge.
var _bout := false
var _centre := Vector3.ZERO   # le milieu de la fenêtre, en monde
var _fenetre := 0.0           # sa largeur au sol, en mètres
var _cap := 0.0               # le cap de l'objet au sol, en degrés
## Ce que le cadre doit contenir. Les points de la PLAQUE, montés au faîtage :
## les huit coins de la boîte englobante cadrent un îlot en biais sur sa
## diagonale, et l'objet ne remplit plus que la moitié du cadre.
var _points := PackedVector3Array()
## L'axe de l'objet quand 07 l'exporte (une rue), et sa largeur façade à façade.
var _axe := PackedVector2Array()
var _largeur := 0.0


func batir(mat_objet: Material, mineral: Color, ciel: Color, ambiant: Color,
		soleil: Color) -> void:
	size = TAILLE * SURECHANTILLON
	own_world_3d = true
	transparent_bg = true
	# 2× et non 4× : le suréchantillonnage fait déjà le plus gros du lissage.
	msaa_3d = Viewport.MSAA_2X
	# Rien à rendre tant que rien n'est choisi.
	render_target_update_mode = SubViewport.UPDATE_DISABLED

	var we := WorldEnvironment.new()
	we.environment = Materiaux.environnement(ciel, ambiant)
	# 🔴 SANS SSAO. Il travaille en espace vue : dans un cadre de 100 m son
	# rayon de 2 m couvre le tiers de l'image et noircit les façades entières.
	# L'occlusion bakée par 07 dans la couleur de sommet tient seule.
	we.environment.ssao_enabled = false
	add_child(we)
	# 🔴 LA PORTÉE DE L'OMBRE SUIT LE CADRE, réglée à chaque cadrage. La carte
	# d'ombre part de la caméra et couvre toujours la même distance : figée sur
	# le plus grand cadre, ses texels font des mètres, et dans une fenêtre de
	# 35 m la plaque plate se marbrait de son propre relief.
	_soleil = Materiaux.soleil(soleil, RECUL + 2.0 * CADRE_MAX_M)
	add_child(_soleil)

	_cam = Camera3D.new()
	_cam.name = "CameraApercu"
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.near = 0.05
	_cam.far = 4000.0
	add_child(_cam)

	# La plaque au sol. Le sol d'un îlot bâti n'est dessiné nulle part — c'est
	# le terrain qui passe dessous —, et sans elle l'objet flotte sur du vide.
	_sol = MeshInstance3D.new()
	_sol.name = "Plaque"
	_sol.position.y = SOUS_LE_SOL
	var m := Materiaux.surface()
	m.albedo_color = mineral
	# 🔴 ELLE NE REÇOIT PAS L'OMBRE. Posée 20 cm sous la chaussée, elle prenait
	# celle du bord de rue sur toute sa longueur — deux bandes noires le long du
	# trottoir. Ce qu'elle doit faire, c'est fermer le vide, pas se dessiner.
	m.disable_receive_shadows = true
	_sol.material_override = m
	add_child(_sol)

	mm_gare = Constructeur.voitures(0)
	mm_roule = Constructeur.voitures(0, true)
	for mm in [mm_gare, mm_roule]:
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Voitures"
		mmi.multimesh = mm
		# Comme dans la ville : une voiture ne porte pas d'ombre.
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)

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

	# La miniature ne joue ni le thème, ni le calque, ni la sélection : elle
	# montre l'objet tel qu'il sera. Posé une fois, jamais repeint.
	for mi in [_objet, _futur]:
		mi.set_instance_shader_parameter("teinte", Color.WHITE)
		mi.set_instance_shader_parameter("calque", Color(1.0, 1.0, 1.0, 0.0))
		mi.set_instance_shader_parameter("maquette_blanche", 0.0)


## Change d'objet. `sol` peut être nul : une berge n'a pas d'emprise. `ligne`
## dit un objet long et étroit — une rue, une berge —, montré par un bout.
## `axe` est la ligne exportée par 07 quand elle existe : une rue en a une, une
## berge non. Sans elle, l'axe se déduit des sommets, et c'est moins sûr.
func montrer(objet: Mesh, futur: Mesh, sol: Mesh, ligne := false,
		axe := PackedVector2Array(), largeur := 0.0) -> void:
	_bout = ligne
	_axe = axe
	_largeur = largeur
	if not ligne:
		vider_voitures()
	_objet.mesh = objet
	_futur.mesh = futur
	_sol.mesh = sol
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_semer_points()
	_cadrer()


## Ce qui coûte est la vue à part : sans sélection, elle s'éteint entièrement.
func vider_voitures() -> void:
	mm_gare.instance_count = 0
	mm_roule.instance_count = 0


func eteindre() -> void:
	if render_target_update_mode == SubViewport.UPDATE_DISABLED:
		return
	vider_voitures()
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
## l'état de la ville. `equipe` est la part de toit couverte, `futur` découvre
## la géométrie reconstruite, `berge` pousse les trois crans de la rive.
func regler(equipe: float, futur: bool, berge: float) -> void:
	_futur.visible = futur and _futur.mesh != null
	for mi in [_objet, _futur]:
		mi.set_instance_shader_parameter("equipe", equipe)
		mi.set_instance_shader_parameter("etat_berge", berge)


## Les points à contenir, calculés UNE FOIS par objet : le cadrage se refait à
## chaque quart de tour, il ne peut pas relire des milliers de sommets.
func _semer_points() -> void:
	_points = PackedVector3Array()
	if _objet.mesh == null:
		return
	var b: AABB = _objet.mesh.get_aabb()
	if _sol.mesh != null:
		b = b.merge((_sol.mesh as Mesh).get_aabb())
	if _futur.mesh != null:
		b = b.merge((_futur.mesh as Mesh).get_aabb())
	var bas := b.position.y
	var haut := b.position.y + b.size.y
	# La plaque quand il y en a une — c'est le couloir façade à façade pour une
	# rue. Sinon le maillage lui-même : une berge n'a pas de plaque, et ses huit
	# coins ne diraient rien de son tracé, qui suit l'Ilse en biais.
	var source: Mesh = _sol.mesh if _sol.mesh != null else _objet.mesh
	if source.get_surface_count() > 0:
		var som: PackedVector3Array = source.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		# 🔴 UN SOMMET SUR `pas` : une berge en porte 1 200 et ces points ne
		# servent qu'à cadrer — l'axe et le milieu n'en bougent pas d'un mètre.
		var pas: int = maxi(1, som.size() / 1200)
		for k in range(0, som.size(), pas):
			var v: Vector3 = som[k]
			_points.append(Vector3(v.x, bas, v.z))
			_points.append(Vector3(v.x, haut, v.z))
	if _points.is_empty():
		for k in 8:
			_points.append(b.get_endpoint(k))
	_mesurer()


## Le cap de l'objet au sol, le milieu de sa longueur et sa largeur en travers.
## Calculé une fois par objet, comme les points.
##
## 🛣️ UN OBJET LONG SE MONTRE PAR SON MORCEAU LE PLUS DROIT (2026-08-28,
## demandé : « pas de virages »). La première passe donne l'axe d'ensemble et
## la hauteur ; la seconde cherche, LE LONG de la ligne, le plus long morceau
## qui ne tourne pas, et n'en montre que celui-là.
func _mesurer() -> void:
	_cap = 0.0
	_fenetre = 0.0
	_centre = Vector3.ZERO
	if _points.is_empty():
		return
	var a := _analyser(_points)
	_poser(a)
	if not _bout:
		return
	if _axe.size() >= 2:
		_poser_ligne(_axe, _largeur)
		return
	var trace := _ligne_des_tranches(a)
	_poser_ligne(trace[0] as PackedVector2Array, float(trace[1]))


## 🛣️ LE PLUS LONG MORCEAU DROIT DE LA LIGNE, et le cadre s'y pose. Un morceau
## s'arrête au premier bout d'axe qui s'écarte de plus de `ANGLE_DROIT` : le
## coude reste dehors, quitte à montrer moins de rue.
func _poser_ligne(ligne: PackedVector2Array, largeur: float) -> void:
	if ligne.size() < 2:
		return
	var dirs := PackedVector2Array()
	var lgs := PackedFloat64Array()
	for i in ligne.size() - 1:
		var v := ligne[i + 1] - ligne[i]
		lgs.append(v.length())
		dirs.append(v.normalized() if v.length() > 0.001 else Vector2(1.0, 0.0))
	var droit := cos(deg_to_rad(ANGLE_DROIT))
	# Au-delà de la fenêtre voulue, un morceau plus droit n'apporterait rien.
	var vise := clampf(largeur * ETALEMENT, FENETRE_MIN_M, FENETRE_MAX_M)
	var debut := 0
	var fin := 0
	var tenu := -1.0
	for i in dirs.size():
		var a := i
		var b := i
		var lg: float = lgs[i]
		while lg < vise:
			var pris := false
			if a > 0 and dirs[a - 1].dot(dirs[i]) >= droit:
				a -= 1
				lg += lgs[a]
				pris = true
			if b < dirs.size() - 1 and dirs[b + 1].dot(dirs[i]) >= droit:
				b += 1
				lg += lgs[b]
				pris = true
			if not pris:
				break
		if lg > tenu:
			tenu = lg
			debut = a
			fin = b + 1
	var d := ligne[debut]
	var f := ligne[fin]
	var axe := (f - d).normalized()
	_cap = rad_to_deg(atan2(axe.y, axe.x))
	var c := (d + f) * 0.5
	# La hauteur reste celle de la première passe : la ligne est au sol.
	_centre = Vector3(c.x, _centre.y, c.y)
	_fenetre = clampf(minf(tenu, vise), FENETRE_MIN_M, FENETRE_MAX_M)


## 🔴 QUAND L'AXE MANQUE, ON LE DESSINE — les sommets sont trop rares pour ça
## un par un (116 pour un tronçon entier, et un voisinage peut n'attraper qu'un
## seul bord). On les range en tranches le long de l'axe d'ensemble, et le
## milieu des tranches fait la ligne. Vrai tant que l'objet ne se replie pas
## sur lui-même — une berge suit un fleuve, elle ne revient pas.
##
## Renvoie la ligne ET la largeur de l'objet, prise à la MÉDIANE des tranches :
## la largeur d'ensemble est celle du fleuve entier, elle cadrerait de trop loin.
func _ligne_des_tranches(a: Dictionary) -> Array:
	var dir: Vector2 = a["dir"]
	var nor: Vector2 = a["nor"]
	var moy: Vector3 = a["moy"]
	var sacs := {}   # tranche -> [somme t, somme s, compte, s mini, s maxi]
	for p in _points:
		var d := Vector2(p.x - moy.x, p.z - moy.z)
		var t := d.dot(dir)
		var u := d.dot(nor)
		var i := int(floor(t / TRANCHE_M))
		if sacs.has(i):
			var v: Array = sacs[i]
			v[0] += t
			v[1] += u
			v[2] += 1.0
			v[3] = minf(v[3], u)
			v[4] = maxf(v[4], u)
		else:
			sacs[i] = [t, u, 1.0, u, u]
	var cles := sacs.keys()
	cles.sort()
	var ligne := PackedVector2Array()
	var larges := []
	var base := Vector2(moy.x, moy.z)
	for i in cles:
		var v: Array = sacs[i]
		ligne.append(base + dir * (float(v[0]) / float(v[2]))
			+ nor * (float(v[1]) / float(v[2])))
		larges.append(float(v[4]) - float(v[3]))
	# 🔴 LE PREMIER QUART, PAS LA MÉDIANE. Une berge est faite de deux rubans —
	# le quai et le talus — et la tranche mesure du bord de l'un au bord de
	# l'autre, VIDE COMPRIS : la médiane cadrait de 40 m de haut, deux fils dans
	# du blanc. Les tranches les plus étroites, elles, sont l'ouvrage seul.
	larges.sort()
	var large := 1.0 if larges.is_empty() \
		else maxf(float(larges[larges.size() / 4]), 1.0)
	return [ligne, large]


## Direction principale d'un nuage au sol — vecteur propre dominant de sa
## covariance 2×2, qui se résout sans itération —, son barycentre, et son
## étendue le long des deux axes. Sur le couloir d'une rue, c'est l'axe de la
## rue ; sur un îlot carré la direction est indifférente, et n'importe laquelle
## fait alors l'affaire.
func _analyser(lot: PackedVector3Array) -> Dictionary:
	var n := float(lot.size())
	var mx := 0.0
	var my := 0.0
	var mz := 0.0
	for p in lot:
		mx += p.x
		my += p.y
		mz += p.z
	mx /= n
	my /= n
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
	var dir := Vector2(1.0, 0.0)
	if absf(sxz) > 1e-6 or absf(sxx - szz) > 1e-6:
		var t := 0.5 * atan2(2.0 * sxz, sxx - szz)
		dir = Vector2(cos(t), sin(t))
	var nor := Vector2(-dir.y, dir.x)
	var t0 := INF
	var t1 := -INF
	var s0 := INF
	var s1 := -INF
	for p in lot:
		var d := Vector2(p.x - mx, p.z - mz)
		t0 = minf(t0, d.dot(dir))
		t1 = maxf(t1, d.dot(dir))
		s0 = minf(s0, d.dot(nor))
		s1 = maxf(s1, d.dot(nor))
	return {"lot": lot, "dir": dir, "nor": nor, "moy": Vector3(mx, my, mz),
		"t": (t0 + t1) * 0.5, "large": s1 - s0}


func _poser(a: Dictionary) -> void:
	var dir: Vector2 = a["dir"]
	var nor: Vector2 = a["nor"]
	var moy: Vector3 = a["moy"]
	var tm: float = a["t"]
	_cap = rad_to_deg(atan2(dir.y, dir.x))
	_fenetre = clampf(float(a["large"]) * ETALEMENT, FENETRE_MIN_M, FENETRE_MAX_M)
	# En travers, le milieu des seuls points QUI SONT LÀ — sur une berge courbe,
	# le barycentre du nuage tombe dans l'Ilse.
	var sm := 0.0
	var compte := 0
	for p in (a["lot"] as PackedVector3Array):
		var d := Vector2(p.x - moy.x, p.z - moy.z)
		if absf(d.dot(dir) - tm) <= _fenetre * 0.5:
			sm += d.dot(nor)
			compte += 1
	if compte > 0:
		sm /= float(compte)
	var c := Vector2(moy.x, moy.z) + dir * tm + nor * sm
	_centre = Vector3(c.x, moy.y, c.y)


## 🔷 TOUJOURS DE TROIS QUARTS. Le lacet vaut `45° − cap` modulo 90° : dans le
## plan, l'objet croise alors l'écran en diagonale, jamais de face. Sans ça, les
## quatre vues cardinales de `Q`/`E` mettaient la rue et la façade à plat.
## On garde le quart de tour le plus proche de la ville : le panneau montre donc
## l'objet du côté d'où on le regarde, à moins d'un huitième de tour près.
func _trois_quarts() -> float:
	var vise := 45.0 - _cap
	return vise + 90.0 * roundf((_lacet - vise) / 90.0)


func _cadrer() -> void:
	if _points.is_empty():
		return
	_cam.rotation_degrees = Vector3(-HAUTEUR, _trois_quarts(), 0.0)
	var base := _cam.transform.basis
	if _bout and _fenetre > 0.0:
		var zz := -INF
		for p in _points:
			zz = maxf(zz, p.dot(base.z))
		# 🔴 En ortho, `size` est la hauteur VUE : la profondeur de sol qu'elle
		# couvre vaut `size / sin(hauteur)` (`Godot/README.md`). L'inverse ici,
		# et le format donne une fenêtre au sol à peu près carrée.
		_cam.size = _fenetre * sin(deg_to_rad(HAUTEUR))
		_cam.position = _centre + base.z * (zz + RECUL - _centre.dot(base.z))
		_regler_ombre()
		return
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
