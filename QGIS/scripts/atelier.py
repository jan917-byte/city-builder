# -*- coding: utf-8 -*-
"""
L'ALLER-RETOUR AVEC QGIS — l'auteur dessine, la chaîne reprend.

    python QGIS/scripts/atelier.py --ouvrir              prépare le chantier
    python QGIS/scripts/atelier.py --reprendre --blanc   montre, n'écrit rien
    python QGIS/scripts/atelier.py --reprendre           écrit dans la SOURCE

✏️ CE SCRIPT ÉCRIT DANS `data/source/` : c'est du LEVEL DESIGN, pas du dérivé.
Il est le quatrième après `00`, `00b` et `tracer_chemins`, et il applique les
mêmes garde-fous — arbre git propre exigé, `--blanc` disponible, contrôles en
français. Il refuse aussi d'écraser un atelier non repris.

Le chantier est `data/travail/atelier.gpkg` : jetable, gitignoré comme tout
GeoPackage. Ce qui compte n'existe qu'une fois `--reprendre` passé.
"""
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import carte

ICI = os.path.dirname(os.path.abspath(__file__))
RACINE = os.path.dirname(os.path.dirname(ICI))
ATELIER = os.path.join(carte.TRAVAIL, "atelier.gpkg")
PROJET = os.path.join(carte.TRAVAIL, "atelier.qgs")

# 🔴 CE QUE `02_qualifier.py` CONNAÎT DÉJÀ. Un îlot neuf absent de toutes ces
# listes tombe en `maisons_de_ville` sans rien dire : `--reprendre` le nomme.
LISTES_02 = ("RIVIERE", "CHAMPS", "PLACE_PARKING", "FRICHES", "EQUIPEMENTS",
             "BARRE", "PARCS", "JARDINS", "FRONT_COMMERCANT", "COEUR_ANCIEN",
             "PAVILLONNAIRE", "COLLECTIF_1995", "ILOT_COMPACT",
             "COEUR_VERT_PRIVE")

GENRES = ("eau", "relief", "bois")


# ==========================================================================
# Les garde-fous
# ==========================================================================

def arbre_propre():
    try:
        r = subprocess.run(["git", "status", "--porcelain"], cwd=RACINE,
                           capture_output=True, text=True, timeout=30)
    except Exception:
        return None
    return None if r.returncode else [l for l in r.stdout.splitlines() if l.strip()]


def exiger_arbre_propre():
    sale = arbre_propre()
    if sale is None:
        print("⚠️  git muet — impossible de vérifier l'arbre. J'écris quand même.")
        return
    if sale:
        print("\n❌ L'ARBRE GIT N'EST PAS PROPRE. Écrire dans la source par-dessus")
        print("   des modifications non commitées rend `git checkout` inutilisable.")
        for l in sale[:12]:
            print("   " + l)
        raise SystemExit("committe ou range d'abord, puis relance.")


# ==========================================================================
# Lecture des deux côtés
# ==========================================================================

def lire_atelier():
    if not os.path.exists(ATELIER):
        raise SystemExit("pas d'atelier : lance d'abord `--ouvrir`.")
    return carte.lire_gpkg(ATELIER)


def listes_connues():
    """Les fid déjà nommés dans `02`, par liste. Lu, jamais réécrit."""
    chemin = os.path.join(ICI, "02_qualifier.py")
    espace = {}
    with open(chemin, encoding="utf-8") as f:
        for ligne in f:
            for nom in LISTES_02:
                if ligne.startswith(nom + " = ["):
                    espace[nom] = eval(ligne.split("=", 1)[1].split("#")[0].strip())
    return espace


# ==========================================================================
# --ouvrir
# ==========================================================================

def ouvrir(refaire):
    couches = carte.lire_source()
    couches.setdefault("paysage", [])

    if os.path.exists(ATELIER) and not refaire:
        try:
            ancien = lire_atelier()
        except SystemExit:
            ancien = None
        if ancien and _resume(ancien, couches)[0]:
            raise SystemExit(
                "❌ l'atelier contient des tracés que la source n'a pas.\n"
                "   `--reprendre` d'abord, ou `--ouvrir --refaire` pour les jeter.")

    carte.construire_gpkg(ATELIER, couches)
    ecrire_projet(couches)
    print("\nATELIER PRÊT")
    for nom, ents in couches.items():
        print("   %-9s %4d entités" % (nom, len(ents)))
    print("\n   ouvrir  : %s" % PROJET)
    print("   dessiner: couche `ilots` pour les champs · couche `paysage` pour")
    print("             la rivière au-delà des bords et les massifs")
    print("   reprendre: python QGIS/scripts/atelier.py --reprendre --blanc")


# ==========================================================================
# --reprendre
# ==========================================================================

def _resume(atelier, source):
    """-> (changements, détail par couche). Compare géométrie ET attributs."""
    detail = {}
    total = 0
    for nom in set(atelier) | set(source):
        av = {e["fid"]: e for e in source.get(nom, [])}
        ap = {e["fid"]: e for e in atelier.get(nom, [])}
        neufs = sorted(set(ap) - set(av))
        partis = sorted(set(av) - set(ap))
        bouges = sorted(f for f in set(av) & set(ap)
                        if _empreinte(av[f], nom) != _empreinte(ap[f], nom))
        if neufs or partis or bouges:
            detail[nom] = (neufs, partis, bouges)
            total += len(neufs) + len(partis) + len(bouges)
    return total, detail


def _empreinte(e, nom):
    champs = [c for c, _ in carte.COUCHES[nom]["champs"]]
    return (e["parts"], e.get("multi", False), [e.get(c) for c in champs])


def reprendre(blanc):
    atelier = lire_atelier()
    source = carte.lire_source()
    source.setdefault("paysage", [])
    total, detail = _resume(atelier, source)

    print("\n" + "=" * 74)
    print("CE QUE L'ATELIER CHANGE DANS LA SOURCE")
    print("=" * 74)
    if not total:
        print("   rien — l'atelier et la source disent la même chose.")
        return

    for nom in ("ilots", "routes", "chemins", "paysage"):
        if nom not in detail:
            continue
        neufs, partis, bouges = detail[nom]
        print("\n%s" % nom.upper())
        if neufs:
            print("   %3d dessinés   fid %s" % (len(neufs), _liste(neufs)))
        if bouges:
            print("   %3d retouchés  fid %s" % (len(bouges), _liste(bouges)))
        if partis:
            print("   %3d effacés    fid %s" % (len(partis), _liste(partis)))

    _controler_paysage(atelier.get("paysage", []))
    _controler_ilots_neufs(detail)

    if blanc:
        print("\n--blanc : rien n'a été écrit.")
        return

    exiger_arbre_propre()
    ecrits = carte.ecrire_source(atelier)
    print("\nSOURCE ÉCRITE")
    for nom, n in sorted(ecrits.items()):
        print("   %-9s %4d entités" % (nom, n))
    print("\n   vérifier : git diff --stat QGIS/data/source")
    print("   annuler  : git checkout QGIS/data/source")
    print("   relancer : python QGIS/scripts/chaine.py --godot")


def _liste(fids, max_montres=14):
    if len(fids) <= max_montres:
        return " ".join(map(str, fids))
    return " ".join(map(str, fids[:max_montres])) + " … (+%d)" % (len(fids) - max_montres)


def _controler_paysage(ents):
    """Un genre inconnu ne casse rien : il est simplement ignoré au rendu."""
    if not ents:
        return
    par_genre = {}
    for e in ents:
        par_genre.setdefault(e.get("genre") or "—", []).append(e["fid"])
    print("\nPAYSAGE — ce que chaque genre porte")
    for genre, fids in sorted(par_genre.items()):
        marque = "  ✅" if genre in GENRES else "  ⚠️  genre inconnu"
        print("   %-8s %3d formes%s" % (genre, len(fids), marque))
    muets = [e["fid"] for e in ents
             if e.get("genre") == "relief" and e.get("altitude_m") in (None, 0)]
    if muets:
        print("   ⚠️  relief sans altitude_m : fid %s" % _liste(muets))
        print("      (sans hauteur, le massif restera plat quand on le soulèvera)")


def _controler_ilots_neufs(detail):
    neufs = detail.get("ilots", ([], [], []))[0]
    if not neufs:
        return
    connus = listes_connues()
    orphelins = [f for f in neufs
                 if not any(f in v for v in connus.values())]
    if not orphelins:
        return
    print("\n🔴 %d ÎLOTS NEUFS NE SONT DANS AUCUNE LISTE DE `02_qualifier.py`" % len(orphelins))
    print("   fid %s" % _liste(orphelins, 30))
    print("   Sans décision, ils tomberont en `maisons_de_ville` — pas en champ.")
    print("   C'est du level design : dis-moi dans quelle liste ils vont.")


# ==========================================================================
# Le projet QGIS
# ==========================================================================

STYLES = {
    # couche      remplissage        contour       largeur
    "paysage":   ("173,196,140,90",  "90,120,70",  "0.5"),
    "ilots":     ("222,214,196,110", "70,70,70",   "0.26"),
    "routes":    (None,              "200,60,50",  "0.6"),
    "chemins":   (None,              "150,90,190", "0.4"),
}

# ✏️ CE QUE L'AUTEUR DOIT DISTINGUER AU COUP D'ŒIL POUR DESSINER : les champs
# à découper, l'eau à prolonger, et le bâti auquel il ne touche pas.
REGLES_ILOTS = [("CHAMPS",  "les champs — à découper", "150,178,106,120", "90,120,70"),
                ("RIVIERE", "l'Ilse",                  "104,173,179,150", "60,120,130")]


def _sym(i, typ, cls, props):
    opts = "".join('<Option type="QString" name="%s" value="%s"/>' % k for k in props)
    return ('<symbol type="%s" name="%d" alpha="1" force_rhr="0" frame_rate="10">'
            '<layer class="%s" enabled="1" pass="0" locked="0">'
            '<Option type="Map">%s</Option></layer></symbol>' % (typ, i, cls, opts))


def _fill(i, remp, trait, larg):
    return _sym(i, "fill", "SimpleFill",
                [("color", remp), ("outline_color", trait),
                 ("outline_width", larg), ("style", "solid"),
                 ("outline_style", "solid"), ("joinstyle", "bevel")])


def _symbole(nom, i):
    remp, trait, larg = STYLES[nom]
    if remp is None:
        return _sym(i, "line", "SimpleLine",
                    [("line_color", trait), ("line_width", larg),
                     ("capstyle", "round"), ("joinstyle", "round")])
    return _fill(i, remp, trait, larg)


# 🔴 RECOPIÉ DE CE QUE QGIS 3.42 ÉCRIT LUI-MÊME. Un bloc bricolé à la main
# se relit sans erreur mais laisse le CRS du projet VIDE — mesuré le
# 2026-09-10. `<srsid>` est retiré : c'est un identifiant de la base
# locale de QGIS, pas un standard, et il diffère d'une machine à l'autre.
_SRS_XML = '<spatialrefsys nativeFormat="Wkt"><wkt>PROJCRS["ETRS89 / UTM zone 32N",BASEGEOGCRS["ETRS89",ENSEMBLE["European Terrestrial Reference System 1989 ensemble",MEMBER["European Terrestrial Reference Frame 1989"],MEMBER["European Terrestrial Reference Frame 1990"],MEMBER["European Terrestrial Reference Frame 1991"],MEMBER["European Terrestrial Reference Frame 1992"],MEMBER["European Terrestrial Reference Frame 1993"],MEMBER["European Terrestrial Reference Frame 1994"],MEMBER["European Terrestrial Reference Frame 1996"],MEMBER["European Terrestrial Reference Frame 1997"],MEMBER["European Terrestrial Reference Frame 2000"],MEMBER["European Terrestrial Reference Frame 2005"],MEMBER["European Terrestrial Reference Frame 2014"],ELLIPSOID["GRS 1980",6378137,298.257222101,LENGTHUNIT["metre",1]],ENSEMBLEACCURACY[0.1]],PRIMEM["Greenwich",0,ANGLEUNIT["degree",0.0174532925199433]],ID["EPSG",4258]],CONVERSION["UTM zone 32N",METHOD["Transverse Mercator",ID["EPSG",9807]],PARAMETER["Latitude of natural origin",0,ANGLEUNIT["degree",0.0174532925199433],ID["EPSG",8801]],PARAMETER["Longitude of natural origin",9,ANGLEUNIT["degree",0.0174532925199433],ID["EPSG",8802]],PARAMETER["Scale factor at natural origin",0.9996,SCALEUNIT["unity",1],ID["EPSG",8805]],PARAMETER["False easting",500000,LENGTHUNIT["metre",1],ID["EPSG",8806]],PARAMETER["False northing",0,LENGTHUNIT["metre",1],ID["EPSG",8807]]],CS[Cartesian,2],AXIS["(E)",east,ORDER[1],LENGTHUNIT["metre",1]],AXIS["(N)",north,ORDER[2],LENGTHUNIT["metre",1]],USAGE[SCOPE["Engineering survey, topographic mapping."],AREA["Europe between 6°E and 12°E: Austria; Belgium; Denmark - onshore and offshore; Germany - onshore and offshore; Norway including - onshore and offshore; Spain - offshore."],BBOX[38.76,6,84.33,12]],ID["EPSG",25832]]</wkt><proj4>+proj=utm +zone=32 +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs</proj4><srid>25832</srid><authid>EPSG:25832</authid><description>ETRS89 / UTM zone 32N</description><projectionacronym>utm</projectionacronym><ellipsoidacronym>EPSG:7019</ellipsoidacronym><geographicflag>false</geographicflag></spatialrefsys>'


def _rendu(nom):
    """`ilots` est rendu PAR RÈGLES : sans ça, champs et bâti sont un même
    aplat et l'auteur ne voit pas ce qu'il a le droit de découper."""
    if nom != "ilots":
        return ('<renderer-v2 type="singleSymbol" forceraster="0" symbollevels="0">'
                '<symbols>%s</symbols></renderer-v2>' % _symbole(nom, 0))
    connus = listes_connues()
    symboles, regles = [], []
    for i, (liste, libelle, remp, trait) in enumerate(REGLES_ILOTS):
        fids = connus.get(liste) or []
        if not fids:
            continue
        symboles.append(_fill(i, remp, trait, "0.4"))
        regles.append('<rule key="r%d" symbol="%d" label="%s" filter="%s"/>'
                      % (i, i, libelle,
                         "fid IN (%s)" % ",".join(map(str, sorted(fids)))))
    i = len(symboles)
    symboles.append(_fill(i, *STYLES["ilots"]))
    regles.append('<rule key="rz" symbol="%d" label="le bâti — ne pas y toucher"/>' % i)
    return ('<renderer-v2 type="RuleRenderer" forceraster="0" symbollevels="0">'
            '<rules key="ilots">%s</rules><symbols>%s</symbols></renderer-v2>'
            % ("".join(regles), "".join(symboles)))


def ecrire_projet(couches):
    """🔴 Le .qgs est ÉCRIT À LA MAIN : les scripts tournent sur un Python nu,
    PyQGIS n'est pas importable. Ordre d'affichage : le décor sous la ville."""
    ordre = ["paysage", "ilots", "routes", "chemins"]
    ordre = [n for n in ordre if n in couches or n == "paysage"]
    x0, y0, x1, y1 = carte._enveloppe(couches["ilots"])
    m = 1400.0     # la marge montre où le décor a la place d'aller

    layers, noeuds, ids = [], [], []
    for i, nom in enumerate(ordre):
        lid = "%s_atelier" % nom
        ids.append(lid)
        geom = "Line" if nom in ("routes", "chemins") else "Polygon"
        champs = "".join(
            '<field name="%s" configurationFlags="NoFlag"/>' % c
            for c, _ in carte.COUCHES[nom]["champs"])
        layers.append(
            '<maplayer type="vector" geometry="%s" hasScaleBasedVisibilityFlag="0" '
            'refreshOnNotifyEnabled="0" simplifyDrawingHints="0" readOnly="0">'
            '<id>%s</id>'
            '<datasource>./atelier.gpkg|layername=%s</datasource>'
            '<layername>%s</layername>'
            '<srs>%s</srs>'
            '<provider encoding="UTF-8">ogr</provider>'
            '%s'
            '<fieldConfiguration>%s</fieldConfiguration>'
            '<layerGeometryType>%d</layerGeometryType>'
            '</maplayer>'
            % (geom, lid, nom, nom, _SRS_XML, _rendu(nom), champs,
               1 if geom == "Line" else 2))
        noeuds.append('<layer-tree-layer id="%s" name="%s" source="./atelier.gpkg|layername=%s" '
                      'providerKey="ogr" checked="Qt::Checked" expanded="0"/>'
                      % (lid, nom, nom))

    # ✏️ L'ACCROCHAGE EST ALLUMÉ D'OFFICE, sur sommet ET segment, 12 px : un
    # champ qui ne partage pas EXACTEMENT ses sommets avec l'îlot voisin sort
    # du graphe d'adjacence de `03` sans que rien ne le signale.
    snap = ('<snapping-settings enabled="1" mode="2" type="3" unit="1" '
            'tolerance="12" intersection-snapping="0" self-snapping="0" '
            'scale-dependency-mode="0" minScale="0" maxScale="0">'
            '<individual-layer-settings>%s</individual-layer-settings>'
            '</snapping-settings>'
            % "".join('<layer-setting id="%s" enabled="1" type="3" units="1" '
                      'tolerance="12" minScale="0" maxScale="0"/>' % i for i in ids))

    xml = ('<?xml version="1.0" encoding="UTF-8"?>\n'
           '<qgis projectname="Wehrau — atelier de dessin" version="3.42.1-Münster">'
           '<homePath path=""/>'
           '<title>Wehrau — atelier de dessin</title>'
           '<projectCrs>%s</projectCrs>'
           '<layer-tree-group>%s<custom-order enabled="0"/></layer-tree-group>'
           '<mapcanvas name="theMapCanvas">'
           '<units>meters</units>'
           '<extent><xmin>%r</xmin><ymin>%r</ymin><xmax>%r</xmax><ymax>%r</ymax></extent>'
           '<destinationsrs>%s</destinationsrs>'
           '</mapcanvas>'
           '%s'
           '<projectlayers>%s</projectlayers>'
           '<properties><Gui><CanvasColorBluePart type="int">242</CanvasColorBluePart>'
           '<CanvasColorGreenPart type="int">246</CanvasColorGreenPart>'
           '<CanvasColorRedPart type="int">236</CanvasColorRedPart></Gui>'
           '<SpatialRefSys><ProjectionsEnabled type="int">1</ProjectionsEnabled></SpatialRefSys>'
           '<Digitizing><DefaultSnapType type="QString">to vertex and segment</DefaultSnapType>'
           '</Digitizing></properties>'
           '</qgis>\n'
           % (_SRS_XML, "".join(reversed(noeuds)),
              x0 - m, y0 - m, x1 + m, y1 + m, _SRS_XML, snap, "".join(layers)))
    os.makedirs(os.path.dirname(PROJET), exist_ok=True)
    with open(PROJET, "w", encoding="utf-8", newline="\n") as f:
        f.write(xml)


# ==========================================================================

def main():
    a = sys.argv[1:]
    if "--ouvrir" in a:
        ouvrir("--refaire" in a)
    elif "--reprendre" in a:
        reprendre("--blanc" in a)
    else:
        print(__doc__)


if __name__ == "__main__":
    main()
