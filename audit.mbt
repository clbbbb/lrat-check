///|
/// An audit snapshot describes the proof state after a prefix of parsed proof
/// steps. It is structural: it does not claim that the hints prove each step.
pub(all) struct AuditSnapshot {
  processed_steps : Int
  additions : Int
  deletions : Int
  active_clause_ids : Array[Int]
  seen_clause_ids : Array[Int]
  empty_clause_ids : Array[Int]
  missing_references : Array[(Int, Int)]
  deleted_references : Array[(Int, Int)]
  last_step_id : Int
}

///|
/// Run a structural audit through at most `step_limit` entries. The first
/// tuple member in each reference array is the source line; the second is the
/// referenced clause ID. Initial CNF clauses use IDs 1 through M.
pub fn audit_prefix(
  formula : Formula,
  steps : Array[ProofStep],
  step_limit : Int,
) -> AuditSnapshot {
  let active : Map[Int, Array[Int]] = Map([])
  let deleted_ids : Map[Int, Bool] = Map([])
  let seen_ids : Map[Int, Bool] = Map([])
  let empty : Array[Int] = []
  for position in 0..<formula.clauses.length() {
    let id = position + 1
    let clause = formula.clauses[position].copy()
    active[id] = clause
    seen_ids[id] = true
    if clause.length() == 0 {
      empty.push(id)
    }
  }
  let missing : Array[(Int, Int)] = []
  let deleted_refs : Array[(Int, Int)] = []
  let mut additions = 0
  let mut deletions = 0
  let mut processed = 0
  let mut last_id = 0
  let limit = if step_limit < 0 {
    0
  } else if step_limit > steps.length() {
    steps.length()
  } else {
    step_limit
  }
  for position in 0..<limit {
    let step = steps[position]
    processed += 1
    last_id = step.id
    if step.delete {
      deletions += step.hints.length()
      for id in step.hints {
        ignore(active.remove(id))
        deleted_ids[id] = true
        let kept : Array[Int] = []
        for empty_id in empty {
          if empty_id != id {
            kept.push(empty_id)
          }
        }
        empty.clear()
        empty.append(kept)
      }
    } else {
      additions += 1
      for hint in step.hints {
        let id = if hint < 0 { -hint } else { hint }
        if !active.contains(id) {
          if deleted_ids.contains(id) {
            deleted_refs.push((step.line, id))
          } else {
            missing.push((step.line, id))
          }
        }
      }
      active[step.id] = step.clause.copy()
      seen_ids[step.id] = true
      deleted_ids.remove(step.id)
      if step.clause.length() == 0 && !empty.contains(step.id) {
        empty.push(step.id)
      }
    }
  }
  let ids : Array[Int] = []
  for entry in active.iter() {
    ids.push(entry.0)
  }
  ids.sort()
  let seen_clause_ids : Array[Int] = []
  for entry in seen_ids.iter() {
    seen_clause_ids.push(entry.0)
  }
  seen_clause_ids.sort()
  empty.sort()
  {
    processed_steps: processed,
    additions,
    deletions,
    active_clause_ids: ids,
    seen_clause_ids,
    empty_clause_ids: empty,
    missing_references: missing,
    deleted_references: deleted_refs,
    last_step_id: last_id,
  }
}

///|

///|
pub fn AuditSnapshot::has_reference_errors(self : AuditSnapshot) -> Bool {
  self.missing_references.length() > 0 || self.deleted_references.length() > 0
}

///|
pub fn AuditSnapshot::active_count(self : AuditSnapshot) -> Int {
  self.active_clause_ids.length()
}

///|
pub fn AuditSnapshot::empty_count(self : AuditSnapshot) -> Int {
  self.empty_clause_ids.length()
}

///|
pub fn AuditSnapshot::is_complete(
  self : AuditSnapshot,
  steps : Array[ProofStep],
) -> Bool {
  self.processed_steps == steps.length()
}

///|
pub fn AuditSnapshot::summary(self : AuditSnapshot) -> String {
  "steps=" +
  self.processed_steps.to_string() +
  ", additions=" +
  self.additions.to_string() +
  ", deletions=" +
  self.deletions.to_string() +
  ", active=" +
  self.active_count().to_string() +
  ", empty=" +
  self.empty_count().to_string() +
  ", reference-errors=" +
  (self.missing_references.length() + self.deleted_references.length()).to_string()
}

///|
pub fn AuditSnapshot::first_missing(self : AuditSnapshot) -> (Int, Int)? {
  if self.missing_references.length() == 0 {
    None
  } else {
    Some(self.missing_references[0])
  }
}

///|
pub fn AuditSnapshot::first_deleted_reference(
  self : AuditSnapshot,
) -> (Int, Int)? {
  if self.deleted_references.length() == 0 {
    None
  } else {
    Some(self.deleted_references[0])
  }
}

///|
pub fn AuditSnapshot::active_contains(self : AuditSnapshot, id : Int) -> Bool {
  self.active_clause_ids.contains(id)
}

///|
pub fn audit_all(formula : Formula, steps : Array[ProofStep]) -> AuditSnapshot {
  audit_prefix(formula, steps, steps.length())
}

///|
pub fn audit_at_line(
  formula : Formula,
  steps : Array[ProofStep],
  line : Int,
) -> AuditSnapshot {
  let mut limit = 0
  for step in steps {
    if step.line <= line {
      limit += 1
    }
  }
  audit_prefix(formula, steps, limit)
}

///|
pub fn AuditSnapshot::reference_error_count(self : AuditSnapshot) -> Int {
  self.missing_references.length() + self.deleted_references.length()
}

///|
pub fn AuditSnapshot::has_empty_clause(self : AuditSnapshot) -> Bool {
  self.empty_clause_ids.length() > 0
}

///|
pub fn AuditSnapshot::added_empty_clause(
  self : AuditSnapshot,
  id : Int,
) -> Bool {
  self.empty_clause_ids.contains(id)
}

///|
pub fn AuditSnapshot::deleted_count(self : AuditSnapshot) -> Int {
  self.deletions
}

///|
pub fn AuditSnapshot::addition_count(self : AuditSnapshot) -> Int {
  self.additions
}

///|
pub fn AuditSnapshot::processed_count(self : AuditSnapshot) -> Int {
  self.processed_steps
}

///|
pub fn AuditSnapshot::last_id(self : AuditSnapshot) -> Int {
  self.last_step_id
}

///|
pub fn AuditSnapshot::active_ids(self : AuditSnapshot) -> Array[Int] {
  self.active_clause_ids.copy()
}

///|
pub fn AuditSnapshot::empty_ids(self : AuditSnapshot) -> Array[Int] {
  self.empty_clause_ids.copy()
}

///|
pub fn AuditSnapshot::missing_ids(self : AuditSnapshot) -> Array[Int] {
  let result : Array[Int] = []
  for item in self.missing_references {
    result.push(item.1)
  }
  result
}

///|
pub fn AuditSnapshot::deleted_reference_ids(self : AuditSnapshot) -> Array[Int] {
  let result : Array[Int] = []
  for item in self.deleted_references {
    result.push(item.1)
  }
  result
}

///|
pub fn AuditSnapshot::has_missing_references(self : AuditSnapshot) -> Bool {
  self.missing_references.length() > 0
}

///|
pub fn AuditSnapshot::has_deleted_references(self : AuditSnapshot) -> Bool {
  self.deleted_references.length() > 0
}

///|
pub fn AuditSnapshot::active_id_checksum(self : AuditSnapshot) -> Int {
  let mut checksum = 0
  for id in self.active_clause_ids {
    checksum = (checksum * 31 + id) % 2147483647
  }
  checksum
}

///|
pub fn AuditSnapshot::empty_id_checksum(self : AuditSnapshot) -> Int {
  let mut checksum = 0
  for id in self.empty_clause_ids {
    checksum = (checksum * 31 + id) % 2147483647
  }
  checksum
}

///|
pub fn AuditSnapshot::has_progress(self : AuditSnapshot) -> Bool {
  self.processed_steps > 0
}

///|
pub fn AuditSnapshot::completion_ratio(
  self : AuditSnapshot,
  total : Int,
) -> Int {
  if total <= 0 {
    return 1000
  }
  self.processed_steps * 1000 / total
}

///|
pub fn AuditSnapshot::is_structurally_clean(self : AuditSnapshot) -> Bool {
  !self.has_reference_errors()
}

///|
pub fn AuditSnapshot::has_live_empty_clause(self : AuditSnapshot) -> Bool {
  for id in self.empty_clause_ids {
    if self.active_contains(id) {
      return true
    }
  }
  false
}

///|
pub fn AuditSnapshot::live_empty_ids(self : AuditSnapshot) -> Array[Int] {
  let result : Array[Int] = []
  for id in self.empty_clause_ids {
    if self.active_contains(id) {
      result.push(id)
    }
  }
  result
}

///|
pub fn AuditSnapshot::progress_text(
  self : AuditSnapshot,
  total : Int,
) -> String {
  self.processed_steps.to_string() +
  "/" +
  total.to_string() +
  " steps (" +
  self.completion_ratio(total).to_string() +
  "/1000)"
}

///|
pub fn AuditSnapshot::active_range(self : AuditSnapshot) -> (Int, Int)? {
  if self.active_clause_ids.length() == 0 {
    None
  } else {
    Some(
      (
        self.active_clause_ids[0],
        self.active_clause_ids[self.active_clause_ids.length() - 1],
      ),
    )
  }
}

///|
pub fn AuditSnapshot::is_before_start(self : AuditSnapshot) -> Bool {
  self.processed_steps == 0
}

///|
pub fn AuditSnapshot::is_after_end(self : AuditSnapshot, total : Int) -> Bool {
  self.processed_steps >= total
}

///|
pub fn AuditSnapshot::has_seen_id(self : AuditSnapshot, id : Int) -> Bool {
  self.seen_clause_ids.contains(id)
}

///|
pub fn AuditSnapshot::empty_clause_was_added(self : AuditSnapshot) -> Bool {
  self.empty_clause_ids.length() > 0
}

///|
pub fn AuditSnapshot::has_clause_lifetimes(self : AuditSnapshot) -> Bool {
  self.additions + self.deletions > 0
}

///|
pub fn AuditSnapshot::is_empty_state(self : AuditSnapshot) -> Bool {
  self.active_clause_ids.length() == 0
}

///|
pub fn AuditSnapshot::active_id_sum(self : AuditSnapshot) -> Int {
  let mut total = 0
  for id in self.active_clause_ids {
    total += id
  }
  total
}

///|
pub fn AuditSnapshot::empty_id_sum(self : AuditSnapshot) -> Int {
  let mut total = 0
  for id in self.empty_clause_ids {
    total += id
  }
  total
}

///|
pub fn AuditSnapshot::reference_lines(self : AuditSnapshot) -> Array[Int] {
  let result : Array[Int] = []
  for item in self.missing_references {
    result.push(item.0)
  }
  for item in self.deleted_references {
    result.push(item.0)
  }
  result.sort()
  result
}

///|
pub fn AuditSnapshot::references_on_line(
  self : AuditSnapshot,
  line : Int,
) -> Int {
  let mut count = 0
  for item in self.missing_references {
    if item.0 == line {
      count += 1
    }
  }
  for item in self.deleted_references {
    if item.0 == line {
      count += 1
    }
  }
  count
}

///|
pub fn AuditSnapshot::maximum_active_id(self : AuditSnapshot) -> Int {
  if self.active_clause_ids.length() == 0 {
    0
  } else {
    self.active_clause_ids[self.active_clause_ids.length() - 1]
  }
}

///|
pub fn AuditSnapshot::minimum_active_id(self : AuditSnapshot) -> Int {
  if self.active_clause_ids.length() == 0 {
    0
  } else {
    self.active_clause_ids[0]
  }
}

///|
pub fn AuditSnapshot::active_contains_all(
  self : AuditSnapshot,
  ids : Array[Int],
) -> Bool {
  for id in ids {
    if !self.active_contains(id) {
      return false
    }
  }
  true
}

///|
pub fn AuditSnapshot::active_intersection(
  self : AuditSnapshot,
  ids : Array[Int],
) -> Array[Int] {
  let result : Array[Int] = []
  for id in ids {
    if self.active_contains(id) && !result.contains(id) {
      result.push(id)
    }
  }
  result
}

///|
pub fn AuditSnapshot::active_difference(
  self : AuditSnapshot,
  ids : Array[Int],
) -> Array[Int] {
  let result : Array[Int] = []
  for id in self.active_clause_ids {
    if !ids.contains(id) {
      result.push(id)
    }
  }
  result
}

///|
pub fn AuditSnapshot::fingerprint(self : AuditSnapshot) -> String {
  self.processed_steps.to_string() +
  ":" +
  self.active_id_checksum().to_string() +
  ":" +
  self.empty_id_checksum().to_string()
}

///|
pub fn AuditSnapshot::reference_summary(self : AuditSnapshot) -> String {
  "missing=" +
  self.missing_references.length().to_string() +
  ", deleted=" +
  self.deleted_references.length().to_string()
}

///|
pub fn AuditSnapshot::has_live_empty_clause_id(
  self : AuditSnapshot,
  id : Int,
) -> Bool {
  self.active_contains(id) && self.empty_clause_ids.contains(id)
}

///|
pub fn AuditSnapshot::live_empty_count(self : AuditSnapshot) -> Int {
  self.live_empty_ids().length()
}

///|
pub fn AuditSnapshot::is_prefix_of(
  self : AuditSnapshot,
  other : AuditSnapshot,
) -> Bool {
  self.processed_steps <= other.processed_steps
}

///|
pub fn AuditSnapshot::added_since(
  self : AuditSnapshot,
  earlier : AuditSnapshot,
) -> Int {
  self.additions - earlier.additions
}

///|
pub fn AuditSnapshot::deleted_since(
  self : AuditSnapshot,
  earlier : AuditSnapshot,
) -> Int {
  self.deletions - earlier.deletions
}

///|
pub fn AuditSnapshot::active_change_count(
  self : AuditSnapshot,
  earlier : AuditSnapshot,
) -> Int {
  let mut changed = 0
  for id in self.active_clause_ids {
    if !earlier.active_contains(id) {
      changed += 1
    }
  }
  for id in earlier.active_clause_ids {
    if !self.active_contains(id) {
      changed += 1
    }
  }
  changed
}

///|
pub fn AuditSnapshot::same_active_state(
  self : AuditSnapshot,
  other : AuditSnapshot,
) -> Bool {
  self.active_clause_ids == other.active_clause_ids
}

///|
pub fn AuditSnapshot::same_empty_state(
  self : AuditSnapshot,
  other : AuditSnapshot,
) -> Bool {
  self.empty_clause_ids == other.empty_clause_ids
}

///|
pub fn AuditSnapshot::is_consistent(self : AuditSnapshot) -> Bool {
  self.active_clause_ids.length() >= self.empty_clause_ids.length()
}

///|
pub fn AuditSnapshot::has_any_activity(self : AuditSnapshot) -> Bool {
  self.additions > 0 || self.deletions > 0
}

///|
pub fn AuditSnapshot::step_kind_count(self : AuditSnapshot) -> Int {
  self.additions + self.deletions
}

///|
pub fn AuditSnapshot::active_density(self : AuditSnapshot) -> Int {
  if self.processed_steps == 0 {
    return self.active_count()
  }
  self.active_count() * 1000 / self.processed_steps
}

///|
pub fn AuditSnapshot::empty_ratio(self : AuditSnapshot) -> Int {
  if self.active_count() == 0 {
    return 0
  }
  self.live_empty_count() * 1000 / self.active_count()
}

///|
pub fn AuditSnapshot::reference_ratio(self : AuditSnapshot) -> Int {
  if self.processed_steps == 0 {
    return 0
  }
  self.reference_error_count() * 1000 / self.processed_steps
}

///|
pub fn AuditSnapshot::line_span(self : AuditSnapshot) -> (Int, Int)? {
  let lines = self.reference_lines()
  if lines.length() == 0 {
    None
  } else {
    Some((lines[0], lines[lines.length() - 1]))
  }
}

///|
pub fn AuditSnapshot::has_reference_error_on(
  self : AuditSnapshot,
  line : Int,
) -> Bool {
  self.references_on_line(line) > 0
}

///|
pub fn AuditSnapshot::all_references_resolved(self : AuditSnapshot) -> Bool {
  !self.has_reference_errors()
}

///|
pub fn AuditSnapshot::has_active_clause(self : AuditSnapshot) -> Bool {
  self.active_clause_ids.length() > 0
}

///|
pub fn AuditSnapshot::active_id_at(
  self : AuditSnapshot,
  position : Int,
) -> Int? {
  if position < 0 || position >= self.active_clause_ids.length() {
    None
  } else {
    Some(self.active_clause_ids[position])
  }
}

///|
pub fn AuditSnapshot::empty_id_at(self : AuditSnapshot, position : Int) -> Int? {
  if position < 0 || position >= self.empty_clause_ids.length() {
    None
  } else {
    Some(self.empty_clause_ids[position])
  }
}

///|
pub fn AuditSnapshot::reference_at(
  self : AuditSnapshot,
  position : Int,
) -> (Int, Int)? {
  if position < self.missing_references.length() && position >= 0 {
    return Some(self.missing_references[position])
  }
  let deleted_position = position - self.missing_references.length()
  if deleted_position >= 0 &&
    deleted_position < self.deleted_references.length() {
    return Some(self.deleted_references[deleted_position])
  }
  None
}

///|
pub fn AuditSnapshot::is_valid_limit(self : AuditSnapshot, total : Int) -> Bool {
  total >= 0 && self.processed_steps <= total
}

///|
pub fn AuditSnapshot::state_label(self : AuditSnapshot) -> String {
  if self.has_reference_errors() {
    "references-invalid"
  } else if self.has_live_empty_clause() {
    "empty-clause-live"
  } else if self.has_progress() {
    "in-progress"
  } else {
    "initial"
  }
}

///|
pub fn AuditSnapshot::is_terminal(self : AuditSnapshot, total : Int) -> Bool {
  self.processed_steps == total
}

///|
pub fn AuditSnapshot::added_clause_ids(
  self : AuditSnapshot,
  steps : Array[ProofStep],
) -> Array[Int] {
  let result : Array[Int] = []
  let limit = if self.processed_steps > steps.length() {
    steps.length()
  } else {
    self.processed_steps
  }
  for position in 0..<limit {
    if !steps[position].delete {
      result.push(steps[position].id)
    }
  }
  result
}

///|
pub fn AuditSnapshot::deleted_clause_ids(
  self : AuditSnapshot,
  steps : Array[ProofStep],
) -> Array[Int] {
  let result : Array[Int] = []
  let limit = if self.processed_steps > steps.length() {
    steps.length()
  } else {
    self.processed_steps
  }
  for position in 0..<limit {
    if steps[position].delete {
      result.append(steps[position].hints)
    }
  }
  result
}
