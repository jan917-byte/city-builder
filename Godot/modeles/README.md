# modeles/ — les modèles 3D que le jeu lit tels quels

`arbres/` : les packs craftpix « Free Tree 3D Low Poly » (`Tree_temp_climate_*`) et « Free Bush 3D Low Poly » (`Bush_temp_climate_*`), au complet, pour pouvoir changer de modèle sans retourner au pack.

**Ce qui s'en sert** : `Constructeur.arbre` (`Godot/scripts/constructeur.gd`), table `MODELES` (une essence → un fichier). Le jeu ne garde que la **forme** : la couleur, les saisons et l'écorce sont les nôtres. La texture du pack (verte en haut, brune en bas) sert seulement à séparer la couronne du bois. Chaque modèle est étiré à la hauteur et à la largeur de l'arbre qu'il remplace (`HAUTEUR`, `LARGEUR`).

**Changer un arbre** : choisir un numéro sur la planche (`blender -b --factory-startup -P Godot/outils/planche_modeles_blender.py -- Godot/modeles/arbres Tree QGIS/rendus/wehrau_pack_arbres_numeros.png`, `Bush` pour les buissons), le mettre dans `MODELES`, puis regarder la pépinière : `Godot_console.exe --path Godot --position 6000,6000 --script res://outils/apercu_arbres.gd -- --mois=6.5`.

**Pièges**
- Les FBX sont lus au lancement par `FBXDocument`, **sans passer par l'import de l'éditeur** : chaque `.fbx.import` dit `importer="keep"` (le fichier part tel quel dans l'export). Un nouveau modèle demande le même fichier `.import`.
- Si un modèle manque ou ne se lit pas, l'arbre retombe sur l'ancienne recette dessinée par le code, avec un avertissement dans la console.
- 🔴 **Licence craftpix (gratuits)** : usage commercial permis, crédit non exigé, mais **interdit de redistribuer les fichiers**, même modifiés. Le dépôt doit rester privé tant que ce dossier y est.
