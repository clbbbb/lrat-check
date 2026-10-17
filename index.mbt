///|
/// An inverted index from a literal to the active clause IDs containing it.
/// The index is deliberately separate from the checker so callers can reuse
/// it for proof inspection and incremental formula tools.
pub(all) struct LiteralIndex {
  by_literal : Map[Int, Array[Int]]
  clauses : Map[Int, Array[Int]]
}

///|
pub fn LiteralIndex::new(formula : Formula) -> LiteralIndex {
  let index : LiteralIndex = { by_literal: Map([]), clauses: Map([]), }
  for position in 0..<formula.clauses.length() {
    ignore(index.insert(position + 1, formula.clauses[position]))
  }
  index
}

///|
pub fn LiteralIndex::insert(
  self : LiteralIndex,
  id : Int,
  clause : Array[Int],
) -> Bool {
  if id <= 0 || self.clauses.contains(id) {
    return false
  }
  self.clauses[id] = clause.copy()
  for literal in clause {
    let ids = match self.by_literal.get(literal) {
      Some(value) => value
      None => []
    }
    if !ids.contains(id) {
      ids.push(id)
    }
    self.by_literal[literal] = ids
  }
  true
}

///|
pub fn LiteralIndex::remove(self : LiteralIndex, id : Int) -> Bool {
  let clause = match self.clauses.get(id) {
    Some(value) => value
    None => return false
  }
  self.clauses.remove(id)
  for literal in clause {
    match self.by_literal.get(literal) {
      Some(ids) => {
        let filtered : Array[Int] = []
        for current in ids {
          if current != id {
            filtered.push(current)
          }
        }
        if filtered.length() == 0 {
          self.by_literal.remove(literal)
        } else {
          self.by_literal[literal] = filtered
        }
      }
      None => ()
    }
  }
  true
}

///|
pub fn LiteralIndex::contains_id(self : LiteralIndex, id : Int) -> Bool {
  self.clauses.contains(id)
}

///|
pub fn LiteralIndex::clause(self : LiteralIndex, id : Int) -> Array[Int]? {
  self.clauses.get(id)
}

///|
pub fn LiteralIndex::ids_for(self : LiteralIndex, literal : Int) -> Array[Int] {
  match self.by_literal.get(literal) {
    Some(ids) => ids.copy()
    None => []
  }
}

///|
pub fn LiteralIndex::size(self : LiteralIndex) -> Int {
  self.clauses.length()
}

///|
pub fn LiteralIndex::literal_count(self : LiteralIndex) -> Int {
  self.by_literal.length()
}

///|
pub fn LiteralIndex::validate(self : LiteralIndex) -> Bool {
  for entry in self.clauses.iter() {
    let id = entry.0
    let clause = entry.1
    for literal in clause {
      let ids = match self.by_literal.get(literal) {
        Some(value) => value
        None => return false
      }
      if !ids.contains(id) {
        return false
      }
    }
  }
  for entry in self.by_literal.iter() {
    let literal = entry.0
    for id in entry.1 {
      let clause = match self.clauses.get(id) {
        Some(value) => value
        None => return false
      }
      if !has_literal(clause, literal) {
        return false
      }
    }
  }
  true
}

///|
/// Return active clause IDs that need RAT checking for a pivot.
pub fn rat_candidates(index : LiteralIndex, pivot : Int) -> Array[Int] {
  index.ids_for(-pivot)
}

///|
pub fn index_clause_count(index : LiteralIndex) -> Int {
  index.size()
}

///|
pub fn index_literal_count(index : LiteralIndex) -> Int {
  index.literal_count()
}
