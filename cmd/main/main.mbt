///|
fn explain(error : @lrat.CheckError) -> String {
  match error {
    BadNumber(line) => "bad integer on line " + line.to_string()
    BadCnf(line) => "invalid DIMACS CNF on line " + line.to_string()
    BadProof(line) => "invalid proof at record location " + line.to_string()
    BadHint(line, id) =>
      "invalid LRAT hint " +
      id.to_string() +
      " at record location " +
      line.to_string()
    MissingEmptyClause => "proof did not derive the empty clause"
    UnsupportedOutputFormat => "output format must be lrat or lrat-binary"
    BadBinary(offset) => "invalid binary proof at byte " + offset.to_string()
    ResourceLimit(line) =>
      "conversion work limit reached at record " + line.to_string()
  }
}

///|
fn main {
  let args = @env.args()
  if args.length() == 6 && args[1] == "check" && args[2] == "--format" {
    let format = match @lrat.parse_format(args[3]) {
      Some(value) => value
      None => {
        println("Unknown proof format")
        @sys.exit(2)
        return
      }
    }
    let cnf = @fs.read_file_to_string(args[4]) catch {
      _ => {
        println("Cannot read CNF")
        @sys.exit(2)
        return
      }
    }
    let proof = @fs.read_file_to_bytes(args[5]) catch {
      _ => {
        println("Cannot read proof")
        @sys.exit(2)
        return
      }
    }
    match @lrat.verify_input(cnf, proof, format) {
      Ok(stats) =>
        println(
          "VERIFIED UNSAT: " +
          stats.additions.to_string() +
          " additions; " +
          stats.rat_additions.to_string() +
          " RAT steps",
        )
      Err(error) => {
        println("FAILED: " + explain(error))
        @sys.exit(if error is ResourceLimit(_) { 3 } else { 1 })
      }
    }
    return
  }
  if args.length() == 9 &&
    args[1] == "convert" &&
    args[2] == "--from" &&
    args[4] == "--to" {
    let from = match @lrat.parse_format(args[3]) {
      Some(value) => value
      None => {
        println("Unknown input format")
        @sys.exit(2)
        return
      }
    }
    let to = match @lrat.parse_format(args[5]) {
      Some(value) => value
      None => {
        println("Unknown output format")
        @sys.exit(2)
        return
      }
    }
    if to is DratText || to is DratBinary {
      println("Output must be LRAT")
      @sys.exit(2)
      return
    }
    let cnf = @fs.read_file_to_string(args[6]) catch {
      _ => {
        println("Cannot read CNF")
        @sys.exit(2)
        return
      }
    }
    let proof = @fs.read_file_to_bytes(args[7]) catch {
      _ => {
        println("Cannot read proof")
        @sys.exit(2)
        return
      }
    }
    match @lrat.convert_proof(cnf, proof, from, to) {
      Ok(bytes) => {
        @fs.write_bytes_to_file(args[8], bytes) catch {
          _ => {
            println("Cannot write proof")
            @sys.exit(2)
            return
          }
        }
        println("VERIFIED UNSAT: wrote LRAT certificate")
      }
      Err(error) => {
        println("FAILED: " + explain(error))
        @sys.exit(if error is ResourceLimit(_) { 3 } else { 1 })
      }
    }
    return
  }
  if args.length() == 5 && args[1] == "--convert-drat" {
    let cnf = @fs.read_file_to_string(args[2]) catch {
      _ => {
        println("Cannot read CNF")
        @sys.exit(2)
        return
      }
    }
    let proof = @fs.read_file_to_string(args[3]) catch {
      _ => {
        println("Cannot read DRAT")
        @sys.exit(2)
        return
      }
    }
    match @lrat.convert_drat(cnf, proof) {
      Ok(result) => {
        @fs.write_string_to_file(args[4], @lrat.render_proof(result.proof)) catch {
          _ => {
            println("Cannot write LRAT")
            @sys.exit(2)
            return
          }
        }
        println(
          "VERIFIED UNSAT: wrote LRAT certificate; work=" +
          result.work.to_string(),
        )
      }
      Err(error) => {
        println("INVALID: " + explain(error))
        @sys.exit(1)
      }
    }
    return
  }
  if args.length() == 4 && (args[1] == "--audit" || args[1] == "--lifetimes") {
    let cnf = @fs.read_file_to_string(args[2]) catch {
      _ => {
        println("Cannot read CNF: " + args[2])
        @sys.exit(2)
        return
      }
    }
    let proof = @fs.read_file_to_string(args[3]) catch {
      _ => {
        println("Cannot read proof: " + args[3])
        @sys.exit(2)
        return
      }
    }
    let formula = match @lrat.parse_cnf(cnf) {
      Ok(value) => value
      Err(error) => {
        println("INVALID: " + explain(error))
        @sys.exit(1)
        return
      }
    }
    let steps = match @lrat.parse_proof(proof) {
      Ok(value) => value
      Err(error) => {
        println("INVALID: " + explain(error))
        @sys.exit(1)
        return
      }
    }
    let snapshot = @lrat.audit_all(formula, steps)
    if args[1] == "--lifetimes" {
      let report = @lrat.analyze_clause_lifetimes(formula, steps)
      println("CLAUSE LIFETIMES: " + report.summary())
      return
    }
    println("STRUCTURAL AUDIT: " + snapshot.summary())
    if snapshot.has_reference_errors() {
      println("References are missing or point to deleted clauses.")
      @sys.exit(1)
    }
    if !snapshot.has_live_empty_clause() {
      println("No live empty clause in the final state.")
    }
    println("This audit does not verify RAT or unit-propagation hints.")
    return
  }
  if args.length() != 3 {
    println("Usage: lrat-check <formula.cnf> <proof.lrat>")
    println(
      "       lrat-check check --format <lrat|lrat-binary|drat|drat-binary> <CNF> <PROOF>",
    )
    println(
      "       lrat-check convert --from <FORMAT> --to <lrat|lrat-binary> <CNF> <PROOF> <OUTPUT>",
    )
    println("       lrat-check --audit <formula.cnf> <proof.lrat>")
    println("       lrat-check --lifetimes <formula.cnf> <proof.lrat>")
    println(
      "       lrat-check --convert-drat <formula.cnf> <proof.drat> <output.lrat>",
    )
    @sys.exit(2)
    return
  }
  let cnf = @fs.read_file_to_string(args[1]) catch {
    _ => {
      println("Cannot read CNF: " + args[1])
      @sys.exit(2)
      return
    }
  }
  let proof = @fs.read_file_to_string(args[2]) catch {
    _ => {
      println("Cannot read proof: " + args[2])
      @sys.exit(2)
      return
    }
  }
  match @lrat.verify(cnf, proof) {
    Ok(stats) =>
      println(
        "VERIFIED UNSAT: " +
        stats.additions.to_string() +
        " additions, " +
        stats.deletions.to_string() +
        " deletions, " +
        stats.rat_additions.to_string() +
        " RAT steps",
      )
    Err(error) => {
      println("INVALID: " + explain(error))
      @sys.exit(1)
    }
  }
}
