#!/bin/zsh
# Lance un outil Godot sans fenêtre visible ni prise de main durable (Mac) : voir scripts/discret.gd.
#   Godot/outils/discret.sh res://outils/apercu_date.gd -- --ouverture
# Godot s'active seul au lancement (aucune option ne l'empêche) : on rend la main dès qu'il l'a prise.
GODOT=${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}
cd "${0:A:h}/.."
avant=$(lsappinfo info -only bundleid "$(lsappinfo front)" | sed 's/.*="//;s/"$//')
DESIRE_PATH_DISCRET=1 "$GODOT" --path . --audio-driver Dummy --resolution 1x1 --position 20000,20000 \
	--script "$@" &
godot=$!
for i in {1..200}; do
	[[ "$(lsappinfo info -only pid "$(lsappinfo front)")" == *"=$godot" ]] && { open -b "$avant"; break }
	kill -0 $godot 2>/dev/null || break
	sleep 0.05
done
wait $godot
