///|
test "proof metrics count RAT steps and densities" {
  let steps = parse_proof("9 1 0 -2 6 0\n9 d 1 0\n10 0 9 0\n").unwrap()
  let metrics = measure_proof(steps)
  assert_eq(metrics.steps, 3)
  assert_eq(metrics.additions, 2)
  assert_eq(metrics.deletions, 1)
  assert_eq(metrics.rat_steps, 1)
  assert_eq(metrics.empty_additions, 1)
  assert_eq(proof_hint_density(metrics), 2000)
  assert_true(proof_is_minimal_shape(metrics))
  assert_true(proof_metrics_summary(metrics).contains("rat=1"))
}

///|
test "proof metrics detect forward references" {
  let forward = parse_proof("9 1 0 99 0\n").unwrap()
  assert_true(proof_has_forward_reference(forward))
  assert_true(!proof_has_duplicate_addition_ids(forward))
  let normal = parse_proof("9 1 0 0\n10 0 9 0\n").unwrap()
  assert_true(!proof_has_forward_reference(normal))
}

///|
test "deletion targets are not counted as proof dependencies" {
  let steps = parse_proof("9 1 0 2 0\n10 d 2 0\n").unwrap()
  assert_eq(referenced_clause_ids(steps), [2])
  assert_eq(deleted_clause_ids(steps), [2])
}
