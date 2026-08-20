# -*- coding: utf-8 -*-
"""
⚰️ VESTIGE — NE PLUS LANCER. Se collait dans la console Python de QGIS pour
poser des listes déroulantes de saisie. QGIS est sorti du projet le 2026-08-17
et sa liste `SOUS_TYPES` a divergé de `02`. Gardé parce
qu'il documente ce que la saisie manuelle demandait avant les scripts.

Ajoute les champs manquants, recopie `hierarchy` → `hierarchie` en minuscules,
calcule `surface_m2`, pose les value maps. Aucune géométrie touchée ;
`fonction` et `sous_type` restent VIDES — c'était la saisie de l'auteur.
"""

from qgis.core import QgsProject, QgsField, QgsEditorWidgetSetup
from qgis.PyQt.QtCore import QVariant

SIMULATION = True          # ← True = on regarde, False = on écrit

NOM_ILOTS = "ilots"
NOM_RUES = "routes"        # nom actuel de la couche ; le vault dit `rues`

# --- taxonomie -------------------------------------------------------------
# `fonction` vient de Géométrie et données (décision 32), c'est arrêté.
FONCTIONS = ["freiraum", "habitation", "industrie", "mixte", "riviere"]

# ⚠️ PROPOSITION, PAS DÉCISION — le vault dit « ~12 combinaisons » sans les
# lister. Tirée des accroches de level design et du profil de l'Altstadt.
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
