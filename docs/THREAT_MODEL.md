# Airlock Threat Model

## Purpose

Airlock is designed to run selected tools inside Windows Sandbox without ambient access to the host user's files or common device/data channels. It reduces host exposure by using a disposable hypervisor-backed guest and an explicit deny-by-default Sandbox profile.

This document defines what Airlock intends to protect, what it trusts, and what remains outside the guarantee.

## Security goals

Airlock aims to ensure that software launched through Airlock cannot, by default:

- browse arbitrary host files or the host user profile;
- access Desktop, Documents, Downloads, or repository contents unless explicitly staged/mapped;
- use host networking while the strict-offline profile is active;
- read/write the host clipboard;
- use microphone, camera, printers, or vGPU redirection;
- modify the read-only bootstrap inputs;
- replace the pinned Brave installer or provisioning script without detection;
- write to arbitrary host locations through Sandbox mappings;
- cause cleanup logic to terminate an unrelated Sandbox/process when lifecycle identity is ambiguous.

## Assets

The main assets are:

1. host filesystem contents;
2. host credentials, tokens, keys, browser data, and application state;
3. host network/LAN reachability;
4. host capture devices and clipboard;
5. integrity of the pinned installer and guest provisioning script;
6. integrity of Airlock host state and lifecycle identity;
7. availability of the host and unrelated Windows Sandbox/processes.

## Trust boundaries

```text
Host
├── Airlock source and PowerShell runtime             TRUSTED BY DESIGN
├── Windows / hypervisor / Windows Sandbox runtime   PLATFORM TRUST
├── %LOCALAPPDATA%\Airlock policy/package/state     HOST-ONLY TRUSTED STATE
│
└── Windows Sandbox guest                            UNTRUSTED EXECUTION ZONE
    ├── read-only bootstrap mapping                  VERIFIED INPUT
    └── writable result mapping                      UNTRUSTED OUTPUT
```

The guest is assumed hostile after launch. Result data written by the guest must therefore be treated as untrusted input by the host.

## Entry points and controls

| Entry point | Main control |
|---|---|
| User-supplied Brave installer | Valid Authenticode signature, expected publisher, product check, SHA-256 pinning |
| Guest provisioning script | SHA-256 pinned during initialization and rechecked |
| `.wsb` configuration | Strict exact policy values, escaped/canonicalized paths, narrow mappings |
| Bootstrap mapping | Fresh per-session directory, read-only, only verified inputs |
| Result mapping | Fresh per-session directory, writable, not executable input |
| Windows 11 lifecycle | Managed Sandbox ID |
| Windows 10 lifecycle | PID + executable path + creation identity; no fake managed ID |
| Cleanup | Exact owned state/staging only; fail closed on identity mismatch |

## Explicitly disabled channels in the strict profile

- networking;
- clipboard redirection;
- microphone/audio input;
- camera/video input;
- printer redirection;
- vGPU.

ProtectedClient is enabled where supported by the Windows Sandbox runtime.

## Threats in scope

### Host filesystem escape

An application inside the guest attempts to access files that were not explicitly mapped.

**Mitigation:** Windows Sandbox isolation plus narrow explicit mappings. The repository, home/profile directories, and Downloads directory are not mapped as ambient shares.

### Writable mapping abuse

Guest code attempts to alter bootstrap code or trusted package bytes, or writes outside the intended output path.

**Mitigation:** bootstrap is mapped read-only; a separate empty result directory is the only writable host mapping.

### Path traversal and reparse-point abuse

Host-side inputs attempt to redirect trusted paths through `..`, symbolic links, junctions, or Windows reparse points.

**Mitigation:** canonical-path checks, root containment checks, safe relative paths, and reparse-point rejection in security-sensitive paths.

### Supply-chain substitution

A different executable is supplied under the expected filename.

**Mitigation:** Authenticode validation, expected Brave publisher/product checks, SHA-256 pinning, immutable package path, and guest-side revalidation before execution.

### Lifecycle identity confusion

Airlock loses track of which Sandbox/process it owns and stops an unrelated one.

**Mitigation:** managed ID on Windows 11. On Windows 10, Airlock requires PID + expected executable path + creation identity and fails closed when those no longer match.

### Policy downgrade

A configuration change silently enables network, clipboard, devices, GPU, or broader host mappings.

**Mitigation:** policy validation requires exact approved values and source/acceptance tests assert the generated strict profile.

### False-success reporting

A launch, stop, or provisioning failure is reported as successful.

**Mitigation:** bounded failure paths, explicit result/state contracts, confirmed shutdown before cleanup, source acceptance, CI, and target-host evidence gates.

## Threats outside Airlock's guarantee

Airlock does not claim to defend against:

- a vulnerability or escape in Windows, Hyper-V, or Windows Sandbox itself;
- a compromised host kernel, administrator, firmware, or hypervisor;
- malicious modification of Airlock code or trusted host state by a user/process with sufficient host privileges;
- files or directories the user deliberately maps or copies into the guest;
- applications launched outside Airlock;
- secrets the user manually types/pastes into the guest through channels they explicitly re-enable;
- denial of service against finite host resources where Windows Sandbox/platform limits do not provide an enforceable quota;
- guarantees for Windows versions/builds not listed as supported by the project;
- internet/LAN isolation after a future network-enabled mode unless that mode has its own reviewed controls and evidence.

## Windows 10 vs Windows 11 lifecycle assurance

The security policy inside the Sandbox is intended to be the same on supported Windows 10 and Windows 11 hosts, but lifecycle control is not equivalent.

- **Windows 11 24H2+**: managed `wsb.exe` lifecycle with Sandbox ID.
- **Windows 10 build 19045**: legacy `WindowsSandbox.exe` process identity. This is weaker operational control and is deliberately reported as such.

Airlock must not invent feature equivalence where the platform does not provide it.

## Security invariants

Changes should preserve these invariants unless an explicitly reviewed design replaces them:

1. deny-by-default Sandbox policy;
2. no ambient host-profile mapping;
3. trusted input and writable output are separate mappings;
4. executable inputs are signature/hash verified;
5. guest output is never implicitly trusted or executed;
6. lifecycle cleanup targets only a verified owned identity;
7. ambiguity fails closed;
8. source tests do not substitute for required live target-host evidence.

## Verification

Run the source and compatibility acceptance suites described in `CONTRIBUTING.md`. Changes that affect native Windows Sandbox behavior require live target-host acceptance before the corresponding security claim is considered validated.

## Reporting issues

For suspected boundary bypasses, follow `SECURITY.md` and do not publish exploit details in a public issue before maintainers have investigated.
