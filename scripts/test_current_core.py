"""R4 current-Core deployment authorization, artifact safety and destination controls.

Fixtures are realistic rather than mocked verdicts: the deployed Core source is
a real Git commit of the exact indexed specifications, artifacts are real
upload-artifact ZIP and upload-pages-artifact ZIP/TAR archives, digests are real
SHA-256 values, and native pages use the GNATdoc 26.0.0 section structure. Only
the transport (API responses, artifact bytes, public HTTPS bytes) is supplied by
the fixture; every verdict comes from the production qualifier.
"""
import copy
import hashlib
import html
import io
import json
from pathlib import Path
import shutil
import stat
import subprocess
import tarfile
import tempfile
import types
import unittest
import zipfile
from unittest.mock import patch

import qualify_current_core as core
from core_source_authority import ROOT, authority, check_solution
from highlight_gnatdoc_ada import highlight_text
from link_gnatdoc_types import CORE_ROOT
from qualify_production_core_links import source_native_types

APPROVED = authority()
TYPES = APPROVED['types']
OWNER_TITLES = {'opencv': 'OpenCV', 'opencv.core': 'OpenCV.Core'}
INDEXED_AVAILABLE = (CORE_ROOT / '.git').exists() or (CORE_ROOT / 'src/opencv.ads').is_file()


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def section(anchor, name, snippet):
    # Published Core pages carry lexical highlighting spans inside snippets.
    escaped = html.escape(snippet, quote=False)
    return (f'<h4 id={anchor}>{name}</h4><pre class=ada-code-snippet><code>'
            f'{highlight_text(escaped)}</code></pre><p>Documentation for {html.escape(name)}.</p>')


def native_page(owner, overrides=None):
    """A GNATdoc-shaped owner page with every approved section (and a decoy)."""
    overrides = overrides or {}
    body = ''.join(section(*overrides.get(p['identity'].lower(), (p['native_anchor'],
                   p['identity'].rpartition('.')[2], p['native_snippet'])))
                   for p in TYPES.values() if p['owner'] == owner)
    decoy = section('0' * 64, 'Unrelated_Decoy', 'type Unrelated_Decoy is new Integer;\n')
    return (f'<html class=main lang="en">\n<head><meta charset="utf-8"><title>{OWNER_TITLES[owner]}</title>'
            f'<link rel=stylesheet href=gnatdoc.css></head><h1>{OWNER_TITLES[owner]}</h1>'
            + body + decoy).encode()


def review_zip(files, extra=()):
    data = io.BytesIO()
    with zipfile.ZipFile(data, 'w', zipfile.ZIP_DEFLATED) as archive:
        for name, content in sorted(files.items()):
            archive.writestr(name, content)
        for info, content in extra:
            archive.writestr(info, content)
    return data.getvalue()


def pages_zip(files, extra=()):
    tar = io.BytesIO()
    with tarfile.open(fileobj=tar, mode='w') as archive:
        root = tarfile.TarInfo('.')
        root.type = tarfile.DIRTYPE
        archive.addfile(root)
        for directory in sorted({n.rpartition('/')[0] for n in files if '/' in n}):
            info = tarfile.TarInfo('./' + directory)
            info.type = tarfile.DIRTYPE
            archive.addfile(info)
        for name, content in sorted(files.items()):
            info = tarfile.TarInfo('./' + name)
            info.size = len(content)
            archive.addfile(info, io.BytesIO(content))
        for info, content in extra:
            archive.addfile(info, io.BytesIO(content) if content is not None else None)
    data = io.BytesIO()
    with zipfile.ZipFile(data, 'w') as archive:
        archive.writestr('artifact.tar', tar.getvalue())
    return data.getvalue()


class FixtureCore:
    """Transport double: real Git repository, real archives, API-shaped JSON."""

    REPOSITORY_ID = 1328215387

    def __init__(self, tmp, deployment=9_000_000_001, run=50_000_000_001):
        self.repo = tmp / 'core-main'
        self.repo.mkdir()
        self._git('init', '--quiet', '-b', 'main')
        self._git('config', 'user.email', 'fixture@example.invalid')
        self._git('config', 'user.name', 'fixture')
        (self.repo / 'src').mkdir()
        for name in ('opencv.ads', 'opencv-core.ads'):
            shutil.copyfile(CORE_ROOT / 'src' / name, self.repo / 'src' / name)
        # Unrelated deployed-tree differences are allowed (newer Core docs/tools).
        (self.repo / 'alire.toml').write_text('name = "opencv_core"\nversion = "0.5.2"\n')
        (self.repo / 'README.md').write_text('Unrelated newer Core documentation tooling\n')
        self.sha = self.commit('fixture Core main')
        self.deployment, self.run, self.calls = deployment, run, 0
        self.status_state, self.extra_newer = 'success', []
        self.site = {
            'index.html': b'<html>Core landing</html>',
            'api/index.html': b'<html>Core API index</html>',
            'api/gnatdoc-search-index.json': b'{"records": []}',
            'assets/gnatdoc-examples.css': b'pre { margin: 0 }',
            'guides/core-operations-guide.html': b'<html>guide</html>',
        }
        for page, owner in self.referenced_owners().items():
            self.site[page] = native_page(owner)
        self.rebuild()
        self.mutate_api = None

    def _git(self, *args):
        return subprocess.run(['git', '-C', str(self.repo), *args], check=True,
                              capture_output=True).stdout.decode().strip()

    def commit(self, message):
        self._git('add', '-A')
        self._git('commit', '--quiet', '--allow-empty', '-m', message)
        return self._git('rev-parse', 'HEAD')

    @staticmethod
    def referenced_owners():
        return {p['native_page']: p['owner'] for p in TYPES.values()}

    def rebuild(self, review=None, pages=None):
        self.review = review if review is not None else review_zip(self.site)
        self.pages = pages if pages is not None else pages_zip(self.site)
        self.live = dict(self.site)
        self.review_digest, self.pages_digest = sha256(self.review), sha256(self.pages)

    def responses(self):
        sha, run = self.sha, self.run
        workflow_run = {'id': run, 'repository_id': self.REPOSITORY_ID,
                        'head_repository_id': self.REPOSITORY_ID, 'head_branch': 'main', 'head_sha': sha}
        repository = {'id': self.REPOSITORY_ID, 'full_name': core.REPO}
        deployments = [{'id': self.deployment, 'sha': sha, 'ref': 'main', 'task': 'deploy',
                        'environment': 'github-pages', 'created_at': '2026-11-02T04:53:41Z',
                        'repository_url': core.REPOSITORY_API}] + self.extra_newer
        result = {
            'deployments?environment=github-pages&per_page=30': deployments,
            f'deployments/{self.deployment}/statuses': [
                {'id': 2, 'state': self.status_state, 'environment_url': core.BASE_URL,
                 'log_url': f'https://github.com/{core.REPO}/actions/runs/{run}/job/702',
                 'created_at': '2026-11-02T04:53:54Z'},
                {'id': 1, 'state': 'in_progress', 'environment_url': '',
                 'log_url': f'https://github.com/{core.REPO}/actions/runs/{run}/job/702',
                 'created_at': '2026-11-02T04:53:46Z'}],
            f'actions/runs/{run}': {'id': run, 'run_attempt': 1, 'workflow_id': 381418512,
                                    'head_sha': sha, 'head_branch': 'main', 'event': 'push',
                                    'path': core.WORKFLOW_PATH, 'status': 'completed',
                                    'conclusion': 'success', 'repository': dict(repository),
                                    'head_repository': dict(repository)},
            f'actions/runs/{run}/jobs?filter=latest&per_page=100': {'jobs': [
                {'id': 701, 'name': 'build', 'conclusion': 'success', 'run_id': run, 'head_sha': sha},
                {'id': 702, 'name': 'deploy', 'conclusion': 'success', 'run_id': run, 'head_sha': sha},
                {'id': 703, 'name': 'verify-live', 'conclusion': 'success', 'run_id': run, 'head_sha': sha}]},
            f'compare/{sha}...main': {'status': 'identical', 'ahead_by': 0, 'behind_by': 0},
            f'git/commits/{sha}': {'sha': sha, 'tree': {'sha': self._git('rev-parse', sha + '^{tree}')}},
            f'actions/runs/{run}/artifacts?per_page=100': {'artifacts': [
                {'id': 801, 'name': 'ada-api-' + sha, 'expired': False, 'size_in_bytes': len(self.review),
                 'digest': 'sha256:' + self.review_digest, 'expires_at': '2027-01-31T04:17:22Z',
                 'workflow_run': dict(workflow_run)},
                {'id': 802, 'name': 'github-pages', 'expired': False, 'size_in_bytes': len(self.pages),
                 'digest': 'sha256:' + self.pages_digest, 'expires_at': '2026-12-02T04:53:38Z',
                 'workflow_run': dict(workflow_run)},
                {'id': 803, 'name': 'gnatdoc-diagnostics-' + sha, 'expired': False, 'size_in_bytes': 1,
                 'digest': 'sha256:' + '1' * 64, 'workflow_run': dict(workflow_run)}]},
        }
        for newer in self.extra_newer:
            result[f"deployments/{newer['id']}/statuses"] = newer['statuses']
        return result

    def api(self, path):
        self.calls += 1
        data = copy.deepcopy(self.responses())
        if self.mutate_api:
            self.mutate_api(data)
        if path not in data:
            raise ValueError('fixture API path not found: ' + path)
        return data[path]

    def artifact(self, identifier):
        return {801: self.review, 802: self.pages}[identifier]

    def commit_file(self, sha, relative):
        return subprocess.run(['git', '-C', str(self.repo), 'show', sha + ':' + relative],
                              check=True, capture_output=True).stdout

    def commit_tree(self, sha):
        return self._git('rev-parse', sha + '^{tree}')

    def fetch(self, relative):
        return self.live[relative]


class Fixture(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix='imgproc-r4-test-'))
        self.addCleanup(shutil.rmtree, self.tmp)
        self.source = FixtureCore(self.tmp)
        self.count = 0

    def verify(self, approved=APPROVED):
        self.count += 1
        record = core.provenance(self.source)
        return core.verify_publication(self.source, record, approved, self.tmp / f'scratch-{self.count}')

    def rejects(self, pattern, approved=APPROVED):
        with self.assertRaisesRegex(ValueError, pattern):
            self.verify(approved)

    def change_source(self, before, after):
        path = self.source.repo / 'src/opencv-core.ads'
        text = path.read_text()
        self.assertIn(before, text)
        path.write_text(text.replace(before, after, 1))
        self.source.sha = self.source.commit('mutated Core source')


@unittest.skipUnless(INDEXED_AVAILABLE, 'requires the indexed Core 0.5.2 sibling checkout')
class LegitimateDeployment(Fixture):
    def test_accepts_new_deployment_with_unchanged_declarations_and_anchors(self):
        proofs, hosted, inventory = self.verify()
        self.assertEqual(set(proofs), set(TYPES))
        self.assertEqual(set(hosted), core.REFERENCED_PAGES)
        self.assertEqual(len(inventory), len(self.source.site))
        for identity, proof in proofs.items():
            self.assertEqual(proof['url'], core.BASE_URL + TYPES[identity]['native_page'] + '#' +
                             TYPES[identity]['native_anchor'])
            self.assertEqual(proof['hosted_revision'], self.source.sha)
        record = core.provenance(self.source)
        self.assertEqual(record['deployment']['id'], 9_000_000_001)
        self.assertNotIn(str(core.HISTORICAL_R3['deployment']), json.dumps(record))

    def test_unrelated_core_documentation_changes_are_accepted(self):
        self.verify()
        self.source.site['api/index.html'] = b'<html>rewritten Core navigation</html>'
        self.source.site['api/new-page.html'] = b'<html>new unrelated package</html>'
        del self.source.site['guides/core-operations-guide.html']
        self.source.deployment, self.source.run = 9_000_000_002, 50_000_000_002
        self.source.rebuild()
        self.verify()

    def test_newer_failed_deployment_is_skipped_but_unsettled_one_is_not(self):
        failed = {'id': 9_000_000_100, 'sha': '1' * 40, 'ref': 'main', 'task': 'deploy',
                  'environment': 'github-pages', 'repository_url': core.REPOSITORY_API,
                  'statuses': [{'id': 9, 'state': 'failure'}]}
        self.source.extra_newer = [failed]
        self.assertEqual(core.provenance(self.source)['deployment']['id'], 9_000_000_001)
        failed['statuses'] = [{'id': 9, 'state': 'in_progress'}]
        with self.assertRaisesRegex(ValueError, 'CORE_DEPLOYMENT_UNSETTLED'):
            core.provenance(self.source)


@unittest.skipUnless(INDEXED_AVAILABLE, 'requires the indexed Core 0.5.2 sibling checkout')
class DeployedSourceMutations(Fixture):
    def test_changed_profile_rejected(self):
        self.change_source('type Mat_Array is array (Natural range <>) of Mat;',
                           'type Mat_Array is array (Positive range <>) of Mat;')
        self.rejects('CORE_SOURCE_CHANGED')

    def test_private_declaration_rejected(self):
        path = self.source.repo / 'src/opencv-core.ads'
        text = path.read_text()
        line = '   type Mat_Array is array (Natural range <>) of Mat;\n'
        self.assertIn(line, text)
        text = text.replace(line, '', 1)
        lines = text.splitlines(keepends=True)
        private = next(i for i, l in enumerate(lines) if l.strip().lower() == 'private')
        lines.insert(private + 1, line)
        path.write_text(''.join(lines))
        self.source.sha = self.source.commit('moved to private part')
        self.rejects('CORE_SOURCE_CHANGED: missing, private or ambiguous')

    def test_ambiguous_declaration_rejected(self):
        self.change_source('   type Mat is tagged private;',
                           '   type Mat is tagged private;\n   type Mat is tagged private;')
        self.rejects('CORE_SOURCE_CHANGED')

    def test_wrong_owner_mapping_rejected(self):
        approved = copy.deepcopy(APPROVED)
        approved['types']['opencv.core.mat']['owner'] = 'opencv'
        self.rejects('CORE_SOURCE_CHANGED', approved)


@unittest.skipUnless(INDEXED_AVAILABLE, 'requires the indexed Core 0.5.2 sibling checkout')
class NativeDestinationMutations(Fixture):
    PAGE = TYPES['opencv.point']['native_page']

    def mutate_page(self, transform):
        self.source.site[self.PAGE] = transform(self.source.site[self.PAGE].decode()).encode()
        self.source.rebuild()

    def test_incorrect_but_existing_anchor_rejected(self):
        approved = copy.deepcopy(APPROVED)
        approved['types']['opencv.point']['native_anchor'] = TYPES['opencv.size']['native_anchor']
        self.rejects('CORE_LINK_COMPATIBILITY_BLOCKED', approved)

    def test_swapped_anchors_rejected(self):
        point, size = TYPES['opencv.point']['native_anchor'], TYPES['opencv.size']['native_anchor']
        self.mutate_page(lambda t: t.replace(point, 'SWAP').replace(size, point).replace('SWAP', size))
        self.rejects('CORE_LINK_COMPATIBILITY_BLOCKED')

    def test_missing_declaration_rejected(self):
        anchor = TYPES['opencv.point']['native_anchor']
        self.mutate_page(lambda t: t.replace(f'<h4 id={anchor}>', '<h4 id=removed>', 1))
        self.rejects('CORE_LINK_COMPATIBILITY_BLOCKED: missing or duplicate native anchor')

    def test_duplicate_declaration_rejected(self):
        point = TYPES['opencv.point']
        duplicate = section(point['native_anchor'], 'Point', point['native_snippet'])
        self.mutate_page(lambda t: t + duplicate)
        self.rejects('CORE_LINK_COMPATIBILITY_BLOCKED: missing or duplicate native anchor')

    def test_substituted_declaration_rejected(self):
        point = TYPES['opencv.point']
        self.source.site[self.PAGE] = native_page('opencv', {'opencv.point': (
            point['native_anchor'], 'Point', 'type Point is record\n   X : Integer;\nend record;\n')})
        self.source.rebuild()
        self.rejects('CORE_LINK_COMPATIBILITY_BLOCKED: substituted')

    def test_anchor_on_non_declaration_rejected(self):
        anchor = TYPES['opencv.point']['native_anchor']
        self.mutate_page(lambda t: t.replace(f'<h4 id={anchor}>', '<h4 id=moved>', 1)
                         .replace('<h1>', f'<p id={anchor}>stray</p><h1>', 1))
        self.rejects('CORE_LINK_COMPATIBILITY_BLOCKED')

    def test_wrong_owner_page_rejected(self):
        self.mutate_page(lambda t: t.replace('<h1>OpenCV</h1>', '<h1>OpenCV.Core</h1>', 1))
        self.rejects('CORE_LINK_COMPATIBILITY_BLOCKED: wrong or ambiguous native owner')

    def test_referenced_page_missing_from_publication_rejected(self):
        del self.source.site[self.PAGE]
        self.source.rebuild()
        self.rejects('referenced native page missing')


@unittest.skipUnless(INDEXED_AVAILABLE, 'requires the indexed Core 0.5.2 sibling checkout')
class ProvenanceMutations(Fixture):
    def mutated(self, transform, pattern):
        self.source.mutate_api = transform
        with self.assertRaisesRegex(ValueError, pattern):
            core.provenance(self.source)
        self.source.mutate_api = None

    def key(self, suffix):
        return next(k for k in self.source.responses() if k.endswith(suffix) or k == suffix)

    def test_artifact_ownership_source_and_workflow_identity(self):
        run, sha = self.source.run, self.source.sha
        artifacts = f'actions/runs/{run}/artifacts?per_page=100'
        jobs = f'actions/runs/{run}/jobs?filter=latest&per_page=100'
        for name, transform, pattern in (
            ('artifact from other run', lambda d: d[artifacts]['artifacts'][0]['workflow_run'].update(id=1),
             'CORE_ARTIFACT_PROVENANCE'),
            ('artifact for other source', lambda d: d[artifacts]['artifacts'][1]['workflow_run'].update(
                head_sha='2' * 40), 'CORE_ARTIFACT_PROVENANCE'),
            ('artifact from fork', lambda d: d[artifacts]['artifacts'][0]['workflow_run'].update(
                head_repository_id=7), 'CORE_ARTIFACT_PROVENANCE'),
            ('expired artifact', lambda d: d[artifacts]['artifacts'][1].update(expired=True),
             'CORE_ARTIFACT_PROVENANCE'),
            ('missing Pages artifact', lambda d: d[artifacts]['artifacts'].pop(1), 'missing or duplicate'),
            ('duplicate review artifact', lambda d: d[artifacts]['artifacts'].append(
                dict(d[artifacts]['artifacts'][0], id=999)), 'missing or duplicate'),
            ('run for other source', lambda d: d[f'actions/runs/{run}'].update(head_sha='3' * 40),
             'CORE_WORKFLOW_IDENTITY'),
            ('pull-request run', lambda d: d[f'actions/runs/{run}'].update(event='pull_request'),
             'CORE_WORKFLOW_IDENTITY'),
            ('other workflow', lambda d: d[f'actions/runs/{run}'].update(path='.github/workflows/x.yml'),
             'CORE_WORKFLOW_IDENTITY'),
            ('fork head repository', lambda d: d[f'actions/runs/{run}']['head_repository'].update(
                full_name='attacker/opencv_core_ada'), 'CORE_WORKFLOW_IDENTITY'),
            ('failed run', lambda d: d[f'actions/runs/{run}'].update(conclusion='failure'),
             'CORE_WORKFLOW_IDENTITY'),
            ('incomplete run', lambda d: d[f'actions/runs/{run}'].update(status='in_progress'),
             'CORE_WORKFLOW_IDENTITY'),
            ('failed deploy job', lambda d: d[jobs]['jobs'][1].update(conclusion='failure'),
             'CORE_WORKFLOW_IDENTITY'),
            ('missing build job', lambda d: d[jobs]['jobs'].pop(0), 'CORE_WORKFLOW_IDENTITY'),
            ('deployment by other job', lambda d: d[f'deployments/{self.source.deployment}/statuses'][0].update(
                log_url=f'https://github.com/{core.REPO}/actions/runs/{run}/job/701'), 'CORE_WORKFLOW_IDENTITY'),
            ('deployment log in other repository', lambda d: d[
                f'deployments/{self.source.deployment}/statuses'][0].update(
                log_url=f'https://github.com/attacker/opencv_core_ada/actions/runs/{run}/job/702'),
             'CORE_DEPLOYMENT_IDENTITY'),
            ('wrong Pages URL', lambda d: d[f'deployments/{self.source.deployment}/statuses'][0].update(
                environment_url='https://attacker.github.io/opencv_core_ada/'), 'CORE_DEPLOYMENT_IDENTITY'),
            ('deployment in other repository', lambda d: d['deployments?environment=github-pages&per_page=30'][0]
             .update(repository_url='https://api.github.com/repos/attacker/x'), 'CORE_DEPLOYMENT_IDENTITY'),
            ('non-main deployment', lambda d: d['deployments?environment=github-pages&per_page=30'][0]
             .update(ref='feature'), 'CORE_DEPLOYMENT_IDENTITY'),
            ('commit outside main history', lambda d: d[f'compare/{sha}...main'].update(
                status='diverged', behind_by=1), 'CORE_SOURCE_HISTORY'),
        ):
            with self.subTest(name):
                self.mutated(transform, pattern)

    def test_unsuccessful_or_incomplete_deployments_rejected(self):
        for state, pattern in (('in_progress', 'CORE_DEPLOYMENT_UNSETTLED'),
                               ('queued', 'CORE_DEPLOYMENT_UNSETTLED'),
                               ('inactive', 'CORE_DEPLOYMENT_UNSETTLED'),
                               ('failure', 'CORE_DEPLOYMENT_UNAVAILABLE')):
            with self.subTest(state):
                self.source.status_state = state
                with self.assertRaisesRegex(ValueError, pattern):
                    core.provenance(self.source)
        self.source.status_state = 'success'
        self.mutated(lambda d: d.update({f'deployments/{self.source.deployment}/statuses': []}),
                     'CORE_DEPLOYMENT_UNSETTLED')

    def test_fetched_tree_must_match_api_tree(self):
        record = core.provenance(self.source)
        record['tree'] = '4' * 40
        with self.assertRaisesRegex(ValueError, 'fetched tree differs'):
            core.verify_publication(self.source, record, APPROVED, self.tmp / 'scratch')


@unittest.skipUnless(INDEXED_AVAILABLE, 'requires the indexed Core 0.5.2 sibling checkout')
class ArtifactMutations(Fixture):
    def test_wrong_digest_and_tampered_bytes_rejected(self):
        original = self.source.review
        self.source.review_digest = '5' * 64
        self.rejects('CORE_ARTIFACT_DIGEST')
        self.source.rebuild()
        self.source.review = original[:-1] + bytes([original[-1] ^ 1])
        self.rejects('CORE_ARTIFACT_DIGEST')

    def unsafe_review(self, info, content=b'x'):
        self.source.rebuild(review=review_zip(self.source.site, [(info, content)]))
        self.rejects('unsafe|CORE_ARTIFACT_UNSAFE')

    def test_unsafe_review_entries_rejected(self):
        self.unsafe_review(zipfile.ZipInfo('../escape.html'))
        self.unsafe_review(zipfile.ZipInfo('/absolute.html'))
        link = zipfile.ZipInfo('api/link.html')
        link.external_attr = (stat.S_IFLNK | 0o777) << 16
        self.unsafe_review(link, b'/etc/passwd')
        self.unsafe_review(zipfile.ZipInfo('api/directory/'), b'')
        self.unsafe_review(zipfile.ZipInfo('api/payload.exe'))
        self.unsafe_review(zipfile.ZipInfo('index.html'), b'duplicate')

    def test_oversized_member_rejected(self):
        with patch.object(core, 'MEMBER_LIMIT', 16):
            self.rejects('oversized')

    def unsafe_pages(self, info, content=None):
        self.source.rebuild(pages=pages_zip(self.source.site, [(info, content)]))
        self.rejects('unsafe|CORE_ARTIFACT_UNSAFE')

    def test_unsafe_pages_entries_rejected(self):
        link = tarfile.TarInfo('./api/link.html')
        link.type, link.linkname = tarfile.SYMTYPE, '/etc/passwd'
        self.unsafe_pages(link)
        hard = tarfile.TarInfo('./api/hard.html')
        hard.type, hard.linkname = tarfile.LNKTYPE, 'index.html'
        self.unsafe_pages(hard)
        escape = tarfile.TarInfo('./../escape.html')
        escape.size = 1
        self.unsafe_pages(escape, b'x')
        duplicate = tarfile.TarInfo('./index.html')
        duplicate.size = 1
        self.unsafe_pages(duplicate, b'x')
        device = tarfile.TarInfo('./api/device.html')
        device.type = tarfile.CHRTYPE
        self.unsafe_pages(device)
        extra = io.BytesIO()
        with zipfile.ZipFile(extra, 'w') as archive:
            archive.writestr('artifact.tar', b'')
            archive.writestr('other.tar', b'')
        self.source.rebuild(pages=extra.getvalue())
        self.rejects('unexpected Pages ZIP inventory')

    def test_review_and_pages_inventories_must_match(self):
        changed = dict(self.source.site, **{'api/index.html': b'<html>diverged</html>'})
        self.source.rebuild(pages=pages_zip(changed))
        self.rejects('CORE_ARTIFACT_INVENTORY')

    def test_stale_public_https_content_rejected(self):
        page = TYPES['opencv.core.mat']['native_page']
        self.source.live[page] = self.source.live[page] + b'<!-- stale CDN copy -->'
        self.rejects('CORE_LIVE_STALE')


@unittest.skipUnless((CORE_ROOT / '.git').exists(), 'requires the indexed Core 0.5.2 sibling checkout')
class EndToEndQualification(Fixture):
    """Complete qualify(): indexed authority + authenticated current deployment."""

    def setUp(self):
        super().setUp()
        # Part A's native side is authentic GNATdoc 26.0.0 output of the indexed
        # source in production (its controls: ReferencedDeclarationMutations and
        # the hosted workflow). Here only that census is replaced by the approved
        # ledger so that parts B/C run end to end against realistic fixtures.
        census = patch.object(core, 'source_native_types',
                              lambda indexed, native, wanted: copy.deepcopy(TYPES))
        census.start()
        self.addCleanup(census.stop)

    def args(self, name, expect=None):
        return types.SimpleNamespace(core=CORE_ROOT, native=self.tmp / 'unused-native',
                                     output=self.tmp / name, expect=expect)

    def test_complete_qualification_and_outputs(self):
        record = core.qualify(self.args('first'), self.source)
        output = self.tmp / 'first'
        policy = json.loads((output / 'policy-proposal.json').read_text())
        self.assertEqual(policy['deployment'], record['deployment']['id'])
        self.assertEqual(policy['verified_referenced_identities'], 14)
        self.assertEqual(sorted(json.loads((output / 'hosted-sha256.json').read_text())),
                         sorted(core.REFERENCED_PAGES))
        self.assertEqual(json.loads((output / 'changed-destinations.json').read_text()), [])
        # Same deployment in a later step of the same build is accepted.
        core.qualify(self.args('second', output / 'provenance-after.json'), self.source)

    def test_deployment_change_during_qualification_is_a_race(self):
        original = core.verify_publication

        def redeploy_midway(*args, **kwargs):
            result = original(*args, **kwargs)
            self.source.deployment, self.source.run = 9_000_000_009, 50_000_000_009
            return result

        with patch.object(core, 'verify_publication', redeploy_midway):
            with self.assertRaisesRegex(ValueError, 'CORE_DEPLOYMENT_RACE'):
                core.qualify(self.args('race'), self.source)

    def test_unsettled_redeploy_during_qualification_is_a_race(self):
        original = core.verify_publication

        def start_deploy(*args, **kwargs):
            result = original(*args, **kwargs)
            self.source.extra_newer = [{'id': 9_000_000_200, 'sha': '6' * 40, 'ref': 'main',
                                        'task': 'deploy', 'environment': 'github-pages',
                                        'repository_url': core.REPOSITORY_API,
                                        'statuses': [{'id': 1, 'state': 'queued'}]}]
            return result

        with patch.object(core, 'verify_publication', start_deploy):
            with self.assertRaisesRegex(ValueError, 'CORE_DEPLOYMENT_RACE'):
                core.qualify(self.args('race-unsettled'), self.source)

    def test_forged_expected_provenance_cannot_authorize(self):
        core.qualify(self.args('first'), self.source)
        forged = json.loads((self.tmp / 'first/provenance-after.json').read_text())
        forged['deployment']['id'] = core.HISTORICAL_R3['deployment']
        path = self.tmp / 'forged.json'
        path.write_text(json.dumps(forged))
        with self.assertRaisesRegex(ValueError, 'CORE_DEPLOYMENT_RACE'):
            core.qualify(self.args('forged-run', path), self.source)

    def test_changed_indexed_dependency_rejected(self):
        with patch.object(core, 'CORE', '7' * 40):
            with self.assertRaisesRegex(ValueError, 'SOURCE_AUTHORITY_CHANGED'):
                core.qualify(self.args('wrong-index'), self.source)


class IndexedAuthorityAndManifestForgery(unittest.TestCase):
    def test_changed_indexed_release_selection_rejected(self):
        manifest = {'depends-on': [{'opencv_core': '~0.5.0'}]}
        lock = {'solution': {'state': [{'crate': 'opencv_core', 'fulfilment': 'solved', 'pinned': False,
                                        'versions': '~0.5.0', 'release': {'version': '0.5.3', 'origin': {
                                            'commit': '8' * 40,
                                            'url': 'git+https://github.com/zackboll/opencv_core_ada.git'}}}]}}
        with self.assertRaisesRegex(ValueError, 'SOURCE_AUTHORITY_CHANGED'):
            check_solution(lock, manifest)

    def copy_root(self):
        tmp = Path(tempfile.mkdtemp(prefix='imgproc-r4-root-'))
        self.addCleanup(shutil.rmtree, tmp)
        for relative in ('docs/evidence/gnatdoc009/r1', 'docs/evidence/gnatdoc009/r3'):
            shutil.copytree(ROOT / relative, tmp / relative)
        for relative in ('docs/gnatdoc-enhancer.toml', 'src/opencv-image_processing.ads'):
            (tmp / relative).parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / relative, tmp / relative)
        return tmp

    def rehash(self, path, transform):
        record = json.loads(path.read_text())
        transform(record)
        path.write_text(json.dumps(record, sort_keys=True, indent=2) + '\n')

    def test_rehashed_source_authority_rejected(self):
        root = self.copy_root()
        self.rehash(root / 'docs/evidence/gnatdoc009/r3/source-authority.json',
                    lambda r: r['types']['opencv.core.mat'].update(native_anchor='f' * 64))
        with self.assertRaisesRegex(ValueError, 'forged R3 source authority'):
            authority(root)

    def test_rehashed_destination_manifests_rejected(self):
        from qualify_shared_production import api_semantics
        root = self.copy_root()
        types_path = root / 'docs/evidence/gnatdoc009/r3/referenced-types.json'
        self.rehash(types_path, lambda r: r['opencv.core.mat'].update(
            url='https://zackboll.github.io/opencv_core_ada/api/forged.html#x'))
        with self.assertRaisesRegex(ValueError, 'declaration authority changed'):
            api_semantics(root, root, root)
        shutil.copyfile(ROOT / 'docs/evidence/gnatdoc009/r3/referenced-types.json', types_path)
        self.rehash(root / 'docs/evidence/gnatdoc009/r3/policy-proposal.json',
                    lambda r: r.update(external_type_target='_self'))
        with self.assertRaisesRegex(ValueError, 'historical Core destination policy record changed'):
            api_semantics(root, root, root)

    def test_historical_identities_are_not_acceptance_criteria(self):
        import re
        source = re.sub(r'HISTORICAL_R3 = \{.*?\n\}\n', '', Path(core.__file__).read_text(), count=1, flags=re.S)
        production = source.replace("'historical_r3_identities_not_used_for_acceptance': HISTORICAL_R3", '')
        self.assertNotIn('HISTORICAL_R3', production.replace('HISTORICAL_R3 = ', ''))
        for value in ('7348179998', '40433988181', '12702919800', '12703258126',
                      '33a2a4f3b83606a5c779b8a93abeb6c91fa49a21', '454fb0fa3a128e638a1d7d85f345c7904f296877'):
            self.assertNotIn(value, production)


class ReferencedDeclarationMutations(unittest.TestCase):
    """Indexed-side source/native census controls (retained from R2/R3)."""

    @unittest.skipUnless(INDEXED_AVAILABLE, 'requires the indexed Core 0.5.2 sibling checkout')
    def test_wrong_owner_private_ambiguous_and_modified_complete_declaration(self):
        wanted = TYPES
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'src').mkdir()
            native = root / 'native'
            (native / 'api').mkdir(parents=True)
            for name in ('opencv.ads', 'opencv-core.ads'):
                shutil.copyfile(CORE_ROOT / 'src' / name, root / 'src' / name)
            for owner in ('opencv', 'opencv.core'):
                members = [p for p in wanted.values() if p['owner'] == owner]
                page = native / members[0]['native_page']
                page.write_text('<h1>' + members[0]['identity'].rpartition('.')[0] + '</h1>' + ''.join(
                    '<h4 id=' + p['native_anchor'] + '>' + p['identity'].rpartition('.')[2] +
                    '</h4><pre class=ada-code-snippet><code>' +
                    html.escape(p['native_snippet'], quote=False) + '</code></pre>' for p in members))
            source_native_types(root, native, wanted)
            mat = wanted['opencv.core.mat']
            page = native / mat['native_page']
            original = page.read_text()
            for before, after in (
                ('<h1>OpenCV.Core</h1>', '<h1>OpenCV</h1>'),
                ('>Mat</h4>', '>Scalar</h4>'),
                (html.escape(mat['native_snippet'], quote=False), 'type Mat is new Natural;'),
                ('</h1>', '</h1><h4 id=' + mat['native_anchor'] + '>Mat</h4>' +
                 '<pre class=ada-code-snippet><code>' + html.escape(mat['native_snippet'], quote=False) + '</code></pre>')):
                with self.subTest(mutation=before):
                    page.write_text(original.replace(before, after, 1))
                    with self.assertRaises(ValueError):
                        source_native_types(root, native, wanted)
                    page.write_text(original)
            specification = root / mat['source_file']
            text = specification.read_text()
            for replacement in ('type Mat is new Natural;', 'type Mat is private;\n   type Mat is private;'):
                with self.subTest(replacement=replacement):
                    specification.write_text(text.replace(mat['source_declaration_text'], replacement, 1))
                    with self.assertRaises(ValueError):
                        source_native_types(root, native, wanted)
                    specification.write_text(text)


if __name__ == '__main__':
    unittest.main()
