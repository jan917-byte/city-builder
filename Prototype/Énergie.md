# Le prototype énergie — une décision, deux échelles

> 🔄 **Simplifié par l’auteur le 2026-08-17.** Le prototype ne teste plus
> l’économie ni une paire de décisions opposées. Il teste d’abord le geste le
> plus court : cliquer un îlot, augmenter sa part de panneaux solaires, voir
> l’îlot et la ville réagir.
>
> Plan de chantier vivant, pas source de vérité du design. La décision est
> consignée dans `Décisions arrêtées` **68**.

## 1. La boucle actuelle

1. Le joueur voit les informations de **toute la ville à gauche**.
2. Il clique un îlot.
3. La fiche de **cet îlot seulement** apparaît à droite. Le survol et les rues
   ne remplacent jamais cette fiche.
4. Il choisit une part solaire entre la valeur actuelle et **100 %**.
5. La décision est immédiate : les toits s’assombrissent, la production monte,
   l’achat et le CO₂ baissent à l’échelle de l’îlot et de la ville.

La part ne peut que monter. La redescendre serait une autre décision — déposer
des panneaux — qui n’appartient pas à ce test.

## 2. Ce qui est affiché

| Gauche — toute la ville | Droite — îlot cliqué |
|---|---|
| consommation en GWh/an | tissu |
| production solaire en GWh/an | logements |
| énergie achetée en GWh/an | consommation en MWh/an |
| CO₂ en kt/an | production en MWh/an |
| | toit équipable en m² |
| | part du toit équipée, curseur 0–100 % |

Il n’y a plus de bandeau transversal : les deux échelles occupent deux côtés
distincts de l’écran. La fiche ne suit plus le survol.

## 3. Ce qui est volontairement absent

- pas de budget ;
- pas de capital politique ;
- pas d’isolation ;
- pas de rentabilité ni de tarif de rachat ;
- pas de délai, de chantier ou de lecture du temps ;
- pas de calque thématique ;
- pas de ciblage de plusieurs îlots par seuil.

`chantiers.gd` et l’ancien essai imprimé restent dans le dépôt comme trace
technique, mais la boucle jouable ne les appelle plus. Ils ne décrivent donc
plus le prototype actuel.

## 4. Les nombres qui restent vrais

La simplification de l’interface ne change pas la physique déjà branchée :

- consommation de départ de Wehrau : **51,1 GWh/an** ;
- production initiale : **0** ;
- rendement solaire : **140 kWh/m²/an**, modulé par le tissu et l’ombrage ;
- potentiel calculé sur les **10,4 ha de toiture réelle**, pas sur une emprise
  estimée ;
- achat = consommation − production ;
- CO₂ = énergie achetée × facteur d’émission.

Le réglage de l’îlot 32, la barre de 1974, de 0 à 100 % produit le contrôle
actuel :

| | avant | après |
|---|---:|---:|
| production de la ville | 0,0 GWh/an | **0,3 GWh/an** |
| achat de la ville | 51,1 GWh/an | **50,9 GWh/an** |
| CO₂ de la ville | 12,8 kt/an | **12,7 kt/an** |
| part solaire de l’îlot 32 | 0 % | **100 %** |

## 5. Ce qui doit se voir

Le contrôle automatisé sélectionne l’îlot **32**, le passe de 0 à 100 % et
produit deux images :

- `QGIS/rendus/wehrau_essai_barre.png` — avant ;
- `QGIS/rendus/wehrau_essai_solaire_100.png` — après.

La preuve attendue :

1. le panneau gauche ne parle que de la ville ;
2. le panneau droit ne parle que de l’îlot 32 ;
3. le toit de la barre passe du clair à l’ardoise sombre ;
4. la production de ville passe de 0,0 à 0,3 GWh/an ;
5. le bouton se ferme sur « Toit entièrement équipé » ;
6. aucun budget ni capital n’apparaît.

Si le curseur revient tout seul à zéro pendant qu’on le déplace, c’est cassé.
Si une rue survolée remplace la fiche, c’est cassé. Si les chiffres bougent
sans que les toits changent, c’est cassé.

## 6. Les fichiers actifs

| Fichier | Ce qu’il porte |
|---|---|
| `Godot/scripts/interface.gd` | les deux panneaux et le curseur solaire |
| `Godot/scripts/ville.gd` | l’état de la part solaire, seulement croissante |
| `Godot/scripts/energie.gd` | les coefficients et les quatre conséquences |
| `Godot/scripts/maquette.gd` | le clic, le branchement et le rendu avant/après |
| `Godot/scripts/materiaux.gd` | les toits qui s’assombrissent selon la part équipée |

## 7. Ce que ce prototype répond — et ce qu’il ne répond pas

Il répond à une question d’interface et de lisibilité :

> **Est-ce que le joueur comprend qu’il transforme un îlot et que cette
> transformation remonte immédiatement à l’échelle de la ville ?**

Il ne répond plus, pour l’instant, à « où investir ? », « quand investir ? » ou
« les panneaux et l’isolation se contraignent-ils ? ». Ces questions restent
dans le vault ; les réintroduire demandera une décision de l’auteur, pas une
réactivation silencieuse de l’ancien code.

---

**Voir aussi** : [00 - Prototype.md](00%20-%20Prototype.md) · [Parcelles.md](Parcelles.md) · `Vault - Jeu urbanisme/Méta/Décisions arrêtées.md` · `Godot/README.md`
