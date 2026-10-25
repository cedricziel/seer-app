import json
import os
from pathlib import Path
import re
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]


def release_version(value):
    match = re.fullmatch(r'v?(\d+)\.(\d+)\.(\d+)', value)
    if not match:
        raise ValueError(f'Unsupported stable version: {value}')
    return tuple(map(int, match.groups()))


def update_kind(current, latest):
    old, new = release_version(current), release_version(latest)
    if new <= old:
        return None
    return next(kind for a, b, kind in zip(old, new, ('major', 'minor', 'patch')) if a != b)


def deferred_reason(repo, latest, deferrals):
    entry = deferrals.get(repo)
    if entry and release_version(latest) <= release_version(entry['version']):
        return entry['reason']
    return None


def dependency_pins():
    lockfiles = [
        ROOT / 'SeerApp.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved',
        ROOT / 'Packages/JellyseerrAPI/Package.resolved',
    ]
    for lockfile in lockfiles:
        for pin in json.loads(lockfile.read_text())['pins']:
            repo = pin['location'].removeprefix('https://github.com/').removesuffix('.git')
            yield repo, pin['state']['version'], str(lockfile.relative_to(ROOT))
    source = 'scripts/swift-tools.lock'
    tool_versions = {}
    for line in (ROOT / source).read_text().splitlines():
        if not line or line.startswith('#'):
            continue
        tool, version, *_ = line.split()
        if tool in tool_versions and tool_versions[tool] != version:
            raise ValueError(f'{tool} versions differ between platforms')
        tool_versions[tool] = version
    for tool, repo in [('swiftlint', 'realm/SwiftLint'), ('swiftformat', 'nicklockwood/SwiftFormat')]:
        yield repo, tool_versions[tool], source

    source = 'Packages/JellyseerrAPI/README.md'
    guide = (ROOT / source).read_text()
    for repo, pattern in [
        ('apple/swift-openapi-generator', r'`swift-openapi-generator` (\d+\.\d+\.\d+)'),
        ('seerr-team/seerr', r'\[Seerr v(\d+\.\d+\.\d+)'),
    ]:
        yield repo, re.search(pattern, guide).group(1), source


def audit():
    releases = {}
    rows = []
    needs_review = False
    deferrals = json.loads((ROOT / '.github/dependency-audit-deferrals.json').read_text())
    for repo, current, source in dependency_pins():
        if repo not in releases:
            result = subprocess.run(
                ['gh', 'api', f'repos/{repo}/releases/latest'],
                check=True, capture_output=True, text=True,
            )
            releases[repo] = json.loads(result.stdout)
        release = releases[repo]
        latest = release['tag_name']
        kind = update_kind(current, latest)
        if kind:
            reason = deferred_reason(repo, latest, deferrals)
            needs_review |= reason is None
            status = f'Deferred: {reason}' if reason else 'New release: review required'
            rows.append(f'| {repo} | {current} | [{latest}]({release["html_url"]}) | {kind} | {source} | {status} |')
    report = '\n'.join([
        '# Dependency audit', '',
        'Newer stable releases are candidates for review; transitive constraints may prevent updates.',
        'Major updates require migration review. Dependabot covers Bundler and GitHub Actions.', '',
        'Reviewed deferrals remain visible; only newer unreviewed releases fail the audit.', '',
        '| Dependency | Pinned | Latest | Change | Source | Review |',
        '| --- | --- | --- | --- | --- | --- |',
        *rows,
    ]) if rows else '# Dependency audit\n\nAll audited pins match or exceed the latest stable releases.'
    print(report)
    if summary := os.environ.get('GITHUB_STEP_SUMMARY'):
        with open(summary, 'a') as output:
            output.write(report + '\n')
    return needs_review


if __name__ == '__main__':
    sys.exit(1 if audit() else 0)
