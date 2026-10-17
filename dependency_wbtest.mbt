///|
test "dependency graph records positive and RAT hints" {
  let steps = parse_proof("9 1 0 -2 6 0\n10 0 9 2 0\n").unwrap()
  let graph = build_dependency_graph(steps)
  assert_eq(graph.node_count(), 4)
  assert_eq(graph.edge_count(), 4)
  assert_eq(graph.negative_edge_count(), 1)
  assert_true(graph.has_edge(9, 2))
  assert_true(graph.has_edge(10, 9))
  assert_eq(graph.outgoing(9).length(), 2)
  assert_eq(graph.incoming(9).length(), 1)
  assert_true(graph.roots().contains(10))
  assert_true(graph.leaves().contains(2))
  assert_eq(dependency_depth(graph, 10), 2)
  assert_true(dependency_summary(graph).contains("nodes=4"))
}

///|
test "empty dependency graph is well defined" {
  let graph = build_dependency_graph([])
  assert_eq(graph.node_count(), 0)
  assert_eq(graph.edge_count(), 0)
  assert_eq(graph.roots(), [])
  assert_eq(graph.leaves(), [])
  assert_eq(dependency_depth(graph, 1), 0)
}
