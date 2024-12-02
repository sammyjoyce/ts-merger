#!/usr/bin/env python3
import os
import sys

def build_script(template_path, output_path, replacements):
    """Build a script from a template by replacing placeholders."""
    with open(template_path, 'r') as f:
        content = f.read()
    
    for key, value in replacements.items():
        content = content.replace(f"{{{{{key}}}}}", value)
    
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, 'w') as f:
        f.write(content)
    
    # Make shell scripts executable
    if output_path.endswith('.sh'):
        os.chmod(output_path, 0o755)

def main():
    # Get repository information from environment variables
    github_repository = os.environ.get('GITHUB_REPOSITORY')
    if not github_repository:
        print("Error: GITHUB_REPOSITORY environment variable not set")
        sys.exit(1)
    
    owner, repo = github_repository.split('/')
    
    replacements = {
        'GITHUB_OWNER': owner,
        'GITHUB_REPO': repo,
        'GITHUB_REPOSITORY': github_repository
    }
    
    # Get the root directory of the repository
    root_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    
    # Build each script
    scripts = [
        ('install.sh', 'install.sh'),
        ('install.ps1', 'install.ps1'),
        ('install-nightly.sh', 'install-nightly.sh'),
        ('install-nightly.ps1', 'install-nightly.ps1'),
    ]
    
    for template_name, output_name in scripts:
        template_path = os.path.join(root_dir, 'scripts', 'templates', template_name + '.template')
        output_path = os.path.join(root_dir, 'scripts', output_name)
        
        print(f"Building {output_name}...")
        build_script(template_path, output_path, replacements)
        print(f"Successfully built {output_name}")

    # Clean up any old files that aren't generated from templates
    scripts_dir = os.path.join(root_dir, 'scripts')
    for file in os.listdir(scripts_dir):
        file_path = os.path.join(scripts_dir, file)
        if os.path.isfile(file_path) and not file.endswith('.template'):
            if file not in [s[1] for s in scripts]:
                print(f"Removing unused file: {file}")
                os.remove(file_path)

if __name__ == '__main__':
    main()
