uniform sampler2D boue_carte : filter_linear, repeat_disable;
uniform vec4 boue_repere = vec4(0.0, 0.0, 1.0, 1.0);
uniform bool boue_active = false;

float boue_hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float boue_bruit(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(boue_hash(i), boue_hash(i + vec2(1.0, 0.0)), f.x),
        mix(boue_hash(i + vec2(0.0, 1.0)), boue_hash(i + vec2(1.0)), f.x), f.y);
}
float boue_nettoyage_acces(vec2 p, vec4 acces, float largeur) {
    vec2 axe = acces.zw - acces.xy;
    float longueur = length(axe);
    if (longueur < 0.01) return 1.0;
    float s = dot(p - acces.xy, axe / longueur);
    float distance_bout = min(s, longueur - s);
    float irregularite = boue_bruit(p * 0.38) * 2.0 + boue_bruit(p * 1.3) * 0.5;
    // Les accès gardent le dépôt voisin ; le tablier devient propre en quelques mètres.
    float bout = smoothstep(1.0 + irregularite, 7.0 + irregularite, distance_bout);
    float travers = abs(dot(p - acces.xy, vec2(-axe.y, axe.x) / longueur));
    float cote = smoothstep(0.0, 2.0 + irregularite * 0.5, largeur * 0.5 - travers);
    return bout * mix(cote, 1.0, smoothstep(8.0, 16.0, distance_bout));
}
vec4 depot_boue_local(vec3 p, float hauteur, float rive) {
    if (hauteur < 0.04 || p.y > 3.0 || p.y < -1.8) return vec4(0.0);
    vec2 derive = vec2(boue_bruit(p.xz * 0.12), boue_bruit(p.zx * 0.13 + 41.0)) - 0.5;
    float large = boue_bruit(p.xz * 0.28 + derive * 2.0);
    float veinage = boue_bruit(p.xz * vec2(0.38, 0.85) + derive * 3.0);
    float fin = boue_bruit(p.xz * 2.6);
    float bord = smoothstep(0.12 + large * 0.65, 0.70 + large * 1.25, hauteur);
    float laisse = rive + min(hauteur * 0.30, 1.45) + (large - 0.5) * 0.42;
    float murs = 1.0 - smoothstep(laisse - 0.18, laisse + 0.17, p.y);
    float net = 1.0 - smoothstep(0.3, 1.1, length(fwidth(p.xz)));
    vec3 terre = mix(vec3(0.205, 0.151, 0.087), vec3(0.29, 0.218, 0.125), large);
    terre *= 0.92 + veinage * 0.15 + (fin - 0.5) * 0.10 * net;
    float epaisseur = smoothstep(0.6, 2.5, hauteur);
    float couverture = mix(mix(0.53, 0.85, veinage), mix(0.90, 0.98, veinage), epaisseur);
    return vec4(terre, bord * murs * couverture);
}
vec4 depot_boue(vec3 p) {
    if (!boue_active || p.y > 3.0 || p.y < -1.8) return vec4(0.0);
    vec2 derive = vec2(boue_bruit(p.xz * 0.12), boue_bruit(p.zx * 0.13 + 41.0)) - 0.5;
    vec2 uv = (p.xz + derive * 9.0 - boue_repere.xy) / boue_repere.zw;
    if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) return vec4(0.0);
    vec2 carte = texture(boue_carte, uv).rg;
    return depot_boue_local(p, carte.r * 6.0, carte.g * 2.0 - 1.0);
}
