#!/usr/bin/env python3
"""The reverse-tool installer ships in the image at the path the app runs.

Regression: the app invoked /root/install-tools.sh, which the build never created, so a
fresh rootfs could never install jadx / apktool / radare2 / binutils.
"""
import importlib.util
from pathlib import Path
import sys
import unittest

sys.dont_write_bytecode = True
RUNTIME = Path(__file__).resolve().parents[1]
REPO = RUNTIME.parent
spec = importlib.util.spec_from_file_location('rtbuild', RUNTIME / 'lib/rtbuild.py')
rtbuild = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rtbuild)


class ToolchainInstaller(unittest.TestCase):
    def test_overlay_ships_the_installer_executable(self):
        entries = rtbuild.overlay_entries({'runtimeVersion': 'test'})
        path = rtbuild.TOOLCHAIN_SCRIPT.lstrip('/')
        self.assertIn(path, entries)
        entry = entries[path]
        self.assertEqual(entry.kind, 'file')
        self.assertEqual(entry.mode, 0o755)
        self.assertTrue(entry.read().startswith(b'#!/bin/sh'))
        self.assertEqual(entry.read(), (RUNTIME / 'toolchain' / 'install-tools.sh').read_bytes())

    def test_app_invokes_that_exact_path(self):
        installer = (REPO / 'app/android/app/src/main/kotlin/io/github/ccch1mneyyy/'
                            'dsh_app/fork/runtime/ToolchainInstaller.kt').read_text()
        self.assertIn('internal const val TOOLCHAIN_SCRIPT = "%s"' % rtbuild.TOOLCHAIN_SCRIPT, installer)
        self.assertNotIn('"/root/install-tools.sh"', installer)

    def test_runtime_version_hashes_the_installer(self):
        build = (RUNTIME / 'build-runtime.sh').read_text()
        self.assertIn('find patches bridge boot direct toolchain', build)


if __name__ == '__main__':
    unittest.main(verbosity=2)
