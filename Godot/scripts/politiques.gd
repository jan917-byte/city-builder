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
		"ke_mois": 6.0,
		"effet": "cout_panneau_x", "valeur": 0.80,
	},
	"subv_vert": {
		"nom": "Prime au toit vert",
		"quoi": "−25 % sur le prix d'un toit vert, tant qu'elle tient",
		"ke_mois": 4.0,
		"effet": "cout_vert_x", "valeur": 0.75,
	},
}
const ORDRE := ["subv_solaire", "subv_vert"]

# 🔴 LES RÈGLES ATTENDENT LE CAPITAL POLITIQUE. Stationnement payant, toit vert
# obligatoire au neuf : elles ne coûtent pas d'argent mais du capital, qui vit
# encore dans le classeur et pas dans la maquette. La fiche le dit à l'écran
# plutôt que de faire semblant.


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
