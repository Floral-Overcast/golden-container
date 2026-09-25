# Clone lifecycle

`ct.sh` automates this; the manual steps are here so you know what it does
and can adapt them. Example: golden CTID 220 at 192.0.2.220, new worker 213.

## Clone

```sh
pct clone 220 213 --hostname <name>      # template must be stopped
# fresh network identity - the clone copied golden's IP AND MAC; change both:
sed -i 's#ip=192.0.2.220/24#ip=192.0.2.213/24#' /etc/pve/lxc/213.conf
sed -i 's/,hwaddr=[^,]*//' /etc/pve/lxc/213.conf   # regenerated on start
# per-clone host dirs, memory seeded from the template seed:
mkdir -p /root/ct-mem/<name>/{memory,work}
cp /root/ct-mem/golden/memory/* /root/ct-mem/<name>/memory/
# bind mounts go on the CLONE (never the template):
cat >> /etc/pve/lxc/213.conf <<EOF
mp0: /root/ct-mem/<name>/memory,mp=/memory
mp1: /root/ct-mem/<name>/work,mp=/work
EOF
```

Seed `/work` with the project checkout from a credentialed machine (the
template has no keys): `rsync -a <checkout>/ /root/ct-mem/<name>/work/`.

Write a BRIEF into the clone's memory (goal, constraints, how to ship), then:

```sh
chown -R 101000:101000 /root/ct-mem/<name>
pct start 213
```

**The #1 mistake**: host uid `101000` == container uid `1000` (the claude
user) under the default unprivileged offset. Anything root writes into a
ct-mem dir without that chown shows up inside as `nobody` and the worker
can't use it.

## Dispatch

Talk to the worker through its own session (if you baked the worker service),
through Soele's UI, or one-shot:

```sh
pct exec 213 -- su - claude -c 'cd /work && claude -p "<task>" --permission-mode acceptEdits'
```

Cancelling a dispatch: killing the host-side wrapper does NOT kill the agent
inside the CT; it survives orphaned and keeps editing /work. Also run
`pct exec 213 -- pkill -u claude -f 'claude -p'` and verify with pgrep.

## Review from outside

The bind mounts mean you never need to enter the container to review:

```sh
cat /root/ct-mem/<name>/memory/LAST_UPDATE.md
git -C /root/ct-mem/<name>/work log --oneline -20
git -C /root/ct-mem/<name>/work diff <base>..HEAD
```

(Host git needs `git config --global --add safe.directory '*'` once; worker
repos are owned by the mapped uid and git refuses "dubious ownership"
otherwise.)

The worker pushes its own repo with the baked scoped token. If it left work
unpushed, fetch straight from the host dir:
`git fetch /root/ct-mem/<name>/work <branch>`.

## Retire

```sh
pct stop 213               # host dirs persist; resume later with pct start
pct destroy 213            # gone for good; /root/ct-mem/<name> remains until you rm it
```

Drifted or broken clone? Destroy and re-clone. The repo re-seeds from git,
memory from the template seed. Repairing clones is how you end up with
seven snowflakes named "temporary".
