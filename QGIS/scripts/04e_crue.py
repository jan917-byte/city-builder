#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
04e — LA CRUE : le terrain sous l'eau, les dégâts, les ponts coupés.

    python3 QGIS/scripts/04e_crue.py --blanc   # mesurer sans écrire
    python3 QGIS/scripts/04e_crue.py           # écrire dans la carte de travail

Décision 23b : le jeu s'ouvre sur une crue, elle frappe la RIVE GAUCHE — le
faubourg de 13 îlots, pas la ville — et une SECONDE CRUE est annoncée. C'est
l'annonce qui fait de « ne pas reconstruire » un calcul et non un sentiment.

🔄 RETOUR EN ARRIÈRE SIGNALÉ. La crue était sortie du prototype le 2026-08-12
(`alea` figé à 0, carte plate). Elle revient ici, et par un autre chemin :
l'ancien essai cherchait une PORTÉE en mètres et retombait sur la même carte de
risque que l'altitude — une portée n'est qu'une distance déguisée. Le modèle
ci-dessous met la HAUTEUR D'EAU EN MÈTRES au centre, et c'est elle qui distingue
une maison mouillée d'une maison perdue. La carte reste plate : le terrain de ce
fichier est un profil de calcul, aucune géométrie ne monte.

LE MODÈLE, EN QUATRE IDÉES

  1. Le sol s'élève quand on s'éloigne de l'eau — une pente, pas un MNT.
  2. La rive gauche est la PLAINE, la rive droite est la TERRASSE : deux pentes,
     et un décrochement à la rive droite. C'est ce décrochement, et rien d'autre,
     qui fait que la ville regarde le faubourg se noyer.
  3. La plaine s'élargit vers l'aval : la pente de rive gauche se couche avec
     `position_fil_eau`.
  4. UNE SEULE RÈGLE, DEUX NIVEAUX D'EAU. La crue d'ouverture est ce qui EST
     arrivé, la crue annoncée est ce qui PEUT arriver — donc `alea`. Le joueur
     lit les deux sur le même îlot : « il a pris 1,4 m, la prochaine en met 2,6 ».
"""

import os
import sqlite3
import sys
from importlib import import_module

ICI = os.path.dirname(os.path.abspath(__file__))
RACINE = os.path.dirname(os.path.dirname(ICI))
sys.path.insert(0, ICI)

from apercu_carte import gpkg_vers_wkb, lire_wkb  # noqa: E402

D4 = import_module("04_deriver_attributs")   # dist_pt_seg, centroide, borne

BLANC = "--blanc" in sys.argv
_ARGS = [a for a in sys.argv[1:] if not a.startswith("--")]
GPKG = _ARGS[0] if _ARGS else os.path.join(RACINE, "QGIS", "data",
                                           "travail", "wehrau.gpkg")


# --- LA TABLE ------------------------------------------------------------
# 🎚️ LEVEL DESIGN. Ces sept nombres décident qui est ruiné, qui est mouillé et
# qui regarde. Une ligne changée, on relance, on lit le tableau imprimé.

# Mètres de distance à l'eau pour 1 m de terrain gagné. Grand = plat = noyé.
PENTE_GAUCHE = (38.0, 72.0)     # amont → aval : la plaine s'élargit vers l'aval
PENTE_DROITE = 26.0             # la terrasse, la même du nord au sud

# 🔴 LE DÉCROCHEMENT DE LA RIVE DROITE, en mètres. C'est LUI qui tient la
# décision 23b : à 0, la crue d'ouverture mord la ville et le faubourg cesse
# d'être « le petit bout d'en face qu'on pourrait ne pas reconstruire ».
BERGE_DROITE_M = 3.10

NIVEAU_OUVERTURE_M = 3.00       # la crue qui a eu lieu — l'état de départ
NIVEAU_ANNONCE_M = 5.00         # celle qu'on annonce — c'est elle qui fait `alea`

# Les paliers de dégât, en mètres d'eau AU PIED du bâtiment.
# 🔴 2,60 m n'est pas un réglage libre : c'est la hauteur sous plafond d'un
# rez-de-chaussée. Au-dessus, l'eau a chargé le plancher de l'étage et la
# structure ne se répare plus — c'est ce qui sépare « on ravale » de « on rase ».
SEUIL_RUINE = 2.60
SEUIL_SINISTRE = 0.85           # l'eau passe le seuil de la porte : RDC à refaire
SEUIL_MOUILLE = 0.10

# 🎚️ LES PONTS. Level design pur : la liste se corrige à la main, jamais par
# un calcul. Trois franchissements restent après 30c (145, 168, 169).
# ⚠️ 168 est LE pont du faubourg — `02_qualifier.py` le dit intouchable, seul
# accès des 279 logements de rive gauche. Le couper est exactement pour ça : la
# crue prend au joueur la seule chose qui reliait le faubourg à la ville, et
# « rendre à l'eau » cesse d'être une lubie pour devenir l'option qui économise
# un pont. Rétablir 145 ou 169 à sa place ne coûte qu'une ligne ici.
PONTS_CASSES = {
    168: "coupe",      # tablier emporté — infranchissable
    169: "fragile",    # pile déchaussée — passe, mais ne tiendra pas la suivante
}


# ------------------------------------------------------------------ le terrain

def pente_gauche(fil):
    """Mètres parcourus pour 1 m de hauteur, à cette hauteur de rivière."""
    a, b = PENTE_GAUCHE
    return a + (b - a) * fil


def sol_m(dist_eau, fil, rive):
    """Altitude du terrain au-dessus de l'étiage, en mètres. La carte reste
    plate : ce profil ne sort JAMAIS d'ici vers la géométrie."""
    if rive == "gauche":
        return dist_eau / pente_gauche(fil)
    return BERGE_DROITE_M + dist_eau / PENTE_DROITE


def hauteur_eau(dist_eau, fil, rive, niveau):
    return max(0.0, niveau - sol_m(dist_eau, fil, rive))


def etat(h):
    if h >= SEUIL_RUINE:
        return "ruine"
    if h >= SEUIL_SINISTRE:
        return "sinistre"
    if h >= SEUIL_MOUILLE:
        return "mouille"
    return "intact"


# ------------------------------------------------------------------ la lecture

def _riviere(cur):
    """Les segments de berge, et les deux latitudes qui bornent le fil de l'eau.
    Même définition qu'en `04` — le fil est une HAUTEUR sur la carte, l'Ilse
    décrivant un S qu'aucun axe droit ne suit."""
    anneaux = []
    for (blob,) in cur.execute(
            "SELECT geom FROM ilots WHERE sous_type = 'riviere'"):
        anneaux += lire_wkb(gpkg_vers_wkb(blob))[0]
    if not anneaux:
        raise SystemExit("aucun îlot `riviere` : la crue n'a pas de source.")
    segs = [(a[i], a[i + 1]) for a in anneaux for i in range(len(a) - 1)]
    ys = [p[1] for a in anneaux for p in a]
    # L'axe principal de l'eau, orienté vers l'AVAL. Même calcul qu'en `04` :
    # sur un méandre, un axe global se tromperait de rive, mais c'est lui qui
    # sert à ORIENTER la berge locale, pas à décider seul.
    _, u = D4.axe_principal([p for a in anneaux for p in a])
    if u[1] > 0:
        u = (-u[0], -u[1])
    return segs, max(ys), min(ys), u


def _rive_de(p, segs, u):
    """« gauche » ou « droite », par la même règle que `04` : le segment de
    berge le plus proche, orienté vers l'aval, et de quel côté on tombe."""
    _, a, b = min(((D4.dist_pt_seg(p, a, b), a, b) for a, b in segs),
                  key=lambda t: t[0])
    vx, vy = b[0] - a[0], b[1] - a[1]
    if vx * u[0] + vy * u[1] < 0:
        vx, vy = -vx, -vy
    return "gauche" if vx * (p[1] - a[1]) - vy * (p[0] - a[0]) > 0 else "droite"


def main():
    if not os.path.exists(GPKG):
        raise SystemExit("introuvable : %s\nLancer la chaîne d'abord." % GPKG)
    con = sqlite3.connect(GPKG)
    cur = con.cursor()
    segs, ynord, ysud, aval = _riviere(cur)

    def mesurer(anneau):
        c = D4.centroide(anneau)
        d = min(D4.dist_pt_seg(c, a, b) for a, b in segs)
        return d, D4.borne((ynord - c[1]) / (ynord - ysud))

    ilots = {}
    for fid, blob, st, rive, log in cur.execute(
            "SELECT fid, geom, sous_type, rive, logements FROM ilots"):
        d, fil = mesurer(lire_wkb(gpkg_vers_wkb(blob))[0][0])
        ilots[fid] = {"st": st, "rive": rive or "droite", "log": log or 0,
                      "d": d, "fil": fil, "bats": []}

    bats = []
    for fid, blob, fid_i, surf in cur.execute(
            "SELECT fid, geom, fid_ilot, surface_m2 FROM batiments ORDER BY fid"):
        if fid_i not in ilots:
            continue
        d, fil = mesurer(lire_wkb(gpkg_vers_wkb(blob))[0][0])
        rive = ilots[fid_i]["rive"]
        h = hauteur_eau(d, fil, rive, NIVEAU_OUVERTURE_M)
        b = {"fid": fid, "ilot": fid_i, "surf": surf or 0.0, "h": h,
             "etat": etat(h),
             "h_annonce": hauteur_eau(d, fil, rive, NIVEAU_ANNONCE_M)}
        bats.append(b)
        ilots[fid_i]["bats"].append(b)

    # --- l'îlot : ce que la crue lui a pris, et ce que la suivante menace ----
    # 🔴 `alea` EST UN DÉGRADÉ, PAS UN DRAPEAU, et c'est la décision 53 qui
    # l'impose : un chiffre global n'existe que s'il a une carte, et une carte
    # où tout vaut 0 ou 1 n'apprend rien. D'où la définition retenue —
    # l'ENFONCEMENT SOUS LA CRUE ANNONCÉE, rapporté à son niveau. Le faubourg
    # sort haut sans saturer, le front de quai sort tiède, le reste sort à zéro.
    #
    # ⚠️ Un îlot sans bâtiment se mesure à son centroïde. Ce n'est pas un
    # bouche-trou : les quatre champs riverains sont l'expansion de crue, donc
    # exactement là où « rendre à l'eau » envoie l'eau. Les laisser à 0 dirait
    # le contraire de ce que la carte raconte.
    for fid, d in ilots.items():
        stot = sum(b["surf"] for b in d["bats"])
        d["surface_bati"] = stot
        if not stot:
            h_a = hauteur_eau(d["d"], d["fil"], d["rive"], NIVEAU_ANNONCE_M)
            d.update({"alea": round(D4.borne(h_a / NIVEAU_ANNONCE_M), 3),
                      "h_max": hauteur_eau(d["d"], d["fil"], d["rive"],
                                           NIVEAU_OUVERTURE_M),
                      "part_ruinee": 0.0, "part_ruinee_apres": 0.0,
                      "part_sinistree": 0.0, "log_sinistres": 0})
            continue
        d["h_max"] = max(b["h"] for b in d["bats"])
        d["part_ruinee"] = sum(b["surf"] for b in d["bats"]
                               if b["etat"] == "ruine") / stot
        touche = sum(b["surf"] for b in d["bats"]
                     if b["etat"] in ("ruine", "sinistre")) / stot
        d["part_sinistree"] = touche
        # 🔴 Les logements sinistrés se DÉDUISENT de la surface touchée : rien
        # ne relie encore `logements` à l'emprise bâtie (dette du prototype), et
        # inventer ici un second lien ferait diverger deux comptes du même parc.
        d["log_sinistres"] = int(round(d["log"] * touche))
        # Ce que la PROCHAINE emporterait si on remettait tout à l'identique :
        # le nombre que « reconstruire » doit regarder en face.
        d["part_ruinee_apres"] = sum(b["surf"] for b in d["bats"]
                                     if b["h_annonce"] >= SEUIL_RUINE) / stot
        d["alea"] = round(D4.borne(
            sum(b["surf"] * b["h_annonce"] for b in d["bats"])
            / stot / NIVEAU_ANNONCE_M), 3)

    # --- les rues -----------------------------------------------------------
    # 🌊 UNE RUE NOYÉE GARDE SON LIMON, et c'est elle qui DESSINE l'emprise de
    # la crue vue d'en haut : le bâti masque le sol, le réseau non. Sans ça la
    # crue ne se lisait que de trois quarts, sur les toits manquants.
    # ⚠️ UNE SEULE HAUTEUR PAR TRONÇON, prise à son milieu. Un tronçon qui
    # traverse la limite de l'emprise se salit donc en entier ou pas du tout.
    # Les rues du faubourg sont courtes, la marche ne se voit pas — sur une
    # radiale de 300 m, elle se verrait.
    rues = []
    for fid, blob in cur.execute("SELECT fid, geom FROM routes"):
        parts, _ = lire_wkb(gpkg_vers_wkb(blob))
        pts = [p for pa in parts for p in pa]
        c = (sum(p[0] for p in pts) / len(pts),
             sum(p[1] for p in pts) / len(pts))
        d = min(D4.dist_pt_seg(c, a, b) for a, b in segs)
        f = D4.borne((ynord - c[1]) / (ynord - ysud))
        # La rive d'une rue n'est pas dans les données : on la déduit, par le
        # même test qu'en `04`. Un pont tombe d'un côté ou de l'autre selon son
        # milieu — sans conséquence, il porte déjà `etat_crue`.
        h = hauteur_eau(d, f, _rive_de(c, segs, aval), NIVEAU_OUVERTURE_M)
        rues.append((round(h, 2), fid))

    _compte_rendu(ilots, bats, rues)
    if BLANC:
        print("\n--blanc : rien n'a ete ecrit.")
        return
    _ecrire(con, cur, ilots, bats, rues)
    print("\n[ok] ecrit dans %s" % os.path.relpath(GPKG, RACINE))


# ------------------------------------------------------------- le compte rendu

ORDRE = ("ruine", "sinistre", "mouille", "intact")


def _compte_rendu(ilots, bats, RUES):
    print("=" * 78)
    print("04e — LA CRUE  (ouverture %.2f m · annoncée %.2f m)"
          % (NIVEAU_OUVERTURE_M, NIVEAU_ANNONCE_M))
    print("=" * 78)

    par_rive = {}
    for b in bats:
        r = ilots[b["ilot"]]["rive"]
        par_rive.setdefault(r, {e: 0 for e in ORDRE})[b["etat"]] += 1
    print("\nBÂTIMENTS TOUCHÉS PAR LA CRUE D'OUVERTURE")
    print("  rive      ruine  sinistré  mouillé  intact")
    for r in sorted(par_rive):
        c = par_rive[r]
        print("  %-8s %5d %9d %8d %7d"
              % (r, c["ruine"], c["sinistre"], c["mouille"], c["intact"]))
    n_droite = sum(par_rive.get("droite", {}).get(e, 0)
                   for e in ("ruine", "sinistre"))
    if n_droite:
        print("  ⚠️ %d bâtiment(s) sinistré(s) EN RIVE DROITE — la décision 23b"
              " veut le faubourg SEUL. Remonter BERGE_DROITE_M." % n_droite)

    print("\nLE FAUBOURG, ÎLOT PAR ÎLOT")
    print("  fid  sous_type              log  bât   ruine sinis mouil intact"
          "   eau max  détruit  logts perdus   aléa  si on rebâtit")
    tot_log = 0
    for fid in sorted(ilots, key=lambda f: -ilots[f]["log"]):
        d = ilots[fid]
        if d["rive"] != "gauche" or not d["bats"]:
            continue
        c = {e: sum(1 for b in d["bats"] if b["etat"] == e) for e in ORDRE}
        tot_log += d["log_sinistres"]
        print("  %3d  %-20s %5d %4d  %6d %5d %5d %6d   %5.2f m   %4.0f %%"
              "          %4d   %5.2f   %4.0f %% perdus"
              % (fid, d["st"], d["log"], len(d["bats"]), c["ruine"],
                 c["sinistre"], c["mouille"], c["intact"], d["h_max"],
                 100 * d["part_ruinee"], d["log_sinistres"], d["alea"],
                 100 * d["part_ruinee_apres"]))
    print("  %-71s %4d" % ("TOTAL des logements sinistrés", tot_log))

    # `alea` moyen par rive — le vault annonce 0,75 / 0,43, mesurés le
    # 2026-08-11 par une méthode d'altitude qui n'existe plus. Le chiffre
    # ci-dessous est celui de la règle EN VIGUEUR ; c'est lui qui fait foi.
    print("\nALÉA — enfoncement moyen du bâti sous la crue annoncée, sur son niveau")
    for r in ("gauche", "droite"):
        v = [d["alea"] for d in ilots.values() if d["rive"] == r and d["bats"]]
        if v:
            print("  rive %-8s %2d îlots bâtis   aléa moyen %.2f"
                  "   (le vault annonçait %s)"
                  % (r, len(v), sum(v) / len(v),
                     "0,75" if r == "gauche" else "0,43"))

    print("\nLES RUES NOYÉES  (une hauteur par tronçon, prise à son milieu)")
    hs = [h for h, _ in RUES]
    print("  %d tronçons sur %d ont gardé du limon, jusqu'à %.2f m"
          % (sum(1 for h in hs if h >= SEUIL_MOUILLE), len(hs),
             max(hs or [0.0])))

    print("\nLES FRANCHISSEMENTS")
    for fid in sorted(PONTS_CASSES):
        print("  pont %3d  → %s" % (fid, PONTS_CASSES[fid]))
    print("  ⚠️ le réseau routier N'EST PAS retouché : un pont coupé reste dans"
          " `routes`.\n     Le report de trafic n'est pas modélisé — dette"
          " nommée dans Prototype/Crue.md.")


# ----------------------------------------------------------------- l'écriture

def _colonnes(cur, table, cols):
    """Idempotent : la chaîne se relance en boucle, `ALTER TABLE` ne le
    supporte pas deux fois."""
    vus = {r[1] for r in cur.execute('PRAGMA table_info("%s")' % table)}
    for nom, typ in cols:
        if nom not in vus:
            cur.execute('ALTER TABLE "%s" ADD COLUMN %s %s' % (table, nom, typ))


def _ecrire(con, cur, ilots, bats, rues):
    _colonnes(cur, "batiments", [("hauteur_eau", "REAL"),
                                 ("hauteur_eau_annoncee", "REAL"),
                                 ("etat_crue", "TEXT")])
    _colonnes(cur, "ilots", [("hauteur_eau_max", "REAL"),
                             ("part_ruinee", "REAL"),
                             ("part_ruinee_apres", "REAL"),
                             ("part_sinistree", "REAL"),
                             ("logements_sinistres", "INTEGER")])
    _colonnes(cur, "routes", [("etat_crue", "TEXT"),
                              ("hauteur_eau", "REAL")])

    cur.executemany(
        "UPDATE batiments SET hauteur_eau=?, hauteur_eau_annoncee=?,"
        " etat_crue=? WHERE fid=?",
        [(round(b["h"], 2), round(b["h_annonce"], 2), b["etat"], b["fid"])
         for b in bats])
    cur.executemany(
        "UPDATE ilots SET alea=?, hauteur_eau_max=?, part_ruinee=?,"
        " part_ruinee_apres=?, part_sinistree=?, logements_sinistres=?"
        " WHERE fid=?",
        [(d["alea"], round(d["h_max"], 2), round(d["part_ruinee"], 3),
          round(d["part_ruinee_apres"], 3), round(d["part_sinistree"], 3),
          d["log_sinistres"], f) for f, d in ilots.items()])
    cur.execute("UPDATE routes SET etat_crue='intact'")
    cur.executemany("UPDATE routes SET hauteur_eau=? WHERE fid=?", rues)
    cur.executemany("UPDATE routes SET etat_crue=? WHERE fid=?",
                    [(v, f) for f, v in PONTS_CASSES.items()])
    con.commit()


if __name__ == "__main__":
    for flux in (sys.stdout, sys.stderr):
        try:
            flux.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, OSError):
            pass
    main()
