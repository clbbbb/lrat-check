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

///|
test "converter cannot refute satisfiable small formulas checked by truth table" {
  let pool = [[1], [-1], [2], [-2], [1, 2], [-1, 2]]
  for mask in 0..<64 {
    let clauses : Array[Array[Int]] = []
    for index in 0..<pool.length() {
      if (mask & (1 << index)) != 0 {
        clauses.push(pool[index])
      }
    }
    let mut satisfiable = false
    for assignment in 0..<4 {
      let mut model = true
      for clause in clauses {
        let mut satisfied = false
        for literal in clause {
          let variable = if literal < 0 { -literal } else { literal }
          let value = (assignment & (1 << (variable - 1))) != 0
          if value == (literal > 0) {
            satisfied = true
          }
        }
        if !satisfied {
          model = false
        }
      }
      if model {
        satisfiable = true
      }
    }
    if satisfiable {
      let cnf = render_dimacs({ variable_count: 2, clauses, })
      for
        proof in [
          "0\n", "1 0\n0\n", "-1 0\n0\n", "1 2 0\n-1 0\n0\n", "3 0\n-3 0\n0\n",
        ] {
        assert_true(convert_drat(cnf, proof) is Err(_))
      }
    }
  }
}

///|
test "blocked RAT candidate emits an explicit negative antecedent" {
  let formula = parse_cnf("p cnf 2 1\n1 2 0\n").unwrap()
  let index = LiteralIndex::new(formula)
  let hints = discover_rat_hints(index, [-1, -2], { left: 100, }, 1).unwrap()
  assert_eq(hints, [-1])
  assert_true(
    verify_addition(index.clauses, index, [-1, -2], hints, 1) is Ok(true),
  )
}
