# Security Policy

Airlock is security-sensitive software. Please do not publish exploit details, secrets, or proof-of-concept material in a public issue before maintainers have had a reasonable chance to investigate.

## Supported versions

Security fixes are made against the current `main` branch unless a release explicitly states otherwise. Until versioned releases are published, older commits should be treated as unsupported.

## Reporting a vulnerability

Preferred path:

1. Open the repository's **Security** tab.
2. Use **Report a vulnerability** / private vulnerability reporting if it is available.
3. Include the affected commit or version, Windows version/build, reproduction steps, expected boundary, observed boundary, and whether host data, network access, device access, process identity, or cleanup integrity is affected.

If private vulnerability reporting is not available, contact the repository owner through the GitHub profile without posting technical exploit details publicly. A private reporting channel should be established before sensitive details are exchanged.

Do **not** use a normal public GitHub issue for an unpatched vulnerability.

## What counts as security-sensitive

Examples include:

- unintended access to host files or directories;
- writable host mappings outside the documented result directory;
- network, clipboard, microphone, camera, printer, or GPU access when policy says it is disabled;
- bypass of Brave installer signature/hash verification;
- path traversal, junction, symlink, or reparse-point escape;
- lifecycle confusion that can stop or modify an unrelated Windows Sandbox/process;
- execution of untrusted result/telemetry data;
- secret, credential, certificate, or private-key exposure;
- a failure that is reported as secure/successful when the security boundary was not actually established.

## Disclosure expectations

Please allow maintainers time to reproduce, fix, test, and release a correction before public disclosure. Maintainers should acknowledge a valid report, keep the reporter informed of material status changes, and credit the reporter if requested and appropriate.

## Security model

Read [`docs/THREAT_MODEL.md`](docs/THREAT_MODEL.md) and [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) before reporting a design limitation as a vulnerability. A documented residual risk may still justify a security improvement, but it is different from a boundary bypass.

## No security warranty

Airlock is provided under the Apache License 2.0 on an "AS IS" basis. Security software reduces risk; it does not eliminate operating-system, hypervisor, administrator, supply-chain, or user-configuration risk.
