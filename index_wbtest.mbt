///|
test "literal index tracks additions and deletions" {
  let formula = parse_cnf("p cnf 3 2\n1 -2 0\n2 3 0\n").unwrap()
  let index = LiteralIndex::new(formula)
  assert_eq(index_clause_count(index), 2)
  assert_eq(index_literal_count(index), 4)
  assert_true(index.validate())
  assert_eq(index.ids_for(2), [2])
  assert_eq(index.ids_for(-2), [1])
  assert_true(index.insert(8, [-1, 3]))
  assert_true(index.validate())
  assert_eq(index.ids_for(3), [2, 8])
  assert_eq(rat_candidates(index, 1), [8])
  assert_true(index.remove(1))
  assert_true(!index.contains_id(1))
  assert_true(index.validate())
  assert_eq(index.ids_for(-2), [])
}

///|
test "index rejects duplicate IDs and unknown removals" {
  let formula = parse_cnf("p cnf 1 1\n1 0\n").unwrap()
  let index = LiteralIndex::new(formula)
  assert_true(!index.insert(1, [-1]))
  assert_true(!index.remove(42))
  assert_true(!index.insert(0, [1]))
  assert_true(index.validate())
}
