---
tags: [système, moc, vue-d-ensemble]
statut: vivant
maj: 2026-08-12
cssclasses:
  - large
---

# Carte des systèmes

> **Une seule page pour tenir l'ensemble en tête.** Trois schémas : la machine, les sept, les tensions.
> Ce n'est pas une source de vérité — chaque boîte renvoie à la note qui la tranche. Si un schéma contredit une note, **c'est la note qui a raison**.

---

## 1. La machine

Ce que fait le joueur, ce que ça coûte, ce que ça déplace, et par où ça revient.

```mermaid
flowchart TB

  subgraph BOUCLE["🔁 LA BOUCLE · tick mensuel"]
    direction TB
    DIAG["🔍 DIAGNOSTIC<br/>lire les calques"]
    DEC["🗂️ DÉCISION<br/>une intention, un lieu"]
    GHOST["👻 GHOST PREVIEW<br/>immédiat"]
    CHANT["🚧 CHANTIER<br/>délai · montée · maturité"]
    EFFET["🌱 EFFET<br/>+ effet de bord"]
    DIAG --> DEC --> GHOST --> CHANT --> EFFET
    EFFET -.->|"ouvre / ferme"| DIAG
  end

  VILLE["🏙️ L'ÉTAT DE LA VILLE<br/>69 îlots · 178 tronçons"]
  EFFET ==> VILLE

  subgraph RESS["💰 RESSOURCES · compteurs"]
    direction TB
    ARGENT["💶 ARGENT<br/>avoir · engagé · libre"]
    CAPITAL["🗳️ CAPITAL POLITIQUE<br/>un chiffre"]
    ARGENT <-.-> CAPITAL
  end

  ECO["📉 ÉCONOMIE<br/>barre sans nombre"]
  ECO -->|"× subi"| ARGENT
  VILLE -->|"recettes · charges"| ARGENT
  ARGENT -->|"étalé"| DEC
  CAPITAL -->|"comptant"| DEC
  EFFET -->|"ça s'est vu"| CAPITAL

  IND["📊 LES SEPT<br/>écart à t0"]
  MIL["🎯 MILESTONES"]
  VILLE ==> IND
  IND -->|"un chiffre, un calque"| DIAG
  IND -.->|"la borne a un nom"| MIL

  CRISE["💥 HAPPENING<br/>peu, lourds, espacés"]
  VILLE --> CRISE
  CRISE -->|"argent brûlé"| ARGENT
  CRISE -->|"refuser coûte"| CAPITAL
  CRISE -->|"fenêtre politique"| DEC
  CRISE -->|"déclin par quartier"| VILLE

  classDef boucle fill:#e6eefc,stroke:#3f6db5,color:#12213a;
  classDef res fill:#fdf0dc,stroke:#c98a2e,color:#3a2a10;
  classDef ind fill:#e4f3e9,stroke:#3f8f5f,color:#12301f;
  classDef ville fill:#f0e9f8,stroke:#8258ad,color:#241436;
  classDef crise fill:#fbe4e4,stroke:#b5504d,color:#3a1414;
  class DIAG,DEC,GHOST,CHANT,EFFET boucle;
  class ARGENT,CAPITAL,ECO res;
  class IND,MIL ind;
  class VILLE ville;
  class CRISE crise;
```

### Ce que disent les flèches courtes

| La flèche | Ce qu'elle veut dire |
|---|---|
| 💶 **étalé** vs 🗳️ **comptant** | l'argent se paie sur la durée du chantier, le capital au mois de la décision. C'est cette asymétrie qui permet de s'engager sur ce qu'on ne peut pas encore payer |
| **recettes · charges** | recettes ∝ `logements`, charges ∝ mètres de voirie — la raison structurelle de préférer la ville compacte à l'étalement |
| **× subi** | l'économie multiplie le budget, et le joueur ne la maîtrise pas. Formule cachée, jamais de difficulté adaptative. Quand la barre bouge, une phrase le dit |
| **ça s'est vu** | le capital ne s'achète pas : il se reconstitue sur un résultat **visible**. D'où le séquencement — impossible d'enchaîner trois mesures dures |
| **argent brûlé** | l'urgence achète du soulagement et zéro transformation. Refuser coûte du capital. Les deux ressources s'échangent au pire moment |
| **fenêtre politique** | la crise non évitée rend acceptable ce qui ne l'était pas. C'est comme ça que la planification marche vraiment |
| **déclin par quartier** | pas de game over. Des spirales lentes et visibles, rattrapables à très grand coût |
| **un chiffre, un calque** | c'est ce qui referme la boucle : un indicateur n'est pas une jauge, c'est la porte d'entrée d'une carte |

**Et le pivot** : rien ne se mesure sur le joueur. Recettes, indicateurs, crises — tout se lit sur **l'état de la ville**, les mêmes 69 îlots.

→ [[Boucle de jeu]] · [[Ressources]] · [[Happenings]] · [[Chantiers et temps]] · [[Déclin et défaite]]

---

## 2. Les sept — un chiffre, un calque, un jalon

La règle qui commande tout : **aucun chiffre global sans son calque.** Le chiffre dit *que* ça bouge, le calque dit *où*. Un indicateur dont on ne saurait pas dessiner la carte ne doit pas exister.

```mermaid
flowchart LR

  subgraph CH["LE CHIFFRE"]
    direction TB
    C1["🌡️ Surchauffe"]
    C2["💧 Ville exposée"]
    C3["🚗 Emprise voiture"]
    C4["🏠 Habitants d'origine"]
    C5["🏭 CO2"]
    C6["☀️ Toits qui produisent"]
    C7["🚋 Ce qui est desservi"]
  end

  subgraph CA["SON CALQUE"]
    direction TB
    L1["îlot de chaleur"]
    L2["aléa + fil de l'eau"]
    L3["stationnement + charge"]
    L4["riverain"]
    L5["trafic + chauffage"]
    L6["potentiel solaire"]
    L7["desserte TC"]
  end

  subgraph JA["SON JALON"]
    direction TB
    J1["❓ plus chaude<br/>que ses champs"]
    J2["ville-éponge"]
    J3["zéro voiture"]
    J4["personne<br/>n'a été chassé"]
    J5["zéro carbone"]
    J6["autonome<br/>en énergie"]
    J7["❓ tous à 300 m<br/>d'un arrêt"]
  end

  C1 --> L1 --> J1
  C2 --> L2 --> J2
  C3 --> L3 --> J3
  C4 --> L4 --> J4
  C5 --> L5 --> J5
  C6 --> L6 --> J6
  C7 --> L7 --> J7

  classDef ch fill:#e4f3e9,stroke:#3f8f5f,color:#12301f;
  classDef ca fill:#e6eefc,stroke:#3f6db5,color:#12213a;
  classDef ja fill:#fdf0dc,stroke:#c98a2e,color:#3a2a10;
  classDef ouvert fill:#f4f4f4,stroke:#8a8a8a,color:#2a2a2a,stroke-dasharray: 4 3;
  class C1,C2,C3,C4,C5,C6,C7 ch;
  class L1,L2,L3,L4,L5,L6,L7 ca;
  class J2,J3,J5,J6 ja;
  class J1,J4,J7 ouvert;
```

En pointillés gris : les trois jalons **non tranchés**. Les valeurs à t0 sont dans [[Indicateurs globaux]] — trois manquent encore.

**En contexte, pas en objectif** : la population, la densité, la date, et l'état de l'économie. On ne joue à faire monter aucun des quatre.

🏠 **« Habitants d'origine » part plein et ne peut que s'entamer.** Il ne se dessine pas comme les six autres : il se pose en travers, dessous, comme une ligne de prix. Tout ce qui se remplit en haut se paie là.

→ [[Indicateurs globaux]] · [[Diagnostic et calques]] · [[Milestones]]

---

## 3. Ce qui pousse contre quoi

> **Si deux indicateurs ne se poussent pas dessus, ce sont des décorations.**
> Les bornes sont la ceinture de sécurité. Le frein, ce sont ces flèches.

```mermaid
flowchart LR

  D1["Densifier"] -->|"loyers"| X1["🏠 habitants d'origine"]
  D1 --> X2["💧 imperméabilisé"]
  D1 -->|"plus de m² à chauffer"| X3["☀️ production / besoin"]
  D2["Planter en alignement"] --> X4["🚗 places de stationnement"]
  D3["Se protéger de la crue"] -->|"à ta place"| X5["🌊 l'aval"]
  D4["Aller vite"] --> X6["🗳️ capital politique"]
  D5["Faire produire les toits"] -->|"plat, plein sud"| X7["🏘️ la forme douce"]
  D6["Reconstruire performant"] --> X8["⚫ le carbone gris"]

  classDef monte fill:#e4f3e9,stroke:#3f8f5f,color:#12301f;
  classDef descend fill:#fbe4e4,stroke:#b5504d,color:#3a1414;
  class D1,D2,D3,D4,D5,D6 monte;
  class X1,X2,X3,X4,X5,X6,X7,X8 descend;
```

Deux garde-fous attachés à ce schéma :

- ⚫ **Le carbone gris rend « adapter » mécaniquement défendable face à « reconstruire »** — mais s'il pèse trop lourd, le jeu dit « ne touche à rien », ce qui contredit tout le projet. À calibrer devant les chiffres.
- 💶 **Densifier rapporte.** La contrepartie est dans la même formule (plus de logements = plus de réseau à entretenir), mais elle doit être calibrée : *une stratégie de densification pure ne doit pas s'autofinancer.*

→ [[Indicateurs globaux]] · [[Pièges connus]]

---

## Les trous de cette carte

Ce sont les endroits où le schéma dessine une flèche que le jeu ne sait pas encore montrer.

| Où | Ce qui manque |
|---|---|
| 🔴 `EFFET → CAPITAL` | **comment le capital se regagne n'a aucune forme à l'écran.** Un nombre nu ne dit pas *« ça revient parce que ça s'est vu »* — or c'est toute la mécanique de rythme → [[Ressources]] |
| ☐ `ECO → ARGENT` | la barre et le budget sont loin l'un de l'autre à l'écran : **rien ne dit au joueur que l'un commande l'autre** → [[Questions ouvertes]] n°21 |
| 🟠 le bandeau | **onze nombres permanents** (7 + capital + 3 de budget), pour un seuil défendu à six. À trancher devant une maquette → [[Direction artistique]] |
| ☐ la boucle | **le temps et les chantiers en cours n'ont pas de place dans le bandeau**, alors que c'est l'anti-spectateur → [[Chantiers et temps]] |
| ⚠️ hors carte | **[[Fins et pluralisme]]** n'apparaît pas ici, et c'est le symptôme : les trois archétypes tiennent encore sur un seul axe. Le deuxième axe manque |

**Voir aussi** : [[Boucle de jeu]] · [[Ressources]] · [[Indicateurs globaux]] · [[Décisions]] · [[Milestones]] · [[Happenings]] · [[Diagnostic et calques]]
