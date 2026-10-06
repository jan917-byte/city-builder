extends RefCounted
## 📖 Le livre des concepts (101) : une page s'ouvre quand la ville rencontre le
## concept, et ouvre ses leviers. Rangé à la bibliothèque de l'université (A).
## 🔴 Textes provisoires, flaggables (90) : l'auteur les réécrit.

## `voir` : le thème qu'ouvre « Voir à Wehrau » ; `lieux` : ce qu'il cadre.
const CONCEPTS := {
	"eponge": {"titre": "La ville-éponge", "chapitre": "Tenir",
		"texte": "Une ville en dur renvoie toute la pluie vers la rivière, et vite : c'est ce qui fait monter la crue. "
			+ "Une ville-éponge garde l'eau là où elle tombe — dans la terre, sur les toits, dans les prés — "
			+ "et laisse de la place à la rivière quand elle déborde. Chaque mètre carré qui boit retire un peu d'eau à la prochaine crue.",
		"leviers": ["permeable", "vert", "berge", "pre"],
		"voir": "sols", "lieux": [["i", 19], ["b", 3], ["i", 31]]},
	"attenuer": {"titre": "Ne pas aggraver", "chapitre": "Ne pas aggraver",
		"texte": "S'adapter change ce que la crue emporte ; réduire ce que la ville émet change la violence des prochaines. "
			+ "Une petite ville ne refroidit pas le climat seule, mais elle peut cesser d'y ajouter : produire son énergie, "
			+ "moins dépendre de la voiture.",
		"leviers": ["solaire", "rue"],
		"voir": "energie", "lieux": [["i", 32]]},
	"chaleur": {"titre": "L'îlot de chaleur", "chapitre": "Plus tard",
		"texte": "", "leviers": ["arbres"], "voir": "", "lieux": []},
}
const ORDRE := ["eponge", "attenuer", "chaleur"]

const LEVIERS := {
	"permeable": "Rendre un parking perméable",
	"vert": "Verdir les toits plats",
	"berge": "Rendre une berge à l'Ilse",
	"pre": "Laisser un pré déborder",
	"solaire": "Poser des panneaux solaires",
	"rue": "Fermer une rue, retirer des places",
	"arbres": "Planter des arbres",
}


static func concept_du_levier(levier: String) -> String:
	for id in ORDRE:
		if levier in CONCEPTS[id]["leviers"]:
			return id
	return ""
