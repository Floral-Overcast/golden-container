# Building the golden template (LXC tier)

One-time setup on a Proxmox host. Worked example uses CTID **220** at
**192.0.2.220** with clones in **212-219**; adjust to your network. The
convention "CTID = last octet of the IP" keeps clone networking a one-line
sed.

## Create the container

An unprivileged Debian/Ubuntu CT, static IP, `onboot=0`. It will spend its
life **stopped**; it exists only to be cloned.

Inside it:

```sh
# node + the agent CLI
apt update && apt install -y curl git tmux
curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && apt install -y nodejs
npm install -g @anthropic-ai/claude-code
useradd -m -s /bin/bash claude
```

## Bake the conventions

- **Git identity**: `su - claude -c 'git config --global user.name ...'` etc.
- **One scoped credential**: a fine-grained GitHub token that can push only
  your project repos, in the claude user's git credential store. This is the
  clone's ONLY credential. No SSH keys, nothing that reaches other hosts.
- **Auth for the agent**: either bake a long-lived token from
  `claude setup-token` into the claude user's environment, or plan to inject
  it per-clone. Do NOT interactively `/login` per clone; OAuth grants are
  capped per account and new logins evict old ones.
- **Memory layout**: workspace at `/work`, scoped memory at `/memory`
  (both will be bind-mounted per-clone). Bake the auto-load symlink:

```sh
su - claude -c 'mkdir -p ~/.claude/projects/-work && rm -rf ~/.claude/projects/-work/memory && ln -s /memory ~/.claude/projects/-work/memory'
```

  Footgun: Claude Code auto-creates that path as a real directory on first
  run, so a plain `ln -s` lands INSIDE it (nested `memory/memory`). Always
  `rm -rf` first, as above.

- **Optional worker service**: a systemd unit that starts an agent session on
  boot so a freshly cloned worker appears in your session list unattended.
  If you enable it in the template, remember to stop it whenever you boot the
  template itself for maintenance, or you mint a stray "golden" session.

## Template hygiene

- **NO bind mounts on the template.** `pct clone` refuses a CT that has
  them. Mounts (`/work`, `/memory`) are added per-clone by ct.sh.
- Template memory seed lives on the HOST (e.g. `/root/ct-mem/golden/memory/`)
  and is copied into each clone's host dir; the template itself stays a pure
  rootfs.
- Before stopping after maintenance, clear session state so clones start
  clean: `pct exec 220 -- su - claude -c 'rm -f ~/.claude/projects/-work/*.jsonl'`.
- Never patch existing clones to match a template change; re-clone them.
