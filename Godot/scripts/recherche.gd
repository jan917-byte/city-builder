extends RefCounted
# L'institut (113, révise 79) : un sujet s'achète en points, au clic, et vaut tout de suite.
# L'état — quel sujet est acquis, à quel mois — vit dans `ville.gd`, comme les
# poses ; ici, la table et les fonctions pures.
const Objectifs := preload("res://scripts/objectifs.gd")
const Politiques := preload("res://scripts/politiques.gd")

# ==========================================================================
# 🎚️ LEVEL DESIGN — les tables que l'auteur règle (113)
# ==========================================================================
# La caisse dit quoi bâtir, les points quoi apprendre : aucun euro ici.
# 🌳 L'ARBRE (auteur, 2026-10-18) : toute action du jeu s'achète ici ; `apres` la tient
# fermée jusqu'à ses parents. Les points ne viennent que des objectifs, un chacun.
# 🔴 Garde-fou de 113 : les objectifs paient environ la MOITIÉ de l'arbre (≈ 13 sur 24),
# sinon on finit par tout acquérir et choisir ne sert plus.
const POINTS_OBJECTIF := 1        # chaque objectif atteint, en bas à gauche
# 🎓 Les gestes dont la première livraison se note (`ville._premieres`).
const PREMIERES_FOIS := ["berge", "toit vert", "sol perméable", "culture"]
# Prix selon la taille : 1 un rendement, 2 un geste nouveau, 3 un objet neuf.
# 🔴 Des paliers de rendement PETITS, exprès : un gros palier tardif rattraperait
# une partie ratée. Les grands gains viennent des objets neufs, encore à écrire.
# « ouvre » : le sujet est une action, `levier` sa clé dans `ouverture.levier_ferme`.
# 🗂️ QUATRE COLONNES, une racine chacune, aucun lien de l'une à l'autre (auteur, 2026-10-19).
const SUJETS := {
	"pilotis": {
		"nom": "Construction sur pilotis",
		"quoi": "Rebâtir un îlot sinistré le rez sur poteaux : l'eau passe dessous.",
		"points": 2, "apres": [],
		"effet": "facon_pilotis", "valeur": 1.0, "domaine": "bati",
	},
	# 🏛️ Le parc inondable vient du concours (auteur, 2026-10-21) ; les maisons amphibies,
	# technique nouvelle, s'apprennent ici.
	"amphibies": {
		"nom": "Maisons amphibies",
		"quoi": "Des maisons posées sur un caisson qui flotte : quand l'Ilse monte, elles montent avec elle.",
		"points": 2, "apres": [],
		"effet": "facon_amphibies", "valeur": 1.0, "domaine": "bati",
	},
	"densifier": {
		"nom": "Densifier",
		"quoi": "Monter un étage ou deux sur un îlot : plus de logements, sans s'étaler.",
		"points": 3, "apres": ["pilotis"],
		"effet": "ouvre", "valeur": 1.0, "domaine": "bati",
	},
	"vert": {
		"nom": "Toits verts",
		"quoi": "Verdir les toits plats : ils boivent la pluie et rafraîchissent.",
		"points": 2, "apres": [],
		"effet": "ouvre", "valeur": 1.0, "domaine": "bati",
	},
	"sedum": {
		"nom": "Substrat léger",
		"quoi": "−20 % sur le prix d'un toit vert",
		"points": 1, "apres": ["vert"],
		"effet": "cout_vert_x", "valeur": 0.80, "domaine": "bati",
	},
	"berge": {
		"nom": "Rendre une berge",
		"quoi": "Rendre une berge à l'Ilse : la rive redevient naturelle, la crue baisse le long du bief.",
		"points": 2, "apres": [],
		"effet": "ouvre", "valeur": 1.0, "domaine": "public",
	},
	"pre": {
		"nom": "Pré inondable",
		"quoi": "Laisser un pré déborder : il retient l'eau avant la ville.",
		"points": 1, "apres": ["berge"],
		"effet": "ouvre", "valeur": 1.0, "domaine": "public",
	},
	"permeable": {
		"nom": "Sol perméable",
		"quoi": "Rendre un parking perméable : la pluie rentre dans la terre.",
		"points": 2, "apres": [],
		"effet": "ouvre", "valeur": 1.0, "domaine": "public",
	},
	"arbres": {
		"nom": "Planter des arbres",
		"quoi": "Des arbres le long des rues : de l'ombre, et la pluie retenue.",
		"points": 2, "apres": [],
		"effet": "ouvre", "valeur": 1.0, "domaine": "public",
	},
	"solaire": {
		"nom": "Panneaux solaires",
		"quoi": "Poser des panneaux sur les toits : la ville produit son énergie.",
		"points": 2, "apres": [],
		"effet": "ouvre", "valeur": 1.0, "domaine": "energie",
	},
	"rendement": {
		"nom": "Rendement des panneaux",
		"quoi": "+8 % de production sur TOUS les toits, posés compris",
		"points": 1, "apres": ["solaire"],
		"effet": "rendement_x", "valeur": 1.08, "domaine": "energie",
	},
	"pose": {
		"nom": "Pose industrialisée",
		"quoi": "−15 % sur le prix de pose des panneaux",
		"points": 1, "apres": ["solaire"],
		"effet": "cout_panneau_x", "valeur": 0.85, "domaine": "energie",
	},
	# 🌉 Idée de l'auteur (118, 2026-10-20) : un pont en dur engagé après lui tient à la prochaine crue.
	"pont_resistant": {
		"nom": "Pont résistant",
		"quoi": "Rebâtir les ponts plus hauts, sur moins de piles : la prochaine crue passe dessous.",
		"points": 2, "apres": [],
		"effet": "pont_resistant", "valeur": 1.0, "domaine": "trafic",
	},
	"places": {
		"nom": "Retirer des places",
		"quoi": "Retirer le stationnement d'une rue : la place revient à autre chose.",
		"points": 1, "apres": [],
		"effet": "ouvre", "valeur": 1.0, "domaine": "trafic",
	},
	"rue": {
		"nom": "Fermer une rue",
		"quoi": "Fermer une rue aux voitures : le trafic se reporte ailleurs.",
		"points": 2, "apres": ["places"],
		"effet": "ouvre", "valeur": 1.0, "domaine": "trafic",
	},
}
## 🎚️ Ce que l'institut montre avant le premier achat : les réponses à la crue (auteur, 2026-10-19).
const D_ABORD := ["pilotis", "amphibies", "berge"]   # 🌉 le pont résistant suit, après un premier achat
const PILOTIS := "pilotis"
const PONT := "pont_resistant"
const AMPHIBIES := "amphibies"
const ORDRE := ["pilotis", "amphibies", "densifier", "vert", "sedum", "berge", "pre", "permeable",
	"arbres", "solaire", "rendement", "pose", "pont_resistant", "places", "rue"]
## 🎓 Les colonnes de l'institut (auteur, 2026-10-19 ; remplace les cinq du 2026-10-09). 🔴 Flaggable (90).
const DOMAINES := [["bati", "Bâti"], ["public", "Espace public"], ["energie", "Énergie"],
	["trafic", "Trafic"]]


## Le mois où le sujet a été acquis. INF tant qu'il ne l'est pas.
static func mois_palier(v, cle: String) -> float:
	if not v._recherche.has(cle):
		return INF
	return float(v._recherche[cle])


static func acquis(v, cle: String, t: float) -> bool:
	return t >= mois_palier(v, cle)


static func prix(cle: String) -> int:
	return int(SUJETS[cle]["points"])


## Ses parents acquis : le sujet s'achète. Sinon le premier qui manque, en clair.
static func manque(v, cle: String, t: float) -> String:
	for p in SUJETS[cle]["apres"]:
		if not acquis(v, p, t):
			return String(SUJETS[p]["nom"])
	return ""


## Une action de l'arbre, achetée. `false` pour ce que l'arbre ne vend pas.
static func ouvre(v, levier: String, t: float) -> bool:
	return SUJETS.has(levier) and SUJETS[levier]["effet"] == "ouvre" and acquis(v, levier, t)


## Ce qui a fait monter le compteur jusqu'au mois `t` : [[raison, points], …].
## Fonction PURE du temps, comme la caisse : « Recommencer » n'a rien à rembobiner.
static func gains(v, t: float) -> Array:
	var out := []
	for id in v._objectifs:
		if float(v._objectifs[id]) <= t:
			out.append(["Objectif atteint : %s" % Objectifs.OBJECTIFS.get(id, id), POINTS_OBJECTIF])
	return out


## Institut et programmes de la mairie : un seul compteur (117).
static func depenses(v, t: float) -> int:
	var n := Politiques.points_depenses(v, t)
	for cle in v._recherche:
		if acquis(v, cle, t):
			n += prix(cle)
	return n


static func points(v, t: float) -> int:
	var n := 0
	for g in gains(v, t):
		n += int(g[1])
	return n - depenses(v, t)


## Le produit des paliers acquis pour un effet donné.
static func facteur(v, effet: String, t: float) -> float:
	var f := 1.0
	for cle in _cles(effet):
		if acquis(v, cle, t):
			f *= float(SUJETS[cle]["valeur"])
	return f


## ⏱️ Les sujets d'un effet, dans l'ordre d'ORDRE : `facteur` passe ~1 000 fois par somme de ville.
static var _par_effet := {}


static func _cles(effet: String) -> Array:
	if not _par_effet.has(effet):
		_par_effet[effet] = ORDRE.filter(func(cle): return SUJETS[cle]["effet"] == effet)
	return _par_effet[effet]


## Les marches de l'escalier, pour intégrer une recette dans le temps :
## `[[mois, facteur à partir de ce mois], …]`, triées, la première à zéro.
## 🔴 C'est ce qui rend le palier rétroactif SANS réécrire le passé : ce qui a
## été produit avant lui reste payé au tarif d'avant.
static func marches(v, effet: String) -> Array:
	var m := [[0.0, 1.0]]
	var dates := []
	for cle in _cles(effet):
		if v._recherche.has(cle):
			dates.append([mois_palier(v, cle), float(SUJETS[cle]["valeur"])])
	dates.sort_custom(func(a, b): return a[0] < b[0])
	var f := 1.0
	for d in dates:
		f *= float(d[1])
		m.append([float(d[0]), f])
	return m
