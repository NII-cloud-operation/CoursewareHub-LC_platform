"""Resolve the deploy branch once for both CoursewareHub scenarios."""
import json
import os
import re
import subprocess
from pathlib import Path


def parameters(body):
    result = {}
    for field, default in [('DEPLOY_REPOSITORY', 'NII-cloud-operation/CoursewareHub-LC_deploy'),
                           ('DEPLOY_BRANCH', 'main')]:
        values = re.findall(r'^-[ \t]*' + field + r':[ \t]*([^\n]*)$', body, re.MULTILINE)
        if len(values) > 1:
            raise ValueError(f'Duplicate {field} in PR description')
        result[field] = (values[0].strip() if values else '') or default
    return result


event = json.loads(Path(os.environ['GITHUB_EVENT_PATH']).read_text())
if 'pull_request' in event:
    config = parameters(event['pull_request']['body'] or '')
    if event['action'] == 'edited':
        previous = event['changes'].get('body')
        if previous is None or parameters(previous['from'] or '') == config:
            print('Deploy selection is unchanged.')
            raise SystemExit(0)
else:
    config = parameters('')
    for name in config:
        if os.environ.get(name):
            config[name] = os.environ[name]

repo = config['DEPLOY_REPOSITORY']
branch = config['DEPLOY_BRANCH']
if not re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', repo):
    raise ValueError(f'Expected owner/repository, got {repo!r}')
ref = f'refs/heads/{branch}'
subprocess.run(['git', 'check-ref-format', ref], check=True)
refs = subprocess.check_output(['git', 'ls-remote', '--exit-code', '--heads',
                                f'https://github.com/{repo}.git', ref], text=True)
sha, resolved = refs.rstrip('\n').split('\t')
if resolved != ref or not re.fullmatch('[0-9a-f]{40}', sha):
    raise ValueError(f'Could not resolve {repo}@{ref}')
print(f'Deploy notebooks: {repo}@{branch} ({sha})')
with open(os.environ['GITHUB_OUTPUT'], 'a') as out:
    print(f'repository={repo}\nsha={sha}', file=out)
