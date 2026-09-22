extends Node3D
## Les problèmes posés SUR la carte : on voit l'étendue du désastre avant
## d'avoir lu une phrase, et chaque pastille s'efface quand son lieu est réglé.
##
## 🔴 ELLES NE SONT PAS UN DEUXIÈME JEU DE DONNÉES : tout ce qu'elles montrent
## sort de `ville.gd`. Une pastille qui resterait après une livraison est donc
## un défaut du noyau, pas du décor.

const Interface := preload("res://scripts/interface.gd")

## 🎚️ LEVEL DESIGN : au-delà, la ville se couvrirait de pictogrammes au lieu de
## se montrer. À 900 m on voit Wehrau en entier ; le repère est là.
const PORTEE_M := 900.0
## Au-dessus du plus haut point de l'objet : assez pour ne pas entrer dans un
## toit, assez peu pour désigner le bon îlot.
const HAUTEUR_M := 14.0
const TAILLE := 128
## 🔴 LA PASTILLE GARDE SA TAILLE À L'ÉCRAN, elle ne la garde pas dans le
## monde : 21 m font une poussière sur la ville entière et un panneau
## d'autoroute une fois qu'on est descendu dans la rue. Sa largeur suit donc la
## distance de caméra. 🎚️ LEVEL DESIGN : le facteur, et les deux bornes.
const LARGEUR_PAR_TAILLE := 0.050
const LARGEUR_MIN_M := 12.0
const LARGEUR_MAX_M := 90.0

var jeu
## 📖 Le récit d'ouverture les tient éteintes jusqu'à la page des dégâts.
var muettes := false
var _pastilles := {}         # "i66" -> Node3D
var _signature := ""
var _fond: Color
var _encre: Color
var _textures := {}
var _largeur_m := 21.0


func batir(maquette) -> void:
	jeu = maquette
	_fond = jeu.interface.ACCENT_VIF
	_encre = jeu.interface.TEXTE


## Ce qu'il faut montrer maintenant, objet par objet : un mot d'état et un
## nombre, ou rien. C'est la seule règle de lecture des pastilles.
func _probleme(couche: String, fid: int, t: float) -> Array:
	var v = jeu.ville
	# 🔴 TROIS PROBLÈMES SEULEMENT, et c'est volontaire : la boue et les ruines
	# se VOIENT déjà au sol. Les avoir badgées mettait vingt-sept pastilles sur
	# le faubourg, et on ne lisait plus ni la ville ni les pastilles.
	if couche == "i":
		if v.camp_pose(fid):
			if not v.camp_accessible(fid, t):
				return ["camp", "vide"]
			return ["camp", "%d" % int(v.camp_occupants(fid, t))]
		# 🔴 À LA LIVRAISON, pas à l'engagement : on rentre chez soi quand le
		# chantier est fini. Pendant les travaux, la pastille reste.
		var sinistres: float = v.base("i", fid, "logements_sinistres")
		if sinistres > 0.0 and not v.reparation_finie("i", fid, t):
			return ["sans_abri", "%d" % int(sinistres)]
		return []
	if str(v.objets("r").get(fid, {}).get("etat_crue", "")) == "coupe":
		return [] if v.reparation_finie("r", fid, t) else ["pont_casse", ""]
	return []


## Refaite quand, et seulement quand, un état change : la signature porte le
## dessin et le nombre de chaque pastille.
func actualiser(t: float) -> void:
	var etats := {}
	var signature := PackedStringArray()
	for couche in ["i", "r"]:
		for fid in jeu.noeuds[couche]:
			var p := _probleme(couche, int(fid), t)
			if p.is_empty():
				continue
			var cle := "%s%d" % [couche, int(fid)]
			etats[cle] = p
			signature.append("%s=%s%s" % [cle, p[0], p[1]])
	var sig := ",".join(signature)
	if sig == _signature:
		return
	_signature = sig
	for cle in _pastilles.keys():
		if not etats.has(cle):
			(_pastilles[cle] as Node3D).queue_free()
			_pastilles.erase(cle)
	for cle in etats:
		var p: Array = etats[cle]
		if _pastilles.has(cle):
			_poser_texte(_pastilles[cle], p)
			continue
		_pastilles[cle] = _batir_pastille(cle, p)


func _batir_pastille(cle: String, p: Array) -> Node3D:
	var couche := cle.substr(0, 1)
	var fid := int(cle.substr(1))
	var mi: MeshInstance3D = jeu.noeuds[couche][fid]
	var boite := mi.get_aabb()
	var n := Node3D.new()
	n.name = "Pastille" + cle
	add_child(n)
	n.global_position = mi.to_global(boite.get_center())
	n.global_position.y = mi.global_position.y + boite.end.y + HAUTEUR_M

	var icone := Sprite3D.new()
	icone.name = "Icone"
	icone.texture = _texture(String(p[0]))
	icone.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	icone.shaded = false
	icone.no_depth_test = true
	icone.render_priority = 2
	n.add_child(icone)

	var texte := Label3D.new()
	texte.name = "Compte"
	texte.font_size = 56
	texte.modulate = _fond
	texte.outline_modulate = _encre
	texte.outline_size = 14
	texte.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	texte.no_depth_test = true
	texte.render_priority = 2
	n.add_child(texte)
	_poser_texte(n, p)
	_dimensionner(n)
	return n


func _poser_texte(n: Node3D, p: Array) -> void:
	var texte: Label3D = n.get_node("Compte")
	texte.text = String(p[1])
	texte.visible = texte.text != ""
	(n.get_node("Icone") as Sprite3D).texture = _texture(String(p[0]))


## Le pictogramme dans un disque, contour compris : posé sur une ville pastel,
## un trait seul disparaît. Même table de dessins que l'interface.
func _texture(nom: String) -> Texture2D:
	if _textures.has(nom):
		return _textures[nom]
	# 🎨 `@` = l'encre du dessin, la même table que l'interface (`_icone`).
	var corps: String = str(Interface.DESSINS.get(nom, Interface.DESSINS["dangers"])) 		.replace("@", "#" + _encre.to_html(false))
	var svg := ("<svg xmlns='http://www.w3.org/2000/svg' width='32' height='32'"
		+ " viewBox='-4 -4 32 32'>"
		+ "<circle cx='12' cy='12' r='15' fill='#%s'/>" % _encre.to_html(false)
		+ "<circle cx='12' cy='12' r='13.2' fill='#%s'/>" % _fond.to_html(false)
		+ "<g fill='none' stroke='#%s' stroke-width='2.2'" % _encre.to_html(false)
		+ " stroke-linecap='round' stroke-linejoin='round'>" + corps + "</g></svg>")
	var img := Image.new()
	if img.load_svg_from_string(svg, float(TAILLE) / 32.0) != OK:
		return null
	_textures[nom] = ImageTexture.create_from_image(img)
	return _textures[nom]


## Une pastille, à la taille du moment.
func _dimensionner(n: Node3D) -> void:
	(n.get_node("Icone") as Sprite3D).pixel_size = _largeur_m / float(TAILLE)
	var texte: Label3D = n.get_node("Compte")
	texte.pixel_size = _largeur_m * 0.0123
	texte.position.y = -_largeur_m * 0.78


## Les pastilles s'éteignent de loin : de haut, la ville doit se voir. Et tant
## qu'elles sont là, elles gardent la même taille à l'écran.
func regler_portee(distance: float) -> void:
	visible = not muettes and distance <= PORTEE_M
	var large := clampf(distance * LARGEUR_PAR_TAILLE,
		LARGEUR_MIN_M, LARGEUR_MAX_M)
	if is_equal_approx(large, _largeur_m):
		return
	_largeur_m = large
	for n in _pastilles.values():
		_dimensionner(n)
