///|
fn error_json(error : @lrat.CheckError) -> String {
  let (kind, location) = match error {
    BadNumber(n) => ("number", n)
    BadCnf(n) => ("cnf", n)
    BadProof(n) => ("proof", n)
    BadHint(n, _) => ("hint", n)
    MissingEmptyClause => ("missing-empty-clause", 0)
    BadBinary(n) => ("binary", n)
    ResourceLimit(n) => ("resource-limit", n)
    UnsupportedOutputFormat => ("output-format", 0)
  }
  "{\"ok\":false,\"error\":\"" +
  kind +
  "\",\"location\":" +
  location.to_string() +
  "}"
}

///|
/// JavaScript ABI: (string, Uint8Array, string) -> JSON string.
pub fn verify_json(cnf : String, proof : Bytes, format : String) -> String {
  let kind = match @lrat.parse_format(format) {
    Some(value) => value
    None => return "{\"ok\":false,\"error\":\"input-format\"}"
  }
  match @lrat.verify_input(cnf, proof, kind) {
    Ok(stats) =>
      "{\"ok\":true,\"additions\":" +
      stats.additions.to_string() +
      ",\"deletions\":" +
      stats.deletions.to_string() +
      ",\"rat\":" +
      stats.rat_additions.to_string() +
      "}"
    Err(error) => error_json(error)
  }
}

///|
/// Produce a checked textual LRAT certificate in the JSON lrat field.
pub fn convert_json(cnf : String, proof : Bytes, format : String) -> String {
  let kind = match @lrat.parse_format(format) {
    Some(value) => value
    None => return "{\"ok\":false,\"error\":\"input-format\"}"
  }
  match
    @lrat.process_proof(cnf, proof, kind, @lrat.default_conversion_options()) {
    Ok(result) => {
      let text = @lrat.render_proof(result.proof)
      let json : Json = { "ok": true, "lrat": text }
      json.stringify()
    }
    Err(error) => error_json(error)
  }
}
