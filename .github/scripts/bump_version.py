#!/usr/bin/env python3
import sys
import re
import os
from typing import Tuple

def parse_semver(version: str) -> Tuple[int, int, int]:
    """Parse a semver string into (major, minor, patch) tuple."""
    match = re.match(r'^(\d+)\.(\d+)\.(\d+)', version)
    if not match:
        raise ValueError(f"Invalid version format: {version}")
    return tuple(map(int, match.groups()))

def bump_version(current_version: str, bump_type: str) -> str:
    """Bump the version according to semver rules."""
    major, minor, patch = parse_semver(current_version)
    
    if bump_type == 'major':
        return f"{major + 1}.0.0"
    elif bump_type == 'minor':
        return f"{major}.{minor + 1}.0"
    elif bump_type == 'patch':
        return f"{major}.{minor}.{patch + 1}"
    else:
        raise ValueError(f"Invalid bump type: {bump_type}")

def get_commit_messages(since_tag: str) -> list[str]:
    """Get all commit messages since the last tag."""
    import subprocess
    result = subprocess.run(['git', 'log', f'{since_tag}..HEAD', '--pretty=format:%s'],
                          capture_output=True, text=True)
    return result.stdout.split('\n')

def determine_bump_type(messages: list[str]) -> str:
    """Determine version bump type based on commit messages."""
    has_breaking = any('BREAKING CHANGE' in msg or 'breaking:' in msg.lower() for msg in messages)
    has_feat = any(msg.startswith('feat:') for msg in messages)
    has_fix = any(msg.startswith('fix:') for msg in messages)
    
    if has_breaking:
        return 'major'
    elif has_feat:
        return 'minor'
    elif has_fix:
        return 'patch'
    else:
        return 'patch'  # Default to patch if no conventional commits found

def main():
    if len(sys.argv) != 2:
        print("Usage: bump_version.py <current_version>")
        sys.exit(1)
    
    current_version = sys.argv[1]
    
    try:
        # Get commit messages since last tag
        messages = get_commit_messages(f"v{current_version}")
        
        # Determine bump type from commit messages
        bump_type = determine_bump_type(messages)
        
        # Calculate new version
        new_version = bump_version(current_version, bump_type)
        
        # Output the new version
        print(new_version)
        
    except Exception as e:
        print(f"Error: {str(e)}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
