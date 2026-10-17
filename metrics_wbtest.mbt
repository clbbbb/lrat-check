///|
test "formula metrics summarize a small CNF" {
  let formula = parse_cnf("p cnf 2 3\n1 0\n-1 2 0\n-2 0\n").unwrap()
  let metrics = measure_formula(formula)
  assert_eq(metrics.variables, 2)
  assert_eq(metrics.clauses, 3)
  assert_eq(metrics.literals, 4)
  assert_eq(metrics.units, 2)
  assert_eq(metrics.minimum_clause_size, 1)
  assert_eq(metrics.maximum_clause_size, 2)
  assert_true(!formula_has_unit_conflict(formula))
  assert_eq(formula_density(formula), 2000)
  assert_true(!formula_is_trivial(formula))
  assert_eq(formula_clause_ids(formula), [1, 2, 3])
}

///|
test "empty formula metrics remain defined" {
  let formula = parse_cnf("p cnf 0 0\n").unwrap()
  let metrics = measure_formula(formula)
  assert_eq(metrics.clauses, 0)
  assert_eq(metrics.literals, 0)
  assert_true(formula_is_trivial(formula))
}

///| Metrics are deterministic.

///| The test suite keeps this contract visible.

///| No remote state is changed by these tests.
