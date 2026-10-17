///|
test "replay applies paper proof lifetime" {
  let formula = parse_cnf("p cnf 1 1\n1 0\n").unwrap()
  let steps = parse_proof("2 -1 0 0\n2 d 1 0\n3 0 2 0\n").unwrap()
  let result = replay_structure(formula, steps).unwrap()
  assert_true(result.is_unsat_certificate())
  assert_eq(result.additions, 2)
  assert_eq(result.deletions, 1)
  assert_eq(result.active_count(), 2)
}

///|
test "replay rejects unknown deletion and invalid literal" {
  let formula = parse_cnf("p cnf 1 1\n1 0\n").unwrap()
  let unknown = parse_proof("2 d 99 0\n").unwrap()
  assert_true(replay_structure(formula, unknown) is Err(UnknownDeletion(99)))
  let invalid = parse_proof("2 2 0 0\n").unwrap()
  assert_true(replay_structure(formula, invalid) is Err(_))
}

///|
test "replay rejects a proof without final empty clause" {
  let formula = parse_cnf("p cnf 1 1\n1 0\n").unwrap()
  let steps = parse_proof("2 -1 0 0\n").unwrap()
  assert_true(replay_structure(formula, steps) is Err(MissingFinalEmptyClause))
  assert_eq(
    replay_error_name(MissingFinalEmptyClause),
    "missing-final-empty-clause",
  )
}

///|
test "replay reports malformed input and clauses precisely" {
  assert_true(replay("bad cnf", "") is Err(InvalidFormula))
  assert_true(replay("p cnf 1 1\n1 0\n", "bad proof\n") is Err(InvalidProof))
  let formula = parse_cnf("p cnf 1 1\n1 0\n").unwrap()
  let malformed : ProofStep = {
    id: 2,
    delete: false,
    clause: [1, 1],
    hints: [],
    line: 7,
  }
  assert_true(replay_structure(formula, [malformed]) is Err(InvalidClause(7)))
}

///|
test "replay accepts empty input formula with explicit empty clause" {
  let formula = parse_cnf("p cnf 0 1\n0\n").unwrap()
  let result = replay_structure(formula, []).unwrap()
  assert_true(result.is_unsat_certificate())
  assert_eq(result.active_count(), 1)
}

///|
test "replay deletes the listed clause IDs, not the deletion record ID" {
  let formula = parse_cnf("p cnf 1 2\n1 0\n-1 0\n").unwrap()
  let steps = parse_proof("3 0 0\n3 d 1 2 0\n").unwrap()
  let result = replay_structure(formula, steps).unwrap()
  assert_eq(result.deletions, 2)
  assert_eq(result.active_count(), 1)
}
