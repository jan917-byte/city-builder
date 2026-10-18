extends RefCounted
# L'institut (113, révise 79) : un sujet s'achète en points, au clic, et vaut tout de suite.
# L'état — quel sujet est acquis, à quel mois — vit dans `ville.gd`, comme les
# poses ; ici, la table et les fonctions pures.
const Calendrier := preload("res://scripts/calendrier.gd")
const Objectifs := preload("res://scripts/objectifs.gd")

# ==========================================================================
# 🎚️ LEVEL DESIGN — les tables que l'auteur règle (113)
# ==========================================================================
# La caisse dit quoi bâtir, les points quoi apprendre : aucun euro ici.
# 🔴 Garde-fou de 113 : avant la crue, les points couvrent environ la MOITIÉ du
# prix de tous les sujets — sinon on finit par tout acquérir et choisir ne sert plus.
const POINTS_DEPART := 2
const POINTS_PAR_AN := 2           # chaque janvier, avec le budget (`Calendrier.an`)
const POINTS_PREMIERE_FOIS := 1    # la première livraison de chacun de ces gestes :
const PREMIERES_FOIS := ["berge", "toit vert", "sol perméable", "culture"]  # la ville-éponge
const POINTS_OBJECTIF := 1        # chaque objectif atteint, en bas à gauche (auteur, 2026-10-18)
# Prix selon la taille : 1 un rendement, 2 un geste nouveau, 3 un objet neuf.
# 🔴 Des paliers de rendement PETITS, exprès : un gros palier tardif rattraperait
# une partie ratée. Les grands gains viennent des objets neufs, encore à écrire.
const SUJETS := {
	"rendement": {
		"nom": "Rendement des panneaux",
		"quoi": "+8 % de production sur TOUS les toits, posés compris",
		"points": 1,
		"effet": "rendement_x", "valeur": 1.08, "domaine": "solaire",
	},
	"pose": {
		"nom": "Pose industrialisée",
		"quoi": "−15 % sur le prix de pose des panneaux",
		"points": 1,
		"effet": "cout_panneau_x", "valeur": 0.85, "domaine": "solaire",
	},
	"pilotis": {
		"nom": "Construction sur pilotis",
		"quoi": "Rebâtir un îlot sinistré le rez sur poteaux : l'eau passe dessous.",
		"points": 2,
		"effet": "facon_pilotis", "valeur": 1.0, "domaine": "logement",
	},
	"sedum": {
		"nom": "Substrat léger",
		"quoi": "−20 % sur le prix d'un toit vert",
		"points": 1,
		"effet": "cout_vert_x", "valeur": 0.80, "domaine": "toits",
	},
}
# 🏗️ La seule recherche ouverte dès l'ouverture (auteur, 2026-10-08). Elle ne change
# aucun prix, elle permet de rebâtir sur pilotis (`Ville.facon_permise`).
const PILOTIS := "pilotis"
const SUJETS_OUVERTURE := [PILOTIS]
const ORDRE := ["pilotis", "rendement", "pose", "sedum"]
## 🎓 Les colonnes de l'institut (auteur, 2026-10-09) ; « eau » n'a encore aucun sujet. 🔴 Flaggable (90).
const DOMAINES := [["logement", "Logement"], ["solaire", "Solaire"], ["toits", "Toits verts"], ["eau", "Eau"]]


## Le mois où le sujet a été acquis. INF tant qu'il ne l'est pas.
static func mois_palier(v, cle: String) -> float:
	if not v._recherche.has(cle):
		return INF
	return float(v._recherche[cle])


static func acquis(v, cle: String, t: float) -> bool:
	return t >= mois_palier(v, cle)


static func prix(cle: String) -> int:
	return int(SUJETS[cle]["points"])


## Ce qui a fait monter le compteur jusqu'au mois `t` : [[raison, points], …].
## Fonction PURE du temps, comme la caisse : « Recommencer » n'a rien à rembobiner.
static func gains(v, t: float) -> Array:
	var out := [["Au départ", POINTS_DEPART]]
	var ans := Calendrier.an(t) - 1
	if ans > 0:
		out.append(["%d nouvelles années" % ans if ans > 1 else "Une nouvelle année", ans * POINTS_PAR_AN])
	for genre in PREMIERES_FOIS:
		if float(v._premieres.get(genre, INF)) <= t:
			out.append(["Premier chantier livré : %s" % genre, POINTS_PREMIERE_FOIS])
	for id in v._objectifs:
		if float(v._objectifs[id]) <= t:
			out.append(["Objectif atteint : %s" % Objectifs.OBJECTIFS.get(id, id), POINTS_OBJECTIF])
	return out


static func depenses(v, t: float) -> int:
	var n := 0
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
	for cle in ORDRE:
		if SUJETS[cle]["effet"] == effet and acquis(v, cle, t):
			f *= float(SUJETS[cle]["valeur"])
	return f


## Les marches de l'escalier, pour intégrer une recette dans le temps :
## `[[mois, facteur à partir de ce mois], …]`, triées, la première à zéro.
## 🔴 C'est ce qui rend le palier rétroactif SANS réécrire le passé : ce qui a
## été produit avant lui reste payé au tarif d'avant.
static func marches(v, effet: String) -> Array:
	var m := [[0.0, 1.0]]
	var dates := []
	for cle in ORDRE:
		if SUJETS[cle]["effet"] == effet and v._recherche.has(cle):
			dates.append([mois_palier(v, cle), float(SUJETS[cle]["valeur"])])
	dates.sort_custom(func(a, b): return a[0] < b[0])
	var f := 1.0
	for d in dates:
		f *= float(d[1])
		m.append([float(d[0]), f])
	return m
