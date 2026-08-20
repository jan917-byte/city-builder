# -*- coding: utf-8 -*-
"""tracer_chemins — proposer une venelle là où l'îlot est trop épais pour ses rues.

    python QGIS/scripts/tracer_chemins.py --blanc     mesure et affiche, n'écrit rien
    python QGIS/scripts/tracer_chemins.py             écrit la couche `chemins`
    python QGIS/scripts/tracer_chemins.py --tous      la mesure de TOUS les îlots
    python QGIS/scripts/tracer_chemins.py --refaire   écrase des chemins existants

🎚️ CE N'EST PAS UNE ÉTAPE DE LA CHAÎNE, c'est un outil : il propose un premier
tracé, l'auteur le corrige, et c'est le tracé corrigé qui compte. Le level
design ne se délègue pas — mais partir d'une page blanche sur soixante-dix
îlots, si.

🔴 IL ÉCRIT DANS LA SOURCE, ET C'EST VOULU : `02` rebâtit la carte de travail à
chaque passage, donc une couche posée là serait effacée sans prévenir. La
source est le seul endroit où un tracé corrigé à la main survit — une venelle
par ligne dans `chemins.geojson`, avec son `fid_ilot` et sa `largeur_m`.

⚠️ IL NE RÉÉCRIT PAS UNE COUCHE EXISTANTE sans `--refaire` : relancer après une
correction effacerait le travail.

═══════════════════════════════════════════════════════════════════════════
OÙ VA UN CHEMIN : AU PLI, ET NULLE PART AILLEURS
═══════════════════════════════════════════════════════════════════════════

Le peigne ne sait pas découper un îlot en L, parce qu'un L n'a pas de fond :
chaque aile est servie par la rue qui la longe, et le COUDE reste une masse que
personne ne réclame — elle ressort en parcelles en biseau, deux fois trop
profondes. Une venelle qui coupe le coude en travers donne un devant et un
derrière à chacune des deux ailes, et c'est tout ce qu'il manquait.

Le script cherche donc les PLIS : les sommets RENTRANTS de l'emprise, ceux où
le contour creuse au lieu de bomber. Depuis chaque pli il essaie les traversées
possibles, de la plus courte à la plus longue, et garde LA PREMIÈRE QUI PASSE
les trois contrôles ci-dessous. La plus courte, parce qu'une venelle courte
coupe un coude quand une venelle longue traverse un îlot — ce n'est plus la
même chose, et ça ne se voit que sur l'image.

Les trois contrôles, dans l'ordre où ils s'appliquent :
  ① le tracé ne mange pas plus de PERTE_COEUR_MAX d'un cœur d'îlot ;
  ② il coupe vraiment l'emprise en deux morceaux ;
  ③ il fait monter la RECTANGULARITÉ moyenne des parcelles d'au moins GAIN_MIN.

⚠️ CE QUI N'EST PAS UN CRITÈRE, et il a fallu se le faire dire : le NOMBRE de
maisons. Un premier jet refusait tout tracé qui en faisait perdre ; ça poussait
la venelle sur la diagonale longue du coude au lieu de couper le bras en
travers, donc ça dégradait la forme au nom d'un compte. Le compte est mesuré et
imprimé — il commande la surface de toit, donc le solaire — mais il ne décide
pas. Ce qu'on cherche est un parcellaire beau et crédible, qui facilite le
travail de la 3D ensuite.

⚠️ ET CE QUE LA MESURE NE VOIT PAS, pourquoi l'œil de l'auteur reste juge : un
îlot peut mériter une venelle sans avoir de pli, ou en avoir un qui ne mérite
rien. Les tissus à la boîte sont exclus d'office — la boîte ne connaît pas les
rues — et le reste se corrige à la main dans QGIS.
"""

import math
import os
import sqlite3
import sys
from importlib import import_module

ICI = os.path.dirname(os.path.abspath(__file__))
RACINE = os.path.dirname(os.path.dirname(ICI))
sys.path.insert(0, ICI)

import carte

D4C = import_module("04c_parcelles")     # la table TISSU, les largeurs, la géométrie

BLANC = "--blanc" in sys.argv
TOUS = "--tous" in sys.argv
REFAIRE = "--refaire" in sys.argv

_ARGS = [a for a in sys.argv[1:] if not a.startswith("--")]
CARTE = os.path.join(RACINE, "QGIS", "data", "travail", "wehrau.gpkg")
SOURCE = _ARGS[0] if _ARGS else carte.SOURCE   # un DOSSIER de .geojson
SRS = 25832

# ==========================================================================
# CE QUI SE RÈGLE
# ==========================================================================

# 🔴 REFUSÉ DEVANT L'IMAGE le 2026-08-14 : partir du POINT LE PLUS LOIN DE
# TOUTE RUE. Ça gagnait 61 maisons et coupait en deux la cour qu'on venait de
# se donner du mal à garder — le point le plus profond d'un îlot est son cœur.
#
# Ce que l'auteur a demandé, et qui se lit dans les trois réglages ci-dessous :
# le chemin va DANS LE COUDE ; un cœur d'îlot se préserve ; le chemin sert des
# parcelles PLUS RECTANGULAIRES, sinon il ne vaut pas son prix.

# ① LE COUDE : un sommet RENTRANT, donc le pli d'un L — le seul endroit d'où
# partir, puisqu'une corde qui part du pli donne un devant et un derrière à
# chaque aile.
# ⚠️ Sous le seuil ce n'est pas un pli mais le biseau que la limite de mitre de
# `04b` laisse partout sur les angles rentrants.
COUDE_MIN_DEG = 25.0

# ② LE CŒUR. Part de la surface de cœur d'îlot que la venelle a le droit de
# manger. Presque zéro : elle peut mordre un coin, pas traverser une cour.
PERTE_COEUR_MAX = 0.05

# ③ LA RECTANGULARITÉ : aire / aire du rectangle englobant, 1,00 pour un
# rectangle, 0,50 pour un triangle. Sous le seuil de gain, c'est du bruit de
# découpe, et on ne prend pas 200 m² de sol à la ville pour du bruit.
GAIN_MIN = 0.010

# Une corde plus courte que ça n'est pas une venelle, c'est une encoche ; plus
# longue que ça, ce n'est plus un coude mais une traversée d'îlot.
LONGUEUR_MIN = 12.0
LONGUEUR_MAX = 90.0


# ==========================================================================
# mécanique
# ==========================================================================

def dedans(anneau, p):
    """Point dans polygone, par lancer de rayon."""
    x, y = p
    n = len(anneau)
    ok = False
    for i in range(n):
        ax, ay = anneau[i]
        bx, by = anneau[(i + 1) % n]
        if (ay > y) != (by > y):
            t = (y - ay) / (by - ay)
            if x < ax + t * (bx - ax):
                ok = not ok
    return ok


def coudes(anneau):
    """Les sommets RENTRANTS de l'anneau — les plis. Renvoie [(indice, angle)].

    L'anneau sort de `D4C.ouvrir`, donc il est trigonométrique : le contour
    tourne à gauche sur un sommet convexe, à droite sur un sommet rentrant.
    C'est le signe du produit vectoriel qui le dit, et rien d'autre.

    ⚠️ On travaille sur l'anneau NETTOYÉ. Sans ça, deux sommets à trois
    millimètres l'un de l'autre — la découpe en fabrique — sortent en faux
    coude à 90°."""
    an = D4C.nettoyer(anneau)
    n = len(an)
    out = []
    for i in range(n):
        p, c, s = an[(i - 1) % n], an[i], an[(i + 1) % n]
        ax, ay = c[0] - p[0], c[1] - p[1]
        bx, by = s[0] - c[0], s[1] - c[1]
        na, nb = math.hypot(ax, ay), math.hypot(bx, by)
        if na < 1e-9 or nb < 1e-9:
            continue
        croix = ax * by - ay * bx
        if croix >= 0.0:
            continue                     # à gauche : sommet convexe, pas un pli
        cos = max(-1.0, min(1.0, (ax * bx + ay * by) / (na * nb)))
        tour = math.degrees(math.acos(cos))
        if tour >= COUDE_MIN_DEG:
            out.append((c, tour))
    return an, out


def sortie(anneau, p, u, depart=0.30):
    """Où le rayon parti de `p` dans la direction `u` quitte l'anneau.

    Renvoie la distance, ou None si le rayon part vers l'extérieur. Le `depart`
    écarte le point du sommet dont il sort : sans lui, les deux arêtes qui se
    rejoignent en `p` donnent une traversée à distance nulle et tout tombe à
    zéro."""
    q = (p[0] + u[0] * depart, p[1] + u[1] * depart)
    if not dedans(anneau, q):
        return None                      # cette direction sort du pli
    n = len(anneau)
    best = None
    nx, ny = -u[1], u[0]
    for i in range(n):
        a, b = anneau[i], anneau[(i + 1) % n]
        da = (a[0] - p[0]) * nx + (a[1] - p[1]) * ny
        db = (b[0] - p[0]) * nx + (b[1] - p[1]) * ny
        if (da > 0.0) == (db > 0.0):
            continue
        s = da / (da - db)
        t = ((a[0] + s * (b[0] - a[0]) - p[0]) * u[0]
             + (a[1] + s * (b[1] - a[1]) - p[1]) * u[1])
        if t > depart and (best is None or t < best):
            best = t
    return best


def cordes_du_coude(anneau, sommet):
    """Les traversées candidates qui partent d'un pli, de la plus courte à la
    plus longue.

    Balayage à deux degrés. Depuis un sommet rentrant, la plus courte est
    presque toujours la bonne — c'est celle qui coupe le pli au plus court,
    donc qui sépare les deux ailes du L. Mais pas toujours : on renvoie les
    candidates dans l'ordre et c'est la mesure de rectangularité, plus bas, qui
    tranche."""
    out = []
    for deg in range(0, 360, 2):
        a = math.radians(deg)
        u = (math.cos(a), math.sin(a))
        t = sortie(anneau, sommet, u)
        if t is None or not (LONGUEUR_MIN <= t <= LONGUEUR_MAX):
            continue
        out.append((t, u))
    out.sort(key=lambda x: x[0])
    # Deux directions voisines de deux degrés donnent la même venelle : on ne
    # garde que des candidates franchement différentes, sinon on paie huit
    # découpes complètes pour un dixième de degré.
    garde = []
    for t, u in out:
        if all(u[0] * v[0] + u[1] * v[1] < 0.94 for _, v in garde):
            garde.append((t, u))
        if len(garde) >= 4:
            break
    return garde


# 🔴 RETIRÉ LE 2026-08-14, NE PAS REMETTRE : la recherche des ÉTRANGLEMENTS,
# pour les îlots qui se rétrécissent sans sommet rentrant. Ses trois venelles
# (11, 39, 55) ont été refusées sur l'image — un col n'est pas un coude, un
# îlot qui s'affine a une pointe, et une venelle en travers ne dessert rien.


def prolonger(ilot, p, u, t):
    """La corde poussée jusqu'au bord de l'ÎLOT, des deux côtés.

    L'auteur dessine par-dessus la couche `ilots` dans QGIS : un trait qui
    s'arrête au bord de l'emprise aurait l'air de flotter au milieu de la rue.
    Et le débordement ne coûte rien — `04c` retire le couloir de l'emprise,
    donc ce qui dépasse tombe dans la voirie, qui n'est à personne."""
    arriere = sortie(ilot, p, (-u[0], -u[1])) or 0.0
    avant = sortie(ilot, (p[0] + u[0] * t, p[1] + u[1] * t), u) or 0.0
    return ((p[0] - u[0] * arriere, p[1] - u[1] * arriere),
            (p[0] + u[0] * (t + avant), p[1] + u[1] * (t + avant)))


# ---------------------------------------------------- juger un tracé candidat

def rectangularite(parcelles):
    """La moyenne, sur les parcelles à bâtir, du rapport aire / aire du
    rectangle englobant.

    1,00 pour un rectangle parfait, 0,50 pour un triangle. C'est LE nombre que
    l'auteur a demandé : « le chemin doit être au service de parcelles plus
    rectangulaires ; si ça empire, alors pas worth ». Les cœurs et les chemins
    en sont exclus — un cœur peut avoir n'importe quelle forme, c'est admis."""
    lot = [p for p, o, _ in parcelles if o not in ("coeur", "chemin")]
    if not lot:
        return 0.0
    tot = 0.0
    for p in lot:
        _, _, lg, ct, _ = D4C.rectangle_englobant(p)
        boite = lg * ct
        tot += abs(D4C.aire_signee(p)) / boite if boite > 1e-9 else 0.0
    return tot / len(lot)


def batissables(parcelles):
    """Combien de parcelles porteront une maison : ni cœur, ni chemin, et une
    façade sur le bord du morceau dont elles sortent."""
    return sum(1 for p, o, idx in parcelles
               if o not in ("coeur", "chemin") and D4C.facade_de(p, idx) > 0.5)


def coeur_perdu(coeurs, ligne, largeur):
    """La part de cœur d'îlot que ce couloir mangerait.

    On retire vraiment le couloir de chaque cœur et on compare les aires : pas
    d'approximation, pas d'échantillonnage. C'est la garantie que demande
    l'auteur — « surtout pas pour couper un centre d'îlot en deux »."""
    avant = sum(abs(D4C.aire_signee(c)) for c in coeurs)
    if avant <= 0.0:
        return 0.0
    apres = 0.0
    for c in coeurs:
        reste, _ = D4C.soustraire_chemin(c, ligne, largeur)
        apres += sum(abs(D4C.aire_signee(m)) for m in reste)
    return (avant - apres) / avant


# ------------------------------------------------------------------ encodage

# 🔄 `wkb_ligne` et `blob_gpkg` retirés le 2026-08-17 : `carte.py` écrit la
# source en texte. Ce script lit encore du GeoPackage (la carte de TRAVAIL,
# par `D4C`) mais n'en écrit plus.


# ---------------------------------------------------------------------- main

def lire():
    if not os.path.exists(CARTE):
        raise SystemExit("introuvable : %s — lancer 02 → 03 → 04 → 04b d'abord"
                         % CARTE)
    con = sqlite3.connect("file:%s?mode=ro" % CARTE.replace("\\", "/"), uri=True)
    ilots = {}
    for fid, st, geom in con.execute(
            "SELECT fid, sous_type, geom FROM ilots ORDER BY fid"):
        ilots[fid] = {"st": st,
                      "brut": D4C.ouvrir(D4C.lire_wkb(
                          D4C.gpkg_vers_wkb(geom))[0][0])}
    for fid, geom in con.execute("SELECT fid_ilot, geom FROM emprises"):
        if fid in ilots:
            ilots[fid]["ext"] = D4C.ouvrir(D4C.lire_wkb(
                D4C.gpkg_vers_wkb(geom))[0][0])
    # 🌾 Les bords sans rue, sinon les deux découpes d'essai ne seraient pas
    # celles que `04c` fera vraiment, et la comparaison ne prouverait rien.
    morts = D4C.lire_bords_morts(con, ilots)
    for fid, segs in morts.items():
        if fid in ilots:
            ilots[fid]["morts"] = segs
    con.close()
    return ilots


def main():
    ilots = lire()
    print("=" * 74)
    print("CHEMINS — proposition de tracé%s"
          % ("   (passe à blanc, rien n'est écrit)" if BLANC else ""))
    print("  carte lue : %s" % os.path.basename(CARTE))
    print("  couche écrite dans : %s" % os.path.basename(SOURCE))
    print()

    print("  LA RECHERCHE — un candidat par pli d'îlot, jugé sur la")
    print("  rectangularité des parcelles qu'il produit.")
    print("     · le tracé part d'un PLI — un sommet rentrant de plus de"
          " %.0f°" % COUDE_MIN_DEG)
    print("     · à pli donné, on prend LA PLUS COURTE traversée qui passe")
    print("     · il est refusé s'il mange plus de %.0f %% d'un cœur d'îlot"
          % (100 * PERTE_COEUR_MAX))
    print("     · il est refusé si la rectangularité ne monte pas de %.3f"
          % GAIN_MIN)
    print("     · le nombre de maisons est imprimé, pas exigé : la forme")
    print("       commande, le compte se constate")
    print()
    print("  %-5s %-20s %6s %8s %8s %9s %7s"
          % ("îlot", "sous_type", "pli", "rect. av", "rect. ap", "maisons",
             "verdict"))
    print("  " + "-" * 72)

    traces = []
    refuses = {"pas de pli": 0, "cœur entamé": 0, "ne coupe pas": 0,
               "pas plus rectangulaire": 0, "lisière": 0}
    for fid in sorted(ilots):
        d = ilots[fid]
        st = d["st"]
        if "ext" not in d or st not in D4C.TISSU:
            continue
        if D4C.TISSU[st][2] != "peigne":
            continue                     # la boîte ne connaît pas les rues
        # 🌾 PAS DE VENELLE DANS UN ÎLOT DE LISIÈRE (2026-08-17). La
        # rectangularité montait pour de bon sur les rubans 72 et 73, mais elle
        # montait parce que la venelle ouvre une deuxième façade et retourne
        # des parcelles dos à la route — l'inverse d'un ruban. Le critère juge
        # des formes, pas des orientations.
        if d.get("morts"):
            refuses["lisière"] += 1
            continue
        ext = d["ext"]
        an, plis = coudes(ext)
        # Les PLIS d'abord, parce que c'est là que l'auteur les met, puis les
        # ÉTRANGLEMENTS.
        candidats = []
        for sommet, tour in plis:
            for t, u in cordes_du_coude(an, sommet):
                candidats.append((sommet, u, t, tour))
        # 🔴 DU PLUS COURT AU PLUS LONG, PREMIER QUI PASSE — l'ordre EST la
        # règle. Les propositions triées par gain partaient en biais pour un
        # centième de rectangularité : une venelle courte coupe le coude, une
        # venelle longue traverse l'îlot.
        candidats.sort(key=lambda c: c[2])
        if not candidats:
            refuses["pas de pli"] += 1
            if TOUS:
                print("  %-5d %-20s %6d %8s %8s %9s   —" % (fid, st, 0, "", "",
                                                            ""))
            continue

        # La découpe SANS chemin : la référence à battre.
        morts = d.get("morts", ())
        base, cr0 = D4C.decouper_ilot(ext, st, (), morts)
        r0 = rectangularite(base)
        n0 = batissables(base)
        coeurs0 = [p for p, o, _ in base if o == "coeur"]

        larg = D4C.LARGEUR_CHEMIN.get(st, D4C.LARGEUR_CHEMIN_DEFAUT)
        meilleur = None
        motif = "pas plus rectangulaire"
        for sommet, u, t, genre in candidats:
            ligne = [sommet, (sommet[0] + u[0] * t, sommet[1] + u[1] * t)]
            if coeur_perdu(coeurs0, ligne, larg) > PERTE_COEUR_MAX:
                motif = "cœur entamé"
                continue
            essai, cr = D4C.decouper_ilot(ext, st, [(ligne, larg)], morts)
            if len(cr["morceaux"]) < 2:
                motif = "ne coupe pas"
                continue
            r1 = rectangularite(essai)
            n1 = batissables(essai)
            # ⚠️ LE NOMBRE DE MAISONS N'EST PAS UN CRITÈRE. Refuser tout tracé
            # qui en fait perdre poussait la venelle sur la DIAGONALE du coude
            # au lieu du travers. Mesuré et imprimé quand même : il commande la
            # surface de toit, donc le solaire.
            if r1 < r0 + GAIN_MIN:
                continue
            meilleur = {"r1": r1, "n1": n1, "u": u, "t": t,
                        "sommet": sommet, "genre": genre,
                        "aire": sum(abs(D4C.aire_signee(c))
                                    for c in cr["couloirs"])}
            break                        # le plus court qui passe : c'est lui
        if meilleur is None:
            refuses[motif] = refuses.get(motif, 0) + 1
            if TOUS:
                print("  %-5d %-20s %6d %8.3f %8s %9d   %s"
                      % (fid, st, len(candidats), r0, "—", n0, motif))
            continue

        seg = prolonger(d["brut"], meilleur["sommet"], meilleur["u"],
                        meilleur["t"])
        traces.append({"fid": fid, "st": st, "seg": seg, "larg": larg,
                       "L": meilleur["t"], "aire": meilleur["aire"],
                       "r0": r0, "r1": meilleur["r1"], "n0": n0,
                       "n1": meilleur["n1"], "genre": meilleur["genre"]})
        print("  %-5d %-20s %5.0f° %8.3f %8.3f %5d → %-3d ✅ +%.3f"
              % (fid, st, meilleur["genre"], r0, meilleur["r1"], n0,
                 meilleur["n1"], meilleur["r1"] - r0))
    print("  " + "-" * 72)
    print("     %d chemin(s) retenu(s). Refusés : %s"
          % (len(traces), " · ".join("%s %d" % (k, v)
                                     for k, v in refuses.items() if v)))
    if not TOUS:
        print("     (`--tous` pour voir aussi les îlots refusés, un par ligne)")
    print()

    aire_tot = sum(t["aire"] for t in traces)
    if traces:
        print("  CE QUE ÇA COÛTE ET CE QUE ÇA RAPPORTE")
        print("  %-5s %-20s %9s %9s %9s %10s"
              % ("îlot", "sous_type", "longueur", "largeur", "surface",
                 "maisons"))
        print("  " + "-" * 70)
        for t in traces:
            (x0, y0), (x1, y1) = t["seg"]
            print("  %-5d %-20s %7.0f m %7.1f m %7.0f m² %6d → %-3d"
                  % (t["fid"], t["st"], math.hypot(x1 - x0, y1 - y0),
                     t["larg"], t["aire"], t["n0"], t["n1"]))
        print("  " + "-" * 70)
        print("     %.0f m² pris à la ville, %d maisons gagnées"
              % (aire_tot, sum(t["n1"] - t["n0"] for t in traces)))
        print()
    print("     LES LARGEURS, ET CE QUI LES FAIT VARIER (3 à 5 m) :")
    for st, w in sorted(D4C.LARGEUR_CHEMIN.items(), key=lambda kv: kv[1]):
        n = sum(1 for t in traces if t["st"] == st)
        print("       %-20s %.1f m   %s"
              % (st, w, "%d chemin(s)" % n if n else "—"))
    print()

    if BLANC:
        print("  (passe à blanc — la couche `chemins` n'a pas été écrite)")
        print("=" * 74)
        return
    if not traces:
        print("  rien à écrire.")
        print("=" * 74)
        return
    ecrire(traces)
    print()
    print("  CE QU'IL FAUT FAIRE MAINTENANT, DANS L'ORDRE :")
    print("   1. regarder l'aperçu : python QGIS/scripts/apercu_parcelles.py")
    print("   2. ouvrir `chemins.geojson` dans un éditeur de texte — une")
    print("      venelle par ligne, avec son numéro d'îlot en clair")
    print("   3. supprimer les lignes qui tombent mal, régler `largeur_m`")
    print("      entre 3 et 5 m — c'est du level design")
    print("   4. relancer : python QGIS/scripts/chaine.py")
    print("=" * 74)


def ecrire(traces):
    # Le garde-fou du `--refaire` compte double maintenant que le fichier est
    # éditable à la main : ce que ce script écraserait, c'est du level design.
    if os.path.exists(carte.chemin_couche("chemins", SOURCE)) and not REFAIRE:
        raise SystemExit(
            "`chemins.geojson` existe déjà dans %s — il contient peut-être"
            " des tracés corrigés à la main.\n"
            "   `--refaire` pour l'écraser quand même." % SOURCE)

    n = carte.ecrire_couche("chemins", [
        {"fid": i + 1, "parts": [list(t["seg"])], "multi": False,
         "fid_ilot": t["fid"], "largeur_m": round(t["larg"], 1),
         "note": "propose par tracer_chemins.py - a corriger a la main"}
        for i, t in enumerate(traces)], SOURCE)
    print("→ %d venelles dans %s"
          % (n, carte.chemin_couche("chemins", SOURCE)))


if __name__ == "__main__":
    for flux in (sys.stdout, sys.stderr):
        try:
            flux.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, OSError):
            pass
    main()
