import os
import platform
import hashlib
import shutil
import zipfile
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class SwiftToolsTests(unittest.TestCase):
    def test_ignores_path_and_propagates_tool_failure(self):
        with tempfile.TemporaryDirectory() as work:
            cache = Path(work)
            binary = cache / ('swiftlint-0.63.2-' + ('Darwin' if platform.system() == 'Darwin' else 'Linux-' + platform.machine())) / 'swiftlint'
            binary.parent.mkdir()
            binary.write_text('#!/bin/sh\n[ "$1" = --version ] && { echo 0.63.2; exit; }\nexit 42\n')
            binary.chmod(0o755)
            wrong = cache / 'swiftlint'
            wrong.write_text('#!/bin/sh\nexit 99\n')
            wrong.chmod(0o755)
            result = subprocess.run(
                ['bash', str(ROOT / 'scripts/swift-tools'), 'swiftlint', 'lint'],
                env={**os.environ, 'SEER_SWIFT_TOOLS_CACHE': work, 'PATH': work + os.pathsep + os.environ['PATH']},
                capture_output=True,
            )
            self.assertEqual(result.returncode, 42, result.stderr)

    def test_platforms_pin_one_version_per_tool(self):
        rows = [line.split() for line in (ROOT / 'scripts/swift-tools.lock').read_text().splitlines()
                if line and not line.startswith('#')]
        self.assertEqual({row[1] for row in rows if row[0] == 'swiftlint'}, {'0.63.2'})
        self.assertEqual({row[1] for row in rows if row[0] == 'swiftformat'}, {'0.61.1'})
        self.assertEqual(len(rows), 6)

    def bootstrap_fixture(self, work, checksum_valid=True):
        root = Path(work)
        scripts = root / 'scripts'
        scripts.mkdir()
        shutil.copy(ROOT / 'scripts/swift-tools', scripts / 'swift-tools')
        archive = root / 'release.zip'
        with zipfile.ZipFile(archive, 'w') as release:
            release.writestr('swiftlint', '#!/bin/sh\necho 0.63.2\n')
        checksum = hashlib.sha256(archive.read_bytes()).hexdigest() if checksum_valid else '0' * 64
        target = 'Darwin' if platform.system() == 'Darwin' else 'Linux-' + platform.machine()
        (scripts / 'swift-tools.lock').write_text(
            f'swiftlint 0.63.2 {target} release.zip swiftlint {checksum}\n')
        curl = root / 'curl'
        curl.write_text('#!/bin/sh\nwhile [ "$1" != -o ]; do shift; done\ncp "$FIXTURE_ARCHIVE" "$2"\n')
        curl.chmod(0o755)
        env = {**os.environ, 'PATH': work + os.pathsep + os.environ['PATH'],
               'FIXTURE_ARCHIVE': str(archive), 'SEER_SWIFT_TOOLS_CACHE': str(root / 'cache')}
        return scripts / 'swift-tools', env, curl

    def test_bootstrap_reuses_verified_install_without_downloading(self):
        with tempfile.TemporaryDirectory() as work:
            entry, env, curl = self.bootstrap_fixture(work)
            first = subprocess.run(['bash', str(entry), 'swiftlint', '--version'], env=env, capture_output=True)
            self.assertEqual(first.returncode, 0, first.stderr)
            curl.write_text('#!/bin/sh\nexit 88\n')
            reused = subprocess.run(['bash', str(entry), 'swiftlint', '--version'], env=env, capture_output=True)
            self.assertEqual(reused.returncode, 0, reused.stderr)
            self.assertEqual(reused.stdout, b'0.63.2\n')

    def test_bad_checksum_never_publishes_install(self):
        with tempfile.TemporaryDirectory() as work:
            entry, env, _ = self.bootstrap_fixture(work, checksum_valid=False)
            result = subprocess.run(['bash', str(entry), 'swiftlint', '--version'], env=env, capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(list((Path(work) / 'cache').iterdir()), [])

    def test_rejects_wrong_cached_version(self):
        with tempfile.TemporaryDirectory() as work:
            target = 'Darwin' if platform.system() == 'Darwin' else 'Linux-' + platform.machine()
            binary = Path(work) / ('swiftlint-0.63.2-' + target) / 'swiftlint'
            binary.parent.mkdir()
            binary.write_text('#!/bin/sh\necho 9.9.9\n')
            binary.chmod(0o755)
            result = subprocess.run(
                ['bash', str(ROOT / 'scripts/swift-tools'), 'swiftlint', 'lint'],
                env={**os.environ, 'SEER_SWIFT_TOOLS_CACHE': work}, capture_output=True,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn(b'expected 0.63.2', result.stderr)


if __name__ == '__main__':
    unittest.main()
