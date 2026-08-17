# -*- coding: utf-8 -*-
"""
Étape 0 bis : poser des îlots de LISIÈRE le long des rues qui entourent la
ville — un ruban d'une seule parcelle de profondeur, taillé dans le champ.

    python 00b_ilots_lisiere.py --blanc         ← calcule et affiche, n'écrit rien
    python 00b_ilots_lisiere.py                 ← écrit dans QGIS/data/source/
    python 00b_ilots_lisiere.py autre/dossier   ← sur une copie de la source

⚠️ C'est le deuxième script qui écrit dans la SOURCE, avec `00` et
`tracer_chemins`. La passe `--blanc` d'abord, toujours. En revanche il n'y a
plus rien à committer avant : depuis le 2026-08-17 la source est du TEXTE
(`carte.py`), donc `git diff` montre les îlots touchés et `git checkout`
défait la passe. Le filet est devenu ordinaire.
`02` rebâtit la carte de travail depuis la source, donc un îlot ajouté
ailleurs que dans la source ne survit pas au `02` suivant.

═══════════════════════════════════════════════════════════════════════════
CE QUE ÇA FABRIQUE, ET POURQUOI CE N'EST PAS UN ÎLOT ORDINAIRE
═══════════════════════════════════════════════════════════════════════════

Wehrau n'a pas de rocade. Ce qui « entoure la ville », c'est la chaîne de
rues qui fait la limite entre le bâti et les champs : 2 795 m, mesurés sur
`adjacences` le 2026-08-16. Un îlot de lisière se pose de l'AUTRE côté de
cette rue, sur le champ, qui perd exactement ce que le ruban gagne.

🔴 CE QUI GARANTIT « UNE SEULE PARCELLE EN PROFONDEUR », ET C'EST GÉOMÉTRIQUE,
   PAS UN RÉGLAGE. Le ruban n'a de rue que sur UN côté — son fond donne sur
   le champ, et aucune rue nouvelle n'est créée. Le peigne de `04c` ne peut
   donc prendre qu'une seule bande, celle de la rue de devant ; il n'y a
   personne en face pour en prendre une deuxième. La profondeur du polygone
   fixe le reste : à 28 m bâtis (la consigne `pavillonnaire`), la bande
   remplit tout le fond et il ne reste rien derrière.
   → Corollaire : si un jour quelqu'un trace une rue au fond d'un ruban, il
     y aura deux rangées le lendemain. C'est le seul moyen de casser ça.

LE PRIX À PAYER, ET IL EST VOULU : le fond du ruban touche le champ sans
rue entre les deux. Ce sont les PREMIÈRES frontières `sans_rue` de la carte
(`03` en comptait zéro). Ce n'est pas une anomalie — c'est un fond de jardin
sur un champ, ce qui est exactement ce qu'on voulait dessiner.

═══════════════════════════════════════════════════════════════════════════
LA MÉTHODE — de la chirurgie d'anneau, pas un booléen
═══════════════════════════════════════════════════════════════════════════

Aucune bibliothèque géométrique ici (comme partout dans ce dossier : `sqlite3`
et `struct`, rien d'autre). On n'a pas besoin d'une différence de polygones,
parce que le ruban se découpe le long de la frontière EXISTANTE :

  · la frontière champ↔îlot bâti est une suite de sommets p0…pn que les deux
    polygones portent à l'identique (polygonisation d'une même couche ligne) ;
  · on la décale vers l'intérieur du champ, ce qui donne p0'…pn' ;
  · le RUBAN  = p0…pn puis pn'…p0'   (aller par la rue, retour par le fond) ;
  · le CHAMP  = son anneau, où le morceau p0→pn est remplacé par
                p0 → p0' → p1' … pn' → pn.

Les deux polygones partagent alors exactement les arêtes p0-p0', le fond, et
pn'-pn : la partition est exacte par construction, comme celle de `04c`. Le
contrôle qui le prouve est imprimé — aire(champ neuf) + aire(ruban) doit
valoir aire(champ ancien) à moins d'un m².
"""

import math
import os
import sys

import carte

for flux in (sys.stdout, sys.stderr):
    try:
        flux.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, OSError):
        pass

ICI = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(os.path.dirname(ICI), "data")
SRS = 25832

BLANC = "--blanc" in sys.argv
_ARGS = [a for a in sys.argv[1:] if not a.startswith("--")]
SOURCE = _ARGS[0] if _ARGS else carte.SOURCE   # un DOSSIER de .geojson

# ==========================================================================
# LE LEVEL DESIGN — c'est ici que ça se joue
# ==========================================================================

# Un ruban par ligne : (champ entamé, îlot bâti d'en face, profondeur bâtie).
#
# 🎯 LE CHOIX DES TROIS, proposé le 2026-08-16 et à corriger devant l'image.
# Trois critères, dans cet ordre :
#   1. TROIS CÔTÉS DIFFÉRENTS. Une ville ne pousse pas trois fois au même
#      endroit ; et trois rubans alignés se liraient comme un lotissement
#      unique, pas comme une lisière.
#   2. LES PLUS LONGS MORCEAUX LIBRES de la ceinture (mesurés sur
#      `adjacences` : 2 795 m répartis en 25 morceaux). En dessous de ~150 m
#      un ruban ne porte plus qu'une poignée de maisons et ne se voit pas.
#   3. DE LA CAMPAGNE DERRIÈRE. Voir `FOND_MIN` ci-dessous.
#
# 🔴 CE QUI A ÉTÉ ÉCARTÉ, ET CE QUE ÇA A APPRIS. Le premier essai posait le
# troisième ruban à l'EST, le long du 63 (199 m, le 3ᵉ plus long morceau).
# Le contrôle de croisement l'a refusé : le champ 6 n'est pas un champ, c'est
# une BANDE de 47 à 57 m entre la ville et le bord de la carte. Un ruban de
# 34,5 m y laissait 12 à 22 m de vert — une haie, pas de la campagne. Tout le
# côté est de Wehrau est dans ce cas (63 : 57 m · 61 : 47 · 60 : 17 · 64 : 2),
# donc il n'y a PAS de lisière possible à l'est, et ce n'est pas un réglage à
# forcer : c'est la carte qui s'arrête là.
#
# 🔄 2026-08-17 — LE TROISIÈME RUBAN A CHANGÉ DE CÔTÉ, tranché par l'auteur
# devant l'image. Il partait au SUD, sur le champ 2, en face de la barre de
# 1974 (îlot 32) ; l'argument était qu'un lotissement des années 80 en face
# d'un grand ensemble, à la sortie de la ville, c'est ce qui s'est construit.
# ❌ Refusé : « ce n'est pas logique qu'il soit derrière les barres ». Une
# barre de 1974 tourne le dos à la campagne — elle n'a pas de devant de ce
# côté-là, donc un ruban posé là ne fait pas face à une rue habitée, il fait
# face à un pignon. Ne pas le remettre.
#
# Il part maintenant à l'OUEST, en face du 42 (pavillonnaire, frontière de
# 192 m sur le même champ 9 que le ruban nord). Deux rubans sur un même champ
# est prévu par la mécanique (voir la boucle de `main`) : le second se
# découpe dans le champ DÉJÀ entamé par le premier, et le contrôle de
# partition les additionne.
#
# ⚠️ Le critère « trois côtés différents » ci-dessus n'est donc plus tenu au
# sens strict : nord et ouest mordent le même champ. Ils restent à deux bouts
# opposés de ce champ, qui fait tout le nord-ouest de la carte, et les deux
# rubans ne se voient pas l'un l'autre.
RUBANS = [
    #  champ  bâti     profondeur bâtie visée (m)
    (   9,     11,     28.0),   # NORD — 195 m, face au pavillonnaire du 11
    (   1,     26,     28.0),   # SUD-OUEST — 237 m, le plus long de la ceinture
    (   9,     42,     28.0),   # OUEST — 192 m, face au pavillonnaire du 42
]

# 🔴 CE QUI SE RETRANCHE DE LA PROFONDEUR, ET POURQUOI ÇA NE S'OUBLIE PAS.
# La frontière champ↔îlot est le PIED DE LA CHAUSSÉE au sens de `04b` : ce
# script recule ensuite chaque bord d'îlot de la demi-largeur de sa rue pour
# fabriquer l'emprise bâtie. Un ruban dessiné à 28 m sortirait donc à 22 m
# bâtis — une parcelle pavillonnaire amputée d'un quart de son jardin.
# On dessine donc 28 + demi-chaussée.
#
# Mesuré le 2026-08-16 sur la carte de travail (`wehrau.gpkg` depuis le
# 2026-08-17) : les trois morceaux
# retenus sont tous en hiérarchie `rue`, largeur 12,7 à 13,6 m → demi-chaussée
# 6,3 à 6,8 m. On prend 6,5. L'écart résiduel (±0,3 m sur 28) est sous le
# bruit de la découpe ; le contrôle imprimé après `04b` donne la profondeur
# bâtie réelle, c'est LUI qui tranche si ça dérive.
DEMI_CHAUSSEE = 6.5

# Un ruban plus court que ça n'est pas un îlot, c'est un accident : on refuse.
LONGUEUR_MIN = 60.0

# 🔴 CE QUI DOIT RESTER DE CAMPAGNE DERRIÈRE LE RUBAN, en mètres. Ce contrôle
# n'était pas prévu : c'est le premier essai qui l'a réclamé (voir le
# commentaire de `RUBANS`). Sans lui, un ruban posé sur une bande étroite sort
# géométriquement valide et visuellement faux — la ville touche le bord de la
# carte, et le fond de jardin donne sur le vide au lieu de donner sur un
# champ. 40 m, c'est un peu plus qu'une profondeur de parcelle : il faut que
# ce qui reste derrière puisse encore se lire comme de la campagne.
FOND_MIN = 40.0

# Pas d'échantillonnage le long du front pour mesurer ce fond. 5 m attrape les
# rétrécissements sans faire exploser le O(n·m) du lancer de rayon.
PAS_SONDE = 5.0

# Grille de clé des sommets — la même que `03` et `04b`, pour que « la même
# arête » veuille dire la même chose dans les trois scripts.
CLE = 0.25

# Un sommet décalé ne doit pas s'éloigner de plus de ça fois le décalage.
# Même valeur et même raison que dans `04b` : à un sommet rentrant, les deux
# droites décalées divergent et leur intersection part à l'infini.
LIMITE_MITRE = 3.0

# ==========================================================================
# mécanique — rien à régler en dessous
# ==========================================================================


# 🔄 Retirés le 2026-08-17, quand la source est passée en texte : `lire_wkb`,
# `gpkg_vers_wkb`, `wkb_polygone`, `blob_gpkg`, `enveloppe` et
# `brancher_fonctions_spatiales` — six fonctions qui ne servaient qu'à lire et
# écrire du GeoPackage. Ce script ne touche plus une seule ligne de binaire :
# `carte.py` lit et écrit la source, et c'est le seul endroit du dépôt qui
# connaisse encore le WKB. Même retrait dans `00_decouper_ilots.py`.
# ⚠️ Ne pas en recopier une ici « pour dépanner » : deux lecteurs de géométrie
# qui divergent, c'est le bug qu'on ne verra pas.


# ------------------------------------------------------------------ géométrie

def aire_signee(anneau):
    """Anneau OUVERT. Le SIGNE est l'information : il donne le côté intérieur,
    donc le sens du décalage."""
    s = 0.0
    n = len(anneau)
    for i in range(n):
        x1, y1 = anneau[i]
        x2, y2 = anneau[(i + 1) % n]
        s += x1 * y2 - x2 * y1
    return s / 2.0


def cle(p):
    return (round(p[0] / CLE), round(p[1] / CLE))


def cle_arete(a, b):
    ka, kb = cle(a), cle(b)
    return (ka, kb) if ka <= kb else (kb, ka)


def dedans(anneau, p):
    """Point dans un anneau OUVERT, par lancer de rayon."""
    x, y = p
    n = len(anneau)
    d = False
    for i in range(n):
        x1, y1 = anneau[i]
        x2, y2 = anneau[(i + 1) % n]
        if (y1 > y) != (y2 > y):
            xi = x1 + (y - y1) * (x2 - x1) / (y2 - y1)
            if x < xi:
                d = not d
    return d


def croisement(p1, p2, p3, p4):
    """Intersection PROPRE (strictement à l'intérieur des deux segments), ou
    None. Exclure les extrémités évite de signaler le sommet que deux arêtes
    consécutives partagent légitimement."""
    d1x, d1y = p2[0] - p1[0], p2[1] - p1[1]
    d2x, d2y = p4[0] - p3[0], p4[1] - p3[1]
    den = d1x * d2y - d1y * d2x
    if abs(den) < 1e-12:
        return None
    ex, ey = p3[0] - p1[0], p3[1] - p1[1]
    t = (ex * d2y - ey * d2x) / den
    u = (ex * d1y - ey * d1x) / den
    e = 1e-9
    if e < t < 1.0 - e and e < u < 1.0 - e:
        return (p1[0] + t * d1x, p1[1] + t * d1y)
    return None


def simple(anneau):
    """Un anneau se croise-t-il lui-même ? O(n²), mais n vaut ici quelques
    dizaines de sommets — l'index n'en vaut pas le commentaire."""
    n = len(anneau)
    for i in range(n):
        a, b = anneau[i], anneau[(i + 1) % n]
        for j in range(i + 2, n):
            if i == 0 and j == n - 1:
                continue                     # arêtes voisines par le bouclage
            c, d = anneau[j], anneau[(j + 1) % n]
            if croisement(a, b, c, d):
                return False
    return True


def decaler_chaine(chaine, sens, profondeur):
    """Décale une chaîne OUVERTE p0…pn du côté donné par `sens`.

    `sens` vaut +1 ou −1 et vient du signe de l'aire de l'anneau du champ :
    la normale intérieure est à gauche d'une arête si l'anneau est
    trigonométrique, à droite s'il est horaire. On ne le suppose pas — on le
    lit, comme `04b`.

    Aux DEUX BOUTS, le décalage est perpendiculaire à la première (resp.
    dernière) arête : le ruban se termine donc d'équerre sur la rue, ce qui
    est la limite de propriété qu'on veut. Aux sommets du milieu, c'est
    l'intersection des deux droites décalées (une mitre), plafonnée comme
    dans `04b` pour qu'un sommet rentrant ne parte pas à 200 m."""
    n = len(chaine)
    normales = []
    for i in range(n - 1):
        a, b = chaine[i], chaine[i + 1]
        dx, dy = b[0] - a[0], b[1] - a[1]
        L = math.hypot(dx, dy)
        if L < 1e-9:
            normales.append(None)
            continue
        ux, uy = dx / L, dy / L
        normales.append((-uy * sens, ux * sens, ux, uy))

    vives = [v for v in normales if v]
    if not vives:
        raise SystemExit("chaîne dégénérée")

    sortie = []
    for i, p in enumerate(chaine):
        prec = normales[i - 1] if i > 0 else None
        cour = normales[i] if i < n - 1 else None
        if prec is None and cour is None:
            continue
        if prec is None or cour is None:
            v = cour or prec
            sortie.append((p[0] + v[0] * profondeur, p[1] + v[1] * profondeur))
            continue
        pnx, pny, pux, puy = prec
        cnx, cny, cux, cuy = cour
        den = pux * cuy - puy * cux
        if abs(den) < 1e-9:                  # arêtes parallèles
            sortie.append((p[0] + cnx * profondeur, p[1] + cny * profondeur))
            continue
        px, py = p[0] + pnx * profondeur, p[1] + pny * profondeur
        cx, cy = p[0] + cnx * profondeur, p[1] + cny * profondeur
        t = ((cx - px) * cuy - (cy - py) * cux) / den
        mx, my = px + pux * t, py + puy * t
        if math.hypot(mx - p[0], my - p[1]) > LIMITE_MITRE * profondeur:
            sortie.append((px, py))          # biseau plutôt que pic
            sortie.append((cx, cy))
        else:
            sortie.append((mx, my))
    return sortie


def longueur(chaine):
    return sum(math.dist(chaine[i], chaine[i + 1])
               for i in range(len(chaine) - 1))


def fond_disponible(anneau_champ, idx):
    """Combien de champ y a-t-il DERRIÈRE la frontière, au plus étroit ?

    On avance le long du front tous les `PAS_SONDE` mètres, on lance un rayon
    vers l'intérieur du champ, et on garde la plus courte distance au reste de
    l'anneau. Les arêtes du front lui-même sont exclues du tir, sinon le rayon
    se cognerait à son propre point de départ.

    C'est ce chiffre, et pas la longueur du front, qui dit si une lisière est
    possible : à l'est de Wehrau les morceaux sont longs et le champ ne fait
    que 47 m de fond."""
    n = len(anneau_champ)
    sens = 1.0 if aire_signee(anneau_champ) > 0 else -1.0
    front = set(idx[:-1])
    autres = [(anneau_champ[i], anneau_champ[(i + 1) % n])
              for i in range(n) if i not in front]
    dmin = float("inf")
    for k in range(len(idx) - 1):
        a, b = anneau_champ[idx[k]], anneau_champ[idx[k + 1]]
        L = math.dist(a, b)
        if L < 1e-9:
            continue
        ux, uy = (b[0] - a[0]) / L, (b[1] - a[1]) / L
        nx, ny = -uy * sens, ux * sens
        t = 0.0
        while t <= L:
            p = (a[0] + ux * t, a[1] + uy * t)
            loin = (p[0] + nx * 5000.0, p[1] + ny * 5000.0)
            for c, d in autres:
                r = croisement(p, loin, c, d)
                if r:
                    dmin = min(dmin, math.dist(p, r))
            t += PAS_SONDE
    return dmin


def chaine_partagee(anneau_champ, anneau_bati):
    """La suite de sommets que le champ et l'îlot bâti portent en commun,
    dans l'ordre de l'anneau du CHAMP.

    ⚠️ Piège déjà payé ailleurs (`03`, `04b`) : les deux polygones sortent de
    la polygonisation d'une même couche ligne, donc leurs sommets sont
    identiques au bit près — mais on passe quand même par la grille de 25 cm,
    parce qu'un `.gpkg` réédité dans QGIS peut avoir arrondi.

    La chaîne peut enjamber le point de bouclage de l'anneau : on cherche donc
    la plus longue suite CYCLIQUE d'arêtes partagées, pas la plus longue suite
    dans la liste."""
    aretes_bati = set()
    nb = len(anneau_bati)
    for i in range(nb):
        aretes_bati.add(cle_arete(anneau_bati[i], anneau_bati[(i + 1) % nb]))

    n = len(anneau_champ)
    partage = [cle_arete(anneau_champ[i], anneau_champ[(i + 1) % n])
               in aretes_bati for i in range(n)]
    if not any(partage):
        return None, 0
    if all(partage):
        # Le champ est entièrement ceint par l'îlot bâti : ça n'arrive pas sur
        # Wehrau, et le ruban serait alors un anneau. On refuse plutôt que de
        # produire une géométrie que la suite de la chaîne ne saurait pas lire.
        raise SystemExit("le champ est entièrement bordé par l'îlot bâti")

    # On repart d'une arête NON partagée pour que la suite ne soit jamais
    # coupée en deux par le bouclage de la liste.
    depart = next(i for i in range(n) if not partage[i])
    runs, cour = [], []
    for k in range(n):
        i = (depart + k) % n
        if partage[i]:
            cour.append(i)
        elif cour:
            runs.append(cour)
            cour = []
    if cour:
        runs.append(cour)

    meilleur = max(runs, key=lambda r: longueur(
        [anneau_champ[j] for j in r] + [anneau_champ[(r[-1] + 1) % n]]))
    # Les INDICES, pas les points : deux sommets d'un même anneau peuvent
    # tomber sur la même clé de 25 cm, et retrouver la position par le point
    # rendrait la chirurgie d'anneau ambiguë.
    return meilleur + [(meilleur[-1] + 1) % n], len(runs)


def poser_ruban(anneau_champ, idx, profondeur):
    """-> (anneau du ruban, nouvel anneau du champ). Voir l'en-tête pour le
    schéma : aller par la rue, retour par le fond.

    `idx` est la suite d'indices p0…pn dans l'anneau du champ."""
    chaine = [anneau_champ[i] for i in idx]
    sens = 1.0 if aire_signee(anneau_champ) > 0 else -1.0
    fond = decaler_chaine(chaine, sens, profondeur)

    ruban = list(chaine) + list(reversed(fond))

    # Le champ : on remplace le morceau p0→pn par p0 → fond → pn. Les deux
    # sommets p0 et pn RESTENT au champ — c'est ce qui fait que le ruban et le
    # champ partagent exactement les deux arêtes de bout.
    n = len(anneau_champ)
    reste = []                               # de pn jusqu'à p0, par l'extérieur
    i = idx[-1]
    while True:
        reste.append(anneau_champ[i])
        if i == idx[0]:
            break
        i = (i + 1) % n
    # reste = [pn, …, p0] ; p0 revient en tête de l'anneau, donc on le coupe.
    champ = [chaine[0]] + list(fond) + reste[:-1]
    net = []
    for p in champ:
        if not net or math.dist(p, net[-1]) > 0.05:
            net.append(p)
    while len(net) > 1 and math.dist(net[0], net[-1]) <= 0.05:
        net.pop()
    return ruban, net


# --------------------------------------------------------------------- lire

def lire(src):
    ilots = {}
    for e in src["ilots"]:
        ext = list(e["parts"][0])
        while len(ext) > 1 and ext[0] == ext[-1]:
            ext.pop()                        # on travaille en anneau OUVERT
        ilots[e["fid"]] = ext
    return ilots


def cadre(titre):
    print("\n" + "=" * 74)
    print("  " + titre)
    print("=" * 74)


def main():
    if not os.path.isdir(SOURCE):
        raise SystemExit("source introuvable : %s" % SOURCE)
    src = carte.lire_source(SOURCE)
    ilots = lire(src)

    print("Source : %s" % os.path.basename(SOURCE))
    print("%d îlots — %s" % (len(ilots),
          "PASSE À BLANC, rien ne sera écrit" if BLANC else "ÉCRITURE"))

    libre = max(ilots) + 1
    resultats = []
    for champ, bati, prof_batie in RUBANS:
        for f in (champ, bati):
            if f not in ilots:
                raise SystemExit("îlot %d absent de la source" % f)
        prof = prof_batie + DEMI_CHAUSSEE
        anneau_champ = ilots[champ]
        idx, n_runs = chaine_partagee(anneau_champ, ilots[bati])
        if idx is None:
            raise SystemExit("les îlots %d et %d ne se touchent pas"
                             % (champ, bati))
        chaine = [anneau_champ[i] for i in idx]
        L = longueur(chaine)
        if L < LONGUEUR_MIN:
            raise SystemExit("frontière %d↔%d trop courte : %.0f m (< %.0f)"
                             % (champ, bati, L, LONGUEUR_MIN))
        dispo = fond_disponible(anneau_champ, idx)
        ruban, champ_neuf = poser_ruban(anneau_champ, idx, prof)
        resultats.append({
            "dispo": dispo, "reste": dispo - prof,
            "fid": libre, "champ": champ, "bati": bati, "chaine": chaine,
            "L": L, "prof": prof, "prof_batie": prof_batie, "runs": n_runs,
            "ruban": ruban, "champ_neuf": champ_neuf,
            "champ0": list(anneau_champ),
            "a0": abs(aire_signee(anneau_champ)),
            "ar": abs(aire_signee(ruban)),
            "ac": abs(aire_signee(champ_neuf)),
        })
        ilots[champ] = champ_neuf            # un champ peut porter 2 rubans
        ilots[libre] = ruban
        libre += 1

    # ------------------------------------------------------------- contrôles
    ok = True
    cadre("1. LES RUBANS")
    print("  %-4s %-6s %-6s %8s %8s %9s %9s %10s"
          % ("îlot", "champ", "face", "front m", "fond m", "aire m²",
             "parcelles", "campagne"))
    for r in resultats:
        n_parc = max(1, round(r["L"] / 13.5))   # façade pavillonnaire de 04c
        print("  %-4d %-6d %-6d %8.0f %8.1f %9.0f %9d %10.0f"
              % (r["fid"], r["champ"], r["bati"], r["L"], r["prof"],
                 r["ar"], n_parc, r["reste"]))
    print("\n  « fond » = profondeur du polygone, demi-chaussée de %.1f m"
          % DEMI_CHAUSSEE)
    print("  comprise, que `04b` retirera → %.0f m bâtis."
          % RUBANS[0][2])
    print("  « campagne » = ce qu'il reste de champ derrière, au plus étroit"
          " (min %.0f m)." % FOND_MIN)
    for r in resultats:
        if r["reste"] < FOND_MIN:
            ok = False
            print("  🔴 îlot %d : %.0f m de campagne derrière, il en faut %.0f."
                  " Le champ %d est trop mince ici."
                  % (r["fid"], r["reste"], FOND_MIN, r["champ"]))

    cadre("2. LA PARTITION — le contrôle qui ne se négocie pas")
    par_champ = {}
    for r in resultats:
        par_champ.setdefault(r["champ"], []).append(r)
    for champ, rs in sorted(par_champ.items()):
        a_avant = rs[0]["a0"]
        a_apres = rs[-1]["ac"] + sum(x["ar"] for x in rs)
        ecart = a_apres - a_avant
        marque = "✅" if abs(ecart) < 1.0 else "🔴"
        ok = ok and abs(ecart) < 1.0
        print("  %s champ %-3d  %10.1f m² → %10.1f m² de champ + %8.1f m² de "
              "ruban   écart %+.3f m²"
              % (marque, champ, a_avant, rs[-1]["ac"],
                 sum(x["ar"] for x in rs), ecart))

    cadre("3. LES POLYGONES")
    for r in resultats:
        s_ruban = simple(r["ruban"])
        s_champ = simple(r["champ_neuf"])
        # 🔴 Le fond du ruban doit rester DANS le champ tel qu'il était avant
        # ce ruban : sinon le ruban déborde sur un îlot voisin et la carte se
        # recouvre en silence — rien, plus loin dans la chaîne, ne le verrait.
        fond = r["ruban"][len(r["chaine"]):]
        dehors = sum(1 for p in fond if not dedans(r["champ0"], p))
        bon = s_ruban and s_champ and dehors == 0
        marque = "✅" if bon else "🔴"
        ok = ok and bon
        print("  %s îlot %-3d  ruban %s, %d sommets   champ %d %s, %d sommets"
              "   fond hors champ : %d"
              % (marque, r["fid"],
                 "simple" if s_ruban else "SE CROISE", len(r["ruban"]),
                 r["champ"], "simple" if s_champ else "SE CROISE",
                 len(r["champ_neuf"]), dehors))
        if r["runs"] > 1:
            print("     ⚠️ la frontière %d↔%d est en %d morceaux — seul le plus"
                  " long est pris" % (r["champ"], r["bati"], r["runs"]))

    cadre("4. CE QU'IL FAUT REPORTER DANS `02_qualifier.py`")
    print("  Sans ça les rubans tombent en `maisons_de_ville` par défaut.")
    print("  PAVILLONNAIRE = [11, 26, 35, 39, 42, 47, 60, 61, 63, 64, 70, 71,")
    print("                   %s]" % ", ".join(str(r["fid"]) for r in resultats))

    if not ok:
        raise SystemExit("\n🔴 un contrôle est au rouge — rien n'est écrit.")
    if BLANC:
        print("\nPasse à blanc : rien n'a été écrit.")
        return

    # 🔄 Avant le 2026-08-17 il fallait aussi remettre à jour `gpkg_ogr_contents`,
    # un compte de lignes que les outils SIG croient sur parole et qui laissait
    # la couche s'ouvrir avec trois îlots de moins qu'elle n'en contenait. Le
    # texte n'a pas de compteur à désynchroniser : le problème a disparu avec
    # le format, il n'a pas été corrigé.
    par_fid = {e["fid"]: e for e in src["ilots"]}
    for champ, rs in sorted(par_champ.items()):
        par_fid[champ]["parts"] = [rs[-1]["champ_neuf"]]
    for r in resultats:
        src["ilots"].append({"fid": r["fid"], "parts": [r["ruban"]],
                             "multi": False})

    carte.ecrire_source(src, SOURCE)
    print("\n✅ %d îlots ajoutés (%s) et %d champ(s) redécoupé(s) dans %s"
          % (len(resultats), ", ".join(str(r["fid"]) for r in resultats),
             len(par_champ), SOURCE))
    print("   Reporter la liste PAVILLONNAIRE ci-dessus, puis relancer"
          " python QGIS/scripts/chaine.py")


if __name__ == "__main__":
    main()
