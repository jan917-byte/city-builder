# Brainstorming — Scénario d'amorce : inondation de la rive droite

**Projet :** city-builder solarpunk (Brightvale)
**Date :** lundi 10 août 2026, 20h23 (CEST)
**Statut :** exploration design — périmètre prototype papier

---

## 1. Prémisse narrative

La ville est traversée par une rivière au régime de crues fréquentes. C'est le thème
identitaire du lieu.

Le jeu s'ouvre sur **une inondation majeure de la rive droite** :

- les usines de la rive droite ne sont plus exploitables
- une partie du logement est sinistrée
- la voirie et les réseaux sont partiellement hors service

Le joueur n'arrive pas sur une page blanche : il arrive sur des ruines encore chaudes
et doit arbitrer. C'est ce qui justifie mécaniquement qu'il **décide** au lieu
d'aménager à la main.

### Condition de tension : la deuxième crue

Une seconde crue est **annoncée** (échéance et probabilité affichées).

Sans cette annonce, « ne pas reconstruire » est un choix sentimental.
Avec elle, c'est un calcul — et le joueur qui reconstruit tout se fait rattraper.
C'est le mécanisme qui donne du poids à l'ensemble des décisions.

---

## 2. Décision structurante : les trois postures

Chaque îlot sinistré reçoit **une posture**, avant toute décision fine.

| Posture | Description | Conséquence |
|---|---|---|
| **Reconstruire** | On remet du bâti à l'identique | Cher ; sera réinondé |
| **Adapter** | On garde, on surélève, rez-de-chaussée non habités | Coût moyen ; dégâts acceptés et limités |
| **Rendre à l'eau** | Pas de reconstruction : expansion de crue, prairie inondable, parc | Perte de surface bâtie ; protection en aval |

> **Hypothèse de design :** « Rendre à l'eau » est la décision signature du jeu —
> celle dont le joueur dira *« regarde ce que j'ai fait »*.
> Choisir de **ne pas** construire, et que ce soit valorisant, n'existe dans aucun
> city-builder. C'est visuellement lisible (un vide qui devient paysage) et la
> mémoire des parcelles doit rester perceptible sous le nouveau sol.

---

## 3. Décisions sur les rues (`rues`)

| Décision | Effet principal | Coût caché |
|---|---|---|
| Retirer la voiture | Report du trafic sur les rues voisines | Commerces, accès pompiers / livraison |
| Planter l'alignement | Ombre, canopée, rétention | Emprise ; incompatible sous une largeur seuil |
| Désimperméabiliser | Absorption du ruissellement | Coût au m², entretien |
| Supprimer le stationnement | Libère l'emprise pour les trois ci-dessus | Coût politique élevé |
| Surélever / digue légère | Protection locale | **Aggrave la situation en aval** |

La digue est le levier « fausse bonne solution » : le joueur protège un tronçon et
déplace le problème. À conserver absolument.

---

## 4. Décisions sur les îlots (`ilots`)

| Décision | Effet principal | Coût caché |
|---|---|---|
| Changer la mixité | Commerces, emplois de proximité | Dépend du flux piéton → dépend des rues |
| Rénovation thermique | Énergie, confort d'été | Cher ; déclenche des hausses de loyer |
| Densifier / surélever | Atteint les seuils de viabilité TC et commerce | Imperméabilise, gentrifie |
| Végétaliser le cœur d'îlot | Chaleur, rétention | Perte de stationnement / entrepôt |
| Reconvertir les friches industrielles | Le gros morceau de la rive droite | Dépollution, temps long |

---

## 5. Modèle de trafic minimal (prototype)

**Pas de feux, pas d'agents, pas de simulation d'itinéraires.**

Règle unique :

1. Chaque rue porte une **charge**.
2. Fermer une rue reporte sa charge sur les rues voisines.
3. Au-delà d'un **seuil**, la rue voisine se dégrade : bruit, valeur riverain, commerce.

Suffisant pour produire tout l'arbitrage intéressant, tient en quelques dizaines de
lignes, et se visualise en carte de chaleur sur la couche `rues`.

---

## 6. Les trois tensions à tester en priorité

1. **Arbres vs désimperméabilisation vs stationnement** — même emprise, trois usages.
2. **Densifier vs rendre à l'eau** — la densité paie le transport en commun, mais la
   rive droite est précisément là où il ne faut plus densifier.
3. **Rénover vs maintenir les habitants** — seule boucle de gentrification du prototype.

---

## 7. Principe de formulation des décisions

Une décision globale n'est pas un bouton, c'est **une doctrine avec un seuil**.

> Pas « je plante des arbres » mais « je plante sur toute rue de plus de X m ».

Le joueur règle X ; le ghost preview affiche instantanément le nombre de rues
concernées et le coût. Descendre le seuil de 15 m à 12 m fait exploser le budget.

Deux bénéfices : la décision devient un arbitrage, et l'effet est **spatialement
inégal par construction** (pilier de spécificité spatiale). Le cœur médiéval n'est
jamais concerné, et ça se voit.

---

## 8. Hors périmètre du prototype

Écartés pour l'instant — n'ajoutent aucune hésitation nouvelle :

- réseau de chaleur
- solaire en toiture
- ZFE
- tarification du stationnement
- feux et priorité TC
- procédures réglementaires (rejet de principe, hors sujet)

---

## 9. Prochaines étapes

- [ ] Construire le tableau `decisions` (surface / coût € / coût politique / effets
      chiffrés / conflits / prérequis)
- [ ] Attribuer une posture aux îlots sinistrés de la rive droite dans `ville.gpkg`
- [ ] Ajouter les attributs de crue aux couches (`hauteur_eau`, `sinistre`, `alea`)
- [ ] Prototype papier : vérifier que les trois tensions produisent bien de
      l'hésitation et du regret
