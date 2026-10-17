///|
/// A compact, serializable summary for CI integrations.
pub(all) struct ProofSummary {
  step_count : Int
  addition_count : Int
  deletion_count : Int
  maximum_id : Int
  has_empty_addition : Bool
  rat_candidate_count : Int
  hint_count : Int
  deleted_clause_reference_count : Int
}

///|
pub fn summarize_proof(steps : Array[ProofStep]) -> ProofSummary {
  let mut rat = 0
  let mut hints = 0
  let mut deleted_references = 0
  for step in steps {
    hints += step.hints.length()
    if step.delete {
      deleted_references += step.hints.length()
    } else {
      for hint in step.hints {
        if hint < 0 {
          rat += 1
        }
      }
    }
  }
  {
    step_count: steps.length(),
    addition_count: proof_additions(steps),
    deletion_count: proof_deletions(steps),
    maximum_id: proof_max_id(steps),
    has_empty_addition: proof_has_empty_addition(steps),
    rat_candidate_count: rat,
    hint_count: hints,
    deleted_clause_reference_count: deleted_references,
  }
}

///|
/// Return IDs referenced by a proof in first-seen order. This helps a caller
/// preflight a certificate before allocating its full checking state.
pub fn referenced_clause_ids(steps : Array[ProofStep]) -> Array[Int] {
  let result : Array[Int] = []
  let seen : Map[Int, Bool] = Map([])
  for step in steps {
    if !step.delete {
      for hint in step.hints {
        let id = if hint < 0 { -hint } else { hint }
        if !seen.contains(id) {
          result.push(id)
          seen[id] = true
        }
      }
    }
  }
  result
}

///|
pub fn added_clause_ids(steps : Array[ProofStep]) -> Array[Int] {
  let result : Array[Int] = []
  for step in steps {
    if !step.delete {
      result.push(step.id)
    }
  }
  result
}

///|
pub fn deleted_clause_ids(steps : Array[ProofStep]) -> Array[Int] {
  let result : Array[Int] = []
  for step in steps {
    if step.delete {
      result.append(step.hints)
    }
  }
  result
}

///|
/// Detect a proof that mentions no hints. Such a proof can only derive the
/// empty clause from an already contradictory input formula.
pub fn is_hint_free(steps : Array[ProofStep]) -> Bool {
  for step in steps {
    if step.hints.length() > 0 {
      return false
    }
  }
  true
}
