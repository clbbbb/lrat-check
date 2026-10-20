# LratCheck

MoonBit library and CLI for checking SAT unsatisfiability certificates and
producing hinted LRAT certificates from DRAT proofs. The checker and DRAT
conversion engine are implemented in MoonBit; external SAT solvers and checkers
are used for integration testing, not as runtime dependencies.

## Formats and commands

| Format | Check input | Convert to textual/binary LRAT |
| --- | --- | --- |
| Text LRAT | yes | yes |
| Binary LRAT (CaDiCaL >=1.9.0 signed IDs) | yes | yes |
| Text DRAT, including genuine RAT | yes | yes |
| Binary DRAT | yes | yes |

```sh
moon update
moon check --deny-warn
moon test --deny-warn
moon build --release --deny-warn
moon run cmd/main -- check --format drat examples/paper.cnf examples/paper.drat
moon run cmd/main -- convert --from drat --to lrat-binary examples/paper.cnf examples/paper.drat _build/proof.clrat
moon run cmd/main -- check --format lrat-binary examples/paper.cnf _build/proof.clrat
moon run cmd/main -- convert --from lrat-binary --to lrat examples/paper.cnf _build/proof.clrat _build/proof.lrat
```

Formats must be selected explicitly: `lrat`, `lrat-binary`, `drat`, `drat-binary`.
Conversions verify the CNF/proof before writing the output. The original
`<CNF> <LRAT>`, `--audit`, `--lifetimes`, and `--convert-drat` commands remain.
Audits, slices and lifetime reports inspect structure and do not certify UNSAT.
The CLI exits 0 on verified UNSAT, 1 on a rejected proof, 2 on invocation/I/O
errors, and 3 on the DRAT conversion work limit.

## MoonBit API

```moonbit
import {
  "clbbbb/lrat-check" @lrat,
}

let result = @lrat.verify_input(cnf_text, proof_bytes, @lrat.DratBinary)
let output = @lrat.convert_proof(cnf_text, proof_bytes, @lrat.DratBinary, @lrat.LratText)
```

The existing `verify(cnf, textual_lrat)` API remains available. `process_proof`
returns the checked LRAT records, statistics and propagation work count, and
accepts `ConversionOptions` for a custom work limit and unit deletion policy.
Binary parser errors carry one-based byte offsets; textual errors carry
one-based line numbers. IDs and literal magnitudes are limited to `2147483647`;
overflow, truncated integers and unsupported binary encodings are rejected.

## Conversion semantics and limits

DRAT conversion searches for a RUP propagation trail first. When that fails,
it checks every active clause containing the complementary first literal
(the RAT pivot), constructs each resolvent, and records its propagation
reasons. The generated certificate is rechecked by the hinted LRAT checker.
Deletion lookup uses sorted clause contents without changing the RAT pivot.
Duplicate clauses retain distinct IDs, and one deletion removes one copy.
Missing DRAT deletions are ignored. Unit clause deletions are ignored by
default, matching DRAT-trim; `honor_unit_deletions: true` selects actual deletion
semantics. LRAT references to absent/deleted clauses remain errors.

The occurrence-driven propagation engine initially examines active clauses,
then revisits clauses affected by falsified literals. Conversion has a default
budget of 50 million clause/literal inspections; exhaustion is a resource
result, not an UNSAT or invalidity verdict. The current API and CLI load the
proof into memory. They target small and medium proof-processing workloads;
there is no claim of streaming, competitive large-proof performance or a
formally verified implementation. FRAT, LPR, solver search from CNF alone and
parallel proof checking are outside this revision.

## Node.js and browser use

```sh
moon build --target js --release --deny-warn bindings
node scripts/test_js.mjs
python -m http.server 8765 --bind 127.0.0.1
```

Open `http://127.0.0.1:8765/web/` to use the browser example. Files are processed
locally. The compiled ESM exports `verify_json(cnfString, Uint8Array, format)`
and `convert_json(...)`, which return JSON strings. The latter includes the
checked textual certificate in its `lrat` field. Example:

```js
import { verify_json } from './_build/js/release/build/bindings/bindings.js';
const result = JSON.parse(verify_json(cnf, proofBytes, 'drat-binary'));
```

CI runs default Wasm tests, JavaScript tests, exported API smoke tests and a
binary CLI conversion on both Windows and Linux. The same I/O-free checking
core can be imported by MoonBit Wasm programs; `moon test --target wasm-gc`
checks that backend too. The browser example is provided for manual testing;
Node binding tests do not by themselves establish browser UI compatibility.

## Independent interoperability

```sh
bash scripts/cross_check_lrat.sh
# Linux: requires gcc, make, Python >=3.12 and network access for pinned sources.
python3 scripts/solver_interop.py
```

The first script checks existing positive/negative fixtures and a generated
RAT certificate with the independent C checker. The integration script builds
immutable pinned revisions of CaDiCaL, drat-trim and lrat-trim in a temporary
directory. Original generators create pigeonhole, odd-cycle coloring and
assignment-exclusion CNFs. It exercises 36 real solver proofs in four formats,
checks generated text with the full RAT C checker, and independently decodes
our binary output through lrat-trim before rechecking it. lrat-trim does not
semantically check general negative RAT antecedents, so its decoder/trimmer
and the full RAT checker are used together. SAT and truncated-proof negatives
are included. See the `solver-interop` CI artifact for proof files, sizes,
whole-CLI timing, optional GNU time peak RSS and `report.json`.

## Provenance and release status

The MoonBit implementation is original, Apache-2.0 licensed. Formats and
algorithms follow [Efficient Certified RAT Verification](https://arxiv.org/abs/1612.02353)
and the [DRAT format](https://github.com/marijnheule/drat-trim).
`examples/paper.cnf` and `paper.lrat` derive from the LRAT paper's mathematical
example; `paper.drat` expresses a derivation on that same formula. No upstream
checker or solver source is included. Reference tools:
[CaDiCaL](https://github.com/arminbiere/cadical),
[drat-trim](https://github.com/marijnheule/drat-trim), and
[lrat-trim](https://github.com/arminbiere/lrat-trim); their sources retain their
upstream licenses in the temporary build directories. Pins are recorded in
`scripts/solver_interop.py` and `scripts/cross_check_lrat.sh`.

The public module is `clbbbb/lrat-check`. The DRAT/binary/multi-platform changes
are currently on GitHub and are not part of the previously published `0.1.0`
Mooncakes package. See [review response](docs/review-response.md) for the scope
of this revision and the remaining release steps.
