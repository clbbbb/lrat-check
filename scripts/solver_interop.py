"""Reproducible Linux solver/checker integration; no upstream sources vendored."""
import itertools
import json
from pathlib import Path
import subprocess
import tarfile
import tempfile
import time
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / '_build' / 'interop'
PINS = {
    'arminbiere/cadical': 'c60730422e758ef1cebe7aeddf2dda31c996bf04',
    'arminbiere/lrat-trim': 'b30f400f4ee5c32b77ee566a7c006081b521534f',
}
DRAT_PIN = '2e3b2dc0ecf938addbd779d42877b6ed69d9a985'


def run(command, *, cwd=ROOT, allowed=(0,), timeout=180):
    result = subprocess.run([str(x) for x in command], cwd=cwd, capture_output=True,
                            text=True, errors='replace', timeout=timeout)
    if result.returncode not in allowed:
        raise RuntimeError(f'{command}: exit {result.returncode}\n{result.stdout}\n{result.stderr}')
    return result


def build(repo, directory):
    pin = PINS[repo]
    archive = directory / (repo.split('/')[-1] + '.tar.gz')
    urllib.request.urlretrieve(f'https://codeload.github.com/{repo}/tar.gz/{pin}', archive)
    with tarfile.open(archive) as source:
        source.extractall(directory, filter='data')
    path = directory / f'{repo.split("/")[-1]}-{pin}'
    run(['./configure'], cwd=path)
    run(['make', '-j2'], cwd=path, timeout=600)
    return path


def dimacs(variables, clauses):
    return f'p cnf {variables} {len(clauses)}\n' + ''.join(' '.join(map(str, c)) + ' 0\n' for c in clauses)


def corpus():
    # Original generators: no benchmark data copied from upstream projects.
    for pigeons in (3, 5, 7):
        holes = pigeons - 1
        variable = lambda p, h: p * holes + h + 1
        clauses = [[variable(p, h) for h in range(holes)] for p in range(pigeons)]
        clauses += [[-variable(p, h), -variable(q, h)]
                    for h in range(holes) for p in range(pigeons) for q in range(p + 1, pigeons)]
        yield f'pigeonhole-{pigeons}', dimacs(pigeons * holes, clauses)
    for vertices in (3, 5, 7):
        clauses = []
        for v in range(vertices):
            clauses += [[2*v+1, 2*v+2], [-2*v-1, -2*v-2]]
            for color in (0, 1):
                clauses.append([-(2*v+color+1), -(2*((v+1) % vertices)+color+1)])
        yield f'odd-cycle-{vertices}', dimacs(2*vertices, clauses)
    for variables in (3, 5, 8):
        clauses = [[-(i+1) if value else i+1 for i, value in enumerate(bits)]
                   for bits in itertools.product((0, 1), repeat=variables)]
        yield f'blocked-assignments-{variables}', dimacs(variables, clauses)


def moon(*args):
    return ['moon', 'run', '--release', 'cmd/main', '--', *args]


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    run(['moon', 'build', '--release', '--deny-warn'])
    rows = []
    with tempfile.TemporaryDirectory(prefix='lrat-reference-') as temporary:
        directory = Path(temporary)
        solver = build('arminbiere/cadical', directory) / 'build' / 'cadical'
        trimmer = build('arminbiere/lrat-trim', directory) / 'lrat-trim'
        for name in ('drat-trim', 'lrat-check'):
            source = directory / f'{name}.c'
            urllib.request.urlretrieve(f'https://raw.githubusercontent.com/marijnheule/drat-trim/{DRAT_PIN}/{name}.c', source)
            run(['gcc', '-std=c99', '-DLONGTYPE', '-O2', source, '-o', directory/name])
        checker = directory / 'lrat-check'
        for name, text in corpus():
            cnf = OUTPUT / f'{name}.cnf'
            cnf.write_text(text, encoding='ascii')
            for kind in ('drat', 'drat-binary', 'lrat', 'lrat-binary'):
                proof = OUTPUT / f'{name}.{kind}'
                run([solver, '--quiet', '--lrat=' + str(kind.startswith('lrat')).lower(),
                     '--binary=' + str(kind.endswith('binary')).lower(), cnf, proof], allowed=(20,))
                start = time.perf_counter()
                command = moon('check', '--format', kind, cnf, proof)
                rss_file = OUTPUT / f'{name}.{kind}.rss.txt'
                if Path('/usr/bin/time').exists():
                    run(['/usr/bin/time', '-f', '%M', '-o', rss_file, *command])
                else:
                    run(command)
                elapsed = time.perf_counter() - start
                generated = OUTPUT / f'{name}.{kind}.generated.lrat'
                run(moon('convert', '--from', kind, '--to', 'lrat', cnf, proof, generated))
                run([checker, cnf, generated])
                binary = OUTPUT / f'{name}.{kind}.generated.clrat'
                run(moon('convert', '--from', 'lrat', '--to', 'lrat-binary', cnf, generated, binary))
                # A different implementation consumes our binary encoding.
                # lrat-trim parses full binary LRAT but does not check general
                # negative RAT antecedents. Decode and trim without checking, then use
                # the full RAT checker on its independently decoded text.
                decoded = OUTPUT / f'{name}.{kind}.reference-decoded.lrat'
                run([trimmer, '-q', '--no-check', '--ascii', cnf, binary, decoded], allowed=(0, 20))
                run([checker, cnf, decoded])
                truncated = OUTPUT / 'truncated.clrat'
                truncated.write_bytes(binary.read_bytes()[:-1])
                run(moon('check', '--format', 'lrat-binary', cnf, truncated), allowed=(1,))
                if kind.startswith('drat'):
                    run([directory/'drat-trim', cnf, proof])
                rows.append(dict(case=name, format=kind, input_bytes=proof.stat().st_size,
                                 lrat_bytes=generated.stat().st_size, binary_bytes=binary.stat().st_size,
                                 cli_elapsed_seconds=round(elapsed, 6),
                                 peak_rss_kib=int(rss_file.read_text().strip()) if rss_file.exists() else None))
                print(f'PASS {name} {kind}', flush=True)
        # SAT is not accepted as UNSAT, independently confirmed by the solver.
        sat = OUTPUT / 'sat.cnf'
        sat.write_text('p cnf 1 1\n1 0\n', encoding='ascii')
        run([solver, '--quiet', sat], allowed=(10,))
        invalid = OUTPUT / 'invalid.drat'
        invalid.write_text('0\n', encoding='ascii')
        run(moon('check', '--format', 'drat', sat, invalid), allowed=(1,))
        # Hand-authored existing fixture exercises genuine RAT, not only RUP.
        rat = OUTPUT / 'genuine-rat.lrat'
        run(moon('convert', '--from', 'drat', '--to', 'lrat', ROOT/'examples/paper.cnf', ROOT/'examples/paper.drat', rat))
        run([checker, ROOT/'examples/paper.cnf', rat])
    report = dict(pins=PINS, drat_trim_pin=DRAT_PIN, checked=rows,
                  timing_scope='Whole release CLI invocation, including Moon/Moonrun startup; GNU time maximum RSS in KiB where available. Not pure algorithm time or storage.')
    (OUTPUT/'report.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(f'{len(rows)} real solver proofs passed, plus truncation, SAT and genuine RAT checks.')


if __name__ == '__main__':
    main()
