///|
/// DRAT has no clause IDs or propagation hints. The first literal remains
/// the RAT pivot; only deletion lookup uses a sorted content key.
pub(all) struct DratStep {
  delete : Bool
  clause : Array[Int]
  line : Int
}

///|
pub(all) struct ConversionOptions {
  max_work : Int
  honor_unit_deletions : Bool
}

///|
pub fn default_conversion_options() -> ConversionOptions {
  { max_work: 50000000, honor_unit_deletions: false, }
}

///|
pub(all) struct ConversionResult {
  proof : Array[ProofStep]
  stats : CheckStats
  work : Int
}

///|
priv struct ConversionBudget {
  mut left : Int
}

///|
fn spend_work(
  budget : ConversionBudget,
  line : Int,
) -> Result[Unit, CheckError] {
  if budget.left <= 0 {
    return Err(ResourceLimit(line))
  }
  budget.left -= 1
  Ok(())
}

///|
fn valid_drat_clause(clause : Array[Int]) -> Bool {
  let seen : Map[Int, Bool] = Map([])
  for literal in clause {
    if literal == 0 ||
      literal == -2147483647 - 1 ||
      seen.contains(literal) ||
      seen.contains(-literal) {
      return false
    }
    seen[literal] = true
  }
  true
}

///|
pub fn parse_drat(text : String) -> Result[Array[DratStep], CheckError] {
  let steps : Array[DratStep] = []
  for line in source_lines(text) {
    if line.words.length() == 0 || line.words[0] == "c" {
      continue
    }
    let delete = line.words[0] == "d"
    let start = if delete { 1 } else { 0 }
    let clause : Array[Int] = []
    let mut ended = false
    for index in start..<line.words.length() {
      let literal = match decimal(line.words[index], line.number) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      if literal == 0 {
        if index != line.words.length() - 1 {
          return Err(BadProof(line.number))
        }
        ended = true
      } else {
        clause.push(literal)
      }
    }
    if !ended || !valid_drat_clause(clause) {
      return Err(BadProof(line.number))
    }
    steps.push({ delete, clause, line: line.number, })
  }
  Ok(steps)
}

///|
pub fn render_drat(steps : Array[DratStep]) -> String {
  let output = StringBuilder()
  for step in steps {
    if step.delete {
      output.write_string("d ")
    }
    output.write_string(render_clause(step.clause))
    output.write_char('\n')
  }
  output.to_string()
}

///|
/// Occurrence-driven UCP with a reason trail. After an initial pass, only
/// clauses containing a newly falsified literal are revisited. The operation
/// budget covers clause and literal inspections across the entire conversion.
fn discover_hints(
  index : LiteralIndex,
  assumptions : Array[Int],
  budget : ConversionBudget,
  line : Int,
) -> Result[Array[Int]?, CheckError] {
  let assignment : Map[Int, Int] = Map([])
  for literal in assumptions {
    if assume_false(assignment, literal) {
      return Ok(Some([]))
    }
  }
  let queue : Array[Int] = []
  for entry in index.clauses.iter() {
    queue.push(entry.0)
  }
  queue.sort()
  let hints : Array[Int] = []
  let mut cursor = 0
  while cursor < queue.length() {
    match spend_work(budget, line) {
      Ok(_) => ()
      Err(error) => return Err(error)
    }
    let id = queue[cursor]
    cursor += 1
    let clause = index.clauses.get(id).unwrap()
    let mut satisfied = false
    let mut unknown = 0
    let mut unit = 0
    for literal in clause {
      match spend_work(budget, line) {
        Ok(_) => ()
        Err(error) => return Err(error)
      }
      let value = literal_value(assignment, literal)
      if value > 0 {
        satisfied = true
        break
      }
      if value == 0 {
        unknown += 1
        unit = literal
      }
    }
    if satisfied || unknown > 1 {
      continue
    }
    hints.push(id)
    if unknown == 0 {
      return Ok(Some(hints))
    }
    ignore(assume_false(assignment, -unit))
    for affected in index.ids_for(-unit) {
      queue.push(affected)
    }
  }
  Ok(None)
}

///|
fn discover_rat_hints(
  index : LiteralIndex,
  clause : Array[Int],
  budget : ConversionBudget,
  line : Int,
) -> Result[Array[Int], CheckError] {
  match discover_hints(index, clause, budget, line) {
    Ok(Some(hints)) => return Ok(hints)
    Ok(None) => ()
    Err(error) => return Err(error)
  }
  if clause.length() == 0 {
    return Err(BadProof(line))
  }
  let pivot = clause[0]
  let candidates = index.ids_for(-pivot)
  candidates.sort()
  let hints : Array[Int] = []
  for id in candidates {
    let resolvent = clause.copy()
    for literal in index.clauses.get(id).unwrap() {
      if literal != -pivot {
        resolvent.push(literal)
      }
    }
    let chain = match discover_hints(index, resolvent, budget, line) {
      Ok(Some(value)) => value
      Ok(None) => return Err(BadHint(line, id))
      Err(error) => return Err(error)
    }
    hints.push(-id)
    hints.append(chain)
  }
  Ok(hints)
}

///|
/// Forward DRAT checking and LRAT hint generation. Duplicate clauses are
/// tracked as distinct IDs; one deletion removes one occurrence. Absent
/// deletions are ignored. By default unit deletions follow DRAT-trim's
/// ignored-unit policy; set honor_unit_deletions for literal deletion semantics.
pub fn convert_drat_steps(
  formula : Formula,
  steps : Array[DratStep],
  options : ConversionOptions,
) -> Result[ConversionResult, CheckError] {
  match formula.validate() {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  if options.max_work <= 0 {
    return Err(ResourceLimit(0))
  }
  let budget = ConversionBudget::{ left: options.max_work, }
  let index = LiteralIndex::new(formula)
  let by_content : Map[String, Array[Int]] = Map([])
  for position in 0..<formula.clauses.length() {
    let key = render_clause(normalize_clause(formula.clauses[position]))
    let ids = by_content.get(key).unwrap_or([])
    ids.push(position + 1)
    by_content[key] = ids
  }
  let output : Array[ProofStep] = []
  let mut last_id = formula.clauses.length()
  for step in steps {
    match spend_work(budget, step.line) {
      Ok(_) => ()
      Err(error) => return Err(error)
    }
    if !valid_drat_clause(step.clause) {
      return Err(BadProof(step.line))
    }
    let key = render_clause(normalize_clause(step.clause))
    if step.delete {
      if step.clause.length() == 1 && !options.honor_unit_deletions {
        continue
      }
      let ids = by_content.get(key).unwrap_or([])
      if ids.length() == 0 {
        continue
      }
      let deleted = ids.pop().unwrap()
      ignore(index.remove(deleted))
      output.push({
        id: last_id,
        delete: true,
        clause: [],
        hints: [deleted],
        line: step.line,
      })
      continue
    }
    if last_id == 2147483647 {
      return Err(BadProof(step.line))
    }
    let hints = match
      discover_rat_hints(index, step.clause, budget, step.line) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    last_id += 1
    ignore(index.insert(last_id, step.clause))
    let ids = by_content.get(key).unwrap_or([])
    ids.push(last_id)
    by_content[key] = ids
    output.push({
      id: last_id,
      delete: false,
      clause: step.clause.copy(),
      hints,
      line: step.line,
    })
  }
  // Recheck the generated certificate through the existing hinted checker.
  match verify_steps(formula, output) {
    Ok(stats) =>
      Ok({ proof: output, stats, work: options.max_work - budget.left, })
    Err(error) => Err(error)
  }
}

///|
pub fn convert_drat(
  cnf : String,
  proof : String,
) -> Result[ConversionResult, CheckError] {
  let formula = match parse_cnf(cnf) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let steps = match parse_drat(proof) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  convert_drat_steps(formula, steps, default_conversion_options())
}
