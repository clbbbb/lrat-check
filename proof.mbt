///|
priv struct RatCase {
  id : Int
  hints : Array[Int]
}

///|
fn active_clause(clauses : Map[Int, Array[Int]], id : Int) -> Array[Int]? {
  clauses.get(id)
}

///|
fn literal_value(assignment : Map[Int, Int], literal : Int) -> Int {
  let variable = if literal < 0 { -literal } else { literal }
  match assignment.get(variable) {
    None => 0
    Some(value) => if literal < 0 { -value } else { value }
  }
}

///|
/// Assign a literal false. A conflicting existing assignment makes a
/// resolvent tautological, so the caller can accept that RAT candidate.
fn assume_false(assignment : Map[Int, Int], literal : Int) -> Bool {
  let variable = if literal < 0 { -literal } else { literal }
  let desired = if literal < 0 { 1 } else { -1 }
  match assignment.get(variable) {
    Some(current) => current != desired
    None => {
      assignment[variable] = desired
      false
    }
  }
}

///|
/// Each positive hint must be unit under prior assignments, or the final
/// conflict clause. Merely naming arbitrary clauses cannot certify a proof.
fn follow_hints(
  clauses : Map[Int, Array[Int]],
  assignment : Map[Int, Int],
  hints : Array[Int],
  line : Int,
) -> Result[Bool, CheckError] {
  for id in hints {
    let clause = match active_clause(clauses, id) {
      Some(value) => value
      None => return Err(BadHint(line, id))
    }
    let mut unknown = 0
    let mut remaining = 0
    for literal in clause {
      let value = literal_value(assignment, literal)
      if value > 0 {
        return Err(BadHint(line, id))
      }
      if value == 0 {
        unknown += 1
        remaining = literal
      }
    }
    if unknown == 0 {
      return Ok(true)
    }
    if unknown != 1 {
      return Err(BadHint(line, id))
    }
    ignore(assume_false(assignment, -remaining))
  }
  Ok(false)
}

///|
fn verify_addition(
  clauses : Map[Int, Array[Int]],
  index : LiteralIndex,
  clause : Array[Int],
  hints : Array[Int],
  line : Int,
) -> Result[Bool, CheckError] {
  let common : Array[Int] = []
  let cases : Array[RatCase] = []
  let case_ids : Map[Int, Bool] = Map([])
  let mut current = -1
  for hint in hints {
    if hint < 0 {
      let id = -hint
      if id <= current || active_clause(clauses, id) is None {
        return Err(BadHint(line, id))
      }
      cases.push({ id, hints: [], })
      case_ids[id] = true
      current = id
    } else if hint > 0 {
      if cases.length() == 0 {
        common.push(hint)
      } else {
        cases[cases.length() - 1].hints.push(hint)
      }
    } else {
      return Err(BadProof(line))
    }
  }
  let base : Map[Int, Int] = Map([])
  for literal in clause {
    if assume_false(base, literal) {
      return Err(BadProof(line))
    }
  }
  let at = match follow_hints(clauses, base, common, line) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  if at {
    return Ok(false)
  }
  if clause.length() == 0 {
    return Err(BadProof(line))
  }
  let pivot = clause[0]
  for candidate in cases {
    let other = match active_clause(clauses, candidate.id) {
      Some(value) => value
      None => return Err(BadHint(line, candidate.id))
    }
    if !has_literal(other, -pivot) {
      return Err(BadHint(line, candidate.id))
    }
    let assignment : Map[Int, Int] = Map([])
    for literal in clause {
      ignore(assume_false(assignment, literal))
    }
    let mut tautological = false
    for literal in other {
      if literal != -pivot && assume_false(assignment, literal) {
        tautological = true
      }
    }
    if !tautological {
      let common_conflict = match
        follow_hints(clauses, assignment, common, line) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      let conflict = if common_conflict {
        true
      } else {
        match follow_hints(clauses, assignment, candidate.hints, line) {
          Ok(value) => value
          Err(error) => return Err(error)
        }
      }
      if !conflict {
        return Err(BadHint(line, candidate.id))
      }
    }
  }
  // Only clauses containing the complementary pivot can falsify this RAT
  // resolvent. The index keeps this completeness check proportional to that
  // set rather than the entire proof history.
  for id in index.ids_for(-pivot) {
    // A hash lookup avoids comparing every required clause with every listed
    // RAT case when a pivot occurs in many active clauses.
    if !case_ids.contains(id) {
      return Err(BadHint(line, id))
    }
  }
  Ok(true)
}

///|
/// Verify a textual LRAT proof against an already parsed formula.
/// A proof succeeds only after a valid empty clause has been added.
pub fn verify_formula(
  formula : Formula,
  proof : String,
) -> Result[CheckStats, CheckError] {
  match formula.validate() {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  let clauses : Map[Int, Array[Int]] = Map([])
  let literal_index = LiteralIndex::new(formula)
  let mut initial_empty = false
  for position in 0..<formula.clauses.length() {
    let id = position + 1
    let clause = formula.clauses[position]
    clauses[id] = clause
    if clause.length() == 0 {
      initial_empty = true
    }
  }
  let mut last_id = formula.clauses.length()
  let mut previous_record_id = last_id
  let mut additions = 0
  let mut deletions = 0
  let mut rat_additions = 0
  let mut found_empty = initial_empty
  for line in source_lines(proof) {
    if line.words.length() == 0 || line.words[0] == "c" {
      continue
    }
    if line.words.length() < 3 {
      return Err(BadProof(line.number))
    }
    let id = match decimal(line.words[0], line.number) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    if id <= 0 || id < previous_record_id || id < last_id {
      return Err(BadProof(line.number))
    }
    previous_record_id = id
    if line.words[1] == "d" {
      if line.words[line.words.length() - 1] != "0" {
        return Err(BadProof(line.number))
      }
      for index in 2..<(line.words.length() - 1) {
        let deleted = match decimal(line.words[index], line.number) {
          Ok(value) => value
          Err(error) => return Err(error)
        }
        if deleted <= 0 || active_clause(clauses, deleted) is None {
          return Err(BadProof(line.number))
        }
        clauses.remove(deleted)
        ignore(literal_index.remove(deleted))
        deletions += 1
      }
      continue
    }
    if id <= last_id {
      return Err(BadProof(line.number))
    }
    let clause : Array[Int] = []
    let seen : Map[Int, Bool] = Map([])
    let hints : Array[Int] = []
    let mut separator = false
    let mut ended = false
    for index in 1..<line.words.length() {
      let value = match decimal(line.words[index], line.number) {
        Ok(number) => number
        Err(error) => return Err(error)
      }
      if value == 0 {
        if !separator {
          separator = true
        } else if index == line.words.length() - 1 {
          ended = true
        } else {
          return Err(BadProof(line.number))
        }
      } else if !separator {
        if value == -2147483647 - 1 ||
          seen.contains(value) ||
          seen.contains(-value) {
          return Err(BadProof(line.number))
        }
        clause.push(value)
        seen[value] = true
      } else {
        hints.push(value)
      }
    }
    if !ended {
      return Err(BadProof(line.number))
    }
    let rat = match
      verify_addition(clauses, literal_index, clause, hints, line.number) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    if rat {
      rat_additions += 1
    }
    clauses[id] = clause
    ignore(literal_index.insert(id, clause))
    last_id = id
    additions += 1
    if clause.length() == 0 {
      found_empty = true
    }
  }
  if !found_empty {
    return Err(MissingEmptyClause)
  }
  Ok({
    initial_clauses: formula.clauses.length(),
    additions,
    deletions,
    rat_additions,
  })
}

///|
pub fn verify(cnf : String, proof : String) -> Result[CheckStats, CheckError] {
  match parse_cnf(cnf) {
    Ok(formula) => verify_formula(formula, proof)
    Err(error) => Err(error)
  }
}
