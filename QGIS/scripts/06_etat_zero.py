#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
06 — L'état zéro de Wehrau, en une page qu'on regarde.

    python3 QGIS/scripts/06_etat_zero.py

Sort QGIS/rendus/etat_zero.html : la carte cliquable, tous les calques dans un
seul fichier, et les stocks de la ville à t0 calculés à côté.

Pourquoi une page et pas un PNG de plus : `apercu_carte.py` sort un calque par
exécution. Vingt-deux attributs, c'est vingt-deux commandes et autant d'images à
comparer de mémoire. Ici on clique et la carte change, et on survole un îlot
pour lire toutes ses colonnes. C'est la boucle « je vois donc je corrige ».

Lecture seule (GeoPackage ouvert en `ro`), aucune dépendance : sqlite3 et le
lecteur WKB d'apercu_carte. Le HTML est autonome — aucun appel réseau, il
s'ouvre par double-clic sur les deux machines.
"""

import json
import math
import os
import sqlite3
import sys

ICI = os.path.dirname(os.path.abspath(__file__))
RACINE = os.path.dirname(os.path.dirname(ICI))
sys.path.insert(0, ICI)

from apercu_carte import gpkg_vers_wkb, lire_wkb  # noqa: E402

# `python3 06_etat_zero.py une_copie.gpkg` pour regarder une autre version
_ARGS = [a for a in sys.argv[1:] if not a.startswith("--")]
GPKG = _ARGS[0] if _ARGS else os.path.join(RACINE, "QGIS", "data",
                                           "travail", "wehrau.gpkg")
SORTIE = os.path.join(RACINE, "QGIS", "rendus", "etat_zero.html")

# Le coefficient qui transforme un stock de bâti en stock d'habitants. Il vit
# dans 04, avec le reste du design : ici on le lit, on ne le redéfinit pas.
from importlib import import_module  # noqa: E402
MENAGE = import_module("04_deriver_attributs").PERSONNES_PAR_LOGEMENT

# Les calques proposés. (champ, libellé, type, unité)
# `cat` = catégoriel (palette fixe), `num` = dégradé.
CALQUES_ILOTS = [
    ("fonction", "Fonction", "cat", ""),
    ("sous_type", "Sous-type", "cat", ""),
    ("rive", "Rive", "cat", ""),
    ("logements", "Logements", "num", ""),
    ("emplois", "Emplois", "num", ""),
    ("densite", "Densité", "num", " log/ha"),
    ("hauteur", "Hauteur", "num", " niv."),
    ("impermeabilise", "Imperméabilisé", "num", ""),
    ("canopee", "Canopée", "num", ""),
    ("stationnement", "Stationnement", "num", " places"),
    ("riverain", "Fragilité riverain", "num", ""),
    ("desserte_tc", "Desserte TC", "num", ""),
    # 2026-08-12 : plus de calque d'aléa ni d'altitude — la carte est plate et
    # la crue sort du prototype. Les deux colonnes valent 0 partout ; un calque
    # d'une seule couleur ne dit rien et fait croire qu'il dit quelque chose.
    ("position_fil_eau", "Fil de l'eau", "num", ""),
    ("surface_m2", "Surface", "num", " m²"),
]
CALQUES_ROUTES = [
    ("hierarchie", "Hiérarchie", "cat", ""),
    ("largeur_m", "Largeur", "num", " m"),
    ("emprise_libre_m", "Emprise libre", "num", " m"),
    ("charge", "Charge de trafic", "num", ""),
    ("stationnement", "Places sur rue", "num", ""),
    ("canopee", "Canopée d'alignement", "num", ""),
]

COLS_I = [c[0] for c in CALQUES_ILOTS] + ["fid", "exception", "bord_carte_m"]
COLS_R = [c[0] for c in CALQUES_ROUTES] + ["fid"]

PALETTE = {
    "freiraum": "#8fbf6a", "habitation": "#e8c46a", "industrie": "#b08d6a",
    "mixte": "#d99b6c", "riviere": "#6ba8d9",
    "gauche": "#d98b6c", "droite": "#6c9dd9", "lit": "#6ba8d9",
    "autoroute": "#c1443c", "boulevard": "#d98b3c", "rue": "#7a7a7a",
    "ruelle": "#adadad", "rive": "#6ba8d9", "voie ferree": "#6b4f8a",
}
# Palette de secours pour les 12 sous-types, dans l'ordre d'apparition.
ROUE = ["#e8c46a", "#8fbf6a", "#d98b6c", "#6c9dd9", "#b08d6a", "#c8a2c8",
        "#9dc6a0", "#d9b86c", "#7fa8b8", "#c1443c", "#6b8f5a", "#bfa06a",
        "#8a7fa8", "#d9d06c"]


def verifier_colonnes(con, table, cols):
    """Un message clair plutôt qu'un « no such column » de sqlite.

    `emplois` est arrivé dans 04 après coup : sans ce contrôle, un dépôt
    fraîchement tiré plante sans dire qu'il manque juste un maillon."""
    presentes = {r[1] for r in con.execute("PRAGMA table_info(%s)" % table)}
    manque = [c for c in cols if c not in presentes]
    if manque:
        raise SystemExit(
            "Colonnes absentes de `%s` : %s\n"
            "Relancer d'abord :  python3 QGIS/scripts/04_deriver_attributs.py"
            % (table, ", ".join(manque)))


def lire():
    con = sqlite3.connect("file:%s?mode=ro" % GPKG, uri=True)
    verifier_colonnes(con, "ilots", COLS_I)
    verifier_colonnes(con, "routes", COLS_R)
    ilots, routes = [], []
    for r in con.execute("SELECT %s, geom FROM ilots ORDER BY fid" % ",".join(COLS_I)):
        anneaux, _ = lire_wkb(gpkg_vers_wkb(r[-1]))
        d = dict(zip(COLS_I, r[:-1]))
        d["_geom"] = anneaux
        ilots.append(d)
    for r in con.execute("SELECT %s, geom FROM routes ORDER BY fid" % ",".join(COLS_R)):
        parts, _ = lire_wkb(gpkg_vers_wkb(r[-1]))
        d = dict(zip(COLS_R, r[:-1]))
        d["_geom"] = parts
        d["longueur_m"] = sum(
            math.hypot(b[0] - a[0], b[1] - a[1])
            for p in parts for a, b in zip(p, p[1:])
        )
        routes.append(d)
    con.close()
    return ilots, routes


def stocks(ilots, routes):
    """Les stocks de la ville à t0. Un stock = ce qui bouge et qu'on regarde bouger."""
    bati = [i for i in ilots if i["fonction"] != "riviere"]
    surf = sum(i["surface_m2"] for i in bati)
    eau = sum(i["surface_m2"] for i in ilots if i["fonction"] == "riviere")
    log = sum(i["logements"] for i in bati)
    pond = lambda ch: sum(i["surface_m2"] * i[ch] for i in bati) / surf
    ml = sum(r["longueur_m"] for r in routes)
    stat_rue = sum(r["stationnement"] for r in routes)
    stat_ilot = sum(i["stationnement"] for i in bati)
    fragile = sum(i["logements"] * i["riverain"] for i in bati)
    tc = sum(i["logements"] for i in bati if i["desserte_tc"] > 0.7)
    emplois = sum(i["emplois"] for i in bati)
    act = sum(i["surface_m2"] for i in bati if i["emplois"])
    bat = sum(i["surface_m2"] for i in bati if i["sous_type"] != "champ")
    g = [i for i in bati if i["rive"] == "gauche"]
    d = [i for i in bati if i["rive"] == "droite"]

    return [
        ("L'assiette", [
            ("Surface urbanisée", "%.1f ha" % (surf / 1e4), ""),
            ("Rivière", "%.1f ha" % (eau / 1e4), "l'Ilse est un îlot, pas une ligne"),
            ("Îlots", "%d" % len(ilots), "dont %d de rivière" % (len(ilots) - len(bati))),
            ("Voirie", "%.1f km" % (ml / 1000), "%d tronçons" % len(routes)),
        ]),
        ("Les gens", [
            ("Logements", "%d" % log, ""),
            ("Habitants", "≈ %d" % round(log * MENAGE),
             "dérivé : %d × %.1f — aucune colonne ne le porte" % (log, MENAGE)),
            ("Ménages fragiles", "%d" % round(fragile),
             "%.0f %% du parc, pondéré par riverain" % (100 * fragile / log)),
            ("Emplois", "%d" % emplois,
             "%.2f par habitant — un dortoir" % (emplois / (log * MENAGE))),
            ("Sol d'activité", "%.1f ha" % (act / 1e4),
             "%.0f %% du sol bâti, industrie et mixte" % (100 * act / bat)),
        ]),
        ("Le sol", [
            ("Imperméabilisé", "%.1f ha" % (pond("impermeabilise") * surf / 1e4),
             "%.0f %% de la surface" % (100 * pond("impermeabilise"))),
            ("Canopée", "%.1f ha" % (pond("canopee") * surf / 1e4),
             "%.0f %% de la surface" % (100 * pond("canopee"))),
        ]),
        ("La voiture", [
            ("Places de stationnement", "%d" % (stat_rue + stat_ilot),
             "%d sur rue, %d hors rue" % (stat_rue, stat_ilot)),
            ("Places par habitant", "%.2f" % ((stat_rue + stat_ilot) / (log * MENAGE)),
             "c'est ça, la voiture-dépendance"),
            ("Logements bien desservis en TC", "%d" % tc,
             "%.0f %% du parc (desserte > 0,7)" % (100 * tc / log)),
        ]),
        # ⏸️ La crue sort du prototype (2026-08-12) : plus de logements exposés,
        # plus d'aléa moyen par rive. Ce qui reste de l'eau est ce qui reste
        # vrai sans elle — deux rives inégales, et trois ponts.
        ("L'eau", [
            ("Rive gauche", "%d logements" % sum(i["logements"] for i in g),
             "%d îlots" % len(g)),
            ("Rive droite", "%d logements" % sum(i["logements"] for i in d),
             "%d îlots" % len(d)),
            ("Franchissements", "3", "sans eux le réseau tombe en deux morceaux"),
        ]),
        ("Les ressources", [
            ("Budget d'investissement", "100 pts / an", "⚠ posé, pas tranché"),
            ("Capital politique", "50 / 100", "un seul chiffre — décision 16b"),
        ]),
    ]


def svg(ilots, routes):
    xs = [p[0] for i in ilots for a in i["_geom"] for p in a]
    ys = [p[1] for i in ilots for a in i["_geom"] for p in a]
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    W = 1000.0
    H = W * (y1 - y0) / (x1 - x0)
    k = W / (x1 - x0)
    T = lambda p: ("%.1f,%.1f" % ((p[0] - x0) * k, H - (p[1] - y0) * k))

    out = ['<svg id="carte" viewBox="0 0 %.0f %.0f" xmlns="http://www.w3.org/2000/svg">' % (W, H)]
    out.append('<g id="gi">')
    for i in ilots:
        d = " ".join("M" + " L".join(T(p) for p in a) + " Z" for a in i["_geom"])
        out.append('<path class="il" data-fid="%d" d="%s"/>' % (i["fid"], d))
    out.append("</g><g id=\"gr\">")
    for r in routes:
        for part in r["_geom"]:
            d = "M" + " L".join(T(p) for p in part)
            out.append('<path class="ro" data-fid="%d" d="%s"/>' % (r["fid"], d))
    out.append("</g></svg>")
    return "\n".join(out), H


GABARIT = u"""<!doctype html>
<html lang="fr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Wehrau — état zéro</title>
<style>
:root{--fd:#14161a;--pan:#1b1e24;--bd:#2c313a;--tx:#e6e8ec;--gr:#9aa2b1;--ac:#e8c46a;--vd:#2a2e36}
@media(prefers-color-scheme:light){:root{--fd:#f4f2ee;--pan:#fff;--bd:#dcd8d0;--tx:#1a1c20;--gr:#6d7480;--ac:#9a6b1f;--vd:#e8e4dc}}
*{box-sizing:border-box}
body{margin:0;background:var(--fd);color:var(--tx);
 font:14px/1.5 ui-sans-serif,system-ui,"Segoe UI",Roboto,sans-serif}
header{padding:22px 26px 14px;border-bottom:1px solid var(--bd)}
h1{margin:0;font-size:20px;font-weight:600;letter-spacing:-.01em}
h1 small{color:var(--gr);font-weight:400;font-size:14px;margin-left:10px}
.wrap{display:grid;grid-template-columns:minmax(0,1fr) 340px;gap:0;align-items:start}
@media(max-width:900px){.wrap{grid-template-columns:1fr}}
.gauche{padding:18px 26px 40px;min-width:0}
aside{padding:18px 26px 40px;border-left:1px solid var(--bd);position:sticky;top:0}
@media(max-width:900px){aside{border-left:0;border-top:1px solid var(--bd);position:static}}
.onglets{display:flex;gap:6px;margin-bottom:10px}
.onglets button{flex:0 0 auto;background:none;border:1px solid var(--bd);color:var(--gr);
 padding:5px 12px;border-radius:99px;cursor:pointer;font:inherit;font-size:13px}
.onglets button.on{background:var(--ac);border-color:var(--ac);color:var(--fd);font-weight:600}
.calques{display:flex;flex-wrap:wrap;gap:5px;margin-bottom:14px}
.calques button{background:var(--vd);border:1px solid transparent;color:var(--tx);
 padding:4px 10px;border-radius:5px;cursor:pointer;font:inherit;font-size:12.5px}
.calques button:hover{border-color:var(--gr)}
.calques button.on{background:var(--ac);color:var(--fd);font-weight:600}
svg{width:100%;height:auto;display:block;background:var(--pan);
 border:1px solid var(--bd);border-radius:8px}
path.il{stroke:var(--fd);stroke-width:.9;cursor:pointer}
path.il:hover{stroke:var(--tx);stroke-width:2.4}
path.il.sel{stroke:var(--tx);stroke-width:3}
path.ro{fill:none;stroke-linecap:round;cursor:pointer}
path.ro:hover{stroke-width:6}
.legende{display:flex;align-items:center;gap:14px;flex-wrap:wrap;margin-top:12px;
 color:var(--gr);font-size:12.5px}
.legende .sw{display:inline-block;width:11px;height:11px;border-radius:3px;
 margin-right:5px;vertical-align:-1px}
.rampe{height:11px;width:150px;border-radius:3px}
.bloc{margin-bottom:22px}
.bloc h2{margin:0 0 9px;font-size:11px;font-weight:700;letter-spacing:.09em;
 text-transform:uppercase;color:var(--ac)}
.st{display:flex;justify-content:space-between;align-items:baseline;gap:12px;
 padding:6px 0;border-bottom:1px solid var(--bd)}
.st:last-child{border-bottom:0}
.st .k{color:var(--gr);font-size:13px}
.st .v{font-weight:600;font-variant-numeric:tabular-nums;white-space:nowrap}
.st .n{color:var(--gr);font-size:11.5px;flex-basis:100%;margin-top:-4px}
#fiche{background:var(--pan);border:1px solid var(--bd);border-radius:8px;
 padding:13px 15px;margin-bottom:22px;min-height:96px}
#fiche .t{font-weight:600;margin-bottom:8px}
#fiche .g{display:grid;grid-template-columns:auto auto;gap:2px 14px;font-size:12.5px}
#fiche .g div:nth-child(odd){color:var(--gr)}
#fiche .g div:nth-child(even){text-align:right;font-variant-numeric:tabular-nums}
#fiche .vide{color:var(--gr);font-size:13px}
</style></head><body>
<header><h1>Wehrau, état zéro <small>@@SOUS@@</small></h1></header>
<div class="wrap">
<div class="gauche">
  <div class="onglets">
    <button id="oi" class="on">Îlots</button><button id="or">Rues</button>
  </div>
  <div class="calques" id="cal"></div>
  @@SVG@@
  <div class="legende" id="leg"></div>
</div>
<aside>
  <div id="fiche"><div class="vide">Survole un îlot ou une rue.</div></div>
  @@STOCKS@@
</aside>
</div>
<script>
const I=@@DI@@, R=@@DR@@, CI=@@CI@@, CR=@@CR@@, PAL=@@PAL@@, ROUE=@@ROUE@@;
let couche='i', champ='fonction';
const $=s=>document.querySelector(s), gi=$('#gi'), gr=$('#gr');
const cats={};
function coul(v,c,ext){
  if(v===null||v===undefined||v==='')return 'var(--vd)';
  if(c[2]==='cat'){
    if(PAL[v])return PAL[v];
    cats[c[0]]=cats[c[0]]||{};
    if(!(v in cats[c[0]]))cats[c[0]][v]=ROUE[Object.keys(cats[c[0]]).length%ROUE.length];
    return cats[c[0]][v];
  }
  const t=ext[1]>ext[0]?(v-ext[0])/(ext[1]-ext[0]):0;
  // dégradé unique : bleu froid (bas) → jaune → rouge (haut)
  const s=[[42,74,110],[90,140,150],[214,190,110],[196,84,62]];
  const x=t*(s.length-1), j=Math.min(Math.floor(x),s.length-2), f=x-j;
  const m=k=>Math.round(s[j][k]+(s[j+1][k]-s[j][k])*f);
  return `rgb(${m(0)},${m(1)},${m(2)})`;
}
function nb(v,u){
  if(v===null||v===undefined||v==='')return '—';
  if(typeof v!=='number')return v;
  const d=Math.abs(v)>=1000?0:Math.abs(v)>=10?1:2;   // virgule décimale française
  return v.toLocaleString('fr-FR',{maximumFractionDigits:d})+u;
}
function peindre(){
  const D=couche==='i'?I:R, C=(couche==='i'?CI:CR).find(c=>c[0]===champ);
  const vals=Object.values(D).map(o=>o[champ]).filter(v=>typeof v==='number');
  const ext=[Math.min(...vals),Math.max(...vals)];
  gi.querySelectorAll('path').forEach(p=>{
    const o=I[p.dataset.fid];
    if(couche==='i'){p.setAttribute('fill',coul(o[champ],C,ext));p.setAttribute('opacity',1);}
    else{p.setAttribute('fill','var(--vd)');p.setAttribute('opacity',.55);}
  });
  gr.querySelectorAll('path').forEach(p=>{
    const o=R[p.dataset.fid];
    if(couche==='r'){p.setAttribute('stroke',coul(o[champ],C,ext));p.setAttribute('stroke-width',3.2);}
    else{p.setAttribute('stroke','var(--fd)');p.setAttribute('stroke-width',1.1);}
  });
  legende(C,ext,D);
}
function legende(C,ext,D){
  if(C[2]==='cat'){
    const u=[...new Set(Object.values(D).map(o=>o[C[0]]))].filter(v=>v!==null&&v!=='');
    u.sort();
    $('#leg').innerHTML=u.map(v=>{
      const n=Object.values(D).filter(o=>o[C[0]]===v).length;
      return `<span><span class="sw" style="background:${coul(v,C,ext)}"></span>${v} <span style="opacity:.6">${n}</span></span>`;
    }).join('');
  }else{
    const g=[0,.25,.5,.75,1].map(t=>coul(ext[0]+t*(ext[1]-ext[0]),C,ext)).join(',');
    $('#leg').innerHTML=`<span>${nb(ext[0],C[3])}</span>`
      +`<span class="rampe" style="background:linear-gradient(90deg,${g})"></span>`
      +`<span>${nb(ext[1],C[3])}</span><span style="opacity:.7">${C[1]}</span>`;
  }
}
function boutons(){
  const C=couche==='i'?CI:CR;
  $('#cal').innerHTML=C.map(c=>`<button data-c="${c[0]}"${c[0]===champ?' class="on"':''}>${c[1]}</button>`).join('');
  $('#cal').querySelectorAll('button').forEach(b=>b.onclick=()=>{champ=b.dataset.c;boutons();peindre();});
}
function fiche(o,kind){
  const C=kind==='i'?CI:CR;
  $('#fiche').innerHTML=`<div class="t">${kind==='i'?'Îlot':'Tronçon'} ${o.fid}`
    +(kind==='i'?` — ${o.sous_type}`:` — ${o.hierarchie}`)+`</div><div class="g">`
    +C.filter(c=>c[2]==='num'||kind==='i'&&c[0]==='rive')
       .map(c=>`<div>${c[1]}</div><div>${nb(o[c[0]],c[3])}</div>`).join('')
    +(kind==='i'&&o.exception?'<div>Exception</div><div>oui</div>':'')+`</div>`;
}
gi.querySelectorAll('path').forEach(p=>{
  p.onmouseenter=()=>{if(couche==='i')fiche(I[p.dataset.fid],'i');};
});
gr.querySelectorAll('path').forEach(p=>{
  p.onmouseenter=()=>{if(couche==='r')fiche(R[p.dataset.fid],'r');};
});
$('#oi').onclick=()=>{couche='i';champ='fonction';$('#oi').classList.add('on');
  $('#or').classList.remove('on');boutons();peindre();};
$('#or').onclick=()=>{couche='r';champ='hierarchie';$('#or').classList.add('on');
  $('#oi').classList.remove('on');boutons();peindre();};
boutons();peindre();
</script></body></html>
"""


def html(ilots, routes):
    corps, _ = svg(ilots, routes)
    di = {i["fid"]: {k: v for k, v in i.items() if k != "_geom"} for i in ilots}
    dr = {r["fid"]: {k: v for k, v in r.items() if k != "_geom"} for r in routes}

    blocs = []
    for titre, lignes in stocks(ilots, routes):
        rows = "".join(
            '<div class="st"><span class="k">%s</span><span class="v">%s</span>%s</div>'
            % (k, v, ('<span class="n">%s</span>' % n) if n else "")
            for k, v, n in lignes
        )
        blocs.append('<div class="bloc"><h2>%s</h2>%s</div>' % (titre, rows))

    bati = [i for i in ilots if i["fonction"] != "riviere"]
    sous = "%d îlots · %d tronçons · %.0f ha · aucune décision prise" % (
        len(ilots), len(routes),
        sum(i["surface_m2"] for i in bati) / 1e4)

    J = lambda o: json.dumps(o, ensure_ascii=False)
    page = GABARIT
    for cle, val in [
        ("SVG", corps), ("SOUS", sous), ("STOCKS", "".join(blocs)),
        ("DI", J(di)), ("DR", J(dr)), ("CI", J(CALQUES_ILOTS)),
        ("CR", J(CALQUES_ROUTES)), ("PAL", J(PALETTE)), ("ROUE", J(ROUE)),
    ]:
        page = page.replace("@@%s@@" % cle, val)
    return page


def main():
    if not os.path.exists(GPKG):
        sys.exit("Introuvable : %s — lancer 02 → 03 → 04 d'abord." % GPKG)
    ilots, routes = lire()
    os.makedirs(os.path.dirname(SORTIE), exist_ok=True)
    page = html(ilots, routes)
    with open(SORTIE, "w", encoding="utf-8", newline="\n") as f:
        f.write(page)
    print("%d îlots, %d tronçons, %d calques" % (
        len(ilots), len(routes), len(CALQUES_ILOTS) + len(CALQUES_ROUTES)))
    print("HTML   %.0f Ko  →  %s" % (len(page.encode("utf-8")) / 1024, SORTIE))


if __name__ == "__main__":
    main()
