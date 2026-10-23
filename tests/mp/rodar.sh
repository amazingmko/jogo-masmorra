#!/bin/bash
# Roda anfitrião e convidado juntos nesta máquina. Uso: tests/mp/rodar.sh <godot>
G=${1:-godot}
D=$(mktemp -d)
cd "$(dirname "$0")/../.."
MPDIR=$D timeout 120 $G --headless --fixed-fps 60 --path . --script res://tests/mp/host.gd > $D/host.log 2>&1 &
H=$!
MPDIR=$D timeout 120 $G --headless --fixed-fps 60 --path . --script res://tests/mp/client.gd > $D/client.log 2>&1 &
C=$!
wait $H; wait $C
grep -hE "^\[(host|convidado)\]|SCRIPT ERROR" -A2 $D/host.log $D/client.log
