# AIRLOCK — Build Brief

**A hardened, permission-managed Windows sandbox for running untrusted AI desktop tools.**

> This document is an **instruction prompt**. Hand it to Claude Code or an equivalent
> coding agent as the complete brief for the engagement. It is self-contained: it carries
> the role definition, the delivery process, the verified platform facts, the requirement
> inventory, the recommended architecture, and the acceptance bar.
>
> **Status: NOT BUILT.** No implementation code exists. This is the brief that authorises
> the work, and nothing in it should be read as a claim that any of it runs today.

---

## 0. How to read this document

| Section | What it is | Binding? |
|---|---|---|
| §1 | Your role | Yes |
| §2 | Delivery discipline — the process you must run | Yes, absolutely |
| §3 | Ponytail engineering principles | Yes |
| §4 | Requirement inventory (R-IDs) — the source of truth for scope | Yes |
| §5 | Verified platform facts — do not re-derive, do not contradict | Yes |
| §6 | Recommended architecture + rejected alternatives | Rebuttable with evidence |
| §7 | The permission model — the heart of the product | Yes |
| §8 | Threat model and trust boundaries | Yes |
| §9 | Known risks and open questions | Must be resolved, not ignored |
| §10 | Increment plan | Rebuttable |
| §11 | Definition of Done, verifier spec, test strategy | Yes |
| §12 | Out of scope | Yes |

**§6 and §10 are rebuttable**: if you find a better architecture or a better slice order,
say so with evidence and get approval before deviating. **Everything else is binding.**
§4 in particular is not negotiable — a requirement you cannot build becomes an open
question or a DEFERRED board item with a reason. It never becomes silence.

---

## 1. Your role

You are simultaneously:

- **Principal AI architect / senior AI engineer.** You decide what is genuinely needed
  versus what is fashionable. You state cost, latency, and failure modes in numbers.
- **Senior systems and security engineer.** This product *is* a security boundary. A
  sandbox that leaks is worse than no sandbox, because it manufactures false confidence.
  You will be asked to defend every trust boundary you draw.
- **Senior full-stack / platform engineer.** You ship production code with tests and docs,
  not prototypes.
- **Senior consultant and product strategist.** You challenge weak assumptions, refuse to
  invent requirements, and map every feature to the value it delivers.
- **Senior technical lead.** You think about who maintains this in five years. You
  prioritise simplicity and you say no to scope that does not earn its place.

**The behaviour that matters most in this engagement:** this is a security product built
for a non-specialist user who will trust it with the boundary between his real machine and
tools he does not control. Overstating what the boundary guarantees is the single worst
thing you can do here. Every control you build must be labelled **HARD** (enforced by the
hypervisor or the OS, an attacker inside cannot defeat it) or **SOFT** (cooperative,
depends on code inside the sandbox behaving). Never let a SOFT control be described in
user-facing text as if it were HARD. See §8.

---

## 2. Delivery discipline — governs everything below

### 2.0 Hard gate — order of operations

**No implementation code exists until Phase 1–3 artifacts exist in the repository and the
backlog has been approved.** If you catch yourself writing a feature that has no backlog
ID, stop, add the ID, and ask whether it belongs in this increment at all.

| Phase | Produces | Gate |
|---|---|---|
| 1 — Discovery + decomposition | `PRODUCT_BACKLOG.md`, `OPEN_QUESTIONS.md` | Zero orphan requirements |
| 2 — Board + process contract | `BOARD.md`, `DEFINITION_OF_DONE.md` | Verifier can parse the board |
| 3 — Verifier + CI wiring | `scripts/verify_board.py` | It fails loudly on a seeded lie |
| 4 — Increment 1, and only 1 | code, tests, docs, `DEMO.md` | Verifier green |
| 5 — Review, retro, re-plan | board delta + deferred register | Re-planned with evidence |

**Methodology to run: Scrum with fixed-scope increments toward an MVP, WIP-limited.**

Justify it from the work, and if you disagree, say so before Phase 1. The reason Scrum fits
here: the requirement set is known and bounded (§4), the increments are genuinely
shippable vertical slices, and there is a clear MVP boundary — a sealed sandbox that runs
one browser with no host access is useful on its own. Kanban's continuous flow buys nothing
when the scope is this well-defined at the outset. WIP limits are retained from Kanban
because a single agent working several slices at once produces three half-things.

### 2.1 The methodology, made concrete

A practice you performed but cannot show the output of **did not happen**. This table is
the contract:

| Practice | Artifact you produce | What proves it happened |
|---|---|---|
| Product backlog | `PRODUCT_BACKLOG.md` | Zero orphan requirements in the coverage table |
| Backlog refinement | Definition of Ready | Nothing enters READY with an open question against it |
| Kanban board | `BOARD.md` | The verifier parses it; chat is never the state |
| WIP limits | IN_PROGRESS ≤ 2 | No item pulled while another is in flight |
| Sprint planning | One sprint goal, one vertical slice | The increment is a vertical slice, not three layers |
| Definition of Done | `DEFINITION_OF_DONE.md` | Verifier refuses DONE that names no passing test |
| Sprint review / demo | `DEMO.md` | Commands the user pastes and watches work |
| Retrospective | Retro notes | Names what was cut and what the estimate got wrong |
| Daily standup | Session-open self-audit | Drift between board and repo reported first thing |
| Burndown / velocity | Verifier column counts | Recomputed from the repo, never typed by you |
| Change control | New ID + re-plan | No requirement absorbed silently mid-increment |
| Traceability | `TRACEABILITY.md` | Every row completable |

Two Scrum practices are deliberately **excluded**. Do not perform them:

- **Story points as velocity forecasting.** This assumes measured throughput over many
  sprints. There is no such history, so a velocity figure would be invented precision.
- **Sprint commitment as a social promise.** It means nothing from a party who cannot be
  held to it. The evidence ledger (§2.4) replaces the promise with a check.

If you find yourself running a ceremony that produces no artifact in that table, stop. It
is theatre, and theatre is what lets unfinished work look finished.

### 2.2 Decomposition — nothing may be implicit

`PRODUCT_BACKLOG.md` uses a strict, stable ID hierarchy:

```
Epic     E-01              business outcome, owner, value hypothesis
Feature  F-01.02           capability, maps to exactly one epic
Story    S-01.02.03        user-visible slice, independently shippable
Task     T-01.02.03.a      engineering step, ≤ 1 day of work
```

Every story carries, without exception:

- User story: *As a `<role>`, I want `<capability>`, so that `<business outcome>`*
- Acceptance criteria as Given/When/Then, **each one machine-testable**
- Dependencies (upstream IDs) and blocking risk
- Size (S/M/L) and the leading indicator it moves
- The business value it serves, traced to an epic, never asserted freeform

**Completeness rules — the anti-slack core:**

1. Emit a **Requirements → Backlog coverage table**. Every R-ID in §4 maps to at least one
   backlog ID. Orphan requirements must equal **zero**. If not zero, you are not done
   decomposing.
2. Emit an explicit **OUT_OF_SCOPE** list. Silence must never be mistakable for scope.
3. Anything ambiguous becomes a numbered entry in `OPEN_QUESTIONS.md` with: the ambiguity,
   the options, your recommended default, and the blast radius if the default is wrong.
   **Do not invent requirements to fill a gap.** §9 seeds this file; add to it.
4. Non-functional work — security, authz, validation, observability, rollback, cost and
   latency budgets, accessibility — gets its own backlog IDs. It is never an unwritten
   assumption inside a feature story.

### 2.3 The board is a file

`BOARD.md` is the single source of truth, machine-parseable, one fixed-format line per
item. Columns: `BACKLOG | READY | IN_PROGRESS (WIP≤2) | IN_REVIEW | BLOCKED | DONE | DEFERRED`.

- **WIP limits are enforced.** You may not pull new work while an item sits IN_PROGRESS or
  BLOCKED. Finish or escalate first.
- **BLOCKED requires** a linked `OPEN_QUESTIONS` entry or a named external dependency.
  "Blocked" with no escalation is a process violation.
- **Scope you cut moves to DEFERRED** with a reason and the trigger to revisit. Scope is
  never silently dropped, narrowed, or reinterpreted. **Descoping is the user's call, not
  yours.**
- **Chat is not state.** If it is not in `BOARD.md`, it did not happen.

### 2.4 Definition of Ready / Definition of Done

**Definition of Ready** (to enter READY): acceptance criteria written and testable;
dependencies resolved; data and contracts known; no open question that changes its shape.

**Definition of Done** (to enter DONE) — all of it, every time:

- [ ] Code implemented; no TODO, stub, mock, or hardcoded fixture inside the slice
- [ ] Tests exist and are named in the evidence block, covering **each** acceptance criterion
- [ ] The test command was actually run this session; output pasted (tail is fine)
- [ ] Error handling, input validation, authz, and data-integrity paths covered
- [ ] Docs and CHANGELOG updated; migration and rollback noted if state changed
- [ ] Board updated and the verifier passes

"Done" is a claim about the repository, not about your intent. **A story you wrote code for
but did not verify is IN_REVIEW, not DONE.**

**Evidence ledger.** Every DONE item carries:

```
EVIDENCE S-01.02.03
  tests:   tests/test_profile.py::test_audio_defaults_to_disabled
  command: python -m pytest tests/test_profile.py -q
  result:  7 passed  (run 2026-08-26)
  code:    scripts/New-AirlockProfile.ps1:88-140
  commit:  <sha>
```

No resolvable evidence → the item cannot be DONE. Not negotiable, and not subject to your
judgement that it is "obviously working".

### 2.5 Build the lie detector first — Increment 0, before any feature

Write `scripts/verify_board.py`. **Standard library only, no new dependencies.** The user
must be able to run it independently of anything you tell him. It must:

1. Parse `BOARD.md` and `PRODUCT_BACKLOG.md`
2. Fail if any requirement has no backlog ID (orphan requirement)
3. Fail if any backlog ID is missing from the board (orphan story)
4. Fail if any DONE item lacks an evidence block, or names a file, test, or line that does
   not exist in the repo
5. Re-run the named tests for DONE items and fail on any failure
6. Fail if a DONE item's code path still contains `TODO`, `FIXME`, `NotImplemented`, or a
   bare `pass` stub
7. Print a truthful summary: counts per column, percentage of acceptance criteria with a
   matching test, and the list of everything not built yet
8. Exit non-zero on any failure

Wire it into CI and the pre-push path. **A green verifier is the only acceptable basis for
the sentence "this is done".**

Prove the verifier works by seeding a deliberate lie — mark an item DONE whose test does
not exist — and showing it fail. A lie detector nobody has tested is decoration.

---

## 3. Ponytail engineering principles

Applies to every change, every session.

**Before adding code:** understand the existing code path first · ask whether the new code
is actually necessary · reuse existing code wherever possible · prefer standard-library
functionality · prefer native platform features · prefer already-installed dependencies ·
avoid unnecessary abstractions, wrappers, factories, classes, services, and dependencies ·
implement the smallest clean solution that fully solves the requirement.

Before a large architectural addition, **explain why the existing architecture cannot solve
it more simply.**

**Never simplify away:** security controls · authentication and authorization · input
validation · error handling · data integrity · transactions where required · concurrency
protection · observability where required · tests for important behaviour · accessibility ·
production reliability.

Do not optimise for fewer lines alone. Optimise for the **smallest correct, secure,
maintainable production implementation.**

**Finishing.** The marginal cost of completeness is near zero. Ship the whole thing: code,
tests, documentation. No dangling threads, no workaround where the real fix is in reach, no
"we can do that later" when later is five more minutes.

**One rule outranks that:** completeness never means *claiming* completeness. If a piece is
unfinished, say so plainly and record the honest status on the board.

### 3.1 What Ponytail means specifically here

This project has an unusually strong pull toward over-building, and you must resist it.

**Windows already ships the hypervisor, the isolation boundary, the device redirection
policy engine, and now a CLI to drive them.** You are not building a sandbox. You are
building the thin control plane that Windows does not ship: profile generation, persistence
strategy, a capability warden, and a brokered file path.

If your design contains a custom hypervisor, a kernel driver, a filesystem filter, a
credential store, a background Windows Service, a message bus, or a plugin framework —
you have failed this section. The expected shape of the deliverable is on the order of a
handful of PowerShell scripts, one JSON policy file, one small guest-side agent, and tests.
If it is materially larger, justify every part in writing before building it.

---

## 4. Requirement inventory

**This is the scope. It is derived directly from the user's brief. Every R-ID must appear in
the coverage table with at least one backlog ID.**

Requirements marked **[V]** are verbatim intent from the user; **[D]** are derived and
should be confirmed.

### R-PLAT — Platform

| ID | Requirement | Source |
|---|---|---|
| R-PLAT-01 | The sandbox runs on the user's existing Windows machine. No second physical device, no cloud VM. | [V] |
| R-PLAT-02 | The solution must state its exact Windows edition and build prerequisites, and fail with a clear, actionable message if unmet. | [D] |
| R-PLAT-03 | Launch must be a single, repeatable action — one shortcut or one command. Not a manual checklist. | [D] |

### R-ISO — Isolation

| ID | Requirement | Source |
|---|---|---|
| R-ISO-01 | Tools inside the sandbox have **no direct access to the host filesystem**. Zero ambient access. | [V] |
| R-ISO-02 | The only way data enters the sandbox is by the user deliberately putting it there. | [V] |
| R-ISO-03 | Inside the sandbox, tools may access anything freely. The boundary is at the edge, not internal. | [V] |
| R-ISO-04 | Nothing outside the sandbox is reachable by default. | [V] |
| R-ISO-05 | Isolation must be **HARD** (hypervisor-enforced), not cooperative, for the filesystem boundary. | [D] |
| R-ISO-06 | The default profile must be deny-by-default across every capability. Every grant is opt-in and recorded. | [D] |
| R-ISO-07 | Host network resources (LAN, router admin, other machines, host-local services) must not be reachable from inside by default. | [D] |

### R-DATA — Data movement

| ID | Requirement | Source |
|---|---|---|
| R-DATA-01 | The user can copy files into the sandbox deliberately. | [V] |
| R-DATA-02 | Data-in must be explicit and per-item, never a standing mount of a broad host location such as `C:\Users\<name>`. | [D] |
| R-DATA-03 | Grants are **read-only by default**; write access is a separate, explicit, louder action. | [D] |
| R-DATA-04 | Data-out (sandbox → host) is a distinct decision from data-in, and must be separately controlled. | [D] |
| R-DATA-05 | Every grant and every export is written to a host-side audit log the sandbox cannot alter. | [D] |
| R-DATA-06 | Clipboard is a data path in both directions and must be treated as one, not overlooked. | [D] |

### R-APP — Applications

| ID | Requirement | Source |
|---|---|---|
| R-APP-01 | ChatGPT desktop application for Windows runs inside. | [V] |
| R-APP-02 | Claude Code runs inside (stated as a future need — the design must not preclude it). | [V] |
| R-APP-03 | OpenAI Codex runs inside. | [V] |
| R-APP-04 | Brave browser runs inside, with managed permissions. | [V] |
| R-APP-05 | Arbitrary further tools of the same class can be added without redesign — adding a tool is a config change, not a code change. | [V] |
| R-APP-06 | Installed tools and their sign-in state must survive across sandbox sessions, or the product is unusable in practice. | [D] |
| R-APP-07 | Provisioning must be deterministic, versioned, and reproducible — same profile in, same environment out. | [D] |

### R-PERM — Permissions

| ID | Requirement | Source |
|---|---|---|
| R-PERM-01 | Permissions are user-managed, granular, and per-capability. | [V] |
| R-PERM-02 | Permissions have a **temporal dimension** — "when and how", not merely on/off. | [V] |
| R-PERM-03 | **Minimising the sandbox window revokes microphone access entirely.** | [V] |
| R-PERM-04 | **Restoring the window restores microphone access.** | [V] |
| R-PERM-05 | **Closing the sandbox ends microphone access.** | [V] |
| R-PERM-06 | The same focus-conditional treatment applies to camera and screen capture. | [D] |
| R-PERM-07 | Current capability state must be **visible to the user at a glance** — he must never have to guess whether the mic is live. | [D] |
| R-PERM-08 | Every capability transition is logged with timestamp, trigger, and outcome. | [D] |
| R-PERM-09 | Capability changes must **fail closed**: if the system cannot confirm a capability was revoked, it escalates rather than assuming success. | [D] |
| R-PERM-10 | Policy is declarative and lives in a file the user can read and edit. Not buried in code. | [D] |

### R-RES — Resources

| ID | Requirement | Source |
|---|---|---|
| R-RES-01 | Low RAM footprint. Stated twice by the user — treat as a first-class constraint, not a nice-to-have. | [V] |
| R-RES-02 | Low disk footprint ("ROM"). | [V] |
| R-RES-03 | A concrete, measured budget must be published and enforced by a test, not asserted in prose. | [D] |
| R-RES-04 | Time-to-usable after launch must be measured and reported; provisioning must not make launch impractical. | [D] |

### R-OPS — Operations

| ID | Requirement | Source |
|---|---|---|
| R-OPS-01 | The user can operate this without reading source code. Plain-language docs. | [D] |
| R-OPS-02 | Failure modes produce actionable messages, never silent failure or a bare stack trace. | [D] |
| R-OPS-03 | The system is inspectable: the user can ask "what is granted right now?" and get a truthful answer. | [D] |
| R-OPS-04 | Full teardown is available and verifiable — the user can prove nothing was left behind. | [D] |

### R-SEC — Security posture

| ID | Requirement | Source |
|---|---|---|
| R-SEC-01 | Every control is documented as HARD or SOFT. No user-facing text may present a SOFT control as HARD. | [D] |
| R-SEC-02 | A written threat model names what this defends against and what it explicitly does not. | [D] |
| R-SEC-03 | Secrets (API keys, tokens) inside the sandbox must have a defined handling policy — where they live, what happens on teardown. | [D] |
| R-SEC-04 | The audit log is append-only from the sandbox's perspective and readable by the host. | [D] |

**Total: 45 requirements** — PLAT 3, ISO 7, DATA 6, APP 7, PERM 10, RES 4, OPS 4, SEC 4.
The coverage table must account for all 45.

---

## 5. Verified platform facts

**Verified against Microsoft Learn on 2026-08-26. Do not re-derive these. Do not contradict
them without re-checking the source and saying so.**

### 5.1 Windows Sandbox `.wsb` configuration schema

Supported elements: `vGPU`, `Networking`, `MappedFolders`, `LogonCommand`, `AudioInput`,
`VideoInput`, `ProtectedClient`, `PrinterRedirection`, `ClipboardRedirection`, `MemoryInMB`.

**The defaults are hostile to this project. Every one of these must be set explicitly:**

| Element | Microsoft's default | Why it matters here | Our default |
|---|---|---|---|
| `AudioInput` | **Enabled** | The microphone is live by default. Directly contradicts R-PERM. | `Disable` |
| `ClipboardRedirection` | **Enabled** | A bidirectional data path, open by default. Contradicts R-DATA-06. | `Disable` |
| `Networking` | **Enabled**, via Hyper-V default switch. MS warns it "can expose untrusted applications to the internal network". | Contradicts R-ISO-07. | `Enable` + in-guest egress firewall (see §7.4) |
| `vGPU` | **Enabled** on non-Arm64. MS warns it "can potentially increase the attack surface". | Attack surface for no essential gain. | `Disable` unless measured as necessary |
| `VideoInput` | Disabled | Correct already. | `Disable` (explicit) |
| `ProtectedClient` | Disabled | AppContainer isolation on the RDP session is free hardening. | `Enable` (but see caveat below) |
| `PrinterRedirection` | Disabled | Correct already. | `Disable` (explicit) |
| `MemoryInMB` | 4096 max; auto-raised to a 2048 minimum | Tunable for R-RES-01. | Profile-dependent |

**`MappedFolder` sub-elements:** `HostFolder`, `SandboxFolder`, `ReadOnly`.

- `ReadOnly` **defaults to `false`** — mapped folders are **writable unless you say
  otherwise**. This is the single most dangerous default in the schema. Always set it
  explicitly.
- If `SandboxFolder` is omitted, the folder maps to the sandbox user's desktop. The default
  sandbox user is `WDAGUtilityAccount`.
- The host folder must already exist or the container fails to start. Validate before launch.
- Mapped folders are mounted **before** `LogonCommand` runs.
- Environment variables in paths are supported from Windows 11 23H2.
- Microsoft's own warning: *"Files and folders mapped from the host can be compromised by
  apps in the sandbox or potentially affect the host. Changes made during a Sandbox session
  to a mapped folder with write-permissions will persist after a Sandbox is disposed."*
  This is the exact mechanism we rely on for persistence — which means it is also the exact
  mechanism that carries our residual risk. Say so in the user docs.

**`ProtectedClient` caveat:** Microsoft notes it "may restrict the user's ability to
copy/paste files in and out of the sandbox." Since we disable clipboard redirection anyway
(R-DATA-06) and move files via brokered shares, this cost is likely acceptable — but it
must be **measured in a spike**, not assumed. If it breaks the brokered file path, it loses.

**`LogonCommand`** invokes a single command after logon. Microsoft's guidance: put anything
multi-step in a script file mapped in via a shared folder. That is exactly our provisioning
path.

### 5.2 Windows Sandbox CLI — `wsb.exe`

**Available from Windows 11, version 24H2.** Microsoft states the CLI may change in future.
Common parameters: `--raw` (JSON output), `-?, -h, --help`.

| Command | Syntax | Notes |
|---|---|---|
| `start` | `wsb start [--config "<Configuration>…</Configuration>"]` | Returns the sandbox ID. **Config can be passed as an inline string — no `.wsb` file on disk required.** |
| `list` | `wsb list` | Running sessions for the current user: ID, status (running/stopped), uptime. |
| `exec` | `wsb exec --id <id> -c <command> -r <ExistingLogin\|System> [-d <dir>]` | `--id`, `-c`, `-r` all **REQUIRED**. |
| `stop` | `wsb stop --id <id>` | Terminates the sandbox, releases resources, closes the window. |
| `share` | `wsb share --id <id> -f <host-path> -s <sandbox-path> [-w\|--allow-write]` | **Mounts a host folder into a *running* sandbox.** |
| `connect` | `wsb connect --id <id>` | Opens an RDP session window to the sandbox. |
| `ip` | `wsb ip --id <id>` | Sandbox IP address. |

**Three CLI facts that shape the entire architecture. Read these twice.**

1. **`wsb exec` has NO process I/O.** Microsoft: *"there is no support for process I/O
   meaning that there is no way to retrieve the output of a command run in Sandbox."*
   The host can push commands in but **cannot read anything back**. Any design that assumes
   it can read `wsb exec` output is broken. The return channel must be a file the guest
   writes into a mapped folder that the host reads. Design for this from the start.

2. **`wsb exec -r ExistingLogin` requires an active user session.** A remote desktop
   connection must be established first (`wsb connect`), or the call fails. `-r System`
   runs in system context without that requirement. Choose deliberately per call and handle
   the failure path.

3. **`wsb share` grants folders at runtime.** This is materially better than copy-paste for
   R-DATA-01: the user grants one specific folder, on demand, to a running sandbox, and it
   is **read-only unless `--allow-write` is passed** — the opposite of the `.wsb` default,
   and the safe direction. This is the mechanism the brokered file path should use.

### 5.3 Footprint and persistence

- **Disk:** the dynamic base image ships as a ~30 MB compressed package and occupies
  roughly **500 MB installed**. The sandbox shares immutable host OS files rather than
  duplicating them, so incremental disk cost is far below a full VM.
- **RAM:** the sandbox shares physical memory pages with the host for OS binaries — when
  `ntdll.dll` loads in the sandbox it uses the same physical pages as the host's copy.
  Memory is dynamically allocated and **the host can reclaim it under pressure**, like a
  normal process, rather than being statically apportioned as with a traditional VM.
- **This is why Windows Sandbox wins on R-RES-01 and R-RES-02.** No other option with a
  comparable isolation guarantee is this light.
- **Persistence: there is none across sessions.** Reboots *within* a session persist (since
  Windows 11 22H2), but closing the sandbox destroys all state. Write-enabled mapped folders
  persist to the host — **that is the only persistence primitive available**, and the whole
  persistence design in §6.3 hangs off it.

### 5.4 Application facts

- **ChatGPT for Windows** is distributed through the Microsoft Store. Current package ID
  `9PLM9XGG6VKS`; the older `9NT1R1C2HH7J` installs ChatGPT Classic. Enterprise guidance
  installs it via `winget --source=msstore`.
- **Neither `winget` (App Installer) nor the Microsoft Store is present in a fresh Windows
  Sandbox.** Both must be bootstrapped. Store-backed installs inside Sandbox are the single
  largest delivery risk in this project — see OQ-03 in §9.
- Do not treat "install ChatGPT desktop" as routine. Spike it before committing to it.

---

## 6. Recommended architecture

### 6.1 The decision

**Windows Sandbox, driven by a host-side control plane, with persistence via a single
brokered vault folder.**

Ponytail justification, as §3 requires: Windows already ships the hypervisor, the isolation
boundary, the device-redirection policy engine, and (from 24H2) a CLI to drive all three at
runtime. Building any part of that ourselves would be strictly worse and unmaintainable.
**The only genuinely missing pieces are persistence, runtime capability policy, and a
brokered file path.** Those three things are the product. Nothing else should be built.

### 6.2 Alternatives considered and rejected

| Option | Why rejected |
|---|---|
| **Full Hyper-V VM with a Windows guest** | Fails R-RES-01/02 decisively: a separate Windows install needs ~25–40 GB disk and a statically apportioned 4 GB+ RAM, versus ~500 MB and shared, reclaimable pages for Windows Sandbox. Buys persistence, which §6.3 obtains far more cheaply. Also needs a separate licence. |
| **WSL2 with a hardened Linux distro** | Genuinely light and genuinely persistent, and excellent for Claude Code and Codex. But it cannot run the ChatGPT Windows desktop app (R-APP-01) or Brave-as-a-Windows-app (R-APP-04), and the default posture is porous — `/mnt/c` host mounts, Windows interop, `\\wsl.localhost` bridging — so it must be hardened *down* rather than being secure by default. **Keep as a documented Track B** for CLI-only AI work, where it is arguably the better answer. Do not build it in the MVP. |
| **Sandboxie-Plus** | Light, persistent, granular file and registry rules, good UX. Rejected on R-ISO-05: it is a user-mode, hook-based sandbox. The boundary is defeatable by code that is actively trying, which is precisely the failure mode that makes a false-confidence security product dangerous. Acceptable for "stop apps cluttering my disk"; not acceptable as the boundary between a machine and untrusted AI tooling. |
| **Windows containers / Docker Desktop** | Process-isolated mode is a weak boundary; Hyper-V-isolated mode reintroduces the VM weight. GUI application support is poor to nonexistent, which fails R-APP-01 and R-APP-04 outright. Docker Desktop itself is a heavy dependency, contradicting §3. |
| **A second physical machine** | Solves isolation perfectly and fails R-PLAT-01, R-RES-*, and cost. Noted for completeness. |

**Hard prerequisite created by this decision:** Windows Sandbox requires Windows Pro,
Enterprise, or Education (**not Home**) with hardware virtualisation enabled, and the CLI
requires Windows 11 24H2 or later. **Confirm the user's actual edition and build before
Phase 1 completes** — see OQ-01. If the machine is Windows Home, this entire architecture
is void and Track B (WSL2) or an edition upgrade becomes the decision. Do not build on an
unverified assumption here; it is the one that invalidates everything else.

### 6.3 Persistence strategy

The problem: Windows Sandbox destroys all state on close (§5.3), but R-APP-06 requires
installed tools and sign-in state to survive.

The solution uses the only persistence primitive available — a write-enabled mapped folder:

```
HOST                                        SANDBOX
C:\Airlock\
  vault\            ──── mapped RW ───────► C:\Airlock\vault\
    installers\       (pre-staged offline)    installers\
    profiles\         (Brave profile,         profiles\
                       tool config, tokens)
    workspace\        (the user's actual      workspace\
                       working files)
  policy.json       ──── mapped RO ───────► C:\Airlock\policy.json
  provision.ps1     ──── mapped RO ───────► C:\Airlock\provision.ps1
  audit\            ◄─── host-only, NEVER mapped
  telemetry\        ◄─── mapped RW ───────► guest state return channel (§5.2 fact 1)
```

On launch, `LogonCommand` runs `provision.ps1`, which:

1. Bootstraps `winget` from the pre-staged offline installer in `vault\installers\`
2. Installs the tools named in `policy.json` — offline where possible, for speed and
   determinism (R-APP-07)
3. Redirects application data directories into `vault\profiles\` (junctions or per-app
   config) so sign-in state and settings survive teardown (R-APP-06)
4. Applies the in-guest egress firewall (§7.4)
5. Starts the guest agent (§7.3)
6. Writes a completion record to `telemetry\` so the host knows provisioning succeeded

**Three things this design must get right, and they are all easy to get wrong:**

- **The vault is the boundary's one deliberate hole.** Everything reachable from inside is
  reachable *because we chose to put it there*. That is exactly the user's stated mental
  model (R-ISO-02) — but it means the vault must never be a broad host location. Never map
  `C:\Users\<name>`, `C:\`, Desktop, or Documents. `workspace\` starts empty and the user
  moves things in.
- **Tokens in `vault\profiles\` persist on the host after teardown.** That is the point,
  and it is also a real exposure (R-SEC-03). Document it plainly; consider DPAPI protection
  or an opt-in ephemeral profile mode.
- **`audit\` must never be mapped into the sandbox** (R-SEC-04). A log the sandbox can edit
  is not a log.

### 6.4 Components

| Component | Where | Responsibility | Est. size |
|---|---|---|---|
| `New-AirlockProfile.ps1` | Host | Read `policy.json`, validate it, emit the `<Configuration>` string for `wsb start --config` | Small |
| `Start-Airlock.ps1` | Host | Preflight checks (edition, build, virtualisation, vault paths), launch, capture sandbox ID, start the warden | Small |
| `Airlock-Warden.ps1` | Host | The focus-aware capability state machine (§7.2). Watches the window, drives `wsb exec`, verifies via telemetry, writes the audit log | **The one non-trivial component** |
| `Grant-AirlockFolder.ps1` | Host | Brokered file grant via `wsb share`, read-only by default, audited (R-DATA-01/02/03/05) | Small |
| `provision.ps1` | Guest | Deterministic provisioning per §6.3 | Medium |
| `agent.ps1` | Guest | Applies capability changes, writes state to `telemetry\` | Small |
| `policy.json` | Host | Declarative policy, user-editable (R-PERM-10) | Config |
| `verify_board.py` | Repo | The lie detector (§2.5) | Small |

That is the whole system. **If your design has more components than this, justify each
addition in writing** against §3 before building it.

---

## 7. The permission model

This is the heart of the product and the part most likely to be built shallowly. Build it
properly.

### 7.1 Capability matrix

| Capability | Mechanism | HARD or SOFT | Default | Requirement |
|---|---|---|---|---|
| Host filesystem | `MappedFolders` / `wsb share` | **HARD** — hypervisor | Nothing mapped except the vault | R-ISO-01 |
| Clipboard | `ClipboardRedirection` | **HARD** | `Disable` | R-DATA-06 |
| Microphone (launch) | `AudioInput` | **HARD** | `Disable` | R-PERM-01 |
| Microphone (runtime) | Guest-side device mute via `wsb exec` | **SOFT** — see §7.5 | Muted | R-PERM-03/04 |
| Camera | `VideoInput` | **HARD** | `Disable` | R-PERM-06 |
| Network (on/off) | `Networking` | **HARD** — but all-or-nothing | `Enable` | R-ISO-07 |
| Network (per-app) | In-guest Windows Firewall | **SOFT** | Deny-by-default outbound | R-ISO-07 |
| Printer | `PrinterRedirection` | **HARD** | `Disable` | R-ISO-06 |
| GPU | `vGPU` | **HARD** | `Disable` | R-ISO-06 |
| Memory ceiling | `MemoryInMB` | **HARD** | Profile-set | R-RES-01 |
| RDP hardening | `ProtectedClient` | **HARD** | `Enable`, pending spike | R-SEC-01 |
| Teardown | `wsb stop` | **HARD** | On demand | R-PERM-05 |

### 7.2 The focus-aware state machine

R-PERM-03/04/05 are the user's most specific request and the most technically demanding
part of the build. The user's words: *"if I minimize it, it won't be able to listen to me at
all… and back I open it, it will be able to listen to me again."*

**States:** `SEALED` (no capture devices live) ⇄ `LIVE` (capture per policy).

**Transitions into SEALED:** window minimised · window loses foreground focus (if policy
says so) · workstation locked · idle timeout exceeded · sandbox stopped · warden loses
contact with the guest agent.

**Transitions into LIVE:** window restored **and** focused **and** policy permits **and**
the guest agent has confirmed it is healthy.

**Warden loop:**

1. Resolve the sandbox client window handle on the host. Windows Sandbox presents as an RDP
   client window; identify it by process and window handle, and re-resolve if it changes.
2. Poll foreground and iconic state via `GetForegroundWindow` and `IsIconic` (P/Invoke from
   PowerShell). Start at ~250 ms and **measure** — tune against R-RES-01, since a tight
   poll loop on the host is itself a resource cost. Prefer an event-driven hook
   (`SetWinEventHook`) if the spike shows polling is measurably expensive.
3. On a state transition, compute the desired capability set from `policy.json`.
4. Apply it via `wsb exec --id <id> -c <mute/unmute command> -r System`.
5. **Verify.** Because `wsb exec` returns nothing (§5.2 fact 1), the guest agent writes the
   applied state and a timestamp to `telemetry\state.json`; the warden reads it back.
6. **Fail closed** (R-PERM-09). If the guest does not confirm SEALED within a bounded
   timeout, escalate: notify the user visibly, and — per policy — `wsb stop` the sandbox.
   Never assume the mute worked.
7. Append every transition to the host-only audit log: timestamp, trigger, target state,
   confirmed state, latency (R-PERM-08).

**Latency is a real acceptance criterion, not a detail.** Measure the wall-clock time from
minimise to confirmed-muted and publish it. If that number is seconds rather than
milliseconds, R-PERM-03 is not honestly met and the board must say so.

### 7.3 The guest agent

Small, single-purpose: watch for a command file or respond to `wsb exec` invocations, apply
the capability change (disable or mute the guest's audio capture endpoint), write the
resulting state to `telemetry\state.json`, and heartbeat so the warden can detect a dead or
tampered agent and fail closed.

### 7.4 Network egress

`Networking` in Windows Sandbox is **all-or-nothing** — there is no per-application or
per-destination control at the `.wsb` layer. Per-app control must therefore be implemented
*inside* the guest with Windows Firewall: default-deny outbound plus an allowlist of the
tools in `policy.json`.

**Be honest about the limit.** Windows Firewall rules are per-application and IP-based, not
domain-based. "Allow Claude Code to reach only `api.anthropic.com`" is **not** achievable
with firewall rules alone; it needs an in-guest proxy. Per-application allowlisting *is*
achievable and is the right MVP scope. Domain-level egress control is a later epic, and
must be listed in OUT_OF_SCOPE for the MVP rather than quietly implied.

Also note Microsoft's own warning that sandbox networking "can expose untrusted
applications to the internal network" — the Hyper-V default switch puts the sandbox on a
network path to the host's LAN. R-ISO-07 requires this be addressed, not just noted. If the
in-guest firewall cannot adequately block RFC1918 destinations, raise it as an open question
rather than shipping a boundary that only appears to hold.

### 7.5 Say this plainly in the user documentation

The launch-time controls in §7.1 marked HARD are enforced by the hypervisor. Code inside the
sandbox cannot defeat them.

**The runtime microphone gate is SOFT.** It works by asking software inside the sandbox to
mute a device. It defends completely against the realistic threat — an AI tool that keeps a
microphone stream open when the user thought it was not listening — and it does **not**
defend against malware inside the sandbox that is actively trying to re-enable capture.

The only HARD guarantees for the microphone are:

- Launch with `AudioInput=Disable`, so the device is never present (**strict mode — this
  should be the default profile**), or
- `wsb stop`, which destroys the sandbox.

Both must be exposed to the user as first-class options. A user who wants a hard guarantee
must be able to get one, and must be told which mode gives it. Presenting the runtime gate
as if it were hypervisor-enforced would be the exact failure this brief warns about in §1.

### 7.6 Visible state

R-PERM-07 requires the user to know, at a glance, whether the microphone is live. A log file
is not "at a glance". Provide a persistent, always-visible host-side indicator — tray icon
with distinct states, or an overlay. This is an accessibility requirement as much as a
security one, and §3 forbids simplifying it away.

---

## 8. Threat model

**Defends against:** an AI tool or its dependency reading files across the host disk ·
exfiltrating host data it was never given · persisting on the host after removal ·
capturing audio when the user believes it is not listening · a supply-chain-compromised npm
or pip package pulled in by a tool inside the sandbox · accidental damage from an agent
given a broad instruction.

**Explicitly does NOT defend against:** a Hyper-V guest-to-host escape (accepted; it is the
platform's boundary and we inherit it) · malicious code inside the sandbox actively
subverting the SOFT runtime microphone gate (§7.5) · the user deliberately granting a
sensitive folder through the broker · data the user pastes in himself · a compromised host,
which is game over regardless · network-level attacks from the sandbox onto the LAN beyond
what the in-guest firewall blocks (§7.4).

**Trust boundaries, ranked by strength:**

1. Hypervisor boundary (host ⇄ sandbox) — strongest, inherited from Windows.
2. Mapped-folder boundary — strong, but exactly as wide as the folders mapped. This is where
   design error is most likely to cause real harm.
3. In-guest controls (firewall, agent, device mute) — SOFT. Defeatable by determined code
   inside. Useful, honestly labelled.

**State this ranking in the user documentation.** A user who understands that layer 2 is
"exactly as wide as what you granted" will use the product correctly. One who thinks the
sandbox is magic will eventually grant his home directory and wonder why it did not save him.

---

## 9. Open questions — seed for `OPEN_QUESTIONS.md`

Resolve these in Phase 1. Do not invent answers. Where a default is recommended, the
recommendation is a starting position, not permission to skip asking.

| ID | Question | Options | Recommended default | Blast radius if wrong |
|---|---|---|---|---|
| **OQ-01** | What Windows edition and build is the target machine? | Home / Pro / Enterprise / Education; build ≥ 26100 or not | **Must be answered before Phase 1 closes — blocking.** | **Total.** Windows Home has no Windows Sandbox; pre-24H2 has no CLI, which removes runtime `share` and `exec` and therefore removes the entire runtime permission model. The whole architecture is void if this is wrong. |
| **OQ-02** | Is strict mode (mic never present) or voice mode (SOFT runtime gating) the default profile? | Strict / voice | **Strict.** Deny by default; the user opts into voice explicitly, having been told it is SOFT. | Medium. Wrong default means the user believes he has a hard guarantee he does not have. |
| **OQ-03** | Can the Microsoft Store ChatGPT app (`9PLM9XGG6VKS`) actually be installed in Windows Sandbox? | Yes / no / only with a Store bootstrap | **Spike this before committing to R-APP-01.** Fallback: run ChatGPT as an installed web app in Brave. | High. R-APP-01 is a named user requirement. If it is unattainable, the user must be told plainly and offered the fallback — not quietly given a browser tab and told it is the app. |
| **OQ-04** | Does `ProtectedClient=Enable` break the brokered `wsb share` file path? | Breaks / does not | Spike. If it breaks the broker, the broker wins and ProtectedClient is disabled with the trade-off documented. | Medium. |
| **OQ-05** | Is provisioning-on-every-launch fast enough to be usable? | Yes / no | Measure it. If time-to-usable exceeds ~90s, the persistence design needs rework, not an apology. | High. Slow launch means the user stops using the sandbox — the security control that goes unused provides zero protection. |
| **OQ-06** | Should focus loss (not just minimise) seal the microphone? | Minimise only / minimise + blur | Ask. The user said "minimize" specifically, but alt-tabbing away is the same intent. Do not assume. | Low, but it is a direct question about stated intent — ask rather than guess. |
| **OQ-07** | How are API keys and tokens handled at teardown? | Persist in vault / DPAPI-protected / ephemeral | Ask. Convenience and exposure trade directly here. | Medium — R-SEC-03. |
| **OQ-08** | Is a host-LAN-reachable sandbox acceptable, given `Networking` is all-or-nothing? | Accept / mitigate in-guest / disable networking | Mitigate in-guest, and state the residual risk honestly. | Medium — R-ISO-07. |
| **OQ-09** | Does the user want Track B (WSL2, CLI-only) as well, for Claude Code and Codex? | Yes / no / later | Ask after MVP. It is a genuinely better fit for CLI tools and a materially lighter footprint. | Low — additive. |

---

## 10. Increment plan

**Increment 0 — the lie detector.** `PRODUCT_BACKLOG.md`, `OPEN_QUESTIONS.md`, `BOARD.md`,
`DEFINITION_OF_DONE.md`, `scripts/verify_board.py`, CI wiring. Prove the verifier fails on a
seeded lie. **No feature code.**

**Increment 1 — the sealed box (vertical slice).**
*Goal: launch a sandbox that runs Brave, has zero host access, has no microphone, and prove
all three.*
Covers R-PLAT-01/02/03, R-ISO-01/03/04/05/06, R-APP-04, R-RES-01/02/03, R-PERM-01.
Deliverables: `policy.json`, `New-AirlockProfile.ps1`, `Start-Airlock.ps1`, minimal
`provision.ps1` (Brave only), preflight checks, tests, `DEMO.md`.
**This is a genuine vertical slice and is useful on its own** — a browser in a sealed box
with a measured footprint. That is the MVP boundary.

**Increment 2 — persistence and the toolchain.** The vault, app-data redirection, offline
installer staging, Claude Code, Codex, Node, Git. R-APP-02/03/05/06/07, R-RES-04.
Resolve OQ-03 and OQ-05 here.

**Increment 3 — the capability warden.** The focus-aware state machine, the guest agent, the
telemetry return channel, fail-closed escalation, the audit log, the visible indicator.
R-PERM-02 through R-PERM-10, R-SEC-01/04. **The hardest increment. Do not start it before
Increment 2 is genuinely DONE.**

**Increment 4 — the broker.** `Grant-AirlockFolder.ps1`, read-only default, explicit write
grants, data-out path, grant audit. R-ISO-02, R-DATA-01 through R-DATA-06, R-OPS-03.
This increment is what finally *closes* R-ISO-02 — Increment 1 establishes that nothing
gets in, and this one builds the single deliberate way it can.

**Increment 5 — hardening and finish.** In-guest egress firewall, ChatGPT resolution per
OQ-03, teardown verification, secrets policy, full user documentation.
R-ISO-07, R-APP-01, R-OPS-01/02/04, R-SEC-02/03.

**WIP ≤ 2 throughout. One increment at a time. Do not start Increment 2 while Increment 1
has an item in IN_PROGRESS.**

---

## 11. Definition of Done, verification, and tests

§2.4 gives the per-story DoD and §2.5 the verifier spec. Both apply in full. Additionally,
for this project specifically:

### 11.1 Security acceptance tests — required, not optional

A sandbox is only as good as the proof that it holds. These are tests, not assertions in a
README:

| Test | Asserts | Requirement |
|---|---|---|
| Host filesystem probe | From inside, enumerate `C:\Users`, the host Desktop and Documents. **Must fail.** | R-ISO-01 |
| Vault-only visibility | From inside, the only host-backed path reachable is the vault. | R-ISO-02, R-DATA-02 |
| Clipboard blocked | Copy on host, paste inside → must not transfer, and the reverse. | R-DATA-06 |
| Mic absent in strict mode | Enumerate capture devices inside → none present. | R-PERM-01 |
| Mic sealed on minimise | Minimise, then confirm the guest reports SEALED within the published latency budget. | R-PERM-03 |
| Mic restored on focus | Restore, confirm LIVE. | R-PERM-04 |
| Fail-closed on dead agent | Kill the guest agent, confirm the warden escalates rather than reporting LIVE. | R-PERM-09 |
| Read-only grant is read-only | `Grant-AirlockFolder` without `-AllowWrite`, then attempt a write inside → must fail. | R-DATA-03 |
| Audit integrity | From inside, attempt to modify the host audit log → must fail. | R-SEC-04 |
| Teardown residue | After `wsb stop`, assert no residue outside the vault. | R-OPS-04 |
| Footprint budget | Measure RAM and disk against the published budget; **fail the build if exceeded**. | R-RES-03 |
| Time-to-usable | Measure and publish; fail if it exceeds the agreed threshold. | R-RES-04 |

**A negative security test that has never been seen to fail is not evidence.** For each one,
demonstrate it failing against a deliberately weakened profile, then passing against the
real one. Otherwise you have a test that asserts nothing.

### 11.2 Benchmarks to publish

Idle RAM (host delta) · peak RAM under load · disk footprint (base + vault) · cold launch to
usable · minimise → confirmed-muted latency · warden CPU cost at the chosen poll interval.

Numbers, measured, in `DEMO.md`. Not adjectives.

### 11.3 What you may not claim

Do not write "the sandbox is secure", "fully isolated", or "the microphone cannot be
accessed" anywhere. Write what is enforced, by what mechanism, with what test as evidence,
and what is not covered. §8 is the template for that honesty.

---

## 12. Out of scope for the MVP

Listed so silence is never mistaken for scope:

- Domain-level network egress filtering (needs an in-guest proxy — §7.4). Per-application
  allowlisting **is** in scope.
- Multiple concurrent sandboxes / multi-profile orchestration.
- GPU compute or local model inference inside the sandbox.
- macOS or Linux hosts.
- Windows Home support (architecturally void — see OQ-01).
- Track B (WSL2 for CLI tools) — documented as an alternative, not built. See OQ-09.
- Automated malware analysis or behavioural monitoring of tools inside.
- Any GUI beyond the tray indicator required by R-PERM-07.
- Sharing the sandbox between users or machines.

---

## 13. First actions

1. **Answer OQ-01 before anything else.** Windows edition and build. It is blocking, and it
   can void the architecture.
2. Read §4 and §5 in full. Do not re-derive §5; it is verified.
3. Produce Phase 1: `PRODUCT_BACKLOG.md` with the coverage table (all 40 R-IDs, zero
   orphans) and `OPEN_QUESTIONS.md` seeded from §9.
4. Produce Phase 2: `BOARD.md`, `DEFINITION_OF_DONE.md`.
5. Produce Phase 3: `scripts/verify_board.py`, proven against a seeded lie.
6. **Stop. Present the backlog for approval before writing any feature code.**

Report honestly at every step. If something in this brief is wrong, say so — a brief is an
input, not scripture. The one thing that is not negotiable is claiming something works when
it has not been verified.

---

*Sources for §5: [Windows Sandbox configuration](https://learn.microsoft.com/en-us/windows/security/application-security/application-isolation/windows-sandbox/windows-sandbox-configure-using-wsb-file) · [Windows Sandbox CLI](https://learn.microsoft.com/en-us/windows/security/application-security/application-isolation/windows-sandbox/windows-sandbox-cli) · [Windows Sandbox architecture](https://learn.microsoft.com/en-us/windows/security/application-security/application-isolation/windows-sandbox/windows-sandbox-architecture) · [ChatGPT for Windows](https://learn.chatgpt.com/docs/windows/windows-app). Verified 2026-08-26.*
