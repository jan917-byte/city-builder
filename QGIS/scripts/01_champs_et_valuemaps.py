# -*- coding: utf-8 -*-
"""
⚰️ VESTIGE — NE PLUS LANCER. Ce script se collait dans la console Python de
QGIS pour poser des listes déroulantes de saisie. QGIS est sorti du projet le
2026-08-17 : plus personne ne saisit à la main, et sa liste `SOUS_TYPES` a de
toute façon divergé de `02` (voir QGIS/README.md §8). Gardé pour mémoire, et
parce qu'il documente ce que la saisie manuelle demandait avant les scripts.

Ce que ça fait, et rien d'autre :
  1. ajoute les champs manquants sur `ilots` et sur la couche de lignes
  2. recopie `hierarchy` → `hierarchie` en minuscules (Boulevard → boulevard)
  3. calcule `surface_m2`
  4. pose les listes de valeurs (value maps) pour que la saisie se fasse
     au clavier en vue formulaire, pas en tapant du texte libre

Ce que ça ne fait pas : aucune géométrie n'est touchée, aucune entité créée
ou supprimée, `fonction` et `sous_type` restent VIDES — c'est ta saisie.

MODE D'EMPLOI
  1. copier Vallmar2.gpkg en Vallmar2_travail.gpkg
  2. ouvrir la copie dans QGIS (les deux couches)
  3. Extensions > Console Python, coller ce fichier, Entrée
  4. lire le compte rendu ; si SIMULATION = True, rien n'a été écrit

Repasser SIMULATION à False pour appliquer.
"""

from qgis.core import QgsProject, QgsField, QgsEditorWidgetSetup
from qgis.PyQt.QtCore import QVariant

SIMULATION = True          # ← True = on regarde, False = on écrit

NOM_ILOTS = "ilots"
NOM_RUES = "routes"        # nom actuel de la couche ; le vault dit `rues`

# --- taxonomie -------------------------------------------------------------
# `fonction` vient de Géométrie et données (décision 32), c'est arrêté.
FONCTIONS = ["freiraum", "habitation", "industrie", "mixte", "riviere"]

# `sous_type` : le vault dit « ~12 combinaisons maximum » sans les lister.
# ⚠️ CETTE LISTE EST UNE PROPOSITION, PAS UNE DÉCISION. Elle est tirée des
# accroches de level design déjà écrites dans Pipeline QGIS et du profil de
# l'Altstadt. À valider, amender, ou remplacer — puis à consigner dans le vault.
SOUS_TYPES = [
    "coeur_medieval",        # parcellaire fin, mitoyen, cour minérale
    "coeur_vert_prive",      # cœur d'îlot planté, invisible depuis la rue
    "front_commercant",      # rez-de-chaussée actifs, propriétaires organisés
    "place_minerale",        # la place entièrement en enrobé
    "faubourg",              # tissu plus lâche, hors du noyau
    "quai",                  # bande riveraine, longée par la voie rapide
    "equipement",            # école, halle, administration
    "parc",                  # freiraum planté
    "friche",                # en attente d'usage
    "riviere",               # le polygone d'eau lui-même
    "champ",                 # hors ville — l'extérieur de l'emprise
]

HIERARCHIES = ["autoroute", "boulevard", "rue", "ruelle", "rive", "voie ferree"]


# --------------------------------------------------------------------------

def couche(nom):
    r = QgsProject.instance().mapLayersByName(nom)
    if not r:
        raise RuntimeError(
            "couche « %s » introuvable dans le projet. Couches présentes : %s"
            % (nom, [c.name() for c in QgsProject.instance().mapLayers().values()]))
    return r[0]


def ajouter_champs(c, specs):
    """specs = [(nom, type, longueur, precision)] — n'ajoute que ce qui manque."""
    presents = [f.name() for f in c.fields()]
    a_creer = [s for s in specs if s[0] not in presents]
    if not a_creer:
        print("   champs : déjà tous présents")
        return []
    print("   champs à créer : %s" % [s[0] for s in a_creer])
    if SIMULATION:
        return [s[0] for s in a_creer]
    c.dataProvider().addAttributes(
        [QgsField(n, t, len=lg, prec=pr) for (n, t, lg, pr) in a_creer])
    c.updateFields()
    return [s[0] for s in a_creer]


def value_map(c, champ, valeurs):
    i = c.fields().indexOf(champ)
    if i < 0:
        print("   value map %s : champ absent, ignoré" % champ)
        return
    if SIMULATION:
        print("   value map %s : %d valeurs" % (champ, len(valeurs)))
        return
    c.setEditorWidgetSetup(i, QgsEditorWidgetSetup(
        "ValueMap", {"map": [{v: v} for v in valeurs]}))
    print("   value map %s : posée (%d valeurs)" % (champ, len(valeurs)))


def remplir(c, expressions):
    """expressions = {champ: expression QGIS}. N'écrit que si la cible est NULL."""
    from qgis.core import QgsExpression, QgsExpressionContext, \
        QgsExpressionContextUtils
    for champ, expr_txt in expressions.items():
        idx = c.fields().indexOf(champ)
        if idx < 0:
            print("   %s : champ absent, ignoré" % champ)
            continue
        expr = QgsExpression(expr_txt)
        ctx = QgsExpressionContext()
        ctx.appendScopes(QgsExpressionContextUtils.globalProjectLayerScopes(c))
        maj = {}
        for e in c.getFeatures():
            ctx.setFeature(e)
            v = expr.evaluate(ctx)
            if v is not None and e[champ] != v:
                maj[e.id()] = {idx: v}
        print("   %s ← %s   (%d entités)" % (champ, expr_txt, len(maj)))
        if maj and not SIMULATION:
            c.dataProvider().changeAttributeValues(maj)


print("=" * 66)
print("SIMULATION" if SIMULATION else "*** ÉCRITURE RÉELLE ***")
print("=" * 66)

ci = couche(NOM_ILOTS)
print("\n[ %s ]  %d entités" % (ci.name(), ci.featureCount()))
ajouter_champs(ci, [
    ("fonction",   QVariant.String, 20, 0),
    ("sous_type",  QVariant.String, 30, 0),
    ("exception",  QVariant.Int,     1, 0),
    ("surface_m2", QVariant.Double, 12, 1),
])
value_map(ci, "fonction", FONCTIONS)
value_map(ci, "sous_type", SOUS_TYPES)
remplir(ci, {"surface_m2": "round($area, 1)", "exception": "0"})

cr = couche(NOM_RUES)
print("\n[ %s ]  %d entités" % (cr.name(), cr.featureCount()))
ajouter_champs(cr, [
    ("hierarchie", QVariant.String, 20, 0),
    ("largeur_m",  QVariant.Double,  5, 1),
])
value_map(cr, "hierarchie", HIERARCHIES)
if "hierarchy" in [f.name() for f in cr.fields()]:
    remplir(cr, {"hierarchie": "lower(trim(\"hierarchy\"))"})
    print("   ⚠️ l'ancien champ `hierarchy` n'est PAS supprimé.")
    print("      Le retirer à la main une fois la recopie vérifiée.")

print("\n" + "=" * 66)
if SIMULATION:
    print("Rien n'a été écrit. Passer SIMULATION = False pour appliquer.")
else:
    print("Appliqué. Vérifier dans la table attributaire avant d'enregistrer.")
print("=" * 66)
