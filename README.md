# golden-container

A pattern (and a small script) for giving coding agents disposable, scoped
workspaces: build one **golden template**, stamp a clone per project, throw
clones away instead of repairing them.

Grew out of running Claude Code workers on a Proxmox homelab; extracted for
use with [Soele](https://github.com/) (a self-hosted agent switchboard, which
can drive this lifecycle from its UI) but useful standalone.

## The idea

An agent session should live in a room you can afford to lose. The template
holds everything a fresh room needs: the agent install, a preset git identity,
a scoped push credential, project-memory conventions. Creating a workspace is
a clone, not a setup checklist. When a workspace drifts or breaks, you don't
debug it; you destroy it and clone again. Clones are cattle.

Two tiers, same idea:

| tier | isolation | needs |
|---|---|---|
| **golden folder** | Claude Code sandbox mode (OS-level fs/network scope) | any Linux/Mac box |
| **golden container** | full LXC container per project | a Proxmox host |

Start with the folder tier. Graduate a project to a container when it's
long-running, runs services, or you want real blast-radius limits.

## Contents

- [docs/golden-folder.md](docs/golden-folder.md) - the no-virtualization tier
- [docs/golden-template.md](docs/golden-template.md) - building the LXC template
- [docs/lifecycle.md](docs/lifecycle.md) - clone, brief, dispatch, harvest, retire
- [ct.sh](ct.sh) - the lifecycle as one script (`ct new|ls|start|stop|rm`)

## Design rules that earn their keep

- **The template has NO bind mounts** (Proxmox refuses to clone a container
  that has them). Mounts are added per-clone.
- **Workspace and memory live on the host**, bind-mounted in, so you can
  review a worker's output from outside without entering the container.
- **No credentials in clones except one scoped push token.** If a worker
  claims it needs another credential, that's a task-boundary smell, not a
  reason to hand one over.
- **Never hand-patch a stale clone.** Re-clone. That's the whole point.

## Soele integration

Soele's daemon drives this lifecycle when `HUB_CTS=1` and `HUB_CT_BASE_IP`
are set on a Proxmox host: new-chat targets include "clone the golden
template", and sessions run inside clones via `pct exec`.
