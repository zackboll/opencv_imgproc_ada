"""Offline adversarial publication campaign: real HTTP, source and native authority."""
import contextlib
import copy
import gzip
import http.server
import io
import json
import os
from pathlib import Path
import re
import shutil
import sys
import tempfile
import threading
import tarfile
import time
import unittest
import zipfile
from unittest import mock

import verify_live_docs as live
from link_gnatdoc_types import CORE_ROOT
from render_gnatdoc_examples import BLOCK, CORE_SYMBOLS


class Commands(unittest.TestCase):
    """Real local children; no GitHub/network or long timeout dependency."""

    def run_command(self, source, **kwargs):
        return live.command([sys.executable, '-c', source], **kwargs)

    def test_successful_command_and_exact_output_boundary(self):
        self.assertEqual(self.run_command('import os; os.write(1, b"qualified")',
                                          limit=9, timeout=2), b'qualified')

    def test_immediate_exit(self):
        self.assertEqual(self.run_command('pass', timeout=2), b'')

    def test_nonzero_status_with_incomplete_output_is_not_success(self):
        with self.assertRaises(live.CommandError) as caught:
            self.run_command('import os; os.write(1, b"partial"); os._exit(7)', timeout=2)
        self.assertEqual(caught.exception.classification, 'nonzero_status')
        self.assertEqual(caught.exception.status, 7)
        self.assertIn('stdout_bytes=7', str(caught.exception))

    def assert_timeout(self, source):
        started = time.monotonic()
        with self.assertRaises(live.CommandError) as caught:
            self.run_command(source, timeout=0.3)
        self.assertEqual(caught.exception.classification, 'timeout')
        self.assertLess(time.monotonic() - started, 3)
        return caught.exception

    def test_no_output_hang(self):
        self.assert_timeout('import time; time.sleep(60)')

    def test_partial_output_hang_is_not_success(self):
        error = self.assert_timeout('import os,time; os.write(1,b"partial"); time.sleep(60)')
        self.assertIn('stdout_bytes=7', str(error))

    def test_closed_pipes_do_not_bypass_process_exit_deadline(self):
        self.assert_timeout('import os,time; os.close(1); os.close(2); time.sleep(60)')

    def test_continuous_output_does_not_restart_deadline(self):
        self.assert_timeout('import os,time\nwhile True: os.write(1,b"x"); time.sleep(0.01)')

    def test_descendant_holding_pipes_does_not_bypass_deadline(self):
        self.assert_timeout('import os,time\nif os.fork(): os._exit(0)\ntime.sleep(60)')

    def test_oversized_stdout(self):
        with self.assertRaises(live.CommandError) as caught:
            self.run_command('import os,time; os.write(1,b"x"*4096); time.sleep(60)',
                             limit=32, timeout=2)
        self.assertEqual(caught.exception.classification, 'oversized_output')
        self.assertIn('stdout_bytes=33', str(caught.exception))

    def test_stderr_is_drained_and_bounded(self):
        self.assertEqual(self.run_command(
            'import os; os.write(2,b"x"*32768); os.write(1,b"ok")', timeout=2), b'ok')
        with self.assertRaises(live.CommandError) as caught:
            self.run_command('import os\nwhile True: os.write(2,b"x"*4096)', timeout=2)
        self.assertEqual(caught.exception.classification, 'oversized_output')
        self.assertIn('stderr_bytes=65537', str(caught.exception))

    def test_failure_diagnostics_do_not_include_arguments_or_output(self):
        secret = 'fixture-credential-never-publish'
        with self.assertRaises(live.CommandError) as caught:
            self.run_command(f'import os; os.write(1,b"{secret}"); '
                             f'os.write(2,b"{secret}"); os._exit(2)', timeout=2)
        self.assertNotIn(secret, str(caught.exception))
        self.assertNotIn('os.write', str(caught.exception))
        self.assertIn('status=2', str(caught.exception))

    def test_timeout_reaps_child_and_closes_all_resources(self):
        real_popen = live.subprocess.Popen
        children = []
        def spawn(*args, **kwargs):
            process = real_popen(*args, **kwargs)
            children.append(process)
            return process
        before = len(os.listdir('/proc/self/fd'))
        with mock.patch.object(live.subprocess, 'Popen', side_effect=spawn), \
                mock.patch.object(live.tempfile, 'TemporaryFile',
                                  side_effect=AssertionError('no output spooling')):
            for _ in range(3):
                self.assert_timeout('import time; time.sleep(60)')
        self.assertEqual(len(os.listdir('/proc/self/fd')), before)
        for child in children:
            self.assertEqual(child.returncode, -live.signal.SIGKILL)
            self.assertTrue(child.stdout.closed)
            self.assertTrue(child.stderr.closed)
            with self.assertRaises(ChildProcessError):
                os.waitpid(child.pid, os.WNOHANG)

    def test_cli_returns_nonzero_and_classified_evidence_for_command_failures(self):
        for classification in ('timeout', 'oversized_output', 'nonzero_status'):
            with self.subTest(classification=classification), tempfile.TemporaryDirectory() as directory:
                evidence = Path(directory) / 'failure.json'
                argv = ['verify_live_docs.py', '--expected-sha', 'a' * 40,
                        '--run-id', '42', '--evidence', str(evidence)]
                with mock.patch.object(sys, 'argv', argv), \
                        mock.patch.object(live, 'source_identity', side_effect=live.CommandError(
                            classification, 7, 0, 2 if classification == 'nonzero_status' else None)), \
                        contextlib.redirect_stdout(io.StringIO()):
                    self.assertEqual(live.main(), 1)
                result = json.loads(evidence.read_text())
                self.assertFalse(result['passed'])
                self.assertEqual(result['failure_class'], classification)


@contextlib.contextmanager
def server(body=b'qualified', headers=None, status=200):
    class Handler(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            self.send_response(status)
            for name, value in (headers or [('Content-Type', 'text/html')]):
                self.send_header(name, value)
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, *args):
            pass
    instance = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    thread = threading.Thread(target=instance.serve_forever, daemon=True)
    thread.start()
    try:
        yield f'http://127.0.0.1:{instance.server_port}/index.html'
    finally:
        instance.shutdown()
        instance.server_close()
        thread.join()


class Transport(unittest.TestCase):
    def test_decoded_http_entities(self):
        for body, headers in ((b'qualified', [('Content-Type', 'text/html')]),
                              (gzip.compress(b'qualified'), [('Content-Type', 'text/html'),
                                                            ('Content-Encoding', 'gzip')])):
            with self.subTest(headers=headers), server(body, headers) as url:
                self.assertEqual(live.entity(url, fixture=True)[0], b'qualified')

    def test_http_mutations(self):
        mutations = [
            ('redirect', 302, [('Location', 'https://evil.example/')], b''),
            ('missing', 404, [('Content-Type', 'text/html')], b''),
            ('mime', 200, [('Content-Type', 'text/plain')], b'qualified'),
            ('truncated', 200, [('Content-Type', 'text/html'), ('Content-Length', '20')], b'qualified'),
            ('gzip', 200, [('Content-Type', 'text/html'), ('Content-Encoding', 'gzip')], b'broken'),
            ('truncated gzip', 200, [('Content-Type', 'text/html'), ('Content-Encoding', 'gzip')],
             gzip.compress(b'qualified')[:-4]),
            ('unsupported encoding', 200, [('Content-Type', 'text/html'), ('Content-Encoding', 'br')], b'bad'),
            ('duplicate header', 200, [('Content-Type', 'text/html'), ('Content-Type', 'text/html')], b'bad'),
            ('length', 200, [('Content-Type', 'text/html'), ('Content-Length', 'oops')], b'bad'),
            ('framing', 200, [('Content-Type', 'text/html'), ('Content-Length', '3'),
                              ('Transfer-Encoding', 'chunked')], b'bad'),
            ('bomb', 200, [('Content-Type', 'text/html'), ('Content-Encoding', 'gzip')],
             gzip.compress(b'a' * (live.LIMIT + 1))),
        ]
        for label, status, headers, body in mutations:
            with self.subTest(mutation=label), server(body, headers, status) as url:
                with self.assertRaises((ValueError, OSError, live.http.client.HTTPException, live.zlib.error)):
                    live.entity(url, fixture=True)

    def test_origins_and_paths(self):
        for url in ('https://evil.example/index.html', live.SITE + '../escape.html',
                    live.SITE + '%2e%2e/escape.html', live.SITE + 'a\\b.html',
                    live.SITE.replace('https:', 'http:') + 'index.html',
                    'https://zackboll.github.io:443/opencv_imgproc_ada/index.html'):
            with self.subTest(url=url), self.assertRaises(ValueError):
                live.entity(url)


def provenance_fixture():
    sha = 'a' * 40
    run = {'id': 42, 'head_sha': sha, 'head_branch': 'main', 'event': 'push',
           'path': live.WORKFLOW, 'workflow_id': live.WORKFLOW_ID,
           'repository': {'full_name': live.REPO}, 'head_repository': {'full_name': live.REPO}}
    jobs = [{'name': name, 'id': identifier, 'conclusion': 'success',
             'steps': [{'name': step, 'conclusion': 'success'} for step in steps]}
            for name, identifier, steps in (
                ('build', 1, ['Upload review artifact', 'Upload Pages artifact']),
                ('deploy', 2, ['Deploy Pages']))]
    artifacts = [{'id': 3, 'name': f'ada-api-{sha}', 'expired': False, 'digest': 'sha256:' + 'c' * 64,
                  'workflow_run': {'id': 42, 'head_sha': sha}},
                 {'id': 5, 'name': 'github-pages', 'expired': False, 'digest': 'sha256:' + 'd' * 64,
                  'workflow_run': {'id': 42, 'head_sha': sha}}]
    deployments = [{'id': 4, 'sha': sha, 'environment': 'github-pages', 'statuses': [
        {'state': 'success', 'environment_url': live.SITE,
         'log_url': f'https://github.com/{live.REPO}/actions/runs/42/job/2'}]}]
    return sha, run, jobs, artifacts, deployments


class Provenance(unittest.TestCase):
    def test_valid_deployment(self):
        self.assertEqual(live.provenance(*provenance_fixture())['run_id'], 42)

    def test_missing_or_wrong_provenance(self):
        changes = [lambda f: f[1].update(head_sha='b' * 40),
                   lambda f: f[1].update(path='other.yml'),
                   lambda f: f[1].update(event='pull_request'),
                   lambda f: f[2][0].update(conclusion='failure'),
                   lambda f: f[2][1].update(conclusion='pending'),
                   lambda f: f[3][0]['workflow_run'].update(id=99),
                   lambda f: f[3][0].update(expired=True),
                   lambda f: f[4].clear(),
                   lambda f: f[4][0].update(environment='other'),
                   lambda f: f[4][0]['statuses'][0].update(environment_url='https://evil.example/'),
                   lambda f: f[4][0]['statuses'][0].update(log_url='another run')]
        for change in changes:
            fixture = copy.deepcopy(provenance_fixture())
            change(fixture)
            with self.subTest(change=change), self.assertRaises(ValueError):
                live.provenance(*fixture)

    def test_wrong_expected_sha(self):
        for sha in ('main', 'b' * 40):
            with self.subTest(sha=sha), self.assertRaises(ValueError):
                live.source_identity(live.ROOT, sha)

    def test_archive_traversal_links_and_limits(self):
        for name, mode in (('../escape', 0), ('/absolute', 0), ('%2e%2e/escape', 0),
                           ('api/link', 0o120777 << 16)):
            with self.subTest(name=name), tempfile.TemporaryDirectory() as directory:
                buffer = io.BytesIO()
                with zipfile.ZipFile(buffer, 'w') as archive:
                    entry = zipfile.ZipInfo(name)
                    entry.external_attr = mode
                    archive.writestr(entry, b'payload')
                with self.assertRaises(ValueError):
                    live.extract_archive(buffer.getvalue(), Path(directory))

    def test_pages_payload_inventory_and_unsafe_tar(self):
        for unsafe in (False, True):
            tar_buffer = io.BytesIO()
            with tarfile.open(fileobj=tar_buffer, mode='w') as archive:
                entry = tarfile.TarInfo('./index.html')
                entry.size = 9
                if unsafe:
                    entry.type = tarfile.SYMTYPE
                    entry.linkname = '/etc/passwd'
                archive.addfile(entry, io.BytesIO(b'qualified'))
            buffer = io.BytesIO()
            with zipfile.ZipFile(buffer, 'w') as archive:
                archive.writestr('artifact.tar', tar_buffer.getvalue())
            if unsafe:
                with self.assertRaises(ValueError):
                    live.pages_inventory(buffer.getvalue())
            else:
                self.assertEqual(live.pages_inventory(buffer.getvalue()), {'index.html': b'qualified'})


@unittest.skipUnless((live.ROOT / '_site/api/type-crossrefs.json').is_file(), 'requires generated site')
class Publication(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.site = Path(self.temporary.name) / 'artifact'
        shutil.copytree(live.ROOT / '_site', self.site)

    def test_valid_qualified_publication(self):
        files, summary = live.qualify(self.site, live.ROOT / '_site')
        self.assertEqual(len(summary['examples']), 6)
        self.assertEqual(sum(len(e['references']) for e in summary['examples']), 55)
        result = live.compare(files, fetch=lambda url: (
            files[url.removeprefix(live.SITE) or 'index.html'], {'url': url}), external=lambda f: {})
        self.assertTrue(result['passed'])
        self.assertEqual(len(result['attempts'][0]['files']), len(files) + 1)

    def test_artifact_mutations(self):
        original = live.inventory(self.site)
        mutations = [('index.html', lambda t: t.replace('ada-keyword', 'no-highlight', 1)),
                     ('index.html', lambda t: t.replace('>with</span>', '>With</span>', 1)),
                     ('index.html', lambda t: t.replace('symbol=OpenCV.Core.Mat', 'symbol=OpenCV.Size', 1)),
                     ('index.html', lambda t: t + '<a href="https://evil.example/">bad</a>'),
                     ('index.html', lambda t: t + '<script>alert(1)</script>'),
                     ('index.html', lambda t: t + '<p id="x"></p><p id="x"></p>'),
                     ('index.html', lambda t: BLOCK.sub('', t)),
                     ('index.html', lambda t: BLOCK.sub(lambda m: m[0] * 2, t)),
                     ('index.html', lambda t: t + '<a href="api/index.html#missing">bad</a>'),
                     ('api/type-crossrefs.json', lambda t: '{}'),
                     ('api/gnatdoc-theme.css', lambda t: t + '/* altered */'),
                     ('api/gnatdoc-navigation.js', lambda t: t + 'alert(1);')]
        guide = 'guides/segmentation-contours-and-morphology.html'
        native = next(data.decode() for name, data in original.items()
                      if re.fullmatch(r'api/[a-f0-9]{64}.html', name))
        wrong_anchor = re.search(r'<h4 id=([^ >]+)>Histogram</h4>', native)[1]
        mutations.append((guide, lambda t: re.sub(
            r'(<a class="type-reference" href="../api/[^#]+#)[^"]+',
            lambda m: m[1] + wrong_anchor, t, count=1)))
        for name, transform in mutations:
            with self.subTest(file=name, transform=transform):
                path = self.site / name
                changed = transform(original[name].decode())
                self.assertNotEqual(changed.encode(), original[name])
                path.write_text(changed)
                with self.assertRaises(ValueError):
                    live.qualify(self.site, live.ROOT / '_site')
                path.write_bytes(original[name])
        (self.site / 'api/gnatdoc-navigation.js').unlink()
        with self.assertRaises(ValueError):
            live.qualify(self.site, live.ROOT / '_site')

    def test_manifest_cannot_authorize_content(self):
        # Even matching artifact/reconstruction copies cannot authorize a
        # forged manifest: source/native qualification is independently required.
        (self.site / 'api/type-crossrefs.json').write_text('{}')
        with self.assertRaises(ValueError):
            live.qualify(self.site, self.site)

    def test_unexpected_inventory(self):
        (self.site / 'unexpected.html').write_text('<html>unexpected</html>')
        with self.assertRaises(ValueError):
            live.qualify(self.site, live.ROOT / '_site')

    def test_stale_and_incomplete_attempts(self):
        files = {'index.html': b'one', 'api/index.html': b'two'}
        counter = 0
        def fetch(url):
            nonlocal counter
            counter += 1
            # First attempt passes api/index but fails index; second fails api.
            # Partial successes must never accumulate into one passing attempt.
            return (b'two' if counter == 1 else b'stale'), {'url': url}
        with mock.patch.object(live.time, 'sleep'):
            result = live.compare(files, fetch=fetch, attempts=2, interval=0, external=lambda f: {})
        self.assertFalse(result['passed'])
        self.assertEqual(len(result['attempts']), 2)

    def test_valid_publication_over_actual_offline_http(self):
        files, _ = live.qualify(self.site, live.ROOT / '_site')
        import functools
        handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(self.site))
        instance = http.server.ThreadingHTTPServer(('127.0.0.1', 0), handler)
        thread = threading.Thread(target=instance.serve_forever, daemon=True)
        thread.start()
        try:
            base = f'http://127.0.0.1:{instance.server_port}/'
            def fetch(url):
                return live.entity(base + url.removeprefix(live.SITE), fixture=True)
            result = live.compare(files, fetch=fetch, external=lambda f: {})
            self.assertTrue(result['passed'], result)
        finally:
            instance.shutdown()
            instance.server_close()
            thread.join()

    def test_corrupt_live_entities_and_missing_files(self):
        files = live.inventory(self.site)
        for name in ('index.html', 'api/gnatdoc-theme.css', 'api/gnatdoc-navigation.js'):
            def fetch(url):
                relative = url.removeprefix(live.SITE) or 'index.html'
                return files[relative] + (b'changed' if relative == name else b''), {'url': url}
            with self.subTest(file=name):
                self.assertFalse(live.compare(files, fetch=fetch, external=lambda f: {})['passed'])
        with mock.patch.object(live, 'entity', side_effect=OSError('missing')):
            self.assertFalse(live.compare(files, fetch=live.entity)['passed'])

    def test_bounds_and_symlinks(self):
        for attempts, interval in ((0, 0), (11, 0), (1, 31), (1, -1)):
            with self.subTest(attempts=attempts, interval=interval), self.assertRaises(ValueError):
                live.compare({}, attempts=attempts, interval=interval)
        (self.site / 'escape').symlink_to('/etc/passwd')
        with self.assertRaises(ValueError):
            live.inventory(self.site)


class Core(unittest.TestCase):
    def fixture(self, wrong=False):
        from link_gnatdoc_types import visible_declarations
        declarations = {}
        for file in ('opencv.ads', 'opencv-core.ads'):
            _, lines, found = visible_declarations(CORE_ROOT / 'src' / file)
            from compare_gnatdoc_warnings import code_tokens
            for declaration in found:
                declaration['full_signature'] = ' '.join(
                    code_tokens(line) for line in lines[declaration['start'] - 1:declaration['end']])
            declarations.update({d['scope'].lower(): d for d in found})
        index, pages = [], {}
        for number, symbol in enumerate(CORE_SYMBOLS):
            anchor = f'{number:064x}'
            filename = f'{number:064x}.html'
            index.append(f'<a data-symbol="{symbol}" href="{filename}#{anchor}">type</a>')
            owner, _, simple = symbol.rpartition('.')
            declaration = declarations[symbol.lower()]['full_signature']
            import html
            pages[live.CORE + filename] = (f'<h1>{owner}</h1><h4 id={anchor}>' +
                ('Size' if wrong and number == 0 else simple) +
                '</h4><pre class=ada-code-snippet><code>' + html.escape(declaration) + '</code></pre>').encode()
        pages[live.CORE + 'index.html'] = ''.join(index).encode()
        return lambda url: (pages[url], {'url': url})

    def test_current_native_destinations(self):
        self.assertEqual(len(live.core_links(self.fixture())['types']), 8)

    def test_wrong_existing_core_type(self):
        with self.assertRaisesRegex(ValueError, 'wrong existing Core'):
            live.core_links(self.fixture(wrong=True))


class Workflow(unittest.TestCase):
    def test_main_only_read_only_job(self):
        text = (live.ROOT / '.github/workflows/documentation.yml').read_text()
        job = text.split('  verify-live:\n')[1]
        for required in ('needs: deploy', 'timeout-minutes: 45',
                         'contents: read', 'actions: read', 'deployments: read',
                         'ref: ${{ github.sha }}', '--expected-sha', '--run-id', 'if: always()'):
            self.assertIn(required, job)
        self.assertNotIn(': write', job)
        self.assertIn("if: github.ref == 'refs/heads/main' && github.event_name != 'pull_request'", job)


if __name__ == '__main__':
    unittest.main()