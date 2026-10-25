import unittest

from dependency_audit import release_version, update_kind


class ReleaseComparisonTests(unittest.TestCase):
    def test_numeric_versions_do_not_sort_as_strings(self):
        self.assertEqual(update_kind('1.9.0', 'v1.13.3'), 'minor')

    def test_major_upgrade_requires_review(self):
        self.assertEqual(update_kind('1.17.1', '2.6.0'), 'major')

    def test_older_and_equal_releases_are_not_updates(self):
        self.assertIsNone(update_kind('1.3.0', '1.3.0'))
        self.assertIsNone(update_kind('1.3.0', '1.2.9'))

    def test_prereleases_are_rejected(self):
        with self.assertRaises(ValueError):
            release_version('2.0.0-rc.1')

    def test_patch_upgrade(self):
        self.assertEqual(update_kind('1.19.2', '1.19.7'), 'patch')


if __name__ == '__main__':
    unittest.main()
