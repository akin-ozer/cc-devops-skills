#!/usr/bin/env python3
"""
Extract Ansible module and collection information from playbooks and roles.
Outputs JSON with detected modules, collections, and version constraints.
"""

import sys
import json
import os
import re
from pathlib import Path
from typing import Dict, List, Set, Any

try:
    import yaml
except ImportError:
    print(json.dumps({
        "error": "PyYAML not installed",
        "message": "Please install PyYAML: pip install pyyaml"
    }), file=sys.stderr)
    sys.exit(1)


class AnsibleInfoExtractor:
    """Extract module and collection information from Ansible files"""

    # Common Ansible builtin modules (ansible.builtin collection)
    BUILTIN_MODULES = {
        'debug', 'set_fact', 'assert', 'fail', 'include', 'include_tasks',
        'include_vars', 'import_tasks', 'import_playbook', 'add_host',
        'group_by', 'pause', 'wait_for', 'meta', 'command', 'shell',
        'script', 'raw', 'copy', 'file', 'template', 'lineinfile',
        'blockinfile', 'replace', 'fetch', 'stat', 'get_url', 'uri',
        'apt', 'yum', 'dnf', 'package', 'service', 'systemd', 'user',
        'group', 'authorized_key', 'cron', 'git', 'pip', 'setup',
        'gather_facts', 'ping', 'reboot', 'include_role', 'import_role'
    }

    def __init__(self, path: str):
        self.path = Path(path)
        self.modules: Set[str] = set()
        self.collections: Set[str] = set()
        self.collection_versions: Dict[str, str] = {}
        self.errors: List[str] = []

    def extract(self) -> Dict[str, Any]:
        """Extract information from Ansible files"""
        if self.path.is_file():
            self._process_file(self.path)
        elif self.path.is_dir():
            self._process_directory(self.path)
        else:
            self.errors.append(f"Path not found: {self.path}")

        return self._build_result()

    def _process_directory(self, directory: Path):
        """Process all YAML files in directory"""
        # Check for requirements.yml first
        req_file = directory / 'requirements.yml'
        if req_file.exists():
            self._process_requirements(req_file)

        # Also check collections/requirements.yml (common location)
        coll_req = directory / 'collections' / 'requirements.yml'
        if coll_req.exists():
            self._process_requirements(coll_req)

        # Check for roles directory (Ansible role structure)
        roles_dir = directory / 'roles'
        if roles_dir.exists():
            for role_dir in roles_dir.iterdir():
                if role_dir.is_dir():
                    self._process_role(role_dir)

        # Process all YAML files
        for ext in ['*.yml', '*.yaml']:
            for yaml_file in directory.rglob(ext):
                # Skip certain directories
                if any(skip in yaml_file.parts for skip in ['.git', 'venv', 'node_modules']):
                    continue
                self._process_file(yaml_file)

    def _process_role(self, role_dir: Path):
        """Process an Ansible role directory"""
        # Check for meta/main.yml for dependencies
        meta_file = role_dir / 'meta' / 'main.yml'
        if meta_file.exists():
            self._process_file(meta_file)

        # Process tasks
        tasks_dir = role_dir / 'tasks'
        if tasks_dir.exists():
            for task_file in tasks_dir.glob('*.yml'):
                self._process_file(task_file)

        # Process handlers
        handlers_dir = role_dir / 'handlers'
        if handlers_dir.exists():
            for handler_file in handlers_dir.glob('*.yml'):
                self._process_file(handler_file)

    def _process_file(self, file_path: Path):
        """Process a single YAML file"""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = yaml.safe_load(f)

            if not content:
                return

            # Check if it's a playbook
            if isinstance(content, list):
                for play in content:
                    if isinstance(play, dict):
                        self._extract_from_play(play)

            # Check if it's a task file
            elif isinstance(content, dict):
                self._extract_from_tasks(content)

        except yaml.YAMLError as e:
            self.errors.append(f"YAML error in {file_path}: {str(e)}")
        except Exception as e:
            self.errors.append(f"Error processing {file_path}: {str(e)}")

    def _process_requirements(self, req_file: Path):
        """Process requirements.yml for collection versions"""
        try:
            with open(req_file, 'r', encoding='utf-8') as f:
                content = yaml.safe_load(f)

            if not content:
                return

            # Parse collections from requirements
            if isinstance(content, dict) and 'collections' in content:
                for collection in content['collections']:
                    if isinstance(collection, dict):
                        name = collection.get('name', '')
                        version = collection.get('version', 'latest')
                        if name:
                            self.collections.add(name)
                            self.collection_versions[name] = version
                    elif isinstance(collection, str):
                        self.collections.add(collection)
                        self.collection_versions[collection] = 'latest'

        except Exception as e:
            self.errors.append(f"Error processing requirements {req_file}: {str(e)}")

    def _extract_from_play(self, play: Dict):
        """Extract modules from a play"""
        # Process pre_tasks
        if 'pre_tasks' in play:
            self._extract_from_task_list(play['pre_tasks'])

        # Process tasks
        if 'tasks' in play:
            self._extract_from_task_list(play['tasks'])

        # Process post_tasks
        if 'post_tasks' in play:
            self._extract_from_task_list(play['post_tasks'])

        # Process handlers
        if 'handlers' in play:
            self._extract_from_task_list(play['handlers'])

        # Process roles
        if 'roles' in play:
            self._extract_from_roles(play['roles'])

    def _extract_from_tasks(self, content: Dict):
        """Extract from task file content"""
        # If it's a list of tasks
        if isinstance(content, list):
            self._extract_from_task_list(content)
        # If it has a tasks key
        elif 'tasks' in content:
            self._extract_from_task_list(content['tasks'])

    def _extract_from_task_list(self, tasks: List):
        """Extract modules from a list of tasks"""
        if not isinstance(tasks, list):
            return

        for task in tasks:
            if not isinstance(task, dict):
                continue

            # Extract module name from task
            for key in task.keys():
                # Skip Ansible keywords
                if key in ['name', 'when', 'with_items', 'loop', 'register',
                          'become', 'become_user', 'notify', 'tags', 'vars',
                          'changed_when', 'failed_when', 'ignore_errors',
                          'block', 'rescue', 'always', 'delegate_to']:
                    continue

                # Check for blocks
                if key == 'block' and isinstance(task['block'], list):
                    self._extract_from_task_list(task['block'])
                if key == 'rescue' and isinstance(task['rescue'], list):
                    self._extract_from_task_list(task['rescue'])
                if key == 'always' and isinstance(task['always'], list):
                    self._extract_from_task_list(task['always'])

                # Extract module name
                if '.' in key:
                    # It's a FQCN (Fully Qualified Collection Name)
                    parts = key.split('.')
                    if len(parts) >= 3:
                        collection = f"{parts[0]}.{parts[1]}"
                        module = parts[2]
                        self.collections.add(collection)
                        self.modules.add(key)
                    elif len(parts) == 2:
                        # Could be collection.module
                        self.modules.add(key)
                else:
                    # It's a short module name
                    if key not in self.BUILTIN_MODULES and not key.startswith('_'):
                        self.modules.add(key)

    def _extract_from_roles(self, roles):
        """Extract information from roles"""
        if not isinstance(roles, list):
            return

        for role in roles:
            if isinstance(role, dict):
                # Role with parameters
                role_name = role.get('role', role.get('name', ''))
                if '.' in role_name:
                    # It's a collection role
                    parts = role_name.split('.')
                    if len(parts) >= 2:
                        collection = f"{parts[0]}.{parts[1]}"
                        self.collections.add(collection)

    def _build_result(self) -> Dict[str, Any]:
        """Build the result dictionary"""
        return {
            "modules": sorted(list(self.modules)),
            "collections": sorted(list(self.collections)),
            "collection_versions": self.collection_versions,
            "builtin_modules": sorted([m for m in self.modules if m in self.BUILTIN_MODULES]),
            "custom_modules": sorted([m for m in self.modules if m not in self.BUILTIN_MODULES]),
            "errors": self.errors
        }


def main():
    if len(sys.argv) < 2:
        print(json.dumps({
            "error": "No path provided",
            "usage": "python extract_ansible_info.py <path-to-playbook-or-role>"
        }))
        sys.exit(1)

    path = sys.argv[1]
    extractor = AnsibleInfoExtractor(path)
    result = extractor.extract()

    print(json.dumps(result, indent=2))

    # Exit with error code if there were errors
    if result['errors']:
        sys.exit(1)


if __name__ == '__main__':
    main()
