#!/usr/bin/env python3
import sys
import re
import os

def is_valid_semver(version):
    # Basic semver regex pattern
    # Matches: MAJOR.MINOR.PATCH(-PRERELEASE)?(+BUILD)?
    pattern = r'^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$'
    return bool(re.match(pattern, version))

def update_version(file_path, new_version):
    if not os.path.isfile(file_path):
        print(f"Error: {file_path} does not exist.")
        sys.exit(1)
    
    # Validate semver format
    if not is_valid_semver(new_version):
        print(f"Error: Version '{new_version}' does not follow semantic versioning (MAJOR.MINOR.PATCH[-PRERELEASE][+BUILD])")
        sys.exit(1)
    
    with open(file_path, 'r') as file:
        content = file.read()

    # Regex to find version = "X.Y.Z" and replace
    new_content, count = re.subn(r'^version\s*=\s*".*"', f'version = "{new_version}"', content, flags=re.MULTILINE)

    if count == 0:
        print("No version line found to update.")
        sys.exit(1)

    with open(file_path, 'w') as file:
        file.write(new_content)

    print(f"Updated {file_path} to version {new_version}")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: update_version.py <file_path> <new_version>")
        sys.exit(1)
    update_version(sys.argv[1], sys.argv[2])