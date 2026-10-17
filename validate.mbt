///|
pub fn Formula::variable_count(self : Formula) -> Int {
  self.variable_count
}

///|
pub fn Formula::clause_count(self : Formula) -> Int {
  self.clauses.length()
}

///|
/// Check a formula independently of proof execution. This is useful before
/// accepting a formula from a network or a build artifact.
pub fn Formula::validate(self : Formula) -> Result[Unit, CheckError] {
  if self.variable_count < 0 {
    return Err(BadCnf(0))
  }
  for clause in self.clauses {
    let seen : Map[Int, Bool] = Map([])
    for literal in clause {
      if literal == 0 ||
        literal == -2147483647 - 1 ||
        literal > self.variable_count ||
        -literal > self.variable_count ||
        seen.contains(literal) ||
        has_literal(clause, -literal) {
        return Err(BadCnf(0))
      }
      seen[literal] = true
    }
  }
  Ok(())
}

///|
pub fn Formula::variables(self : Formula) -> Array[Int] {
  let result : Array[Int] = []
  for index in 1..<(self.variable_count + 1) {
    result.push(index)
  }
  result
}

///|
pub fn Formula::clause_size_histogram(self : Formula) -> Map[Int, Int] {
  let result : Map[Int, Int] = Map([])
  for clause in self.clauses {
    let size = clause.length()
    result[size] = match result.get(size) {
      Some(value) => value + 1
      None => 1
    }
  }
  result
}

///|
pub fn Formula::contains_empty_clause(self : Formula) -> Bool {
  for clause in self.clauses {
    if clause.length() == 0 {
      return true
    }
  }
  false
}

///|
/// Count literal occurrences. The result is indexed by variable number and
/// stores positive and negative occurrences separately.
pub fn Formula::literal_occurrences(self : Formula) -> Array[(Int, Int)] {
  let counts = Array::make(self.variable_count + 1, (0, 0))
  for clause in self.clauses {
    for literal in clause {
      let variable = if literal < 0 { -literal } else { literal }
      let (positive, negative) = counts[variable]
      if literal < 0 {
        counts[variable] = (positive, negative + 1)
      } else {
        counts[variable] = (positive + 1, negative)
      }
    }
  }
  counts
}
