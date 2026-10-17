///|
/// A non-semantic preflight result for rejecting obviously malformed proofs.
pub(all) struct PreflightReport {
  ok : Bool
  diagnostics : Array[Diagnostic]
  limits_checked : Bool
  forward_references : Int
  referenced_ids : Int
}

///|
pub fn preflight_proof(
  steps : Array[ProofStep],
  limits : CheckLimits,
) -> PreflightReport {
  let diagnostics = diagnose_proof(steps)
  let limit_error = check_limits(steps, limits)
  let limits_checked = limit_error is Ok(_)
  let forward = if proof_has_forward_reference(steps) { 1 } else { 0 }
  let ids = referenced_clause_ids(steps)
  {
    ok: diagnostics.length() == 0 && limits_checked && forward == 0,
    diagnostics,
    limits_checked,
    forward_references: forward,
    referenced_ids: ids.length(),
  }
}

///|
pub fn PreflightReport::is_ok(self : PreflightReport) -> Bool {
  self.ok
}

///|
pub fn PreflightReport::diagnostic_count(self : PreflightReport) -> Int {
  self.diagnostics.length()
}

///|
pub fn PreflightReport::summary(self : PreflightReport) -> String {
  if self.ok {
    return "preflight ok; references=" + self.referenced_ids.to_string()
  }
  "preflight failed; diagnostics=" +
  self.diagnostics.length().to_string() +
  ", forward=" +
  self.forward_references.to_string()
}

///|
pub fn preflight_default(steps : Array[ProofStep]) -> PreflightReport {
  preflight_proof(steps, CheckLimits::default())
}

///|
pub fn proof_is_well_formed(steps : Array[ProofStep]) -> Bool {
  preflight_default(steps).is_ok()
}

///|
pub fn proof_reference_ratio(
  report : PreflightReport,
  steps : Array[ProofStep],
) -> Int {
  if steps.length() == 0 {
    return 0
  }
  report.referenced_ids * 1000 / steps.length()
}

///|
pub fn combine_preflight_reports(
  left : PreflightReport,
  right : PreflightReport,
) -> PreflightReport {
  let diagnostics = left.diagnostics.copy()
  diagnostics.append(right.diagnostics)
  {
    ok: left.ok && right.ok,
    diagnostics,
    limits_checked: left.limits_checked && right.limits_checked,
    forward_references: left.forward_references + right.forward_references,
    referenced_ids: left.referenced_ids + right.referenced_ids,
  }
}
