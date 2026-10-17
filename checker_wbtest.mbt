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
  assert_true(parse_cnf("p cnf 2 1\n-2147483648 0\n") is Err(_))
}

///|
test "formula validation rejects externally constructed malformed clauses" {
  let duplicate : Formula = { variable_count: 2, clauses: [[1, 1]], }
  let complementary : Formula = { variable_count: 2, clauses: [[1, -1]], }
  let minimum_int : Formula = {
    variable_count: 2,
    clauses: [[-2147483647 - 1]],
  }
  assert_true(duplicate.validate() is Err(BadCnf(0)))
  assert_true(complementary.validate() is Err(BadCnf(0)))
  assert_true(minimum_int.validate() is Err(BadCnf(0)))
}

///|
test "proof parser rejects duplicate IDs, deletions, and integer overflow" {
  let cnf = "p cnf 1 2\n1 0\n-1 0\n"
  assert_true(verify(cnf, "3 0 1 2 0\n3 0 1 2 0\n") is Err(BadProof(2)))
  assert_true(verify(cnf, "3 d 9 0\n3 0 1 2 0\n") is Err(BadProof(1)))
  assert_true(verify(cnf, "999999999999 0 1 2 0\n") is Err(BadNumber(1)))
  assert_true(parse_proof("0 0 0\n") is Err(BadProof(1)))
  assert_true(parse_proof("1 -2147483648 0 1 0\n") is Err(_))
}

///|
test "checker rejects decreasing IDs across deletion records" {
  let cnf = "p cnf 0 2\n0\n0\n"
  let proof = "3 d 1 0\n2 d 2 0\n"
  assert_true(verify(cnf, proof) is Err(BadProof(2)))
}

///|
test "RAT coverage scales across many complementary clauses" {
  let candidate_count = 512
  let cnf = StringBuilder()
  cnf.write_string("p cnf ")
  cnf.write_string((candidate_count + 1).to_string())
  cnf.write_string(" ")
  cnf.write_string((candidate_count * 3).to_string())
  cnf.write_char('\n')
  for offset in 0..<candidate_count {
    let variable = offset + 2
    cnf.write_string(variable.to_string())
    cnf.write_string(" 0\n")
    cnf.write_string((-variable).to_string())
    cnf.write_string(" 0\n")
    cnf.write_string("-1 ")
    cnf.write_string(variable.to_string())
    cnf.write_string(" 0\n")
  }
  let addition_id = candidate_count * 3 + 1
  let proof = StringBuilder()
  proof.write_string(addition_id.to_string())
  proof.write_string(" 1 0")
  for offset in 0..<candidate_count {
    let candidate_id = offset * 3 + 3
    proof.write_string(" -")
    proof.write_string(candidate_id.to_string())
    proof.write_string(" ")
    proof.write_string((offset * 3 + 1).to_string())
    proof.write_string(" ")
    proof.write_string((offset * 3 + 2).to_string())
  }
  proof.write_string(" 0\n")
  proof.write_string((addition_id + 1).to_string())
  proof.write_string(" 0 1 2 0\n")
  match verify(cnf.to_string(), proof.to_string()) {
    Ok(stats) => assert_eq(stats.rat_additions, 1)
    Err(_) => assert_true(false)
  }
}

///|
test "long-clause parsing uses set-based duplicate detection" {
  let clause_size = 1024
  let cnf = StringBuilder()
  cnf.write_string("p cnf 1024 1\n")
  let proof = StringBuilder()
  proof.write_string("1025")
  for literal in 1..<(clause_size + 1) {
    cnf.write_string(literal.to_string())
    cnf.write_char(' ')
    proof.write_char(' ')
    proof.write_string(literal.to_string())
  }
  cnf.write_string("0\n")
  proof.write_string(" 0 0\n")
  assert_eq(
    parse_cnf(cnf.to_string()).unwrap().clauses[0].length(),
    clause_size,
  )
  assert_eq(
    parse_proof(proof.to_string()).unwrap()[0].clause.length(),
    clause_size,
  )

  let duplicate = cnf.to_string().replace(old="0\n", new="1024 0\n")
  assert_true(parse_cnf(duplicate) is Err(BadCnf(2)))
}
