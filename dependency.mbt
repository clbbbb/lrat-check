///|
/// A directed dependency edge from a derived clause to a referenced clause.
pub(all) struct DependencyEdge {
  from : Int
  to : Int
  negative : Bool
}

///|
/// A compact proof dependency graph.
pub(all) struct DependencyGraph {
  edges : Array[DependencyEdge]
  nodes : Array[Int]
}

///|
pub fn build_dependency_graph(steps : Array[ProofStep]) -> DependencyGraph {
  let edges : Array[DependencyEdge] = []
  let nodes : Array[Int] = []
  for step in steps {
    if !nodes.contains(step.id) {
      nodes.push(step.id)
    }
    for hint in step.hints {
      let negative = hint < 0
      let target = if negative { -hint } else { hint }
      if !nodes.contains(target) {
        nodes.push(target)
      }
      edges.push({ from: step.id, to: target, negative, })
    }
  }
  nodes.sort()
  { edges, nodes, }
}

///|
pub fn DependencyGraph::node_count(self : DependencyGraph) -> Int {
  self.nodes.length()
}

///|
pub fn DependencyGraph::edge_count(self : DependencyGraph) -> Int {
  self.edges.length()
}

///|
pub fn DependencyGraph::outgoing(
  self : DependencyGraph,
  id : Int,
) -> Array[DependencyEdge] {
  let result : Array[DependencyEdge] = []
  for edge in self.edges {
    if edge.from == id {
      result.push(edge)
    }
  }
  result
}

///|
pub fn DependencyGraph::incoming(
  self : DependencyGraph,
  id : Int,
) -> Array[DependencyEdge] {
  let result : Array[DependencyEdge] = []
  for edge in self.edges {
    if edge.to == id {
      result.push(edge)
    }
  }
  result
}

///|
pub fn DependencyGraph::has_edge(
  self : DependencyGraph,
  from : Int,
  to : Int,
) -> Bool {
  for edge in self.edges {
    if edge.from == from && edge.to == to {
      return true
    }
  }
  false
}

///|
pub fn DependencyGraph::roots(self : DependencyGraph) -> Array[Int] {
  let result : Array[Int] = []
  for node in self.nodes {
    if self.incoming(node).length() == 0 {
      result.push(node)
    }
  }
  result
}

///|
pub fn DependencyGraph::leaves(self : DependencyGraph) -> Array[Int] {
  let result : Array[Int] = []
  for node in self.nodes {
    if self.outgoing(node).length() == 0 {
      result.push(node)
    }
  }
  result
}

///|
pub fn DependencyGraph::negative_edge_count(self : DependencyGraph) -> Int {
  let mut count = 0
  for edge in self.edges {
    if edge.negative {
      count += 1
    }
  }
  count
}

///|
pub fn dependency_depth(graph : DependencyGraph, node : Int) -> Int {
  let mut frontier : Array[Int] = [node]
  let visited : Array[Int] = [node]
  let mut depth = 0
  while frontier.length() > 0 {
    let next : Array[Int] = []
    for current in frontier {
      for edge in graph.outgoing(current) {
        if !visited.contains(edge.to) {
          visited.push(edge.to)
          next.push(edge.to)
        }
      }
    }
    if next.length() == 0 {
      break
    }
    frontier = next
    depth += 1
  }
  depth
}

///|
pub fn dependency_summary(graph : DependencyGraph) -> String {
  "nodes=" +
  graph.node_count().to_string() +
  ", edges=" +
  graph.edge_count().to_string() +
  ", negative=" +
  graph.negative_edge_count().to_string()
}
