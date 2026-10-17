///|
fn audit_example_cnf() -> String {
  "p cnf 4 8\n" +
  "1 2 -3 0\n-1 -2 3 0\n2 3 -4 0\n-2 -3 4 0\n" +
  "-1 -3 -4 0\n1 3 4 0\n-1 2 4 0\n1 -2 -4 0\n"
}

///|
fn audit_example_proof() -> String {
  "9 1 2 0 1 6 3 0\n" +
  "9 d 1 0\n" +
  "10 1 3 0 9 8 6 0\n" +
  "10 d 6 0\n" +
  "11 1 0 10 9 4 8 0\n" +
  "11 d 10 9 8 0\n" +
  "12 2 0 11 7 5 3 0\n" +
  "12 d 7 3 0\n" +
  "13 0 11 12 2 4 5 0\n"
}

///|
test "audit prefix reports live clauses at selected proof boundaries" {
  let formula = parse_cnf(audit_example_cnf()).unwrap()
  let steps = parse_proof(audit_example_proof()).unwrap()
  let initial = audit_prefix(formula, steps, 0)
  assert_eq(initial.processed_count(), 0)
  assert_eq(initial.active_count(), 8)
  assert_true(!initial.has_live_empty_clause())
  let after_first_deletion = audit_prefix(formula, steps, 2)
  assert_eq(after_first_deletion.addition_count(), 1)
  assert_eq(after_first_deletion.deleted_count(), 1)
  assert_true(!after_first_deletion.active_contains(1))
  assert_true(after_first_deletion.is_structurally_clean())
}

///|
test "complete audit tracks final empty clause and reference integrity" {
  let formula = parse_cnf(audit_example_cnf()).unwrap()
  let steps = parse_proof(audit_example_proof()).unwrap()
  let snapshot = audit_all(formula, steps)
  assert_true(snapshot.is_complete(steps))
  assert_eq(snapshot.addition_count(), 5)
  assert_eq(snapshot.deleted_count(), 7)
  assert_true(snapshot.has_live_empty_clause())
  assert_true(snapshot.active_contains(13))
  assert_true(snapshot.has_seen_id(1))
  assert_true(!snapshot.has_seen_id(999))
  assert_true(snapshot.all_references_resolved())
  assert_true(snapshot.active_id_at(-1) is None)
}

///|
test "audit distinguishes unknown and previously deleted hint references" {
  let formula = parse_cnf("p cnf 1 1\n1 0\n").unwrap()
  let deleted_steps = parse_proof("2 d 1 0\n3 0 1 0\n").unwrap()
  let deleted = audit_all(formula, deleted_steps)
  assert_true(deleted.has_deleted_references())
  assert_eq(deleted.first_deleted_reference(), Some((2, 1)))
  let unknown_steps = parse_proof("2 0 8 0\n").unwrap()
  let unknown = audit_all(formula, unknown_steps)
  assert_true(unknown.has_missing_references())
  assert_eq(unknown.first_missing(), Some((1, 8)))
}

///|
test "audit line selection and boundary limits are clamped" {
  let formula = parse_cnf(audit_example_cnf()).unwrap()
  let steps = parse_proof(audit_example_proof()).unwrap()
  assert_eq(audit_prefix(formula, steps, -4).processed_count(), 0)
  assert_eq(audit_prefix(formula, steps, 999).processed_count(), steps.length())
  assert_eq(audit_at_line(formula, steps, 1).processed_count(), 1)
  assert_eq(audit_at_line(formula, steps, 2).processed_count(), 2)
}

///|
test "audit snapshot comparison reports state changes" {
  let formula = parse_cnf("p cnf 1 1\n1 0\n").unwrap()
  let steps = parse_proof("2 0 1 0\n").unwrap()
  let before = audit_prefix(formula, steps, 0)
  let after = audit_all(formula, steps)
  assert_true(before.is_prefix_of(after))
  assert_eq(after.active_change_count(before), 1)
  assert_true(after.has_live_empty_clause_id(2))
  assert_eq(after.live_empty_ids(), [2])
}

///|
test "lifetime report profiles references and peak live clauses" {
  let formula = parse_cnf("p cnf 1 2\n1 0\n-1 0\n").unwrap()
  let steps = parse_proof("3 0 1 2 0\n3 d 1 0\n").unwrap()
  let report = analyze_clause_lifetimes(formula, steps)
  assert_eq(report.total_references, 2)
  assert_eq(report.used_clause_count(), 2)
  assert_eq(report.peak_active_clauses, 3)
  assert_eq(report.clause(1).unwrap().use_count, 1)
  assert_true(report.clause(3).unwrap().is_active())
  assert_eq(report.deleted_clause_ids(), [1])
}

///|
test "lifetime report flags references after deletion and missing IDs" {
  let formula = parse_cnf("p cnf 1 1\n1 0\n").unwrap()
  let steps = parse_proof("2 d 1 0\n3 0 1 9 0\n").unwrap()
  let report = analyze_clause_lifetimes(formula, steps)
  assert_eq(report.references_after_deletion, 1)
  assert_eq(report.references_to_missing_ids, 1)
  assert_eq(report.unused_clause_ids(), [3])
  assert_true(report.never_used_active_ids().contains(3))
}

///|
test "deleting the only empty clause removes it from the live state" {
  let formula = parse_cnf("p cnf 0 1\n0\n").unwrap()
  let steps = parse_proof("1 d 1 0\n").unwrap()
  let snapshot = audit_all(formula, steps)
  assert_eq(snapshot.empty_ids(), [])
  assert_true(!snapshot.has_live_empty_clause())
  assert_eq(snapshot.state_label(), "in-progress")
}

///|
test "prefix audit ignores later malformed references" {
  let formula = parse_cnf("p cnf 1 1\n1 0\n").unwrap()
  let steps = parse_proof("2 0 1 0\n3 0 99 0\n").unwrap()
  let first = audit_prefix(formula, steps, 1)
  let all = audit_prefix(formula, steps, 2)
  assert_true(first.is_structurally_clean())
  assert_eq(first.reference_error_count(), 0)
  assert_eq(all.reference_error_count(), 1)
  assert_eq(all.first_missing(), Some((2, 99)))
}

///|
test "lifetime report exposes use concentration and duration metrics" {
  let formula = parse_cnf("p cnf 1 2\n1 0\n-1 0\n").unwrap()
  let steps = parse_proof("3 0 1 2 1 0\n").unwrap()
  let report = analyze_clause_lifetimes(formula, steps)
  assert_eq(report.maximum_uses(), 2)
  assert_eq(report.most_used_clause().unwrap().id, 1)
  assert_eq(report.mean_uses_per_clause(), 1000)
  assert_eq(report.maximum_lifetime_steps(1), 1)
}

///|
test "empty formula and proof produce a zeroed lifetime report" {
  let formula = parse_cnf("p cnf 0 0\n").unwrap()
  let steps = parse_proof("").unwrap()
  let report = analyze_clause_lifetimes(formula, steps)
  assert_eq(report.clauses.length(), 0)
  assert_eq(report.total_references, 0)
  assert_eq(report.maximum_uses(), 0)
  assert_eq(report.mean_lifetime_steps(0), 0)
  assert_eq(report.mean_uses_per_used_clause(), 0)
}

///|
test "audit reports ordered active IDs and stable prefix fingerprints" {
  let formula = parse_cnf("p cnf 1 2\n1 0\n-1 0\n").unwrap()
  let steps = parse_proof("3 d 1 0\n").unwrap()
  let snapshot = audit_all(formula, steps)
  assert_eq(snapshot.active_ids(), [2])
  assert_eq(snapshot.minimum_active_id(), 2)
  assert_eq(snapshot.maximum_active_id(), 2)
  assert_eq(snapshot.active_range(), Some((2, 2)))
  assert_true(snapshot.fingerprint() != "")
}
