///|
/// Aggregate measurements used by proof dashboards and regression tests.
pub(all) struct FormulaMetrics {
  variables : Int
  clauses : Int
  literals : Int
  units : Int
  tautologies : Int
  minimum_clause_size : Int
  maximum_clause_size : Int
}

///|
pub fn measure_formula(formula : Formula) -> FormulaMetrics {
  let literal_count = formula_literal_count(formula)
  {
    variables: formula.variable_count(),
    clauses: formula.clause_count(),
    literals: literal_count,
    units: formula_unit_count(formula),
    tautologies: formula_tautology_count(formula),
    minimum_clause_size: formula_min_clause_size(formula),
    maximum_clause_size: formula_max_clause_size(formula),
  }
}

///|
pub fn formula_density(formula : Formula) -> Int {
  if formula.variable_count() == 0 {
    return 0
  }
  formula_literal_count(formula) * 1000 / formula.variable_count()
}

///|
fn formula_literal_count(formula : Formula) -> Int {
  let mut count = 0
  for clause in formula.clauses {
    count += clause.length()
  }
  count
}

///|
pub fn formula_is_trivial(formula : Formula) -> Bool {
  formula.clause_count() == 0 || formula.contains_empty_clause()
}

///|
pub fn formula_unit_literals(formula : Formula) -> Array[Int] {
  let result : Array[Int] = []
  for clause in formula.clauses {
    if clause.length() == 1 {
      result.push(clause[0])
    }
  }
  result
}

///|
pub fn formula_clause_ids(formula : Formula) -> Array[Int] {
  let result : Array[Int] = []
  for id in 1..<(formula.clause_count() + 1) {
    result.push(id)
  }
  result
}

///|
pub fn formula_has_unit_conflict(formula : Formula) -> Bool {
  let units : Map[Int, Bool] = Map([])
  for clause in formula.clauses {
    if clause.length() == 1 && clause[0] != -2147483647 - 1 {
      units[clause[0]] = true
    }
  }
  for literal in units.keys() {
    if units.contains(-literal) {
      return true
    }
  }
  false
}
