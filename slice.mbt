///|
/// A contiguous view of proof steps, useful for debugging a failing range.
pub(all) struct ProofSlice {
  start : Int
  stop : Int
  steps : Array[ProofStep]
}

///|
pub fn slice_proof(
  steps : Array[ProofStep],
  start : Int,
  stop : Int,
) -> ProofSlice {
  let lower = if start < 0 {
    0
  } else if start > steps.length() {
    steps.length()
  } else {
    start
  }
  let upper = if stop > steps.length() { steps.length() } else { stop }
  let result : Array[ProofStep] = []
  if lower >= upper {
    return { start: lower, stop: lower, steps: result, }
  }
  for index in lower..<upper {
    result.push(steps[index])
  }
  { start: lower, stop: upper, steps: result, }
}

///|
pub fn ProofSlice::length(self : ProofSlice) -> Int {
  self.steps.length()
}

///|
pub fn ProofSlice::is_empty(self : ProofSlice) -> Bool {
  self.steps.length() == 0
}

///|
pub fn ProofSlice::first_id(self : ProofSlice) -> Int? {
  if self.steps.length() == 0 {
    None
  } else {
    Some(self.steps[0].id)
  }
}

///|
pub fn ProofSlice::last_id(self : ProofSlice) -> Int? {
  if self.steps.length() == 0 {
    None
  } else {
    Some(self.steps[self.steps.length() - 1].id)
  }
}

///|
pub fn ProofSlice::contains_empty(self : ProofSlice) -> Bool {
  proof_has_empty_addition(self.steps)
}

///|
pub fn ProofSlice::metrics(self : ProofSlice) -> ProofMetrics {
  measure_proof(self.steps)
}

///|
pub fn ProofSlice::dependency_graph(self : ProofSlice) -> DependencyGraph {
  build_dependency_graph(self.steps)
}

///|
pub fn ProofSlice::render(self : ProofSlice) -> String {
  render_proof(self.steps)
}

///|
pub fn ProofSlice::with_limit(self : ProofSlice, limit : Int) -> ProofSlice {
  if limit >= self.steps.length() {
    return self
  }
  slice_proof(self.steps, 0, if limit < 0 { 0 } else { limit })
}

///|
pub fn ProofSlice::find_id(self : ProofSlice, id : Int) -> ProofStep? {
  for step in self.steps {
    if step.id == id {
      return Some(step)
    }
  }
  None
}

///|
pub fn ProofSlice::rat_step_count(self : ProofSlice) -> Int {
  measure_proof(self.steps).rat_steps
}

///|
pub fn ProofSlice::empty_step_count(self : ProofSlice) -> Int {
  measure_proof(self.steps).empty_additions
}

///|
pub fn ProofSlice::clause_literal_count(self : ProofSlice) -> Int {
  measure_proof(self.steps).total_clause_literals
}

///|
pub fn ProofSlice::hint_count(self : ProofSlice) -> Int {
  measure_proof(self.steps).total_hints
}

///|
pub fn split_proof(steps : Array[ProofStep], width : Int) -> Array[ProofSlice] {
  let result : Array[ProofSlice] = []
  if width <= 0 {
    return result
  }
  let mut start = 0
  while start < steps.length() {
    let remaining = steps.length() - start
    let stop = if width >= remaining { steps.length() } else { start + width }
    result.push(slice_proof(steps, start, stop))
    start = stop
  }
  result
}

///|
pub fn total_slice_steps(slices : Array[ProofSlice]) -> Int {
  let mut total = 0
  for slice in slices {
    total += slice.length()
  }
  total
}

///|
pub fn slices_have_contiguous_ranges(slices : Array[ProofSlice]) -> Bool {
  if slices.length() == 0 {
    return true
  }
  let mut expected = slices[0].start
  for slice in slices {
    if slice.start != expected {
      return false
    }
    expected = slice.stop
  }
  true
}
