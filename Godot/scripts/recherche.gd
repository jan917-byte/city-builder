extends RefCounted
# L'université (décision 79) : on finance un sujet, on attend, un palier tombe.
# L'état — quel sujet est engagé, à quel mois — vit dans `ville.gd`, comme les
# poses ; ici, la table et les fonctions pures.

# ==========================================================================
# 🎚️ LEVEL DESIGN — la table que l'auteur règle (décision 79)
# ==========================================================================
# `ke_mois` × `mois` sort de LA MÊME caisse que les poses : financer, c'est ne
# pas équiper ce mois-ci. Un sujet engagé ne s'arrête plus — c'est un chantier
# sans géométrie, et un chantier ne se révise pas (`lancer_solaire`).
# 🔴 Des paliers PETITS, exprès : un gros palier tardif rattraperait une partie
# ratée. Les grands gains doivent venir des objets neufs, qui restent à écrire.
const SUJETS := {
	"rendement": {
		"nom": "Rendement des panneaux",
		"quoi": "+8 % de production sur TOUS les toits, posés compris",
		"ke_mois": 25.0, "mois": 24.0,
		"effet": "rendement_x", "valeur": 1.08,
	},
	"pose": {
		"nom": "Pose industrialisée",
		"quoi": "−15 % sur le prix de pose des panneaux",
		"ke_mois": 20.0, "mois": 18.0,
		"effet": "cout_panneau_x", "valeur": 0.85,
	},
	"sedum": {
		"nom": "Substrat léger",
		"quoi": "−20 % sur le prix d'un toit vert",
		"ke_mois": 12.0, "mois": 12.0,
		"effet": "cout_vert_x", "valeur": 0.80,
	},
}
const ORDRE := ["rendement", "pose", "sedum"]


## Le mois où le palier tombe. INF tant que le sujet n'est pas financé.
static func mois_palier(v, cle: String) -> float:
	if not v._recherche.has(cle):
		return INF
	return float(v._recherche[cle]) + float(SUJETS[cle]["mois"])


static func acquis(v, cle: String, t: float) -> bool:
	return t >= mois_palier(v, cle)


## Ce qu'il reste à attendre, en mois. 0 une fois le palier tombé.
static func reste_mois(v, cle: String, t: float) -> float:
	return maxf(mois_palier(v, cle) - t, 0.0)


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


## En k€ depuis le mois 0 : on paie chaque mois, jusqu'au palier et pas au-delà.
static func depense_ke(v, t: float) -> float:
	var ke := 0.0
	for cle in v._recherche:
		var s: Dictionary = SUJETS[cle]
		var mois := clampf(t - float(v._recherche[cle]), 0.0, float(s["mois"]))
		ke += mois * float(s["ke_mois"])
	return ke


## Le coût total d'un sujet, annoncé avant de s'engager.
static func cout_total_ke(cle: String) -> float:
	return float(SUJETS[cle]["ke_mois"]) * float(SUJETS[cle]["mois"])
