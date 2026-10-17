///|
/// Errors produced while replaying the structural lifetime of a proof.
pub(all) enum ReplayError {
  InvalidFormula
  InvalidProof
  NonMonotonicId(Int)
  DuplicateClause(Int)
  UnknownDeletion(Int)
  InvalidLiteral(Int, Int)
  InvalidClause(Int)
  MissingFinalEmptyClause
}

///|
pub(all) struct ReplayResult {
  final_empty : Bool
  additions : Int
  deletions : Int
  active_clauses : Int
}

///|
fn valid_literal(variable_count : Int, literal : Int) -> Bool {
  literal != 0 &&
  literal != -2147483647 - 1 &&
  literal <= variable_count &&
  -literal <= variable_count
}

///|
/// Replay additions and deletions without checking RAT hints. This is useful
/// for separating lifetime/format errors from semantic proof errors.
pub fn replay_structure(
  formula : Formula,
  steps : Array[ProofStep],
) -> Result[ReplayResult, ReplayError] {
  if formula.validate() is Err(_) {
    return Err(InvalidFormula)
  }
  let session = ProofSession::from_formula(formula)
  let mut previous = formula.clauses.length()
  let mut final_empty = formula.contains_empty_clause()
  for step in steps {
    if step.id <= 0 {
      return Err(InvalidProof)
    }
    if step.id < previous {
      return Err(NonMonotonicId(step.id))
    }
    if step.delete {
      if step.id > previous {
        previous = step.id
      }
      for id in step.hints {
        if !session.delete_clause(id) {
          return Err(UnknownDeletion(id))
        }
      }
      continue
    }
    if step.id <= previous {
      return Err(NonMonotonicId(step.id))
    }
    previous = step.id
    if session.has_clause(step.id) {
      return Err(DuplicateClause(step.id))
    }
    let seen : Map[Int, Bool] = Map([])
    for literal in step.clause {
      if !valid_literal(formula.variable_count, literal) {
        return Err(InvalidLiteral(step.line, literal))
      }
      if seen.contains(literal) || seen.contains(-literal) {
        return Err(InvalidClause(step.line))
      }
      seen[literal] = true
    }
    if !session.add_clause_with_id(step.id, step.clause) {
      return Err(DuplicateClause(step.id))
    }
    if step.clause.length() == 0 {
      final_empty = true
    }
  }
  if !final_empty {
    return Err(MissingFinalEmptyClause)
  }
  Ok({
    final_empty,
    additions: session.addition_count(),
    deletions: session.deletion_count(),
    active_clauses: session.active_count(),
  })
}

///|
pub fn replay(
  cnf : String,
  proof : String,
) -> Result[ReplayResult, ReplayError] {
  let formula = match parse_cnf(cnf) {
    Ok(value) => value
    Err(_) => return Err(InvalidFormula)
  }
  let steps = match parse_proof(proof) {
    Ok(value) => value
    Err(_) => return Err(InvalidProof)
  }
  replay_structure(formula, steps)
}

///|
pub fn replay_error_name(error : ReplayError) -> String {
  match error {
    InvalidFormula => "invalid-formula"
    InvalidProof => "invalid-proof"
    NonMonotonicId(id) => "non-monotonic-id:" + id.to_string()
    DuplicateClause(id) => "duplicate-clause:" + id.to_string()
    UnknownDeletion(id) => "unknown-deletion:" + id.to_string()
    InvalidLiteral(line, literal) =>
      "invalid-literal:" + line.to_string() + ":" + literal.to_string()
    InvalidClause(line) => "invalid-clause:" + line.to_string()
    MissingFinalEmptyClause => "missing-final-empty-clause"
  }
}

///|
pub fn ReplayResult::is_unsat_certificate(self : ReplayResult) -> Bool {
  self.final_empty
}

///|
pub fn ReplayResult::active_count(self : ReplayResult) -> Int {
  self.active_clauses
}
