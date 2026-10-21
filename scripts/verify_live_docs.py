#!/usr/bin/env python3
"""Read-only Pages acceptance; GitHub provenance, source reconstruction, HTTP bytes.

Only the CLI talks to GitHub. Offline tests exercise the same qualification and
transport functions without credentials. No manifest supplies content authority.
"""
import argparse
import hashlib
import http.client
import io
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys
import tarfile
import tempfile
import time
import urllib.error
import urllib.request
from urllib.parse import urlsplit
import zipfile
import zlib
from html.parser import HTMLParser

sys.dont_write_bytecode = True

ROOT = Path(__file__).resolve().parent.parent
REPO = 'zackboll/opencv_imgproc_ada'
SITE = 'https://zackboll.github.io/opencv_imgproc_ada/'
CORE = 'https://zackboll.github.io/opencv_core_ada/api/'
WORKFLOW = '.github/workflows/documentation.yml'
WORKFLOW_ID = 383777053
LIMIT = 8 * 1024 * 1024
TOTAL_LIMIT = 32 * 1024 * 1024
MIMES = {'.html': {'text/html'}, '.css': {'text/css'},
         '.js': {'application/javascript', 'text/javascript'}, '.json': {'application/json'}}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def command(args, cwd=None, limit=TOTAL_LIMIT):
    with tempfile.TemporaryFile() as errors, subprocess.Popen(
            args, cwd=cwd, stdout=subprocess.PIPE, stderr=errors) as process:
        try:
            data = process.stdout.read(limit + 1)
            require(len(data) <= limit, 'command output exceeds limit')
            status = process.wait(timeout=120)
            require(status == 0, f'command failed ({status}): {args[:3]}')
            return data
        finally:
            if process.poll() is None:
                process.kill()


def api(path):
    return json.loads(command(['gh', 'api', f'repos/{REPO}/{path}']))


def safe_path(name):
    require(isinstance(name, str) and re.fullmatch(r'[A-Za-z0-9_.\-/]+', name)
            and all(p not in ('', '.', '..') for p in name.split('/')),
            f'unsafe repository path: {name}')
    return name


def inventory(directory):
    directory = Path(directory)
    require(directory.is_dir() and not directory.is_symlink(), 'unsafe site root')
    for parent in directory.absolute().parents:
        require(not parent.is_symlink(), 'symlink site ancestor')
    result = {}
    total = 0
    for path in sorted(directory.rglob('*')):
        name = safe_path(path.relative_to(directory).as_posix())
        require(not path.is_symlink(), f'symlink in publication: {name}')
        if path.is_dir():
            require(name in ('api', 'guides'), f'unexpected directory: {name}')
            continue
        require(path.is_file() and path.stat().st_size <= LIMIT, 'unsafe publication file')
        result[name] = path.read_bytes()
        total += len(result[name])
        require(total <= TOTAL_LIMIT and len(result) <= 256, 'unbounded publication')
    require(result, 'empty publication')
    return result


def extract_archive(data, destination):
    require(len(data) <= TOTAL_LIMIT, 'artifact archive exceeds limit')
    total = 0
    names = set()
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        require(len(archive.infolist()) <= 256, 'too many archive entries')
        for entry in archive.infolist():
            name = safe_path(entry.filename.rstrip('/'))
            require(name not in names, 'duplicate archive entry')
            names.add(name)
            mode = entry.external_attr >> 16
            require(not stat.S_ISLNK(mode) and not entry.flag_bits & 1,
                    'symlink/encrypted artifact entry')
            require(stat.S_IFMT(mode) in (0, stat.S_IFREG, stat.S_IFDIR),
                    'special artifact entry')
            total += entry.file_size
            require(entry.file_size <= LIMIT and total <= TOTAL_LIMIT,
                    'expanded artifact exceeds limit')
            path = destination / name
            if entry.is_dir():
                path.mkdir(parents=True, exist_ok=True)
            else:
                path.parent.mkdir(parents=True, exist_ok=True)
                with path.open('xb') as stream:
                    stream.write(archive.read(entry))


def pages_inventory(data):
    """Read the upload-pages-artifact ZIP/tar without extracting any tar path."""
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        require(archive.namelist() == ['artifact.tar'], 'unexpected Pages ZIP inventory')
        entry = archive.getinfo('artifact.tar')
        require(entry.file_size <= TOTAL_LIMIT, 'Pages tar exceeds limit')
        tar_data = archive.read(entry)
    files, total, names = {}, 0, set()
    with tarfile.open(fileobj=io.BytesIO(tar_data), mode='r:') as archive:
        for number, entry in enumerate(archive):
            require(number < 256, 'too many Pages tar entries')
            require(entry.isfile() or entry.isdir(), 'Pages tar link/special file')
            if entry.name in ('.', './') and entry.isdir():
                continue
            name = safe_path(entry.name.removeprefix('./').rstrip('/'))
            require(name not in names, 'duplicate Pages tar entry')
            names.add(name)
            if entry.isdir():
                require(name in ('api', 'guides'), 'unexpected Pages directory')
                continue
            total += entry.size
            require(entry.size <= LIMIT and total <= TOTAL_LIMIT, 'Pages tar entity exceeds limit')
            with archive.extractfile(entry) as stream:
                files[name] = stream.read(LIMIT + 1)
    return files


def provenance(expected, run, jobs, artifacts, deployments):
    require(re.fullmatch(r'[0-9a-f]{40}', expected or ''), 'expected full 40-character SHA')
    require(run['head_sha'] == expected and run['head_branch'] == 'main'
            and run['event'] in ('push', 'workflow_dispatch')
            and run['path'] == WORKFLOW and run['workflow_id'] == WORKFLOW_ID
            and run['repository']['full_name'] == REPO
            and run['head_repository']['full_name'] == REPO,
            'wrong source/workflow provenance')
    selected = {}
    for name in ('build', 'deploy'):
        matches = [j for j in jobs if j['name'] == name]
        require(len(matches) == 1 and matches[0]['conclusion'] == 'success',
                f'{name} not successfully completed')
        selected[name] = matches[0]
    for step in ('Upload review artifact', 'Upload Pages artifact'):
        require(any(s['name'] == step and s['conclusion'] == 'success'
                    for s in selected['build']['steps']), f'{step} not successful')
    require(any(s['name'] == 'Deploy Pages' and s['conclusion'] == 'success'
                for s in selected['deploy']['steps']), 'Pages deployment step missing')
    matches = [a for a in artifacts if a['name'] == f'ada-api-{expected}']
    require(len(matches) == 1, 'missing/ambiguous qualified artifact')
    artifact = matches[0]
    require(not artifact['expired'] and artifact['workflow_run']['id'] == run['id']
            and artifact['workflow_run']['head_sha'] == expected,
            'artifact not from expected deployment run')
    pages = [a for a in artifacts if a['name'] == 'github-pages']
    require(len(pages) == 1 and not pages[0]['expired']
            and pages[0]['workflow_run']['id'] == run['id']
            and pages[0]['workflow_run']['head_sha'] == expected,
            'missing same-run Pages artifact provenance')
    job_url = f'https://github.com/{REPO}/actions/runs/{run["id"]}/job/{selected["deploy"]["id"]}'
    deployed = [d for d in deployments if d['sha'] == expected
                and d['environment'] == 'github-pages' and d.get('statuses')
                and d['statuses'][0]['state'] == 'success'
                and d['statuses'][0]['environment_url'] == SITE
                and d['statuses'][0]['log_url'] == job_url]
    require(len(deployed) == 1, 'missing successful same-run deployment provenance/approved URL')
    return {'sha': expected, 'run_id': run['id'], 'workflow_id': WORKFLOW_ID,
            'artifact_id': artifact['id'], 'deployment_id': deployed[0]['id'],
            'pages_artifact_id': pages[0]['id'],
            'deployment_job': job_url, 'url': SITE}


def github_provenance(expected, run_id):
    run = api(f'actions/runs/{run_id}')
    jobs = api(f'actions/runs/{run_id}/jobs?per_page=100')['jobs']
    artifacts = api(f'actions/runs/{run_id}/artifacts?per_page=100')['artifacts']
    deployments = api(f'deployments?sha={expected}&environment=github-pages&per_page=100')
    for deployment in deployments:
        deployment['statuses'] = api(f'deployments/{deployment["id"]}/statuses?per_page=100')
    return provenance(expected, run, jobs, artifacts, deployments)


def source_identity(root, expected):
    require(re.fullmatch(r'[0-9a-f]{40}', expected or ''), 'expected full 40-character SHA')
    require(command(['git', 'rev-parse', 'HEAD'], root).decode().strip() == expected,
            'checkout differs from expected SHA')
    require(not command(['git', 'status', '--porcelain'], root),
            'modified committed source')
    require(not root.is_symlink() and all(not p.is_symlink() for p in root.parents),
            'symlink source ancestor')
    tracked = command(['git', 'ls-files', '-z'], root).decode().split('\0')
    for name in filter(None, tracked):
        path = root / safe_path(name)
        require(not path.is_symlink(), 'symlink committed source')
    return {'sha': expected, 'tree': command(['git', 'rev-parse', 'HEAD^{tree}'], root).decode().strip()}


def qualify(artifact, reconstructed, root=ROOT, core=None):
    """Fresh generation AND source/native validation; manifests cannot authorize bytes."""
    from link_gnatdoc_types import CORE_ROOT
    from render_gnatdoc_examples import BLOCK, ExampleRenderer
    from validate_docs import validate
    core = CORE_ROOT if core is None else core
    files = inventory(artifact)
    require(files == inventory(reconstructed), 'artifact differs from independent fresh generation')
    from validate_docs import DocumentationError
    try:
        summary = validate(Path(artifact), root=Path(root), core=Path(core))
    except DocumentationError as error:
        raise ValueError(f'source/native reconstruction rejected: {error}') from error
    renderer = ExampleRenderer(artifact, root, core)
    examples = []
    for path in [Path(root) / 'docs/example.adb',
                 *sorted((Path(root) / 'docs/examples').glob('*.adb'))]:
        source = path.read_text(encoding='utf-8')
        references = renderer.references(source)
        pages = [name for name, data in files.items() if name.endswith('.html')
                 and renderer.render(source, '../' if name.startswith('guides/') else '').encode() in data]
        require(len(pages) == 1 and len(BLOCK.findall(files[pages[0]].decode())) == 1,
                'missing/duplicated authoritative example')
        examples.append({'source': path.relative_to(root).as_posix(), 'page': pages[0],
                         'sha256': digest(source.encode()), 'references': [
                             {'start': a, 'end': b, 'identity': identity,
                              'destination': renderer.destinations[identity]}
                             for a, b, identity in references]})
    require(len(examples) == 6 and sum(len(e['references']) for e in examples) == 55,
            'six-example / 55 source-qualified hyperlink baseline changed')
    return files, {'coverage': summary, 'examples': examples, 'source_qualified_links': 55,
                   'imgproc_types': {name: renderer.destinations[
                       'opencv.image_processing.' + name.lower()] for name in (
                           'Connected_Component_Set', 'Component_Statistics', 'Contour_Set',
                           'Histogram', 'Phase_Correlation_Result')}}


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def entity(url, fixture=False):
    parsed = urlsplit(url)
    if fixture:
        require(parsed.scheme == 'http' and parsed.hostname == '127.0.0.1', 'fixture origin')
    else:
        require(parsed.scheme == 'https' and parsed.netloc == 'zackboll.github.io'
                and not parsed.username and not parsed.password
                and any(url.startswith(base) for base in (SITE, CORE)), 'unapproved HTTPS origin')
    require(not parsed.query and not parsed.fragment, 'unexpected HTTP query/fragment')
    prefix = '/opencv_imgproc_ada/' if parsed.path.startswith('/opencv_imgproc_ada/') else '/opencv_core_ada/api/'
    relative = parsed.path[len(prefix):] if not fixture else parsed.path.lstrip('/')
    safe_path(relative or 'index.html')
    request = urllib.request.Request(url, headers={
        'Accept-Encoding': 'gzip, identity', 'Cache-Control': 'no-cache',
        'User-Agent': 'Imgproc-live-publication-verifier/1'})
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())
    with opener.open(request, timeout=30) as response:
        require(response.status == 200 and response.url == url, 'HTTP status/redirect')
        for name in ('Content-Type', 'Content-Length', 'Content-Encoding', 'Transfer-Encoding'):
            require(len(response.headers.get_all(name, [])) <= 1, 'duplicate response header')
        mime = response.headers.get_content_type()
        require(mime in MIMES.get(Path(relative or 'index.html').suffix, set()), 'incorrect Content-Type')
        length = response.headers.get('Content-Length')
        transfer = response.headers.get('Transfer-Encoding')
        require(not (length and transfer) and transfer in (None, 'chunked'), 'ambiguous response framing')
        require(length is None or (length.isdecimal() and int(length) <= LIMIT), 'invalid response length')
        raw = response.read(LIMIT + 1)
        require(len(raw) <= LIMIT, 'HTTP entity exceeds limit')
        require(length is None or len(raw) == int(length), 'truncated HTTP entity')
        encoding = response.headers.get('Content-Encoding', 'identity').lower()
        require(encoding in ('identity', 'gzip'), 'unsupported compression')
        if encoding == 'gzip':
            decoder = zlib.decompressobj(16 + zlib.MAX_WBITS)
            data = decoder.decompress(raw, LIMIT + 1)
            require(len(data) <= LIMIT and decoder.eof and not decoder.unused_data
                    and not decoder.unconsumed_tail, 'invalid/truncated/unbounded gzip entity')
        else:
            data = raw
        return data, {'url': url, 'bytes': len(data), 'sha256': digest(data),
                      'content_type': mime, 'content_encoding': encoding}


class CoreIndex(HTMLParser):
    def __init__(self, text):
        super().__init__()
        self.symbols = {}
        self.ids = set()
        self.feed(text)

    def handle_starttag(self, tag, attrs):
        attributes = dict(attrs)
        require(len(attributes) == len(attrs), 'duplicate Core markup attribute')
        if 'id' in attributes:
            require(attributes['id'] not in self.ids, 'duplicate Core ID')
            self.ids.add(attributes['id'])
        require(not any(name.startswith('on') for name in attributes), 'unsafe Core event handler')
        require(tag not in ('base', 'object', 'embed', 'applet', 'form'), 'unsafe Core active content')
        if tag == 'script':
            require(attributes == {'src': 'gnatdoc-navigation.js', 'defer': None},
                    'unexpected Core script')
        if tag == 'a' and 'data-symbol' in attributes:
            name = attributes['data-symbol']
            require(name not in self.symbols, 'duplicate Core symbol')
            self.symbols[name] = attributes.get('href', '')


def core_links(fetch=entity, core=None):
    """Discover CURRENT Core native filenames; never reuse historical hashes."""
    from link_gnatdoc_types import CORE_ROOT, SECTION, plain, visible_declarations
    from render_gnatdoc_examples import CORE_SYMBOLS
    from highlight_gnatdoc_ada import strip_highlighting
    core = CORE_ROOT if core is None else core
    index, record = fetch(CORE + 'index.html')
    symbols = CoreIndex(index.decode('utf-8')).symbols
    renderer_sources = {}
    for filename in ('opencv.ads', 'opencv-core.ads'):
        package, lines, declarations = visible_declarations(Path(core) / 'src' / filename)
        for declaration in declarations:
            from compare_gnatdoc_warnings import code_tokens
            declaration['full_signature'] = ' '.join(
                code_tokens(line) for line in lines[declaration['start'] - 1:declaration['end']])
            renderer_sources[declaration['scope'].lower()] = declaration
    results, cache = [], {}
    for symbol in CORE_SYMBOLS:
        declaration = renderer_sources.get(symbol.lower())
        require(declaration and declaration['signature'].split()[0] in ('type', 'subtype'),
                'Core symbol is not a public type/subtype')
        href = symbols.get(symbol, '')
        require(re.fullmatch(r'[a-f0-9]{64}\.html#[a-f0-9]{64}', href), 'unsupported Core symbol destination')
        name, anchor = href.split('#')
        if name not in cache:
            cache[name] = fetch(CORE + name)
        data, target_record = cache[name]
        text = data.decode('utf-8')
        parsed = CoreIndex(text)
        require(anchor in parsed.ids, 'missing Core fragment')
        owner, _, simple = symbol.rpartition('.')
        require(f'<h1>{owner}</h1>' in text, 'wrong Core package identity')
        matches = [m for m in SECTION.finditer(text) if m[1] == anchor]
        require(len(matches) == 1 and matches[0][2] == simple, 'wrong existing Core type anchor')
        snippet = plain(strip_highlighting(matches[0][3]))
        import html
        from compare_gnatdoc_warnings import code_tokens
        actual = ' '.join(code_tokens(html.unescape(snippet)).lower().split())
        expected = ' '.join(declaration['full_signature'].lower().split())
        require(actual == expected, f'Core public type declaration changed: {symbol}: {actual!r} != {expected!r}')
        results.append({'symbol': symbol, 'stable_url': CORE + 'index.html?symbol=' + symbol,
                        'current_destination': CORE + href, 'declaration': expected,
                        'entity': target_record})
    return {'index': record, 'types': results,
            'no_javascript': 'Native package/sidebar navigation; symbol queries require JavaScript.'}


def compare(files, fetch=entity, attempts=1, interval=15, external=core_links):
    require(type(attempts) is int and 1 <= attempts <= 10
            and type(interval) is int and 0 <= interval <= 30, 'unbounded retry configuration')
    evidence = {'passed': False, 'attempts': []}
    for number in range(1, attempts + 1):
        attempt = {'number': number, 'files': [], 'passed': False}
        evidence['attempts'].append(attempt)
        try:
            for name, expected in sorted(files.items()):
                data, record = fetch(SITE + safe_path(name))
                record['comparison'] = data == expected
                attempt['files'].append(record)
                require(data == expected, f'stale/altered publication: {name}')
            data, record = fetch(SITE)
            record['comparison'] = data == files['index.html']
            attempt['files'].append(record)
            require(record['comparison'], 'stale/altered publication root')
            attempt['core'] = external(fetch)
            attempt['passed'] = evidence['passed'] = True
            break
        except (ValueError, OSError, http.client.HTTPException, zlib.error) as error:
            attempt['error'] = str(error)
        if number < attempts:
            time.sleep(interval)
    return evidence


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--expected-sha', required=True)
    parser.add_argument('--run-id', required=True, type=int)
    parser.add_argument('--source-root', type=Path, default=ROOT)
    parser.add_argument('--attempts', type=int, default=1)
    parser.add_argument('--interval', type=int, default=15)
    parser.add_argument('--evidence', type=Path, required=True)
    args = parser.parse_args()
    result = {'passed': False}
    try:
        require(1 <= args.attempts <= 10 and 0 <= args.interval <= 30, 'unbounded retry configuration')
        root = args.source_root.absolute()
        destination = args.evidence.absolute()
        require(destination.parent.is_dir()
                and all(not p.is_symlink() for p in destination.parents)
                and not destination.exists() and not destination.is_symlink()
                and not destination.is_relative_to(root), 'evidence must be a fresh external file')
        result['source'] = source_identity(root, args.expected_sha)
        result['provenance'] = github_provenance(args.expected_sha, args.run_id)
        # Preserve current generator, tool versions and qualification gates.
        subprocess.run(['sh', str(root / 'scripts/generate_docs.sh')], cwd=root, check=True, timeout=900)
        os.environ['DOC_CORE_SOURCE'] = command(
            ['alr', 'exec', '--', 'printenv', 'OPENCV_CORE_ALIRE_PREFIX'], root).decode().strip()
        with tempfile.TemporaryDirectory(prefix='imgproc-live-') as temporary:
            artifact = Path(temporary) / 'artifact'
            artifact.mkdir()
            archive = command(['gh', 'api', f'repos/{REPO}/actions/artifacts/'
                               f'{result["provenance"]["artifact_id"]}/zip'])
            result['artifact_archive_sha256'] = digest(archive)
            extract_archive(archive, artifact)
            files, qualification = qualify(artifact, root / '_site', root)
            pages = command(['gh', 'api', f'repos/{REPO}/actions/artifacts/'
                             f'{result["provenance"]["pages_artifact_id"]}/zip'])
            require(pages_inventory(pages) == files, 'Pages artifact differs from qualified reconstruction')
            result['pages_archive_sha256'] = digest(pages)
            result['qualification'] = qualification
            result['inventory'] = {name: {'bytes': len(data), 'sha256': digest(data)}
                                   for name, data in files.items()}
            result.update(compare(files, attempts=args.attempts, interval=args.interval))
            require(inventory(artifact) == files, 'artifact changed during verification')
        require(source_identity(root, args.expected_sha) == result['source'], 'source changed during verification')
        # Detect a changed deployment/provenance during a long comparison.
        require(github_provenance(args.expected_sha, args.run_id) == result['provenance'],
                'deployment provenance changed during verification')
    except (ValueError, OSError, subprocess.SubprocessError, http.client.HTTPException,
            KeyError, zipfile.BadZipFile, tarfile.TarError) as error:
        result.update(passed=False, error=str(error))
    # A failure must not hide diagnostics; CI also retains the stdout log.
    print(json.dumps(result, indent=2, sort_keys=True))
    if 'destination' in locals() and destination.parent.is_dir() \
            and all(not p.is_symlink() for p in destination.parents) \
            and not destination.is_relative_to(args.source_root.absolute()) \
            and not destination.exists() and not destination.is_symlink():
        with destination.open('x', encoding='utf-8') as stream:
            json.dump(result, stream, indent=2, sort_keys=True)
            stream.write('\n')
    return 0 if result['passed'] else 1


if __name__ == '__main__':
    sys.exit(main())