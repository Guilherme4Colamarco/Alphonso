#!/usr/bin/env python3
"""Runtime regression tests for the local QML support processes."""

from __future__ import annotations

import importlib.util
import json
import os
import select
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
QML_DIR = REPO_ROOT / ".config" / "quickshell"


def load_module(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise ImportError(f"cannot load {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def process_is_alive(pid: int) -> bool:
    stat_path = Path(f"/proc/{pid}/stat")
    try:
        state = stat_path.read_text(encoding="utf-8").split()[2]
    except (FileNotFoundError, IndexError, PermissionError):
        return False
    return state != "Z"


class RuntimeInfrastructureTests(unittest.TestCase):
    def test_state_store_replaces_json_atomically(self) -> None:
        store = load_module("kamalen_state_store", QML_DIR / "state_store.py")

        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / "nested" / "settings.json"
            store.write_json_atomic(target, {"skin": "commonality", "scale": 1.15})

            self.assertEqual(
                {"skin": "commonality", "scale": 1.15},
                json.loads(target.read_text(encoding="utf-8")),
            )
            self.assertEqual([], list(target.parent.glob(f".{target.name}.*")))

    def test_process_supervisor_terminates_the_entire_child_group(self) -> None:
        supervisor = QML_DIR / "process_supervisor.py"
        child_code = (
            "import subprocess,time; "
            "child=subprocess.Popen(['sleep','30']); "
            "print(child.pid, flush=True); "
            "time.sleep(30)"
        )
        proc = subprocess.Popen(
            [sys.executable, str(supervisor), "--", sys.executable, "-c", child_code],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        grandchild_pid = 0
        try:
            ready, _, _ = select.select([proc.stdout], [], [], 3.0)
            self.assertTrue(ready, proc.stderr.read() if proc.poll() is not None else "")
            grandchild_pid = int(proc.stdout.readline().strip())
            self.assertTrue(process_is_alive(grandchild_pid))

            proc.send_signal(signal.SIGTERM)
            proc.wait(timeout=3.0)
            deadline = time.monotonic() + 3.0
            while process_is_alive(grandchild_pid) and time.monotonic() < deadline:
                time.sleep(0.05)
            self.assertFalse(process_is_alive(grandchild_pid))
        finally:
            if proc.poll() is None:
                proc.kill()
                proc.wait(timeout=2.0)
            if grandchild_pid and process_is_alive(grandchild_pid):
                os.kill(grandchild_pid, signal.SIGKILL)
            if proc.stdout:
                proc.stdout.close()
            if proc.stderr:
                proc.stderr.close()

    def test_process_supervisor_survives_an_abrupt_wrapper_kill(self) -> None:
        supervisor = QML_DIR / "process_supervisor.py"
        child_code = (
            "import subprocess,time; "
            "child=subprocess.Popen(['sleep','30']); "
            "print(child.pid, flush=True); "
            "time.sleep(30)"
        )
        proc = subprocess.Popen(
            [sys.executable, str(supervisor), "--", sys.executable, "-c", child_code],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        grandchild_pid = 0
        child_group = 0
        try:
            ready, _, _ = select.select([proc.stdout], [], [], 3.0)
            self.assertTrue(ready, proc.stderr.read() if proc.poll() is not None else "")
            grandchild_pid = int(proc.stdout.readline().strip())
            child_group = os.getpgid(grandchild_pid)

            proc.kill()
            proc.wait(timeout=3.0)
            deadline = time.monotonic() + 3.0
            while process_is_alive(grandchild_pid) and time.monotonic() < deadline:
                time.sleep(0.05)
            self.assertFalse(process_is_alive(grandchild_pid))
        finally:
            if proc.poll() is None:
                proc.kill()
                proc.wait(timeout=2.0)
            if child_group:
                try:
                    os.killpg(child_group, signal.SIGKILL)
                except ProcessLookupError:
                    pass
            if proc.stdout:
                proc.stdout.close()
            if proc.stderr:
                proc.stderr.close()

    def test_ipc_bridge_reports_named_file_events(self) -> None:
        bridge = QML_DIR / "ipc_bridge.py"
        with tempfile.TemporaryDirectory() as directory:
            event_file = Path(directory) / "dashboard"
            proc = subprocess.Popen(
                [sys.executable, str(bridge), f"dashboard={event_file}"],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
            )
            try:
                ready, _, _ = select.select([proc.stdout], [], [], 3.0)
                self.assertTrue(ready, proc.stderr.read() if proc.poll() is not None else "")
                self.assertEqual("READY", proc.stdout.readline().strip())

                event_file.touch()
                received, _, _ = select.select([proc.stdout], [], [], 3.0)
                self.assertTrue(received, proc.stderr.read() if proc.poll() is not None else "")
                self.assertEqual("dashboard", proc.stdout.readline().strip())
            finally:
                proc.terminate()
                proc.wait(timeout=3.0)
                if proc.stdout:
                    proc.stdout.close()
                if proc.stderr:
                    proc.stderr.close()


if __name__ == "__main__":
    unittest.main()
