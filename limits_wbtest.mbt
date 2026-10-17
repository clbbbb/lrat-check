///|
test "default limits accept the paper proof" {
  let steps = parse_proof("9 1 0 1 0\n10 0 9 0\n").unwrap()
  assert_true(check_limits(steps, CheckLimits::default()) is Ok(_))
}

///|
test "custom limits reject oversized certificates" {
  let steps = parse_proof("9 1 2 3 0 1 2 3 0\n").unwrap()
  assert_true(
    check_limits(steps, {
      max_steps: 1,
      max_clause_literals: 2,
      max_hints_per_step: 8,
      max_clause_id: 20,
    })
    is Err(TooManyClauseLiterals(1)),
  )
  assert_true(
    check_limits(steps, {
      max_steps: 1,
      max_clause_literals: 4,
      max_hints_per_step: 2,
      max_clause_id: 20,
    })
    is Err(TooManyHints(1)),
  )
  assert_eq(
    limit_violation_name(ClauseIdTooLarge(42)),
    "clause-id-too-large:42",
  )
}
