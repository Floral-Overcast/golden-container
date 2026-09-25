#!/bin/bash
# ct.sh - golden-template clone lifecycle on a Proxmox host.
# Usage: ct.sh new <name> [repo-path] | ls | start <name> | stop <name> | rm <name> [--purge]
# Env:   GOLDEN_ID   template CTID              (default 220)
#        GOLDEN_IP   template's static IP       (default 192.0.2.220; clones get
#                    the same /24 with their CTID as the last octet)
#        CT_RANGE    CTIDs usable for clones    (default "212 213 214 215 216 217 218 219")
#        CT_MEM      host dir for per-clone work/memory (default /root/ct-mem)
set -eu
GOLDEN_ID="${GOLDEN_ID:-220}"
GOLDEN_IP="${GOLDEN_IP:-192.0.2.220}"
CT_RANGE="${CT_RANGE:-212 213 214 215 216 217 218 219}"
CT_MEM="${CT_MEM:-/root/ct-mem}"
NET="${GOLDEN_IP%.*}"   # e.g. 192.0.2

die() { echo "ct: $*" >&2; exit 1; }

id_of() {  # name -> CTID
  pct list | awk -v n="$1" '$3 == n {print $1}'
}

case "${1:-}" in
  new)
    NAME="${2:?usage: ct.sh new <name> [repo-path]}"; REPO="${3:-}"
    [ -n "$(id_of "$NAME")" ] && die "'$NAME' already exists"
    ID=""
    for c in $CT_RANGE; do pct status "$c" >/dev/null 2>&1 || { ID="$c"; break; }; done
    [ -n "$ID" ] || die "no free CTID in range ($CT_RANGE)"
    pct status "$GOLDEN_ID" | grep -q stopped || die "template $GOLDEN_ID must be stopped to clone"
    pct clone "$GOLDEN_ID" "$ID" --hostname "$NAME"
    CONF="/etc/pve/lxc/$ID.conf"
    sed -i "s#ip=$GOLDEN_IP/24#ip=$NET.$ID/24#" "$CONF"
    sed -i 's/,hwaddr=[^,]*//' "$CONF"
    mkdir -p "$CT_MEM/$NAME/memory" "$CT_MEM/$NAME/work"
    [ -d "$CT_MEM/golden/memory" ] && cp -r "$CT_MEM/golden/memory/." "$CT_MEM/$NAME/memory/"
    printf 'mp0: %s,mp=/memory\nmp1: %s,mp=/work\n' \
      "$CT_MEM/$NAME/memory" "$CT_MEM/$NAME/work" >> "$CONF"
    [ -n "$REPO" ] && rsync -a --delete "$REPO/" "$CT_MEM/$NAME/work/"
    chown -R 101000:101000 "$CT_MEM/$NAME"
    pct start "$ID"
    echo "ct: $NAME up as CT $ID at $NET.$ID (write your BRIEF to $CT_MEM/$NAME/memory/)"
    ;;
  ls)
    pct list
    for d in "$CT_MEM"/*/memory/LAST_UPDATE.md; do
      [ -f "$d" ] || continue
      printf '\n== %s ==\n' "$(basename "$(dirname "$(dirname "$d")")")"
      head -5 "$d"
    done
    ;;
  start|stop)
    NAME="${2:?usage: ct.sh $1 <name>}"; ID="$(id_of "$NAME")"
    [ -n "$ID" ] || die "no CT named '$NAME'"
    pct "$1" "$ID"
    ;;
  rm)
    NAME="${2:?usage: ct.sh rm <name> [--purge]}"; ID="$(id_of "$NAME")"
    [ -n "$ID" ] || die "no CT named '$NAME'"
    pct status "$ID" | grep -q stopped || pct stop "$ID"
    pct destroy "$ID"
    if [ "${3:-}" = "--purge" ]; then
      rm -rf "${CT_MEM:?}/$NAME"
      echo "ct: $NAME destroyed, host dirs purged"
    else
      echo "ct: $NAME destroyed (host dirs kept at $CT_MEM/$NAME)"
    fi
    ;;
  *)
    die "usage: ct.sh new <name> [repo-path] | ls | start <name> | stop <name> | rm <name> [--purge]"
    ;;
esac
