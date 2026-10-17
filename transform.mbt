///|
/// Return a sorted copy of a clause, preserving literal uniqueness.
pub fn normalize_clause(clause : Array[Int]) -> Array[Int] {
  let result = clause.copy()
  result.sort()
  let unique : Array[Int] = []
  for literal in result {
    if unique.length() == 0 || unique[unique.length() - 1] != literal {
      unique.push(literal)
    }
  }
  unique
}

///|
pub fn normalize_formula(formula : Formula) -> Formula {
  let clauses : Array[Array[Int]] = []
  for clause in formula.clauses {
    clauses.push(normalize_clause(clause))
  }
  { variable_count: formula.variable_count, clauses, }
}

///|
pub fn clause_equal(left : Array[Int], right : Array[Int]) -> Bool {
  let a = normalize_clause(left)
  let b = normalize_clause(right)
  if a.length() != b.length() {
    return false
  }
  for index in 0..<a.length() {
    if a[index] != b[index] {
      return false
    }
  }
  true
}

///|
pub fn clause_subset(subset : Array[Int], superset : Array[Int]) -> Bool {
  let a = normalize_clause(subset)
  let b = normalize_clause(superset)
  for literal in a {
    if !b.contains(literal) {
      return false
    }
  }
  true
}

///|
/// A clause is redundant when another clause subsumes it.
pub fn clause_subsumed(formula : Formula, target : Array[Int]) -> Bool {
  for clause in formula.clauses {
    if clause.length() < target.length() && clause_subset(clause, target) {
      return true
    }
  }
  false
}

///|
pub fn remove_duplicate_clauses(formula : Formula) -> Formula {
  let clauses : Array[Array[Int]] = []
  for clause in formula.clauses {
    let normalized = normalize_clause(clause)
    let mut seen = false
    for existing in clauses {
      if clause_equal(existing, normalized) {
        seen = true
        break
      }
    }
    if !seen {
      clauses.push(normalized)
    }
  }
  { variable_count: formula.variable_count, clauses, }
}

///|
pub fn remove_subsumed_clauses(formula : Formula) -> Formula {
  let clauses : Array[Array[Int]] = []
  for index in 0..<formula.clauses.length() {
    let target = formula.clauses[index]
    let mut redundant = false
    for other_index in 0..<formula.clauses.length() {
      if index != other_index {
        let other = formula.clauses[other_index]
        if other.length() < target.length() && clause_subset(other, target) {
          redundant = true
          break
        }
      }
    }
    if !redundant {
      clauses.push(normalize_clause(target))
    }
  }
  { variable_count: formula.variable_count, clauses, }
}

///|
pub fn simplify_formula(formula : Formula) -> Formula {
  remove_subsumed_clauses(remove_duplicate_clauses(normalize_formula(formula)))
}

///|
pub fn apply_assignment(
  formula : Formula,
  assignment : Map[Int, Bool],
) -> Formula {
  let clauses : Array[Array[Int]] = []
  for clause in formula.clauses {
    let reduced : Array[Int] = []
    let mut satisfied = false
    for literal in clause {
      match literal_state(assignment, literal) {
        True => {
          satisfied = true
          break
        }
        False => ()
        Unknown => reduced.push(literal)
      }
    }
    if !satisfied {
      clauses.push(reduced)
    }
  }
  { variable_count: formula.variable_count, clauses, }
}

///|
pub fn unit_simplify(formula : Formula) -> Result[Formula, Unit] {
  let assignment : Map[Int, Bool] = Map([])
  if !propagate_units(assignment, formula) {
    return Err(())
  }
  Ok(apply_assignment(formula, assignment))
}

///|
pub fn resolve_clauses(
  left : Array[Int],
  right : Array[Int],
  pivot : Int,
) -> Array[Int]? {
  if pivot == 0 ||
    pivot == -2147483647 - 1 ||
    !has_literal(left, pivot) ||
    !has_literal(right, -pivot) {
    return None
  }
  let result : Array[Int] = []
  for literal in left {
    if literal != pivot && !result.contains(literal) {
      result.push(literal)
    }
  }
  for literal in right {
    if literal != -pivot && !result.contains(literal) {
      result.push(literal)
    }
  }
  if clause_is_tautology(result) {
    None
  } else {
    Some(normalize_clause(result))
  }
}

///|
pub fn all_resolvents(
  left : Array[Int],
  right : Array[Int],
) -> Array[Array[Int]] {
  let result : Array[Array[Int]] = []
  for literal in left {
    if has_literal(right, -literal) {
      match resolve_clauses(left, right, literal) {
        Some(clause) => {
          let mut seen = false
          for existing in result {
            if clause_equal(existing, clause) {
              seen = true
              break
            }
          }
          if !seen {
            result.push(clause)
          }
        }
        None => ()
      }
    }
  }
  result
}

///|
pub fn formula_resolvents(
  formula : Formula,
  left_id : Int,
  right_id : Int,
) -> Array[Array[Int]] {
  if left_id <= 0 ||
    right_id <= 0 ||
    left_id > formula.clause_count() ||
    right_id > formula.clause_count() {
    return []
  }
  all_resolvents(formula.clauses[left_id - 1], formula.clauses[right_id - 1])
}

///|
pub fn clause_contains_literal(clause : Array[Int], literal : Int) -> Bool {
  has_literal(clause, literal)
}

///|
pub fn formula_contains_clause(formula : Formula, target : Array[Int]) -> Bool {
  for clause in formula.clauses {
    if clause_equal(clause, target) {
      return true
    }
  }
  false
}

///|
pub fn formula_is_simplified(formula : Formula) -> Bool {
  for clause in formula.clauses {
    if clause_is_tautology(clause) || clause_subsumed(formula, clause) {
      return false
    }
    if clause.length() != normalize_clause(clause).length() {
      return false
    }
  }
  true
}
