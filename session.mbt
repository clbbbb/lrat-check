///|
/// Mutable state for replaying a certificate incrementally. The session does
/// not decide whether a learned clause is sound; callers should call
/// `verify_addition` or use `verify` before committing untrusted steps.
pub(all) struct ProofSession {
  variable_count : Int
  active : Map[Int, Array[Int]]
  index : LiteralIndex
  mut next_id : Int
  mut additions : Int
  mut deletions : Int
}

///|
pub fn ProofSession::from_formula(formula : Formula) -> ProofSession {
  let active : Map[Int, Array[Int]] = Map([])
  for position in 0..<formula.clauses.length() {
    active[position + 1] = formula.clauses[position].copy()
  }
  {
    variable_count: formula.variable_count,
    active,
    index: LiteralIndex::new(formula),
    next_id: formula.clauses.length() + 1,
    additions: 0,
    deletions: 0,
  }
}

///|
pub fn ProofSession::variable_count(self : ProofSession) -> Int {
  self.variable_count
}

///|
pub fn ProofSession::active_count(self : ProofSession) -> Int {
  self.active.length()
}

///|
pub fn ProofSession::next_id(self : ProofSession) -> Int {
  self.next_id
}

///|
pub fn ProofSession::addition_count(self : ProofSession) -> Int {
  self.additions
}

///|
pub fn ProofSession::deletion_count(self : ProofSession) -> Int {
  self.deletions
}

///|
pub fn ProofSession::has_clause(self : ProofSession, id : Int) -> Bool {
  self.active.contains(id)
}

///|
pub fn ProofSession::get_clause(self : ProofSession, id : Int) -> Array[Int]? {
  match self.active.get(id) {
    Some(clause) => Some(clause.copy())
    None => None
  }
}

///|
fn ProofSession::allocate_id(self : ProofSession) -> Int {
  if self.next_id <= 0 {
    return 0
  }
  let result = self.next_id
  self.next_id = if result == 2147483647 { 0 } else { result + 1 }
  result
}

///|
pub fn ProofSession::add_clause(
  self : ProofSession,
  clause : Array[Int],
) -> Int {
  let id = self.allocate_id()
  if id == 0 {
    return 0
  }
  self.active[id] = clause.copy()
  ignore(self.index.insert(id, clause))
  self.additions += 1
  id
}

///|
pub fn ProofSession::add_clause_with_id(
  self : ProofSession,
  id : Int,
  clause : Array[Int],
) -> Bool {
  if id <= 0 ||
    self.next_id <= 0 ||
    self.active.contains(id) ||
    id < self.next_id {
    return false
  }
  self.next_id = if id == 2147483647 { 0 } else { id + 1 }
  self.active[id] = clause.copy()
  ignore(self.index.insert(id, clause))
  self.additions += 1
  true
}

///|
pub fn ProofSession::delete_clause(self : ProofSession, id : Int) -> Bool {
  if !self.active.contains(id) {
    return false
  }
  self.active.remove(id)
  ignore(self.index.remove(id))
  self.deletions += 1
  true
}

///|
pub fn ProofSession::ids_for_literal(
  self : ProofSession,
  literal : Int,
) -> Array[Int] {
  self.index.ids_for(literal)
}

///|
pub fn ProofSession::index_is_consistent(self : ProofSession) -> Bool {
  self.index.validate()
}

///|
pub fn ProofSession::active_ids(self : ProofSession) -> Array[Int] {
  let result : Array[Int] = []
  for entry in self.active.iter() {
    result.push(entry.0)
  }
  result.sort()
  result
}

///|
pub fn ProofSession::active_clauses(
  self : ProofSession,
) -> Array[(Int, Array[Int])] {
  let result : Array[(Int, Array[Int])] = []
  for entry in self.active.iter() {
    result.push((entry.0, entry.1.copy()))
  }
  result.sort_by(fn(left, right) { left.0 - right.0 })
  result
}

///|
pub fn ProofSession::contains_empty_clause(self : ProofSession) -> Bool {
  for clause in self.active.values() {
    if clause.length() == 0 {
      return true
    }
  }
  false
}

///|
pub fn ProofSession::active_literal_count(self : ProofSession) -> Int {
  let mut result = 0
  for clause in self.active.values() {
    result += clause.length()
  }
  result
}

///|
pub fn ProofSession::active_tautology_count(self : ProofSession) -> Int {
  let mut result = 0
  for clause in self.active.values() {
    if clause_is_tautology(clause) {
      result += 1
    }
  }
  result
}

///|
pub fn ProofSession::reset_counters(self : ProofSession) -> Unit {
  self.additions = 0
  self.deletions = 0
}

///|
pub fn ProofSession::snapshot(self : ProofSession) -> ProofSession {
  let active : Map[Int, Array[Int]] = Map([])
  let index : LiteralIndex = { by_literal: Map([]), clauses: Map([]), }
  for entry in self.active.iter() {
    active[entry.0] = entry.1.copy()
    ignore(index.insert(entry.0, entry.1))
  }
  {
    variable_count: self.variable_count,
    active,
    index,
    next_id: self.next_id,
    additions: self.additions,
    deletions: self.deletions,
  }
}
