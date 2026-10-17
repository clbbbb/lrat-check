///|
/// Limits used by callers before accepting untrusted certificates.
pub(all) struct CheckLimits {
  max_steps : Int
  max_clause_literals : Int
  max_hints_per_step : Int
  max_clause_id : Int
}

///|
pub fn CheckLimits::default() -> CheckLimits {
  {
    max_steps: 10_000_000,
    max_clause_literals: 1_000_000,
    max_hints_per_step: 10_000_000,
    max_clause_id: 2_000_000_000,
  }
}

///|
pub(all) enum LimitViolation {
  TooManySteps(Int)
  TooManyClauseLiterals(Int)
  TooManyHints(Int)
  ClauseIdTooLarge(Int)
}

///|
pub fn check_limits(
  steps : Array[ProofStep],
  limits : CheckLimits,
) -> Result[Unit, LimitViolation] {
  if steps.length() > limits.max_steps {
    return Err(TooManySteps(steps.length()))
  }
  for step in steps {
    if step.id > limits.max_clause_id {
      return Err(ClauseIdTooLarge(step.id))
    }
    if step.clause.length() > limits.max_clause_literals {
      return Err(TooManyClauseLiterals(step.line))
    }
    if step.hints.length() > limits.max_hints_per_step {
      return Err(TooManyHints(step.line))
    }
  }
  Ok(())
}

///|
pub fn limit_violation_name(violation : LimitViolation) -> String {
  match violation {
    TooManySteps(value) => "too-many-steps:" + value.to_string()
    TooManyClauseLiterals(line) =>
      "too-many-clause-literals:" + line.to_string()
    TooManyHints(line) => "too-many-hints:" + line.to_string()
    ClauseIdTooLarge(id) => "clause-id-too-large:" + id.to_string()
  }
}
