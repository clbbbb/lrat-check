///|
test "clause normalization and equality" {
  assert_eq(normalize_clause([3, 1, 3, -2]), [-2, 1, 3])
  assert_true(clause_equal([1, 2], [2, 1]))
  assert_true(clause_subset([1], [1, 2]))
  assert_true(!clause_subset([3], [1, 2]))
}

///|
test "duplicate and subsumed clauses are removed" {
  let formula = parse_cnf("p cnf 3 4\n1 2 0\n2 1 0\n1 0\n-3 0\n").unwrap()
  let unique = remove_duplicate_clauses(formula)
  assert_eq(unique.clause_count(), 3)
  let simplified = simplify_formula(formula)
  assert_eq(simplified.clause_count(), 2)
  assert_true(formula_is_simplified(simplified))
  let duplicates = parse_cnf("p cnf 1 2\n1 0\n1 0\n").unwrap()
  assert_true(!formula_is_simplified(duplicates))
  assert_true(formula_is_simplified(remove_duplicate_clauses(duplicates)))
}

///|
test "assignment application and unit simplification" {
  let formula = parse_cnf("p cnf 2 2\n1 2 0\n-1 0\n").unwrap()
  let assignment : Map[Int, Bool] = Map([])
  assignment[1] = false
  let projected = apply_assignment(formula, assignment)
  assert_eq(projected.clauses, [[2]])
  let simplified = unit_simplify(formula).unwrap()
  assert_eq(simplified.clauses, [])
}

///|
test "resolution generates non-tautological resolvents" {
  assert_eq(resolve_clauses([1, 2], [-1, 3], 1), Some([2, 3]))
  assert_true(resolve_clauses([1, 2], [1, 3], 1) is None)
  let all = all_resolvents([1, 2], [-1, 3])
  assert_eq(all, [[2, 3]])
}

///|
test "formula membership and resolvent lookup" {
  let formula = parse_cnf("p cnf 2 2\n1 0\n-1 2 0\n").unwrap()
  assert_true(formula_contains_clause(formula, [1]))
  assert_true(!formula_contains_clause(formula, [2]))
  assert_eq(formula_resolvents(formula, 1, 2), [[2]])
  assert_true(clause_contains_literal([1, -2], -2))
}
