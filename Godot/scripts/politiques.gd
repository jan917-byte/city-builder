extends RefCounted
# La mairie (décision 80) : une politique n'est pas un chantier qui se termine,
# c'est un ÉTAT qui dure et se paie tous les mois. On peut la retirer.
# L'état — les périodes où chacune a tenu — vit dans `ville.gd`.

# ==========================================================================
# 🎚️ LEVEL DESIGN — la table que l'auteur règle (décision 80)
# ==========================================================================
# 🔴 Le premier coût RÉCURRENT du jeu : signée au mois 6, une subvention pèse
# encore au mois 240. Repère : la dotation est de 30 k€/mois.
# ⚠️ Une subvention ne convainc personne — la ville possède tout (70) : elle
# CHOISIT SON AXE, elle accélère un poste en prenant sur le reste. Question
# n°25 du vault, à trancher avant d'en ajouter d'autres.
const POLITIQUES := {
	"subv_solaire": {
		"nom": "Subvention à la pose",
		"quoi": "−20 % sur le prix des panneaux, tant qu'elle tient",
		"ke_mois": 6.0, "levier": "solaire",
		"effet": "cout_panneau_x", "valeur": 0.80,
	},
	"subv_vert": {
		"nom": "Prime au toit vert",
		"quoi": "−25 % sur le prix d'un toit vert, tant qu'elle tient",
		"ke_mois": 4.0, "levier": "vert",
		"effet": "cout_vert_x", "valeur": 0.75,
	},
}
const ORDRE := ["subv_solaire", "subv_vert"]
# 🌳 Une subvention paraît à la mairie quand son levier est acheté à l'institut (`levier`).

# 🏛️ LES PROGRAMMES (117, auteur 2026-10-19) : les points ouvrent, l'argent fait. Adopté une
# fois en points ; ce qu'il ouvre (chaque concours) se paie en euros. 🔴 Textes flaggables (90).
const PROGRAMMES := {
	"concours": {
		"nom": "Concours d'architecture",
		"quoi": "Là où des maisons sont tombées, demander à des architectes trois projets pensés pour chaque îlot.",
		"points": 1,
	},
}
const PROGRAMMES_ORDRE := ["concours"]


static func adopte(v, cle: String, t: float) -> bool:
	return v._programmes.has(cle) and t >= float(v._programmes[cle])


## Les points pris par la mairie : `Recherche.points` les retire du même compteur.
static func points_depenses(v, t: float) -> int:
	var n := 0
	for cle in v._programmes:
		if PROGRAMMES.has(cle) and adopte(v, cle, t):
			n += int(PROGRAMMES[cle]["points"])
	return n

# 🗳️ LES RÈGLES (98, auteur 2026-10-28) : ni argent ni confiance dépensés, un SEUIL de confiance
# pour les signer. Signée, une règle tient même si la confiance retombe (🔴 à juger) ; pas de retrait (Q. 25).
# 🎚️ Level design : un seuil par règle — celui de la suivante plus haut que celui-ci (98).
# 🔴 Textes flaggables (90).
const REGLES := {
	"stationnement_payant": {
		"nom": "Stationnement payant",
		"quoi": "Faire payer les places dans les rues. Rapporte chaque mois, selon les places qui restent.",
		"seuil": 60.0,
	},
}
const REGLES_ORDRE := ["stationnement_payant"]
# 🎚️ ≈ 60 €/place/an net, toutes rues confondues : 3 430 places → ≈ 17 k€/mois, ≈ 200 k€/an,
# l'ordre d'une petite ville allemande (6b : l'argent ne triche pas). Retirer des places en retire.
const STATIONNEMENT_KE_PLACE_MOIS := 0.005


static func signee(v, cle: String, t: float) -> bool:
	return v._regles.has(cle) and t >= float(v._regles[cle])


## Une politique est en vigueur si sa dernière période est encore ouverte.
static func active(v, cle: String) -> bool:
	var p: Array = v._politiques.get(cle, [])
	return not p.is_empty() and float(p[-1][1]) < 0.0


static func facteur(v, effet: String, _t: float) -> float:
	var f := 1.0
	for cle in ORDRE:
		if POLITIQUES[cle]["effet"] == effet and active(v, cle):
			f *= float(POLITIQUES[cle]["valeur"])
	return f


## Combien de mois elle a tenu jusqu'à `t`, périodes cumulées.
static func mois_actifs(v, cle: String, t: float) -> float:
	var total := 0.0
	for p in v._politiques.get(cle, []):
		var fin: float = t if float(p[1]) < 0.0 else minf(float(p[1]), t)
		total += maxf(fin - float(p[0]), 0.0)
	return total


## En k€ depuis le mois 0. 🔴 Ce qui a été versé reste versé : couper une
## subvention arrête la dépense, il ne la rembourse pas.
static func depense_ke(v, t: float) -> float:
	var ke := 0.0
	for cle in v._politiques:
		ke += mois_actifs(v, cle, t) * float(POLITIQUES[cle]["ke_mois"])
	return ke
