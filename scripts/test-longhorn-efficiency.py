#!/usr/bin/env python3
"""Test the actual GitOps Longhorn rules; fixtures contain synthetic metrics only.
Requires PyYAML and promtool. Does not contact or mutate Kubernetes.
"""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import yaml

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--promtool', default='promtool')
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
values = yaml.safe_load((root / 'apps/kube-prometheus-stack/custom-values.yaml').read_text())
groups = [g for g in values['additionalPrometheusRulesMap']['cluster-alerts']['groups']
          if g['name'] == 'longhorn-alerts']
assert len(groups) == 1, 'Expected one canonical Longhorn rule group'
expected = {'LonghornPrometheusMaintenanceStale', 'LonghornPrometheusStorageAmplification'}
assert expected <= {r.get('alert') for r in groups[0]['rules']}, 'Missing efficiency guardrail'
# Extract from the real values on every run, never test a stale copied rule.
with tempfile.TemporaryDirectory(prefix='longhorn-rule-tests-', dir=os.environ.get('TMPDIR', str(root))) as tmp:
    dest = Path(tmp)
    rules = dest / 'longhorn-efficiency.rules.yaml'
    rules.write_text(yaml.safe_dump({'groups': groups}))
    fixtures = []
    for name in ['longhorn-efficiency.test.yaml', 'longhorn-amplification.test.yaml']:
        shutil.copyfile(root / 'scripts/tests' / name, dest / name)
        fixtures.append(str(dest / name))
    subprocess.run([args.promtool, 'check', 'rules', str(rules)], check=True)
    subprocess.run([args.promtool, 'test', 'rules', *fixtures], check=True)
