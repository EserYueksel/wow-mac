#!/bin/bash
# qcow2-grow.sh BILD NEUE_GROESSE_IN_GIB
# Vergroessert die virtuelle Größe eines qcow2-Abbilds (wie "qemu-img resize", nur Vergroessern),
# ohne qemu-img: Es werden nur die Kopffelder "size" und "l1_size" angepasst. Das geht, wenn die
# vorhandene L1-Tabelle in ihren Clustern Platz für die zusaetzlichen Eintraege hat (bei Ubuntu-
# Cloud-Images immer der Fall). Andernfalls bricht das Skript ohne Aenderung ab.
# Nur macOS-Bordmittel (od, dd, printf); läuft mit /bin/bash 3.2.
set -u
IMG=${1:?Bild fehlt}
GIB=${2:?Größe in GiB fehlt}

die() { echo "qcow2-grow: $*" >&2; exit 1; }
# u N OFFSET -> vorzeichenlose Big-Endian-Zahl mit N Bytes
u() { local h; h=$(od -v -An -tx1 -j "$2" -N "$1" "$IMG" | tr -d ' \n'); [ ${#h} -eq $(($1*2)) ] || die "Lesefehler bei $2"; echo $((16#$h)); }
# w N OFFSET WERT -> schreibt WERT als Big-Endian mit N Bytes (ohne die Datei zu kuerzen)
w() {
  local n=$1 off=$2 v=$3 i fmt="" b
  for ((i=n-1; i>=0; i--)); do b=$(( (v >> (i*8)) & 255 )); fmt="$fmt$(printf '\\%03o' "$b")"; done
  # shellcheck disable=SC2059  # Format enthaelt bewusst Oktal-Escapes
  printf "$fmt" | dd of="$IMG" bs=1 seek="$off" conv=notrunc 2>/dev/null || die "Schreibfehler bei $off"
}

[ -f "$IMG" ] && [ -w "$IMG" ] || die "$IMG nicht vorhanden oder nicht beschreibbar"
[ "$(od -v -An -tx1 -N 4 "$IMG" | tr -d ' \n')" = "514649fb" ] || die "kein qcow2-Abbild"
ver=$(u 4 4);            [ "$ver" = 2 ] || [ "$ver" = 3 ] || die "qcow2-Version $ver nicht unterstützt"
[ "$(u 8 8)" = 0 ] || die "Abbild mit Backing-File nicht unterstützt"
cb=$(u 4 20);            [ "$cb" -ge 9 ] && [ "$cb" -le 21 ] || die "cluster_bits $cb ungültig"
size=$(u 8 24)
[ "$(u 4 32)" = 0 ] || die "verschluesselte Abbilder nicht unterstützt"
l1=$(u 4 36); l1off=$(u 8 40)
[ "$(u 4 60)" = 0 ] || die "Abbild enthält Snapshots"
if [ "$ver" = 3 ]; then
  inc=$(u 8 72)
  # erlaubt ist nur Bit 3 (Kompressionsart); dirty/corrupt/external data/extended L2 -> Abbruch
  [ $(( inc & ~8 )) = 0 ] || die "incompatible_features=$inc nicht unterstützt"
fi
cs=$((1 << cb))
new=$((GIB * 1024 * 1024 * 1024))
[ "$new" -gt "$size" ] || { echo "qcow2-grow: schon $((size/1024/1024)) MiB gross - nichts zu tun"; exit 0; }
per_l1=$(( cs * (cs / 8) ))                      # Bytes, die ein L1-Eintrag abdeckt
need=$(( (new + per_l1 - 1) / per_l1 ))
[ "$l1" -ge 1 ] || die "leere L1-Tabelle"
alloc=$(( (l1 * 8 + cs - 1) / cs * cs ))        # belegte Bytes der L1-Tabelle (ganze Cluster)
[ $((need * 8)) -le "$alloc" ] || die "L1-Tabelle zu klein für $GIB GiB (braucht $need, Platz für $((alloc/8)))"
if [ "$need" -gt "$l1" ]; then
  z=$(od -v -An -tx1 -j $((l1off + l1 * 8)) -N $(( (need - l1) * 8 )) "$IMG" | tr -d ' \n0')
  [ -z "$z" ] || die "unerwartete Daten hinter der L1-Tabelle - Abbruch ohne Aenderung"
  w 4 36 "$need"
fi
w 8 24 "$new"
[ "$(u 8 24)" = "$new" ] && [ "$(u 4 36)" -ge "$need" ] || die "Prüfung nach dem Schreiben fehlgeschlagen"
echo "qcow2-grow: $((size/1024/1024)) MiB -> $((new/1024/1024)) MiB (L1 $l1 -> $(u 4 36))"
