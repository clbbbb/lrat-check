///|
/// A three-valued literal result used by diagnostic propagation helpers.
pub(all) enum LiteralState {
  True
  False
  Unknown
}

///|
pub fn literal_state(
  assignment : Map[Int, Bool],
  literal : Int,
) -> LiteralState {
  if literal == 0 || literal == -2147483647 - 1 {
    return Unknown
  }
  let variable = if literal < 0 { -literal } else { literal }
  match assignment.get(variable) {
    None => Unknown
    Some(value) => {
      let positive = if literal < 0 { !value } else { value }
      if positive {
        True
      } else {
        False
      }
    }
  }
}

///|
pub fn clause_state(
  assignment : Map[Int, Bool],
  clause : Array[Int],
) -> LiteralState {
  let mut unknown = false
  for literal in clause {
    match literal_state(assignment, literal) {
      True => return True
      False => ()
      Unknown => unknown = true
    }
  }
  if unknown {
    Unknown
  } else {
    False
  }
}

///|
pub fn formula_state(
  assignment : Map[Int, Bool],
  formula : Formula,
) -> LiteralState {
  let mut unknown = false
  for clause in formula.clauses {
    match clause_state(assignment, clause) {
      False => return False
      True => ()
      Unknown => unknown = true
    }
  }
  if unknown {
    Unknown
  } else {
    True
  }
}

///|
pub fn unit_literal(assignment : Map[Int, Bool], clause : Array[Int]) -> Int? {
  let mut candidate = 0
  for literal in clause {
    match literal_state(assignment, literal) {
      True => return None
      False => ()
      Unknown => {
        if candidate != 0 {
          return None
        }
        candidate = literal
      }
    }
  }
  if candidate == 0 {
    None
  } else {
    Some(candidate)
  }
}

///|
pub fn assign_literal(assignment : Map[Int, Bool], literal : Int) -> Bool {
  if literal == 0 || literal == -2147483647 - 1 {
    return false
  }
  let variable = if literal < 0 { -literal } else { literal }
  let value = literal > 0
  match assignment.get(variable) {
    None => {
      assignment[variable] = value
      true
    }
    Some(old) => old == value
  }
}

///|
/// Perform ordinary unit propagation until a fixed point. The return value is
/// false when a clause becomes contradictory.
pub fn propagate_units(assignment : Map[Int, Bool], formula : Formula) -> Bool {
  let mut changed = true
  while changed {
    changed = false
    for clause in formula.clauses {
      match unit_literal(assignment, clause) {
        None =>
          match clause_state(assignment, clause) {
            False => return false
            _ => ()
          }
        Some(literal) => {
          if !assign_literal(assignment, literal) {
            return false
          }
          changed = true
        }
      }
    }
  }
  true
}

///|
pub fn clause_is_tautology(clause : Array[Int]) -> Bool {
  let seen : Map[Int, Bool] = Map([])
  for literal in clause {
    if literal != -2147483647 - 1 && seen.contains(-literal) {
      return true
    }
    seen[literal] = true
  }
  false
}

///|
pub fn clause_variables(clause : Array[Int]) -> Array[Int] {
  let result : Array[Int] = []
  let seen : Map[Int, Bool] = Map([])
  for literal in clause {
    if literal == -2147483647 - 1 {
      continue
    }
    let variable = if literal < 0 { -literal } else { literal }
    if !seen.contains(variable) {
      result.push(variable)
      seen[variable] = true
    }
  }
  result
}

///|
pub fn formula_tautology_count(formula : Formula) -> Int {
  let mut count = 0
  for clause in formula.clauses {
    if clause_is_tautology(clause) {
      count += 1
    }
  }
  count
}

///|
pub fn formula_unit_count(formula : Formula) -> Int {
  let mut count = 0
  for clause in formula.clauses {
    if clause.length() == 1 {
      count += 1
    }
  }
  count
}

///|
pub fn formula_max_clause_size(formula : Formula) -> Int {
  let mut maximum = 0
  for clause in formula.clauses {
    if clause.length() > maximum {
      maximum = clause.length()
    }
  }
  maximum
}

///|
pub fn formula_min_clause_size(formula : Formula) -> Int {
  if formula.clauses.length() == 0 {
    return 0
  }
  let mut minimum = formula.clauses[0].length()
  for clause in formula.clauses {
    if clause.length() < minimum {
      minimum = clause.length()
    }
  }
  minimum
}
