# -*- coding: utf-8 -*-
"""
Le seul endroit du dépôt qui sait lire et écrire LA SOURCE de la carte.

    QGIS/data/source/*.geojson   ← du TEXTE, suivi par git, fusionnable
    QGIS/data/travail/*.gpkg     ← du binaire DÉRIVÉ, gitignoré, jetable

🔄 La source était `Vallmar2.gpkg`, un binaire suivi par git, jusqu'au
2026-08-17. Deux prix payés à chaque session : git ne fusionne pas un `.gpkg`,
d'où l'ancienne règle « la carte ne s'écrit que sous Windows » ; et le dérivé
suivi lui aussi se périmait en silence (2026-08-14, une session passée à
décrire un défaut déjà corrigé). QGIS étant sorti de la chaîne (65), plus
personne n'ouvre ces fichiers à la main — et la source ne contient que de la
géométrie, ~250 ko de texte, tout le reste étant recalculé.

FORMAT. Du GeoJSON écrit à la main pour tenir UNE ENTITÉ PAR LIGNE : c'est ce
qui rend le diff lisible et la fusion possible. `json.dump(indent=…)` casserait
les deux. Coordonnées en EPSG:25832, écrites par `repr()`.

🔴 LA SOURCE NE S'ARRONDIT PAS — piège payé le 2026-08-17. Arrondir au
millimètre a fait passer `04c` de 2 coupes effacées à 1 : la rectangularité de
l'îlot 13 vaut 1,00 pile contre un seuil à 0,90, et un demi-millimètre suffit
à faire basculer un test de forme. Le diff reste propre, `repr()` étant
déterministe.

⚠️ Le GeoJSON standard impose du WGS84 ; on ne le respecte pas volontairement,
reprojeter perdrait la précision métrique pour personne.
"""

import json
import os
import struct

SRS = 25832

ICI = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(os.path.dirname(ICI), "data")
SOURCE = os.path.join(DATA, "source")
TRAVAIL = os.path.join(DATA, "travail")
CARTE = os.path.join(TRAVAIL, "wehrau.gpkg")

# Les couches de la source, et ce qu'elles portent en plus de la géométrie.
# `chemins` est facultative : elle n'existe qu'une fois `tracer_chemins.py`
# passé, et `02` la recopie telle quelle dans la carte de travail.
COUCHES = {
    "ilots":   {"type": "POLYGON", "champs": []},
    "routes":  {"type": "MULTILINESTRING", "champs": [("hierarchy", "TEXT")]},
    "chemins": {"type": "LINESTRING",
                "champs": [("fid_ilot", "INTEGER"), ("largeur_m", "REAL"),
                           ("note", "TEXT")]},
}


# ==========================================================================
# WKB — le format binaire des géométries, partagé par toute la chaîne
# ==========================================================================

def gpkg_vers_wkb(blob):
    """Saute l'en-tête GeoPackage : 8 octets + l'enveloppe si elle est là."""
    return blob[8 + {0: 0, 1: 32, 2: 48, 3: 48, 4: 64}[(blob[3] >> 1) & 0x07]:]


def _lire_simple(buf, off):
    o = "<" if buf[off] == 1 else ">"
    typ = struct.unpack_from(o + "I", buf, off + 1)[0] % 1000
    off += 5

    def pts(off, n):
        return ([struct.unpack_from(o + "dd", buf, off + 16 * i)
                 for i in range(n)], off + 16 * n)

    if typ == 1:
        return [[struct.unpack_from(o + "dd", buf, off)]], off + 16
    if typ == 2:
        n, = struct.unpack_from(o + "I", buf, off)
        p, off = pts(off + 4, n)
        return [p], off
    if typ == 3:
        nr, = struct.unpack_from(o + "I", buf, off)
        off += 4
        anns = []
        for _ in range(nr):
            n, = struct.unpack_from(o + "I", buf, off)
            p, off = pts(off + 4, n)
            anns.append(p)
        return anns, off
    raise ValueError("type WKB simple inattendu : %d" % typ)


def lire_wkb(buf):
    """-> (liste de listes de points, type géométrique)."""
    o = "<" if buf[0] == 1 else ">"
    typ = struct.unpack_from(o + "I", buf, 1)[0] % 1000
    if typ in (1, 2, 3):
        return _lire_simple(buf, 0)[0], typ
    if typ in (4, 5, 6):
        ng, = struct.unpack_from(o + "I", buf, 5)
        off = 9
        out = []
        for _ in range(ng):
            parts, off = _lire_simple(buf, off)
            out.extend(parts)
        return out, typ
    raise ValueError("type WKB inattendu : %d" % typ)


def wkb_polygone(anneaux):
    out = [struct.pack("<BII", 1, 3, len(anneaux))]
    for a in anneaux:
        pts = list(a)
        if pts[0] != pts[-1]:
            pts.append(pts[0])
        out.append(struct.pack("<I", len(pts)))
        for x, y in pts:
            out.append(struct.pack("<dd", x, y))
    return b"".join(out)


def wkb_lignes(parties, multi):
    """MULTILINESTRING si `multi`, LINESTRING sinon — on rend ce qu'on a lu."""
    def une(pts):
        out = [struct.pack("<BII", 1, 2, len(pts))]
        for x, y in pts:
            out.append(struct.pack("<dd", x, y))
        return b"".join(out)
    if not multi:
        return une(parties[0])
    return struct.pack("<BII", 1, 5, len(parties)) + b"".join(une(p) for p in parties)


def blob_gpkg(wkb):
    """En-tête GeoPackage sans enveloppe (indicateur 0) — les lecteurs de la
    chaîne la recalculent, et personne n'interroge d'index spatial ici."""
    return struct.pack("<2sBBi", b"GP", 0, 0x01, SRS) + wkb


# ==========================================================================
# LA SOURCE EN TEXTE — lecture
# ==========================================================================

def _geom_vers_points(geom):
    """GeoJSON -> (liste de listes de points, multi). Les tuples, pas les
    listes : le reste de la chaîne compare des points avec `==` et s'en sert
    comme clés de dictionnaire (dédoublonnage des sommets)."""
    t = geom["type"]
    c = geom["coordinates"]
    if t == "Polygon":
        return [[tuple(p) for p in anneau] for anneau in c], False
    if t == "LineString":
        return [[tuple(p) for p in c]], False
    if t == "MultiLineString":
        return [[tuple(p) for p in part] for part in c], True
    if t == "MultiPolygon":
        return [[tuple(p) for p in anneau] for poly in c for anneau in poly], True
    raise ValueError("géométrie GeoJSON inattendue : %s" % t)


def chemin_couche(nom, dossier=None):
    return os.path.join(dossier or SOURCE, "%s.geojson" % nom)


def lire_couche(nom, dossier=None):
    """-> liste de dicts {fid, parts, multi, <champs>}, triée par fid.

    Rend None si le fichier n'existe pas : `chemins` est facultative, et
    l'appelant doit pouvoir faire la différence avec une couche vide."""
    chemin = chemin_couche(nom, dossier)
    if not os.path.exists(chemin):
        return None
    with open(chemin, "r", encoding="utf-8") as f:
        fc = json.load(f)
    out = []
    for ent in fc["features"]:
        parts, multi = _geom_vers_points(ent["geometry"])
        rec = {"fid": int(ent["id"]), "parts": parts, "multi": multi}
        rec.update(ent.get("properties") or {})
        out.append(rec)
    out.sort(key=lambda r: r["fid"])
    return out


def lire_source(dossier=None):
    """-> {nom: liste d'entités}. Les couches absentes ne sont pas dans le dict."""
    couches = {}
    for nom in COUCHES:
        lu = lire_couche(nom, dossier)
        if lu is not None:
            couches[nom] = lu
    if "ilots" not in couches or "routes" not in couches:
        raise SystemExit(
            "source incomplète dans %s — il faut au moins `ilots.geojson` et "
            "`routes.geojson`." % (dossier or SOURCE))
    return couches


# ==========================================================================
# LA SOURCE EN TEXTE — écriture
# ==========================================================================

def _nb(v):
    """`repr` d'un flottant : la plus courte écriture qui le redonne EXACTEMENT.
    Aucun arrondi — voir le piège de l'îlot 13 dans l'en-tête. Déterministe,
    donc deux écritures d'une carte inchangée sont identiques à l'octet, et
    `git status` reste propre quand rien n'a bougé."""
    return repr(float(v))


def _points_vers_geom(parts, multi, type_geom):
    def anneau(pts, fermer=False):
        pts = list(pts)
        # `00` et `00b` travaillent en anneau OUVERT et laissent
        # `wkb_polygone` refermer ; le texte doit refermer pareil.
        if fermer and len(pts) > 1 and pts[0] != pts[-1]:
            pts.append(pts[0])
        return "[%s]" % ",".join("[%s,%s]" % (_nb(x), _nb(y)) for x, y in pts)
    if type_geom == "POLYGON":
        return '{"type":"Polygon","coordinates":[%s]}' \
            % ",".join(anneau(p, True) for p in parts)
    if multi:
        return '{"type":"MultiLineString","coordinates":[%s]}' \
            % ",".join(anneau(p) for p in parts)
    return '{"type":"LineString","coordinates":%s}' % anneau(parts[0])


def ecrire_couche(nom, entites, dossier=None):
    """Une entité par ligne, triées par fid. Ces deux contraintes sont ce qui
    rend le fichier fusionnable : un conflit git ne peut porter que sur les
    entités réellement touchées des deux côtés."""
    spec = COUCHES[nom]
    os.makedirs(dossier or SOURCE, exist_ok=True)
    lignes = []
    for e in sorted(entites, key=lambda r: r["fid"]):
        props = {}
        for champ, _typ in spec["champs"]:
            if e.get(champ) is not None:
                props[champ] = e[champ]
        lignes.append(
            '{"type":"Feature","id":%d,"properties":%s,"geometry":%s}'
            % (e["fid"],
               json.dumps(props, ensure_ascii=False, sort_keys=True),
               _points_vers_geom(e["parts"], e.get("multi", False),
                                 spec["type"])))
    texte = ('{\n"type": "FeatureCollection",\n"name": "%s",\n'
             '"crs": "EPSG:%d",\n"features": [\n%s\n]\n}\n'
             % (nom, SRS, ",\n".join(lignes)))
    with open(chemin_couche(nom, dossier), "w", encoding="utf-8",
              newline="\n") as f:
        f.write(texte)
    return len(lignes)


def ecrire_source(couches, dossier=None):
    return {nom: ecrire_couche(nom, ents, dossier)
            for nom, ents in couches.items()}


# ==========================================================================
# LA CARTE DE TRAVAIL — un GeoPackage neuf, construit depuis le texte
# ==========================================================================

# Les quatre systèmes de coordonnées que la spec GeoPackage exige, plus le
# nôtre. Recopiés tels quels de l'ancien `Vallmar2.gpkg`.
_SRS = [
    (-1, "NONE", -1, "Undefined cartesian SRS", "undefined",
     "undefined cartesian coordinate reference system"),
    (0, "NONE", 0, "Undefined geographic SRS", "undefined",
     "undefined geographic coordinate reference system"),
    (4326, "EPSG", 4326, "WGS 84 geodetic",
     'GEOGCS["WGS 84",DATUM["WGS_1984",SPHEROID["WGS 84",6378137,298.257223563]],'
     'PRIMEM["Greenwich",0],UNIT["degree",0.0174532925199433]]',
     "longitude/latitude coordinates in decimal degrees on the WGS 84 spheroid"),
    (25832, "EPSG", 25832, "ETRS89 / UTM zone 32N",
     'PROJCS["ETRS89 / UTM zone 32N",GEOGCS["ETRS89",DATUM["European_Terrestrial_'
     'Reference_System_1989",SPHEROID["GRS 1980",6378137,298.257222101]],'
     'PRIMEM["Greenwich",0],UNIT["degree",0.0174532925199433]],'
     'PROJECTION["Transverse_Mercator"],PARAMETER["latitude_of_origin",0],'
     'PARAMETER["central_meridian",9],PARAMETER["scale_factor",0.9996],'
     'PARAMETER["false_easting",500000],PARAMETER["false_northing",0],'
     'UNIT["metre",1],AXIS["Easting",EAST],AXIS["Northing",NORTH]]',
     "ETRS89 / UTM zone 32N"),
]

_BOILERPLATE = """
CREATE TABLE gpkg_spatial_ref_sys (
  srs_name TEXT NOT NULL, srs_id INTEGER PRIMARY KEY,
  organization TEXT NOT NULL, organization_coordsys_id INTEGER NOT NULL,
  definition TEXT NOT NULL, description TEXT);
CREATE TABLE gpkg_contents (
  table_name TEXT PRIMARY KEY, data_type TEXT NOT NULL,
  identifier TEXT UNIQUE, description TEXT DEFAULT '',
  last_change DATETIME NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  min_x DOUBLE, min_y DOUBLE, max_x DOUBLE, max_y DOUBLE,
  srs_id INTEGER REFERENCES gpkg_spatial_ref_sys(srs_id));
CREATE TABLE gpkg_geometry_columns (
  table_name TEXT NOT NULL, column_name TEXT NOT NULL,
  geometry_type_name TEXT NOT NULL, srs_id INTEGER NOT NULL,
  z TINYINT NOT NULL, m TINYINT NOT NULL,
  CONSTRAINT pk_geom_cols PRIMARY KEY (table_name, column_name));
CREATE TABLE gpkg_ogr_contents (
  table_name TEXT NOT NULL PRIMARY KEY, feature_count INTEGER DEFAULT NULL);
CREATE TABLE gpkg_extensions (
  table_name TEXT, column_name TEXT, extension_name TEXT NOT NULL,
  definition TEXT NOT NULL, scope TEXT NOT NULL,
  CONSTRAINT ge_tce UNIQUE (table_name, column_name, extension_name));
"""


def _enveloppe(entites):
    xs = [p[0] for e in entites for pa in e["parts"] for p in pa]
    ys = [p[1] for e in entites for pa in e["parts"] for p in pa]
    if not xs:
        return (None, None, None, None)
    return (min(xs), min(ys), max(xs), max(ys))


def construire_gpkg(cible, couches=None, dossier_source=None):
    """Fabrique une carte de travail NEUVE depuis la source en texte.

    Remplace le `shutil.copy2(Vallmar2.gpkg, …)` de `02_qualifier.py`. Aucun
    index spatial n'est créé : rien dans la chaîne n'interroge le rtree, et
    l'écrire coûterait des déclencheurs SQL à maintenir pour personne.

    ⚠️ Le fichier cible est ÉCRASÉ. C'est voulu et c'est le cœur de la
    nouvelle règle : la carte de travail est jetable, la source ne l'est pas.
    """
    import sqlite3

    couches = couches or lire_source(dossier_source)
    os.makedirs(os.path.dirname(os.path.abspath(cible)) or ".", exist_ok=True)
    if os.path.exists(cible):
        os.remove(cible)

    con = sqlite3.connect(cible)
    cur = con.cursor()
    # 0x47504B47 = « GPKG », et 10200 = version 1.2. Un fichier sans ces deux
    # nombres est un SQLite ordinaire que les outils SIG refusent d'ouvrir.
    cur.execute("PRAGMA application_id = 1196444487")
    cur.execute("PRAGMA user_version = 10200")
    cur.executescript(_BOILERPLATE)
    cur.executemany("INSERT INTO gpkg_spatial_ref_sys (srs_id, organization,"
                    " organization_coordsys_id, srs_name, definition,"
                    " description) VALUES (?,?,?,?,?,?)", _SRS)

    for nom, entites in couches.items():
        spec = COUCHES[nom]
        cols = "".join(', "%s" %s' % (c, t) for c, t in spec["champs"])
        cur.execute('CREATE TABLE "%s" ("fid" INTEGER PRIMARY KEY '
                    'AUTOINCREMENT NOT NULL, "geom" %s%s)'
                    % (nom, spec["type"], cols))
        noms = [c for c, _ in spec["champs"]]
        sql = ('INSERT INTO "%s" (fid, geom%s) VALUES (?,?%s)'
               % (nom, "".join(', "%s"' % c for c in noms), ",?" * len(noms)))
        for e in entites:
            if spec["type"] == "POLYGON":
                wkb = wkb_polygone(e["parts"])
            else:
                wkb = wkb_lignes(e["parts"],
                                 spec["type"] == "MULTILINESTRING")
            cur.execute(sql, [e["fid"], blob_gpkg(wkb)]
                        + [e.get(c) for c in noms])

        x0, y0, x1, y1 = _enveloppe(entites)
        cur.execute("INSERT INTO gpkg_contents (table_name, data_type,"
                    " identifier, description, min_x, min_y, max_x, max_y,"
                    " srs_id) VALUES (?,'features',?,'',?,?,?,?,?)",
                    (nom, nom, x0, y0, x1, y1, SRS))
        cur.execute("INSERT INTO gpkg_geometry_columns (table_name,"
                    " column_name, geometry_type_name, srs_id, z, m)"
                    " VALUES (?,'geom',?,?,0,0)", (nom, spec["type"], SRS))
        cur.execute("INSERT INTO gpkg_ogr_contents (table_name, feature_count)"
                    " VALUES (?,?)", (nom, len(entites)))

    con.commit()
    con.close()
    return {nom: len(e) for nom, e in couches.items()}


# ==========================================================================
# Reprise : convertir un vieux GeoPackage en source texte
# ==========================================================================

def importer_gpkg(source_gpkg, dossier=None):
    """Le pont d'origine — a servi une fois, le 2026-08-17, pour sortir
    `Vallmar2.gpkg` du dépôt. Gardé parce qu'il redevient utile le jour où
    une carte arrive de l'extérieur en `.gpkg`."""
    import sqlite3

    con = sqlite3.connect("file:%s?mode=ro" % source_gpkg.replace("\\", "/"),
                          uri=True)
    presentes = {r[0] for r in
                 con.execute("SELECT table_name FROM gpkg_geometry_columns")}
    couches = {}
    for nom in COUCHES:
        if nom not in presentes:
            continue
        noms = [c for c, _ in COUCHES[nom]["champs"]]
        sql = ('SELECT fid, geom%s FROM "%s" ORDER BY fid'
               % ("".join(', "%s"' % c for c in noms), nom))
        ents = []
        for r in con.execute(sql):
            parts, typ = lire_wkb(gpkg_vers_wkb(r[1]))
            rec = {"fid": r[0], "parts": parts, "multi": typ in (4, 5, 6)}
            rec.update(dict(zip(noms, r[2:])))
            ents.append(rec)
        couches[nom] = ents
    con.close()
    return ecrire_source(couches, dossier)
