# -*- coding: utf-8 -*-
"""07 — Lire la carte, assembler les familles et écrire le contrat JSON de Godot."""


import json
import math
import os
import palette as PAL
import random
import sqlite3
import sys
from apercu_carte import dedans
from apercu_carte import gpkg_vers_wkb
from apercu_carte import lire_wkb
from importlib import import_module
from export_godot.equipements import PENTES, ROLES, equipement
from export_godot.batiments import (
    _acces_pavillonnaire,
    _bandes_de_fauche,
    _debordement,
    _direction_faitage,
    _facades,
    _haie,
    _index_bord,
    _index_murs,
    _masse,
    _ouvrir_segment,
    _rangs_denses,
    _rangs_verts,
    _ruine,
    _sur_rue,
    _toit_plat,
)
from export_godot.boue import carte_boue
from export_godot.paysage import paysage
from export_godot.ponts import _acces_pont
from export_godot.berges import (
    _arrondir_rives,
    GrilleChaussee,
    _asphalte_en_lair,
    _axe_ampute,
    _axe_manque,
    _bande_berge,
    _boites,
    _bord_eau,
    _cale_rive,
    _emettre_quai,
    _large_berge,
    _pente_berge,
    _pont_neuf,
    _pont_ruine,
    _promenade_berge,
    _quais,
    _semis_berge,
    _tabliers,
)
from export_godot.geometrie import (
    Chenal,
    Maillage,
    Relief,
    _cap_plat,
    _chenal_eau,
    _cle,
    _graine_lieu,
    _grille,
    _ruban,
    _semer_jardin,
    _sol,
    aire_signee,
)
from export_godot.reglages import (
    ACCES_LARGEUR,
    ACCES_OUVERTURE,
    ACROTERE,
    AIRE_JARDIN_MIN,
    ALLEE_PARKING,
    BANDE_CHAMP,
    BATI,
    BATI_DEFAUT,
    BERGE_BANDE_M,
    BERGE_TRAIT_MARGE,
    BERGE_Y,
    BORD_PARKING,
    COLS_ILOTS,
    COLS_ROUTES,
    COUDE_MIN_DEG,
    CRUE_ARBRE_NOYE_M,
    DEBORD_TOIT,
    DENSE_ILOTS,
    ETAGE_M,
    FACADE_PORTE,
    FICHE_ILOTS,
    FICHE_ROUTES,
    FOND_ILSE,
    GRAINE,
    HAUTEUR_BORDURE,
    JEU_CHAUSSEE,
    LARGEUR_LIGNE,
    LARGEUR_TROTTOIR,
    MARGE_COULOIR,
    MARGE_TRONC_CHAUSSEE,
    MODULE_PARKING,
    NAPPE_ILSE,
    PARAPET_H,
    PASSAGE_BANDE,
    PAS_TERRAIN,
    PENTE_RIVE_M,
    PLACE_LARGEUR,
    PLACE_LONGUEUR,
    QUAI_PAS,
    QUAI_PORTEE,
    RIVE_DROITE_Y,
    RIVE_GAUCHE_Y,
    RUINE_PANS,
    SEMIS_BUISSON,
    SEMIS_ROSEAU,
    TALUS_DESSOUS,
    TALUS_LARGEUR,
    TALUS_PAS,
    TOIT_ILOTS,
    TROTTOIR_MIN,
    VERDURE,
    VERDURE_DEFAUT,
    Y_CHAUSSEE,
    Y_MARQUAGE_SOL,
    Y_SOL,
    Y_SOL_ILOT,
    Y_TERRAIN,
    Y_TROTTOIR,
    cheminees,
    facades,
    facades_m,
    retournes,
)
from export_godot.vegetation import (
    _alignement,
    _semer,
)
from export_godot.voirie import (
    DecoupeChaussees,
    _bord_libre,
    _bordure,
    _coller_aux_facades,
    _coudes,
    _dans_chaussee,
    _dessus_trottoir,
    _index_chaussees,
    _longueur,
    _marquage,
    _noeuds_voirie,
    _passages_ville,
    _places_de_parc,
    _places_de_rue,
    _trottoirs,
)

D4 = import_module("04_deriver_attributs")
D4C = import_module("04c_parcelles")
D4D = import_module("04d_emprises_batiments")
D4E = import_module("04e_crue")

ICI = os.path.dirname(os.path.abspath(__file__))
RACINE = os.path.dirname(os.path.dirname(ICI))
sys.path.insert(0, ICI)


_ARGS = [a for a in sys.argv[1:] if not a.startswith("--")]
GPKG = _ARGS[0] if _ARGS else os.path.join(RACINE, "QGIS", "data",
                                           "travail", "wehrau.gpkg")
SORTIE = os.path.join(RACINE, "Godot", "data", "wehrau.json")


def verifier_colonnes(con, table, cols):
    """Un message clair plutôt qu'un « no such column » de sqlite."""
    presentes = {r[1] for r in con.execute("PRAGMA table_info(%s)" % table)}
    manque = [c for c in cols if c not in presentes]
    if manque:
        raise SystemExit(
            "Colonnes absentes de `%s` : %s\n"
            "Relancer d'abord :  python3 QGIS/scripts/04_deriver_attributs.py"
            % (table, ", ".join(manque)))


def verifier_couche(con, table, script):
    presentes = {r[0] for r in con.execute(
        "SELECT name FROM sqlite_master WHERE type='table'")}
    if table not in presentes:
        raise SystemExit(
            "Couche `%s` absente du GeoPackage.\n"
            "Relancer d'abord :  python3 QGIS/scripts/%s" % (table, script))


# ===================================================================== lecture

def lire(con):
    verifier_colonnes(con, "ilots", COLS_ILOTS)
    verifier_colonnes(con, "routes", COLS_ROUTES)
    verifier_couche(con, "emprises", "04b_emprises_baties.py")
    verifier_couche(con, "parcelles", "04c_parcelles.py")
    verifier_couche(con, "batiments", "04d_emprises_batiments.py")

    ilots = {}
    for r in con.execute("SELECT %s FROM ilots ORDER BY fid" % ",".join(COLS_ILOTS)):
        d = dict(zip(COLS_ILOTS, r))
        d["ruine_apres_baisse"] = [float(v) for v in
                                   (d["ruine_apres_baisse"] or "").split(",")
                                   if v]
        ilots[d["fid"]] = d

    def anneau_ouvert(geom):
        """Anneau ouvert et orienté dans le sens TRIGONOMÉTRIQUE.

        Les 69 anneaux sources sont horaires, mais on ne le suppose pas : on
        force le sens ici, une fois. Tout le reste du fichier en dépend —
        c'est lui qui décide du côté visible des murs. Une fois passé dans
        `G()`, qui inverse Z, un anneau trigonométrique donne des normales de
        toit vers le haut et des murs tournés vers l'extérieur."""
        an, _ = lire_wkb(gpkg_vers_wkb(geom))
        a = list(an[0])
        while len(a) > 1 and a[0] == a[-1]:
            a.pop()
        if aire_signee(a) < 0:
            a.reverse()
        return a

    for fid, geom in con.execute("SELECT fid_ilot, geom FROM emprises"):
        ilots[fid]["anneau"] = anneau_ouvert(geom)

    for fid, geom in con.execute("SELECT fid, geom FROM ilots"):
        ilots[fid]["brut"] = anneau_ouvert(geom)

    orphelins = [f for f, d in ilots.items() if "anneau" not in d]
    if orphelins:
        raise SystemExit("îlots sans emprise : %s — relancer 04b"
                         % ", ".join(str(f) for f in orphelins))

    # Les PARCELLES portent le niveau et le fond non bâti ; les BÂTIMENTS sont
    # désormais lus tels que 04d les a dessinés. Avant le 2026-08-17, 07
    # recalculait ici une seconde empreinte avec une seconde table de règles :
    # l'aperçu 2D et Godot montraient donc deux villes différentes.
    for d in ilots.values():
        d["parcelles"] = []
        d["batiments"] = []
    parcelles = {}
    for fid, fid_i, niv, org, geom in con.execute(
        "SELECT fid, fid_ilot, niveaux, origine, geom"
        " FROM parcelles ORDER BY fid"
    ):
        if fid_i not in ilots:
            continue
        p = {"fid": fid, "anneau": anneau_ouvert(geom),
             "niveaux": niv or 0.0, "origine": org}
        parcelles[fid] = p
        ilots[fid_i]["parcelles"].append(p)

    # 🌊 `etat_crue` et `hauteur_eau` viennent de `04e` et ne servent QU'AU
    # RENDU ici : c'est la seule chose que la 3D sait de la crue. Le nombre qui
    # compte pour le jeu (`alea`, les parts sinistrées) reste sur l'îlot.
    for fid_p, fid_i, geom, etat, h in con.execute(
        "SELECT fid_parcelle, fid_ilot, geom, etat_crue, hauteur_eau"
        " FROM batiments ORDER BY fid"
    ):
        if fid_i in ilots and fid_p in parcelles:
            ilots[fid_i]["batiments"].append(
                {"anneau": anneau_ouvert(geom), "parcelle": parcelles[fid_p],
                 "crue": etat or "intact", "eau": h or 0.0})

    routes = []
    for r in con.execute("SELECT %s, geom FROM routes ORDER BY fid"
                         % ",".join(COLS_ROUTES)):
        d = dict(zip(COLS_ROUTES, r[:-1]))
        d["parts"] = lire_wkb(gpkg_vers_wkb(r[-1]))[0]
        routes.append(d)
    return ilots, routes


# ==================================================================== la sortie

def main():
    if not os.path.exists(GPKG):
        sys.exit("Introuvable : %s — lancer 02 → 03 → 04 → 04b d'abord." % GPKG)
    con = sqlite3.connect("file:%s?mode=ro" % GPKG.replace("\\", "/"), uri=True)
    ilots, routes = lire(con)
    con.close()
    _arrondir_rives(ilots)

    print("EXPORT GODOT — %s" % os.path.basename(GPKG))
    print("  %d îlots, %d tronçons" % (len(ilots), len(routes)))

    routes_par_fid = {d["fid"]: d for d in routes}
    for d in routes:
        d["longueur_m"] = round(sum(
            math.hypot(b[0] - a[0], b[1] - a[1])
            for part in d["parts"] for a, b in zip(part, part[1:])), 1)

    # Le lien tronçon → îlots riverains. Il n'est dans AUCUNE table :
    # `adjacences` est îlot↔îlot. Sans lui, une décision de voirie ne peut pas
    # retomber sur les îlots qu'elle borde — donc pas de canopée qui monte
    # autour d'un alignement planté.
    # Emprunté à 08_jouer.py plutôt que réécrit : c'est le même critère
    # géométrique que 04b, déjà éprouvé (178/178, zéro orphelin).
    J8 = import_module("08_jouer")
    r2i, _ = J8.lier_routes_ilots(
        {f: [d["brut"]] for f, d in ilots.items()},
        {d["fid"]: d["parts"] for d in routes})
    orphelins = [d["fid"] for d in routes if d["fid"] not in r2i]
    print("  riverains : %d tronçons sur %d ont au moins un îlot (%d orphelins)"
          % (len(r2i), len(routes), len(orphelins)))
    if orphelins:
        print("    ⚠️  %s" % ", ".join(str(f) for f in orphelins[:12]))

    # ------------------------------------------------------- le recentrage
    xs = [p[0] for d in ilots.values() for p in d["brut"]]
    ys = [p[1] for d in ilots.values() for p in d["brut"]]
    for d in routes:
        for part in d["parts"]:
            xs.extend(p[0] for p in part)
            ys.extend(p[1] for p in part)
    minx, maxx, miny, maxy = min(xs), max(xs), min(ys), max(ys)
    cx, cy = (minx + maxx) / 2.0, (miny + maxy) / 2.0
    print("  emprise %.1f × %.1f m, centre (%.3f, %.3f)"
          % (maxx - minx, maxy - miny, cx, cy))

    # Repère Godot : Y en haut, Z vers le sud. Le signe sur Z garde le nord
    # au nord — et inverse la chiralité, ce dont la triangulation tient compte.
    def G_eau(x, y, alt):
        return (x - cx, alt, -(y - cy))

    chenal = Chenal([d["brut"] for d in ilots.values()
                     if d["sous_type"] == "riviere"])
    print("  chenal : %d arêtes de berge (%d arêtes internes à l'eau écartées)"
          % (len(chenal.berges), chenal.internes))

    def G(x, y, alt):
        return G_eau(x, y, alt + chenal.niveau_rive(x, y))

    def G_voirie(x, y, alt):
        return G_eau(x, y, alt + chenal.niveau_voirie(x, y))

    st_colle = _coller_aux_facades(routes, ilots, chenal)
    coudes, (n_coude, n_marque, n_rond) = _coudes(routes)
    axes_voirie, chaussees = _index_chaussees(routes, coudes)
    passages_ponts = DecoupeChaussees([], {})
    for d in routes:
        if d.get("etat_crue") == "coupe":
            for axe in axes_voirie.get(d["fid"], ()):
                for poly in passages_ponts.ruban(axe, d["largeur_m"] + .4):
                    passages_ponts.ajouter(d["fid"], poly)

    # ------------------------------------------------- le talus, puis la plaque
    # LA VILLE RESTE PLATE. Le seul relief est la descente des champs vers
    # l'eau — construite AVANT la plaque, parce que c'est elle qui dit où la
    # maille de 16 m est trop grossière.
    relief = Relief(chenal, {f: d["anneau"] for f, d in ilots.items()
                             if d["sous_type"] == "champ"})
    n_zones, m_rive = relief.mesures()
    print("  talus : %d champs riverains, %.0f m de rive en pente sur %.0f m"
          " (%.2f m de creux)"
          % (n_zones, m_rive, TALUS_LARGEUR, -Relief.CREUX))

    terre = Maillage()
    coul_terre = PAL.vers_lineaire(PAL.MINERAL_CLAIR)
    # Le paysage prolonge désormais cette plaque ; plus de cadre minéral.
    x0, y0, x1, y1 = minx, miny, maxx, maxy
    morceaux, approx = chenal.plaque(x0, y0, x1, y1, PAS_TERRAIN, relief)
    for mo in morceaux:
        # La plaque plonge un quart plus bas que le talus : elle est invisible
        # sous le champ, et cette marge est ce qui dispense de faire coïncider
        # deux découpages différents du même relief.
        _cap_plat(terre, mo, Y_TERRAIN, coul_terre, G,
                  relief, 1.0 + TALUS_DESSOUS)
    # Mesuré ICI et pas à la fin : `terre` recevra ensuite le lit du chenal et
    # les murs de quai, qui descendent bien plus bas et masqueraient la seule
    # chose qu'on veut contrôler — jusqu'où la PLAQUE plonge sous le talus.
    bas_plaque = min(p[1] for p in terre.v)
    print("  sol : plan à 0,00 m sauf les berges — %d morceaux de plaque"
          " au pas de %.0f m" % (len(morceaux), PAS_TERRAIN))
    if approx:
        print("        dont %d mailles coupées par plusieurs arêtes de berge"
              % approx)

    # ------------------------------------------------------------ les îlots
    masses, sols, eau = Maillage(), Maillage(), Maillage()
    # 🔧 LE MAILLAGE DE LA RÉPARATION. Les mêmes bâtiments, intacts, groupés
    # par îlot — jamais affichés au chargement. Godot en montre le groupe d'un
    # îlot le jour où le joueur paie sa reconstruction ; la ruine, qui tient
    # dessous, disparaît d'elle-même. Voir RUINE_RETRAIT.
    repare = Maillage()
    # 🔧 LA VOIRIE RÉPARÉE, un groupe par tronçon : le tablier neuf d'un
    # franchissement emporté, la chaussée lavée d'une rue envasée. Cachée au
    # chargement, comme le bâti réparé — et posée 2 cm plus haut que ce qu'elle
    # recouvre, sans quoi deux surfaces coplanaires se battraient en duel.
    repare_voirie = Maillage()
    RELEVE = 0.02
    n_tablier_neuf = 0
    n_pont_ruine = 0
    rng = random.Random(GRAINE)
    arbres = []
    emprises = {}
    n_masse = n_sol = n_eau = 0
    n_parc = n_parc_batie = n_vol = 0
    n_pentu = n_plat_force = 0
    n_range = n_ilot_grossier = 0
    n_deborde = 0
    n_ruine = n_sali = 0
    deb_max = 0.0
    toit_total = 0.0
    canopee_perdue = 0.0
    murs_ok = murs_tot = toits_ok = toits_tot = 0
    quais_ok = quais_tot = 0
    # Le mur de quai : le minéral de la ville, un peu assombri — un quai est à
    # l'ombre de sa propre berge une bonne partie de la journée.
    coul_quai = tuple(c * 0.86 for c in PAL.vers_lineaire(PAL.MINERAL_CLAIR))
    n_jardin = n_vert = n_arbre_jardin = 0
    aire_jardin = aire_verte = 0.0
    n_parcelle_haie = n_haie = n_acces = n_pav_vert = 0
    longueur_haie = 0.0
    longueur_acces = 0.0
    ecart_perpendiculaire = 0.0
    # Un vert de jardin, légèrement assombri : un cœur d'îlot est en partie à
    # l'ombre des volumes qui l'entourent, et rien ici ne calcule d'ombre
    # portée sur le sol.
    coul_jardin = PAL.vers_lineaire(PAL.couleur_sol("jardins_familiaux", 0.10))
    coul_jardin = tuple(c * 0.92 for c in coul_jardin)
    # Plus sombre que la pelouse : à la distance de jeu, c'est le contraste
    # vertical qui doit dessiner la limite, pas une nouvelle teinte de palette.
    coul_haie = tuple(c * 0.68 for c in coul_jardin)
    # Le chemin privé reste clair sur le jardin, sans prendre le noir de la
    # chaussée : gravier ou dalles, pas une route miniature.
    coul_acces = tuple(c * 1.03 for c in PAL.vers_lineaire(PAL.MINERAL_CLAIR))
    # 🚶 Le pavé de la venelle : le minéral CLAIR, celui du sol nu, et non le
    # minéral de la chaussée. Vue d'en haut, la différence dit tout ce qu'il y
    # a à dire — on passe du noir de l'asphalte au gris du pavé, donc d'une rue
    # à un passage. Assombri d'un cheveu : une venelle de 3 m entre deux murs
    # ne voit pas beaucoup de ciel.
    coul_chemin = tuple(c * 0.94 for c in PAL.vers_lineaire(PAL.MINERAL_CLAIR))
    # 🅿️ La même peinture usée que la voirie, et c'est le point : une place de
    # parc et une ligne d'axe sont le MÊME objet du monde. Deux blancs
    # différents diraient qu'il s'agit de deux choses.
    coul_marq_sol = PAL.vers_lineaire(PAL.MARQUAGE)
    parkings = []
    n_tri_parc = 0
    n_chemin = 0
    aire_chemin = 0.0
    n_champ = n_bande = n_maille_talus = 0
    n_neuf = 0                 # bâtiments préparés pour la reconstruction
    n_dense = 0                # bâtiments qui ont le droit de prendre un étage
    aire_sol_ilot = 0.0        # le sol nu rendu aux îlots bâtis

    for fid in sorted(ilots):
        d = ilots[fid]
        an = d["anneau"]
        st = d["sous_type"]
        haut = d["hauteur"] or 0.0
        # La couleur de fond reste propre ; la carte de boue couvre les supports.
        brut_ilot = PAL.couleur_ilot(st, haut, d["impermeabilise"])
        # En espace LINÉAIRE : Godot interprète les couleurs de sommet
        # comme telles. En sRGB, toute la maquette ressort délavée.
        coul = PAL.vers_lineaire(brut_ilot)

        if len(an) < 3:
            continue

        if st == "riviere":
            n_eau += 1
            eau.marque(fid)
            # 🌊 Sur l'anneau BRUT, pas sur l'emprise : l'emprise est retirée
            # de la voirie, et le chenal doit tomber exactement sur la limite
            # de l'îlot d'eau, sinon un liseré de sol flotte au-dessus du vide.
            a, b = _chenal_eau(
                eau, terre, d["brut"], chenal, coul, coul_quai, G_eau, relief,
                lambda x, y: chenal.niveau_rive(x, y, False), passages_ponts)
            quais_ok += a
            quais_tot += b
            continue

        # 🔲 L'EMPRISE AU SOL, ET ELLE NE SERT QU'À LA SÉLECTION.
        #
        # 🔄 RETOUR EN ARRIÈRE PARTIEL, signalé — 2026-08-18, le soir même.
        # Le matin, l'export de `contours` était parti d'ici : Godot en faisait
        # un ruban blanc posé au sol, et ce ruban n'entourait que l'emprise
        # alors qu'on sélectionne l'îlot ENTIER — les bâtiments dépassaient du
        # trait. Le trait est depuis tiré de la silhouette RENDUE, et ça, ça
        # reste.
        # Ce qui manquait : une silhouette rendue ne connaît que ce qui est
        # DESSINÉ, et un îlot bâti ne dessine pas son sol — sous une barre de
        # 1970 il n'y a que la plaque de terrain, qui n'appartient à personne.
        # La sélection sortait donc trouée : le trait collait aux bâtiments et
        # laissait dehors le gris qui les entoure.
        # Ce qui repart d'ici n'est donc PAS l'ancien ruban, c'est une DEUXIÈME
        # pièce du masque, réunie à la silhouette dans la vue à part. Le trait
        # suit l'union des deux : l'emprise au sol, et tout ce qui la dépasse
        # en hauteur.
        # ⚠️ Ce n'est pas de la géométrie affichable et ça ne doit jamais le
        # devenir : rien de tout ça n'entre dans le monde, seulement dans le
        # masque (`maquette.gd`, `_batir_contour`).
        # Chaque point porte SON altitude : sur un champ en pente, une emprise
        # plate décollerait du talus et le trait flotterait au-dessus du bord.
        emprises[str(fid)] = [
            [round(c, 2) for c in G(p[0], p[1], Y_SOL + relief.z(p[0], p[1]))]
            for p in an]

        if haut > 0.0:
            n_masse += 1
            masses.marque(fid)
            eau_ilot = d["hauteur_eau_max"] or 0.0
            coul_jardin_i = coul_jardin
            coul_haie_i = tuple(c * 0.68 for c in coul_jardin_i)
            # 🔲 LE SOL NU D'UN ÎLOT BÂTI LUI APPARTIENT. Cour, délaissé,
            # fond de parcelle non planté : rien n'y était dessiné, donc on
            # voyait la plaque de terrain — qui n'est à personne. Ces parties
            # grises sortaient du clic, du calque et du thème « tissu ».
            # La même teinte que le terrain, donc l'image ne bouge pas ; ce
            # qui change est l'APPARTENANCE, et elle passe par le groupe.
            _sol(masses, an,
                 PAL.vers_lineaire(PAL.MINERAL_CLAIR),
                 G, y=Y_SOL_ILOT)
            aire_sol_ilot += abs(D4C.aire_signee(an))
            # ⚠️ TOUTES les parcelles d'un îlot tombent dans LE MÊME groupe.
            # C'est ce qui permet d'avoir mille bâtiments sans passer de 237 à
            # 1 200 nœuds cliquables : la géométrie descend à la parcelle, la
            # SÉLECTION reste à l'îlot — et la décision aussi. La parcelle est
            # l'entité persistante des données (35), pas celle du clic.
            repare.marque(fid)
            role = ROLES.get(fid) if st == "equipement" else None
            pente = PENTES[role] if role else BATI.get(st, BATI_DEFAUT)[3]
            toit_ilot = 0.0
            toit_neuf_ilot = 0.0
            toit_plat_ilot = 0.0
            volumes = []
            batiments_par_parcelle = {}
            # 🚶 LA VENELLE NE SE BÂTIT PAS, ET ELLE EST UNE ADRESSE. Deux
            # choses en découlent, et il faut les deux : elle sort de la liste
            # des parcelles à bâtir — ses deux bouts touchent le bord de
            # l'îlot, donc elle a une façade et `_empreinte_batie` y poserait
            # une lame de bâtiment de 3 m en travers — et ses parois entrent
            # dans l'index du bord, sinon toute la rangée qui donne dessus
            # sortirait enclavée.
            chemins_ilot = [p["anneau"] for p in d["parcelles"]
                            if p.get("origine") == "chemin"]
            if d["parcelles"]:
                idx = _index_bord([an] + chemins_ilot)
                for b in d["batiments"]:
                    p = b["parcelle"]
                    emp = b["anneau"]
                    faite = _direction_faitage(p["anneau"], idx)
                    # 🌊 LA HAUTEUR ET LE FAÎTAGE RESTENT CEUX DU BÂTIMENT
                    # INTACT, même pour une ruine : ce sont eux que le maillage
                    # « réparé » emploiera. Ce qu'une ruine perd — toit, étages,
                    # percements — est perdu à l'ÉMISSION, pas ici.
                    if b["crue"] == "ruine":
                        n_ruine += 1
                    else:
                        n_sali += b["crue"] != "intact"
                    volumes.append((emp, p["niveaux"], faite, p,
                                    b["crue"], b["eau"]))
                    batiments_par_parcelle.setdefault(p["fid"], []).append(emp)
                n_parc += len(d["parcelles"]) - len(chemins_ilot)
                n_parc_batie += len(batiments_par_parcelle)
                n_vol += len(volumes)
                n_chemin += len(chemins_ilot)
            # 🪟 L'index des murs de TOUT l'îlot, bâti une fois : c'est lui
            # qui dira, mur par mur, lesquels sont mitoyens — donc aveugles.
            idx_murs = _index_murs([v[0] for v in volumes])
            rangs_verts = _rangs_verts(volumes, pente)
            n_range += len(rangs_verts)
            rangs_denses, emprise_dense, cumul_dense = _rangs_denses(
                volumes, st, int(d["logements"] or 0))
            d["dense_n"] = len(rangs_denses)
            d["dense_logements_etage"] = int(round(
                emprise_dense / D4D.M2_BRUT_PAR_LOGEMENT))
            d["dense_cumul"] = [round(c, 4) for c in cumul_dense]
            n_dense += d["dense_n"]
            # ⚠️ UN TOIT NE SE VERDIT PAS À MOITIÉ : moins de trois toits plats
            # et le curseur vert de cet îlot n'a plus que deux ou trois crans.
            n_ilot_grossier += 1 if 0 < len(rangs_verts) <= 2 else 0
            adresse = ilots[20 if fid == 16 else 16]["anneau"] if fid in (16, 20) else an
            cible_edifice = tuple(sum(p[j] for p in adresse) / len(adresse) for j in (0, 1))
            principal = max(range(len(volumes)), key=lambda k: abs(aire_signee(volumes[k][0]))) if volumes else -1
            for k_vol, (emp, niv, faite, parcelle, crue, eau_m) in \
                    enumerate(volumes):
                # ⚠️ TOIT À DEUX PENTES SUR EMPREINTE CONVEXE SEULEMENT, et
                # c'est une limite du procédé, pas une préférence. Sur une
                # empreinte concave, une arête d'égout peut repartir en arrière
                # dans un renfoncement et le versant qu'elle porte se retourne.
                pente_v = 0.0
                if pente > 0.0:
                    if _toit_plat(pente, faite, emp):
                        n_plat_force += 1
                    else:
                        pente_v = pente
                        n_pentu += 1
                # La surface de toit se compte VOLUME PAR VOLUME, avec la pente
                # de ce volume-là : un toit plat ne porte pas les 1,4 m² de
                # couverture par m² d'emprise d'un toit à 45°. C'est ce nombre
                # que l'énergie viendra lire (41 · 64).
                # 🌊 UNE RUINE N'A PLUS DE TOIT, DONC PLUS DE PANNEAUX. C'est
                # la seule chose que « reconstruire » RAPPORTE aujourd'hui :
                # `toit_m2` est ce qu'on peut équiper maintenant, `toit_m2_neuf`
                # ce qu'on pourrait équiper une fois l'îlot relevé.
                aire_toit = abs(D4C.aire_signee(emp)) * math.hypot(1.0, pente_v)
                toit_neuf_ilot += aire_toit
                if crue != "ruine":
                    toit_ilot += aire_toit
                    # 🌿 CE QUI PEUT PORTER UN TOIT VERT, et rien d'autre : un
                    # substrat ne tient pas sur un versant. Mesuré ici plutôt
                    # que déduit du tissu, parce que les empreintes concaves
                    # d'un tissu à versants retombent AUSSI au toit plat.
                    if pente_v <= 0.0:
                        toit_plat_ilot += aire_toit
                # ⚠️ Les chemins sont ÉCARTÉS de ce contrôle : un bâtiment qui
                # mord sur la venelle est exactement le défaut qu'on cherche à
                # voir, et le compter « dans une parcelle » le masquerait.
                deb = _debordement(emp, parcelle)
                if deb > 0.5:
                    n_deborde += 1
                    deb_max = max(deb_max, deb)
                # 🎨 UN BÂTIMENT = DEUX MATÉRIAUX, TIRÉS DE SA POSITION (35).
                # C'est ici que la ville cesse d'être coloriée par typologie :
                # deux maisons mitoyennes du même tissu n'ont plus la même
                # façade, et le toit ne suit plus le mur. La graine vient de
                # l'empreinte, donc bouger une ligne de table ne rebat pas
                # toute la ville.
                gr = _graine_lieu(emp)
                mur_neuf = PAL.couleur_mur(st, gr)
                toit_neuf = PAL.couleur_toit(st, gr)
                mur, toit = mur_neuf, toit_neuf
                # 🌊 CE QUE LA CRUE A LAISSÉ. Les teintes se MÉLANGENT à celles
                # du bâtiment, elles ne les remplacent pas : la couleur dit
                # l'époque depuis le 2026-08-18, et un faubourg gris uni
                # effacerait le tissu. Une ruine, elle, a bien perdu son enduit.
                if crue == "ruine":
                    # 🔄 0,72 → 0,88 le 2026-08-21 : une ruine A perdu son
                    # enduit, elle n'a pas à garder la couleur de son époque.
                    # C'est la seule exception au rendu par matériau du
                    # 2026-08-18, et elle vaut pour 68 bâtiments sur 757.
                    mur = PAL.melanger(mur, PAL.RUINE_MUR, 0.88)
                c_mur = PAL.vers_lineaire(mur)
                c_toit = PAL.vers_lineaire(toit)
                # 🪟 Le percement des murs, mur par mur, et le tirage qui
                # donne à CE bâtiment son entraxe de travées. Le tirage vient
                # de la même graine de lieu que ses deux teintes : bouger une
                # ligne de table ne rebat pas les fenêtres de la ville.
                genres = _facades(k_vol, emp, parcelle["anneau"], idx,
                                  idx_murs, st)
                alea = random.Random(gr ^ 0xFE4E).random()
                if role:
                    destination = repare if crue == "ruine" else masses
                    compte, aire_edifice = equipement(
                        destination, emp, G, role, niv, cible_edifice,
                        k_vol == principal, 0.0 if crue == "ruine" else eau_m)
                    toit_neuf_ilot += aire_edifice - aire_toit
                    if crue != "ruine":
                        toit_ilot += aire_edifice - aire_toit
                        if pente_v <= 0.0:
                            toit_plat_ilot -= aire_toit
                        a, b, c, e = compte
                    else:
                        n_neuf += 1
                        a, b, c, e = _ruine(masses, emp, c_mur,
                            PAL.vers_lineaire(PAL.GRAVATS), G,
                            random.Random(gr ^ 0x9C21))
                    murs_ok += a
                    murs_tot += b
                    toits_ok += c
                    toits_tot += e
                    print("  repère %s · îlot %d · %d triangles · %.1f m² de toit mesuré"
                          % (role, fid, compte[1], aire_edifice))
                    continue
                if crue == "ruine":
                    a, b, c, e = _ruine(masses, emp, c_mur,
                                        PAL.vers_lineaire(PAL.GRAVATS), G,
                                        random.Random(gr ^ 0x9C21))
                    # 🔧 ET LE MÊME BÂTIMENT NEUF, dans un maillage à part que
                    # Godot garde CACHÉ jusqu'à ce que la décision tombe. C'est
                    # tout ce que « reconstruire » demande à la 3D : la maquette
                    # bâtit sa géométrie une fois, elle ne sait pas en fabriquer
                    # en cours de partie.
                    n_neuf += 1
                    _masse(repare, emp, d, PAL.vers_lineaire(mur_neuf), G, niv,
                           pente_v, faite, PAL.vers_lineaire(toit_neuf),
                           genres, alea, rangs_verts.get(k_vol, 1.0))
                else:
                    # 🏢 Tout ce que le bâtiment émet à partir d'ici porte son
                    # rang de montée : murs, toit, acrotère, souches.
                    if k_vol in rangs_denses:
                        # Le seuil des sommets qui montent, puis l'égout
                        # lui-même : un demi-mètre plus haut, et c'est la
                        # couture entre le bâtiment d'avant et ses étages neufs.
                        seuil = G(emp[0][0], emp[0][1],
                                  niv * ETAGE_M - 0.5)[1]
                        masses.dense = (rangs_denses[k_vol], seuil,
                                        seuil + 0.5)
                    a, b, c, e = _masse(masses, emp, d, c_mur, G, niv,
                                        pente_v, faite, c_toit, genres, alea,
                                        rangs_verts.get(k_vol, 1.0))
                    masses.dense = None
                murs_ok += a
                murs_tot += b
                toits_ok += c
                toits_tot += e

            # 🌳 LES CŒURS D'ÎLOT. Les fonds de parcelle étaient calculés puis
            # jetés : le cœur d'un pâté ressortait en terrain nu, donc gris.
            # Ils sont maintenant DESSINÉS — mais pas tous verts, et c'est le
            # sujet. Une cour de cœur ancien est pavée, un jardin de
            # pavillonnaire est planté ; ce contraste-là fait lire le tissu vu
            # d'en haut mieux que la couleur des façades.
            #
            # Ils partent dans le maillage des MASSES, dans le groupe de
            # l'îlot : le cœur d'îlot appartient à l'îlot, donc il se clique
            # avec lui et se teinte avec lui quand un calque s'allume.
            # 🚶 LA VENELLE, AU SOL. Elle passe dans le maillage des MASSES,
            # donc dans le groupe de son îlot : elle appartient à l'îlot, elle
            # se clique avec lui et se teinte avec lui quand un calque
            # s'allume. C'est la traduction en 3D de la seule chose qui compte
            # ici — le chemin n'a pas fabriqué une deuxième décision.
            # Elle est PAVÉE et jamais plantée : un tirage cour/jardin lui
            # mettrait des arbres au milieu d'un passage.
            for c in chemins_ilot:
                if len(c) >= 3:
                    aire_chemin += abs(D4C.aire_signee(c))
                    _sol(masses, c, coul_chemin, G)

            part_verte = VERDURE.get(st, VERDURE_DEFAUT)
            limites_haie = set()
            for p in d["parcelles"]:
                if p.get("origine") == "chemin":
                    continue
                j = p["anneau"]
                emps = batiments_par_parcelle.get(p["fid"], [])
                if st == "pavillonnaire" and emps:
                    haie_posee = False
                    rues = _sur_rue(j, idx)
                    acces = _acces_pavillonnaire(j, emps, rues)
                    if acces is not None:
                        _ruban(masses, [acces["maison"], acces["route"]],
                               ACCES_LARGEUR, coul_acces, G,
                               y=Y_SOL + 0.015, bouts=False)
                        n_acces += 1
                        longueur_acces += acces["longueur"]
                        ecart_perpendiculaire = max(
                            ecart_perpendiculaire, acces["ecart_angle"])
                    for k, sur_rue in enumerate(rues):
                        a, b = j[k], j[(k + 1) % len(j)]
                        morceaux = [(a, b)]
                        if acces is not None and k == acces["arete"]:
                            morceaux = _ouvrir_segment(
                                a, b, acces["route"], ACCES_OUVERTURE)
                        cle = tuple(sorted((_cle(a), _cle(b))))
                        if not sur_rue and cle in limites_haie:
                            # La voisine l'a déjà dessinée : cette parcelle
                            # est bien bordée elle aussi, sans second prisme.
                            haie_posee = True
                            continue
                        dessine = 0.0
                        for debut, fin in morceaux:
                            longueur = _haie(
                                masses, debut, fin, coul_haie_i, G)
                            if longueur > 0.0:
                                n_haie += 1
                                longueur_haie += longueur
                                dessine += longueur
                        if dessine > 0.0:
                            limites_haie.add(cle)
                            haie_posee = True
                    if haie_posee:
                        n_parcelle_haie += 1
                aire_j = max(0.0, abs(D4C.aire_signee(j)) - sum(
                    abs(D4C.aire_signee(emp)) for emp in emps))
                # Le pavillonnaire BÂTI est toujours vert. Avant, `part_verte`
                # valait 0,92 : le tirage laissait donc 8 % des maisons sur une
                # parcelle grise, sans que la simulation ne l'explique.
                vert_force = st == "pavillonnaire" and bool(emps)
                if vert_force:
                    _sol(masses, j, coul_jardin_i, G)
                    n_pav_vert += 1
                if aire_j < AIRE_JARDIN_MIN or len(j) < 3:
                    continue
                n_jardin += 1
                aire_jardin += aire_j
                if not vert_force and \
                        random.Random(_graine_lieu(j)).random() > part_verte:
                    continue                  # une cour, pas un jardin
                n_vert += 1
                aire_verte += aire_j
                # Le sol vert couvre la parcelle entière, mais les volumes
                # opaques posés dessus cachent exactement leur empreinte : ce
                # qui reste visible est donc la différence parcelle − bâti,
                # sans introduire un second moteur de géométrie dans 07.
                if not vert_force:
                    _sol(masses, j, coul_jardin_i, G)
                if eau_ilot >= CRUE_ARBRE_NOYE_M:
                    continue                  # jardin noyé : plus un arbre
                arbres_jardin = _semer_jardin(j, aire_j, emps)
                arbres.extend(arbres_jardin)
                n_arbre_jardin += len(arbres_jardin)

            # 🔗 L'INTERFACE DU TOIT — décisions 41 et 64.
            # Un objet bâti expose quatre nombres : surface de toit, pente,
            # orientation, ombrage. Aujourd'hui c'est le générateur de
            # parcelles qui les produit ; avant lui, une table de coefficients
            # par `sous_type` en tenait lieu. 🔴 Le code d'énergie ne doit
            # jamais savoir lequel des deux parle — c'est ce qui fait que
            # l'énergie n'attend pas la 3D (64b).
            #   `toit_m2` est la surface RÉELLE, pente comprise : un toit à
            #   45° porte 1,41 fois l'emprise qu'il couvre, et c'est cette
            #   surface-là qu'on couvrirait de panneaux. Elle est sommée
            #   VOLUME PAR VOLUME : un bâtiment tombé au toit plat compte pour
            #   son emprise, pas pour l'emprise étirée du tissu.
            d["toit_m2"] = round(toit_ilot, 1)
            # Ce que l'îlot porterait une fois relevé. Égal à `toit_m2` partout
            # où la crue n'a rien pris : c'est l'écart entre les deux qui donne
            # à « reconstruire » son seul rendement mesurable.
            d["toit_m2_neuf"] = round(toit_neuf_ilot, 1)
            d["toit_pente"] = round(pente, 2)
            d["toit_plat"] = 1 if pente <= 0.0 else 0
            # 🌿 Le drapeau ci-dessus dit ce que le TISSU veut ; ce m² dit ce
            # que la ville a vraiment de plat. Les deux divergent, et c'est le
            # second qui plafonne les toits verts.
            d["toit_plat_m2"] = round(toit_plat_ilot, 1)
            toit_total += toit_ilot
            # La canopée d'un îlot bâti n'est pas représentable dans une
            # maquette de masses : le pâté est plein, il n'y a pas de sol
            # visible dessous. On la compte pour le dire, pas pour la cacher.
            canopee_perdue += (d["canopee"] or 0.0) * (d["surface_m2"] or 0.0)
        else:
            n_sol += 1
            sols.marque(fid)
            # 🌾 Le champ n'est plus un aplat : sa teinte est tirée de sa
            # position (blé, prairie, chaume, labour) et il est coupé en
            # bandes de fauche. C'est la plus grande surface unie de l'image,
            # donc celle qui trahissait le plus la maquette.
            if st == "champ":
                brut_champ = PAL.couleur_champ(_graine_lieu(an), d["impermeabilise"])
                coul = PAL.vers_lineaire(brut_champ)
                # 🌊 La berge n'est ni fauchée ni cultivée : on ne descend pas
                # une moissonneuse à 22 %. Sa teinte part de celle du champ et
                # va aux deux tiers vers le vert du parc — donc deux champs
                # voisins ont encore deux berges différentes, et la cassure du
                # haut de talus se lit même à contre-jour, où la pente seule ne
                # se voit pas.
                coul_berge = PAL.vers_lineaire(
                    PAL.melanger(brut_champ, PAL.SOLS["parc"], 0.65))
                for mo, tint in _bandes_de_fauche(an, coul):
                    if len(mo) < 3:
                        continue
                    n_bande += 1
                    for piece, en_pente in relief.trier(fid, mo):
                        if not en_pente:
                            _sol(sols, piece, tint, G, relief)
                            continue
                        for cel in _grille(piece, TALUS_PAS):
                            _sol(sols, cel, coul_berge, G, relief)
                            n_maille_talus += 1
                n_champ += 1
            else:
                _sol(sols, an, coul, G)
            # 🅿️ LA PLACE-PARKING SE DESSINE. Le test ne nomme aucun îlot et
            # aucun sous-type : un îlot de SOL qui porte des places, c'est la
            # place minérale et rien d'autre — la barre et l'équipement en
            # portent aussi, mais ils ont une hauteur et sont partis plus haut.
            # Le jour où le level design pose une deuxième place, elle se
            # dessinera sans qu'on revienne ici.
            interdit = None
            if (d["stationnement"] or 0) > 0:
                n_pl, traits, trame_pl = _places_de_parc(an)
                # Les places entrent dans le maillage des SOLS, donc dans le
                # groupe de leur îlot : cliquer une place ouvre la fiche de la
                # place. Elles ne sont pas de la voirie — le jeu ne les
                # sélectionne pas une par une.
                for p_, q_ in traits:
                    n_tri_parc += _ruban(sols, [p_, q_], LARGEUR_LIGNE,
                                         coul_marq_sol, G, y=Y_MARQUAGE_SOL,
                                         bouts=False)
                # 🌳 ET LES ARBRES TIENNENT LE BORD. Sans ça, un arbre sur deux
                # de la place pousse au milieu d'une place peinte : le semis
                # tire au hasard dans l'anneau et ne sait rien de la trame.
                # C'est le même mécanisme que le rejet hors de l'anneau, avec
                # un anneau de plus — pas une position corrigée à la main.
                if trame_pl is not None:
                    interdit = list(trame_pl) + [trame_pl[0]]
            plantes = [] if (d["hauteur_eau_max"] or 0.0) >= CRUE_ARBRE_NOYE_M                 else _semer(an, d, rng, relief, interdit)
            arbres.extend(plantes)
            if interdit is not None:
                # Le compte est MESURÉ sur les arbres rendus, pas déduit du
                # rejet : c'est ce qui prouve que le rejet a bien tourné.
                parkings.append((fid, n_pl, len(traits), d["stationnement"],
                                 len(plantes),
                                 sum(1 for t in plantes
                                     if dedans(interdit, (t[0], t[1])))))

    print("  masses %d · sols %d · eau %d" % (n_masse, n_sol, n_eau))
    print("        emprises de sélection : %d îlots, %d sommets"
          " (jamais affichées, c'est le masque du trait)"
          % (len(emprises), sum(len(v) for v in emprises.values())))
    if n_parc:
        print("  couche `batiments` : %d volumes sur %d parcelles bâties"
              " (%d parcelles non bâties)"
              % (n_vol, n_parc_batie, n_parc - n_parc_batie))
        print("  sol d'îlot bâti : %.2f ha posés sous les %d pâtés — la cour"
              " et le délaissé se cliquent et se teintent avec leur îlot"
              % (aire_sol_ilot / 1e4, n_masse))
        if n_chemin:
            print("  chemins %d → %.0f m² de venelle pavée, dans le groupe de"
                  " leur îlot" % (n_chemin, aire_chemin))
        # 🔗 Ce que l'énergie viendra lire. À imprimer maintenant, parce que
        # c'est le seul moment où on peut encore dire « ce chiffre est faux »
        # avant qu'une décision de jeu s'appuie dessus.
        print("  toits : %.1f ha de surface réelle (pente comprise)"
              % (toit_total / 1e4))
        print("  haies : %d parcelles bâties, %d tronçons, %.2f km en"
              " pavillonnaire" %
              (n_parcelle_haie, n_haie, longueur_haie / 1000.0))
        print("  accès pavillonnaires : %d chemins, %.1f m en tout, écart"
              " maximal à la perpendiculaire %.4f°"
              % (n_acces, longueur_acces, ecart_perpendiculaire))
        print("        %d parcelles pavillonnaires bâties vertes sur %d"
              % (n_pav_vert, n_parcelle_haie))
        print("        %d à deux pentes · %d plats par dessin (le tissu les"
              " veut plats) · %d plats faute d'empreinte convexe"
              % (n_pentu, n_vol - n_pentu - n_plat_force, n_plat_force))
        if n_deborde:
            print("        ⚠️  %d bâtiments sur %d débordent de leur parcelle,"
                  " jusqu'à %.1f m" % (n_deborde, n_vol, deb_max))
            print("           pic de mitre sur angle rentrant — borné par le recul"
                  " du tissu, à reprendre")
        plats = [f for f, x in ilots.items() if x.get("toit_plat")]
        print("        dont %d îlots à toit plat — barre, friches,"
              " collectif 1995 et îlot compact" % len(plats))
        # 🌿 LE PLAFOND DES TOITS VERTS, et il ne se devine pas depuis le
        # tissu : les empreintes concaves ajoutent du plat dans des îlots à
        # versants. C'est ce nombre que l'énergie lit.
        plat_m2 = sum(x.get("toit_plat_m2") or 0.0 for x in ilots.values())
        porteurs = [f for f, x in ilots.items() if (x.get("toit_plat_m2") or 0.0) > 0.0]
        print("        surface plate : %.1f ha, %.0f %% du toit, sur %d îlots"
              " (%d que le tissu veut plats)"
              % (plat_m2 / 1e4, 100.0 * plat_m2 / max(toit_total, 1.0),
                 len(porteurs), len(plats)))
        # 🌿 UN TOIT EST SOLAIRE OU VERT : le curseur vert avance donc par
        # TOITS ENTIERS, et c'est ce que la finesse coûte.
        print("        %d toits plats rangés pour le vert ; %d îlots n'en ont"
              " qu'un ou deux, leur curseur est un interrupteur"
              % (n_range, n_ilot_grossier))
        # 🏢 CE QUE LA DENSIFICATION A LE DROIT DE LEVER. Le patrimoine est
        # dehors ; si ce compte tombe à zéro, aucun îlot ne peut monter.
        montables = [f for f, x in ilots.items() if x.get("dense_n")]
        log_etage = sum(x.get("dense_logements_etage", 0)
                        for x in ilots.values())
        print("  densification : %d bâtiments montables sur %d îlots ;"
              " un étage partout ajouterait %d logements (parc : %d)"
              % (n_dense, len(montables), log_etage,
                 sum(int(x["logements"] or 0) for x in ilots.values())))
        print("  empreintes : lues directement dans 04d, aucune forme recalculée"
              " par l'export Godot")
        # 🌊 CE QUE LA CRUE DOIT AVOIR CHANGÉ À L'ÉCRAN. Deux nombres, et ils
        # se contrôlent à l'œil : les ruines sont des murs sans toit, le reste
        # du faubourg est sali. À zéro ruine, `04e` n'est pas passé.
        coupes = [r["fid"] for r in routes
                  if (r.get("etat_crue") or "") == "coupe"]
        print("  crue : %d ruines à ciel ouvert, %d bâtiments salis,"
              " %d franchissement(s) emporté(s) %s"
              % (n_ruine, n_sali, len(coupes), sorted(coupes)))
        print("        crêtes tirées dans %s × 2,70 m — si elles sortent"
              " toutes pareilles, la ruine se lit comme un toit plat"
              % (RUINE_PANS,))
        print("  réparation : %d bâtiments neufs en attente sur %d îlots"
              % (n_neuf, len(repare.groupes)))
        if not n_ruine:
            print("        ⚠️ aucune ruine — relancer `04e_crue.py`, ou la table"
                  " de `04e` ne ruine plus personne")
        # 🎨 LE RENDU RÉALISTE (2026-08-18). Ces quatre lignes sont le compte
        # rendu de la passe : elles disent ce que l'auteur doit RETROUVER à
        # l'écran, et ce qui manquerait si un des trois volets était muet.
        print("  matériaux : toit et mur séparés, tirés de la position du"
              " bâtiment (35)")
        print("        îlots couverts en tuile %d · ardoise %d · étanchéité %d"
              " · bac acier %d"
              % tuple(sum(1 for f, x in ilots.items()
                          if PAL.TOIT_TISSU.get(x["sous_type"]) == fam
                          and (x["hauteur"] or 0.0) > 0.0)
                      for fam in ("tuile", "ardoise", "etancheite",
                                  "bac_acier")))
        print("        débord de toit %.2f m sur les %d volumes à deux pentes,"
              " acrotère de %.2f m sur les toits plats"
              % (DEBORD_TOIT, n_pentu, ACROTERE))
        print("        %d souches de cheminée (%.0f %% des toits pentus)"
              % (cheminees[0], 100.0 * cheminees[0] / max(n_pentu, 1)))
        # 🪟 LES FAÇADES. Ce tableau est le seul endroit où le percement se
        # vérifie sans lancer Godot : il dit ce que l'export a DÉCIDÉ, pas ce
        # que le shader dessine. Le dessin, lui, se juge à l'écran (§3 bis).
        # Ce qu'on y lit : « aveugle » doit rester la part des pignons du
        # tissu mitoyen — s'il monte, c'est `_mitoyen` qui mord trop large ;
        # « porte » doit valoir à peu près un bâtiment sur un.
        noms = ["aveugle", "fenêtres", "+ porte", "vitrine", "bandeau"]
        print("  façades : %d murs percés sur %d (%.2f km de façade)"
              % (sum(facades[1:]), sum(facades),
                 sum(facades_m[1:]) / 1000.0))
        for g, nom in enumerate(noms):
            if facades[g]:
                print("        %-9s %5d murs  %7.0f m  %4.0f %%"
                      % (nom, facades[g], facades_m[g],
                         100.0 * facades[g] / max(sum(facades), 1)))
        if facades[FACADE_PORTE] > n_vol:
            raise SystemExit(
                "%d portes pour %d bâtiments : `_facades` en pose plus d'une "
                "par volume." % (facades[FACADE_PORTE], n_vol))
        # 🌳 Les cœurs d'îlot. « pas tous » est le chiffre qui compte : à 100 %
        # de vert, le contraste entre une cour pavée et un jardin disparaît.
        print("  cœurs d'îlot : %d espaces libres (%.1f ha), dont %d plantés"
              " (%.0f %%, %.1f ha) et %d arbres"
              % (n_jardin, aire_jardin / 1e4, n_vert,
                 100.0 * n_vert / max(n_jardin, 1), aire_verte / 1e4,
                 n_arbre_jardin))
    print("  chenal : %d murs de quai, tous tournés vers l'eau  %s"
          % (quais_tot, "✅" if quais_ok == quais_tot
             else "❌ %d à l'envers" % (quais_tot - quais_ok)))
    print("  triangles : plaque %d, masses %d, sols %d, eau %d"
          % (len(terre), len(masses), len(sols), len(eau)))
    print("  sens des faces : murs vers l'extérieur %d/%d · toits dehors %d/%d"
          % (murs_ok, murs_tot, toits_ok, toits_tot))
    # ⚠️ Les deux colonnes ne se lisent PAS de la même façon, et il faut le
    # savoir pour ne pas se rassurer à bon compte. Pour les MURS, le sens vient
    # du parcours de l'anneau : le contrôle est réel, et 3 005 sur 3 005 veut
    # dire quelque chose. Pour les TOITS, l'orientation est calculée à
    # l'émission, donc la colonne est vraie par construction et ne prouve rien.
    # Le chiffre qui informe est celui-ci : combien de pans ont dû être
    # retournés. S'il s'envole, c'est la recette du faîtage qu'il faut revoir.
    if retournes[0]:
        print("        %d pans de toit réorientés à l'émission (%.0f %% des toits)"
              % (retournes[0], 100.0 * retournes[0] / max(toits_tot, 1)))
    if murs_ok != murs_tot or toits_ok != toits_tot:
        raise SystemExit(
            "Faces mal orientées : le culling les ferait disparaître.\n"
            "L'inversion de Z change la chiralité — vérifier `anneau_ouvert`.")

    # ----------------------------------------------------------- la voirie
    voirie = Maillage()
    ponts_ruine = Maillage()
    # 🌊 LA BERGE A SON MAILLAGE, donc ses groupes, donc ses nœuds cliquables
    # dans Godot. Trois maillages, un fid par groupe dans chacun : la bande de
    # rive, qui reste ; le MUR, que la rive rendue fait disparaître ; le TALUS,
    # qui prend sa place. Cliquer l'un des trois ouvre la même fiche — c'est le
    # fid du groupe qui le dit, pas le maillage.
    berges_m = Maillage()
    murs_m = Maillage()
    pentes_m = Maillage()
    # 🅿️ LES PLACES ONT LEUR MAILLAGE, donc leurs nœuds : « retirer les places »
    # doit les effacer de la ville, pas seulement en retirer les voitures.
    # C'est la même recette que la ville réparée, à un détail près : ces nœuds
    # partent VISIBLES et se cachent, au lieu de l'inverse.
    places_m = Maillage()
    # Deux teintes, et ce sont celles de ce qu'elle recouvre : à l'état
    # « asphalte » la bande ne doit RIEN changer au rendu de la ville.
    coul_berge = (PAL.vers_lineaire(PAL.TROTTOIR),
                  PAL.vers_lineaire(PAL.melanger(PAL.MINERAL_CLAIR, "#000000",
                                                 0.10)))
    coul_ch = PAL.vers_lineaire(PAL.MINERAL)
    coul_tr = PAL.vers_lineaire(PAL.TROTTOIR)
    # La bordure est le trottoir assombri, pas une couleur de plus : c'est une
    # tranche de la même dalle, et l'œil ne doit y lire qu'une ombre d'arête.
    coul_bord = PAL.vers_lineaire(PAL.melanger(PAL.TROTTOIR, "#000000", 0.22))
    coul_marq = PAL.vers_lineaire(PAL.MARQUAGE)
    # 🌊 LE CORRIDOR DES RUES DE BERGE SE POSE SUR LA TERRE, AVANT TOUT LE
    # RESTE : coudes, chaussée, marquage, quai, alignements et couloir de
    # sélection lisent tous `parts`, et n'ont donc rien à savoir de la berge.
    if st_colle["n"]:
        print("  berge : %d tronçons collés aux façades sur %.0f m — décalé de"
              " %.1f à %.1f m, il reste %.1f à %.1f m entre l'asphalte et l'eau"
              "  ·  %d rues perpendiculaires arrêtées à la rive"
              % (st_colle["n"], st_colle["m"],
                 min(st_colle["decals"]), max(st_colle["decals"]),
                 min(st_colle["libres"]), max(st_colle["libres"]),
                 st_colle["bouts"]))
    else:
        print("  ⚠️  aucune rue de berge collée aux façades — sonde ou emprise ?")
    # 🅿️ OÙ SE GARE UNE VOITURE, en mètres depuis l'axe : le milieu de la file
    # peinte. Mesuré ici, où la coupe en travers est connue, et lu tel quel par
    # `trafic.gd` — deux recettes parallèles auraient dérivé dès le premier
    # tronçon de berge, dont le corridor n'est plus celui de la source.
    # 🚶 OÙ MARCHE UN PIÉTON, même règle et même raison : le milieu du
    # trottoir, depuis l'axe. 0 quand le corridor n'en laisse pas la place —
    # `trafic.gd` fait alors marcher au bord de la chaussée, comme en ruelle.
    for d in routes:
        larg_ = d["largeur_m"] or 0.0
        ch_ = min(D4.EMPRISE_CIRCULATION.get(d["hierarchie"], 8.5), larg_)
        d["bord_places_m"] = (round(_bord_libre(d, ch_) - PLACE_LARGEUR / 2.0, 2)
                              if larg_ > 0.0 else 0.0)
        nu_ = _bord_libre(d, ch_) + JEU_CHAUSSEE
        dehors_ = d.get("corridor_m", larg_) / 2.0
        d["bord_trottoir_m"] = (round((nu_ + dehors_) / 2.0, 2)
                                if larg_ > 0.0 and dehors_ - nu_ >= TROTTOIR_MIN
                                else 0.0)
    # 🌊 LE PONT EMPORTÉ (04e · 23b). On ampute son axe UNE FOIS, ici, et tout
    # ce qui le lit ensuite — chaussée, tablier, parapet, pile, marquage — ne
    # voit qu'un axe qui s'arrête au bord de l'eau. Aucune de ces cinq recettes
    # n'a été touchée : c'est ce qui rend la chose réversible en une ligne de
    # `04e` et ce qui évite d'ouvrir `_bord_eau`.
    # ⚠️ Un axe amputé rend une LISTE de morceaux, jamais un axe.
    morceaux_voirie = {}
    for d in routes:
        coupe = (d.get("etat_crue") or "") == "coupe"
        morceaux_voirie[d["fid"]] = [
            _axe_ampute(a, chenal) if coupe else [a]
            for a in axes_voirie.get(d["fid"], ())]
    # Les arbres semés lisent les îlots, qui devraient déjà s'arrêter au bord
    # des rues. On les contrôle quand même ici : c'est le filet qui montrera
    # immédiatement une future régression du découpage de la carte.
    arbres_ecartes_chaussee = sum(
        1 for a in arbres
        if _dans_chaussee((a[0], a[1]), chaussees,
                          MARGE_TRONC_CHAUSSEE))
    arbres = [a for a in arbres
              if not _dans_chaussee((a[0], a[1]), chaussees,
                                     MARGE_TRONC_CHAUSSEE)]
    trot, st_tr = _trottoirs(ilots, routes, coudes)
    # 🎨 Les nœuds du marquage : combien de branches à chaque bout de
    # tronçon. C'est plus riche que le `noeuds` d'à côté (qui ne sert qu'à
    # compter les carrefours) — il faut aussi savoir LEUR LARGEUR.
    nd_marq = _noeuds_voirie(routes)
    passages_gardes, n_passage_croise = _passages_ville(
        routes, morceaux_voirie, nd_marq, chenal)
    st_marq = {"passages": 0, "bandes": 0, "traits": 0, "pleins": 0,
               "rives": 0, "tri": 0, "sur_eau": 0, "sans_trottoir": 0}
    # 🌊 Le bord de l'eau. `coul_quai` est LA MÊME variable que celle des murs
    # de berge du chenal, et ce n'est pas une économie : le mur qui porte un
    # quai et celui qui tient la rive sont le même ouvrage, souvent bout à bout.
    # Deux teintes proches se verraient comme un défaut de raccord.
    coul_chap = PAL.vers_lineaire(PAL.TROTTOIR)
    st_bord = {"pont": 0, "pont_m": 0.0, "pile": 0, "quai_m": 0.0,
               "parapet_m": 0.0, "parapet_coupe_m": 0.0, "sur_quai": 0.0,
               "bouts": 0, "tri": 0}
    plateformes = []
    ponts_vus = []
    murs_eau = []
    noeuds = set()
    for d in routes:
        for part in d["parts"]:
            for p in (part[0], part[-1]):
                noeuds.add((round(p[0] / 0.25), round(p[1] / 0.25)))
    # 🌊 LE QUAI SE PLANIFIE AVANT D'Être ÉMIS, et il lui faut deux choses
    # qu'aucun tronçon ne connaît tout seul : l'asphalte de TOUTE la ville
    # (sinon le débouché d'une rue perpendiculaire passe pour de l'eau) et les
    # tabliers (sinon un muret pousse sous un pont). Il s'émet ensuite dans la
    # boucle, tronçon par tronçon, pour tomber dans le bon groupe cliquable.
    tabliers = []
    # 🔴 UN PONT EMPORTÉ RESTE UN FRANCHISSEMENT. `franchis` part des axes
    # ENTIERS, pas des morceaux amputés par la crue : c'est lui qui coupe les
    # berges, et une berge ne doit pas fusionner avec sa voisine le jour où un
    # tablier tombe. `tabliers`, lui, ne connaît que ce qui est bâti — sans
    # quoi un muret pousserait sous un pont qui n'existe plus.
    franchis = []
    for d in routes:
        if not (d["largeur_m"] or 0.0) > 0.0:
            continue
        ch = min(D4.EMPRISE_CIRCULATION.get(d["hierarchie"], 8.5),
                 d["largeur_m"])
        for ip in range(len(d["parts"])):
            for axe_ in morceaux_voirie[d["fid"]][ip]:
                tabliers.extend(_tabliers(axe_, ch, chenal, relief))
            for axe_ in axes_voirie.get(d["fid"], ())[ip:ip + 1]:
                franchis.extend(_tabliers(axe_, ch, chenal, relief))
    decoupe_chaussee = DecoupeChaussees(routes, morceaux_voirie)
    plan_quai, st_quai, plat_quai, murs_quai, berges = _quais(
        chenal, relief, GrilleChaussee(chaussees, decoupe_chaussee), tabliers, franchis)
    plateformes.extend(plat_quai)
    murs_eau.extend(murs_quai)
    # Le pont a besoin du quai pour savoir ou finir son parapet ; le quai a
    # besoin des tabliers pour ne pas pousser dessous. L'ordre est donc :
    # tabliers (geometrie seule) -> quais -> emission des ponts.
    boites_quai = _boites(plat_quai)

    n_seg = 0
    n_tri_tr = 0
    # Deux compteurs de contrôle, en liste pour rester écrivables dans la
    # boucle : la promenade de quai et les places de rue peintes.
    n_promenade = 0
    n_places = [0]
    # 🔲 LE COULOIR DE CHAQUE TRONÇON, pour la silhouette de sélection.
    #
    # Un tronçon n'est PAS une surface : c'est la chaussée, plus les mètres
    # libres, plus un bout de trottoir par îlot riverain — trois choses
    # disjointes, séparées de 2,6 m sur le tronçon 120. Godot entourait donc
    # chacune, et une rue choisie ressortait en bandes parallèles.
    #
    # Ce qu'on exporte ici est ce qui les réunit : l'axe (le même que la
    # chaussée, coudes arrondis compris) et la largeur FAÇADE À FAÇADE. Godot
    # en fait un ruban plat, invisible, qui ne sert qu'à être détouré.
    couloirs = {}
    fentes_places = {}
    par_fid = {d["fid"]: d for d in routes}
    n_align_eau = 0
    n_align_chaussee = 0
    n_align_chaussee_t0 = 0
    alignements = {}
    for d in routes:
        larg = d["largeur_m"] or 0.0
        if larg <= 0.0:
            continue                            # 4 tronçons `rive` à 0 m
        ch = min(D4.EMPRISE_CIRCULATION.get(d["hierarchie"], 8.5), larg)
        voirie.marque(d["fid"])
        # ⚠️ UN SEUL GROUPE PAR TRONÇON, ouvert ici et pas dans la boucle des
        # morceaux : deux groupes de même fid donneraient deux nœuds de même
        # nom dans Godot, et un seul des deux se cacherait.
        places_m.marque(d["fid"])
        axes = []
        # 🌊 Un pont FRAGILE (04e) garde toute sa géométrie et prend le limon :
        # il passe encore, et il se voit qu'il a bu. Le pont EMPORTÉ, lui, a
        # déjà perdu ses morceaux au-dessus de l'eau.
        etat_crue = d.get("etat_crue") or "intact"
        if etat_crue == "coupe":
            repare_voirie.marque(d["fid"])
            ponts_ruine.marque(d["fid"])
            for axe_entier in axes_voirie.get(d["fid"], ()):
                manque = _axe_manque(axe_entier, chenal)
                if manque:
                    n_pont_ruine += _pont_ruine(
                        ponts_ruine, manque, larg, ch,
                        PAL.vers_lineaire(PAL.GRAVATS), coul_ch, coul_quai, G_voirie)
                    n_tablier_neuf += _pont_neuf(
                        repare_voirie, manque, larg, ch,
                        coul_tr, coul_ch, coul_quai, G_voirie, _bord_libre(d, ch), chenal)
                    n_tablier_neuf += _acces_pont(
                        repare_voirie, axe_entier, manque, larg, _bord_libre(d, ch),
                        coul_tr, G_voirie, decoupe_chaussee)
        # Le shader dépose le limon en coordonnées monde, sur tous les supports.
        lavage = (d.get("hauteur_eau") or 0.0) > 0.10 and etat_crue != "coupe"
        if lavage:
            repare_voirie.marque(d["fid"])
        coul_ch_d, coul_tr_d, coul_marq_d = coul_ch, coul_tr, coul_marq
        decoupe_chaussee.emettre_noeuds(voirie, d["fid"], coul_ch_d, G_voirie, Y_CHAUSSEE)
        if lavage:
            decoupe_chaussee.emettre_noeuds(repare_voirie, d["fid"], coul_ch, G_voirie,
                                           Y_CHAUSSEE + RELEVE)
        for ip, part in enumerate(d["parts"]):
            axe = axes_voirie[d["fid"]][ip]
            # 🅿️ LES MÈTRES LIBRES : ce qui reste entre le bord de l'asphalte
            # et le trottoir — 0,2 m sur une rue de 13 m, 1,65 m sur un
            # boulevard de 18. Une bande de sol nu que rien n'expliquait, et
            # c'est là que les voitures se garent.
            libre = _bord_libre(d, ch) - ch / 2.0
            for axe_ in morceaux_voirie[d["fid"]][ip]:
                decoupe_chaussee.emettre(voirie, axe_, ch, coul_ch_d, G_voirie,
                                         d["fid"], Y_CHAUSSEE)
                n_seg += len(axe_) - 1
                # Ils reçoivent l'asphalte : même teinte, même hauteur que la
                # chaussée — la file peinte suffit à dire ce que c'est.
                if libre > 0.05:
                    for sens in (-1.0, 1.0):
                        decoupe_chaussee.emettre(voirie, axe_, libre, coul_ch_d, G_voirie,
                               d["fid"], Y_CHAUSSEE,
                               decal=sens * (ch / 2.0 + libre / 2.0))
                # 🅿️ Les places peintes vont dans LEUR maillage, un groupe par
                # tronçon (ouvert plus haut) : Godot les efface quand la rue
                # n'a plus de stationnement.
                n_places[0] += _places_de_rue(
                    places_m, d, axe_, ip, ch, nd_marq, chenal, coul_marq_d, G_voirie,
                    fentes=fentes_places.setdefault(str(d["fid"]), []),
                    gardes=passages_gardes)
                if lavage:
                    _places_de_rue(repare_voirie, d, axe_, ip, ch, nd_marq,
                                   chenal, coul_marq, G_voirie, RELEVE,
                                   gardes=passages_gardes)
                # 🔧 LA MÊME RUE, LAVÉE, dans le maillage caché. Elle ne coûte
                # que sur les 36 tronçons envasés — ailleurs `lavage` est faux
                # et rien n'est émis.
                if lavage:
                    decoupe_chaussee.emettre(repare_voirie, axe_, ch, coul_ch, G_voirie,
                           d["fid"], Y_CHAUSSEE + RELEVE)
                    for sens in (-1.0, 1.0):
                        if libre > 0.05:
                            decoupe_chaussee.emettre(repare_voirie, axe_, libre, coul_ch, G_voirie,
                                   d["fid"], Y_CHAUSSEE + RELEVE,
                                   decal=sens * (ch / 2.0 + libre / 2.0))
                    _marquage(repare_voirie, d, axe_, ip, ch, nd_marq,
                              chenal, coul_marq, G_voirie, dy=RELEVE,
                              gardes=passages_gardes)
                # 🎨 Le marquage se pose SUR la chaussée qu'on vient d'émettre,
                # et dans le même groupe : cliquer une ligne blanche ouvre la
                # fiche de la rue, comme cliquer son trottoir.
                # ⚠️ Sur un pont emporté il tombe de lui-même : le marquage se
                # cale sur l'axe REÇU, et cet axe s'arrête au bord de l'eau.
                for k_, v_ in _marquage(voirie, d, axe_, ip, ch, nd_marq,
                                        chenal, coul_marq_d, G_voirie,
                                        gardes=passages_gardes).items():
                    st_marq[k_] += v_
                # 🌊 Le mur de quai et le pont, dans le GROUPE DU TRONÇON :
                # cliquer un parapet ou un tablier ouvre la fiche de la rue,
                # comme cliquer son trottoir. Un pont n'est pas un objet du jeu,
                # c'est un état de la route — et c'est déjà ce que dit le
                # creusement du chenal.
                k_, pl_, po_, mu_ = _bord_eau(voirie, axe_, ch, chenal, relief,
                                              coul_quai, coul_chap, G_voirie,
                                              boites_quai)
                for nom, v_ in k_.items():
                    st_bord[nom] += v_
                plateformes.extend(pl_)
                ponts_vus.extend(po_)
                murs_eau.extend(mu_)
            # ⚠️ Le COULOIR de sélection reste celui de l'axe ENTIER : on doit
            # pouvoir cliquer un pont détruit pour lire sa fiche.
            plat = []
            for pt in axe:
                g = G_voirie(pt[0], pt[1], 0.0)
                plat.append(round(g[0], 2))
                plat.append(round(g[2], 2))
            axes.append(plat)
        couloirs[str(d["fid"])] = [
            round(d.get("corridor_m", larg) + MARGE_COULOIR, 2), axes]
        # 🚶 Le trottoir de ce tronçon a été fabriqué par les ÎLOTS qui le
        # bordent, pas par lui — mais il est rangé sous SON fid, dans son
        # groupe : cliquer un trottoir ouvre la fiche de la rue.
        for f in trot.get(d["fid"], ()):
            if f[0] == "plat":
                n_tri_tr += _dessus_trottoir(voirie, f[1], coul_tr_d, G_voirie,
                                            decoupe=decoupe_chaussee)
                if lavage:
                    _dessus_trottoir(repare_voirie, f[1], coul_tr, G_voirie, RELEVE,
                                     decoupe=decoupe_chaussee)
            else:
                n_tri_tr += _bordure(voirie, f[1], f[2], f[3], coul_bord, G_voirie,
                                    decoupe=decoupe_chaussee)
                if lavage:
                    _bordure(repare_voirie, f[1], f[2], f[3], coul_bord, G_voirie,
                             RELEVE, decoupe=decoupe_chaussee)
        emplacements = [] if (d["hauteur_eau"] or 0.0) >= CRUE_ARBRE_NOYE_M             else _alignement(d, rng)
        # 🌊 Un franchissement reste une route pour la voirie, mais sa bande
        # plantable traverse le chenal. Avant ce filtre, le décalage latéral des
        # arbres de pont posait leurs troncs dans l'eau. On retire aussi les
        # emplacements futurs : augmenter la canopée ne doit jamais faire
        # apparaître un arbre dans l'Ilse.
        align_eau = [a for a in emplacements
                     if chenal.dans_eau((a[0], a[1]))]
        n_align_eau += len(align_eau)
        emplacements = [a for a in emplacements
                        if not chenal.dans_eau((a[0], a[1]))]
        # Un arbre est placé dans la bande libre de SON tronçon. Au carrefour,
        # cette bande peut pourtant être coupée par la chaussée d'UNE AUTRE
        # rue ; dans un coude, l'axe arrondi peut aussi la rattraper. Le filtre
        # porte donc sur toutes les chaussées affichées, et sur tous les
        # emplacements futurs : faire pousser la canopée ne doit pas révéler
        # plus tard un arbre au milieu de l'asphalte.
        align_chaussee = [a for a in emplacements
                          if _dans_chaussee((a[0], a[1]), chaussees,
                                           MARGE_TRONC_CHAUSSEE)]
        n_align_chaussee += len(align_chaussee)
        n_align_chaussee_t0 += sum(
            1 for a in align_chaussee
            if a[5] <= (d["canopee"] or 0.0))
        emplacements = [a for a in emplacements
                        if not _dans_chaussee((a[0], a[1]), chaussees,
                                             MARGE_TRONC_CHAUSSEE)]
        # Le pied suit le talus, comme celui des arbres semés. Un alignement
        # passe au ras d'un champ riverain : le décalage latéral suffit à
        # poser un tronc dans la pente, et il y flotterait.
        for a in emplacements:
            a[2] = relief.z(a[0], a[1])
        if emplacements:
            alignements[str(d["fid"])] = emplacements
    n_align = sum(len(v) for v in alignements.values())
    plantes_t0 = sum(1 for f, v in alignements.items()
                     for a in v
                     if a[5] <= (routes_par_fid[int(f)]["canopee"] or 0.0))
    # 🔧 CE QUE LA RÉPARATION TIENT PRÊT CÔTÉ VOIRIE. À zéro tablier neuf avec
    # un pont coupé, la décision « rebâtir » existerait sans rien à montrer.
    print("  ponts emportés : %d moignons de tablier visibles"
          " · rives gauche %.0f m / droite +%.0f m"
          % (n_pont_ruine, RIVE_GAUCHE_Y, RIVE_DROITE_Y))
    print("  réparation : %d tronçons lavés, %d tablier(s) neuf(s) prêt(s)"
          % (sum(1 for g in repare_voirie.groupes
                 if (par_fid.get(g[0], {}).get("etat_crue") or "") != "coupe"),
             sum(1 for g in repare_voirie.groupes
                 if (par_fid.get(g[0], {}).get("etat_crue") or "") == "coupe")))
    print("  voirie : %d segments de chaussée, %d triangles"
          % (n_seg, len(voirie)))
    print("        couloirs de sélection : %d tronçons, %.1f m de large en"
          " moyenne (largeur_m + %.1f)"
          % (len(couloirs),
             sum(v[0] for v in couloirs.values()) / max(len(couloirs), 1),
             MARGE_COULOIR))
    print("        courbes : %d coudes internes, %d marqués (≥ %.0f°),"
          " %d arrondis — les %d carrefours gardent leur angle"
          % (n_coude, n_marque, COUDE_MIN_DEG, n_rond, len(noeuds)))
    print("        places de rue : %d peintes sur %d annoncées par `04`"
          "  %s"
          % (n_places[0], sum(int(d["stationnement"] or 0) for d in routes),
             "✅" if n_places[0] else "❌ aucune file peinte"))
    print("        trottoir : %d îlots bordés, %.2f km de bordure,"
          " marche de %.0f cm, %d triangles"
          % (st_tr["ilots"], st_tr["long"] / 1000.0,
             HAUTEUR_BORDURE * 100.0, n_tri_tr))
    print("        %d arêtes d'emprise sur %d longent une rue, %d ont la place"
          " d'un trottoir de %.1f m"
          % (st_tr["avec_rue"], st_tr["aretes"], st_tr["avec_trottoir"],
             LARGEUR_TROTTOIR))
    print("        %d coins de trottoir, dont %d arrondis — %d coudes le sont"
          " des DEUX bords, donc à largeur de rue constante"
          % (st_tr["coins"], st_tr["arrondis"], st_tr["coudes_entiers"]))
    tr_ = [d["bord_trottoir_m"] for d in routes if d["bord_trottoir_m"] > 0.0]
    print("        %d tronçons sur %d où un piéton a un trottoir — il marche à"
          " %.1f–%.1f m de l'axe ; les %d autres marchent au bord de la chaussée"
          % (len(tr_), len(routes), min(tr_), max(tr_), len(routes) - len(tr_)))
    print("        marquage : %d passages piétons (%d bandes de %.2f m),"
          " %d traits d'axe, %d pleins de virage, %d lignes de rive"
          % (st_marq["passages"], st_marq["bandes"], PASSAGE_BANDE,
             st_marq["traits"], st_marq["pleins"], st_marq["rives"]))
    print("        %d tronçons trop étroits pour un trottoir, donc sans"
          " passage · %d passages refusés au-dessus de l'Ilse · %d retirés"
          " parce qu'ils en croisaient un autre · %d triangles"
          % (st_marq["sans_trottoir"], st_marq["sur_eau"], n_passage_croise,
             st_marq["tri"]))
    # 🌊 LE CORPS DES BERGES, groupe par groupe. Hors de la boucle des routes :
    # une berge n'appartient à aucun tronçon, c'est justement ce qui en fait un
    # objet. 🔄 Le mur tombait dans le groupe de la RUE jusqu'au 2026-08-26 —
    # cliquer un parapet ouvrait la fiche du tronçon.
    rng_rive = random.Random(GRAINE ^ 0xB3E6)
    berges_couloir = {}
    coul_pente = (PAL.vers_lineaire(PAL.SOLS["parc"]),
                  PAL.vers_lineaire(PAL.melanger(PAL.MINERAL_CLAIR,
                                                 "#000000", 0.45)))
    # Tout ce qui est POSÉ SUR LA RIVE prend le niveau de sa rive, y compris
    # sur la ligne d'eau elle-même — voir `_cale_rive`.
    def G_rive(x, y, alt):
        return G(x, y, alt + _cale_rive(chenal, x, y))

    # Les promenades dégagent aussi le tablier futur et ses trottoirs.
    for fid, poly, _ in passages_ponts.polys:
        decoupe_chaussee.ajouter(fid, poly)
    for b in berges:
        n_promenade += _promenade_berge(terre, b, coul_tr, G_rive, decoupe_chaussee)
        murs_m.marque(b["fid"])
        b["tri"] = _emettre_quai(murs_m, plan_quai.get(b["fid"], ()),
                                 coul_quai, coul_chap, G_rive, chenal, passages_ponts)
        berges_m.marque(b["fid"])
        b["tri"] += _bande_berge(berges_m, b, coul_berge, G_rive, relief, passages_ponts)
        pentes_m.marque(b["fid"])
        b["tri"] += _pente_berge(pentes_m, b, coul_pente[0], coul_pente[1],
                                 G_eau, chenal)
        # 🌿 Le semis, pas le maillage : il ne rentre dans aucun groupe, c'est
        # Godot qui en fait un MultiMesh quand la berge est rendue au fleuve.
        # Son tirage est À PART — pris sur `rng`, il déplacerait les arbres.
        b["semis"] = _semis_berge(b, rng_rive, relief, chenal)
        # ✏️ LE RUBAN D'UNE BERGE — sa SILHOUETTE de sélection, pas sa
        # géométrie. Même raison que pour un tronçon : mur, couronnement et
        # bande sont trois surfaces disjointes et fines, et les détourer une à
        # une donnait quatre traits parallèles pour un seul objet. Deux rails
        # par station, tout entiers CÔTÉ TERRE : de la ligne d'eau au fond de
        # la rive — ce que la chaussée laisse en ville, le talus en campagne.
        # 🔴 IL SUIT LA BANDE, station par station : c'est elle que la décision
        # change. En campagne, c'est le talus.
        rails = []
        for i in range(b["i0"], b["i1"] + 1):
            pt, e = b["net"][i], b["eau"][i]
            large = _large_berge(b, i) + BERGE_TRAIT_MARGE \
                if b["prendre"][i] else TALUS_LARGEUR
            g0 = G(pt[0], pt[1], 0.0)
            g1 = G(pt[0] - e[0] * large, pt[1] - e[1] * large, 0.0)
            rails.append([round(g0[0], 2), round(g0[2], 2),
                          round(g1[0], 2), round(g1[2], 2)])
        berges_couloir[str(b["fid"])] = rails
    berges_m.fermer()
    murs_m.fermer()
    pentes_m.fermer()
    print("        promenade continue : %d triangles, bord partagé avec la rive"
          % n_promenade)
    st_bord["tri"] += sum(b["tri"] for b in berges)

    # 🌊 LE BORD DE L'EAU. Le compte rendu tient en trois lignes parce que la
    # règle tient en trois lignes : qui traverse prend un pont, qui longe prend
    # un mur, et le contrôle dit combien d'asphalte reste en l'air.
    aire_eau, aire_cache, aire_dela, depasse = _asphalte_en_lair(
        routes, coudes, chenal, plateformes, murs_eau, morceaux_voirie)
    print("  bord de l'eau : %d ponts (%.0f m de tablier, %d piles),"
          " %.2f km de quai porté en %d longueurs"
          % (st_bord["pont"], st_bord["pont_m"], st_bord["pile"],
             st_quai["quai_m"] / 1000.0, st_quai["runs"]))
    print("        parapet de %.2f m : %.2f km · mur avancé sur l'eau :"
          " %.2f km · %d morceaux cliquables, sans joint visible"
          % (PARAPET_H,
             (st_bord["parapet_m"] + st_quai["parapet_m"]) / 1000.0,
             st_quai["avance_m"] / 1000.0, st_quai["morceaux"]))
    # 🌉 CE QUI A ÉTÉ COUPÉ AUX PONTS, ET C'EST LE CONTRÔLE DU 2026-08-19 :
    # le parapet d'un pont ne doit border que l'eau libre. Ce qui est retiré
    # ici est ce qui montait sur la terre ou sur le quai — donc en travers de
    # la voie de berge. Le compte de bouts dit qu'il en reste UN par joue :
    # deux, et le muret se serait coupé au milieu d'une travée.
    print("        parapet de pont : %.0f m gardés sur l'eau en %d bouts"
          " (%d attendus) · retirés : %.0f m sur le quai, %.0f m sur la terre"
          "  %s"
          % (st_bord["parapet_m"], st_bord["bouts"], 2 * st_bord["pont"],
             st_bord["sur_quai"],
             st_bord["parapet_coupe_m"] - st_bord["sur_quai"],
             "✅" if st_bord["bouts"] == 2 * st_bord["pont"]
             else "❌ un muret coupé en deux"))
    # 🔴 LE CHIFFRE QUI PROUVE QUE LE MUR LONGE LE FLEUVE : il est bâti À
    # PARTIR de la berge, donc son écart à elle EST son avancée sur l'eau, et
    # rien d'autre. Avant le 2026-08-19 le mur était un décalé de la route et
    # cet écart dérivait jusqu'à 8,1 m sans que personne puisse le dire.
    print("        berge : %.0f m de rive suivie · refusé : %d stations"
          " (%.0f m) de talus de champ, %d (%.0f m) sans chaussée à %.0f m,"
          " %d (%.0f m) sous un tablier"
          % (st_quai["quai_m"],
             st_quai["talus"], st_quai["talus"] * QUAI_PAS,
             st_quai["campagne"], st_quai["campagne"] * QUAI_PAS,
             QUAI_PORTEE,
             st_quai["tablier"], st_quai["tablier"] * QUAI_PAS))
    # 🌊 LES BERGES, ET LE CONTRÔLE EST LEUR NOMBRE : trois franchissements
    # coupent chaque rive en quatre biefs, donc HUIT berges. Moins, c'est qu'un
    # bief est tombé sous les 15 m et a rejoint sa voisine ; plus, c'est que la
    # recousue des arêtes s'est brisée ailleurs qu'à un tablier.
    attendu = 2 * (len(franchis) + 1)
    print("  berges : %d objets cliquables — %d franchissements coupent chaque"
          " rive en %d, donc %d attendues · %d biefs courts rattachés  %s"
          % (st_quai["berges"], len(franchis), len(franchis) + 1, attendu,
             st_quai["rattachees"],
             "✅" if st_quai["berges"] == attendu
             else "⚠️ vérifier la coupe aux franchissements"))
    for b in berges:
        print("        %2d  rive %-7s %6.0f m  mur %5.0f m  asphalte sur l'eau"
              " %6.0f m² (max %.1f m) · rive libre %4.1f m  rues : %s"
              % (b["fid"], b["rive"], b["longueur_m"], b["mur_m"],
                 b["debord_m2"], b["debord_max_m"], b["rive_m"],
                 ", ".join(str(f) for f in b["rues"]) or "aucune"))
    # 🌿 LE CONTRÔLE DE LA PENTE : une rive rendue doit ENTRER dans l'eau. Sans
    # ce talus, renaturer ne faisait que verdir un mur vertical (2026-09-02).
    y_haut = Y_TROTTOIR + BERGE_Y
    pente_m = sum(
        _longueur(b["net"], i, i + 1)
        for b in berges for i in range(b["i0"], b["i1"])
        if b["prendre"][i] and not b["sous"][i])
    print("        talus des rives rendues : %.0f m de mur remplacés par une"
          " pente de %.1f m à %.0f°  %s"
          % (pente_m, PENTE_RIVE_M,
             math.degrees(math.atan2(y_haut - FOND_ILSE, PENTE_RIVE_M)),
             "✅" if pente_m > 100.0 else "⚠️ la rive rendue resterait un mur"))
    n_ros = sum(1 for b in berges for a in b["semis"] if a[5] == SEMIS_ROSEAU)
    n_bui = sum(1 for b in berges for a in b["semis"] if a[5] == SEMIS_BUISSON)
    print("        semis des rives rendues : %d touffes de roseaux + %d buissons"
          " sur %.0f m de berge  %s"
          % (n_ros, n_bui, sum(b["longueur_m"] for b in berges),
             "✅" if n_ros and n_bui
             else "⚠️ une rive rendue sortirait en aplat vert"))
    print("        asphalte au-dessus du chenal : %.0f m², porté à %.1f %% ·"
          " %.0f m² masqués derrière un parapet · %.0f m² au-delà"
          " (dépassement max %.2f m)  %s"
          % (aire_eau,
             100.0 * (aire_eau - aire_cache - aire_dela) / max(aire_eau, 1e-9),
             aire_cache, aire_dela, depasse,
             # 🔄 Le seuil était relatif seul, et il ne veut plus rien dire :
             # depuis que le corridor se colle aux façades il ne reste que
             # 13 m² d'asphalte au-dessus du chenal, dont 1 m² au bout d'une
             # amorce. 2 m² sur toute la ville ne se voient pas.
             "✅" if aire_dela <= max(2.0, 0.002 * aire_eau)
             else "❌ à regarder"))
    print("        %d triangles" % st_bord["tri"])
    if n_champ:
        print("  champs : %d îlots, chacun sa teinte, découpés en %d bandes"
              " de fauche de %.0f m" % (n_champ, n_bande, BANDE_CHAMP))
    if n_maille_talus:
        # Deux choses à prouver, et une seule ligne pour les deux : que le sol
        # des champs DESCEND SOUS l'eau (sans quoi il n'y a pas de trait de
        # rive, juste une lèvre de terre qui affleure), et que la plaque reste
        # dessous (sans quoi elle ressort par la pente).
        bas_sol = min(p[1] for p in sols.v)
        print("        talus : %d mailles, le sol descend à %.2f m — sous la"
              " nappe (%.2f m) %s, plaque dessous à %.2f m %s"
              % (n_maille_talus, bas_sol, NAPPE_ILSE,
                 "✅" if bas_sol < NAPPE_ILSE else "❌",
                 bas_plaque, "✅" if bas_plaque < bas_sol else "❌"))
    # 🅿️ LE SEUL CONTRÔLE QUI CONFRONTE DEUX CHAÎNES. Partout ailleurs, ce
    # qu'on imprime est mesuré sur ce qu'on vient de dessiner. Ici, la
    # géométrie répond à un nombre calculé par `04` sans elle, et l'écart est
    # un vrai résultat : au-delà de ~10 %, c'est que l'un des deux ment.
    for f_, n_pl_, n_tr_, annonce, n_arb, n_dedans in parkings:
        ecart = 100.0 * (n_pl_ - annonce) / max(annonce, 1)
        print("  place-parking (îlot %d) : %d places rangées, %d annoncées"
              " par 04 — écart %+.0f %% %s"
              % (f_, n_pl_, annonce, ecart,
                 "✅" if abs(ecart) <= 10.0 else "❌ à regarder"))
        print("        trame parallèle à la plus longue façade · module"
              " %.0f m (allée %.0f + deux rangées de %.0f) · place %.2f × %.2f m"
              % (MODULE_PARKING, ALLEE_PARKING, PLACE_LONGUEUR,
                 PLACE_LARGEUR, PLACE_LONGUEUR))
        print("        %d traits peints, %d triangles, %.0f m de retrait au"
              " bord — le sol nu par où on entre"
              % (n_tr_, n_tri_parc, BORD_PARKING))
        print("        %d arbres plantés sur la place, dont %d sur la trame %s"
              % (n_arb, n_dedans, "✅" if n_dedans == 0 else "❌ à regarder"))
    print("  arbres : %d semés dans les îlots" % len(arbres))
    print("  alignements : %d emplacements sur %d tronçons plantables, "
          "%d occupés à t0"
          % (n_align, len(alignements), plantes_t0))
    arbres_dans_chaussee = sum(
        1 for a in arbres
        if _dans_chaussee((a[0], a[1]), chaussees,
                          MARGE_TRONC_CHAUSSEE))
    align_dans_chaussee = sum(
        1 for v in alignements.values() for a in v
        if _dans_chaussee((a[0], a[1]), chaussees,
                          MARGE_TRONC_CHAUSSEE))
    print("        chaussée : %d arbres semés + %d emplacements écartés"
          " (dont %d visibles à t0) · arbres restants : %d  %s"
          % (arbres_ecartes_chaussee, n_align_chaussee,
             n_align_chaussee_t0,
             arbres_dans_chaussee + align_dans_chaussee,
             "✅" if arbres_dans_chaussee + align_dans_chaussee == 0
             else "❌"))
    if arbres_dans_chaussee or align_dans_chaussee:
        raise SystemExit("Des arbres restent dans la chaussée.")
    arbres_dans_eau = sum(1 for a in arbres
                          if chenal.dans_eau((a[0], a[1])))
    align_dans_eau = sum(1 for v in alignements.values() for a in v
                         if chenal.dans_eau((a[0], a[1])))
    print("        %d emplacements de pont écartés · arbres dans l'eau : %d  %s"
          % (n_align_eau, arbres_dans_eau + align_dans_eau,
             "✅" if arbres_dans_eau + align_dans_eau == 0 else "❌"))
    if arbres_dans_eau or align_dans_eau:
        raise SystemExit("Des arbres restent dans le polygone de la rivière.")
    print("  canopée non représentable (îlots bâtis) : %.1f ha"
          % (canopee_perdue / 1e4))

    # -------------------------------------------------------------- écrire
    for m in (masses, sols, eau, voirie, places_m):
        m.fermer()
    n_groupes = sum(len(m.groupes) for m in (masses, sols, eau, voirie))
    n_gi = len(masses.groupes) + len(sols.groupes) + len(eau.groupes)
    print("  groupes cliquables : %d îlots sur %d, %d tronçons sur %d"
          % (n_gi, len(ilots), len(voirie.groupes), len(routes)))
    if n_gi != len(ilots):
        print("    ⚠️  des îlots ne seront pas cliquables — anneau dégénéré ?")

    doc = {
        "meta": {
            "source": os.path.basename(GPKG),
            "crs": "EPSG:%d" % 25832,
            "centre": [round(cx, 3), round(cy, 3)],
            "emprise_m": [round(maxx - minx, 1), round(maxy - miny, 1)],
            "etage_m": ETAGE_M,
            "y_terrain": Y_TERRAIN,
        },
        "palette": PAL.pour_json(),
        # 🌊 LE CONTRAT DE LA CRUE. `04e` dit la hauteur d'eau, `07` la bande de
        # rive qu'une berge rend ; `ville.gd` n'a plus qu'à multiplier.
        "crue": {
            "niveau_annonce_m": D4E.NIVEAU_ANNONCE_M,
            "baisses_m": list(D4E.BAISSES_M),
            "berge_bande_m": BERGE_BANDE_M,
        },
        # 🔄 C'ÉTAIT UN CHAMP D'ALTITUDE (`x0, z0, pas, nx, nz, alt`) que Godot
        # dépliait en grille. La carte étant plate, c'est un maillage comme les
        # autres : Godot n'a plus qu'UNE façon de lire de la géométrie.
        "boue": carte_boue(ilots, routes, chenal, cx, cy),
        "terrain": terre.json(),
        "paysage": paysage(maxx - minx, maxy - miny, chenal, cx, cy),
        "masses": masses.json(),
        # 🔧 LA VILLE RÉPARÉE, groupe par groupe, jamais montrée au chargement.
        # Le bâti neuf d'un îlot ruiné, et le tablier neuf d'un franchissement
        # emporté : les deux seules géométries qui apparaissent en cours de
        # partie, et elles sont calculées ici comme tout le reste.
        "repare": repare.json(),
        "repare_voirie": repare_voirie.json(),
        # 🅿️ Les places peintes, un groupe par tronçon : Godot les cache quand
        # la rue n'en a plus.
        "places": places_m.json(),
        "sols": sols.json(),
        "eau": eau.json(),
        # 🌊 Le corps des berges, un groupe par berge, en trois maillages :
        # la bande de rive, le mur de quai, et le talus qui remplace le mur
        # quand la rive est rendue au fleuve. Godot montre l'un OU l'autre.
        "berges": berges_m.json(),
        "berges_mur": murs_m.json(),
        "berges_pente": pentes_m.json(),
        "voirie": voirie.json(),
        "ponts_ruine": ponts_ruine.json(),
        # Déjà en repère Godot : [x, y, z, échelle, lacet]. Godot ne fait
        # aucune conversion de coordonnées, c'est la règle du contrat.
        "arbres": [[round(c, 2) for c in G(a[0], a[1], a[2])]
                   + [round(a[3], 3), round(a[4], 3), int(a[5])]
                   for a in arbres],
        # Les emplacements d'alignement, avec leur seuil de canopée. Godot en
        # fait UN MultiMesh et n'affiche que ceux dont le seuil est atteint —
        # c'est là que le temps se voit sans lire un chiffre.
        "alignements": {
            f: [[round(c, 2) for c in G(a[0], a[1], a[2])]
                + [round(a[3], 3), round(a[4], 3), round(a[5], 4)] for a in v]
            for f, v in alignements.items()
        },
        # 🌿 Ce qui pousse sur chaque berge une fois rendue au fleuve, déjà en
        # repère Godot. Godot n'en montre que les berges renaturées : c'est le
        # semis, et pas une teinte, qui fait lire la décision.
        "berges_semis": {
            str(b["fid"]): [[round(c, 2) for c in G(a[0], a[1], a[2])]
                            + [round(a[3], 3), round(a[4], 3), int(a[5])]
                            for a in b["semis"]]
            for b in berges
        },
        # Les deux rails du ruban de rive, déjà en repère Godot :
        # [[x_eau, z_eau, x_terre, z_terre], …]. Godot n'en fait pas une berge,
        # il en fait la SILHOUETTE qu'il détoure quand on la choisit.
        "berges_couloir": berges_couloir,
        # La fiche qu'on lit en cliquant, et l'état de départ du noyau.
        "objets": {
            "ilots": {str(f): dict({c: d[c] for c in FICHE_ILOTS},
                                   **{c: d[c]
                                      for c in TOIT_ILOTS + DENSE_ILOTS
                                      if c in d})
                      for f, d in ilots.items()},
            "routes": {str(d["fid"]): {c: d[c] for c in FICHE_ROUTES}
                       for d in routes},
            # 🌊 La fiche d'une berge : ce qui est MESURÉ sur la carte, rien de
            # plus. `debord_m2` est l'asphalte que le quai a pris à l'Ilse ;
            # `rive_m`, la largeur de rive qui reste entre la chaussée et
            # l'eau. 🔴 Depuis le 2026-08-31 le premier est tombé à ~0 sur les
            # huit berges — la rue ne vole plus le fleuve, elle le longe — et
            # `ville.berge_largeur_rendue_m` en dépend encore : le quai apaisé
            # ne rachète plus rien. Le nombre de remplacement est du LEVEL
            # DESIGN, il est mesuré ici et il attend l'auteur.
            "berges": {str(b["fid"]): {
                "rive": b["rive"],
                "longueur_m": round(b["longueur_m"], 1),
                "mur_m": round(b["mur_m"], 1),
                "debord_m2": b["debord_m2"],
                "debord_max_m": b["debord_max_m"],
                "rive_m": b["rive_m"],
                "rues": b["rues"],
                "fil_amont": round(b["fil_amont"], 3),
                "fil_aval": round(b["fil_aval"], 3),
            } for b in berges},
        },
        # L'axe et la largeur façade à façade de chaque tronçon, déjà en
        # repère Godot : [largeur, [[x, z, x, z…], …]]. Godot n'en fait pas une
        # route — il en fait la SILHOUETTE qu'il détoure quand on la choisit.
        "couloirs": couloirs,
        "places_rue": {f: v for f, v in fentes_places.items() if v},
        # L'emprise au sol de chaque îlot, déjà en repère Godot : [[x, y, z], …],
        # anneau OUVERT. Jamais affichée — c'est la moitié basse du masque de
        # sélection, celle que la silhouette rendue ne peut pas donner.
        "emprises": emprises,
        "riverains": {str(f): sorted(v) for f, v in r2i.items()},
        "reperes": _reperes(ilots, routes, cx, cy, relief, ponts_vus),
        "controles": {
            "ilots": len(ilots), "routes": len(routes),
            "berges": len(berges),
            "masses": n_masse, "sols": n_sol, "eau": n_eau,
            "triangles": (len(terre) + len(masses) + len(sols) + len(eau)
                          + len(voirie) + len(ponts_ruine)),
            "arbres": len(arbres),
            "alignements": n_align,
            "groupes": n_groupes,
        },
    }

    os.makedirs(os.path.dirname(SORTIE), exist_ok=True)
    with open(SORTIE, "w", encoding="utf-8", newline="\n") as f:
        json.dump(doc, f, ensure_ascii=False, separators=(",", ":"))
    ko = os.path.getsize(SORTIE) / 1024.0
    print("\n→ %s  (%.0f Ko)" % (os.path.relpath(SORTIE, RACINE), ko))


def _reperes(ilots, routes, cx, cy, relief=None, ponts=()):
    """Les points de vue du clavier. Une touche par critère de réussite :
    on ne juge pas de mémoire (`Plan 3 mois.md:48`)."""
    def centre(fid):
        a = ilots[fid]["brut"]
        return [round(sum(p[0] for p in a) / len(a) - cx, 2),
                round(-(sum(p[1] for p in a) / len(a) - cy), 2)]

    quai = [d for d in routes if (d["largeur_m"] or 0) >= 20.0]
    qp = [0.0, 0.0]
    if quai:
        pts = [p for d in quai for part in d["parts"] for p in part]
        qp = [round(sum(p[0] for p in pts) / len(pts) - cx, 2),
              round(-(sum(p[1] for p in pts) / len(pts) - cy), 2)]

    # 🌊 Le point de vue sur l'Ilse. C'est là que le chenal se juge : deux
    # mètres de mur au-dessus de l'eau sur toute la longueur du quai, et le
    # tablier des trois franchissements qui passe au-dessus sans y plonger.
    eau_pts = [p for x in ilots.values() if x["sous_type"] == "riviere"
               for p in x["brut"]]
    ip = [0.0, 0.0]
    if eau_pts:
        ip = [round(sum(p[0] for p in eau_pts) / len(eau_pts) - cx, 2),
              round(-(sum(p[1] for p in eau_pts) / len(eau_pts) - cy), 2)]

    # 🌾 Et le point de vue sur le TALUS, qui n'existait pas : les quatre
    # autres sont tous posés sur la ville, où le sol est plat. Sans lui le
    # relief demandé le 2026-08-18 ne se voit sur aucune capture d'essai — donc
    # il n'existe pas (§3 bis). Visé sur le milieu de la plus longue rive de
    # champ, celle du champ 6, en aval.
    bp = list(ip)
    if relief is not None and relief.zones:
        f = max(relief.zones, key=lambda k: relief.zones[k]["longueur"])
        pts = [p for a in relief.zones[f]["riv"] for p in a]
        bp = [round(sum(p[0] for p in pts) / len(pts) - cx, 2),
              round(-(sum(p[1] for p in pts) / len(pts) - cy), 2)]
    # 🌉 ET LE POINT DE VUE SUR LE PLUS LONG FRANCHISSEMENT. `ilse` regarde le
    # chenal de haut : à 260 m d'étendue, un tablier de 70 cm et une pile ne
    # sont pas jugeables. Le pont est visé de près, et c'est là qu'on voit s'il
    # passe AU-DESSUS de l'eau au lieu de flotter dedans.
    # 🅿️ Le point de vue sur la place-parking. Il n'est pas visé sur un fid
    # écrit ici : c'est l'îlot de SOL qui porte des places, et il n'y en a
    # qu'un. 130 m d'étendue — une place de 2,5 m ne se juge pas à 1 200.
    pm = [f for f, x in ilots.items()
          if (x["hauteur"] or 0.0) <= 0.0 and (x["stationnement"] or 0) > 0]
    place = {"cible": centre(pm[0]) if pm else [0.0, 0.0],
             "taille": 130.0,
             "libelle": "La place-parking et ses places"}

    pp, ptaille = ip, 260.0
    if ponts:
        L, mil = max(ponts, key=lambda x: x[0])
        pp = [round(mil[0] - cx, 2), round(-(mil[1] - cy), 2)]
        ptaille = round(L * 2.2, 1)

    # 🌊 LE FAUBOURG SINISTRÉ (23b). Sans ce point de vue, la crue ne se juge
    # sur aucune capture : `ville` la montre à 1 200 m d'étendue, où une ruine
    # fait deux pixels. Visé sur le barycentre des îlots de RIVE GAUCHE qui ont
    # bu — donc il suit la table de `04e` au lieu d'une liste de fid écrite ici.
    noyes = [f for f, x in ilots.items()
             if x.get("rive") == "gauche" and (x.get("hauteur_eau_max") or 0) > 0
             and (x["hauteur"] or 0.0) > 0.0]
    fb = [0.0, 0.0]
    if noyes:
        cs = [centre(f) for f in noyes]
        fb = [round(sum(c[0] for c in cs) / len(cs), 2),
              round(sum(c[1] for c in cs) / len(cs), 2)]
    # 🌉 Et le pont EMPORTÉ, visé sur son milieu : c'est un trou, donc rien ne
    # le signale sur une vue d'ensemble. `pont` vise le plus LONG, qui n'est
    # pas forcément celui que la crue a pris.
    casse = [d for d in routes if (d.get("etat_crue") or "") == "coupe"]
    cp, ctaille = pp, 150.0
    if casse:
        pts = [q for d in casse for part in d["parts"] for q in part]
        cp = [round(sum(q[0] for q in pts) / len(pts) - cx, 2),
              round(-(sum(q[1] for q in pts) / len(pts) - cy), 2)]

    return {
        # 🔄 C'était « la vallée ». Il n'y a plus de vallée : la carte est
        # plate. Le point de vue, lui, sert toujours — c'est la ville entière.
        "ville": {"cible": [0.0, 0.0], "taille": 1200.0,
                  "libelle": "Wehrau en entier"},
        "barre": {"cible": centre(32), "taille": 220.0,
                  "libelle": "La barre de 1974 (ilot 32)"},
        "pans_solaire": {"cible": centre(22), "taille": 115.0,
                         "libelle": "Les panneaux, pan par pan"},
        # Les deux époques récentes ont le toit PLAT : de haut, c'est la seule
        # vue où ça se voit, et les cinq percées du 49 avec.
        "compact": {"cible": centre(49), "taille": 170.0,
                    "libelle": "L'ilot compact, toit plat et percees"},
        "quai": {"cible": qp, "taille": 160.0,
                 "libelle": "Les rues a 20 et 22 m"},
        "ilse": {"cible": ip, "taille": 260.0,
                 "libelle": "L'Ilse canalisee et les ponts"},
        "berge": {"cible": bp, "taille": 200.0,
                  "libelle": "Le talus des champs, au bord de l'eau"},
        "pont": {"cible": pp, "taille": ptaille,
                 "libelle": "Le plus long franchissement, tablier et pile"},
        "place": place,
        "faubourg": {"cible": fb, "taille": 420.0,
                     "libelle": "Le faubourg sinistre, rive gauche"},
        "pont_casse": {"cible": cp, "taille": ctaille,
                       "libelle": "Le pont emporte par la crue"},
    }


if __name__ == "__main__":
    for flux in (sys.stdout, sys.stderr):
        try:
            flux.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, OSError):
            pass
    main()
