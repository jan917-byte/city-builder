extends Node3D
# Un flux agrégé figuré : les voitures glissent sur les axes exportés, aucune
# ne navigue. Deux MultiMesh couvrent toute la ville (décision 62).

const Constructeur := preload("res://scripts/constructeur.gd")
const Echantillon := preload("res://scripts/echantillon.gd")

const Y_ROULE := 0.72
const Y_GARE := 0.66
const ESPACEMENT_CALME := 48.0
const ESPACEMENT_CHARGE := 7.0
const ESPACEMENT_RESERVE := 12.0
const LONGUEUR_PLACE := 5.5
## La largeur d'une place de rue — la même que `07` (PLACE_LARGEUR).
const LARGEUR_PLACE := 2.5
## L'écart à l'axe de la file qui roule, à droite du sens de marche.
const DECAL_FILE := 1.35
const ECHANTILLON_STATIONNEMENT := 0.30
const TAILLE_VISIBLE_MAX := 700.0
const PALETTE := [
	Color8(194, 92, 73), Color8(70, 91, 112), Color8(216, 198, 157),
	Color8(116, 130, 119), Color8(151, 116, 92), Color8(205, 207, 198),
]
## 🚗 Fermer une rue ne déplace pas tout le monde. Un trajet dont le chemin
## s'allonge perd d'abord une part fixe — ceux qui ne reprennent pas la voiture
## du tout —, puis une part qui grandit avec le détour :
## gardés = (1 − PART) × (temps avant / temps après) ^ ELASTICITE.
## DEUX NOMBRES DE LEVEL DESIGN, à trancher devant l'image.
const PART_RENONCE := 0.25
const ELASTICITE_RENONCE := 0.7
const VITESSES := {
	"autoroute": 70.0, "boulevard": 50.0, "rue": 30.0,
	"ruelle": 12.0, "rive": 25.0,
}

# --- 🚶🚲 les usagers doux ------------------------------------------------
# Même principe que les voitures : un flux agrégé, des créneaux réservés une
# fois, l'animation sur le GPU. Une seule différence, et c'est le sujet — leur
# nombre suit l'INVERSE de la charge. Une rue saturée chasse le piéton et le
# cycliste ; la fermer aux voitures les fait revenir, sans ouvrir de thème.
const Y_MARCHE := 0.14           # la marche de bordure de 07 (HAUTEUR_BORDURE)
const VITESSE_PIETON := 1.35     # m/s
const VITESSE_VELO := 4.40       # m/s ≈ 16 km/h : la congestion ne le ralentit pas
## Le créneau réservé vaut l'espacement le plus DENSE : au-delà on paierait des
## instances qui ne sortiraient jamais.
const RESERVE_PIETON := 6.0
const RESERVE_VELO := 18.0
const ESPACEMENT_PIETON_ANIME := 6.0
const ESPACEMENT_PIETON_DESERT := 30.0
const ESPACEMENT_VELO_DENSE := 18.0
const ESPACEMENT_VELO_RARE := 110.0
## Le cycliste roule DEHORS de la file des voitures (décal 1,35) et DEDANS de
## celle des places : entre les deux quand la chaussée en laisse la place.
const BORD_VELO_MIN := 1.80
const JEU_VELO_PLACES := 0.75
## Deux étages de plus que les voitures (700 m) : un piéton fait 0,40 m de
## large, une voiture 1,78 — sous ces tailles ils ne sont plus que du grain.
const TAILLE_PIETON_MAX := 320.0
const TAILLE_VELO_MAX := 450.0
## 🔴 TROIS NOMBRES DE LEVEL DESIGN, comme PART_RENONCE : ce que la charge
## chasse, et le fond de fréquentation d'une hiérarchie. À trancher devant
## l'image, pas ici.
const CHASSE_PIETON := 0.80
const CHASSE_VELO := 0.90
const FOULE := {
	"boulevard": 1.00, "rue": 0.85, "ruelle": 0.70, "rive": 0.55,
	"autoroute": 0.0, "voie ferree": 0.0,
}
const HABITS := [
	Color8(78, 92, 108), Color8(142, 118, 96), Color8(96, 104, 92),
	Color8(158, 148, 134), Color8(120, 80, 76), Color8(70, 74, 82),
	Color8(174, 166, 150),
]


## Une famille d'usagers doux : des créneaux semés UNE FOIS, leur transformée
## déjà calculée, et le groupe contigu de chaque rue. La pulsation ne rouvre
## que les rues dont la foule a bougé — 178 comparaisons, pas 5 000 écritures.
class Famille extends RefCounted:
	var t: Array[Transform3D] = []
	var rang := PackedInt32Array()      # le rang DANS SON SENS de marche
	var creneaux := PackedInt32Array()  # combien ce morceau en porte, par sens
	var longueur := PackedFloat32Array()
	var donnees := PackedColorArray()   # phase, vitesse, longueur du segment
	var groupes := {}                   # fid → [début, fin)
	var pas := {}                       # fid → la foule du dernier passage
	var vus := PackedByteArray()
	var mm: MultiMesh
	var noeud: MultiMeshInstance3D
	var actif := true

var ville
var _roulantes := []
var _garees := []
var _mm_roule: MultiMesh
var _mm_gare: MultiMesh
var _node_roule: MultiMeshInstance3D
var _node_gare: MultiMeshInstance3D
var _actif := true
var _visibles_roule := PackedByteArray()
var _visibles_gare := PackedByteArray()
var _dernier_etat := -1.0
var _derniere_charge := -1.0
## fid → la vitesse écrite au dernier passage.
var _vitesse_vue := {}
var _fermees := {}
var _calibration := [1.0, 1.0]
var _indisponibles_connues := ""
## Les temps du réseau entier ouvert, mesurés une fois : sans eux, un détour
## n'a pas de longueur et tout le flux se reporterait.
var _t_ref := {}
var _pieds := Famille.new()
var _roues := Famille.new()
## Le créneau qu'on n'écrit pas : une base à zéro, donc trois triangles nuls
## que le rasteriseur jette. Même recette que les voitures.
var _vide := Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO)
var _mois := 0.0

# --- 🔄 le circuit : ce que la voiture fait au bout de son segment ---------
## Un arc = UN segment droit ORIENTÉ, sa file déjà décalée à droite. Chaque arc
## en désigne un seul suivant, donc les arcs forment des circuits fermés : la
## voiture tourne sans fin et ne cherche jamais son chemin (décision 62).
var _arc_t: Array[Transform3D] = []
var _arc_L := PackedFloat32Array()
var _arc_fid := PackedInt32Array()
var _arc_dir := PackedVector2Array()
var _arc_tete := PackedInt32Array()     # arc → nœud d'arrivée
var _arc_inverse := PackedInt32Array()
var _arc_suivant := PackedInt32Array()  # la continuation la plus droite
var _sortie_deb := PackedInt32Array()   # nœud → sa première sortie (CSR)
var _sortie_arc := PackedInt32Array()
var _rang_noeud := {}
var _arc_par_paire := {}
## Le balayage de chaque image ne lit QUE ça : 963 comparaisons de flottants,
## et le dictionnaire de la voiture n'est ouvert que si elle change d'arc.
var _arrivee := PackedFloat32Array()
var _arc_vu := PackedInt32Array()       # l'arc écrit dans le MultiMesh
## L'horloge partagée avec le GPU (`Constructeur.HORLOGE`) : sans elle, le CPU
## ne sait pas où le shader a posé la voiture.
var _temps_trafic := 0.0
var _indispo_courant := {}
var _long_fid := {}


## 🅿️ L'écart à l'axe d'une voiture garée SUR LE MORCEAU DROIT DE LA FICHE : le
## milieu de la file peinte, MESURÉ PAR 07 (`bord_places_m`). Le recalculer ici
## dériverait sur les rues de berge, dont le corridor n'est plus celui de la
## source. Dans la ville, les places viennent de `places_rue`.
static func _bord_gare(route: Dictionary) -> float:
	return maxf(1.45, float(route.get("bord_places_m", 0.0)))


func batir(donnees: Dictionary, etat_ville) -> void:
	ville = etat_ville
	var couloirs: Dictionary = donnees["couloirs"]
	var fentes: Dictionary = donnees.get("places_rue", {})
	_batir_graphe(couloirs)
	_batir_arcs(couloirs)
	var indisponibles := _indisponibles(0.0)
	# La passe de référence tourne sur le réseau ENTIER OUVERT — ponts compris :
	# c'est l'étalon du détour, pas l'état de départ.
	_affectation({}, true)
	# L'étalon de la charge reste l'état de départ, celui qui est à l'écran.
	var reference := _affectation(indisponibles)
	_calibration = [_p95(reference[0]), _p95(reference[1])]
	_reaffecter(0.0, 0.0, indisponibles)
	for fid in ville.routes:
		var cle := str(fid)
		if not couloirs.has(cle):
			continue
		var route: Dictionary = ville.routes[fid]
		var foule := float(FOULE.get(str(route.get("hierarchie", "rue")), 0.8))
		# 🚶 Le trottoir vient de `07` (`bord_trottoir_m`). Quand il n'y en a
		# pas — 38 tronçons, les ruelles —, on marche au bord de la chaussée,
		# de plain-pied : c'est ce que fait une ruelle.
		var trottoir := float(route.get("bord_trottoir_m", 0.0))
		var bord_pieton := trottoir if trottoir > 0.0 else \
			maxf(1.0, Echantillon.chaussee(route) * 0.5 - 0.35)
		var y_pieton: float = Y_ROULE + (Y_MARCHE if trottoir > 0.0 else 0.0)
		var debut_p := _pieds.t.size()
		var debut_v := _roues.t.size()
		for brut in (couloirs[cle][1] as Array):
			var chemin := _chemin(brut)
			if chemin[1] < 8.0:
				continue
			_long_fid[fid] = float(_long_fid.get(fid, 0.0)) + float(chemin[1])
			var n := maxi(1, int(floor(float(chemin[1]) / ESPACEMENT_RESERVE)))
			for k in n:
				var pose := _poser(chemin[0], chemin[2],
					fmod((k + 0.35) * float(chemin[1]) / n, float(chemin[1])),
					-1.0 if k % 2 else 1.0)
				if int(pose[0]) < 0:
					continue
				_roulantes.append({"arc": int(pose[0]), "arc0": int(pose[0]),
					"offset0": float(pose[1]), "v": 1.1, "phase": 0.0,
					"arrivee": 0.0})
			if foule <= 0.0:
				continue
			_semer(_pieds, chemin, bord_pieton, y_pieton, RESERVE_PIETON,
				VITESSE_PIETON, 0.26)
			_semer(_roues, chemin, _bord_velo(route), Y_ROULE, RESERVE_VELO,
				VITESSE_VELO, 0.0)
		if _pieds.t.size() > debut_p:
			_pieds.groupes[fid] = [debut_p, _pieds.t.size()]
		if _roues.t.size() > debut_v:
			_roues.groupes[fid] = [debut_v, _roues.t.size()]

		# 🅿️ DANS LA PLACE PEINTE : `07` exporte le milieu et la direction de
		# chacune (`places_rue`), donc une voiture ne peut plus se garer là où
		# aucune file n'est peinte — au carrefour, en travers d'un passage.
		if not fentes.has(cle):
			continue
		var f: Array = fentes[cle]
		var pas := maxi(1, int(round(1.0 / ECHANTILLON_STATIONNEMENT)))
		var i := 0
		while i * 4 < f.size():
			var b3 := Basis(Vector3.UP, atan2(float(f[i * 4 + 2]),
				float(f[i * 4 + 3])))
			_garees.append({"fid": fid, "t": Transform3D(b3, Vector3(
				float(f[i * 4]), Y_GARE, float(f[i * 4 + 1])))})
			i += pas

	_mm_roule = Constructeur.voitures(_roulantes.size(), true, true)
	_mm_gare = Constructeur.voitures(_garees.size())
	_node_roule = MultiMeshInstance3D.new()
	_node_roule.name = "VoituresRoulantes"
	_node_roule.multimesh = _mm_roule
	_node_roule.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_node_roule)
	_node_gare = MultiMeshInstance3D.new()
	_node_gare.name = "VoituresGarees"
	_node_gare.multimesh = _mm_gare
	_node_gare.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_node_gare)
	for k in _roulantes.size():
		_mm_roule.set_instance_color(k, PALETTE[(k * 5 + 1) % PALETTE.size()])
	_visibles_roule.resize(_roulantes.size())
	_visibles_roule.fill(0)
	_arc_vu.resize(_roulantes.size())
	_arc_vu.fill(-1)
	_arrivee.resize(_roulantes.size())
	_semer_circuit()
	_maj_roulantes(0.0, true)
	for k in _garees.size():
		var gris := 0.62 + 0.16 * float(k % 5) / 4.0
		_mm_gare.set_instance_color(k, Color(gris, gris * 1.01, gris * 0.98))
	_visibles_gare.resize(_garees.size())
	_visibles_gare.fill(0)
	_maj_garees(0.0, true)
	_monter(_pieds, Constructeur.pietons(_pieds.t.size()), "Pietons", HABITS)
	_monter(_roues, Constructeur.cyclistes(_roues.t.size()), "Cyclistes", HABITS)
	var doux := _impraticables(0.0)
	_maj_famille(_pieds, 0.0, true, CHASSE_PIETON, ESPACEMENT_PIETON_ANIME,
		ESPACEMENT_PIETON_DESERT, doux)
	_maj_famille(_roues, 0.0, true, CHASSE_VELO, ESPACEMENT_VELO_DENSE,
		ESPACEMENT_VELO_RARE, doux)
	var peintes := 0
	for cle in fentes:
		@warning_ignore("integer_division")
		peintes += (fentes[cle] as Array).size() / 4
	print(("  trafic : %d voitures roulantes visibles sur %d en circuit,"
		+ " %d garées sur %d places peintes, 2 appels, animation GPU à l'écran")
		% [_compter_visibles(), _roulantes.size(), _garees.size(), peintes])
	print(("  usagers doux : %d piétons visibles sur %d créneaux (%d rues avec"
		+ " trottoir), %d cyclistes sur %d — 2 appels de plus, la foule suit"
		+ " l'inverse de la charge")
		% [_compter(_pieds), _pieds.t.size(), _rues_avec_trottoir(),
			_compter(_roues), _roues.t.size()])


func avancer(mois: float) -> void:
	# Retenu même quand la vue est trop haute pour les voitures : c'est ce mois
	# que le réveil d'une famille repeindra.
	_mois = mois
	if not _actif:
		return
	# Une seule passe sur les routes pour les deux publics : les voitures y
	# ajoutent les rues fermées, les usagers doux non.
	var doux := _impraticables(mois)
	var indisponibles: Dictionary = doux.duplicate()
	indisponibles.merge(_fermees)
	var signature := _signature(indisponibles)
	if signature != _indisponibles_connues:
		_reaffecter(mois, 0.0, indisponibles)
	if absf(mois - _dernier_etat) > 0.02:
		_maj_garees(mois, false)
	if absf(mois - _derniere_charge) > 0.05:
		_maj_roulantes(mois, false)
		_maj_famille(_pieds, mois, false, CHASSE_PIETON, ESPACEMENT_PIETON_ANIME,
			ESPACEMENT_PIETON_DESERT, doux)
		_maj_famille(_roues, mois, false, CHASSE_VELO, ESPACEMENT_VELO_DENSE,
			ESPACEMENT_VELO_RARE, doux)


## Trois étages, du plus gros au plus fin : la voiture tient jusqu'à 700 m de
## caméra, le cycliste 450, le piéton 320. Éteinte, une famille ne coûte plus
## rien — ni dessin, ni pulsation ; rallumée, elle se réécrit en entier.
func regler_detail(taille_camera: float) -> void:
	_reveiller(_pieds, taille_camera <= TAILLE_PIETON_MAX)
	_reveiller(_roues, taille_camera <= TAILLE_VELO_MAX)
	var actif := taille_camera <= TAILLE_VISIBLE_MAX
	if actif == _actif:
		return
	_actif = actif
	_node_roule.visible = actif
	_node_gare.visible = actif
	if actif:
		_dernier_etat = -1.0
		_derniere_charge = -1.0


## 🔴 LE RÉVEIL REPEINT TOUT DE SUITE, il n'attend pas la pulsation. Elle
## ne bat qu'à 4 Hz : en zoomant depuis la ville entière, la première image
## sortait sans personne — et les captures de l'essai avec.
func _reveiller(fam: Famille, actif: bool) -> void:
	if fam.noeud == null or actif == fam.actif:
		return
	fam.actif = actif
	fam.noeud.visible = actif
	if not actif:
		return
	fam.pas.clear()
	if fam == _pieds:
		_maj_famille(fam, _mois, true, CHASSE_PIETON, ESPACEMENT_PIETON_ANIME,
			ESPACEMENT_PIETON_DESERT, _impraticables(_mois))
	else:
		_maj_famille(fam, _mois, true, CHASSE_VELO, ESPACEMENT_VELO_DENSE,
			ESPACEMENT_VELO_RARE, _impraticables(_mois))


## 🔴 LA DENSITÉ RESTE UNE PROPRIÉTÉ DE LA RUE, pas de la voiture. Depuis que
## les voitures circulent, ce n'est plus leur rang de semis qui décide de leur
## visibilité — c'est un QUOTA par tronçon, tenu ici : la rue à `charge = 1,00`
## en montre autant qu'avant, mais celles qui ne tiennent pas dedans s'effacent
## AU CARREFOUR au lieu du milieu de la rue.
func _maj_roulantes(mois: float, force: bool) -> void:
	_derniere_charge = mois
	# La charge est une propriété de 178 rues, pas de milliers de voitures.
	var vitesses := {}
	var quota := {}
	_indispo_courant = _indisponibles(mois)
	for fid in ville.routes:
		var praticable := not _indispo_courant.has(fid)
		var q := float(ville.valeur("r", fid, "charge", mois)) if praticable else 0.0
		var hier := str(ville.routes[fid].get("hierarchie", "rue"))
		var libre := float(VITESSES.get(hier, 30.0)) / 3.6
		# La donnée d'animation ne porte que la vitesse : tant qu'aucune rampe
		# ne court, elle est identique d'une pulsation à l'autre et ne vaut pas
		# 329 écritures de plus.
		var v := maxf(1.1, libre * (1.0 - 0.92 * q * q))
		_vitesse_vue[fid] = v
		vitesses[fid] = v
		var esp: float = lerpf(ESPACEMENT_CALME, ESPACEMENT_CHARGE,
			pow(clampf(q / 0.65, 0.0, 1.0), 0.72))
		quota[fid] = maxi(1, int(floor(float(_long_fid.get(fid, 0.0)) / esp))) \
			if praticable else 0
	var occupe := {}
	for k in _roulantes.size():
		var a: Dictionary = _roulantes[k]
		var e: int = a["arc"]
		var fid := _arc_fid[e]
		var n := int(occupe.get(fid, 0))
		var place := n < int(quota[fid])
		if place:
			occupe[fid] = n + 1
		elif _visibles_roule[k] == 1 or force:
			_mm_roule.set_instance_transform(k, _vide)
			_arc_vu[k] = -1
		_visibles_roule[k] = 1 if place else 0
		var v: float = vitesses[fid]
		var change := not is_equal_approx(v, float(a["v"]))
		if change:
			_recaler(k, a, v)
		if place and (force or change or _arc_vu[k] != e):
			_ecrire(k, a)


func _compter_visibles() -> int:
	var n := 0
	for v in _visibles_roule:
		n += int(v)
	return n


## 🚲 OÙ ROULE UN CYCLISTE, en mètres depuis l'axe : dehors de la file des
## voitures (1,35), dedans de celle des places. Sur une rue de 13 m garée des
## deux bords il ne reste rien entre les deux — il partage donc la voie, un peu
## plus au large que la voiture, et c'est ce qu'il fait dans la réalité.
static func _bord_velo(route: Dictionary) -> float:
	var demi := Echantillon.chaussee(route) * 0.5
	var file := float(route.get("bord_places_m", 0.0)) - LARGEUR_PLACE * 0.5 \
		- JEU_VELO_PLACES
	return clampf(file, BORD_VELO_MIN, maxf(BORD_VELO_MIN, demi - 0.45))


## Les créneaux d'un morceau d'axe, DANS LES DEUX SENS : rang pair vers l'aval,
## rang impair vers l'amont, chacun tenant sa droite. `ecart` décale un
## marcheur sur trois en travers du trottoir — trois files bien droites se
## liraient comme un défilé.
func _semer(fam: Famille, chemin: Array, decal: float, y: float,
		reserve: float, vitesse: float, ecart: float) -> void:
	var L := float(chemin[1])
	var creneaux := int(floor(L / reserve))
	if creneaux < 1:
		return
	for k in creneaux * 2:
		@warning_ignore("integer_division")
		var r: int = k / 2
		# Les deux sens sont décalés d'un demi-créneau : sinon ils marchent par
		# paires, épaule contre épaule, tout le long de la rue.
		var s := fmod((float(r) + 0.35 + 0.5 * float(k % 2)) * L / creneaux, L)
		var seg := _segment(chemin[0], chemin[2], L, s,
			decal + ecart * (float(r % 3) - 1.0), -1.0 if k % 2 else 1.0, y)
		fam.t.append(seg[0])
		fam.rang.append(r)
		fam.creneaux.append(creneaux)
		fam.longueur.append(L)
		fam.donnees.append(Color(float(seg[1]), vitesse, float(seg[2]), 1.0))


## Le nœud, la teinte et la donnée d'animation : tout ce qui ne changera plus.
## La pulsation n'écrira ensuite QUE des transformées, et seulement celles qui
## basculent.
func _monter(fam: Famille, mm: MultiMesh, nom: String, teintes: Array) -> void:
	fam.mm = mm
	fam.noeud = MultiMeshInstance3D.new()
	fam.noeud.name = nom
	fam.noeud.multimesh = mm
	fam.noeud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fam.noeud)
	fam.vus.resize(fam.t.size())
	fam.vus.fill(0)
	for k in fam.t.size():
		mm.set_instance_color(k, teintes[(k * 3 + 1) % teintes.size()])
		mm.set_instance_custom_data(k, fam.donnees[k])
		mm.set_instance_transform(k, _vide)


## La foule d'une rue, et rien d'autre : une comparaison par rue, et on ne
## rouvre le groupe que si elle a bougé d'un trente-deuxième. C'est ce qui
## tient 5 000 usagers pour le prix de 178 lectures de `charge`.
func _maj_famille(fam: Famille, mois: float, force: bool, chasse: float,
		esp_dense: float, esp_rare: float, indisponibles: Dictionary) -> void:
	if not fam.actif:
		return
	for fid in fam.groupes:
		var f := 0.0
		if not indisponibles.has(fid):
			var base := float(FOULE.get(
				str(ville.routes[fid].get("hierarchie", "rue")), 0.8))
			f = clampf(base * (1.0 - chasse
				* float(ville.valeur("r", fid, "charge", mois))), 0.0, 1.0)
		var quantifie := int(f * 32.0)
		if not force and int(fam.pas.get(fid, -1)) == quantifie:
			continue
		fam.pas[fid] = quantifie
		# Une rue vidée l'est FRANCHEMENT : sous un trente-deuxième de foule il
		# ne reste personne, pas un dernier marcheur qui tiendrait le trottoir.
		var esp := lerpf(esp_rare, esp_dense, f) if quantifie > 0 else 0.0
		var g: Array = fam.groupes[fid]
		for k in range(int(g[0]), int(g[1])):
			var n := fam.creneaux[k]
			var vus := 0 if esp <= 0.0 else \
				clampi(int(floor(fam.longueur[k] / esp)), 0, n)
			# Le créneau retenu est étalé sur TOUTE la longueur, jamais pris
			# dans les premiers : une rue calme ne doit pas grouper ses
			# marcheurs à un bout.
			var montre := (fam.rang[k] * vus) % n < vus
			if montre == (fam.vus[k] == 1):
				continue
			fam.vus[k] = 1 if montre else 0
			fam.mm.set_instance_transform(k, fam.t[k] if montre else _vide)


## 📊 CE QUE COÛTE LA PULSATION, part par part, en microsecondes moyennées.
## « à froid » = tout réécrit, ce que paie le réveil d'un zoom ; « à chaud » =
## ce qui tourne vraiment 4×/s. Lu par `-- --banc`, rien d'autre ne l'appelle.
func banc(mois: float, n: int) -> Dictionary:
	var out := {}
	var doux := _impraticables(mois)
	var t0 := Time.get_ticks_usec()
	for i in n:
		var d := _impraticables(mois)
		var ind: Dictionary = d.duplicate()
		ind.merge(_fermees)
		_signature(ind)
	out["indisponibles"] = float(Time.get_ticks_usec() - t0) / float(n)

	t0 = Time.get_ticks_usec()
	for i in n:
		_maj_garees(mois, true)
	out["garées à froid"] = float(Time.get_ticks_usec() - t0) / float(n)
	t0 = Time.get_ticks_usec()
	for i in n:
		_maj_garees(mois, false)
	out["garées à chaud"] = float(Time.get_ticks_usec() - t0) / float(n)

	t0 = Time.get_ticks_usec()
	for i in n:
		_maj_roulantes(mois, true)
	out["roulantes à froid"] = float(Time.get_ticks_usec() - t0) / float(n)
	t0 = Time.get_ticks_usec()
	for i in n:
		_maj_roulantes(mois, false)
	out["roulantes à chaud"] = float(Time.get_ticks_usec() - t0) / float(n)

	t0 = Time.get_ticks_usec()
	for i in n:
		_maj_famille(_pieds, mois, true, CHASSE_PIETON, ESPACEMENT_PIETON_ANIME,
			ESPACEMENT_PIETON_DESERT, doux)
		_maj_famille(_roues, mois, true, CHASSE_VELO, ESPACEMENT_VELO_DENSE,
			ESPACEMENT_VELO_RARE, doux)
	out["usagers doux à froid"] = float(Time.get_ticks_usec() - t0) / float(n)
	t0 = Time.get_ticks_usec()
	for i in n:
		_maj_famille(_pieds, mois, false, CHASSE_PIETON, ESPACEMENT_PIETON_ANIME,
			ESPACEMENT_PIETON_DESERT, doux)
		_maj_famille(_roues, mois, false, CHASSE_VELO, ESPACEMENT_VELO_DENSE,
			ESPACEMENT_VELO_RARE, doux)
	out["usagers doux à chaud"] = float(Time.get_ticks_usec() - t0) / float(n)

	t0 = Time.get_ticks_usec()
	for i in n:
		avancer(mois)
	out["la pulsation entière"] = float(Time.get_ticks_usec() - t0) / float(n)

	# Le seul coût par IMAGE du trafic : le balayage des arrivées et les deux
	# ou trois voitures qui changent d'arc. Tout le reste est sur le GPU.
	t0 = Time.get_ticks_usec()
	for i in n:
		_process(1.0 / 60.0)
	out["le circuit (chaque image)"] = float(Time.get_ticks_usec() - t0) / float(n)

	t0 = Time.get_ticks_usec()
	_affectation(_indisponibles(mois))
	out["une affectation (au clic)"] = float(Time.get_ticks_usec() - t0)
	var rien := PackedByteArray()
	rien.resize(_vers.size())
	rien.fill(0)
	var sources := 0
	t0 = Time.get_ticks_usec()
	for u in _deb.size() - 1:
		if _deb[u + 1] - _deb[u] != 2 and _deb[u + 1] > _deb[u]:
			sources += 1
			_dijkstra(u, rien)
	out["  dont les %d Dijkstra" % sources] = float(Time.get_ticks_usec() - t0)
	return out


func _compter(fam: Famille) -> int:
	var n := 0
	for v in fam.vus:
		n += int(v)
	return n


func _rues_avec_trottoir() -> int:
	var n := 0
	for fid in ville.routes:
		if float(ville.routes[fid].get("bord_trottoir_m", 0.0)) > 0.0:
			n += 1
	return n


## Contrôle de l'essai, comme `voitures_visibles_sur` : piétons puis cyclistes
## réellement dessinés sur un fid.
func doux_visibles_sur(fid: int) -> Array:
	var out := []
	for fam in [_pieds, _roues]:
		var n := 0
		if fam.groupes.has(fid):
			var g: Array = fam.groupes[fid]
			for k in range(int(g[0]), int(g[1])):
				n += int(fam.vus[k])
		out.append(n)
	return out


## 🧩 LES VOITURES DU MORCEAU DROIT, POUR LA MINIATURE DE LA FICHE. `places` et
## `roule` sont l'état QU'ON VEUT MONTRER, pas celui de la ville : survoler
## « Retirer les places » vide la bordure avant qu'on ait cliqué (décision 12).
##
## 🔄 ON NE RECOPIE PLUS LES INSTANCES DE LA VILLE (2026-08-31) : la fiche ne
## montre plus un bout de rue réel mais un échantillon droit, où aucune voiture
## de la ville ne passe. Les RÈGLES, elles, ne bougent pas — même espacement
## selon la charge, mêmes teintes, même animation. Une seule différence, et
## elle est voulue : la fiche pose TOUTES les places du tronçon au mètre, quand
## la ville n'en échantillonne qu'une sur trois. De près, la bordure doit être
## pleine — c'est ce que « Retirer les places » enlève.
## Rend le nombre écrit dans chacun des deux MultiMesh.
func remplir_droit(mm_gare: MultiMesh, mm_roule: MultiMesh,
		mm_pieton: MultiMesh, mm_velo: MultiMesh, fid: int,
		mois: float, places: bool, roule: bool, longueur: float,
		chaussee: float) -> Array:
	var axe := PackedVector2Array([Vector2(-longueur * 0.5, 0.0),
		Vector2(longueur * 0.5, 0.0)])
	var cum := PackedFloat32Array([0.0, longueur])
	# 🔴 DEUX ÉTATS, ET C'EST LE PARTAGE DES DEUX DÉCISIONS : une rue noyée n'a
	# plus rien, une rue FERMÉE n'a plus que ses places — les retirer se paie à
	# part, la miniature ne doit pas les faire disparaître d'elle-même.
	var praticable: bool = ville.route_praticable(fid, mois)
	var roulable := praticable and not _fermees.has(fid)
	var hier := str(ville.routes[fid].get("hierarchie", "rue"))

	var n_g := 0
	if places and praticable:
		# La densité de places AU MÈTRE, mesurée sur le tronçon : c'est elle qui
		# fait qu'une rue à 49 places sur 134 m en montre quinze sur quarante.
		var lg := maxf(float(ville.routes[fid].get("longueur_m", 0.0)), 1.0)
		n_g = int(roundf(ville.valeur("r", fid, "stationnement", mois)
			/ lg * longueur))
		n_g = mini(n_g, 2 * int(longueur / LONGUEUR_PLACE))
	mm_gare.instance_count = n_g
	var par_cote := int(ceil(n_g / 2.0))
	var depart := (longueur - par_cote * LONGUEUR_PLACE) * 0.5
	var bord := _bord_gare(ville.routes[fid])
	for k in n_g:
		@warning_ignore("integer_division")
		var rang: int = k / 2
		var cote := -1.0 if k % 2 else 1.0
		mm_gare.set_instance_transform(k, _transforme(axe, cum, longueur,
			depart + (rang + 0.5) * LONGUEUR_PLACE, cote * bord, Y_GARE))
		var gris := 0.62 + 0.16 * float(k % 5) / 4.0
		mm_gare.set_instance_color(k, Color(gris, gris * 1.01, gris * 0.98))

	var q := float(ville.valeur("r", fid, "charge", mois))
	var esp: float = lerpf(ESPACEMENT_CALME, ESPACEMENT_CHARGE,
		pow(clampf(q / 0.65, 0.0, 1.0), 0.72))
	var n_r := maxi(1, int(floor(longueur / esp))) if roule and roulable else 0
	var vitesse: float = maxf(1.1, float(VITESSES.get(hier, 30.0)) / 3.6
		* (1.0 - 0.92 * q * q))
	mm_roule.instance_count = n_r
	for k in n_r:
		var segment := _segment(axe, cum, longueur,
			fmod((k + 0.35) * longueur / n_r, longueur),
			maxf(1.35, chaussee * 0.25), -1.0 if k % 2 else 1.0)
		mm_roule.set_instance_transform(k, segment[0])
		mm_roule.set_instance_color(k, PALETTE[(k * 5 + 1) % PALETTE.size()])
		mm_roule.set_instance_custom_data(k, Color(float(segment[1]), vitesse,
			float(segment[2]), 1.0))

	# 🚶🚲 La foule du morceau, à la règle de la ville. Une nuance voulue : la
	# rue qu'on vient de fermer garde sa `charge` six mois, le temps de la
	# rampe — la miniature, elle, montre ce qui sera LIVRÉ, donc une rue fermée
	# y est déjà rendue aux piétons. C'est tout l'objet du bouton APRÈS.
	var q_doux := 0.0 if not roulable else q
	var trottoir := float(ville.routes[fid].get("bord_trottoir_m", 0.0))
	var n_p := _doux_droit(mm_pieton, axe, cum, longueur,
		trottoir if trottoir > 0.0 else maxf(1.0, chaussee * 0.5 - 0.35),
		Y_ROULE + (Y_MARCHE if trottoir > 0.0 else 0.0),
		q_doux if praticable else 1.0, CHASSE_PIETON, ESPACEMENT_PIETON_ANIME,
		ESPACEMENT_PIETON_DESERT, VITESSE_PIETON, 0.26, praticable, hier)
	var n_v := _doux_droit(mm_velo, axe, cum, longueur,
		_bord_velo(ville.routes[fid]), Y_ROULE,
		q_doux if praticable else 1.0, CHASSE_VELO, ESPACEMENT_VELO_DENSE,
		ESPACEMENT_VELO_RARE, VITESSE_VELO, 0.0, praticable, hier)
	return [n_g, n_r, n_p, n_v]


## La même foule que la ville, posée droit : ici tous les créneaux servent, il
## n'y a donc ni réserve ni sélection — le morceau ne fait que 40 m.
func _doux_droit(mm: MultiMesh, axe: PackedVector2Array,
		cum: PackedFloat32Array, longueur: float, decal: float, y: float,
		q: float, chasse: float, esp_dense: float, esp_rare: float,
		vitesse: float, ecart: float, praticable: bool, hier: String) -> int:
	var base := float(FOULE.get(hier, 0.8))
	var f := clampf(base * (1.0 - chasse * q), 0.0, 1.0) if praticable else 0.0
	var creneaux := 0 if int(f * 32.0) == 0 else \
		int(floor(longueur / lerpf(esp_rare, esp_dense, f)))
	mm.instance_count = creneaux * 2
	for k in creneaux * 2:
		@warning_ignore("integer_division")
		var r: int = k / 2
		var seg := _segment(axe, cum, longueur,
			fmod((float(r) + 0.35 + 0.5 * float(k % 2)) * longueur / creneaux,
			longueur), decal + ecart * (float(r % 3) - 1.0),
			-1.0 if k % 2 else 1.0, y)
		mm.set_instance_transform(k, seg[0])
		mm.set_instance_color(k, HABITS[(k * 3 + 1) % HABITS.size()])
		mm.set_instance_custom_data(k, Color(float(seg[1]), vitesse,
			float(seg[2]), 1.0))
	return creneaux * 2


## Contrôle de l'essai : roulantes puis garées réellement dessinées sur un fid.
func voitures_visibles_sur(fid: int) -> Array:
	var roulantes := 0
	for k in _roulantes.size():
		if _arc_fid[int((_roulantes[k] as Dictionary)["arc"])] == fid:
			roulantes += int(_visibles_roule[k])
	var garees := 0
	for k in _garees.size():
		if int(_garees[k]["fid"]) == fid:
			garees += int(_visibles_gare[k])
	return [roulantes, garees]


## Une affectation agrégée au clic, jamais une navigation par voiture.
func retirer_axe(fid: int, mois: float) -> void:
	if _fermees.has(fid):
		return
	_fermees[fid] = mois
	_reaffecter(mois, 6.0, _indisponibles(mois))
	_derniere_charge = -1.0


func axe_ferme(fid: int) -> bool:
	return _fermees.has(fid)


func report_en_cours(fid: int, mois: float) -> bool:
	return _fermees.has(fid) and mois < float(_fermees[fid]) + 6.0


func _reaffecter(mois: float, duree: float, indisponibles: Dictionary) -> void:
	var brut: Array = _affectation(indisponibles)
	for f in ville.routes:
		var ct: float = pow(minf(1.0, float(brut[0].get(f, 0)) / _calibration[0]), 0.6)
		var cl: float = pow(minf(1.0, float(brut[1].get(f, 0)) / _calibration[1]), 0.6)
		var cible: float = 0.0 if indisponibles.has(f) else \
			clampf(0.55 * ct + 0.45 * cl, 0.0, 1.0)
		ville.ajouter_rampe("r", f, "charge",
			cible - ville.valeur("r", f, "charge", mois), mois, 0.0, duree)
	_indisponibles_connues = _signature(indisponibles)
	_derniere_charge = -1.0
	_dernier_etat = -1.0


func _indisponibles(mois: float) -> Dictionary:
	var out := _impraticables(mois)
	out.merge(_fermees)
	return out


## 🚶 CE QUI ARRÊTE UN PIÉTON N'EST PAS CE QUI ARRÊTE UNE VOITURE. Une rue
## noyée ou un pont emporté vident tout ; une rue FERMÉE AUX VOITURES, non —
## c'est même là qu'on doit voir la foule revenir. Les usagers doux lisent donc
## l'impraticable seul, jamais `_fermees`.
func _impraticables(mois: float) -> Dictionary:
	var out := {}
	for fid in ville.routes:
		if not ville.route_praticable(fid, mois):
			out[fid] = true
	return out


static func _signature(indisponibles: Dictionary) -> String:
	var fids := indisponibles.keys()
	fids.sort()
	var morceaux := PackedStringArray()
	for fid in fids:
		morceaux.append(str(fid))
	return ",".join(morceaux)


func reinitialiser() -> void:
	_fermees.clear()
	_semer_circuit()
	var indisponibles := _indisponibles(0.0)
	_reaffecter(0.0, 0.0, indisponibles)
	_dernier_etat = -1.0
	_derniere_charge = -1.0


## Le réseau en TABLEAUX PLATS (CSR), pas en dictionnaires de listes : les 156
## Dijkstra d'une affectation sont le seul calcul lourd de la maquette, et un
## nœud désigné par un rang entier n'a ni chaîne à hacher ni tableau à
## déréférencer.
var _deb := PackedInt32Array()       # rang du nœud → sa première arête
var _vers := PackedInt32Array()      # arête → nœud d'arrivée
var _temps := PackedFloat64Array()   # arête → secondes
var _fid_arete := PackedInt32Array()
## Combien d'arêtes ÉLÉMENTAIRES une arête contractée remplace : le flux se
## comptait par bout de polyligne traversé, il faut garder le compte.
var _poids := PackedInt32Array()


## 🔴 LE RÉSEAU EST CONTRACTÉ : un sommet de polyligne dont les deux bouts
## portent le même tronçon n'est pas un carrefour, il ne décide de rien, et
## Dijkstra le traversait quand même. 414 nœuds et 432 arêtes deviennent 159 et
## 177 — même graphe, mêmes temps, mêmes charges.
## ⚠️ On ne contracte QUE si les deux arêtes portent le même `fid` : la jonction
## de deux tronçons doit rester un nœud, sinon fermer l'un des deux ne crée plus
## le cul-de-sac que l'affectation traite comme une porte.
func _batir_graphe(couloirs: Dictionary) -> void:
	var index := {}
	var liens := []
	for cle in couloirs:
		var fid := int(cle)
		var hier := str(ville.routes[fid].get("hierarchie", "rue"))
		var vitesse := float(VITESSES.get(hier, 30.0)) / 3.6
		for brut in (couloirs[cle][1] as Array):
			for k in range(0, brut.size() - 2, 2):
				var a := Vector2(float(brut[k]), float(brut[k + 1]))
				var b := Vector2(float(brut[k + 2]), float(brut[k + 3]))
				# Le demi-mètre de raccord : deux morceaux qui se touchent
				# doivent tomber sur le MÊME nœud, sinon le réseau se déchire.
				var ka := roundi(a.x * 2.0) * 8388608 + roundi(a.y * 2.0)
				var kb := roundi(b.x * 2.0) * 8388608 + roundi(b.y * 2.0)
				if ka == kb:
					continue
				var ia := int(index.get(ka, -1))
				if ia < 0:
					ia = liens.size()
					index[ka] = ia
					liens.append([])
				var ib := int(index.get(kb, -1))
				if ib < 0:
					ib = liens.size()
					index[kb] = ib
					liens.append([])
				var t := a.distance_to(b) / vitesse
				liens[ia].append([ib, t, fid])
				liens[ib].append([ia, t, fid])

	var elementaires := 0
	for u in liens.size():
		elementaires += (liens[u] as Array).size()
	var total := liens.size()
	var traverse := PackedByteArray()
	traverse.resize(total)
	for u in total:
		var l: Array = liens[u]
		traverse[u] = 1 if l.size() == 2 and int(l[0][2]) == int(l[1][2]) else 0
	var rang := PackedInt32Array()
	rang.resize(total)
	rang.fill(-1)
	var ancres := []
	for u in total:
		if traverse[u] == 0 and not (liens[u] as Array).is_empty():
			rang[u] = ancres.size()
			ancres.append(u)

	var chaines := []
	for i in ancres.size():
		chaines.append([])
	for i in ancres.size():
		for e in (liens[ancres[i]] as Array):
			var precedent: int = ancres[i]
			var courant := int(e[0])
			var t := float(e[1])
			var bouts := 1
			while traverse[courant] == 1:
				var paire: Array = liens[courant]
				var suivant := int(paire[0][0])
				var dt := float(paire[0][1])
				if suivant == precedent:
					suivant = int(paire[1][0])
					dt = float(paire[1][1])
				precedent = courant
				courant = suivant
				t += dt
				bouts += 1
			chaines[i].append([rang[courant], t, int(e[2]), bouts])

	_deb.resize(ancres.size() + 1)
	for i in ancres.size():
		_deb[i] = _vers.size()
		for c in (chaines[i] as Array):
			_vers.append(int(c[0]))
			_temps.append(float(c[1]))
			_fid_arete.append(int(c[2]))
			_poids.append(int(c[3]))
	_deb[ancres.size()] = _vers.size()
	@warning_ignore("integer_division")
	print("  réseau : %d nœuds et %d arêtes ramenés à %d et %d par contraction"
		% [total, elementaires / 2, ancres.size(), _poids.size() / 2])


## 🔄 LE CIRCUIT, calculé UNE FOIS. Le réseau élémentaire — pas le contracté de
## Dijkstra, qui a perdu les coudes — devient des arcs orientés, et chaque arc
## reçoit UN suivant. Aucune voiture ne décide rien : elles suivent la table.
##
## 🔴 LA TABLE EST UNE PERMUTATION, et c'est ce qui tient tout. À chaque nœud,
## les arcs qui ENTRENT sont appariés un à un à ceux qui SORTENT — donc les
## circuits sont fermés et couvrent tous les arcs, et une rue ne peut pas se
## vider au profit d'une autre. « Le plus droit devant » seul ne le garantit
## pas : deux entrées choisiraient la même sortie, et tout le trafic finirait
## par se vider dans une poignée de boucles.
func _batir_arcs(couloirs: Dictionary) -> void:
	var sorties := []
	var entrees := []
	for cle in couloirs:
		var fid := int(cle)
		for brut in (couloirs[cle][1] as Array):
			for k in range(0, brut.size() - 2, 2):
				var a := Vector2(float(brut[k]), float(brut[k + 1]))
				var b := Vector2(float(brut[k + 2]), float(brut[k + 3]))
				var na := _noeud(sorties, entrees, a)
				var nb := _noeud(sorties, entrees, b)
				# Le demi-mètre de raccord de `_batir_graphe` : sous lui, les
				# deux bouts sont le même nœud et le segment n'existe pas.
				if na == nb:
					continue
				var e := _arc_L.size()
				_ajouter_arc(a, b, na, nb, fid, sorties, entrees)
				_ajouter_arc(b, a, nb, na, fid, sorties, entrees)
				_arc_inverse[e] = e + 1
				_arc_inverse[e + 1] = e

	_sortie_deb.resize(sorties.size() + 1)
	for u in sorties.size():
		_sortie_deb[u] = _sortie_arc.size()
		for e in (sorties[u] as Array):
			_sortie_arc.append(int(e))
	_sortie_deb[sorties.size()] = _sortie_arc.size()
	_arc_suivant.resize(_arc_L.size())
	_arc_suivant.fill(-1)
	for u in sorties.size():
		_apparier(entrees[u], sorties[u])
	var demi_tours := 0
	for e in _arc_L.size():
		if _arc_suivant[e] == _arc_inverse[e]:
			demi_tours += 1
	print("  circuit : %d arcs orientés, %d culs-de-sac où la voiture"
		% [_arc_L.size(), demi_tours] + " fait demi-tour")


## L'appariement d'un nœud, exact : les degrés vont de 1 à 5 ici, donc au pire
## 120 combinaisons. Le demi-tour est pénalisé, pas interdit — au bout d'une
## impasse il est le seul mouvement possible.
func _apparier(ins: Array, outs: Array) -> void:
	var pris := PackedByteArray()
	pris.resize(outs.size())
	var choix := PackedInt32Array()
	choix.resize(ins.size())
	var garde := PackedInt32Array()
	garde.resize(ins.size())
	var meilleur := [-INF]
	_essayer(ins, outs, 0, 0.0, pris, choix, garde, meilleur)
	for i in ins.size():
		_arc_suivant[int(ins[i])] = int(outs[garde[i]])


func _essayer(ins: Array, outs: Array, i: int, score: float,
		pris: PackedByteArray, choix: PackedInt32Array,
		garde: PackedInt32Array, meilleur: Array) -> void:
	if i == ins.size():
		if score > float(meilleur[0]):
			meilleur[0] = score
			for j in choix.size():
				garde[j] = choix[j]
		return
	var e := int(ins[i])
	for j in outs.size():
		if pris[j] == 1:
			continue
		var f := int(outs[j])
		var d := -10.0 if f == _arc_inverse[e] else _arc_dir[e].dot(_arc_dir[f])
		pris[j] = 1
		choix[i] = j
		_essayer(ins, outs, i + 1, score + d, pris, choix, garde, meilleur)
		pris[j] = 0


func _noeud(sorties: Array, entrees: Array, p: Vector2) -> int:
	var cle := roundi(p.x * 2.0) * 8388608 + roundi(p.y * 2.0)
	var u := int(_rang_noeud.get(cle, -1))
	if u < 0:
		u = sorties.size()
		_rang_noeud[cle] = u
		sorties.append([])
		entrees.append([])
	return u


func _ajouter_arc(a: Vector2, b: Vector2, na: int, nb: int, fid: int,
		sorties: Array, entrees: Array) -> void:
	var e := _arc_L.size()
	var u := (b - a).normalized()
	var pos := a + Vector2(u.y, -u.x) * DECAL_FILE
	_arc_t.append(Transform3D(Basis(Vector3.UP, atan2(u.x, u.y)),
		Vector3(pos.x, Y_ROULE, pos.y)))
	_arc_L.append(maxf(a.distance_to(b), 0.01))
	_arc_fid.append(fid)
	_arc_dir.append(u)
	_arc_tete.append(nb)
	_arc_inverse.append(e)
	_arc_par_paire[na * 65536 + nb] = e
	(sorties[na] as Array).append(e)
	(entrees[nb] as Array).append(e)


## Le détour du clic, et lui seul : une rue qu'on vient de fermer se vide au
## coin suivant au lieu d'avaler les voitures. Il sort de la permutation, donc
## il ne sert JAMAIS au réseau ouvert — sinon les circuits se déforment.
func _droit_devant(e: int, interdits: Dictionary) -> int:
	var mieux := -1
	var score := -2.0
	var u := _arc_dir[e]
	var tete := _arc_tete[e]
	for i in range(_sortie_deb[tete], _sortie_deb[tete + 1]):
		var f := _sortie_arc[i]
		if f == _arc_inverse[e] or interdits.has(_arc_fid[f]):
			continue
		var d := u.dot(_arc_dir[f])
		if d > score:
			score = d
			mieux = f
	return mieux if mieux >= 0 else _arc_inverse[e]


func _suivant(e: int) -> int:
	var f := _arc_suivant[e]
	if not _indispo_courant.has(_arc_fid[f]):
		return f
	return _droit_devant(e, _indispo_courant)


## De (chemin, abscisse, sens) à (arc, distance parcourue dessus). Rend un arc
## négatif quand le morceau a été avalé par le raccord d'un demi-mètre.
func _poser(pts: PackedVector2Array, cum: PackedFloat32Array, s: float,
		sens: float) -> Array:
	var j := 1
	while j < cum.size() - 1 and cum[j] < s:
		j += 1
	var na := int(_rang_noeud.get(
		roundi(pts[j - 1].x * 2.0) * 8388608 + roundi(pts[j - 1].y * 2.0), -1))
	var nb := int(_rang_noeud.get(
		roundi(pts[j].x * 2.0) * 8388608 + roundi(pts[j].y * 2.0), -1))
	if na < 0 or nb < 0 or na == nb:
		return [-1, 0.0]
	var e := int(_arc_par_paire.get(
		(na * 65536 + nb) if sens > 0.0 else (nb * 65536 + na), -1))
	if e < 0:
		return [-1, 0.0]
	var offset: float = (s - cum[j - 1]) if sens > 0.0 else (cum[j] - s)
	return [e, clampf(offset, 0.0, _arc_L[e])]


## Engager la voiture au DÉBUT d'un arc : le shader repart de zéro, et la phase
## est calée sur l'horloge partagée pour que rien ne saute.
func _engager(k: int, e: int, v: float) -> void:
	var a: Dictionary = _roulantes[k]
	a["arc"] = e
	a["v"] = v
	a["phase"] = -_temps_trafic * v
	a["arrivee"] = _temps_trafic + _arc_L[e] / v
	_arrivee[k] = float(a["arrivee"])
	if _visibles_roule[k] == 1:
		_ecrire(k, a)


## La vitesse a changé : la voiture repart D'OÙ ELLE EST, pas du bord de l'arc
## — sinon toute la file saute d'un coup à chaque pulsation.
func _recaler(k: int, a: Dictionary, v: float) -> void:
	var e: int = a["arc"]
	var offset := clampf(float(a["phase"]) + _temps_trafic * float(a["v"]),
		0.0, _arc_L[e])
	a["v"] = v
	a["phase"] = offset - _temps_trafic * v
	a["arrivee"] = _temps_trafic + (_arc_L[e] - offset) / v
	_arrivee[k] = float(a["arrivee"])


## Remettre toutes les voitures là où le semis les avait posées : sans ça, une
## partie relancée ne repart pas de la même image que la précédente.
func _semer_circuit() -> void:
	for k in _roulantes.size():
		var a: Dictionary = _roulantes[k]
		var e := int(a["arc0"])
		var offset := float(a["offset0"])
		var v := _vitesse_de(_arc_fid[e])
		a["arc"] = e
		a["v"] = v
		a["phase"] = offset - _temps_trafic * v
		a["arrivee"] = _temps_trafic + (_arc_L[e] - offset) / v
		_arrivee[k] = float(a["arrivee"])
		_arc_vu[k] = -1


func _ecrire(k: int, a: Dictionary) -> void:
	var e: int = a["arc"]
	_mm_roule.set_instance_transform(k, _arc_t[e])
	_mm_roule.set_instance_custom_data(k, Color(float(a["phase"]),
		float(a["v"]), _arc_L[e], 1.0))
	_arc_vu[k] = e


## 🔴 LE SEUL TRAVAIL PAR IMAGE DE TOUT LE TRAFIC. Une voiture parcourt un
## segment médian de 19,9 m : à 8 m/s elle change d'arc toutes les 2,5 s, donc
## deux ou trois voitures par image sur les 963. Le reste est un balayage de
## flottants, et l'animation est toujours sur le GPU.
func _process(delta: float) -> void:
	if _arrivee.is_empty():
		return
	_temps_trafic += delta
	RenderingServer.global_shader_parameter_set(Constructeur.HORLOGE,
		_temps_trafic)
	for k in _arrivee.size():
		if _temps_trafic < _arrivee[k]:
			continue
		var e := _suivant(int((_roulantes[k] as Dictionary)["arc"]))
		_engager(k, e, _vitesse_de(_arc_fid[e]))


func _vitesse_de(fid: int) -> float:
	return maxf(1.1, float(_vitesse_vue.get(fid, 8.3)))


func _affectation(fermees: Dictionary, memoriser := false) -> Array:
	var n := _deb.size() - 1
	# L'arête coupée se marque UNE FOIS ici, pas à chaque relâchement : sinon
	# c'est 190 000 lectures de dictionnaire par affectation.
	var bloquee := PackedByteArray()
	bloquee.resize(_vers.size())
	for e in _vers.size():
		bloquee[e] = 1 if fermees.has(_fid_arete[e]) else 0
	var portes := PackedInt32Array()
	var carrefours := PackedInt32Array()
	var est_porte := PackedByteArray()
	est_porte.resize(n)
	est_porte.fill(0)
	for u in n:
		var deg := 0
		for e in range(_deb[u], _deb[u + 1]):
			if bloquee[e] == 0:
				deg += 1
		if deg == 1:
			portes.append(u)
			est_porte[u] = 1
		if deg != 2 and deg > 0:
			carrefours.append(u)
	# 🔴 UNE PORTE EST AUSSI UN CARREFOUR (degré 1) : les deux comptes tournaient
	# sur des listes qui se recouvrent, donc 65 des 221 Dijkstra étaient
	# refaits à l'identique. Une seule passe par source les sert tous les deux.
	var compte_portes := {}
	var compte_carrefours := {}
	for src in carrefours:
		var trajets: Array = _dijkstra(src, bloquee)
		_verser(compte_carrefours, trajets, carrefours, src, n, memoriser)
		if est_porte[src] == 1:
			_verser(compte_portes, trajets, portes, src, n, false)
	return [compte_portes, compte_carrefours]


## Une paire dont le trajet s'allonge n'est pas reportée en entier : une part
## renonce à la voiture. Le reste du flux, lui, se reporte bien sur les rues
## voisines. `memoriser` enregistre les temps du réseau entier ouvert, seule
## référence de ce qu'un détour coûte.
func _verser(compte: Dictionary, trajets: Array, cibles: PackedInt32Array,
		src: int, n: int, memoriser: bool) -> void:
	var prec_n: PackedInt32Array = trajets[0]
	var prec_f: PackedInt32Array = trajets[1]
	var dist: PackedFloat64Array = trajets[2]
	var prec_p: PackedInt32Array = trajets[4]
	var flot := PackedFloat64Array()
	flot.resize(n)
	flot.fill(0.0)
	for cible in cibles:
		if cible == src or prec_n[cible] < 0:
			continue
		var t := dist[cible]
		var cle := src * n + cible
		if memoriser:
			_t_ref[cle] = t
		var part := 1.0
		if t > 0.0 and _t_ref.has(cle):
			var tr := float(_t_ref[cle])
			if t > tr * 1.001:
				part = (1.0 - PART_RENONCE) * clampf(
					pow(tr / t, ELASTICITE_RENONCE), 0.0, 1.0)
		flot[cible] += part
	# 🔴 LE FLUX REMONTE L'ARBRE, il ne redescend pas chaque trajet. Compter en
	# repartant de chaque cible relisait le même bout de chemin des dizaines de
	# fois : 1,5 million de pas par affectation. Dijkstra rend ses nœuds par
	# distance croissante, donc les prendre à l'envers suffit — un enfant est
	# toujours vidé avant son parent. Même total.
	var ordre: PackedInt32Array = trajets[3]
	for i in range(ordre.size() - 1, -1, -1):
		var u := ordre[i]
		var f := flot[u]
		if f == 0.0 or prec_n[u] < 0:
			continue
		var arete := prec_f[u]
		compte[arete] = float(compte.get(arete, 0.0)) + f * float(prec_p[u])
		flot[prec_n[u]] += f


## Renvoie [précédent, fid, temps, ordre de sortie, poids de l'arête] — le temps
## sert à mesurer le détour, l'ordre à remonter l'arbre sans le relire.
## 🔴 TAS BINAIRE, et c'est là que passait le temps : la file d'attente était
## balayée EN ENTIER à chaque extraction, ce qui mettait une affectation à
## 147 ms — une saccade visible à chaque réouverture de rue.
func _dijkstra(src: int, bloquee: PackedByteArray) -> Array:
	var n := _deb.size() - 1
	var dist := PackedFloat64Array()
	dist.resize(n)
	dist.fill(INF)
	var prec_n := PackedInt32Array()
	prec_n.resize(n)
	prec_n.fill(-1)
	var prec_f := PackedInt32Array()
	prec_f.resize(n)
	prec_f.fill(-1)
	var prec_p := PackedInt32Array()
	prec_p.resize(n)
	prec_p.fill(0)
	var tas_d := PackedFloat64Array([0.0])
	var tas_n := PackedInt32Array([src])
	dist[src] = 0.0
	var ordre := PackedInt32Array()
	while not tas_n.is_empty():
		var dt := tas_d[0]
		var u := tas_n[0]
		var dernier := tas_n.size() - 1
		tas_d[0] = tas_d[dernier]
		tas_n[0] = tas_n[dernier]
		tas_d.resize(dernier)
		tas_n.resize(dernier)
		var i := 0
		while true:
			var g := i * 2 + 1
			if g >= dernier:
				break
			if g + 1 < dernier and tas_d[g + 1] < tas_d[g]:
				g += 1
			if tas_d[g] >= tas_d[i]:
				break
			var ed := tas_d[i]
			tas_d[i] = tas_d[g]
			tas_d[g] = ed
			var en := tas_n[i]
			tas_n[i] = tas_n[g]
			tas_n[g] = en
			i = g
		if dt > dist[u] + 0.000001:
			continue
		ordre.append(u)
		for e in range(_deb[u], _deb[u + 1]):
			if bloquee[e] == 1:
				continue
			var v := _vers[e]
			var nd := dt + _temps[e]
			if nd >= dist[v] - 0.000001:
				continue
			dist[v] = nd
			prec_n[v] = u
			prec_f[v] = _fid_arete[e]
			prec_p[v] = _poids[e]
			tas_d.append(nd)
			tas_n.append(v)
			var j := tas_n.size() - 1
			while j > 0:
				var pa := (j - 1) >> 1
				if tas_d[pa] <= tas_d[j]:
					break
				var ed2 := tas_d[j]
				tas_d[j] = tas_d[pa]
				tas_d[pa] = ed2
				var en2 := tas_n[j]
				tas_n[j] = tas_n[pa]
				tas_n[pa] = en2
				j = pa
	return [prec_n, prec_f, dist, ordre, prec_p]


static func _p95(compte: Dictionary) -> float:
	var valeurs := compte.values()
	valeurs.sort()
	return maxf(1.0, float(valeurs[int(0.95 * (valeurs.size() - 1))])) \
		if not valeurs.is_empty() else 1.0


func _maj_garees(mois: float, force: bool) -> void:
	if not force and is_equal_approx(mois, _dernier_etat):
		return
	_dernier_etat = mois
	# Combien de voitures est une propriété des 98 RUES marquées, pas des 745
	# voitures : `stationnement` se lit une fois par rue, et on n'écrit que les
	# instances qui basculent — comme les roulantes.
	var combien := {}
	var vus := {}
	for k in _garees.size():
		var a: Dictionary = _garees[k]
		var fid: int = a["fid"]
		var visibles := int(combien.get(fid, -1))
		if visibles < 0:
			visibles = 0 if not ville.route_praticable(fid, mois) else \
				int(roundf(ville.valeur("r", fid, "stationnement", mois)
				* ECHANTILLON_STATIONNEMENT))
			combien[fid] = visibles
		var rang := int(vus.get(fid, 0))
		vus[fid] = rang + 1
		var montre := rang < visibles
		# 🔄 LE CONTRÔLE NE RELIT PLUS LA MATRICE — corrigé le 2026-08-26. Une
		# base mise à zéro ressortait de `get_instance_transform` en IDENTITÉ,
		# donc l'essai voyait 5 voitures garées sur une rue noyée qui n'en
		# dessinait aucune. On note ce qu'on écrit, comme pour les roulantes.
		if not force and montre == (_visibles_gare[k] == 1):
			continue
		_visibles_gare[k] = 1 if montre else 0
		_mm_gare.set_instance_transform(k, a["t"] if montre else _vide)


static func _chemin(brut: Array) -> Array:
	var pts := PackedVector2Array()
	for k in range(0, brut.size(), 2):
		pts.append(Vector2(float(brut[k]), float(brut[k + 1])))
	var cum := PackedFloat32Array([0.0])
	for k in range(1, pts.size()):
		cum.append(cum[-1] + pts[k - 1].distance_to(pts[k]))
	return [pts, cum[-1], cum]


static func _segment(pts: PackedVector2Array, cum: PackedFloat32Array,
		longueur: float, s: float, decal: float, sens: float,
		y := Y_ROULE) -> Array:
	s = clampf(s, 0.0, longueur)
	var j := 1
	while j < cum.size() - 1 and cum[j] < s:
		j += 1
	var p := pts[j - 1]
	var q := pts[j]
	var segment_m := maxf(p.distance_to(q), 0.01)
	var depart := p if sens > 0.0 else q
	var u := ((q - p) if sens > 0.0 else (p - q)).normalized()
	var phase := s - cum[j - 1] if sens > 0.0 else cum[j] - s
	var pos := depart + Vector2(u.y, -u.x) * decal
	var basis := Basis(Vector3.UP, atan2(u.x, u.y))
	return [Transform3D(basis, Vector3(pos.x, y, pos.y)), phase, segment_m]


static func _transforme(pts: PackedVector2Array, cum: PackedFloat32Array,
		longueur: float, s: float, decal: float, y: float, sens := 1.0) -> Transform3D:
	s = clampf(s, 0.0, longueur)
	var j := 1
	while j < cum.size() - 1 and cum[j] < s:
		j += 1
	var p := pts[j - 1]
	var q := pts[j]
	var u := (q - p).normalized() * sens
	var t := clampf((s - cum[j - 1]) / maxf(cum[j] - cum[j - 1], 0.001), 0.0, 1.0)
	var pos := p.lerp(q, t) + Vector2(u.y, -u.x) * decal
	var basis := Basis(Vector3.UP, atan2(u.x, u.y))
	return Transform3D(basis, Vector3(pos.x, y, pos.y))
