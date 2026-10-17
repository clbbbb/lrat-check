# LratCheck

LratCheck checks whether a textual LRAT certificate proves that a DIMACS CNF
formula is unsatisfiable. It is an independent checker, not a SAT solver. The
library is written in MoonBit; the command-line wrapper reads files and sets an
exit status suitable for CI.

## Run

```sh
moon check --deny-warn
moon test --deny-warn
moon build --release --deny-warn
moon run cmd/main -- examples/paper.cnf examples/paper.lrat
moon run cmd/main -- --audit examples/paper.cnf examples/paper.lrat
moon run cmd/main -- --lifetimes examples/paper.cnf examples/paper.lrat
```

The example is Figure 2 from the [LRAT paper](https://arxiv.org/abs/1612.02353).
It prints a `VERIFIED UNSAT` summary. The invalid example reports its bad hint
and exits with status 1.

## Checked format

The library validates DIMACS headers, variable bounds, clause counts,
duplicate/complementary literals, textual LRAT additions and deletions,
monotonic IDs, guided unit propagation, RAT candidate coverage, and derivation
of the final empty clause. Errors include a proof line and, where applicable,
the failing clause ID.

The current scope is textual LRAT. Binary LRAT, DRAT, LPR, proof generation,
and formal verification of this implementation are outside the first release.
RAT coverage uses an inverted literal index and hash membership for listed
candidate clauses, so coverage scales with the clauses containing the pivot
instead of comparing every pair of candidates. Deleted clauses are removed
from the active-clause table. DIMACS and LRAT long-clause duplicate checks use
per-clause literal sets rather than rescanning the clause for every literal.
Structural audit can inspect a proof prefix and
report active clauses, empty clauses, and missing or deleted references. An
audit does not replace semantic LRAT verification.
The lifetime report counts references per clause and measures the peak number
of active clauses; it is useful for comparing proof traces, not for validating
their derivations.

The format and algorithm follow [Efficient Certified RAT Verification](https://arxiv.org/abs/1612.02353).
The MoonBit implementation is original and Apache-2.0 licensed.

## Use as a library

Add the module with `moon add clbbbb/lrat-check`, then import the package:

```moonbit
import {
  "clbbbb/lrat-check" @lrat,
}

let result = @lrat.verify(cnf_text, proof_text)
```

`verify` returns checking statistics on success and a typed `CheckError` on
failure. The command line tool exits with status 0 for a verified proof, 1 for
an invalid certificate, and 2 for invocation or file errors.
