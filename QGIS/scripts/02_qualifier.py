# -*- coding: utf-8 -*-
"""
Qualification du prototype : écrit `fonction`, `sous_type`, `exception`,
`surface_m2` sur les îlots et `hierarchie`, `largeur_m` sur les lignes.

Ne touche JAMAIS la source : il la LIT et fabrique une carte de travail
neuve, `QGIS/data/travail/wehrau.gpkg`. Aucune géométrie n'est modifiée.

🔄 Depuis le 2026-08-17 la source n'est plus `Vallmar2.gpkg` mais
`QGIS/data/source/*.geojson` — du texte que git fusionne. Ce qui a changé
ici : `shutil.copy2` d'un binaire est devenu `carte.construire_gpkg`, qui
bâtit le GeoPackage de zéro. Tout l'aval est inchangé, il lit toujours du
GeoPackage. → `carte.py`, en-tête

    python 02_qualifier.py

Tout le level design est dans les dictionnaires en haut du fichier. Pour
changer l'affectation d'un îlot, changer une ligne ici et relancer — puis
`python apercu_carte.py` pour regarder le résultat.
"""

import math
import os
import sqlite3
import struct
import sys

import carte

for flux in (sys.stdout, sys.stderr):
    try:
        flux.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, OSError):
        pass

ICI = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(os.path.dirname(ICI), "data")
SOURCE = carte.SOURCE          # QGIS/data/source/*.geojson — suivi par git
CIBLE = os.path.join(DATA, "travail", "wehrau.gpkg")   # dérivé, gitignoré

# ==========================================================================
# LE LEVEL DESIGN — c'est ici que ça se joue
# ==========================================================================

# La rivière traverse la ville du nord-est au sud-ouest. Elle est découpée
# par les franchissements : chaque morceau est un polygone.
RIVIERE = [4, 7, 51, 52, 54, 57]

# Hors les murs. Le prototype est une petite ville entière, pas un quartier :
# ce qui l'entoure est vraiment de la campagne.
CHAMPS = [1, 2, 3, 5, 6, 8, 9]

# --- les trois plaies de 1965, « fort mais réparable » ---------------------
PLACE_PARKING = [19]        # la place du marché, la plus centrale, sur l'eau
FRICHES = [31, 65]          # le moulin et la brasserie, en aval

# La voie rapide de berge est une propriété de la RUE, pas du type d'îlot :
# cette liste ne sert qu'à repérer les tronçons de rive qui la portent, et à
# leur donner 22 m de largeur. Les îlots concernés sont du tissu ordinaire.
BERGE_VOIE_RAPIDE = [15, 55, 58]

# --- les points fixes de la ville -----------------------------------------
EQUIPEMENTS = [16, 36]      # église protégée · lycée
# 🔄 2026-08-18, demandé par l'auteur : l'îlot 17 était le Rathaus, il repasse
# en `coeur_ancien`. Wehrau n'a donc plus de mairie sur la carte — c'est un
# choix, pas un oubli. Pour la remettre, ajouter un fid ici ET le retirer de
# COEUR_ANCIEN ci-dessous ; 20 ou 22 conviennent (voisins de l'église).
PATRIMOINE_PROTEGE = [16]   # l'église : aucun panneau solaire en toiture
# L'hôpital a été retiré : il était sur l'îlot 26. Pour le remettre ailleurs,
# ajouter un fid ici — 35 (bord ouest) ou 30 (accès par l'axe sud) conviennent.
BARRE = [32]                # le grand ensemble de 1974, en aval, au bord de l'eau
PARCS = [46]                # le jardin de ville
JARDINS = [48]              # les jardins familiaux, au nord-ouest

# --- le tissu -------------------------------------------------------------
FRONT_COMMERCANT = [12, 21, 24, 45, 72] # dont les deux moitiés de l'ancienne dalle
COEUR_ANCIEN = [13, 14, 15, 17, 18, 20, 22, 34, 37, 38, 53, 55, 56]
# 70 et 71 sont les moitiés neuves du 26 et du 42, coupées le 2026-08-13 par
# les rues 179 et 180 ; l'ancien 27 a été fusionné dans le 26 (rue 78 retirée).
# 73 et 74 sont les anciens numéros réservés aux ÎLOTS DE LISIÈRE posés le 2026-08-16 par
# `00b_ilots_lisiere.py` : des rubans d'une seule parcelle de profondeur, de
# l'autre côté de la rue qui fait le tour de la ville, taillés dans les champs
# 9 (nord, face au 11), 1 (sud-ouest, face au 26) et 9 encore (ouest, face au
# 42 — le ruban sud du champ 2 a été retiré le 2026-08-17, il tombait derrière
# les barres). Pavillonnaire est le seul tissu qui convienne : c'est le seul
# SANS cœur d'îlot, donc la parcelle va vraiment du trottoir au champ.
# → `00b_ilots_lisiere.py`, en-tête
PAVILLONNAIRE = [11, 26, 35, 39, 42, 47, 60, 61, 63, 64, 70, 71, 73, 74]
# tout le reste des îlots bâtis tombe en `maisons_de_ville`

# Cœur d'îlot vert privatisé : invisible depuis la rue, mais c'est le seul
# vrai gisement de fraîcheur du centre. Encodé plus tard en `canopee` élevée.
COEUR_VERT_PRIVE = [44, 49]

FONCTION_DE = {
    "riviere": "riviere", "champ": "freiraum", "parc": "freiraum",
    "jardins_familiaux": "freiraum", "place_minerale": "freiraum",
    "coeur_ancien": "mixte", "front_commercant": "mixte",
    "equipement": "mixte",
    "maisons_de_ville": "habitation", "pavillonnaire": "habitation",
    "barre_1970": "habitation",
    "friche_industrielle": "industrie",
}

# Les îlots posés à la main, protégés du recalcul (décision 32 du vault).
def sous_types():
    s = {}
    for lst, st in ((RIVIERE, "riviere"), (CHAMPS, "champ"),
                    (PLACE_PARKING, "place_minerale"),
                    (FRICHES, "friche_industrielle"),
                    (EQUIPEMENTS, "equipement"), (BARRE, "barre_1970"),
                    (PARCS, "parc"), (JARDINS, "jardins_familiaux"),
                    (FRONT_COMMERCANT, "front_commercant"),
                    (COEUR_ANCIEN, "coeur_ancien"),
                    (PAVILLONNAIRE, "pavillonnaire")):
        for fid in lst:
            if fid in s:
                raise SystemExit("îlot %d affecté deux fois (%s et %s)"
                                 % (fid, s[fid], st))
            s[fid] = st
    return s


# `exception = 1` : saisie manuelle protégée. Tout ce qui est du level design
# posé consciemment, par opposition au tissu ordinaire dérivé par règle.
def exceptions():
    e = set(RIVIERE) | set(PLACE_PARKING) \
        | set(FRICHES) | set(EQUIPEMENTS) | set(BARRE) | set(PARCS) \
        | set(JARDINS) | set(COEUR_VERT_PRIVE)
    return e


# --- les rues -------------------------------------------------------------
# Les franchissements de l'Ilse qu'on RETIRE de la carte. Décision 30c : trois
# ponts, pas cinq — « à cinq ponts la rivière ne coupe plus rien, et ajouter
# une passerelle cesse d'être une décision ».
#
# Le choix des deux, tranché par l'auteur le 2026-08-12 devant le tableau :
#   · 136 — un boulevard de 20 m à 20 m de 145, qui atterrit sur le même îlot.
#           Le même franchissement compté deux fois, et le moins chargé de tous
#           (0,04). C'est lui qui faisait que la rivière ne coupait rien au nord
#   · 171 — la petite rue de 12 m du nord (charge 0,07), qui ne dessert que des
#           champs et dix logements déjà servis par 145
#
# Les trois qui restent tombent un par tiers de rivière : 145 au nord (0,69),
# 168 au milieu (0,42), 169 au sud (0,24). ⚠️ 168 est intouchable — c'est le
# seul accès des 279 logements du cœur du faubourg de rive gauche, celui que la
# crue d'ouverture frappe (23b).
#
# Les dix paires possibles ont été testées : AUCUNE ne coupe le réseau routier
# en deux. Le contrôle de connexité de `03` doit donc toujours passer après.
PONTS_SUPPRIMES = [136, 171]

# Largeur par défaut, en mètres, par hiérarchie. Base du profil en travers.
LARGEUR = {"boulevard": 18.0, "rue": 12.0, "ruelle": 7.0,
           "rive": 0.0, "voie ferree": 8.0, "autoroute": 25.0}

# La voie rapide de berge : plus large que le reste, c'est tout le problème.
LARGEUR_QUAI = 22.0
# L'axe de transit nord-sud qui traverse le cœur.
LARGEUR_TRANSIT = 20.0
# Une berge qui longe du bâti porte une rue de quai ordinaire. Une berge qui
# ne longe que des champs n'est qu'une rive : 0 m.
LARGEUR_QUAI_ORDINAIRE = 10.0

# Une largeur constante par hiérarchie rendrait tout seuil inopérant : « je
# plante sur toute rue de plus de X m » n'aurait que trois réponses possibles.
# Les rues et ruelles varient donc selon le tissu qu'elles desservent et selon
# leur longueur — les percées rectilignes sont celles qu'on a élargies.
# Les boulevards, eux, gardent leur largeur posée à la main : c'est du level
# design, et seuls le quai et l'axe de transit doivent dépasser 20 m.
MOD_ANCIEN = -2.0        # parcellaire ancien : l'emprise n'a jamais bougé
MOD_MODERNE = +2.0       # normes des années 60 : lotissements, barre, dalle
MOD_CAMPAGNE = +1.0      # route de campagne : accotements
MOD_LONGUEUR_MAX = 3.0   # + 1 m par 60 m au-delà de 60 m, plafonné


# ==========================================================================
# mécanique — rien à régler en dessous
# ==========================================================================

def gpkg_vers_wkb(blob):
    tailles = {0: 0, 1: 32, 2: 48, 3: 48, 4: 64}
    return blob[8 + tailles[(blob[3] >> 1) & 0x07]:]


def _e(buf, off, o):
    return struct.unpack_from(o + "I", buf, off)[0], off + 4


def _p(buf, off, o, n):
    c = struct.unpack_from(o + "%dd" % (2 * n), buf, off)
    return [(c[i], c[i + 1]) for i in range(0, 2 * n, 2)], off + 16 * n


def lire_wkb(buf, off=0):
    o = "<" if buf[off] == 1 else ">"
    off += 1
    g, off = _e(buf, off, o)
    base = g % 1000
    if base == 2:
        n, off = _e(buf, off, o)
        pts, off = _p(buf, off, o, n)
        return [pts], off
    if base == 3:
        na, off = _e(buf, off, o)
        r = []
        for _ in range(na):
            n, off = _e(buf, off, o)
            pts, off = _p(buf, off, o, n)
            r.append(pts)
        return r, off
    if base in (5, 6):
        ng, off = _e(buf, off, o)
        t = []
        for _ in range(ng):
            p, off = lire_wkb(buf, off)
            t.extend(p)
        return t, off
    raise ValueError("WKB %d" % base)


def aire(r):
    s = 0.0
    for i in range(len(r) - 1):
        s += r[i][0] * r[i + 1][1] - r[i + 1][0] * r[i][1]
    return abs(s) / 2.0


def dedans(r, p):
    x, y = p
    d = False
    for i in range(len(r) - 1):
        x1, y1 = r[i]
        x2, y2 = r[i + 1]
        if (y1 > y) != (y2 > y) and x < x1 + (y - y1) * (x2 - x1) / (y2 - y1):
            d = not d
    return d


def enveloppe(blob):
    """(minx, maxx, miny, maxy) — depuis l'en-tête GeoPackage, sinon calculée."""
    ind = (blob[3] >> 1) & 0x07
    if ind in (1, 2, 3, 4):
        o = "<" if blob[3] & 1 else ">"
        return struct.unpack_from(o + "4d", blob, 8)
    parts, _ = lire_wkb(gpkg_vers_wkb(blob))
    xs = [p[0] for pa in parts for p in pa]
    ys = [p[1] for pa in parts for p in pa]
    return (min(xs), max(xs), min(ys), max(ys))


def brancher_fonctions_spatiales(con):
    """Les déclencheurs d'index spatial du GeoPackage appellent ST_*.
    SQLite seul ne les a pas : on les fournit. La géométrie n'étant jamais
    modifiée ici, ces fonctions ne font que relire ce qui est déjà écrit."""
    con.create_function("ST_IsEmpty", 1,
                        lambda b: 0 if b else 1)
    for i, nom in enumerate(("ST_MinX", "ST_MaxX", "ST_MinY", "ST_MaxY")):
        con.create_function(
            nom, 1, (lambda k: lambda b: enveloppe(b)[k] if b else None)(i))


GRILLE = 0.25


def cle_seg(a, b):
    ka = (round(a[0] / GRILLE), round(a[1] / GRILLE))
    kb = (round(b[0] / GRILLE), round(b[1] / GRILLE))
    return (ka, kb) if ka <= kb else (kb, ka)


def main():
    if not os.path.isdir(SOURCE):
        raise SystemExit("source introuvable : %s" % SOURCE)
    # La carte de travail est refaite de zéro à chaque passage. C'est la
    # garantie qu'elle ne peut pas être plus vieille que la source — le piège
    # payé le 2026-08-14, une session passée à décrire un défaut déjà corrigé.
    bati = carte.construire_gpkg(CIBLE)
    print("carte de travail bâtie depuis %s — %s"
          % (os.path.relpath(SOURCE, os.path.dirname(DATA)),
             ", ".join("%s %d" % (n, c) for n, c in sorted(bati.items()))))
    con = sqlite3.connect(CIBLE)
    brancher_fonctions_spatiales(con)
    cur = con.cursor()

    # ---------------- les deux ponts qu'on retire (décision 30c)
    # Avant toute lecture, pour que tout l'aval — le comptage, `03`, `04`,
    # `04b`, l'export — travaille sur la carte réduite et jamais sur l'ancienne.
    # Le GeoPackage porte ses propres déclencheurs de suppression : l'index
    # spatial et le compteur de la couche se remettent à jour tout seuls.
    if PONTS_SUPPRIMES:
        avant = cur.execute("SELECT count(*) FROM routes").fetchone()[0]
        cur.execute("DELETE FROM routes WHERE fid IN (%s)"
                    % ",".join("?" * len(PONTS_SUPPRIMES)), PONTS_SUPPRIMES)
        apres = cur.execute("SELECT count(*) FROM routes").fetchone()[0]
        con.commit()
        print("franchissements retirés : %s — %d tronçons, puis %d"
              % (sorted(PONTS_SUPPRIMES), avant, apres))
        if avant - apres != len(PONTS_SUPPRIMES):
            raise SystemExit("un des fid à supprimer n'existait pas dans `routes`")

    # ---------------- lecture des géométries
    ilots = {}
    for fid, blob in cur.execute("SELECT fid, geom FROM ilots"):
        anneaux, _ = lire_wkb(gpkg_vers_wkb(blob))
        ilots[fid] = {"anneaux": anneaux,
                      "aire": aire(anneaux[0]) - sum(aire(a) for a in anneaux[1:])}

    rues = {}
    for fid, blob in cur.execute("SELECT fid, geom FROM routes"):
        parts, _ = lire_wkb(gpkg_vers_wkb(blob))
        lg = sum(math.hypot(p[i + 1][0] - p[i][0], p[i + 1][1] - p[i][1])
                 for p in parts for i in range(len(p) - 1))
        rues[fid] = {"parts": parts, "long": lg}

    # ---------------- qualification des îlots
    st = sous_types()
    exc = exceptions()
    inconnus = [f for f in ilots if f not in st]
    for f in inconnus:
        st[f] = "maisons_de_ville"

    for col, typ in (("fonction", "TEXT"), ("sous_type", "TEXT"),
                     ("exception", "INTEGER"), ("surface_m2", "REAL"),
                     ("solaire_possible", "INTEGER")):
        try:
            cur.execute('ALTER TABLE ilots ADD COLUMN %s %s' % (col, typ))
        except sqlite3.OperationalError:
            pass
    for fid, d in ilots.items():
        s = st[fid]
        cur.execute("UPDATE ilots SET fonction=?, sous_type=?, exception=?, "
                    "surface_m2=?, solaire_possible=? WHERE fid=?",
                    (FONCTION_DE[s], s, 1 if fid in exc else 0,
                     round(d["aire"], 1), 0 if fid in PATRIMOINE_PROTEGE else 1,
                     fid))

    # ---------------- quels îlots borde chaque tronçon
    proprio = {}
    for fid, d in ilots.items():
        r = d["anneaux"][0]
        for i in range(len(r) - 1):
            proprio.setdefault(cle_seg(r[i], r[i + 1]), set()).add(fid)

    riv = set(RIVIERE)
    quai = set(BERGE_VOIE_RAPIDE)
    transit = set(FRONT_COMMERCANT)          # l'axe qui longe le front commerçant
    coeur = set(COEUR_ANCIEN) | set(FRONT_COMMERCANT)
    champs = set(CHAMPS)
    moderne = set(PAVILLONNAIRE) | set(BARRE)
    bati = set(ilots) - riv - champs

    def moduler(base, bordes, longueur):
        """La largeur réelle d'une rue : sa base, le tissu qu'elle dessert,
        et sa longueur. Sans cette variation, aucun seuil ne discrimine."""
        w = base
        if bordes & coeur:
            w += MOD_ANCIEN
        if bordes & moderne:
            w += MOD_MODERNE
        if bordes & champs:
            w += MOD_CAMPAGNE
        w += min(MOD_LONGUEUR_MAX, max(0.0, (longueur - 60.0) / 60.0))
        return round(w, 1)

    for col, typ in (("hierarchie", "TEXT"), ("largeur_m", "REAL")):
        try:
            cur.execute('ALTER TABLE routes ADD COLUMN %s %s' % (col, typ))
        except sqlite3.OperationalError:
            pass

    anciennes = dict(cur.execute("SELECT fid, hierarchy FROM routes"))
    comptes = {}
    ponts = []
    for fid, d in rues.items():
        bordes = set()
        for p in d["parts"]:
            for i in range(len(p) - 1):
                bordes |= proprio.get(cle_seg(p[i], p[i + 1]), set())

        anc = (anciennes.get(fid) or "").strip().lower()
        long_riv = bordes & riv
        pont = not bordes and any(
            dedans(ilots[r]["anneaux"][0], d["parts"][0][len(d["parts"][0]) // 2])
            for r in riv)

        # Un tronçon qui sépare DEUX morceaux de rivière est un franchissement :
        # c'est lui qui a coupé l'Ilse en six polygones. Sans cette règle il
        # tombe en « rive » avec le reste de la berge, et la ville se retrouve
        # sans aucun pont — les deux rives ne communiquent plus du tout.
        if len(long_riv) >= 2:
            pont = True

        if pont:
            h, w = ("boulevard", LARGEUR_TRANSIT) if d["long"] > 40 \
                else ("rue", moduler(LARGEUR["rue"], bordes, d["long"]))
        elif long_riv and bordes & quai:
            h, w = "boulevard", LARGEUR_QUAI      # la voie rapide de berge
        elif long_riv:
            # une berge qui longe du bâti porte une rue de quai ; une berge
            # qui ne longe que des champs n'est qu'une rive
            h = "rive"
            w = LARGEUR_QUAI_ORDINAIRE if bordes & bati else LARGEUR["rive"]
        elif anc == "boulevard":
            h = "boulevard"
            w = LARGEUR_TRANSIT if bordes & transit else LARGEUR["boulevard"]
        elif bordes and bordes <= champs:
            h, w = "rue", moduler(LARGEUR["rue"], bordes, d["long"])
        elif bordes and bordes <= coeur:
            h, w = "ruelle", moduler(LARGEUR["ruelle"], bordes, d["long"])
        else:
            h, w = "rue", moduler(LARGEUR["rue"], bordes, d["long"])

        cur.execute("UPDATE routes SET hierarchie=?, largeur_m=? WHERE fid=?",
                    (h, w, fid))
        comptes.setdefault(h, []).append(w)
        if pont:
            ponts.append(fid)

    con.commit()

    # ---------------- compte rendu
    print("=" * 62)
    print("ÎLOTS")
    par_st = {}
    for fid in ilots:
        par_st.setdefault(st[fid], []).append(fid)
    for s in sorted(par_st, key=lambda k: -len(par_st[k])):
        ha = sum(ilots[f]["aire"] for f in par_st[s]) / 1e4
        print("  %-20s %3d îlots  %6.1f ha   %s"
              % (s, len(par_st[s]), ha,
                 sorted(par_st[s])[:12] if len(par_st[s]) <= 12 else "…"))
    print("  exceptions posées : %d" % len(exc & set(ilots)))
    print("  patrimoine sans solaire : %s" % sorted(set(PATRIMOINE_PROTEGE) & set(ilots)))
    print("\nRUES")
    for h in sorted(comptes, key=lambda k: -len(comptes[k])):
        w = comptes[h]
        print("  %-12s %3d tronçons   %4.1f–%4.1f m   %d largeurs distinctes"
              % (h, len(w), min(w), max(w), len(set(w))))
    print("  franchissements de l'Ilse : %d  %s" % (len(ponts), sorted(ponts)))
    print("\n→ %s" % CIBLE)
    print("=" * 62)
    con.close()


if __name__ == "__main__":
    main()
