///|
/// A parsed proof step, useful for tools that want to inspect a certificate
/// without executing it. `delete` distinguishes an LRAT deletion record.
pub(all) struct ProofStep {
  id : Int
  delete : Bool
  clause : Array[Int]
  hints : Array[Int]
  line : Int
}

///|
/// Parse proof text into immutable step values. Semantic checking remains the
/// responsibility of `verify_formula`, so this function is also useful for
/// diagnostics and proof statistics.
pub fn parse_proof(text : String) -> Result[Array[ProofStep], CheckError] {
  let output : Array[ProofStep] = []
  let mut previous = 0
  for line in source_lines(text) {
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
    if id < previous {
      return Err(BadProof(line.number))
    }
    if id > previous {
      previous = id
    }
    if line.words[1] == "d" {
      let hints : Array[Int] = []
      for index in 2..<line.words.length() {
        let value = match decimal(line.words[index], line.number) {
          Ok(number) => number
          Err(error) => return Err(error)
        }
        if value == 0 {
          if index != line.words.length() - 1 {
            return Err(BadProof(line.number))
          }
        } else {
          if value < 0 {
            return Err(BadProof(line.number))
          }
          hints.push(value)
        }
      }
      if line.words[line.words.length() - 1] != "0" {
        return Err(BadProof(line.number))
      }
      output.push({ id, delete: true, clause: [], hints, line: line.number, })
      continue
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
        if separator {
          if index != line.words.length() - 1 {
            return Err(BadProof(line.number))
          }
          ended = true
        } else {
          separator = true
        }
      } else if separator {
        hints.push(value)
      } else {
        if seen.contains(value) || seen.contains(-value) {
          return Err(BadProof(line.number))
        }
        clause.push(value)
        seen[value] = true
      }
    }
    if !ended {
      return Err(BadProof(line.number))
    }
    output.push({ id, delete: false, clause, hints, line: line.number, })
  }
  Ok(output)
}

///|
pub fn proof_additions(steps : Array[ProofStep]) -> Int {
  let mut count = 0
  for step in steps {
    if !step.delete {
      count += 1
    }
  }
  count
}

///|
pub fn proof_deletions(steps : Array[ProofStep]) -> Int {
  let mut count = 0
  for step in steps {
    if step.delete {
      count += 1
    }
  }
  count
}

///|
pub fn proof_has_empty_addition(steps : Array[ProofStep]) -> Bool {
  for step in steps {
    if !step.delete && step.clause.length() == 0 {
      return true
    }
  }
  false
}

///|
pub fn proof_max_id(steps : Array[ProofStep]) -> Int {
  let mut result = 0
  for step in steps {
    if step.id > result {
      result = step.id
    }
  }
  result
}
