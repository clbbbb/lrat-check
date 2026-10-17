///|
/// Diagnostic categories are stable enough for command-line consumers.
pub(all) enum DiagnosticKind {
  MissingClause
  DeletedBeforeUse
  NonMonotonicId
  DuplicateAdditionId
  EmptyProof
  NoEmptyAddition
  ExcessiveHints
}

///|
pub(all) struct Diagnostic {
  kind : DiagnosticKind
  line : Int
  id : Int
  message : String
}

///|
pub fn diagnose_proof(steps : Array[ProofStep]) -> Array[Diagnostic] {
  let findings : Array[Diagnostic] = []
  if steps.length() == 0 {
    findings.push({
      kind: EmptyProof,
      line: 0,
      id: 0,
      message: "proof contains no steps",
    })
    return findings
  }
  if !proof_has_empty_addition(steps) {
    findings.push({
      kind: NoEmptyAddition,
      line: steps[steps.length() - 1].line,
      id: steps[steps.length() - 1].id,
      message: "proof does not add the empty clause",
    })
  }
  let known : Map[Int, Bool] = Map([])
  let added_ids : Map[Int, Bool] = Map([])
  let mut previous_id = 0
  for step in steps {
    if step.id <= 0 || step.id < previous_id {
      findings.push({
        kind: NonMonotonicId,
        line: step.line,
        id: step.id,
        message: "step ID is lower than the preceding proof step",
      })
    }
    if step.id > previous_id {
      previous_id = step.id
    }
    if step.delete {
      for deleted in step.hints {
        if deleted >= step.id {
          findings.push({
            kind: MissingClause,
            line: step.line,
            id: deleted,
            message: "deletion references a clause that has not been added yet",
          })
        }
        known[deleted] = false
      }
    } else {
      if added_ids.contains(step.id) {
        findings.push({
          kind: DuplicateAdditionId,
          line: step.line,
          id: step.id,
          message: "addition reuses a clause ID",
        })
      }
      if step.hints.length() > 100000 {
        findings.push({
          kind: ExcessiveHints,
          line: step.line,
          id: step.id,
          message: "step contains an unusually large hint list",
        })
      }
      for hint in step.hints {
        let referenced = if hint < 0 { -hint } else { hint }
        match known.get(referenced) {
          None =>
            if referenced >= step.id {
              findings.push({
                kind: MissingClause,
                line: step.line,
                id: referenced,
                message: "hint references a clause that has not been added yet",
              })
            }
          Some(false) =>
            findings.push({
              kind: DeletedBeforeUse,
              line: step.line,
              id: referenced,
              message: "hint references a deleted clause",
            })
          Some(true) => ()
        }
      }
      known[step.id] = true
      added_ids[step.id] = true
    }
  }
  findings
}

///|
pub fn diagnostics_have_errors(findings : Array[Diagnostic]) -> Bool {
  findings.length() > 0
}

///|
pub fn diagnostic_kind_name(kind : DiagnosticKind) -> String {
  match kind {
    MissingClause => "missing-clause"
    DeletedBeforeUse => "deleted-before-use"
    NonMonotonicId => "non-monotonic-id"
    DuplicateAdditionId => "duplicate-addition-id"
    EmptyProof => "empty-proof"
    NoEmptyAddition => "no-empty-addition"
    ExcessiveHints => "excessive-hints"
  }
}

///|
pub fn diagnostic_summary(findings : Array[Diagnostic]) -> String {
  if findings.length() == 0 {
    return "no diagnostics"
  }
  let output = StringBuilder()
  for finding in findings {
    output.write_string(diagnostic_kind_name(finding.kind))
    output.write_string(" at line ")
    output.write_string(finding.line.to_string())
    output.write_string(": ")
    output.write_string(finding.message)
    output.write_char('\n')
  }
  output.to_string()
}
