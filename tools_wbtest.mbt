///|
test "formula states and unit propagation" {
  let formula = parse_cnf("p cnf 2 2\n1 2 0\n-1 0\n").unwrap()
  let assignment : Map[Int, Bool] = Map([])
  assert_true(formula_state(assignment, formula) is Unknown)
  assert_true(propagate_units(assignment, formula))
  assert_eq(assignment.get(1), Some(false))
  assert_eq(assignment.get(2), Some(true))
  assert_true(formula_state(assignment, formula) is True)
  assert_eq(clause_variables([1, -2, 2]), [1, 2])
  assert_true(clause_is_tautology([1, -2, 2]))
  assert_true(!clause_is_tautology([-2147483647 - 1]))
  assert_true(literal_state(assignment, -2147483647 - 1) is Unknown)
  assert_true(!assign_literal(assignment, -2147483647 - 1))
}

///|
test "formula summary counts units and clause sizes" {
  let formula = parse_cnf("p cnf 3 3\n1 0\n-2 3 0\n-3 0\n").unwrap()
  assert_eq(formula_unit_count(formula), 2)
  assert_eq(formula_max_clause_size(formula), 2)
  assert_eq(formula_min_clause_size(formula), 1)
  assert_eq(formula_tautology_count(formula), 0)
}

///|
test "diagnostics identify missing and deleted references" {
  let steps = parse_proof("1 1 0 0\n1 d 1 0\n2 0 1 0\n").unwrap()
  let findings = diagnose_proof(steps)
  assert_true(findings.length() >= 1)
  assert_true(diagnostics_have_errors(findings))
  assert_true(diagnostic_summary(findings).length() > 0)
}

///|
test "deletion diagnostics use deleted IDs and preserve initial clause refs" {
  let steps = parse_proof("9 1 0 1 0\n9 d 1 0\n10 0 1 0\n").unwrap()
  let findings = diagnose_proof(steps)
  let mut found_deleted = false
  for finding in findings {
    if finding.id == 1 {
      match finding.kind {
        DeletedBeforeUse => found_deleted = true
        _ => ()
      }
    }
  }
  assert_true(found_deleted)
  assert_true(!proof_has_forward_reference(steps))
  assert_eq(referenced_clause_ids(steps), [1])
  assert_eq(deleted_clause_ids(steps), [1])
}

///|
test "proof rendering round trips parsed structure" {
  let source = "9 1 0 2 0\n10 d 9 0\n"
  let steps = parse_proof(source).unwrap()
  let rendered = render_proof(steps)
  assert_eq(rendered, "9 1 0 2 0\n10 d 9 0\n")
  let formula = parse_cnf("p cnf 1 1\n1 0\n").unwrap()
  assert_eq(render_dimacs(formula), "p cnf 1 1\n1 0\n")
}
