#!/usr/bin/env python3
"""R2 publication comparison against explicitly selected immutable Core inputs.

This is a proposal, not production-policy approval. Neither a live response nor
an output-generated manifest is allowed to select a deployment or destination.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor
import html
import io
import json
from pathlib import Path
import stat
import zipfile

from highlight_gnatdoc_ada import strip_highlighting
from install_released_gnatdoc import digest, require
from link_gnatdoc_types import SECTION, plain
from qualify_production_core_links import (
    BASE_URL, CORE, fetch, git, public_model, source_native_types,
)
from qualify_released_gnatdoc import write
from verify_live_docs import command, pages_inventory, safe_path

REPO = 'zackboll/opencv_core_ada'
SOURCE = '33a2a4f3b83606a5c779b8a93abeb6c91fa49a21'
TREE = '454fb0fa3a128e638a1d7d85f345c7904f296877'
DEPLOYMENT = 7348179998
RUN = 40433988181
REVIEW = 12702919800
PAGES = 12703258126
REVIEW_SHA = '4995abbfed1ef594f8d1b31e8941cb0edfca3402a7b952f53683b1db524ddec4'
PAGES_SHA = '9c79d54f4db56b841da0f29814c87fec563ff8bb8d8991f4b4ea5e2580581c80'
ROOT = Path(__file__).resolve().parents[1]


def api(path):
    return json.loads(command(['gh', 'api', f'repos/{REPO}/{path}']))


def review_members(data):
    require(digest(data) == REVIEW_SHA, 'Core review archive digest differs')
    members = {}
    total = 0
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        require(len(archive.infolist()) == 209, 'Core publication inventory changed')
        for item in archive.infolist():
            name = safe_path(item.filename)
            total += item.file_size
            require(name not in members and not item.is_dir() and
                    not item.flag_bits & 1 and
                    stat.S_IFMT(item.external_attr >> 16) in (0, stat.S_IFREG) and
                    item.file_size <= 8_000_000 and total <= 32_000_000,
                    'unsafe, duplicate or oversized Core artifact member')
            require(Path(name).suffix in {'.html', '.css', '.js', '.json'},
                    'unexpected Core artifact file type')
            members[name] = archive.read(item)
    return members


def provenance():
    deployments = api('deployments?environment=github-pages&per_page=5')
    require(deployments and deployments[0]['id'] == DEPLOYMENT and
            deployments[0]['sha'] == SOURCE, 'Core deployment changed; renewed comparison required')
    statuses = api(f'deployments/{DEPLOYMENT}/statuses')
    require(statuses[0]['state'] == 'success' and
            statuses[0]['environment_url'] == BASE_URL and
            f'/actions/runs/{RUN}/' in statuses[0]['log_url'], 'Core deployment/run mismatch')
    run = api(f'actions/runs/{RUN}')
    require(run['head_sha'] == SOURCE and run['conclusion'] == 'success' and
            run['head_branch'] == 'main' and run['event'] == 'push' and
            run['path'] == '.github/workflows/documentation.yml', 'Core run mismatch')
    jobs = api(f'actions/runs/{RUN}/jobs')['jobs']
    for name in ('build', 'deploy'):
        found = [j for j in jobs if j['name'] == name]
        require(len(found) == 1 and found[0]['conclusion'] == 'success',
                'Core same-run job not successful: ' + name)
    artifacts = {}
    for identifier, sha in ((REVIEW, REVIEW_SHA), (PAGES, PAGES_SHA)):
        record = api(f'actions/artifacts/{identifier}')
        require(not record['expired'] and record['digest'] == 'sha256:' + sha and
                record['workflow_run']['id'] == RUN and
                record['workflow_run']['head_sha'] == SOURCE, 'Core artifact provenance differs')
        artifacts[str(identifier)] = record
    commit = api(f'git/commits/{SOURCE}')
    require(commit['sha'] == SOURCE and commit['tree']['sha'] == TREE, 'Core source tree differs')
    return {'deployment': deployments[0], 'status': statuses[0],
            'run': run, 'artifacts': artifacts, 'source_tree': TREE}


def qualify(args):
    output = args.output.absolute()
    require(not output.exists(), 'Core evidence directory must be new')
    output.mkdir(parents=True)
    before = provenance()
    write(output / 'provenance-before.json', before)
    review = command(['gh', 'api', f'repos/{REPO}/actions/artifacts/{REVIEW}/zip'])
    pages = command(['gh', 'api', f'repos/{REPO}/actions/artifacts/{PAGES}/zip'])
    members = review_members(review)
    require(digest(pages) == PAGES_SHA and pages_inventory(pages) == members,
            'Core Pages and review artifact bytes differ')
    require(git(args.core, 'rev-parse', 'HEAD').decode().strip() == CORE and
            not git(args.core, 'diff', '--name-only', 'HEAD', '--', 'src'),
            'indexed Core witness is not clean approved 0.5.0')
    historical = json.loads((ROOT / 'docs/evidence/gnatdoc009/r1/core-destination-proposal.json').read_text())
    proofs = source_native_types(args.core, args.native, historical['types'])
    require(len(proofs) == 14, 'Core identity inventory differs')
    changed = []
    for identity, proof in proofs.items():
        model = public_model(args.core / proof['source_file'])
        require(proof['declaration']['signature'] == historical['types'][identity]['declaration']['signature'],
                'indexed declaration differs from historical census')
        data = git(args.core, 'show', SOURCE + ':' + proof['source_file'])
        source = output / proof['source_file']
        source.parent.mkdir(exist_ok=True)
        source.write_bytes(data)
        model = public_model(source)
        found = [d for d in model.top if d['scope'].lower() == identity]
        require(len(found) == 1, 'missing or ambiguous current source identity: ' + identity)
        declaration = found[0]
        text = '\n'.join(model.lines[declaration['start'] - 1:declaration['end']])
        require(declaration['signature'] == proof['declaration']['signature'] and
                text == proof['source_declaration_text'], 'current Core source type changed: ' + identity)
        page = members[proof['native_page']].decode()
        matches = [s for s in SECTION.finditer(page) if s[1] == proof['native_anchor']]
        require(len(matches) == 1 and matches[0][2] == proof['identity'].rpartition('.')[2],
                'current hosted declaration missing or substituted: ' + identity)
        snippet = html.unescape(plain(strip_highlighting(matches[0][3])))
        if snippet != proof['native_snippet']:
            changed.append({'identity': identity, 'expected': proof['native_snippet'], 'actual': snippet})
        proof.update(url=BASE_URL + proof['native_page'] + '#' + proof['native_anchor'],
                     hosted_page_sha256=digest(members[proof['native_page']]),
                     hosted_source_sha256=digest(data), hosted_source_declaration=declaration,
                     hosted_snippet=snippet)
    write(output / 'referenced-types.json', proofs)
    write(output / 'changed-destinations.json', changed)

    def compare(item):
        name, expected = item
        actual = fetch(name)
        require(actual == expected, 'live Core bytes differ from pinned artifact: ' + name)
        return name, digest(actual)

    with ThreadPoolExecutor(max_workers=8) as executor:
        hosted = dict(executor.map(compare, sorted(members.items())))
    write(output / 'hosted-sha256.json', hosted)
    after = provenance()
    require(before == after, 'Core deployment changed during comparison')
    write(output / 'provenance-after.json', after)
    require(not changed, 'CORE_PUBLICATION_COMPATIBILITY_BLOCKED: referenced declaration changed')
    write(output / 'policy-proposal.json', {
        'policy_approved': False, 'production_enabled': False,
        'deployment': DEPLOYMENT, 'source': SOURCE, 'tree': TREE, 'run': RUN,
        'review_artifact': REVIEW, 'pages_artifact': PAGES,
        'review_archive_sha256': REVIEW_SHA, 'pages_archive_sha256': PAGES_SHA,
        'verified_hosted_files': len(hosted), 'verified_referenced_identities': len(proofs),
        'external_type_target': '_top',
        'proposal': 'Direct native declaration URLs; top-level Core navigation; independent merge review required',
        'historical_r1_policy_approved': False,
    })


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('core', 'native', 'output'):
        parser.add_argument('--' + name, type=Path, required=True)
    qualify(parser.parse_args())