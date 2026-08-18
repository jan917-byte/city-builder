# Le prototype — ce qu'on construit, étape par étape

> **Ce dossier est le chantier. Le vault est la tête.**
> Une idée, un arbitrage, une règle du jeu → `Vault - Jeu urbanisme/`.
> Ce qu'on est en train de construire, ses chiffres, ce qui reste → **ici**.
>
> Ce dossier **n'est pas dans le vault** : pas de frontmatter, pas de wikilinks. Les liens y sont des liens markdown ordinaires, et les renvois au vault se font par le nom de la note en `code`.

---

## La règle

> **Une seule étape est ouverte à la fois.**

Le prototype avance pas à pas. Une étape se termine quand **son critère de réussite est vu à l'écran**, pas quand le code compile. Tant qu'une étape est ouverte, les autres ne se travaillent pas — elles attendent leur ligne dans le tableau ci-dessous.

Ce que ça protège : le risque nommé dans `Décisions arrêtées` **52** — *que la 3D mange le calendrier*. Deux étapes ouvertes en même temps, c'est le retour de ce risque par la porte de derrière.

## Les étapes, dans l'ordre

| | L'étape | État | Son critère de réussite |
|---|---|---|---|
| 1 | **La carte** — îlots, rues, attributs | ✅ fait | la ville privée de sa rivière tombe en deux morceaux, le réseau routier tient d'un seul tenant, l'axe de transit sort tout seul |
| 2 | **[Les parcelles](Parcelles.md)** | ⏸️ **en pause** | la surface de toit mesurée retombe sur le coefficient de l'énergie · le cœur ancien ressemble à un cœur ancien |
| 3 | **[L'énergie](Énergie.md)** — une décision, deux échelles | ✅ simplifié, **à regarder** | cliquer un îlot, le passer de 0 à 100 % solaire, voir ses toits et les quatre totaux de ville changer |
| 4 | **[Les toits et le sol](Toits%20et%20sol.md)** | 🎯 **en cours** | croire qu'on y habite |
| 5 | **Le trafic visible** | ☐ | une rue à `charge = 1,00` est désagréable à regarder |
| 6 | **Le thème suivant** | ☐ | il s'écrit en trois pièces, sans toucher à la machinerie |

**Pourquoi l'étape 2 passe en pause au lieu de passer à ✅**, le 2026-08-18 :
son critère n'est pas atteint. Il lui reste **118 parcelles de rue avec un
sommet rentrant**, dont le dard de l'îlot 40 que l'auteur a entouré. Ce n'est
pas fini, c'est **suspendu** — et ce qui reste est décrit dans
[CHANTIERS.md](../CHANTIERS.md) §1 n°8, avec la piste à essayer.

🔴 **La règle « une seule étape ouverte » tient donc toujours**, et c'est
important : ouvrir la 4 sans fermer la 2 aurait été exactement le retour du
risque **52** par la porte de derrière. L'auteur a ouvert la 4 explicitement,
et la 2 s'est refermée en même temps.

**Pourquoi 3 apparaît quand même** : l'énergie est construite mais attend le
regard de l'auteur ; elle ne porte plus de chantier de système.
→ `Décisions arrêtées` **68**

## Ce qui relie les deux étapes ouvertes : **le toit**

L'énergie estime aujourd'hui la surface de toit par un coefficient. Les parcelles la produisent pour de vrai. Donc :

- la **3D alimente** l'énergie — le toit cesse d'être estimé ;
- l'**énergie donne aux parcelles leur critère de réussite** — un potentiel solaire calculé sur les vrais toits.

🔴 **Le sens ne se renverse jamais : l'énergie n'attend jamais la 3D.** Le prototype reste jouable avec les toits estimés quoi qu'il arrive au générateur.

## Où va quoi

| Ce que j'écris | Où ça va |
|---|---|
| une idée, un arbitrage, une règle du jeu, une référence | le **vault** — c'est la source de vérité |
| ce qu'une étape fait, ses chiffres mesurés, ce qui lui reste | **ici**, une note par étape |
| où on en est aujourd'hui, la prochaine commande à lancer | [`ETAT.md`](../ETAT.md) |
| ce qui attend, les défauts connus, la dette | [`CHANTIERS.md`](../CHANTIERS.md) |
| ce qui s'est passé, session par session | [`HISTORIQUE.md`](../HISTORIQUE.md) |

🔴 **La frontière avec le vault, pour qu'aucune des deux ne mente.** Le vault porte **la doctrine** : *pourquoi* la parcelle est une partition, ce qu'on ne fera jamais, ce qui est tranché. Ce dossier porte **le chantier** : où en est l'algo aujourd'hui, avec quels chiffres. Quand les deux disent la même chose, c'est ici qu'on efface — le vault est la source.

Une étape ne consigne **rien** dans `Décisions arrêtées` toute seule. Un arbitrage se ferme dans `Questions ouvertes.md` **et** se consigne dans `Décisions arrêtées.md`, jamais au détour d'une note de chantier.

## La contrainte de machine

Le travail se fait principalement sous **Windows**, parfois sur le Mac.

> 🔄 **L'ancienne règle a disparu, elle n'a pas été assouplie.** Elle disait : *« Le script voyage entre les deux machines. La carte, non — `QGIS/data/*.gpkg` ne s'écrit que sous Windows. »* Sa seule raison d'être était que la carte était un **binaire suivi par git**, que git ne sait pas fusionner.

Les deux machines font le même travail depuis le 2026-08-17 : la carte est du texte, aucun `.gpkg` n'est suivi. La passe `--blanc` reste obligatoire pour les trois scripts qui écrivent la source — c'est du level design. → `CLAUDE.md` §5

---

**Voir aussi** : [ETAT.md](../ETAT.md) · [CHANTIERS.md](../CHANTIERS.md) · `Vault - Jeu urbanisme/00 - Index.md`
