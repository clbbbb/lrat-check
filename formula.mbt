///|
/// Read strict DIMACS CNF. Clause literals can span lines; comments and the
/// header occupy complete lines. Original clause IDs are 1 through M.
pub fn parse_cnf(input : String) -> Result[Formula, CheckError] {
  let mut declared_vars = -1
  let mut declared_clauses = -1
  let clauses : Array[Array[Int]] = []
  let clause : Array[Int] = []
  let mut seen : Map[Int, Bool] = Map([])
  let mut final_line = 1
  for line in source_lines(input) {
    final_line = line.number
    if line.words.length() == 0 || line.words[0] == "c" {
      continue
    }
    if line.words[0] == "p" {
      if declared_vars >= 0 ||
        line.words.length() != 4 ||
        line.words[1] != "cnf" {
        return Err(BadCnf(line.number))
      }
      declared_vars = match decimal(line.words[2], line.number) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      declared_clauses = match decimal(line.words[3], line.number) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      if declared_vars < 0 || declared_clauses < 0 {
        return Err(BadCnf(line.number))
      }
      continue
    }
    if declared_vars < 0 {
      return Err(BadCnf(line.number))
    }
    for word in line.words {
      let literal = match decimal(word, line.number) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      if literal == 0 {
        clauses.push(clause.copy())
        clause.clear()
        seen = Map([])
        if clauses.length() > declared_clauses {
          return Err(BadCnf(line.number))
        }
      } else {
        if literal == -2147483647 - 1 ||
          literal > declared_vars ||
          -literal > declared_vars ||
          seen.contains(literal) ||
          seen.contains(-literal) {
          return Err(BadCnf(line.number))
        }
        clause.push(literal)
        seen[literal] = true
      }
    }
  }
  if declared_vars < 0 ||
    clauses.length() != declared_clauses ||
    clause.length() > 0 {
    return Err(BadCnf(final_line))
  }
  Ok({ variable_count: declared_vars, clauses, })
}
