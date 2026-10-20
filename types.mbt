///|
/// All input errors carry a one-based line number when one is available.
pub(all) enum CheckError {
  BadNumber(Int)
  BadCnf(Int)
  BadProof(Int)
  BadHint(Int, Int)
  MissingEmptyClause
  BadBinary(Int)
  ResourceLimit(Int)
}

///|
pub(all) struct Formula {
  variable_count : Int
  clauses : Array[Array[Int]]
}

///|
pub(all) struct CheckStats {
  initial_clauses : Int
  additions : Int
  deletions : Int
  rat_additions : Int
}

///|
priv struct SourceLine {
  number : Int
  words : Array[String]
}
