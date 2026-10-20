///|
pub(all) enum ProofFormat {
  LratText
  LratBinary
  DratText
  DratBinary
}

///|
pub fn parse_format(name : String) -> ProofFormat? {
  match name {
    "lrat" => Some(LratText)
    "lrat-binary" => Some(LratBinary)
    "drat" => Some(DratText)
    "drat-binary" => Some(DratBinary)
    _ => None
  }
}

///|
fn proof_text(bytes : Bytes) -> Result[String, CheckError] {
  Ok(@utf8.decode(bytes[:])) catch {
    _ => Err(BadBinary(1))
  }
}

///|
/// Core processing uses no file I/O, for the CLI, JavaScript and Wasm callers.
pub fn process_proof(
  cnf : String,
  input : Bytes,
  format : ProofFormat,
  options : ConversionOptions,
) -> Result[ConversionResult, CheckError] {
  let formula = match parse_cnf(cnf) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  if format is DratBinary {
    let steps = match parse_binary_drat(input) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    return convert_drat_steps(formula, steps, options)
  }
  if format is DratText {
    let text = match proof_text(input) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    let steps = match parse_drat(text) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    return convert_drat_steps(formula, steps, options)
  }
  let steps = if format is LratBinary {
    match parse_binary_lrat(input, formula.clauses.length()) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
  } else {
    let text = match proof_text(input) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    match parse_proof(text) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
  }
  match verify_steps(formula, steps) {
    Ok(stats) => Ok({ proof: steps, stats, work: 0, })
    Err(error) => Err(error)
  }
}

///|
pub fn verify_input(
  cnf : String,
  input : Bytes,
  format : ProofFormat,
) -> Result[CheckStats, CheckError] {
  match process_proof(cnf, input, format, default_conversion_options()) {
    Ok(result) => Ok(result.stats)
    Err(error) => Err(error)
  }
}

///|
/// All four inputs can produce textual or binary LRAT. An output certificate
/// is emitted only after verifying the supplied formula as UNSAT.
pub fn convert_proof(
  cnf : String,
  input : Bytes,
  from : ProofFormat,
  to : ProofFormat,
) -> Result[Bytes, CheckError] {
  if to is DratText || to is DratBinary {
    return Err(UnsupportedOutputFormat)
  }
  let result = match
    process_proof(cnf, input, from, default_conversion_options()) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  if to is LratBinary {
    encode_binary_lrat(result.proof)
  } else {
    Ok(@utf8.encode(render_proof(result.proof)[:]))
  }
}
