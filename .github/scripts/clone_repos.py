#!/usr/bin/env python3

import os
import subprocess
from pathlib import Path

# ANSI color codes
GREEN = '\033[0;32m'
BLUE = '\033[0;34m'
NC = '\033[0m'  # No Color

def print_status(msg, color=BLUE):
    """Print a colored status message."""
    print(f"{color}{msg}{NC}")

def run_command(cmd, cwd=None):
    """Run a command and return its output."""
    try:
        result = subprocess.run(
            cmd,
            cwd=cwd,
            check=True,
            capture_output=True,
            text=True
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        print(f"Error running command {' '.join(cmd)}: {e}")
        print(f"Error output: {e.stderr}")
        raise

def clone_repo(repo_url, target_dir, version):
    """Clone a repository to the target directory."""
    target_path = Path(target_dir)
    
    if target_path.exists():
        print_status(f"{target_path.name} already exists", GREEN)
        return
    
    print_status(f"Cloning {repo_url} into {target_dir}")
    cmd = ["git", "clone", "--depth", "1", "-b", version, repo_url, str(target_path)]
    run_command(cmd)
    print_status(f"Successfully cloned {target_path.name}", GREEN)

def main():
    print_status("Setting up development environment...")
    
    # Get the root directory of the project
    root_dir = Path(__file__).resolve().parent.parent.parent
    deps_dir = root_dir / "deps"
    
    # Create deps directory if it doesn't exist
    print_status("Creating deps directory...")
    deps_dir.mkdir(parents=True, exist_ok=True)
    
    # Repository information with specific versions
    repos = [
        {
            "url": "https://github.com/tree-sitter/tree-sitter.git",
            "dir": "tree-sitter",
            "version": "v0.20.8"
        },
        {
            "url": "https://github.com/tree-sitter/tree-sitter-typescript.git",
            "dir": "tree-sitter-typescript",
            "version": "v0.20.1"
        }
    ]
    
    # Clone each repository
    for repo in repos:
        target_dir = deps_dir / repo["dir"]
        clone_repo(repo["url"], target_dir, repo["version"])
    
    # Verify the dependencies were installed correctly
    print_status("Verifying dependencies...")
    all_deps_exist = all((deps_dir / repo["dir"]).exists() for repo in repos)
    
    if all_deps_exist:
        print_status("All dependencies are installed successfully!", GREEN)
        print_status("Setup complete! You can now build the project.", GREEN)
    else:
        print("Error: Some dependencies are missing. Please check the error messages above.")
        exit(1)

if __name__ == "__main__":
    main()
