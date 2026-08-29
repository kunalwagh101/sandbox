import copy
import json
from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[1]


STRICT_SANDBOX = {
    "networking": "Disable",
    "vGPU": "Disable",
    "audioInput": "Disable",
    "videoInput": "Disable",
    "clipboardRedirection": "Disable",
    "printerRedirection": "Disable",
    "protectedClient": "Enable",
}


def validate_strict_policy(policy):
    if policy.get("schemaVersion") != 1:
        raise ValueError("unsupported schema")
    if policy.get("profileName") != "strict-offline":
        raise ValueError("unsupported profile")
    sandbox = policy.get("sandbox", {})
    for name, expected in STRICT_SANDBOX.items():
        if sandbox.get(name) != expected:
            raise ValueError(f"{name} must be {expected}")
    memory = sandbox.get("memoryMB")
    if not isinstance(memory, int) or not 2048 <= memory <= 4096:
        raise ValueError("memory outside binding ceiling")


class Increment1ContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.policy = json.loads((ROOT / "policy.json").read_text(encoding="utf-8"))
        cls.common = (ROOT / "scripts" / "Airlock.Common.ps1").read_text(
            encoding="utf-8"
        )
        cls.initialize = (ROOT / "scripts" / "Initialize-Airlock.ps1").read_text(
            encoding="utf-8"
        )
        cls.profile = (ROOT / "scripts" / "New-AirlockProfile.ps1").read_text(
            encoding="utf-8"
        )
        cls.start = (ROOT / "scripts" / "Start-Airlock.ps1").read_text(
            encoding="utf-8"
        )
        cls.provision = (ROOT / "guest" / "provision.ps1").read_text(
            encoding="utf-8"
        )
        cls.benchmark = (ROOT / "tests" / "Measure-Increment1.ps1").read_text(
            encoding="utf-8"
        )

    def test_strict_policy_and_deliberate_weakening(self):
        validate_strict_policy(self.policy)
        for name in STRICT_SANDBOX:
            weakened = copy.deepcopy(self.policy)
            weakened["sandbox"][name] = "Enable" if name != "protectedClient" else "Disable"
            with self.subTest(name=name), self.assertRaises(ValueError):
                validate_strict_policy(weakened)

        self.assertEqual("UNINITIALIZED", self.policy["package"]["expectedSha256"])
        self.assertEqual(
            "UNINITIALIZED", self.policy["guest"]["provisionScriptSha256"]
        )

    def test_profile_has_only_bounded_explicit_mappings(self):
        self.assertIn("Assert-AirlockMappedPath", self.profile)
        self.assertIn("Assert-AirlockNoReparsePoint", self.common)
        self.assertIn("Assert-AirlockPrivateRoot", self.common)
        self.assertIn("Airlock-relative audit and state paths can never be mapped", self.common)
        self.assertIn("Host = $bootstrap; Guest = 'C:\\AirlockBootstrap'; ReadOnly = 'true'", self.profile)
        self.assertIn("Host = $result; Guest = 'C:\\AirlockResult'; ReadOnly = 'false'", self.profile)
        self.assertNotIn("$env:USERPROFILE, 'true'", self.profile)
        self.assertNotIn("$env:USERPROFILE, 'false'", self.profile)
        for element in (
            "vGPU",
            "Networking",
            "AudioInput",
            "VideoInput",
            "ProtectedClient",
            "PrinterRedirection",
            "ClipboardRedirection",
            "MemoryInMB",
        ):
            self.assertIn(f"'{element}'", self.profile)

    def test_preflight_refuses_unsupported_or_ambiguous_hosts(self):
        for requirement in (
            "Windows 11 Pro, Enterprise, or Education",
            "below 26100",
            "AMD64",
            "ARM64",
            "at least 4 GB",
            "at least two CPU cores",
            "free at least 1 GB",
            "Hardware virtualisation or SLAT",
            "Containers-DisposableClientVM",
            "System32\\wsb.exe",
        ):
            self.assertIn(requirement, self.start)
        self.assertIn("Airlock preflight failed", self.start)
        self.assertLess(
            self.start.index("$preflight = Invoke-AirlockPreflight"),
            self.start.index("'start', '--config'"),
        )

    def test_launch_is_single_session_hash_checked_and_atomic(self):
        self.assertIn("Local\\Airlock-Launch", self.start)
        self.assertLess(
            self.start.index("@('list', '--raw')"),
            self.start.index("'start', '--config'"),
        )
        self.assertIn("another Windows Sandbox is active", self.start)
        self.assertIn("Get-AirlockSessionIdAfterStart", self.start)
        self.assertIn("active-session.json", self.start)
        self.assertIn("Write-AirlockJsonAtomic", self.start)
        self.assertIn("[IO.File]::Replace($temporary, $destination, $backup)", self.common)
        self.assertNotIn("[IO.File]::Replace($temporary, $destination, $null)", self.common)
        self.assertIn("'start', '--config', $profileXml, '--raw'", self.start)
        self.assertGreaterEqual(self.start.count("Get-FileHash"), 5)
        self.assertIn("provisioning script changed after initialisation", self.start)
        self.assertIn("bootstrapMapping = 'read-only'", self.start)

    def test_initializer_pins_signed_installer_and_provisioner(self):
        self.assertIn("Get-AuthenticodeSignature", self.initialize)
        self.assertIn("SignatureStatus]::Valid", self.initialize)
        self.assertIn("expectedPublisher", self.initialize)
        self.assertIn("Brave Software, Inc.", self.initialize)
        self.assertIn("Get-FileHash", self.initialize)
        self.assertIn("packageRelativePath", self.initialize)
        self.assertIn("provisionScriptSha256", self.initialize)
        self.assertIn("Write-AirlockJsonAtomic", self.initialize)
        self.assertIn("$PSCmdlet.ShouldProcess", self.initialize)
        self.assertIn("New-AirlockInitializationResult", self.initialize)
        self.assertIn("PolicyWritten", self.common)
        self.assertNotIn("Invoke-WebRequest", self.initialize)

    def test_guest_rechecks_package_and_records_exact_version(self):
        self.assertIn("Get-FileHash", self.provision)
        self.assertIn("Get-AuthenticodeSignature", self.provision)
        self.assertIn("expectedPublisher", self.provision)
        self.assertIn("$PSCommandPath", self.provision)
        self.assertIn("installer hash mismatch", self.provision)
        self.assertIn("Start-Process -FilePath $installerPath -Wait -PassThru", self.provision)
        self.assertIn("browserVersion", self.provision)
        self.assertIn("browserProcessId", self.provision)
        self.assertIn("networking = [string]$policy.sandbox.networking", self.provision)
        self.assertIn("status = 'failed'", self.provision)
        self.assertNotIn("http://", self.provision)
        self.assertNotIn("https://", self.provision)

    def test_no_bootstrap_source_is_mapped_directly(self):
        self.assertIn("Copy-Item -LiteralPath $packagePath", self.start)
        self.assertIn("Copy-Item -LiteralPath $provisionSource", self.start)
        self.assertIn("Copy-Item -LiteralPath $policyFile", self.start)
        self.assertNotIn("HostFolder', $repoRoot", self.profile)
        self.assertNotIn("HostFolder', $packagePath", self.profile)

    def test_resource_benchmark_has_three_runs_and_enforced_limits(self):
        self.assertIn("$index -le 3", self.benchmark)
        self.assertIn("MaxColdLaunchSeconds", self.benchmark)
        self.assertIn("MaxPeakRamDeltaMB", self.benchmark)
        self.assertIn("MaxDiskDeltaMB", self.benchmark)
        self.assertIn("CollectOnly", self.benchmark)
        self.assertIn("failedRunCount", self.benchmark)
        self.assertIn("idleRamDeltaMB", self.benchmark)
        self.assertIn("medianColdLaunchSeconds", self.benchmark)
        self.assertIn("worstColdLaunchSeconds", self.benchmark)
        self.assertIn("overallStatus", self.benchmark)
        self.assertIn("exit 1", self.benchmark)


if __name__ == "__main__":
    unittest.main()
