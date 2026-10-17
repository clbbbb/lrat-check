///|
/// Lifetime and reference counts for one clause ID in a proof trace.
pub(all) struct ClauseLifetime {
  id : Int
  initial : Bool
  added_at : Int
  deleted_at : Int?
  use_count : Int
  last_used_at : Int?
}

///|
/// Aggregate clause-lifetime measurements. Positions are proof-step indices;
/// initial clauses have `added_at == 0`.
pub(all) struct LifetimeReport {
  clauses : Array[ClauseLifetime]
  total_references : Int
  references_to_missing_ids : Int
  references_after_deletion : Int
  peak_active_clauses : Int
}

///|
/// Measure clause use and deletion across the supplied trace. This is a
/// structural profiler and intentionally does not verify LRAT hint semantics.
pub fn analyze_clause_lifetimes(
  formula : Formula,
  steps : Array[ProofStep],
) -> LifetimeReport {
  let records : Map[Int, ClauseLifetime] = Map([])
  for position in 0..<formula.clauses.length() {
    let id = position + 1
    records[id] = {
      id,
      initial: true,
      added_at: 0,
      deleted_at: None,
      use_count: 0,
      last_used_at: None,
    }
  }
  let mut references = 0
  let mut missing = 0
  let mut deleted_use = 0
  let mut peak = records.length()
  for position in 0..<steps.length() {
    let step = steps[position]
    let step_index = position + 1
    if step.delete {
      for id in step.hints {
        match records.get(id) {
          Some(record) =>
            records[id] = { ..record, deleted_at: Some(step_index), }
          None => ()
        }
      }
    } else {
      for hint in step.hints {
        let id = if hint < 0 { -hint } else { hint }
        references += 1
        match records.get(id) {
          Some(record) => {
            if record.deleted_at is Some(_) {
              deleted_use += 1
            }
            records[id] = {
              ..record,
              use_count: record.use_count + 1,
              last_used_at: Some(step_index),
            }
          }
          None => missing += 1
        }
      }
      if !records.contains(step.id) {
        records[step.id] = {
          id: step.id,
          initial: false,
          added_at: step_index,
          deleted_at: None,
          use_count: 0,
          last_used_at: None,
        }
      }
    }
    let live = active_lifetime_count(records)
    if live > peak {
      peak = live
    }
  }
  let clauses : Array[ClauseLifetime] = []
  for entry in records.iter() {
    clauses.push(entry.1)
  }
  clauses.sort_by(fn(a, b) { a.id - b.id })
  {
    clauses,
    total_references: references,
    references_to_missing_ids: missing,
    references_after_deletion: deleted_use,
    peak_active_clauses: peak,
  }
}

///|
fn active_lifetime_count(records : Map[Int, ClauseLifetime]) -> Int {
  let mut count = 0
  for entry in records.iter() {
    if entry.1.deleted_at is None {
      count += 1
    }
  }
  count
}

///|
pub fn LifetimeReport::clause(
  self : LifetimeReport,
  id : Int,
) -> ClauseLifetime? {
  for item in self.clauses {
    if item.id == id {
      return Some(item)
    }
  }
  None
}

///|
pub fn LifetimeReport::used_clause_count(self : LifetimeReport) -> Int {
  let mut count = 0
  for item in self.clauses {
    if item.use_count > 0 {
      count += 1
    }
  }
  count
}

///|
pub fn LifetimeReport::unused_clause_ids(self : LifetimeReport) -> Array[Int] {
  let result : Array[Int] = []
  for item in self.clauses {
    if item.use_count == 0 {
      result.push(item.id)
    }
  }
  result
}

///|
pub fn LifetimeReport::deleted_clause_ids(self : LifetimeReport) -> Array[Int] {
  let result : Array[Int] = []
  for item in self.clauses {
    if item.deleted_at is Some(_) {
      result.push(item.id)
    }
  }
  result
}

///|
pub fn LifetimeReport::active_clause_ids(self : LifetimeReport) -> Array[Int] {
  let result : Array[Int] = []
  for item in self.clauses {
    if item.deleted_at is None {
      result.push(item.id)
    }
  }
  result
}

///|
pub fn LifetimeReport::maximum_uses(self : LifetimeReport) -> Int {
  let mut maximum = 0
  for item in self.clauses {
    if item.use_count > maximum {
      maximum = item.use_count
    }
  }
  maximum
}

///|
pub fn LifetimeReport::most_used_clause(
  self : LifetimeReport,
) -> ClauseLifetime? {
  let mut best : ClauseLifetime? = None
  for item in self.clauses {
    match best {
      None => best = Some(item)
      Some(current) =>
        if item.use_count > current.use_count {
          best = Some(item)
        }
    }
  }
  best
}

///|
pub fn LifetimeReport::mean_uses_per_clause(self : LifetimeReport) -> Int {
  if self.clauses.length() == 0 {
    return 0
  }
  self.total_references * 1000 / self.clauses.length()
}

///|
pub fn LifetimeReport::mean_uses_per_used_clause(self : LifetimeReport) -> Int {
  let count = self.used_clause_count()
  if count == 0 {
    return 0
  }
  self.total_references * 1000 / count
}

///|
pub fn LifetimeReport::mean_lifetime_steps(
  self : LifetimeReport,
  end_step : Int,
) -> Int {
  if self.clauses.length() == 0 {
    return 0
  }
  let mut total = 0
  for item in self.clauses {
    let end = match item.deleted_at {
      Some(position) => position
      None => end_step
    }
    total += end - item.added_at
  }
  total * 1000 / self.clauses.length()
}

///|
pub fn LifetimeReport::maximum_lifetime_steps(
  self : LifetimeReport,
  end_step : Int,
) -> Int {
  let mut maximum = 0
  for item in self.clauses {
    let end = match item.deleted_at {
      Some(position) => position
      None => end_step
    }
    let duration = end - item.added_at
    if duration > maximum {
      maximum = duration
    }
  }
  maximum
}

///|
pub fn LifetimeReport::never_used_active_ids(
  self : LifetimeReport,
) -> Array[Int] {
  let result : Array[Int] = []
  for item in self.clauses {
    if item.deleted_at is None && item.use_count == 0 {
      result.push(item.id)
    }
  }
  result
}

///|
pub fn LifetimeReport::summary(self : LifetimeReport) -> String {
  "clauses=" +
  self.clauses.length().to_string() +
  ", used=" +
  self.used_clause_count().to_string() +
  ", references=" +
  self.total_references.to_string() +
  ", missing=" +
  self.references_to_missing_ids.to_string() +
  ", after-deletion=" +
  self.references_after_deletion.to_string() +
  ", peak-active=" +
  self.peak_active_clauses.to_string()
}

///|
pub fn ClauseLifetime::is_active(self : ClauseLifetime) -> Bool {
  self.deleted_at is None
}

///|
pub fn ClauseLifetime::lifetime_steps(
  self : ClauseLifetime,
  end_step : Int,
) -> Int {
  let end = match self.deleted_at {
    Some(position) => position
    None => end_step
  }
  end - self.added_at
}

///|
pub fn ClauseLifetime::was_referenced(self : ClauseLifetime) -> Bool {
  self.use_count > 0
}

///|
pub fn ClauseLifetime::is_unused(self : ClauseLifetime) -> Bool {
  self.use_count == 0
}
