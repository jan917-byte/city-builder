extends RefCounted
# Le calendrier : le mois `t` du jeu (0 = début de partie) devient une date.
# Pas de vraie année, « an 1 » (auteur, 2026-10-09) : on ne compare pas au monde réel.
# La température n'a encore aucun effet (décision 92) ; le mois dit la saison (auteur, 2026-10-09).

## La crue tombe fin février, la partie commence en mars (auteur, 2026-10-09).
const MOIS_DEPART := 2
const NOMS := ["janvier", "février", "mars", "avril", "mai", "juin", "juillet",
	"août", "septembre", "octobre", "novembre", "décembre"]
## Normales mensuelles d'une vallée d'Europe centrale, °C — ordre de grandeur
## de Fribourg-en-Brisgau 1991-2020, pas une mesure de Wehrau.
const TEMPERATURES := [2.4, 3.5, 7.3, 11.0, 15.0, 18.6, 20.3, 19.9, 15.6, 11.0, 6.1, 3.1]


## 0 = janvier.
static func mois_de_l_annee(t: float) -> int:
	return (MOIS_DEPART + int(floor(t))) % 12


## L'an change en janvier, pas à l'anniversaire : l'an 1 n'a que dix mois, et le
## budget voté en janvier est celui de l'an qui commence.
static func an(t: float) -> int:
	return 1 + int(floor((MOIS_DEPART + floor(t)) / 12.0))


## « mars, an 1 » ; « Mars, an 1 » en tête de ligne (`capitalize` mettrait « An »).
static func date(t: float, tete := false) -> String:
	var nom: String = NOMS[mois_de_l_annee(t)]
	return "%s, an %d" % [nom.left(1).to_upper() + nom.substr(1) if tete else nom, an(t)]


## Dans une phrase : « en mars de l'an 1 », sans point médian (auteur, 2026-10-09).
static func en(t: float) -> String:
	return "en %s de l'an %d" % [NOMS[mois_de_l_annee(t)], an(t)]


## Interpolée d'un milieu de mois au suivant, pour qu'elle ne saute pas le 1ᵉʳ.
static func temperature(t: float) -> float:
	var x := MOIS_DEPART + t - 0.5
	var m := int(floor(x))
	return lerpf(TEMPERATURES[posmod(m, 12)], TEMPERATURES[posmod(m + 1, 12)], x - m)
