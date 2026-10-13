---
tags: [système, moc, vue-d-ensemble]
statut: vivant
maj: 2026-10-12
cssclasses:
  - large
---

# Carte des systèmes

> **Une seule page pour tenir l'ensemble en tête.** Trois schémas : la machine, les thèmes, les tensions.
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
    CAPITAL["🗳️ CONFIANCE<br/>un chiffre"]
    ARGENT <-.-> CAPITAL
  end

  ECO["📉 ÉCONOMIE<br/>barre sans nombre"]
  ECO -->|"× subi"| ARGENT
  VILLE -->|"recettes · charges"| ARGENT
  ARGENT -->|"étalé"| DEC
  CAPITAL -->|"comptant"| DEC
  EFFET -->|"ça s'est vu"| CAPITAL

  IND["📊 CO₂ + SIX THÈMES<br/>vers leur jalon"]
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

## 2. Le CO₂ et six thèmes — un chiffre, un calque, un jalon

La règle qui commande tout : **aucun chiffre global sans son calque** (53). Le chiffre dit *que* ça bouge, le calque dit *où*. Depuis 91, les indicateurs se rangent sous **six thèmes**, coiffés par le CO₂ ; chaque barre va de l'état de départ à son jalon.

```mermaid
flowchart LR

  CO2["🏭 CO₂"] --> JCO2["zéro carbone"]

  subgraph TH["LE THÈME"]
    direction TB
    T1["⚡ Énergie"]
    T2["🚗 Mobilité"]
    T3["🌾 Agriculture"]
    T4["🦋 Biodiversité"]
    T5["🌊 Dangers naturels"]
    T6["🏠 Habitants"]
  end

  subgraph JA["SON JALON"]
    direction TB
    J1["autonome<br/>en énergie"]
    J2["zéro voiture"]
    J3["autonome<br/>en nourriture"]
    J4["❓ à nommer"]
    J5["ville-éponge"]
    J6["personne<br/>n'a été chassé"]
  end

  T1 --> J1
  T2 --> J2
  T3 --> J3
  T4 --> J4
  T5 --> J5
  T6 --> J6

  classDef th fill:#e4f3e9,stroke:#3f8f5f,color:#12301f;
  classDef ja fill:#fdf0dc,stroke:#c98a2e,color:#3a2a10;
  classDef ouvert fill:#f4f4f4,stroke:#8a8a8a,color:#2a2a2a,stroke-dasharray: 4 3;
  class CO2,T1,T2,T3,T4,T5,T6 th;
  class JCO2,J1,J2,J3,J5,J6 ja;
  class J4 ouvert;
```

En pointillés gris : le jalon **non tranché**. Ce que chaque thème range dessous est dans [[Indicateurs globaux]].

**En contexte, pas en objectif** : la population, la date, la température et la saison. On ne joue à faire monter aucun des quatre.

🏠 **« Habitants d'origine » part plein et ne peut que s'entamer.** Tout ce qui se remplit ailleurs se paie là.

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
| 🟢 `EFFET → CAPITAL` | la confiance se regagne à la livraison, et le journal dit pourquoi (96) |
| ☐ `ECO → ARGENT` | la barre et le budget sont loin l'un de l'autre à l'écran : **rien ne dit au joueur que l'un commande l'autre** → [[Questions ouvertes]] n°21 |
| 🟠 le bandeau | les thèmes sont tranchés (91) ; **les nombres du budget et la confiance** restent à placer → [[Questions ouvertes]] n°19 |
| ☐ la boucle | **le temps et les chantiers en cours n'ont pas de place dans le bandeau**, alors que c'est l'anti-spectateur → [[Chantiers et temps]] |
| ⚠️ hors carte | **[[Fins et pluralisme]]** n'apparaît pas ici, et c'est le symptôme : les trois archétypes tiennent encore sur un seul axe. Le deuxième axe manque |

**Voir aussi** : [[Boucle de jeu]] · [[Ressources]] · [[Indicateurs globaux]] · [[Décisions]] · [[Milestones]] · [[Happenings]] · [[Diagnostic et calques]]
