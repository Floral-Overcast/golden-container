# The golden folder tier

Same pattern, no virtualization: a template directory stamped per project,
with Claude Code's sandbox mode as the boundary.

## Build the template once

```
~/golden/
  CLAUDE.md            # your standing instructions for any project
  .claude/
    settings.json      # permissions, sandbox on, hooks
  memory/
    MEMORY.md          # seed memory conventions (empty index is fine)
```

Put in `settings.json` whatever you always end up configuring: allowed
commands, sandbox mode enabled, deny rules for paths sessions should never
touch. The point is that a fresh project never starts from the raw defaults.

## Stamp a project

```sh
cp -r ~/golden ~/projects/<name>
cd ~/projects/<name> && git clone <repo> work   # or start fresh
```

Open your session with cwd inside the stamped folder. With sandbox mode on,
file and network access are enforced at the OS level (bubblewrap on Linux,
Seatbelt on macOS), so "the session stays in its folder" is a real boundary
rather than a polite request.

## What this tier doesn't give you

- Process isolation: a long-running server started by the agent runs as you.
- Clean teardown of installed system packages.
- Independent credentials per project.

When any of those start to matter, that project graduates to a container
(see golden-template.md). The folder layout transfers as-is: the container
tier uses the same CLAUDE.md/memory conventions.
