///|
test "proof session replays active clause changes" {
  let formula = parse_cnf("p cnf 3 2\n1 -2 0\n2 3 0\n").unwrap()
  let session = ProofSession::from_formula(formula)
  assert_eq(session.variable_count(), 3)
  assert_eq(session.active_count(), 2)
  assert_eq(session.next_id(), 3)
  assert_true(session.has_clause(1))
  assert_eq(session.get_clause(1), Some([1, -2]))
  let id = session.add_clause([3])
  assert_eq(id, 3)
  assert_eq(session.addition_count(), 1)
  assert_eq(session.ids_for_literal(3), [2, 3])
  assert_true(session.delete_clause(2))
  assert_eq(session.deletion_count(), 1)
  assert_true(!session.has_clause(2))
  assert_true(session.index_is_consistent())
  assert_eq(session.active_literal_count(), 3)
}

///|
test "session rejects duplicate and backward IDs" {
  let formula = parse_cnf("p cnf 1 1\n1 0\n").unwrap()
  let session = ProofSession::from_formula(formula)
  assert_true(!session.add_clause_with_id(1, [-1]))
  assert_true(!session.add_clause_with_id(1, [1]))
  assert_true(session.add_clause_with_id(8, [-1]))
  assert_true(!session.add_clause_with_id(7, [1]))
  assert_eq(session.next_id(), 9)
}

///|
test "session reports empty and tautological clauses" {
  let formula = parse_cnf("p cnf 1 1\n1 0\n").unwrap()
  let session = ProofSession::from_formula(formula)
  assert_true(!session.contains_empty_clause())
  let empty = session.add_clause([])
  assert_eq(empty, 2)
  assert_true(session.contains_empty_clause())
  let taut = session.add_clause([1, -1])
  assert_eq(taut, 3)
  assert_eq(session.active_tautology_count(), 1)
  assert_eq(session.active_literal_count(), 3)
}

///|
test "session snapshots isolate the active map" {
  let formula = parse_cnf("p cnf 2 1\n1 2 0\n").unwrap()
  let session = ProofSession::from_formula(formula)
  ignore(session.add_clause([-1]))
  let copy = session.snapshot()
  assert_eq(copy.active_count(), session.active_count())
  assert_eq(copy.next_id(), session.next_id())
  ignore(session.delete_clause(1))
  assert_true(session.active_count() != copy.active_count())
  assert_true(copy.has_clause(1))
}

///|
test "session returns sorted active IDs and clauses" {
  let formula = parse_cnf("p cnf 2 1\n1 0\n").unwrap()
  let session = ProofSession::from_formula(formula)
  assert_true(session.add_clause_with_id(8, [2]))
  assert_true(session.add_clause_with_id(12, [-2]))
  assert_eq(session.active_ids(), [1, 8, 12])
  let clauses = session.active_clauses()
  assert_eq(clauses[0], (1, [1]))
  assert_eq(clauses[2], (12, [-2]))
}

///|
test "session snapshot preserves sparse clause IDs and index entries" {
  let formula = parse_cnf("p cnf 2 1\n1 0\n").unwrap()
  let session = ProofSession::from_formula(formula)
  assert_true(session.add_clause_with_id(8, [-2]))
  assert_true(session.delete_clause(1))
  let copy = session.snapshot()
  assert_eq(copy.active_ids(), [8])
  assert_eq(copy.get_clause(8), Some([-2]))
  assert_eq(copy.ids_for_literal(-2), [8])
  assert_true(copy.index_is_consistent())
  assert_eq(copy.active_count(), 1)
}

///|
test "session ID allocation stops cleanly at integer exhaustion" {
  let formula = parse_cnf("p cnf 1 1\n1 0\n").unwrap()
  let session = ProofSession::from_formula(formula)
  assert_true(session.add_clause_with_id(2147483647, [-1]))
  assert_eq(session.next_id(), 0)
  assert_eq(session.add_clause([1]), 0)
  assert_eq(session.active_count(), 2)
  assert_true(session.index_is_consistent())
}
