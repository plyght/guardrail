# guardrail (`gr`)

A fast, independent version control system built for humans and agents — not a git wrapper, not git-backed. guardrail has its own content-addressed store, but interoperates with git so you can adopt it gradually and keep pushing to GitHub.

## Why

git is superb at what it was built for. But today we work on big Rust/TS repos and with coding agents, and a lot of git's model is friction: the staging area, stashing to switch branches, scary resets, whole-file LFS for binaries, and heavyweight worktrees. guardrail rethinks the everyday loop while keeping git as a first-class peer.

## Ideas

- **Content-addressed store** with FastCDC chunking — large binaries and assets are first-class and deduped at the chunk level, no LFS.
- **Working copy is always a change** — no staging, no stash. You just edit and `gr save`.
- **Operation log** — `gr undo`/`gr redo` is whole-repo and never scary.
- **Instant copy-on-write worktrees** (`gr work`) — great for agents, near-zero disk.
- **Bidirectional git interop** — import/export/clone/push/pull; gr and git coexist in the same repo.
- **Sparse/lazy transfer** — pull just the paths you need; a peer is just an object store, no forced central server.

## The everyday loop

```
gr init
gr save -m "message"      # checkpoint the whole working tree (no add/stash)
gr status | gr diff | gr log
gr desc -m "rename it"
```

## Moving around

```
gr new feature            # branch + switch
gr switch main            # auto-saves your work first
gr work ../agent-copy     # instant copy-on-write worktree
gr undo   /  gr redo
gr restore <file>         # discard edits to one file
gr merge <branch>         # three-way merge with conflict markers
```

## Git, side by side

```
gr import <git-repo>      # pull git HEAD into guardrail
gr export <git-repo>      # write guardrail HEAD out as git commits
gr clone <git-url> <dir>
gr push <url> [branch]    # e.g. push to your GitHub master
gr pull <url>
```

## Config

```
gr config user.name "You"                 # local (.gr/config)
gr config --global user.email you@x.com    # global (~/.config/gr/config)
gr config --global init.defaultBranch main
```

Identity precedence: `GR_AUTHOR` env → local config → global config.

## Experimental

```
gr serve [port]           # share objects over TCP
gr fetch <src> [prefix]   # sparse-pull a branch (optionally just some paths)
gr watch                  # auto-save on every file change
```

## Build

Requires Zig 0.16 and libgit2.

```
zig build          # produces zig-out/bin/gr
zig build test     # run the test suite
```

Status: early, opinionated, and moving fast.

## Releases

Prebuilt `gr` binaries are published to GitHub Releases for each platform (macOS arm64/x64, Linux x64/arm64); they dynamically link libgit2, so you need `libgit2` installed to run them.
