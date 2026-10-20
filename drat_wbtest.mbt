///|
test "DRAT generates a recheckable LRAT proof including genuine RAT" {
  let result = convert_drat(
    paper_cnf(),
    "1 0\nd 1 2 -3 0\nd 1 3 4 0\nd 1 -2 -4 0\n2 0\n0\n",
  ).unwrap()
  assert_true(result.stats.rat_additions > 0)
  assert_eq(
    verify(paper_cnf(), render_proof(result.proof)).unwrap().additions,
    3,
  )
  assert_true(result.work > 0)
  assert_true(convert_drat("p cnf 1 1\n1 0\n", "0\n") is Err(_))
}

///|
test "DRAT duplicate deletions remove one occurrence and unit policy is explicit" {
  let cnf = "p cnf 2 4\n1 2 0\n1 2 0\n-1 0\n-2 0\n"
  let result = convert_drat(cnf, "d 2 1 0\nd 2 -1 0\n0\n").unwrap()
  assert_eq(result.stats.deletions, 1)
  let formula = parse_cnf("p cnf 1 2\n1 0\n-1 0\n").unwrap()
  let steps = parse_drat("d 1 0\n0\n").unwrap()
  assert_true(
    convert_drat_steps(formula, steps, {
      max_work: 100,
      honor_unit_deletions: true,
    })
    is Err(_),
  )
  assert_true(
    convert_drat_steps(formula, steps, default_conversion_options()) is Ok(_),
  )
  assert_true(
    convert_drat_steps(formula, steps, {
      max_work: 1,
      honor_unit_deletions: false,
    })
    is Err(ResourceLimit(_)),
  )
}

///|
test "DRAT rejects malformed clauses and preserves pivot order" {
  for proof in ["1 1 0\n", "1 -1 0\n", "d\n", "1\n", "0 2\n", "2147483648 0\n"] {
    assert_true(parse_drat(proof) is Err(_))
  }
  let steps = parse_drat("c generated here\n2 1 0\nd 1 2 0\n").unwrap()
  assert_eq(steps[0].clause, [2, 1])
  assert_eq(render_drat(steps), "2 1 0\nd 1 2 0\n")
}
