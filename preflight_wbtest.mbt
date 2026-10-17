///|
test "preflight accepts a simple backward-reference proof" {
  let steps = parse_proof("9 1 0 0\n10 0 9 0\n").unwrap()
  let report = preflight_default(steps)
  assert_true(report.is_ok())
  assert_eq(report.diagnostic_count(), 0)
  assert_true(report.summary().contains("preflight ok"))
  assert_eq(proof_reference_ratio(report, steps), 500)
}

///|
test "preflight reports forward references and combines reports" {
  let forward = parse_proof("9 1 0 99 0\n").unwrap()
  let failed = preflight_default(forward)
  assert_true(!failed.is_ok())
  assert_eq(failed.forward_references, 1)
  let empty = preflight_default([])
  assert_true(!empty.is_ok())
  let combined = combine_preflight_reports(failed, empty)
  assert_true(!combined.is_ok())
  assert_true(combined.diagnostic_count() >= 1)
}

///|
test "preflight limit errors make a report fail" {
  let steps = parse_proof("9 1 2 0 1 0\n").unwrap()
  let report = preflight_proof(steps, {
    max_steps: 1,
    max_clause_literals: 1,
    max_hints_per_step: 2,
    max_clause_id: 20,
  })
  assert_true(!report.is_ok())
  assert_true(!report.limits_checked)
}

///|
test "preflight catches reused addition IDs and forward deletions" {
  let duplicate = parse_proof("9 1 0 0\n9 0 9 0\n").unwrap()
  assert_true(!preflight_default(duplicate).is_ok())
  let deletion = parse_proof("9 d 99 0\n10 0 0\n").unwrap()
  let report = preflight_default(deletion)
  assert_true(!report.is_ok())
  assert_true(report.diagnostic_count() > 0)
}
