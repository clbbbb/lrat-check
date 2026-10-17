///|
fn append_ints(buffer : StringBuilder, values : Array[Int]) -> Unit {
  for value in values {
    buffer.write_string(value.to_string())
    buffer.write_char(' ')
  }
}

///|
/// Render a parsed proof with canonical whitespace. The output is intended for
/// diagnostics and fixtures, not as a replacement for a proof optimizer.
pub fn render_proof(steps : Array[ProofStep]) -> String {
  let output = StringBuilder()
  for step in steps {
    output.write_string(step.id.to_string())
    if step.delete {
      output.write_string(" d ")
      append_ints(output, step.hints)
      output.write_string("0\n")
      continue
    }
    output.write_char(' ')
    append_ints(output, step.clause)
    output.write_string("0 ")
    append_ints(output, step.hints)
    output.write_string("0\n")
  }
  output.to_string()
}

///|
pub fn render_clause(clause : Array[Int]) -> String {
  let output = StringBuilder()
  append_ints(output, clause)
  output.write_char('0')
  output.to_string()
}

///|
pub fn render_dimacs(formula : Formula) -> String {
  let output = StringBuilder()
  output.write_string("p cnf ")
  output.write_string(formula.variable_count.to_string())
  output.write_char(' ')
  output.write_string(formula.clauses.length().to_string())
  output.write_char('\n')
  for clause in formula.clauses {
    output.write_string(render_clause(clause))
    output.write_char('\n')
  }
  output.to_string()
}
