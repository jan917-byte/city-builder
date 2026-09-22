---
tags: [système, gameplay, proposition]
statut: proposition, à arbitrer par l'auteur
maj: 2026-09-18
---

# Relogement progressif - proposition

Analyse du retour de jeu du 18 septembre. Le retrait des données générales et le réglage à deux personnes par container sont appliqués. Le compteur permanent est appliqué par la décision 85 ; le montage progressif et le verrou à zéro restent proposés.

## Ce que montre le prototype actuel

Le trafic interdit les chaussées envasées et les ponts détruits, mais conserve des voitures sur les rues praticables de la rive isolée. Un quota visuel minimum peut afficher des voitures même avec une charge nulle : corriger uniquement le calcul des trajets ne suffirait pas.

Les camps sont entièrement invisibles jusqu'à leur livraison, puis tous leurs containers apparaissent ensemble. Le guide propose le trafic dès qu'un premier camp est livré, même vide. Le nombre de personnes dehors existe déjà dans une petite ligne mêlée à la caisse ; il disparaît avec le guide.

## La boucle recommandée

| Moment | Ce que le joueur voit |
|---|---|
| Départ | **Personnes sans logement : 260**, caisse et temps. La rive isolée ne porte aucune voiture en mouvement. |
| Champ sélectionné | Capacité, coût, perte agricole, accessibilité et résultat prévu en personnes ; les logements sont indiqués séparément. |
| Décision engagée | Le terrain devient un chantier ; le nombre de places en préparation est distinct du nombre de personnes relogées. |
| Montage | Les containers apparaissent par petits groupes dans l'ordre des rangées ; chaque groupe livré fait baisser le compteur. |
| Dernière personne abritée | « Tout le monde est à l'abri ». Bref temps pour regarder la transformation, puis invitation à découvrir le trafic. |
| Premier pont livré | La liaison réellement praticable retrouve ses voitures ; la suite de la transformation urbaine s'ouvre. |

Le compteur reste visible en bas à droite (décision 85) même lorsque le guide est réduit ou qu'une fiche est ouverte. Une seconde ligne indique la part de personnes relogées et, seulement pendant un chantier, les places en préparation. Aucun décompte rouge clignotant : il s'agit de comprendre l'urgence, pas de punir l'observation. Les informations générales reviennent après la découverte du premier pont ; le coût agricole reste dans la fiche du champ concerné.

## Construction et comptage

Conserver comme premier essai les **12 secondes à ×1** du chantier actuel (0,2 mois). Révéler des groupes successifs pendant cette durée, avec un bref éclaircissement des modules livrés et une seule indication de gain par groupe. L'accélération et la pause suivent le temps du jeu ; à ×12, plusieurs groupes peuvent arriver ensemble. La reprise conserve l'avancement. Aucun délai purement décoratif ne retarde l'occupation ou le passage au pont.

La même quantité entière de logements livrés pilote les containers visibles et leur capacité. **Retour de l'auteur : plusieurs personnes par container ; le réglage appliqué est de deux places par logement temporaire**, avec un dernier logement partiellement occupé si nécessaire. Cela remplace la proposition initiale d'une personne par logement. Le besoin initial reste une simplification du prototype calculée à partir des logements sinistrés ; ce n'est pas une règle démographique pour toute la ville.

Personnes sans logement = besoin restant après les retours en logement réparé, moins places temporaires livrées et accessibles, avec un minimum de zéro. Les logements simplement commandés ne relogent encore personne.

Dimensionner une nouvelle commande selon le besoin **moins les places accessibles déjà en préparation**, afin que deux camps lancés ensemble ne réservent pas les mêmes personnes. Ne payer que les containers commandés. S'il manque des places, garder le compteur et annoncer le manque ; si les travaux en cours suffisent, dire « Les logements nécessaires sont en construction ». Un surplus existant reste vacant et visible, sans créer d'habitants et sans compteur négatif.

## Le verrou et ses pièges

Débloquer la reconstruction lorsque le **nombre réel de personnes sans logement atteint zéro**, après livraison et accès vérifié. Garder cet acquis dans la progression. Le verrou doit couvrir le guide et toute commande directe de pont, et tenir après sauvegarde/reprise. Ne pas se baser sur un texte arrondi à zéro, une promesse ou la fermeture du panneau.

**Capacité résolue, décision 84 :** n'importe quels deux champs accessibles suffisent désormais, aucun champ seul. Le dernier camp s'ajuste automatiquement au manque : aucun calcul exact n'est demandé au joueur. Le dessin des champs, les modules et leurs espacements sont conservés ; capacités mesurées dans `Prototype/Premiers pas.md`.

**Le camp de l'autre rive est le piège majeur.** Il est aujourd'hui autorisé, payé et vide jusqu'au pont. Avec le nouveau verrou, il ne doit pas pouvoir être proposé comme solution immédiate. Recommandation : pendant cette introduction, garder sa fiche consultable mais désactiver l'engagement avec « Inaccessible tant qu'aucun pont n'est rétabli ». Cela revient sur le choix précédent qui autorisait cette erreur ; cette modification reste à arbitrer. Les anciennes parties qui ont déjà payé ces camps doivent conserver une voie de sortie, par exemple une annulation remboursée de ces commandes pendant l'introduction.

**Le prix du pont peut briser le rythme.** Le partage des containers diminue la dépense de relogement, mais laisse environ 30 mois d'épargne, puis 18 mois de travaux pour le premier pont : environ quatre minutes à ×12, hors temps déjà écoulé. Recommandation : calibrer une enveloppe dédiée au premier franchissement pour permettre son engagement après le relogement, avec montant et durée à arbitrer. Aucun prix unitaire n'a été modifié.

## Cohérence du trafic

Utiliser la connexion routière effective de la rive pour supprimer ensemble circulation visible et charge affichée ; conserver les voitures garées et les déplacements piétons locaux possibles. Une route déblayée ne rétablit pas à elle seule la liaison. À la livraison du **premier pont qui reconnecte effectivement la rive**, seuls les itinéraires praticables reprennent. Attendre la reconstruction des trois ponts rendrait la première réparation sans effet visible. Le diagnostic doit nommer ce qui reste coupé, notamment les rues encore sous la boue.

Cette séquence conserve le rôle du joueur : il choisit un terrain et engage une transformation, observe les logements s'installer, puis lit le résultat. Le zéro est une réussite observable ; l'ajustement automatique de la dernière commande lui évite de devenir une énigme arithmétique.

**Voir aussi** : [[Premiers pas après la crue]] · [[Chantiers et temps]] · [[Boucle de jeu]]
