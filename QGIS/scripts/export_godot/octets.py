# -*- coding: utf-8 -*-
"""Les tableaux de sommets sortent du JSON vers un fichier binaire voisin, compressé (zlib).
Chaque bloc est au format de `var_to_bytes` : Godot le relit par `bytes_to_var`, sans conversion.
Mêmes nombres : Godot les passait déjà en float32 à la lecture du JSON."""

import hashlib
import json
import sys
import zlib
from array import array
from itertools import chain
from pathlib import Path

# clé → (type Variant de Godot 4, composantes par sommet, bourrage)
# 🔴 Bourrage = ce que `constructeur.gd` mettait quand la colonne manquait.
BLOCS = {
    "v": (36, 3, ()),               # PackedVector3Array
    "n": (36, 3, ()),
    "c": (37, 4, (1.0,)),           # PackedColorArray, alpha 1 si absent
    "uv": (35, 2, ()),              # PackedVector2Array
    "uv2": (35, 2, ()),
    "dense": (32, 4, (0.0, 0.0)),   # PackedFloat32Array à plat, CUSTOM0
}
INDICES = 30                        # PackedInt32Array


def _est_maillage(d):
    # Un renvoi `octets` porte aussi v, n, c, i, mais en [début, longueur].
    return (isinstance(d, dict) and all(isinstance(d.get(k), list) for k in "vnci")
            and (not d["v"] or isinstance(d["v"][0], list)))


def _plat(lignes, largeur, bourrage):
    for ligne in lignes:
        manque = largeur - len(ligne)
        if manque < 0 or manque > len(bourrage):
            raise ValueError("ligne de %d valeurs pour %d attendues" % (len(ligne), largeur))
        yield chain(ligne, bourrage[len(bourrage) - manque:])


# Godot compte les ÉLÉMENTS : des vecteurs pour 35 à 37, des nombres seuls pour 30 et 32.
PAR_ELEMENT = {30: 1, 32: 1, 35: 2, 36: 3, 37: 4}


def _bloc(type_, valeurs, code):
    a = array(code, valeurs)
    if sys.byteorder != "little":
        a.byteswap()
    return array("I", [type_, len(a) // PAR_ELEMENT[type_]]).tobytes() + a.tobytes()


def separer(doc, chemin_bin):
    """Retire les tableaux de chaque maillage de `doc` et les écrit dans `chemin_bin`.
    Chaque maillage reçoit `octets` : {clé: [début, longueur]}, positions dans le
    binaire DÉCOMPRESSÉ ; `meta.binaire` porte sa taille et l'empreinte du fichier."""
    morceaux, pos = [], 0

    def ajouter(refs, cle, b):
        nonlocal pos
        refs[cle] = [pos, len(b)]
        morceaux.append(b)
        pos += len(b)

    def ranger(m):
        refs, nv = {}, len(m["v"])
        for cle, (type_, largeur, bourrage) in BLOCS.items():
            if cle not in m:
                continue
            lignes = m.pop(cle)
            if len(lignes) != nv:
                raise ValueError("maillage : %d lignes de `%s` pour %d sommets" % (len(lignes), cle, nv))
            ajouter(refs, cle, _bloc(type_, chain.from_iterable(_plat(lignes, largeur, bourrage)), "f"))
        i = m.pop("i")
        ajouter(refs, "i", _bloc(INDICES, i, "i"))
        m["octets"] = refs

    def parcourir(x):
        if isinstance(x, dict):
            if _est_maillage(x):
                ranger(x)
                return
            for v in x.values():
                parcourir(v)

    parcourir(doc)
    # Godot ne cherche les maillages que dans les dictionnaires : un oublié dans une liste partirait en JSON.
    reste = []

    def chercher(x, chemin):
        if _est_maillage(x):
            reste.append(chemin)
        elif isinstance(x, dict):
            for k, v in x.items():
                chercher(v, chemin + "." + k)
        elif isinstance(x, list):
            for k, v in enumerate(x):
                if isinstance(v, (dict, list)):
                    chercher(v, "%s[%d]" % (chemin, k))

    chercher(doc, "")
    if reste:
        raise ValueError("maillages dans une liste, non sortis : " + ", ".join(reste))
    # Niveau 6 : 50 Mo → 5 Mo en 0,3 s ; Godot décompresse en 0,04 s.
    z = zlib.compress(b"".join(morceaux), 6)
    with open(chemin_bin, "wb") as f:
        f.write(z)
    # L'empreinte entre dans le JSON : la somme du JSON, qui date les sauvegardes, suit le binaire.
    doc["meta"]["binaire"] = {"taille": pos, "md5": hashlib.md5(z).hexdigest()}
    return len(z)


def lire(chemin_json):
    """L'export tel qu'il était avant la séparation : listes Python, valeurs en float32."""
    chemin_json = Path(chemin_json)
    doc = json.loads(chemin_json.read_text(encoding="utf-8"))
    z = chemin_json.with_suffix(".bin").read_bytes()
    if hashlib.md5(z).hexdigest() != doc["meta"].get("binaire", {}).get("md5"):
        raise ValueError("%s ne correspond pas à %s : relancer 07" % (
            chemin_json.with_suffix(".bin").name, chemin_json.name))
    brut = zlib.decompress(z)

    def deplier(m):
        for cle, (debut, longueur) in m.pop("octets").items():
            code = "i" if cle == "i" else "f"
            a = array(code)
            a.frombytes(brut[debut + 8:debut + longueur])
            if sys.byteorder != "little":
                a.byteswap()
            if cle == "i":
                m[cle] = a.tolist()
            else:
                largeur = BLOCS[cle][1]
                m[cle] = [a[k:k + largeur].tolist() for k in range(0, len(a), largeur)]

    def parcourir(x):
        if isinstance(x, dict):
            if isinstance(x.get("octets"), dict):
                deplier(x)
            for v in x.values():
                parcourir(v)

    parcourir(doc)
    return doc
