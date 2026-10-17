///|
/// Diagnostic categories are stable enough for command-line consumers.
pub(all) enum DiagnosticKind {
  MissingClause
  DeletedBeforeUse
  NonMonotonicId
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
  for step in steps {
    if step.delete {
      known[step.id] = false
    } else {
      known[step.id] = true
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
            findings.push({
              kind: MissingClause,
              line: step.line,
              id: referenced,
              message: "hint references a clause not seen before",
            })
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
