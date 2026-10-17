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
  let mut literal_count = 0
  for pair in formula.literal_occurrences() {
    literal_count += pair.0 + pair.1
  }
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
  let mut literal_count = 0
  for pair in formula.literal_occurrences() {
    literal_count += pair.0 + pair.1
  }
  literal_count * 1000 / formula.variable_count()
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
  let units = formula_unit_literals(formula)
  for literal in units {
    if units.contains(-literal) {
      return true
    }
  }
  false
}
