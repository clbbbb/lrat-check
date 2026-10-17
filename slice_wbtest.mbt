///|
test "proof slices preserve ranges and metrics" {
  let steps = parse_proof("9 1 0 0\n10 2 0 9 0\n11 0 10 0\n").unwrap()
  let slice = slice_proof(steps, 1, 3)
  assert_eq(slice.length(), 2)
  assert_eq(slice.first_id(), Some(10))
  assert_eq(slice.last_id(), Some(11))
  assert_true(slice.contains_empty())
  assert_eq(slice.empty_step_count(), 1)
  assert_eq(slice.hint_count(), 2)
  assert_eq(slice.find_id(10).unwrap().clause, [2])
  assert_eq(slice.with_limit(1).length(), 1)
}

///|
test "proof splitting covers every step exactly once" {
  let steps = parse_proof("1 1 0 0\n2 2 0 1 0\n3 0 2 0\n4 d 1 0\n").unwrap()
  let slices = split_proof(steps, 2)
  assert_eq(slices.length(), 2)
  assert_eq(total_slice_steps(slices), 4)
  assert_true(slices_have_contiguous_ranges(slices))
  assert_eq(slices[0].first_id(), Some(1))
  assert_eq(slices[1].last_id(), Some(4))
  assert_true(split_proof(steps, 0).length() == 0)
}
