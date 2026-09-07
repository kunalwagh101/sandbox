## What changed

Describe the problem and the smallest production-safe change.

## Security boundary impact

- [ ] No security boundary change
- [ ] Host filesystem/mappings
- [ ] Network/device/clipboard/vGPU policy
- [ ] Installer trust/supply chain
- [ ] Path/reparse-point handling
- [ ] Sandbox/process lifecycle
- [ ] Host state/cleanup
- [ ] Guest writable output
- [ ] Windows compatibility

Explain any checked item:

## Verification

Exact commands run and results:

```text

```

- [ ] Python tests pass
- [ ] `scripts/verify_board.py` passes where applicable
- [ ] Source acceptance passes
- [ ] Compatibility acceptance passes
- [ ] Lifecycle acceptance passes
- [ ] Live target-host acceptance completed if native Windows Sandbox behavior changed
- [ ] Documentation updated
- [ ] Migration/rollback considered

## Evidence and status

Do not mark a security claim DONE solely from source tests when the repository requires target-host evidence.

## Publication safety

- [ ] No credentials, tokens, private keys, certificates, customer/private data, local state, or installer binaries are included
- [ ] No security control was weakened merely to make a test pass
