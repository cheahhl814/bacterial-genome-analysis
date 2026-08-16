#!/usr/bin/env python3
"""Smoke tests for the bacterial-genome-analysis Nextflow runner (v5.1).

Validates the runner is structurally sound and runnable without executing any
real analysis tools:

  - required file layout (main.nf, nextflow.config, SKILL.md, conf/*)
  - Java + Nextflow availability
  - `nextflow config` parses and the required profiles / params are declared
  - every module follows the bettamt patterns (tag, label, container, emit)
  - subworkflows include the expected module cross-references
  - the DAG builds via the test profile (stub-run; a missing spades.py on PATH
    is treated as an expected stub-only failure, not a fail)
  - test fixtures and nf-core resource labels are present

Run with:
    python3 test_smoke.py          # structural + execution checks (no tools run)
    python3 test_smoke.py --offline  # structural checks only (no nextflow subprocess)

All Nextflow subprocesses run inside a temporary working directory, so no
`.nextflow.log` / `work/` / `results/` artifacts are left behind.

Exit code 0 on success, 1 on failure.
"""

import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent

REQUIRED = [
    "main.nf",
    "nextflow.config",
    "SKILL.md",
    "conf/base.config",
    "conf/modules.config",
    "conf/test.config",
]

REQUIRED_PROFILES = ["standard", "docker", "singularity", "test"]
REQUIRED_PARAMS = ["reads", "outdir", "mode"]
REQUIRED_LABELS = [
    "process_single",
    "process_low",
    "process_medium",
    "process_high",
    "process_long",
]

SUBWORKFLOW_MODULES = {
    "preflight_to_polish.nf": ["short_read_assembly", "long_read_assembly",
                               "hybrid_assembly", "polish"],
    "polish_to_qc.nf": ["quast", "busco", "checkm"],
    "qc_to_annotation.nf": ["bakta"],
}

TIMEOUT = 180


def trunc(text, limit=500):
    """Shorten output for failure messages."""
    text = str(text).strip()
    return text[:limit] + f" ...[{len(text) - limit} more chars]" if len(text) > limit else text


def _major_version(name):
    """Major version from a JDK directory name like '21.0.11-tem' (or 0)."""
    m = re.match(r"(\d+)", name or "")
    return int(m.group(1)) if m else 0


def _resolve_java_home():
    """Pick a usable JAVA_HOME without hardcoding a machine-specific path.

    Preference: the newest JDK with major version 8..22 (Nextflow 24.x rejects
    Java 25) found in $JAVA_HOME or under ~/.sdkman/candidates/java. Falls back
    to any JDK at all if nothing matches the range.
    """
    candidates = []
    if os.environ.get("JAVA_HOME"):
        candidates.append(Path(os.environ["JAVA_HOME"]))
    sdkman = Path.home() / ".sdkman" / "candidates" / "java"
    if sdkman.is_dir():
        candidates.extend(sorted(
            (d for d in sdkman.iterdir() if (d / "bin" / "java").exists()),
            key=lambda d: _major_version(d.name), reverse=True))
    for home in candidates:
        if 8 <= _major_version(home.name) <= 22:
            return str(home)
    for home in candidates:
        return str(home)
    return None


def _nextflow_cmd():
    """Path to nextflow, or None if not on PATH."""
    return shutil.which("nextflow")


def _env_with_java(java_home):
    env = os.environ.copy()
    env["JAVA_HOME"] = java_home
    return env


def _run(cmd, cwd, env=None, timeout=TIMEOUT):
    """Run a subprocess and return (returncode, combined stdout+stderr)."""
    try:
        proc = subprocess.run(cmd, cwd=cwd, env=env, capture_output=True,
                              text=True, timeout=timeout)
    except subprocess.TimeoutExpired as exc:
        out = (exc.stdout or "")
        if not isinstance(out, str):
            out = out.decode(errors="replace")
        return 124, f"TIMEOUT after {timeout}s\n{out}"
    return proc.returncode, (proc.stdout or "") + "\n" + (proc.stderr or "")


def _extract_block(text, keyword):
    """Return the brace-balanced body of a `keyword { ... }` block, or None.

    Brace-counting is used so comments containing braces (e.g. a `{1,2}` read
    glob) do not truncate the block.
    """
    m = re.search(rf"^\s*{keyword}\s*\{{", text, re.M)
    if not m:
        return None
    depth = 0
    for j in range(m.end() - 1, len(text)):
        if text[j] == "{":
            depth += 1
        elif text[j] == "}":
            depth -= 1
            if depth == 0:
                return text[m.end():j]
    return None


def _iter_process_blocks(text):
    """Yield each `process NAME { ... }` block from a module file."""
    for part in re.split(r"(?=^\s*process\s+\w+)", text, flags=re.M):
        if re.match(r"^\s*process\s+\w+", part, flags=re.M):
            yield part


def _write(file_path):
    return (HERE / file_path).read_text()


class TestNextflowRunnerStructure(unittest.TestCase):
    """Structural checks that need no Nextflow subprocess."""

    def test_01_layout(self):
        for name in REQUIRED:
            self.assertTrue((HERE / name).exists(),
                            msg=f"missing required file: {name}")

    def test_04_profiles_present(self):
        cfg = _write("nextflow.config")
        block = _extract_block(cfg, "profiles")
        self.assertIsNotNone(block, msg="no `profiles { ... }` block in nextflow.config")
        names = set(re.findall(r"^\s*(\w+)\s*\{", block, re.M))
        for profile in REQUIRED_PROFILES:
            self.assertIn(profile, names,
                          msg=f"missing profile `{profile}` (found: {sorted(names)})")

    def test_05_required_params(self):
        cfg = _write("nextflow.config")
        block = _extract_block(cfg, "params")
        self.assertIsNotNone(block, msg="no `params { ... }` block in nextflow.config")
        for param in REQUIRED_PARAMS:
            self.assertIsNotNone(re.search(rf"^\s*{param}\s*=", block, re.M),
                                 msg=f"missing required param `{param}`")

    def test_06_modules_bettamt_patterns(self):
        modules = sorted((HERE / "modules").glob("*.nf"))
        self.assertGreaterEqual(len(modules), 1, msg="no module files found")
        for path in modules:
            text = path.read_text()
            blocks = list(_iter_process_blocks(text))
            self.assertGreaterEqual(len(blocks), 1,
                                    msg=f"{path.name}: no `process` block found")
            for block in blocks:
                name = re.search(r"process\s+(\w+)", block).group(1)
                for directive in ("tag", "label", "container"):
                    self.assertIsNotNone(
                        re.search(rf"(?m)^\s*{directive}\s+", block),
                        msg=f"{path.name}:{name}: missing `{directive}` directive")
                self.assertIsNotNone(re.search(r"(?m)^\s*output\s*:", block),
                                     msg=f"{path.name}:{name}: missing `output:` block")
                self.assertIsNotNone(re.search(r"\bemit\s*:", block),
                                     msg=f"{path.name}:{name}: output has no `emit`")
                cont = re.search(r"container\s+(['\"])([^'\"]+)\1", block)
                self.assertIsNotNone(cont,
                                     msg=f"{path.name}:{name}: no pinned container image")
                self.assertNotIn(":latest", cont.group(2),
                                 msg=f"{path.name}:{name}: container uses `:latest` "
                                     f"({cont.group(2)})")

    def test_07_subworkflows_include_modules(self):
        for subworkflow, expected in SUBWORKFLOW_MODULES.items():
            path = HERE / "subworkflows" / subworkflow
            self.assertTrue(path.exists(), msg=f"missing subworkflow: {subworkflow}")
            text = path.read_text()
            included = {Path(m).stem for m in
                        re.findall(r"include\s*\{[^}]*\}\s*from\s*'([^']+)'", text, re.S)}
            for module in expected:
                self.assertIn(module, included,
                              msg=f"{subworkflow}: expected include from "
                                  f"`modules/{module}` (found: {sorted(included)})")

    def test_09_test_fixtures(self):
        for name in ("SAMPLE1_1.fastq.gz", "SAMPLE1_2.fastq.gz"):
            path = HERE / "test_data" / "reads" / name
            self.assertTrue(path.exists(), msg=f"missing test fixture: {name}")
            self.assertGreaterEqual(path.stat().st_size, 10,
                                    msg=f"test fixture too small (<10 bytes): {name}")

    def test_10_resource_labels(self):
        base = _write("conf/base.config")
        for label in REQUIRED_LABELS:
            self.assertIsNotNone(
                re.search(rf"withLabel\s*:\s*'{label}'", base),
                msg=f"missing resource label `{label}` in conf/base.config")


class TestNextflowRunnerExecution(unittest.TestCase):
    """Checks that shell out to Nextflow. Skipped when the toolchain is absent."""

    def setUp(self):
        if "--offline" in sys.argv:
            self.skipTest("offline mode (structural checks only)")
        self.nextflow = _nextflow_cmd()
        if self.nextflow is None:
            self.skipTest("nextflow not on PATH")
        self.java_home = _resolve_java_home()
        if self.java_home is None:
            self.skipTest("no Java 8-22 found; set JAVA_HOME to a JDK "
                          "(e.g. ~/.sdkman/candidates/java/21.0.11-tem)")
        self.env = _env_with_java(self.java_home)

    def test_02_java_nextflow_availability(self):
        rc, out = _run([self.nextflow, "-version"], cwd=str(HERE), env=self.env,
                       timeout=60)
        self.assertEqual(rc, 0, msg=f"`nextflow -version` failed:\n{trunc(out)}")
        self.assertIn("N E X T F L O W", out,
                      msg=f"unexpected `nextflow -version` output:\n{trunc(out)}")

    def test_03_config_parses(self):
        with tempfile.TemporaryDirectory(prefix="nfx-config-") as tmp:
            # Documented form: `nextflow config -log nextflow.log`
            rc, out = _run([self.nextflow, "config", "-log", "nextflow.log",
                            str(HERE)], cwd=tmp, env=self.env)
            if rc != 0:
                # Nextflow < 24.10.6 rejects `-log` after the subcommand.
                rc, out = _run([self.nextflow, "config", str(HERE)],
                               cwd=tmp, env=self.env)
            self.assertEqual(rc, 0, msg=f"`nextflow config` failed:\n{trunc(out)}")
            for param in REQUIRED_PARAMS:
                self.assertIn(param, out, msg=f"resolved config missing `{param}`")

    def test_08_stub_run_builds_dag(self):
        # Documented smoke-test form. `--stub-run` (double dash) is treated as
        # a param, so tools actually run: PREFLIGHT needs seqkit, SPADES needs
        # spades.py. On a plain machine both are missing; that is expected.
        with tempfile.TemporaryDirectory(prefix="nfx-dag-") as tmp:
            rc, out = _run([self.nextflow, "run", str(HERE / "main.nf"),
                            "-profile", "test", "--stub-run"], cwd=tmp, env=self.env)
            preflight_ok = "PREFLIGHT" in out and "✔" in out
            spades_missing = ("spades.py: command not found" in out
                              or ("SPADES_ASSEMBLY" in out and "(127)" in out))
            if rc == 0:
                self.assertIn("SPADES_ASSEMBLY", out,
                              msg=f"stub-run DAG missing SPADES:\n{trunc(out)}")
            else:
                self.assertTrue(
                    preflight_ok and spades_missing,
                    msg=f"stub-run failed unexpectedly (rc={rc}); expected the "
                        f"missing-spades stub-only failure once preflight passes:\n"
                        f"{trunc(out)}")

        # Authoritative DAG build: the real `-stub-run` flag executes no tools.
        # Fresh cwd per invocation so trace/report/timeline never collide.
        with tempfile.TemporaryDirectory(prefix="nfx-dag-stub-") as tmp:
            rc2, out2 = _run([self.nextflow, "run", str(HERE / "main.nf"),
                              "-profile", "test", "-stub-run"], cwd=tmp, env=self.env)
            self.assertEqual(rc2, 0, msg=f"`-stub-run` DAG build failed:\n{trunc(out2)}")
            self.assertIn("PREFLIGHT", out2,
                          msg=f"DAG did not build past preflight:\n{trunc(out2)}")
            self.assertIn("SPADES_ASSEMBLY", out2,
                          msg=f"DAG did not reach assembly stage:\n{trunc(out2)}")


def main():
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(unittest.TestLoader().loadTestsFromModule(__import__(__name__)))
    sys.exit(0 if result.wasSuccessful() else 1)


if __name__ == "__main__":
    main()
