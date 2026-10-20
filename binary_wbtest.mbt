///|
test "binary LRAT signed ID wire format and DRAT round trips" {
  let cnf = "p cnf 1 2\n1 0\n-1 0\n"
  let steps = parse_proof("3 0 1 2 0\n").unwrap()
  let encoded = encode_binary_lrat(steps).unwrap()
  assert_eq(encoded, b"a\x06\x00\x02\x04\x00")
  assert_eq(verify_input(cnf, encoded, LratBinary).unwrap().additions, 1)
  assert_eq(render_proof(parse_binary_lrat(encoded, 2).unwrap()), "3 0 1 2 0\n")
  let drat = encode_binary_drat(parse_drat("0\n").unwrap()).unwrap()
  assert_eq(drat, b"a\x00")
  assert_true(verify_input(cnf, drat, DratBinary) is Ok(_))
  assert_eq(convert_proof(cnf, drat, DratBinary, LratBinary).unwrap(), encoded)
}

///|
test "binary readers reject truncation overflow and noncanonical integers" {
  for
    input in [
      b"a", b"a\x80", b"x\x00", b"a\x80\x00", b"a\x01\x00", b"a\xff\xff\xff\xff\x10\x00",
    ] {
    assert_true(parse_binary_drat(input) is Err(BadBinary(_)))
    assert_true(parse_binary_lrat(input, 0) is Err(BadBinary(_)))
  }
  assert_true(parse_binary_lrat(b"d\x03\x00", 2) is Err(BadBinary(_)))
  let maximum = parse_drat("2147483647 -2147483646 0\n").unwrap()
  let decoded = parse_binary_drat(encode_binary_drat(maximum).unwrap()).unwrap()
  assert_eq(decoded[0].clause, maximum[0].clause)
}

///|
test "binary LRAT initial deletions and RAT hints preserve meaning" {
  let cnf = "p cnf 2 3\n2 0\n1 0\n-1 0\n"
  let steps = parse_proof("3 d 1 0\n4 0 2 3 0\n").unwrap()
  assert_true(
    verify_input(cnf, encode_binary_lrat(steps).unwrap(), LratBinary) is Ok(_),
  )
  let generated = convert_drat(paper_cnf(), "1 0\n2 0\n0\n").unwrap()
  let encoded = encode_binary_lrat(generated.proof).unwrap()
  assert_eq(
    verify_input(paper_cnf(), encoded, LratBinary).unwrap().rat_additions,
    1,
  )
  assert_true(
    convert_proof(cnf, b"0\n", DratText, DratText)
    is Err(UnsupportedOutputFormat),
  )
}
