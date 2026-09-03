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

import math
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
# 🔄 MONTÉ AVEC LA CRUE le 2026-08-21 (3,10 → 4,50) : l'auteur veut la rive
# gauche RASÉE, et le décrochement se mesure à la crue, pas dans l'absolu. À
# 3,10 sous une crue de 4,40 le front de quai buvait, et « la ville regarde »
# devenait « la ville aussi ».
BERGE_DROITE_M = 4.50

# 🔄 REPRIS le 2026-08-21 (3,00 → 4,40 → 3,80) : à 4,40, les 106
# ruines effaçaient le tissu du faubourg. À 3,80, ruines et bâtiments encore
# debout se partagent les îlots touchés : la crue frappe sans raser le lieu.
NIVEAU_OUVERTURE_M = 3.80       # la crue qui a eu lieu — l'état de départ
NIVEAU_ANNONCE_M = 6.00         # celle qu'on annonce — c'est elle qui fait `alea`

# Les paliers de dégât, en mètres d'eau AU PIED du bâtiment.
# 🔴 2,60 m n'est pas un réglage libre : c'est la hauteur sous plafond d'un
# rez-de-chaussée. Au-dessus, l'eau a chargé le plancher de l'étage et la
# structure ne se répare plus — c'est ce qui sépare « on ravale » de « on rase ».
SEUIL_RUINE = 2.60
SEUIL_SINISTRE = 0.85           # l'eau passe le seuil de la porte : RDC à refaire
SEUIL_MOUILLE = 0.10

# 🌊 CE QU'UNE BAISSE DU NIVEAU ANNONCÉ RACHÈTE (question 24). Rendre une
# rive au fleuve élargit la section : le niveau de la prochaine crue baisse, et
# c'est la SEULE façon qu'a une berge de changer autre chose que la caisse.
# Combien de mètres une berge achète est du level design et se règle dans
# `ville.gd` ; ici on exporte la COURBE, parce qu'elle se mesure bâtiment par
# bâtiment et que Godot n'a pas le profil de terrain.
BAISSES_M = tuple(0.25 * k for k in range(11))   # 0 à 2,50 m

# 🎚️ LES PONTS. Level design pur : la liste se corrige à la main, jamais par
# un calcul. Trois franchissements restent après 30c (145, 168, 169).
# 🔄 LES TROIS SONT COUPÉS depuis le 2026-08-21, demande de l'auteur : la rive
# gauche n'est plus accessible du tout. Avant, 168 seul l'était et 169 tenait —
# le faubourg restait joignable, donc la crue ne coûtait rien de structurel.
# ⚠️ Ça contredit frontalement 30c (`le faubourg garde un accès qui n'est pas
# le quai`) : c'est le prix à payer pour que « rendre à l'eau » soit l'option
# qui ÉCONOMISE trois ponts au lieu d'un caprice. Rétablir un accès ne coûte
# qu'une ligne ici — mettre 169 en `fragile` rend le faubourg piéton.
# --- LE PRIX DE LA RÉPARATION --------------------------------------------
# 🎚️ LEVEL DESIGN PUR, et c'est une PROPOSITION : ces trois nombres décident
# si « rendre à l'eau » est un choix ou une évidence. Ils se corrigent à la
# main, comme les listes de `fid` de `02`.
#
# Le repère qui les tient : la caisse part à 800 k€, la dotation vaut 360 k€/an,
# donc ~7 700 k€ sur les vingt ans du jeu — et équiper toute la ville en solaire
# en coûte 11 000. Tout remettre en état DOIT rester hors de portée ; un îlot,
# non. Le tableau imprimé plus bas dit où on en est à chaque relance.
PRIX_RECONSTRUCTION_EUR_M2 = 220.0   # par m² de plancher ruiné (emprise × niveaux)
PRIX_REMISE_EN_ETAT_EUR_M2 = 60.0    # par m² de plancher SINISTRÉ : le rez à refaire
PRIX_DEBLAIEMENT_EUR_M2 = 14.0       # la vase enlevée d'une rue, par m² de voirie
PRIX_PONT_EUR_M2 = 3500.0            # un tablier neuf, par m² de tablier

# Les trois franchissements qui restent apres 30c. Ecrits ici pour que le
# controle d'acces sache dire « il en reste un » : `02` en a la liste, elle
# ne remonte pas jusqu'ici.
FRANCHISSEMENTS = (145, 168, 169)

PONTS_CASSES = {
    145: "coupe",      # tablier emporté — infranchissable
    168: "coupe",      # celui du faubourg : les 279 logements n'ont plus d'accès
    169: "coupe",      # tablier emporté — infranchissable
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
    return segs, max(ys), min(ys), u, anneaux


def _dedans(anneau, p):
    """Lancer de rayon. Sert à mesurer la PORTÉE d'un pont : la longueur de son
    axe qui passe au-dessus de l'eau, et c'est elle qui fait le prix du tablier.
    """
    x, y = p
    dedans = False
    n = len(anneau)
    for i in range(n):
        ax, ay = anneau[i]
        bx, by = anneau[(i + 1) % n]
        if (ay > y) != (by > y) and \
                x < (bx - ax) * (y - ay) / (by - ay) + ax:
            dedans = not dedans
    return dedans


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
    segs, ynord, ysud, aval, eaux = _riviere(cur)

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
                      "h_annonce": h_a,
                      "h_max": hauteur_eau(d["d"], d["fil"], d["rive"],
                                           NIVEAU_OUVERTURE_M),
                      "part_ruinee": 0.0, "part_ruinee_apres": 0.0,
                      "ruine_apres_baisse": [0.0] * len(BAISSES_M),
                      "part_sinistree": 0.0, "log_sinistres": 0})
            continue
        d["h_max"] = max(b["h"] for b in d["bats"])
        d["part_ruinee"] = sum(b["surf"] for b in d["bats"]
                               if b["etat"] == "ruine") / stot
        touche = sum(b["surf"] for b in d["bats"]
                     if b["etat"] in ("ruine", "sinistre")) / stot
        d["part_sinistree"] = touche
        # Les logements sinistrés se DÉDUISENT de la surface touchée au sol, et
        # non du plancher : `logements` sort du plancher depuis le 2026-09-03
        # (04d), mais un étage noyé ruine tout ce qui est au-dessus de lui.
        d["log_sinistres"] = int(round(d["log"] * touche))
        # Ce que la PROCHAINE emporterait si on remettait tout à l'identique :
        # le nombre que « reconstruire » doit regarder en face.
        d["part_ruinee_apres"] = sum(b["surf"] for b in d["bats"]
                                     if b["h_annonce"] >= SEUIL_RUINE) / stot
        # La même part, sous une crue annoncée plus basse de tant de mètres :
        # c'est ce que la berge rendue au fleuve rachète, bâtiment par bâtiment.
        d["ruine_apres_baisse"] = [
            round(sum(b["surf"] for b in d["bats"]
                      if b["h_annonce"] - v >= SEUIL_RUINE) / stot, 3)
            for v in BAISSES_M]
        # La hauteur d'eau annoncée MOYENNE, pondérée par la surface : c'est le
        # numérateur d'`alea`, et Godot en a besoin en mètres pour lui retirer
        # la baisse. La déduire d'`alea` mentirait le jour où il saturerait à 1.
        d["h_annonce"] = sum(b["surf"] * b["h_annonce"] for b in d["bats"]) / stot
        d["alea"] = round(D4.borne(d["h_annonce"] / NIVEAU_ANNONCE_M), 3)

    # --- les rues -----------------------------------------------------------
    # 🌊 UNE RUE NOYÉE GARDE SON LIMON, et c'est elle qui DESSINE l'emprise de
    # la crue vue d'en haut : le bâti masque le sol, le réseau non. Sans ça la
    # crue ne se lisait que de trois quarts, sur les toits manquants.
    # ⚠️ UNE SEULE HAUTEUR PAR TRONÇON, prise à son milieu. Un tronçon qui
    # traverse la limite de l'emprise se salit donc en entier ou pas du tout.
    # Les rues du faubourg sont courtes, la marche ne se voit pas — sur une
    # radiale de 300 m, elle se verrait.
    rues = []
    largeurs = {}
    reseau = {}          # ce que `charge_reseau` attend, pour le report ci-dessous
    for fid, blob, larg, hier in cur.execute(
            "SELECT fid, geom, largeur_m, hierarchie FROM routes"):
        parts, _ = lire_wkb(gpkg_vers_wkb(blob))
        reseau[fid] = {"parts": parts, "hier": (hier or "").strip().lower(),
                       "largeur": larg or 0.0}
        pts = [p for pa in parts for p in pa]
        c = (sum(p[0] for p in pts) / len(pts),
             sum(p[1] for p in pts) / len(pts))
        d = min(D4.dist_pt_seg(c, a, b) for a, b in segs)
        f = D4.borne((ynord - c[1]) / (ynord - ysud))
        # La longueur du tronçon, et celle de la part qui passe AU-DESSUS DE
        # L'EAU : la première fait le prix du déblaiement, la seconde celui du
        # tablier. Aucune des deux n'est dans la table `routes`.
        longueur = portee = 0.0
        for pa in parts:
            for k in range(len(pa) - 1):
                a0, b0 = pa[k], pa[k + 1]
                L = math.hypot(b0[0] - a0[0], b0[1] - a0[1])
                longueur += L
                mil = ((a0[0] + b0[0]) / 2.0, (a0[1] + b0[1]) / 2.0)
                if any(_dedans(an, mil) for an in eaux):
                    portee += L
        largeurs[fid] = (larg or 0.0, longueur, portee)
        # La rive d'une rue n'est pas dans les données : on la déduit, par le
        # même test qu'en `04`. Un pont tombe d'un côté ou de l'autre selon son
        # milieu — sans conséquence, il porte déjà `etat_crue`.
        h = hauteur_eau(d, f, _rive_de(c, segs, aval), NIVEAU_OUVERTURE_M)
        rues.append((round(h, 2), fid))

    # --- CE QUE COÛTE LA RÉPARATION ------------------------------------
    # 🔴 UN PRIX PAR OBJET, SUR L'OBJET. C'est ce qui permet à la maquette de
    # poser trois décisions — un îlot, une rue, un pont — sans qu'une seule
    # ligne de GDScript ne connaisse la crue. Godot lit `cout_reparation_ke`
    # et l'affiche ; il ne le calcule jamais.
    niveaux = dict(cur.execute(
        "SELECT b.fid, p.niveaux FROM batiments b"
        " JOIN parcelles p ON p.fid = b.fid_parcelle"))
    for b in bats:
        b["plancher"] = b["surf"] * (niveaux.get(b["fid"]) or 1.0)
    for fid, d in ilots.items():
        sdp = sum(b["plancher"] for b in d["bats"] if b["etat"] == "ruine")
        # 🔴 UN SEUL PRIX POUR TOUT L'ÎLOT, et il couvre les deux états : on ne
        # reconstruit pas une maison en laissant sa voisine les pieds dans la
        # boue. C'est ce qui permet à « reconstruire » de rendre TOUS les
        # logements perdus, ruinés comme sinistrés.
        sdp_sin = sum(b["plancher"] for b in d["bats"]
                      if b["etat"] == "sinistre")
        d["n_ruines"] = sum(1 for b in d["bats"] if b["etat"] == "ruine")
        d["sdp_ruinee"] = sdp
        d["cout_ke"] = round((sdp * PRIX_RECONSTRUCTION_EUR_M2
                              + sdp_sin * PRIX_REMISE_EN_ETAT_EUR_M2)
                             / 1000.0, 1)
    couts_rue = {}
    for h, fid in rues:
        larg, longueur, portee = largeurs.get(fid, (0.0, 0.0, 0.0))
        if PONTS_CASSES.get(fid) == "coupe":
            # Un tablier neuf, sur la portée MESURÉE au-dessus de l'eau.
            couts_rue[fid] = round(portee * larg
                                   * PRIX_PONT_EUR_M2 / 1000.0, 1)
        elif h >= SEUIL_MOUILLE:
            couts_rue[fid] = round(longueur * larg
                                   * PRIX_DEBLAIEMENT_EUR_M2 / 1000.0, 1)

    # --- LE REPORT DE TRAFIC ------------------------------------------------
    # 🌉 Un pont emporté sort du GRAPHE, pas de la table : `routes` le garde,
    # avec sa géométrie et son prix de tablier. Seule la charge se réaffecte.
    # ⚠️ `04` a calculé la charge sur le réseau intact au passage précédent ;
    # c'est ici qu'elle devient vraie. Même dépendance à l'ordre de la chaîne
    # que `ilots.alea` — lancer `04` seul après `04e` la ramène à l'intact.
    # 🔴 L'AVANT SE RECALCULE, il ne se relit pas dans `routes.charge` : sinon
    # relancer `04e` seul comparerait l'après à lui-même et le report tomberait
    # à zéro sans rien dire. Une affectation de plus coûte quelques dixièmes.
    coupes = {f for f, v in PONTS_CASSES.items() if v == "coupe"}
    charge_avant, _intact = D4.charge_reseau(reseau)
    charge_apres, morceaux = D4.charge_reseau(reseau, coupes)
    trafic = {"avant": charge_avant, "apres": charge_apres,
              "morceaux": morceaux, "coupes": coupes}

    _compte_rendu(ilots, bats, rues, couts_rue, largeurs, trafic)
    if BLANC:
        print("\n--blanc : rien n'a ete ecrit.")
        return
    _ecrire(con, cur, ilots, bats, rues, couts_rue, trafic)
    print("\n[ok] ecrit dans %s" % os.path.relpath(GPKG, RACINE))


# ------------------------------------------------------------- le compte rendu

ORDRE = ("ruine", "sinistre", "mouille", "intact")


def _compte_rendu(ilots, bats, RUES, COUTS=None, LARGEURS=None, TRAFIC=None):
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

    # 🌊 CE QU'UNE BERGE RENDUE AU FLEUVE PEUT RACHETER. La courbe est
    # exportée îlot par îlot ; ce tableau en donne le total de ville, qui est
    # le seul repère pour régler le prix du mètre de rive dans `ville.gd`.
    print("\nSI LA CRUE ANNONCÉE BAISSAIT  (ce qu'une berge rendue au fleuve"
          " rachète)")
    # ⚠️ En bâtiments, pas en logements : `logements` a déjà été amputé des
    # sinistrés par le passage précédent, un compte de ville y tomberait à zéro.
    print("  baisse   bâtiments repris par la prochaine   épargnés")
    base_n = None
    for v in BAISSES_M:
        n = sum(1 for b in bats if b["h_annonce"] - v >= SEUIL_RUINE)
        if base_n is None:
            base_n = n
        print("  %4.2f m %30d %14d" % (v, n, base_n - n))

    print("\nLES RUES NOYÉES  (une hauteur par tronçon, prise à son milieu)")
    hs = [h for h, _ in RUES]
    print("  %d tronçons sur %d ont gardé du limon, jusqu'à %.2f m"
          % (sum(1 for h in hs if h >= SEUIL_MOUILLE), len(hs),
             max(hs or [0.0])))

    # 💶 CE QUE LA RÉPARATION COÛTE, ET C'EST LE TABLEAU QU'ON REGARDE POUR
    # RÉGLER LES TROIS PRIX. Le total DOIT dépasser ce que la ville gagne en
    # vingt ans, sinon reconstruire n'est pas un choix ; un îlot pris seul
    # DOIT rester payable, sinon il n'y a pas de décision du tout.
    if COUTS is not None:
        print("\nLE PRIX DE LA RÉPARATION  (%.0f €/m² de plancher ·"
              " %.0f €/m² de rue · %.0f €/m² de tablier)"
              % (PRIX_RECONSTRUCTION_EUR_M2, PRIX_DEBLAIEMENT_EUR_M2,
                 PRIX_PONT_EUR_M2))
        print("  fid  ce qu'on répare              ruines   plancher     k€")
        tot_i = 0.0
        for fid, d in sorted(ilots.items(), key=lambda t: -t[1]["cout_ke"]):
            if d["cout_ke"] <= 0.0:
                continue
            tot_i += d["cout_ke"]
            print("  %3d  reconstruire %-16s %5d %8.0f m² %7.0f"
                  % (fid, d["st"], d["n_ruines"], d["sdp_ruinee"],
                     d["cout_ke"]))
        tot_p = sum(v for f, v in COUTS.items()
                    if PONTS_CASSES.get(f) == "coupe")
        tot_r = sum(COUTS.values()) - tot_p
        for f in sorted(FRANCHISSEMENTS):
            if f in COUTS and PONTS_CASSES.get(f) == "coupe":
                larg, _, portee = (LARGEURS or {}).get(f, (0.0, 0.0, 0.0))
                print("  %3d  rebâtir le tablier          %5.0f m × %.0f m     %7.0f" % (f, portee, larg, COUTS[f]))
        print("  %-50s %7.0f" % ("déblayer les rues envasées", tot_r))
        print("  %-50s %7.0f" % ("TOUT réparer", tot_i + tot_p + tot_r))
        print("       la ville dispose de ~7 700 k€ sur vingt ans"
              " (800 de caisse + 360/an) — donc %.1f× ce qu'elle a"
              % ((tot_i + tot_p + tot_r) / 7700.0))

    # 🌉 CE QU'ON DEMANDE À CE TABLEAU N'EST PLUS « quel pont est cassé »
    # mais « reste-t-il un accès » — c'est ça que l'auteur a tranché le
    # 2026-08-21. Le contrôle sort en clair pour qu'un `PONTS_CASSES`
    # retouché à la main dise tout de suite ce qu'il vient de rouvrir.
    print("\nLES FRANCHISSEMENTS")
    for fid in sorted(FRANCHISSEMENTS):
        print("  pont %3d  → %s" % (fid, PONTS_CASSES.get(fid, "intact")))
    passants = [f for f in FRANCHISSEMENTS if PONTS_CASSES.get(f) != "coupe"]
    log_g = sum(d["log"] for d in ilots.values() if d["rive"] == "gauche")
    if passants:
        print("  → la rive gauche RESTE ACCESSIBLE par %s"
              % ", ".join("le pont %d" % f for f in sorted(passants)))
    else:
        print("  → RIVE GAUCHE COUPÉE : aucun franchissement, %d logements"
              " sans accès routier" % log_g)
    print("  le réseau source reste entier ; Godot exclut les tronçons"
          " endommagés du trafic jusqu'à la fin de leur réparation.")
    # Deux trafics, deux questions : ici le report une fois pour toutes (23b),
    # dans Godot les rues cassées vidées puis rouvertes à la réparation.
    if not TRAFIC:
        return
    # 🚗 LE REPORT DE TRAFIC. Ce tableau répond à une seule question : est-ce
    # que couper le faubourg coûte quelque chose à la ville ? Si la colonne
    # « après » de la rive droite ne bouge pas, la réponse est non — et c'est
    # l'argument chiffré de la décision 23b.
    av, ap = TRAFIC["avant"], TRAFIC["apres"]
    mor = TRAFIC["morceaux"]
    print("\nLE REPORT DE TRAFIC  (la charge recalculée sans les ponts coupés)")
    if len(mor) > 1:
        print("  réseau en %d morceaux %s — VOULU : le faubourg est une île."
              % (len(mor), mor))
        print("  ⚠️ le contrôle de `04` dit encore « d'un seul tenant » : il"
              " parle du réseau intact, avant la crue.")
    else:
        print("  réseau d'un seul tenant (%d nœuds) : un accès subsiste."
              % (mor[0] if mor else 0))
    ecarts = sorted(av, key=lambda f: ap.get(f, 0.0) - av.get(f, 0.0))
    for titre, fs in (("CE QUE LA COUPURE VIDE", ecarts[:4]),
                      ("CE QUI ENCAISSE", list(reversed(ecarts[-4:])))):
        print("  %s" % titre)
        for f in fs:
            print("    tronçon %-4d  %.2f → %.2f   (%+.2f)"
                  % (f, av.get(f, 0.0), ap.get(f, 0.0),
                     ap.get(f, 0.0) - av.get(f, 0.0)))
    gain = max((ap.get(f, 0.0) - av.get(f, 0.0)) for f in av) if av else 0.0
    print("  → la rue qui encaisse le plus prend %+.2f de charge ;"
          " %d tronçons tombent à zéro, contre %d avant."
          % (gain, sum(1 for f in av if ap.get(f, 0.0) <= 0.001),
             sum(1 for f in av if av[f] <= 0.001)))


# ----------------------------------------------------------------- l'écriture

def _colonnes(cur, table, cols):
    """Idempotent : la chaîne se relance en boucle, `ALTER TABLE` ne le
    supporte pas deux fois."""
    vus = {r[1] for r in cur.execute('PRAGMA table_info("%s")' % table)}
    for nom, typ in cols:
        if nom not in vus:
            cur.execute('ALTER TABLE "%s" ADD COLUMN %s %s' % (table, nom, typ))


def _ecrire(con, cur, ilots, bats, rues, couts_rue, trafic):
    _colonnes(cur, "batiments", [("hauteur_eau", "REAL"),
                                 ("hauteur_eau_annoncee", "REAL"),
                                 ("etat_crue", "TEXT")])
    _colonnes(cur, "ilots", [("hauteur_eau_max", "REAL"),
                             ("hauteur_eau_annonce", "REAL"),
                             ("ruine_apres_baisse", "TEXT"),
                             ("part_ruinee", "REAL"),
                             ("part_ruinee_apres", "REAL"),
                             ("part_sinistree", "REAL"),
                             ("logements_sinistres", "INTEGER"),
                             ("batiments_ruines", "INTEGER"),
                             ("cout_reparation_ke", "REAL")])
    _colonnes(cur, "routes", [("etat_crue", "TEXT"),
                              ("hauteur_eau", "REAL"),
                              ("cout_reparation_ke", "REAL")])

    cur.executemany(
        "UPDATE batiments SET hauteur_eau=?, hauteur_eau_annoncee=?,"
        " etat_crue=? WHERE fid=?",
        [(round(b["h"], 2), round(b["h_annonce"], 2), b["etat"], b["fid"])
         for b in bats])
    # 🔴 LES LOGEMENTS SINISTRÉS SORTENT DU PARC. Sans ça l'îlot 66 annonçait
    # 71 logements alors que ses 21 bâtiments sont des murs sans toit, et la
    # ville consommait pour un faubourg évacué. `logements_sinistres` garde la
    # trace de ce qui a été retiré : c'est lui que « reconstruire » rend.
    # ⚠️ `04d` réécrit `logements` au passage précédent — cette soustraction
    # ne tient que parce que `chaine.py` fait passer 04e APRÈS.
    cur.executemany(
        "UPDATE ilots SET logements = MAX(0, logements - ?) WHERE fid=?",
        [(d["log_sinistres"], f) for f, d in ilots.items()
         if d["log_sinistres"]])
    cur.executemany(
        "UPDATE ilots SET alea=?, hauteur_eau_max=?, hauteur_eau_annonce=?,"
        " ruine_apres_baisse=?, part_ruinee=?,"
        " part_ruinee_apres=?, part_sinistree=?, logements_sinistres=?,"
        " batiments_ruines=?, cout_reparation_ke=? WHERE fid=?",
        [(d["alea"], round(d["h_max"], 2), round(d["h_annonce"], 3),
          ",".join("%.3f" % v for v in d["ruine_apres_baisse"]),
          round(d["part_ruinee"], 3),
          round(d["part_ruinee_apres"], 3), round(d["part_sinistree"], 3),
          d["log_sinistres"], d["n_ruines"], d["cout_ke"], f)
         for f, d in ilots.items()])
    # ⚠️ Même dépendance à l'ordre que `ilots.alea` juste au-dessus : `04`
    # écrit la charge du réseau intact, on la remplace par celle d'après.
    cur.executemany("UPDATE routes SET charge=? WHERE fid=?",
                    [(v, f) for f, v in trafic["apres"].items()])
    cur.execute("UPDATE routes SET etat_crue='intact', cout_reparation_ke=0")
    cur.executemany("UPDATE routes SET cout_reparation_ke=? WHERE fid=?",
                    [(v, f) for f, v in couts_rue.items()])
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
