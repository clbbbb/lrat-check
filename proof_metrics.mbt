///|
/// Measurements for comparing certificates across solver versions.
pub(all) struct ProofMetrics {
  steps : Int
  additions : Int
  deletions : Int
  maximum_id : Int
  total_clause_literals : Int
  total_hints : Int
  maximum_clause_size : Int
  maximum_hint_size : Int
  empty_additions : Int
  rat_steps : Int
}

///|
pub fn measure_proof(steps : Array[ProofStep]) -> ProofMetrics {
  let mut literals = 0
  let mut hints = 0
  let mut maximum_clause = 0
  let mut maximum_hints = 0
  let mut empty = 0
  let mut rat = 0
  for step in steps {
    literals += step.clause.length()
    hints += step.hints.length()
    if step.clause.length() > maximum_clause {
      maximum_clause = step.clause.length()
    }
    if step.hints.length() > maximum_hints {
      maximum_hints = step.hints.length()
    }
    if !step.delete && step.clause.length() == 0 {
      empty += 1
    }
    if !step.delete {
      for hint in step.hints {
        if hint < 0 {
          rat += 1
          break
        }
      }
    }
  }
  {
    steps: steps.length(),
    additions: proof_additions(steps),
    deletions: proof_deletions(steps),
    maximum_id: proof_max_id(steps),
    total_clause_literals: literals,
    total_hints: hints,
    maximum_clause_size: maximum_clause,
    maximum_hint_size: maximum_hints,
    empty_additions: empty,
    rat_steps: rat,
  }
}

///|
pub fn proof_hint_density(metrics : ProofMetrics) -> Int {
  if metrics.additions == 0 {
    return 0
  }
  metrics.total_hints * 1000 / metrics.additions
}

///|
pub fn proof_clause_density(metrics : ProofMetrics) -> Int {
  if metrics.additions == 0 {
    return 0
  }
  metrics.total_clause_literals * 1000 / metrics.additions
}

///|
pub fn proof_is_minimal_shape(metrics : ProofMetrics) -> Bool {
  metrics.steps > 0 &&
  metrics.empty_additions == 1 &&
  metrics.maximum_id >= metrics.additions
}

///|
pub fn proof_metrics_summary(metrics : ProofMetrics) -> String {
  "steps=" +
  metrics.steps.to_string() +
  ", additions=" +
  metrics.additions.to_string() +
  ", deletions=" +
  metrics.deletions.to_string() +
  ", hints=" +
  metrics.total_hints.to_string() +
  ", rat=" +
  metrics.rat_steps.to_string()
}

///|
pub fn proof_has_duplicate_addition_ids(steps : Array[ProofStep]) -> Bool {
  let ids : Array[Int] = []
  for step in steps {
    if !step.delete {
      if ids.contains(step.id) {
        return true
      }
      ids.push(step.id)
    }
  }
  false
}

///|
pub fn proof_has_forward_reference(steps : Array[ProofStep]) -> Bool {
  let known : Map[Int, Bool] = Map([])
  for step in steps {
    for hint in step.hints {
      let id = if hint < 0 { -hint } else { hint }
      if !known.contains(id) {
        return true
      }
    }
    if !step.delete {
      known[step.id] = true
    }
  }
  false
}
