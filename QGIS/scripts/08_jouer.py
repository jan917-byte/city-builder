#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
08 — Jouer le classeur : 60 mois, une décision à la fois.

    python3 QGIS/scripts/08_jouer.py                 # joue Classeur/chantiers.csv
    python3 QGIS/scripts/08_jouer.py --toutes        # joue Classeur/parties/*.csv
    python3 QGIS/scripts/08_jouer.py --partie=emprise

Lit les feuilles de `Classeur/`, applique les chantiers mois par mois, écrit
les 60 lignes de `partie.csv` (ou `Classeur/parties/<nom>_resultat.csv`) et
produit `QGIS/rendus/parties.html` : la carte à n'importe quel mois, l'écart au
mois 0, et les courbes des parties superposées.

N'écrit RIEN dans le GeoPackage : il n'y est lu que la géométrie, en `ro`.

Ce que fait ce script, et que le tableur ne fait pas
----------------------------------------------------
La quantité d'une décision se calcule sur l'état du mois où le chantier
commence, pas sur l'état de départ. C'est tout le mécanisme de D06 : elle
ajoute 2,5 m d'emprise libre, et D07/D08 n'ont de cible que par elle.

Trois liens n'existaient dans aucune table et sont construits ici
-----------------------------------------------------------------
1. tronçon → îlots riverains. `adjacences.csv` est îlot↔îlot ; sans ce lien,
   `D07;voisins;ilots;canopee` ne retombe nulle part et la spécificité
   spatiale disparaît. Construit géométriquement, avec le critère de 04b
   (milieu d'arête à moins de 30 cm d'un segment, et parallèle).
2. tronçon → tronçons voisins, par sommet partagé. C'est le support du report
   de charge de D05.
3. aval d'une décision de voirie : les îlots dont `position_fil_eau` dépasse
   celui du plus aval des riverains de la cible.

Trois choix de lecture, à confirmer par l'auteur
-------------------------------------------------
- Pour une décision sur `routes`, `portee = cible` et `portee = voisins` avec
  `couche = ilots` désignent le MÊME ensemble : les îlots riverains. Les deux
  mots existent dans effets.csv, ils ne produisent pas deux anneaux.
- `set` est converti en écart au moment où le chantier commence. Deux `set`
  qui se chevauchent : le second part de l'état réellement atteint.
- Une variable absente des données (`confort_ete`) est créée à 0 et signalée.
  Ce qu'on lit alors est un gain cumulé, pas un niveau.
"""

import csv
import json
import math
import os
import re
import sqlite3
import sys

ICI = os.path.dirname(os.path.abspath(__file__))
RACINE = os.path.dirname(os.path.dirname(ICI))
sys.path.insert(0, ICI)

from apercu_carte import gpkg_vers_wkb, lire_wkb  # noqa: E402

GPKG = os.path.join(RACINE, "QGIS", "data", "Prototype_qualifie.gpkg")
CLASSEUR = os.path.join(RACINE, "Classeur")
PARTIES = os.path.join(CLASSEUR, "parties")
SORTIE_HTML = os.path.join(RACINE, "QGIS", "rendus", "parties.html")
SEP = ";"

MOIS = 60
HORIZON = MOIS + 240                   # au-delà de la partie : les chantiers en cours
ANNEE_0 = 2026
BUDGET_MENSUEL = 100.0 / 12.0          # 100 pts par an — README du classeur §2
CAPITAL_DEPART = 50.0                  # décision 16b

# Mêmes tolérances que 04b : on veut rater bruyamment, pas de peu.
TOL_ROUTE = 0.30
COS_MIN = 0.85
GRILLE = 25.0
CLE = 0.25

# Bornes de bon sens. Une part reste une part ; un stock ne devient pas négatif.
RATIOS = {"impermeabilise", "canopee", "riverain", "desserte_tc",
          "charge", "confort_ete", "position_fil_eau"}
POSITIFS = {"logements", "emplois", "stationnement", "hauteur", "densite",
            "emprise_libre_m", "largeur_m", "surface_m2"}

# Les colonnes de partie.csv, dans l'ordre du fichier existant.
COLS_PARTIE = [
    "mois", "annee", "evenement", "budget_verse", "budget_engage",
    "budget_solde", "capital", "logements", "logements_a_reloger",
    "canopee_moy", "impermeabilise_moy",
    "charge_max", "stationnement", "riverain_moy", "note",
]


def borne(var, v):
    if var in RATIOS:
        return min(1.0, max(0.0, v))
    if var in POSITIFS:
        return max(0.0, v)
    return v


# ------------------------------------------------------------------ lecture

def lire_csv(nom, dossier=None):
    chemin = os.path.join(dossier or CLASSEUR, nom)
    if not os.path.exists(chemin):
        sys.exit("Introuvable : %s" % chemin)
    with open(chemin, encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f, delimiter=SEP))


def nombre(s):
    """Une cellule de CSV vers un float quand c'en est un, sinon la chaîne."""
    if s is None or s == "":
        return None
    try:
        return float(s)
    except ValueError:
        return s


def charger_objets():
    """ilots.csv et routes.csv vers {fid: {champ: valeur}}."""
    def conv(lignes):
        out = {}
        for l in lignes:
            o = {}
            for k, v in l.items():
                o[k] = nombre(v)
            fid = int(o["fid"])
            o["fid"] = fid
            out[fid] = o
        return out
    return conv(lire_csv("ilots.csv")), conv(lire_csv("routes.csv"))


def charger_adjacences():
    """{fid: [(voisin, permeabilite), ...]} — le graphe îlot↔îlot de 03."""
    adj = {}
    for l in lire_csv("adjacences.csv"):
        a, b = int(l["id_a"]), int(l["id_b"])
        p = float(l["permeabilite"])
        adj.setdefault(a, []).append((b, p))
        adj.setdefault(b, []).append((a, p))
    return adj


# ------------------------------------------------------- les liens manquants

def geometrie():
    """Les anneaux des îlots et les segments de route, lus en lecture seule."""
    if not os.path.exists(GPKG):
        sys.exit("Introuvable : %s — lancer 02 → 03 → 04 d'abord." % GPKG)
    con = sqlite3.connect("file:%s?mode=ro" % GPKG, uri=True)
    ilots = {}
    for fid, geom in con.execute("SELECT fid, geom FROM ilots ORDER BY fid"):
        anneaux, _ = lire_wkb(gpkg_vers_wkb(geom))
        ilots[fid] = anneaux
    routes = {}
    for fid, geom in con.execute("SELECT fid, geom FROM routes ORDER BY fid"):
        routes[fid] = lire_wkb(gpkg_vers_wkb(geom))[0]
    con.close()
    return ilots, routes


def dist_pt_seg(p, a, b):
    px, py = p
    ax, ay = a
    bx, by = b
    dx, dy = bx - ax, by - ay
    L2 = dx * dx + dy * dy
    if L2 < 1e-18:
        return math.hypot(px - ax, py - ay)
    t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / L2))
    return math.hypot(px - (ax + t * dx), py - (ay + t * dy))


def lier_routes_ilots(geo_i, geo_r):
    """{route fid: set(îlot fids)} — le lien qui n'existe dans aucune table.

    Le critère est celui de 04b : le milieu d'une arête d'îlot doit être à
    moins de 30 cm d'un segment du tronçon, et parallèle à lui. L'écart réel
    mesuré par 04b était de 0,0000 m — les axes de rue tombent exactement sur
    les bords d'îlot."""
    segs = []
    for fid, parts in geo_r.items():
        for part in parts:
            for a, b in zip(part, part[1:]):
                if math.hypot(b[0] - a[0], b[1] - a[1]) > 1e-9:
                    segs.append((a, b, fid))
    idx = {}
    for k, (a, b, _) in enumerate(segs):
        for cx in range(int(min(a[0], b[0]) // GRILLE),
                        int(max(a[0], b[0]) // GRILLE) + 1):
            for cy in range(int(min(a[1], b[1]) // GRILLE),
                            int(max(a[1], b[1]) // GRILLE) + 1):
                idx.setdefault((cx, cy), []).append(k)

    r2i, i2r = {}, {}
    for fid, anneaux in geo_i.items():
        ext = list(anneaux[0])
        while len(ext) > 1 and ext[0] == ext[-1]:
            ext.pop()
        for i in range(len(ext)):
            a, b = ext[i], ext[(i + 1) % len(ext)]
            dx, dy = b[0] - a[0], b[1] - a[1]
            L = math.hypot(dx, dy)
            if L < 1e-9:
                continue
            ux, uy = dx / L, dy / L
            mx, my = (a[0] + b[0]) / 2.0, (a[1] + b[1]) / 2.0
            cx, cy = int(mx // GRILLE), int(my // GRILLE)
            best, best_d = None, TOL_ROUTE
            for ix in (cx - 1, cx, cx + 1):
                for iy in (cy - 1, cy, cy + 1):
                    for k in idx.get((ix, iy), ()):
                        sa, sb, rfid = segs[k]
                        sdx, sdy = sb[0] - sa[0], sb[1] - sa[1]
                        sl = math.hypot(sdx, sdy)
                        if sl < 1e-9:
                            continue
                        if abs((sdx / sl) * ux + (sdy / sl) * uy) < COS_MIN:
                            continue
                        d = dist_pt_seg((mx, my), sa, sb)
                        if d < best_d:
                            best, best_d = rfid, d
            if best is not None:
                r2i.setdefault(best, set()).add(fid)
                i2r.setdefault(fid, set()).add(best)
    return r2i, i2r


def voisins_routes(geo_r):
    """{route fid: set(route fids)} — deux tronçons voisins partagent un bout.

    Le support du report de charge de D05 : quand on ferme l'axe, la voiture
    va quelque part, et ce quelque part est nommé."""
    noeuds = {}
    for fid, parts in geo_r.items():
        for part in parts:
            for p in (part[0], part[-1]):
                k = (round(p[0] / CLE), round(p[1] / CLE))
                noeuds.setdefault(k, set()).add(fid)
    v = {}
    for fids in noeuds.values():
        for a in fids:
            v.setdefault(a, set()).update(f for f in fids if f != a)
    return v


# ---------------------------------------------------------------- les cibles

RE_EGAL = re.compile(r"(?<![<>=!])=(?!=)")


def compiler_cible(expr, nom_param):
    """La colonne `cible` de decisions.csv est du SQL. On la traduit une fois.

    Le paramètre (`A`, `S`) est un nom libre dans l'expression : il vient de la
    colonne `parametre`, et c'est lui qui fait qu'une même ligne coûte 42 ou
    115 points."""
    if not expr or not expr.strip():
        return lambda o, p: True
    py = RE_EGAL.sub("==", expr)
    py = re.sub(r"\bAND\b", " and ", py)
    py = re.sub(r"\bOR\b", " or ", py)
    py = re.sub(r"\bNOT\b", " not ", py)
    code = compile(py, "<cible>", "eval")

    def f(o, p):
        ns = dict(o)
        if nom_param:
            ns[nom_param] = p
        try:
            return bool(eval(code, {"__builtins__": {}}, ns))  # noqa: S307
        except NameError as e:
            raise SystemExit("cible « %s » : %s" % (expr, e))
    return f


# ------------------------------------------------------------------ le moteur

def avancement(t, d, L, M):
    """La rampe du README §4. Rien ne bouge pendant le délai, puis ça monte."""
    if t < d + L:
        return 0.0
    if M <= 0:
        return 1.0
    if t >= d + L + M:
        return 1.0
    return (t - d - L) / float(M)


class Partie(object):
    def __init__(self, nom, base_i, base_r, adj, r2i, i2r, rvois,
                 decisions, effets):
        self.nom = nom
        self.base = {"i": base_i, "r": base_r}
        self.adj, self.r2i, self.i2r, self.rvois = adj, r2i, i2r, rvois
        self.decisions = decisions
        self.effets = effets
        self.apps = []                 # les rampes, envoyées telles quelles au HTML
        # Les tableaux dépassent l'horizon : un chantier lancé au mois 48 avec
        # 24 mois de rampe se paie jusqu'au mois 72. Le tronquer à 60 rendrait
        # gratuite la moitié d'une décision tardive.
        self.paiements = [0.0] * (HORIZON + 1)
        self.capital_evt = [0.0] * (HORIZON + 1)
        self.ville = {"logements_a_reloger": [0.0] * (HORIZON + 1)}
        self.journal = []
        self.inconnues = set()
        self.fermes = []               # (decision_id, set(fids), couche)

    # -- lecture de l'état ------------------------------------------------
    def etat(self, couche, t):
        """L'état d'une couche au mois t : la base plus toutes les rampes."""
        out = {}
        for fid, o in self.base[couche].items():
            out[fid] = dict(o)
        for a in self.apps:
            if a["c"] != couche:
                continue
            av = avancement(t, a["d"], a["L"], a["M"])
            if av <= 0.0:
                continue
            for fid, val in a["v"].items():
                o = out.get(fid)
                if o is not None:
                    o[a["k"]] = borne(a["k"], (o.get(a["k"]) or 0.0) + val * av)
        return out

    def solde(self, t, extra=None):
        verse = BUDGET_MENSUEL * (t + 1)
        paye = sum(self.paiements[:t + 1])
        if extra:
            paye += sum(extra[:t + 1])
        return verse - paye

    # -- jouer un chantier ------------------------------------------------
    def jouer(self, mois, did, param, note):
        D = self.decisions.get(did)
        if D is None:
            self.journal.append((mois, did, "refusé", "décision inconnue", 0, 0, 0))
            return
        couche = "i" if D["couche"] == "ilots" else "r"
        p = float(param) if param not in (None, "") else (
            float(D["defaut"]) if D["defaut"] else None)
        etat = self.etat(couche, mois)
        test = compiler_cible(D["cible"], D["parametre"] or None)
        cibles = [o for o in etat.values() if test(o, p)]
        fids = set(int(o["fid"]) for o in cibles)

        q = self.quantite(D, cibles)
        cout = float(D["cout_base_pts"]) + float(D["cout_unitaire_pts"]) * q
        cap = float(D["capital_base"]) + float(D["capital_unitaire"]) * q
        L, M = int(D["delai_mois"]), int(D["montee_mois"])

        refus = self.refuser(D, mois, fids, cout, L, M)
        if refus:
            self.journal.append((mois, did, "refusé", refus, q, cout, cap))
            return

        etale = max(1, L + M)
        for t in range(mois, mois + etale):
            self.paiements[t] += cout / etale
        self.capital_evt[mois] += cap
        for id_ferme in re.findall(r"D\d\d", D["ferme"] or ""):
            self.fermes.append((id_ferme, fids, couche))

        self.appliquer(D, mois, fids, couche, q, etat, L, M)
        fin = mois + L + M
        note = note or D["nom"]
        if fin > MOIS:
            note += "  ⚠ plein effet au mois %d, après la fin de la partie" % fin
        self.journal.append((mois, did, "pris", note, q, cout, cap))

    def quantite(self, D, cibles):
        u = D["unite"]
        if u == "logement":
            return sum(o.get("logements") or 0 for o in cibles)
        if u == "place":
            return sum(o.get("stationnement") or 0 for o in cibles)
        if u == "100ml":
            return sum(o.get("longueur_m") or 0 for o in cibles) / 100.0
        if u == "logement_cree":
            # 35 log/ha, la valeur du delta de densité de D09 dans effets.csv.
            return sum((o.get("surface_m2") or 0) / 1e4 for o in cibles) * 35.0
        raise SystemExit("unité inconnue : %s (décision %s)" % (u, D["id"]))

    def refuser(self, D, mois, fids, cout, L, M):
        c = (D["condition"] or "").strip()
        m = re.search(r"disponible au mois (\d+)", c)
        if m and mois < int(m.group(1)):
            return "pas disponible avant le mois %s" % m.group(1)
        m = re.search(r"au moins (\d+) logements? à reloger", c)
        if m and self.ville["logements_a_reloger"][mois] < int(m.group(1)):
            return "il faut %s logements à reloger, il y en a %d" % (
                m.group(1), self.ville["logements_a_reloger"][mois])
        if "emprise disponible" in c and not fids:
            return "aucune cible : l'emprise n'est pas libérée"
        if not fids:
            return "aucune cible"
        for id_ferme, autres, _ in self.fermes:
            if id_ferme == D["id"] and (fids & autres):
                return "fermée par une décision antérieure sur les mêmes objets"

        etale = max(1, L + M)
        extra = [0.0] * (HORIZON + 1)
        for t in range(mois, min(HORIZON, mois + etale - 1) + 1):
            extra[t] = cout / etale
        for t in range(mois, min(HORIZON, mois + etale - 1) + 1):
            if self.solde(t, extra) < -0.01:
                return ("budget : %.0f pts, le solde passe sous zéro au mois %d"
                        % (cout, t))
        return None

    # -- les effets -------------------------------------------------------
    def portee_fids(self, portee, couche_eff, couche_dec, fids, etat_i):
        """Qui reçoit l'effet. Retourne {fid: poids}."""
        if portee == "cible":
            if couche_eff == couche_dec:
                return {f: 1.0 for f in fids}
            if couche_dec == "r":                     # routes → îlots riverains
                return {i: 1.0 for f in fids for i in self.r2i.get(f, ())}
            return {r: 1.0 for f in fids for r in self.i2r.get(f, ())}

        if portee == "voisins":
            if couche_dec == "i" and couche_eff == "i":
                out = {}
                for f in fids:
                    for v, perm in self.adj.get(f, ()):
                        if v not in fids:
                            out[v] = max(out.get(v, 0.0), perm)
                return out
            if couche_dec == "r" and couche_eff == "r":
                out = {}
                for f in fids:
                    for v in self.rvois.get(f, ()):
                        if v not in fids:
                            out[v] = 1.0
                return out
            # routes → îlots : le même ensemble que `cible`. Voir l'en-tête.
            return self.portee_fids("cible", couche_eff, couche_dec, fids, etat_i)

        if portee == "aval":
            riverains = fids if couche_dec == "i" else set(
                i for f in fids for i in self.r2i.get(f, ()))
            seuils = [etat_i[i].get("position_fil_eau") or 0.0
                      for i in riverains if i in etat_i]
            if not seuils:
                return {}
            seuil = max(seuils)
            return {f: 1.0 for f, o in etat_i.items()
                    if (o.get("position_fil_eau") or 0.0) > seuil
                    and f not in riverains}
        return {}

    def appliquer(self, D, mois, fids, couche_dec, q, etat_dec, L, M):
        etat_i = etat_dec if couche_dec == "i" else self.etat("i", mois)
        etat_r = etat_dec if couche_dec == "r" else self.etat("r", mois)
        for e in self.effets:
            if e["decision_id"] != D["id"]:
                continue
            if e["couche"] == "partie":
                val = q if e["valeur"] == "=quantite" else (
                    -q if e["valeur"] == "-quantite" else float(e["valeur"]))
                for t in range(mois, HORIZON + 1):
                    self.ville[e["variable"]][t] += val * avancement(t, mois, L, M)
                continue

            ce = "i" if e["couche"] == "ilots" else "r"
            etat = etat_i if ce == "i" else etat_r
            cibles = self.portee_fids(e["portee"], ce, couche_dec, fids, etat_i)
            if not cibles:
                continue
            var = e["variable"]
            if var not in self.base[ce][next(iter(self.base[ce]))]:
                self.inconnues.add("%s.%s" % (e["couche"], var))
                for o in self.base[ce].values():
                    o[var] = 0.0
                for o in etat.values():
                    o.setdefault(var, 0.0)

            brut = e["valeur"]
            vals = {}
            for fid, poids in cibles.items():
                if fid not in etat:
                    continue
                actuel = etat[fid].get(var) or 0.0
                if brut == "=quantite":
                    cible_val = actuel + q
                elif brut == "-quantite":
                    cible_val = actuel - q
                else:
                    v = float(brut)
                    if e["operation"] == "delta":
                        cible_val = actuel + v * poids
                    elif e["operation"] == "set":
                        cible_val = v
                    elif e["operation"] == "restaure":
                        cible_val = (self.base[ce][fid].get(var) or 0.0) * v
                    else:
                        raise SystemExit("opération inconnue : %s" % e["operation"])
                ecart = cible_val - actuel
                if abs(ecart) > 1e-12:
                    vals[fid] = ecart
            if vals:
                self.apps.append({"c": ce, "k": var, "d": mois, "L": L, "M": M,
                                  "v": vals, "id": D["id"], "p": e["portee"]})

    # -- la sortie --------------------------------------------------------
    def lignes(self):
        """Les 61 lignes de partie.csv, plus les séries pour les courbes."""
        evts = {int(m): (n or d) for m, d, s, n, q, c, k in
                [(j[0], j[1], j[2], j[3], j[4], j[5], j[6]) for j in self.journal]
                if s == "pris"}
        out, series = [], {}
        cap = CAPITAL_DEPART
        for t in range(MOIS + 1):
            cap += self.capital_evt[t]
            EI, ER = self.etat("i", t), self.etat("r", t)
            bati = [o for o in EI.values() if o["fonction"] != "riviere"]
            log = sum(o["logements"] for o in bati)
            habites = [o for o in bati if o["logements"] > 0]
            g = [o for o in bati if o["rive"] == "gauche"]
            avl = [o for o in bati if (o.get("position_fil_eau") or 0) > 0.5]
            moy = lambda s, ch: (sum(o.get(ch) or 0 for o in s) / len(s)) if s else 0.0
            # Moyennes SIMPLES par îlot, et `riverain` sur les seuls îlots
            # habités : ce sont les définitions qui reproduisent le mois 0 de
            # partie.csv. Elles traitent un champ de 50 ha comme un parc de
            # 0,4 ha — c'est un choix, pas un accident, et le contrôle de fin
            # de script est là pour qu'il reste conscient.
            pond = lambda ch: moy(bati, ch)
            r = {
                "mois": t, "annee": ANNEE_0 + t // 12,
                "evenement": evts.get(t, ""),
                "budget_verse": round(BUDGET_MENSUEL, 1),
                "budget_engage": round(self.paiements[t], 2),
                "budget_solde": round(self.solde(t), 1),
                "capital": round(cap, 1),
                "logements": int(round(log)),
                "logements_a_reloger": int(round(self.ville["logements_a_reloger"][t])),
                "canopee_moy": round(pond("canopee"), 3),
                "impermeabilise_moy": round(pond("impermeabilise"), 3),
                "charge_max": round(max(o.get("charge") or 0 for o in ER.values()), 3),
                "stationnement": int(round(sum(o.get("stationnement") or 0
                                               for o in ER.values()))),
                "riverain_moy": round(moy(habites, "riverain"), 3),
                "note": "",
                # Hors partie.csv : le seuil de dégradation nommé par
                # effets.csv (« au-delà de 0.80 la rue voisine se dégrade »).
                # `charge_max` sature à 1 et ne dit plus rien ; le NOMBRE de
                # tronçons au-dessus du seuil, si.
                "satures": sum(1 for o in ER.values()
                               if (o.get("charge") or 0) > 0.80),
            }
            out.append(r)
            for k, v in r.items():
                if isinstance(v, (int, float)) and k not in ("mois", "annee"):
                    series.setdefault(k, []).append(v)
        return out, series


# ------------------------------------------------------------------ écriture

def ecrire_partie(chemin, lignes):
    with open(chemin, "w", encoding="utf-8", newline="\n") as f:
        f.write(SEP.join(COLS_PARTIE) + "\n")
        for r in lignes:
            f.write(SEP.join(str(r[c]) for c in COLS_PARTIE) + "\n")


def rapport(p, lignes):
    print("\n" + "=" * 74)
    print("PARTIE — %s" % p.nom)
    print("=" * 74)
    print("  mois  décision  quantité      coût   capital   ")
    for mois, did, statut, note, q, cout, cap in p.journal:
        marque = "✅" if statut == "pris" else "⛔"
        print("  %s %3d  %-8s %9.0f %7.1f pts %+7.1f   %s"
              % (marque, mois, did, q, cout, cap, note))
    a, b = lignes[0], lignes[-1]
    print("\n  %-22s %10s %10s %10s" % ("", "mois 0", "mois 60", "écart"))
    for cle, lib, f in [
        ("capital", "Capital politique", "%.0f"),
        ("budget_solde", "Solde budgétaire", "%.0f"),
        ("canopee_moy", "Canopée moyenne", "%.3f"),
        ("impermeabilise_moy", "Sol imperméable", "%.3f"),
        ("stationnement", "Places sur rue", "%.0f"),
        ("satures", "Rues saturées >0,80", "%.0f"),
        ("charge_max", "Charge max", "%.2f"),
        ("riverain_moy", "Fragilité riverain", "%.3f"),
        ("logements", "Logements", "%.0f"),
    ]:
        d = b[cle] - a[cle]
        print("  %-22s %10s %10s %10s"
              % (lib, f % a[cle], f % b[cle],
                 ("%+" + f[1:]) % d if abs(d) > 1e-9 else "—"))


# ---------------------------------------------------------------------- HTML

def svg_carte(geo_i, geo_r):
    xs = [p[0] for a in geo_i.values() for r in a for p in r]
    ys = [p[1] for a in geo_i.values() for r in a for p in r]
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    W = 1000.0
    H = W * (y1 - y0) / (x1 - x0)
    k = W / (x1 - x0)
    T = lambda p: "%.1f,%.1f" % ((p[0] - x0) * k, H - (p[1] - y0) * k)
    out = ['<svg id="carte" viewBox="0 0 %.0f %.0f" xmlns="http://www.w3.org/2000/svg">' % (W, H)]
    out.append('<g id="gi">')
    for fid, anneaux in geo_i.items():
        d = " ".join("M" + " L".join(T(p) for p in a) + " Z" for a in anneaux)
        out.append('<path class="il" data-fid="%d" d="%s"/>' % (fid, d))
    out.append('</g><g id="gr">')
    for fid, parts in geo_r.items():
        for part in parts:
            out.append('<path class="ro" data-fid="%d" d="M%s"/>'
                       % (fid, " L".join(T(p) for p in part)))
    out.append("</g></svg>")
    return "\n".join(out)


CALQUES_I = [("canopee", "Canopée", ""), ("impermeabilise", "Imperméabilisé", ""),
             ("riverain", "Fragilité riverain", ""), ("confort_ete", "Confort d'été", ""),
             ("logements", "Logements", ""),
             ("hauteur", "Hauteur", " niv."), ("densite", "Densité", " log/ha")]
CALQUES_R = [("canopee", "Canopée d'alignement", ""), ("charge", "Charge de trafic", ""),
             ("stationnement", "Places sur rue", ""), ("emprise_libre_m", "Emprise libre", " m"),
             ("largeur_m", "Largeur", " m")]

COURBES = [("capital", "Capital politique"), ("budget_solde", "Solde budgétaire (pts)"),
           ("canopee_moy", "Canopée moyenne"), ("impermeabilise_moy", "Sol imperméable"),
           ("stationnement", "Places sur rue"), ("satures", "Rues saturées (>0,80)"),
           ("riverain_moy", "Fragilité riverain"), ("logements", "Logements")]

GABARIT = u"""<!doctype html>
<html lang="fr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Wehrau — les parties</title>
<style>
:root{--fd:#14161a;--pan:#1b1e24;--bd:#2c313a;--tx:#e6e8ec;--gr:#9aa2b1;--ac:#e8c46a;--vd:#2a2e36}
@media(prefers-color-scheme:light){:root{--fd:#f4f2ee;--pan:#fff;--bd:#dcd8d0;--tx:#1a1c20;--gr:#6d7480;--ac:#9a6b1f;--vd:#e8e4dc}}
*{box-sizing:border-box}
body{margin:0;background:var(--fd);color:var(--tx);
 font:14px/1.5 ui-sans-serif,system-ui,"Segoe UI",Roboto,sans-serif}
header{padding:20px 26px 14px;border-bottom:1px solid var(--bd)}
h1{margin:0;font-size:20px;font-weight:600;letter-spacing:-.01em}
h1 small{color:var(--gr);font-weight:400;font-size:14px;margin-left:10px}
.wrap{display:grid;grid-template-columns:minmax(0,1fr) 360px}
@media(max-width:980px){.wrap{grid-template-columns:1fr}}
.gauche{padding:16px 26px 40px;min-width:0}
aside{padding:16px 22px 40px;border-left:1px solid var(--bd)}
@media(max-width:980px){aside{border-left:0;border-top:1px solid var(--bd)}}
.onglets{display:flex;gap:6px;margin-bottom:12px;flex-wrap:wrap}
.onglets button{background:none;border:1px solid var(--bd);color:var(--gr);
 padding:6px 14px;border-radius:99px;cursor:pointer;font:inherit;font-size:13px}
.onglets button.on{background:var(--ac);border-color:var(--ac);color:var(--fd);font-weight:600}
.barre{display:flex;align-items:center;gap:14px;margin:0 0 12px;
 background:var(--pan);border:1px solid var(--bd);border-radius:8px;padding:10px 14px}
.barre input[type=range]{flex:1;accent-color:var(--ac)}
.barre .mois{font-variant-numeric:tabular-nums;font-weight:600;min-width:112px}
.barre .mois b{font-size:17px}
.calques{display:flex;flex-wrap:wrap;gap:5px;margin-bottom:10px;align-items:center}
.calques button{background:var(--vd);border:1px solid transparent;color:var(--tx);
 padding:4px 10px;border-radius:5px;cursor:pointer;font:inherit;font-size:12.5px}
.calques button:hover{border-color:var(--gr)}
.calques button.on{background:var(--ac);color:var(--fd);font-weight:600}
.calques .sep{width:1px;height:20px;background:var(--bd);margin:0 5px}
.calques button.ec{border-color:var(--gr)}
.calques button.ec.on{background:#c1443c;color:#fff;border-color:#c1443c}
svg#carte{width:100%;height:auto;display:block;background:var(--pan);
 border:1px solid var(--bd);border-radius:8px}
path.il{stroke:var(--fd);stroke-width:.9;cursor:pointer}
path.il:hover{stroke:var(--tx);stroke-width:2.4}
path.ro{fill:none;stroke-linecap:round;cursor:pointer}
path.ro:hover{stroke-width:6}
.legende{display:flex;align-items:center;gap:12px;flex-wrap:wrap;margin-top:10px;
 color:var(--gr);font-size:12.5px}
.rampe{height:11px;width:170px;border-radius:3px}
.bloc{margin-bottom:20px}
.bloc h2{margin:0 0 8px;font-size:11px;font-weight:700;letter-spacing:.09em;
 text-transform:uppercase;color:var(--ac)}
.st{display:flex;justify-content:space-between;align-items:baseline;gap:10px;
 padding:5px 0;border-bottom:1px solid var(--bd)}
.st:last-child{border-bottom:0}
.st .k{color:var(--gr);font-size:13px}
.st .v{font-weight:600;font-variant-numeric:tabular-nums;white-space:nowrap}
.st .e{font-size:12px;font-variant-numeric:tabular-nums;min-width:64px;text-align:right}
.up{color:#6fae5e}.dn{color:#c1443c}.nul{color:var(--gr)}
#fiche{background:var(--pan);border:1px solid var(--bd);border-radius:8px;
 padding:12px 14px;margin-bottom:18px;min-height:92px}
#fiche .t{font-weight:600;margin-bottom:7px}
#fiche .g{display:grid;grid-template-columns:auto auto auto;gap:2px 12px;font-size:12.5px}
#fiche .g div:nth-child(3n+1){color:var(--gr)}
#fiche .g div:nth-child(3n+2){text-align:right;font-variant-numeric:tabular-nums}
#fiche .g div:nth-child(3n+3){text-align:right;font-variant-numeric:tabular-nums;font-size:11.5px}
#fiche .vide{color:var(--gr);font-size:13px}
.jr{display:grid;grid-template-columns:38px 1fr;gap:3px 9px;font-size:12.5px;
 align-items:baseline}
.jr .m{color:var(--gr);font-variant-numeric:tabular-nums;text-align:right}
.jr .d b{font-weight:600}
.jr .d.no{color:#c1443c}
.jr .d small{color:var(--gr);display:block;font-size:11.5px;line-height:1.35}
#courbes{margin-top:22px}
#courbes svg{width:100%;height:auto;background:var(--pan);border:1px solid var(--bd);
 border-radius:8px}
.cleg{display:flex;gap:16px;flex-wrap:wrap;color:var(--gr);font-size:12.5px;margin:8px 0 0}
.cleg span i{display:inline-block;width:16px;height:3px;border-radius:2px;
 margin-right:6px;vertical-align:3px}
</style></head><body>
<header><h1>Wehrau — trois parties <small>@@SOUS@@</small></h1></header>
<div class="wrap">
<div class="gauche">
  <div class="onglets" id="ong"></div>
  <div class="barre">
    <span class="mois"><b id="lm">mois 0</b> <span id="la" style="color:var(--gr)"></span></span>
    <input type="range" id="sl" min="0" max="@@MOIS@@" value="0" step="1">
  </div>
  <div class="calques" id="cal"></div>
  @@SVG@@
  <div class="legende" id="leg"></div>
  <div id="courbes"></div>
  <div class="cleg" id="cleg"></div>
</div>
<aside>
  <div id="fiche"><div class="vide">Survole un îlot ou une rue.</div></div>
  <div class="bloc"><h2>La ville à ce mois</h2><div id="stats"></div></div>
  <div class="bloc"><h2>Le journal</h2><div class="jr" id="journal"></div></div>
</aside>
</div>
<script>
const I0=@@I0@@, R0=@@R0@@, P=@@P@@, CI=@@CI@@, CR=@@CR@@,
      EXT=@@EXT@@, COURBES=@@COURBES@@, MOIS=@@MOIS@@,
      RATIOS=@@RATIOS@@, POSITIFS=@@POSITIFS@@;
const COUL=['#e8c46a','#6fae5e','#6c9dd9','#c1443c'];
let ip=0, t=0, couche='i', champ='canopee', ecart=false;
const $=s=>document.querySelector(s), gi=$('#gi'), gr=$('#gr');
let EI={}, ER={};

function borne(k,v){
  if(RATIOS.includes(k))return Math.min(1,Math.max(0,v));
  if(POSITIFS.includes(k))return Math.max(0,v);
  return v;
}
function ramp(t,d,L,M){
  if(t<d+L)return 0; if(M<=0)return 1;
  if(t>=d+L+M)return 1; return (t-d-L)/M;
}
function etat(){
  EI={};ER={};
  for(const f in I0)EI[f]=Object.assign({},I0[f]);
  for(const f in R0)ER[f]=Object.assign({},R0[f]);
  if(ip>0)for(const a of P[ip-1].apps){
    const av=ramp(t,a.d,a.L,a.M); if(av<=0)continue;
    const T=a.c==='i'?EI:ER;
    for(const f in a.v){ if(T[f])T[f][a.k]=borne(a.k,(T[f][a.k]||0)+a.v[f]*av); }
  }
}
function coul(v,ext){
  if(v===null||v===undefined||isNaN(v))return 'var(--vd)';
  const s=[[42,74,110],[90,140,150],[214,190,110],[196,84,62]];
  const x=Math.max(0,Math.min(1,ext[1]>ext[0]?(v-ext[0])/(ext[1]-ext[0]):0))*(s.length-1);
  const j=Math.min(Math.floor(x),s.length-2), f=x-j;
  const m=k=>Math.round(s[j][k]+(s[j+1][k]-s[j][k])*f);
  return `rgb(${m(0)},${m(1)},${m(2)})`;
}
function coulEcart(v,amp){
  if(!amp||Math.abs(v)<1e-9)return 'var(--vd)';
  const u=Math.max(-1,Math.min(1,v/amp));
  // vert = ça monte, rouge = ça baisse. Le signe est l'information.
  const a=u>0?[111,174,94]:[193,68,60];
  const k=Math.abs(u);
  const b=[Math.round(42+(a[0]-42)*k),Math.round(46+(a[1]-46)*k),Math.round(54+(a[2]-54)*k)];
  return `rgb(${b[0]},${b[1]},${b[2]})`;
}
function ampEcart(){
  const D=couche==='i'?EI:ER, B=couche==='i'?I0:R0;
  let a=0; for(const f in D)a=Math.max(a,Math.abs((D[f][champ]||0)-(B[f][champ]||0)));
  return a;
}
function peindre(){
  etat();
  const amp=ecart?ampEcart():0;
  const ext=EXT[couche][champ]||[0,1];
  gi.querySelectorAll('path').forEach(p=>{
    const f=p.dataset.fid;
    if(couche==='i'){
      const v=EI[f][champ];
      p.setAttribute('fill',ecart?coulEcart(v-(I0[f][champ]||0),amp):coul(v,ext));
      p.setAttribute('opacity',1);
    }else{p.setAttribute('fill','var(--vd)');p.setAttribute('opacity',.5);}
  });
  gr.querySelectorAll('path').forEach(p=>{
    const f=p.dataset.fid;
    if(couche==='r'){
      const v=ER[f][champ];
      p.setAttribute('stroke',ecart?coulEcart(v-(R0[f][champ]||0),amp):coul(v,ext));
      p.setAttribute('stroke-width',3.4);
    }else{p.setAttribute('stroke','var(--fd)');p.setAttribute('stroke-width',1.1);}
  });
  legende(ext,amp); stats(); courbes();
}
function nb(v,u){
  if(v===null||v===undefined||v==='')return '—';
  if(typeof v!=='number')return v;
  const d=Math.abs(v)>=1000?0:Math.abs(v)>=10?1:3;
  return v.toLocaleString('fr-FR',{maximumFractionDigits:d})+(u||'');
}
function legende(ext,amp){
  const C=(couche==='i'?CI:CR).find(c=>c[0]===champ)||[champ,champ,''];
  if(ecart){
    const g=[-1,-.5,0,.5,1].map(k=>coulEcart(k*amp,amp)).join(',');
    $('#leg').innerHTML=`<span>${nb(-amp,C[2])}</span>`
      +`<span class="rampe" style="background:linear-gradient(90deg,${g})"></span>`
      +`<span>+${nb(amp,C[2])}</span><span style="opacity:.8">écart au mois 0 — ${C[1]}</span>`;
  }else{
    const g=[0,.25,.5,.75,1].map(k=>coul(ext[0]+k*(ext[1]-ext[0]),ext)).join(',');
    $('#leg').innerHTML=`<span>${nb(ext[0],C[2])}</span>`
      +`<span class="rampe" style="background:linear-gradient(90deg,${g})"></span>`
      +`<span>${nb(ext[1],C[2])}</span><span style="opacity:.8">${C[1]}</span>`;
  }
}
function stats(){
  const S=ip>0?P[ip-1].series:P[0].series0;
  $('#stats').innerHTML=COURBES.map(c=>{
    const v=S[c[0]][t], v0=S[c[0]][0], d=v-v0;
    const cl=Math.abs(d)<1e-9?'nul':(d>0?'up':'dn');
    return `<div class="st"><span class="k">${c[1]}</span>`
      +`<span class="v">${nb(v)}</span>`
      +`<span class="e ${cl}">${Math.abs(d)<1e-9?'—':(d>0?'+':'')+nb(d)}</span></div>`;
  }).join('');
}
function journal(){
  if(ip===0){$('#journal').innerHTML='<div></div><div class="d"><small>La ville '
    +'sans aucune décision. C\\'est la référence.</small></div>';return;}
  $('#journal').innerHTML=P[ip-1].journal.map(j=>{
    const ok=j[2]==='pris';
    return `<div class="m">${j[0]}</div><div class="d${ok?'':' no'}">`
      +`<b>${j[1]}</b> ${ok?`${j[5].toFixed(0)} pts · capital ${j[6]>0?'+':''}${j[6].toFixed(1)}`:'refusé'}`
      +`<small>${j[3]}</small></div>`;
  }).join('');
}
function courbes(){
  const W=1000,H=250,pl=46,pr=10,pt=16,pb=26,n=MOIS+1;
  const c=COURBES.find(x=>x[0]===CH_COURBE)||COURBES[0];
  const sers=P.map((p,k)=>({n:p.nom,c:COUL[k+1]||COUL[0],d:(k===0?p.series:p.series)}));
  const all=[P[0].series0[c[0]]].concat(P.map(p=>p.series[c[0]]));
  let lo=Math.min(...all.flat()), hi=Math.max(...all.flat());
  if(hi-lo<1e-9){hi=lo+1;}
  const pad=(hi-lo)*.08; lo-=pad; hi+=pad;
  const X=i=>pl+(W-pl-pr)*i/(n-1), Y=v=>pt+(H-pt-pb)*(1-(v-lo)/(hi-lo));
  let o=`<svg viewBox="0 0 ${W} ${H}" xmlns="http://www.w3.org/2000/svg">`;
  for(let k=0;k<=4;k++){const v=lo+(hi-lo)*k/4;
    o+=`<line x1="${pl}" y1="${Y(v).toFixed(1)}" x2="${W-pr}" y2="${Y(v).toFixed(1)}" stroke="var(--bd)" stroke-width="1"/>`
      +`<text x="${pl-7}" y="${(Y(v)+4).toFixed(1)}" fill="var(--gr)" font-size="12" text-anchor="end">${nb(v)}</text>`;}
  for(let a=0;a<=5;a++){const i=a*12; if(i>MOIS)break;
    o+=`<text x="${X(i).toFixed(1)}" y="${H-7}" fill="var(--gr)" font-size="12" text-anchor="middle">${2026+a}</text>`;}
  const ligne=(s,col,w,dash)=>`<path d="M${s.map((v,i)=>`${X(i).toFixed(1)},${Y(v).toFixed(1)}`).join(' L')}" fill="none" stroke="${col}" stroke-width="${w}"${dash?' stroke-dasharray="4 4"':''}/>`;
  o+=ligne(P[0].series0[c[0]],'var(--gr)',1.6,true);
  P.forEach((p,k)=>{o+=ligne(p.series[c[0]],COUL[k+1]||COUL[0],ip===k+1?2.8:1.6);});
  o+=`<line x1="${X(t).toFixed(1)}" y1="${pt}" x2="${X(t).toFixed(1)}" y2="${H-pb}" stroke="var(--ac)" stroke-width="1.5"/>`;
  if(ip>0)for(const j of P[ip-1].journal){ if(j[2]!=='pris')continue;
    o+=`<circle cx="${X(j[0]).toFixed(1)}" cy="${(H-pb).toFixed(1)}" r="3.5" fill="${COUL[ip]||COUL[0]}"/>`;}
  o+='</svg>';
  $('#courbes').innerHTML=o;
  $('#cleg').innerHTML='<span style="color:var(--tx);font-weight:600">'+c[1]+'</span>'
    +'<span><i style="background:var(--gr)"></i>sans décision</span>'
    +P.map((p,k)=>`<span><i style="background:${COUL[k+1]||COUL[0]}"></i>${p.nom}</span>`).join('')
    +'<span style="margin-left:auto">'+COURBES.map(x=>
      `<a href="#" data-c="${x[0]}" style="color:${x[0]===CH_COURBE?'var(--ac)':'var(--gr)'};margin-left:10px;text-decoration:none">${x[1]}</a>`).join('')+'</span>';
  $('#cleg').querySelectorAll('a').forEach(a=>a.onclick=e=>{
    e.preventDefault();CH_COURBE=a.dataset.c;courbes();});
}
let CH_COURBE='capital';
function boutons(){
  const C=couche==='i'?CI:CR;
  $('#cal').innerHTML=C.map(c=>`<button data-c="${c[0]}"${c[0]===champ?' class="on"':''}>${c[1]}</button>`).join('')
    +'<span class="sep"></span>'
    +`<button id="bi" class="${couche==='i'?'on':''}">Îlots</button>`
    +`<button id="br" class="${couche==='r'?'on':''}">Rues</button>`
    +'<span class="sep"></span>'
    +`<button id="be" class="ec${ecart?' on':''}">Écart au mois 0</button>`;
  $('#cal').querySelectorAll('button[data-c]').forEach(b=>b.onclick=()=>{
    champ=b.dataset.c;boutons();peindre();});
  $('#bi').onclick=()=>{couche='i';champ='canopee';boutons();peindre();};
  $('#br').onclick=()=>{couche='r';champ='canopee';boutons();peindre();};
  $('#be').onclick=()=>{ecart=!ecart;boutons();peindre();};
}
function fiche(fid,kind){
  const C=kind==='i'?CI:CR, D=kind==='i'?EI:ER, B=kind==='i'?I0:R0;
  const o=D[fid], b=B[fid];
  $('#fiche').innerHTML=`<div class="t">${kind==='i'?'Îlot':'Tronçon'} ${fid} — `
    +`${kind==='i'?o.sous_type:o.hierarchie}</div><div class="g">`
    +C.map(c=>{const d=(o[c[0]]||0)-(b[c[0]]||0);
      return `<div>${c[1]}</div><div>${nb(o[c[0]],c[2])}</div>`
        +`<div class="${Math.abs(d)<1e-9?'nul':(d>0?'up':'dn')}">`
        +`${Math.abs(d)<1e-9?'—':(d>0?'+':'')+nb(d)}</div>`;}).join('')+'</div>';
}
gi.querySelectorAll('path').forEach(p=>p.onmouseenter=()=>{if(couche==='i')fiche(p.dataset.fid,'i');});
gr.querySelectorAll('path').forEach(p=>p.onmouseenter=()=>{if(couche==='r')fiche(p.dataset.fid,'r');});
$('#ong').innerHTML=['Sans décision'].concat(P.map(p=>p.nom))
  .map((n,k)=>`<button data-p="${k}"${k===0?' class="on"':''}>${n}</button>`).join('');
$('#ong').querySelectorAll('button').forEach(b=>b.onclick=()=>{
  ip=+b.dataset.p;
  $('#ong').querySelectorAll('button').forEach(x=>x.classList.toggle('on',x===b));
  journal();peindre();});
$('#sl').oninput=e=>{t=+e.target.value;
  $('#lm').textContent='mois '+t;
  $('#la').textContent=(2026+Math.floor(t/12))+(t%12?' · '+(t%12)+' mois':'');
  peindre();};
boutons();journal();peindre();
</script></body></html>
"""


def construire_html(geo_i, geo_r, base_i, base_r, parties, ref):
    """`ref` = la partie vide : la ville sans aucune décision, en pointillé."""
    J = lambda o: json.dumps(o, ensure_ascii=False, separators=(",", ":"))

    def maigre(objs, calques):
        """On n'envoie au navigateur que ce qui sert à peindre ou à survoler."""
        cles = [c[0] for c in calques] + ["fid", "sous_type", "hierarchie",
                                          "fonction", "rive", "longueur_m",
                                          "surface_m2"]
        return {str(f): {k: o[k] for k in cles if k in o and o[k] is not None}
                for f, o in objs.items()}

    # Les échelles de couleur sont fixées sur l'ensemble des mois ET des
    # parties : sans ça, chaque déplacement du curseur recalculerait l'extrémum
    # et rien ne semblerait bouger.
    ext = {"i": {}, "r": {}}
    for couche, calques, base in (("i", CALQUES_I, base_i), ("r", CALQUES_R, base_r)):
        for champ, _, _ in calques:
            vals = [o[champ] for o in base.values()
                    if isinstance(o.get(champ), (int, float))]
            for p in parties:
                for a in p.apps:
                    if a["c"] == couche and a["k"] == champ:
                        for f, v in a["v"].items():
                            b = base[f].get(champ) or 0.0
                            vals.append(borne(champ, b + v))
            if vals:
                ext[couche][champ] = [min(vals), max(vals)]

    dp = []
    for p in parties:
        lignes, series = p.lignes()
        dp.append({
            "nom": p.nom,
            "apps": [{"c": a["c"], "k": a["k"], "d": a["d"], "L": a["L"],
                      "M": a["M"], "v": {str(f): round(v, 5)
                                         for f, v in a["v"].items()}}
                     for a in p.apps],
            "journal": [[m, d, s, n, round(q, 1), round(c, 1), round(k, 1)]
                        for m, d, s, n, q, c, k in p.journal],
            "series": {k: v for k, v in series.items()},
        })
    dp[0]["series0"] = ref
    for d in dp[1:]:
        d["series0"] = ref

    sous = "%d mois · %d parties · budget 100 pts/an · capital 50 au départ" % (
        MOIS, len(parties))
    page = GABARIT
    for cle, val in [
        ("SVG", svg_carte(geo_i, geo_r)), ("SOUS", sous), ("MOIS", str(MOIS)),
        ("I0", J(maigre(base_i, CALQUES_I))), ("R0", J(maigre(base_r, CALQUES_R))),
        ("P", J(dp)), ("CI", J(CALQUES_I)), ("CR", J(CALQUES_R)),
        ("EXT", J(ext)), ("COURBES", J(COURBES)),
        ("RATIOS", J(sorted(RATIOS))), ("POSITIFS", J(sorted(POSITIFS))),
    ]:
        page = page.replace("@@%s@@" % cle, val)
    return page


# ------------------------------------------------------------------- contrôle

def controle_mois_zero(lignes):
    """Le mois 0 calculé doit retrouver la ligne déjà écrite dans partie.csv.

    C'est le seul contrôle qui vaille : si l'état de départ ne se reproduit
    pas, tout ce qui suit est du bruit."""
    chemin = os.path.join(CLASSEUR, "partie.csv")
    if not os.path.exists(chemin):
        return
    ref = lire_csv("partie.csv")[0]
    print("\nCONTRÔLE — le mois 0 doit retrouver partie.csv")
    ok = True
    for c in ("logements", "canopee_moy", "impermeabilise_moy", "charge_max",
              "stationnement", "riverain_moy"):
        a, b = float(ref[c]), float(lignes[0][c])
        bon = abs(a - b) <= max(0.002, abs(a) * 0.01)
        ok = ok and bon
        print("  %-20s attendu %9s   calculé %9s   %s"
              % (c, ref[c], lignes[0][c], "✅" if bon else "❌"))
    if not ok:
        print("  ⚠️  Un écart ici veut dire que la définition d'un stock a bougé "
              "entre 06 et 08 — à regarder avant de lire les courbes.")


# ------------------------------------------------------------------------ main

def main():
    partiel = [a.split("=", 1)[1] for a in sys.argv[1:] if a.startswith("--partie=")]
    toutes = "--toutes" in sys.argv

    base_i, base_r = charger_objets()
    adj = charger_adjacences()
    decisions = {l["id"]: l for l in lire_csv("decisions.csv")}
    effets = lire_csv("effets.csv")

    print("Liens géométriques (absents des tables, construits ici)")
    geo_i, geo_r = geometrie()
    r2i, i2r = lier_routes_ilots(geo_i, geo_r)
    rvois = voisins_routes(geo_r)
    orphelines = [f for f in base_r if f not in r2i]
    print("  %d tronçons sur %d ont au moins un îlot riverain (%d orphelins)"
          % (len(r2i), len(base_r), len(orphelines)))
    print("  %d îlots sur %d bordent au moins un tronçon"
          % (len(i2r), len(base_i)))
    print("  %.1f îlots riverains par tronçon en moyenne"
          % (sum(len(v) for v in r2i.values()) / float(max(1, len(r2i)))))
    print("  %.1f tronçons voisins par tronçon" %
          (sum(len(v) for v in rvois.values()) / float(max(1, len(rvois)))))

    fichiers = []
    if toutes or partiel:
        os.makedirs(PARTIES, exist_ok=True)
        for f in sorted(os.listdir(PARTIES)):
            if f.endswith(".csv") and not f.endswith("_resultat.csv"):
                nom = f[:-4]
                if partiel and nom not in partiel:
                    continue
                fichiers.append((nom.replace("_", " "), os.path.join(PARTIES, f)))
        if not fichiers:
            sys.exit("Aucune partie dans %s" % PARTIES)
    else:
        fichiers = [("chantiers", os.path.join(CLASSEUR, "chantiers.csv"))]

    faites, inconnues = [], set()
    for nom, chemin in fichiers:
        p = Partie(nom, base_i, base_r, adj, r2i, i2r, rvois, decisions, effets)
        with open(chemin, encoding="utf-8", newline="") as f:
            for l in csv.DictReader(f, delimiter=SEP):
                p.jouer(int(l["mois_debut"]), l["decision_id"],
                        l["parametre"], l.get("note", ""))
        lignes, series = p.lignes()
        p._lignes, p._series = lignes, series
        inconnues |= p.inconnues
        cible = (chemin[:-4] + "_resultat.csv" if chemin.startswith(PARTIES)
                 else os.path.join(CLASSEUR, "partie.csv"))
        ecrire_partie(cible, lignes)
        rapport(p, lignes)
        print("\n  → %s" % os.path.relpath(cible, RACINE))
        faites.append(p)

    if inconnues:
        print("\n⚠️  VARIABLES ABSENTES DES DONNÉES, créées à 0 : %s"
              % ", ".join(sorted(inconnues)))
        print("   Ce qu'on lit dessus est un gain cumulé, pas un niveau. Soit on "
              "les dérive dans 04, soit la décision s'exprime autrement.")

    vide = Partie("sans décision", base_i, base_r, adj, r2i, i2r, rvois,
                  decisions, effets)
    lref, sref = vide.lignes()
    controle_mois_zero(lref)

    os.makedirs(os.path.dirname(SORTIE_HTML), exist_ok=True)
    page = construire_html(geo_i, geo_r, base_i, base_r, faites, sref)
    with open(SORTIE_HTML, "w", encoding="utf-8", newline="\n") as f:
        f.write(page)
    print("\nHTML   %.0f Ko  →  %s"
          % (len(page.encode("utf-8")) / 1024, os.path.relpath(SORTIE_HTML, RACINE)))


if __name__ == "__main__":
    main()
