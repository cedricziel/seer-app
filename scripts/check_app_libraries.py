#!/usr/bin/env python3
"""Reject app bundles whose required runtime libraries cannot be resolved."""

import argparse
import plistlib
import subprocess
from pathlib import Path


def load_commands(binary):
    output = subprocess.check_output(['otool', '-l', str(binary)], text=True)
    libraries, runpaths = set(), set()
    command = None
    for line in output.splitlines():
        fields = line.strip().split()
        if fields[:1] == ['cmd']:
            command = fields[1]
        elif fields[:1] == ['path'] and command == 'LC_RPATH':
            runpaths.add(line.strip()[5:].rsplit(' (offset ', 1)[0])
        elif fields[:1] == ['name'] and command in {
            'LC_LOAD_DYLIB', 'LC_REEXPORT_DYLIB', 'LC_LOAD_UPWARD_DYLIB'
        }:
            libraries.add(line.strip()[5:].rsplit(' (offset ', 1)[0])
    return libraries, runpaths


def unresolved_libraries(app):
    contents = app / 'Contents' if (app / 'Contents').is_dir() else app
    with (contents / 'Info.plist').open('rb') as stream:
        executable = plistlib.load(stream)['CFBundleExecutable']
    main = contents / 'MacOS' / executable if contents != app else app / executable
    _, main_runpaths = load_commands(main)
    binaries = {main}
    for framework in (contents / 'Frameworks').glob('*.framework'):
        binaries.add(framework / framework.stem)
    binaries.update((contents / 'Frameworks').glob('*.dylib'))
    errors = []
    for binary in sorted(binaries):
        libraries, runpaths = load_commands(binary)

        def expand(path):
            return Path(path.replace('@executable_path', str(main.parent))
                        .replace('@loader_path', str(binary.parent)))

        search_paths = {expand(path) for path in runpaths}
        search_paths.update(Path(path.replace('@executable_path', str(main.parent))
                                 .replace('@loader_path', str(main.parent)))
                            for path in main_runpaths)
        for library in sorted(libraries):
            if library.startswith(('/System/Library/', '/usr/lib/')):
                continue
            if library.startswith('@rpath/'):
                candidates = [path / library[7:] for path in search_paths]
            else:
                candidates = [expand(library)]
            if not any(path.is_file() for path in candidates):
                errors.append(f'{binary.relative_to(app)}: cannot resolve {library}')
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('bundle', type=Path, help='Path to an .app or .xcarchive')
    args = parser.parse_args()
    apps = sorted((args.bundle / 'Products/Applications').glob('*.app')) \
        if args.bundle.suffix == '.xcarchive' else [args.bundle]
    if not apps:
        parser.error('archive contains no application')
    errors = [error for app in apps for error in unresolved_libraries(app)]
    if errors:
        parser.exit(1, '\n'.join(errors) + '\n')
    print('All required app libraries resolve within the bundle or system paths.')


if __name__ == '__main__':
    main()
