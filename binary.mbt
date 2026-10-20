///|
priv struct ProofReader {
  data : Bytes
  mut position : Int
}

///|
/// Signed variable-byte integers in the non-negative 31-bit ID/literal domain.
/// Offsets are one-based. Reject overflow and malformed encodings before casts.
fn read_proof_int(reader : ProofReader) -> Result[Int, CheckError] {
  let start = reader.position
  let mut value : Int64 = 0
  let mut factor : Int64 = 1
  for count in 0..<5 {
    if reader.position >= reader.data.length() {
      return Err(BadBinary(start + 1))
    }
    let byte = reader.data[reader.position].to_int()
    reader.position += 1
    if count == 4 && byte > 15 {
      return Err(BadBinary(start + 1))
    }
    value += (byte & 127).to_int64() * factor
    if byte < 128 {
      if (count > 0 && byte == 0) || value == 1 {
        return Err(BadBinary(start + 1))
      }
      let magnitude = (value / 2).to_int()
      return Ok(if value % 2 == 0 { magnitude } else { -magnitude })
    }
    factor *= 128
  }
  Err(BadBinary(start + 1))
}

///|
fn read_proof_list(reader : ProofReader) -> Result[Array[Int], CheckError] {
  let result : Array[Int] = []
  while true {
    match read_proof_int(reader) {
      Ok(0) => return Ok(result)
      Ok(value) => result.push(value)
      Err(error) => return Err(error)
    }
  } nobreak {
    Err(BadBinary(reader.position + 1))
  }
}

///|
fn write_proof_int(output : Array[Byte], number : Int) -> Unit {
  let mut value = if number < 0 {
    -number.to_int64() * 2 + 1
  } else {
    number.to_int64() * 2
  }
  while value >= 128 {
    output.push(((value % 128).to_int() + 128).to_byte())
    value /= 128
  }
  output.push(value.to_int().to_byte())
}

///|
fn write_proof_list(output : Array[Byte], numbers : Array[Int]) -> Unit {
  for number in numbers {
    write_proof_int(output, number)
  }
  output.push(0)
}

///|
fn proof_bytes(output : Array[Byte]) -> Bytes {
  Bytes::from_array(output)
}

///|
pub fn parse_binary_drat(bytes : Bytes) -> Result[Array[DratStep], CheckError] {
  let reader = ProofReader::{ data: bytes, position: 0, }
  let steps : Array[DratStep] = []
  while reader.position < bytes.length() {
    let offset = reader.position + 1
    let tag = bytes[reader.position].to_int()
    reader.position += 1
    if tag != 97 && tag != 100 {
      return Err(BadBinary(offset))
    }
    let clause = match read_proof_list(reader) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    if !valid_drat_clause(clause) {
      return Err(BadBinary(offset))
    }
    steps.push({ delete: tag == 100, clause, line: offset, })
  }
  Ok(steps)
}

///|
pub fn encode_binary_drat(steps : Array[DratStep]) -> Result[Bytes, CheckError] {
  let output : Array[Byte] = []
  for step in steps {
    if !valid_drat_clause(step.clause) {
      return Err(BadProof(step.line))
    }
    output.push(if step.delete { 100 } else { 97 })
    write_proof_list(output, step.clause)
  }
  Ok(proof_bytes(output))
}

///|
/// CaDiCaL >=1.9.0 signed-ID binary LRAT. Deletions have no record ID;
/// initial_id must be the number of original CNF clauses.
pub fn parse_binary_lrat(
  bytes : Bytes,
  initial_id : Int,
) -> Result[Array[ProofStep], CheckError] {
  if initial_id < 0 {
    return Err(BadBinary(1))
  }
  let reader = ProofReader::{ data: bytes, position: 0, }
  let steps : Array[ProofStep] = []
  let mut last_id = initial_id
  while reader.position < bytes.length() {
    let offset = reader.position + 1
    let tag = bytes[reader.position].to_int()
    reader.position += 1
    if tag == 100 {
      let ids = match read_proof_list(reader) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      for id in ids {
        if id <= 0 {
          return Err(BadBinary(offset))
        }
      }
      steps.push({
        id: last_id,
        delete: true,
        clause: [],
        hints: ids,
        line: offset,
      })
    } else if tag == 97 {
      let id = match read_proof_int(reader) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      if id <= last_id {
        return Err(BadBinary(offset))
      }
      let clause = match read_proof_list(reader) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      let hints = match read_proof_list(reader) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      if !valid_drat_clause(clause) {
        return Err(BadBinary(offset))
      }
      steps.push({ id, delete: false, clause, hints, line: offset, })
      last_id = id
    } else {
      return Err(BadBinary(offset))
    }
  }
  Ok(steps)
}

///|
/// Syntax-only conversion. convert_proof verifies the supplied CNF as well.
pub fn encode_binary_lrat(
  steps : Array[ProofStep],
) -> Result[Bytes, CheckError] {
  match parse_proof(render_proof(steps)) {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  let output : Array[Byte] = []
  for step in steps {
    if step.delete {
      output.push(100)
      write_proof_list(output, step.hints)
    } else {
      output.push(97)
      write_proof_int(output, step.id)
      write_proof_list(output, step.clause)
      write_proof_list(output, step.hints)
    }
  }
  Ok(proof_bytes(output))
}
