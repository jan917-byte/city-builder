extends SceneTree
## Godot --path Godot --script res://outils/apercu_icones.gd
## ✏️ La planche des icônes : numéro, nom du fichier à poser dans `res://icones/`,
## ce qu'elle désigne, et son rendu (dessin de l'auteur s'il existe, trait sinon).
## Puis le rail, actif et au repos, agrandi ×3. → QGIS/rendus/wehrau_icones*.png

const Pastilles := preload("res://scripts/pastilles.gd")
# Ce que chaque icône désigne dans le jeu ; `*` = garder en trait (elle se transforme).
const QUOI := {
	"ville": "Vue Ville (rail)", "diagnostic": "Icône de secours",
	"adaptation": "Bilan : ville relevée", "reduction": "Bilan : émissions évitées",
	"conso": "Énergie consommée", "production": "Solaire produit", "achat": "Énergie achetée", "co2": "CO₂",
	"temperature": "* Température (se remplit)", "capital": "Confiance", "recherche": "Points de recherche",
	"caisse": "Caisse", "dangers": "Vue Dangers (rail)", "chantiers": "Vue Chantiers (rail)",
	"energie": "Vue Énergie (rail)", "nourriture": "Vue Campagne (rail)",
	"pont_casse": "Pastille : pont emporté", "pont": "Pont", "duree": "Durée",
	"annuler": "Annuler les réglages", "trafic": "Vue Trafic (rail)", "sols": "Vue Sols (rail)",
	"guide": "Guide, rouvre les premiers pas (rail)", "mairie": "Mairie (rail)", "institut": "Institut (rail)",
	"bibliotheque": "Bibliothèque (rail)", "universite": "Université (rail)",
	"logement": "Bâti, sans-logis", "feuille": "Vert, arbres", "eau": "Eau",
	"pause": "Pause", "lecture": "Lecture", "mois_zero": "Retour au mois 0",
	"sauver": "Sauvegarder", "ouvrir": "Reprendre la partie", "boussole": "* Nord (tourne)",
	"plan": "Caméra : plan", "cube": "Caméra : 3D", "croix": "Fermer", "camp": "Camp",
	"personnes": "Habitants",
}

var jeu


func _initialize() -> void:
	call_deferred("capturer")


func capturer() -> void:
	root.size = Vector2i(1600, 1000)
	jeu = load("res://maquette.tscn").instantiate()
	root.add_child(jeu)
	jeu.set_process(false)
	jeu.horloge_trafic.stop()
	jeu.moniteur_performances.hide()
	jeu._sur_vitesse(0.0)
	var ui = jeu.interface
	var dossier := ProjectSettings.globalize_path("res://../QGIS/rendus/")
	for etat in [["actif", ""], ["repos", str(jeu.THEMES[0]["id"])]]:
		ui._sur_rail(etat[1])
		(ui._menu_boutons[""] as Button).button_pressed = etat[1] == ""
		await _attendre()
		var rail := root.get_texture().get_image().get_region(Rect2i(0, 0, 100, 640))
		rail.resize(300, 1920, Image.INTERPOLATE_NEAREST)
		rail.save_png(dossier + "wehrau_icones_rail_%s.png" % etat[0])

	var fond := ColorRect.new()
	fond.color = Color("f3f1ec")
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(fond)
	var grille := GridContainer.new()
	grille.columns = 7
	grille.position = Vector2(16, 12)
	grille.add_theme_constant_override("h_separation", 6)
	grille.add_theme_constant_override("v_separation", 4)
	fond.add_child(grille)
	var noms: Array = ui.DESSINS.keys()
	for i in noms.size():
		var nom: String = noms[i]
		var dessinee: bool = ui.est_dessinee(nom)
		var case := VBoxContainer.new()
		case.custom_minimum_size = Vector2(218, 0)
		case.add_theme_constant_override("separation", 0)
		var ligne := HBoxContainer.new()
		for t in [[ui._icone(nom, 64, ui.TEXTE), 64], [ui._icone(nom, 26, ui.TEXTE), 26],
				[Pastilles.pictogramme(nom, ui.ALERTE, Color.WHITE), 40]]:
			var pic := TextureRect.new()
			pic.texture = t[0]
			pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			pic.custom_minimum_size = Vector2(t[1], 64)
			ligne.add_child(pic)
		case.add_child(ligne)
		case.add_child(_mot("%d · %s.svg%s" % [i + 1, nom, "  ✓" if dessinee else ""], 15,
			Color("2e7d32") if dessinee else ui.TEXTE))
		case.add_child(_mot(str(QUOI.get(nom, "")), 13, Color(ui.TEXTE, 0.6)))
		grille.add_child(case)
	await _attendre()
	root.get_texture().get_image().save_png(dossier + "wehrau_icones.png")
	print("planche → %swehrau_icones.png" % dossier)
	quit()


func _mot(texte: String, taille: int, coul: Color) -> Label:
	var l := Label.new()
	l.text = texte
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", coul)
	return l


func _attendre() -> void:
	for frame in 8:
		await process_frame
		await RenderingServer.frame_post_draw
