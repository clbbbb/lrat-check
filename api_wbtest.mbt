///|
test "proof AST exposes stable structural statistics" {
  let proof = "9 1 2 0 1 6 3 0\n9 d 1 0\n13 0 11 12 2 4 5 0\n"
  let steps = parse_proof(proof).unwrap()
  assert_eq(steps.length(), 3)
  assert_eq(proof_additions(steps), 2)
  assert_eq(proof_deletions(steps), 1)
  assert_eq(proof_max_id(steps), 13)
  assert_true(proof_has_empty_addition(steps))
  assert_eq(steps[1].hints, [1])
  assert_true(steps[1].delete)
}

///|
test "formula utility methods describe literals and clause sizes" {
  let formula = parse_cnf("p cnf 3 3\n1 -2 0\n2 0\n-3 0\n").unwrap()
  assert_eq(formula.variable_count(), 3)
  assert_eq(formula.clause_count(), 3)
  assert_true(formula.validate() is Ok(_))
  assert_true(!formula.contains_empty_clause())
  assert_eq(formula.variables(), [1, 2, 3])
  assert_eq(formula.clause_size_histogram().get(1), Some(2))
  assert_eq(formula.clause_size_histogram().get(2), Some(1))
  assert_eq(formula.literal_occurrences()[1], (1, 0))
  assert_eq(formula.literal_occurrences()[2], (1, 1))
  assert_eq(formula.literal_occurrences()[3], (0, 1))
}

///|
test "proof AST catches malformed deletion and duplicate literals" {
  assert_true(parse_proof("3 d -4 0\n") is Err(BadProof(1)))
  assert_true(parse_proof("3 1 1 0 0\n") is Err(BadProof(1)))
  assert_true(parse_proof("3 1 -1 0 0\n") is Err(BadProof(1)))
  assert_true(parse_proof("3 1 0 1 0 4\n") is Err(BadProof(1)))
}
