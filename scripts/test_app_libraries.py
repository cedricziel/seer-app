import plistlib
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from scripts.check_app_libraries import load_commands, unresolved_libraries


class AppLibrariesTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.app = Path(self.temp.name) / 'SeerApp.app'

    def bundle(self, mac=False, runpath='@executable_path/Frameworks'):
        contents = self.app / 'Contents' if mac else self.app
        executable_dir = contents / 'MacOS' if mac else contents
        executable_dir.mkdir(parents=True)
        main = executable_dir / 'SeerApp'
        main.touch()
        (contents / 'Info.plist').write_bytes(plistlib.dumps({'CFBundleExecutable': 'SeerApp'}))
        framework = contents / 'Frameworks/Client.framework/Client'
        framework.parent.mkdir(parents=True)
        framework.touch()
        return {
            main: ({'@rpath/Client.framework/Client'}, {runpath}),
            framework: ({'@rpath/DequeModule.framework/DequeModule'}, set()),
        }

    def check(self, commands):
        with patch('scripts.check_app_libraries.load_commands', side_effect=commands.__getitem__):
            return unresolved_libraries(self.app)

    def test_missing_transitive_framework_fails_even_when_direct_framework_is_embedded(self):
        errors = self.check(self.bundle())
        self.assertEqual(len(errors), 1)
        self.assertIn('DequeModule', errors[0])

    def test_mac_ios_runpath_fails_despite_embedded_framework(self):
        commands = self.bundle(mac=True)
        errors = self.check(commands)
        self.assertTrue(any('cannot resolve @rpath/Client.framework/Client' in e for e in errors))

    def test_mac_correct_runpath_resolves_embedded_framework(self):
        commands = self.bundle(mac=True, runpath='@executable_path/../Frameworks')
        framework = self.app / 'Contents/Frameworks/Client.framework/Client'
        commands[framework] = ({'/usr/lib/libSystem.B.dylib'}, set())
        self.assertEqual(self.check(commands), [])

    def test_ios_complete_dependency_closure_passes(self):
        commands = self.bundle()
        deque = self.app / 'Frameworks/DequeModule.framework/DequeModule'
        deque.parent.mkdir()
        deque.touch()
        commands[deque] = (set(), set())
        self.assertEqual(self.check(commands), [])

    def test_parser_checks_required_libraries_but_allows_missing_weak_libraries(self):
        output = '''Load command 0
          cmd LC_ID_DYLIB
         name @rpath/Client.framework/Client (offset 24)
Load command 1
          cmd LC_LOAD_DYLIB
         name @rpath/DequeModule.framework/DequeModule (offset 24)
Load command 2
          cmd LC_LOAD_WEAK_DYLIB
         name @rpath/Optional.framework/Optional (offset 24)
Load command 3
          cmd LC_RPATH
         path @executable_path/../Frameworks (offset 12)
'''
        with patch('scripts.check_app_libraries.subprocess.check_output', return_value=output):
            self.assertEqual(load_commands(Path('Client')), (
                {'@rpath/DequeModule.framework/DequeModule'},
                {'@executable_path/../Frameworks'},
            ))


if __name__ == '__main__':
    unittest.main()
