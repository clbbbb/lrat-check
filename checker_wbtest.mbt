///|
fn paper_cnf() -> String {
  "p cnf 4 8\n" +
  "1 2 -3 0\n-1 -2 3 0\n2 3 -4 0\n-2 -3 4 0\n" +
  "-1 -3 -4 0\n1 3 4 0\n-1 2 4 0\n1 -2 -4 0\n"
}

///|
test "paper example validates LRAT with AT hints and deletions" {
  let proof = "9 1 2 0 1 6 3 0\n" +
    "9 d 1 0\n" +
    "10 1 3 0 9 8 6 0\n" +
    "10 d 6 0\n" +
    "11 1 0 10 9 4 8 0\n" +
    "11 d 10 9 8 0\n" +
    "12 2 0 11 7 5 3 0\n" +
    "12 d 7 3 0\n" +
    "13 0 11 12 2 4 5 0\n"
  match verify(paper_cnf(), proof) {
    Ok(stats) => {
      assert_eq(stats.initial_clauses, 8)
      assert_eq(stats.additions, 5)
      assert_eq(stats.deletions, 7)
      assert_eq(stats.rat_additions, 0)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "paper example validates a genuine RAT step" {
  let proof = "9 1 0 -2 6 8 -5 1 8 -7 6 1 0\n" +
    "9 d 8 6 1 0\n" +
    "10 2 0 9 7 5 3 0\n" +
    "10 d 7 3 0\n" +
    "11 0 9 10 2 4 5 0\n"
  match verify(paper_cnf(), proof) {
    Ok(stats) => {
      assert_eq(stats.rat_additions, 1)
      assert_eq(stats.additions, 3)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "missing RAT candidate is rejected even if named candidates pass" {
  let proof = "9 1 0 -2 6 8 -5 1 8 0\n"
  assert_true(verify(paper_cnf(), proof) is Err(BadHint(1, 7)))
}

///|
test "a fake empty-clause proof cannot certify satisfiable CNF" {
  assert_true(verify("p cnf 1 1\n1 0\n", "2 0 1 0\n") is Err(_))
  assert_true(verify("p cnf 1 0\n", "1 0 0 0\n") is Err(_))
}

///|
test "small valid refutation and wrong hint ordering" {
  let cnf = "c input\np cnf 1 2\n1 0\n-1 0\n"
  assert_true(verify(cnf, "c proof\n3 0 1 2 0\n") is Ok(_))
  assert_true(verify(paper_cnf(), "9 1 2 0 6 1 3 0\n") is Err(BadHint(1, 6)))
}

///|
test "vacuous RAT is allowed but does not itself prove UNSAT" {
  let cnf = "p cnf 2 1\n1 0\n"
  assert_true(verify(cnf, "2 2 0 0\n") is Err(MissingEmptyClause))
  assert_true(verify(cnf, "2 2 0 0\n3 0 1 0\n") is Err(_))
}

///|
test "bad DIMACS counts literals and unfinished clauses are rejected" {
  assert_true(parse_cnf("p cnf 2 1\n1 0\n2 0\n") is Err(BadCnf(3)))
  assert_true(parse_cnf("p cnf 2 1\n1\n") is Err(BadCnf(2)))
  assert_true(parse_cnf("p cnf 2 1\n1 -1 0\n") is Err(BadCnf(2)))
  assert_true(parse_cnf("p cnf 2 1\n3 0\n") is Err(BadCnf(2)))
}

///|
test "proof parser rejects duplicate IDs, deletions, and integer overflow" {
  let cnf = "p cnf 1 2\n1 0\n-1 0\n"
  assert_true(verify(cnf, "3 0 1 2 0\n3 0 1 2 0\n") is Err(BadProof(2)))
  assert_true(verify(cnf, "3 d 9 0\n3 0 1 2 0\n") is Err(BadProof(1)))
  assert_true(verify(cnf, "999999999999 0 1 2 0\n") is Err(BadNumber(1)))
}
