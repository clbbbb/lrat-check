///|
/// Split ASCII proof files without depending on target-specific file I/O.
/// The caller can obtain text through native, JS, or WASI facilities.
fn source_lines(text : String) -> Array[SourceLine] {
  let lines : Array[SourceLine] = []
  let word : Array[Char] = []
  let words : Array[String] = []
  let mut line = 1
  for char in text.to_array() {
    if char == ' ' || char == '\t' || char == '\r' || char == '\n' {
      if word.length() > 0 {
        words.push(String::from_iter(word.iter()))
        word.clear()
      }
      if char == '\n' {
        lines.push({ number: line, words: words.copy(), })
        words.clear()
        line += 1
      }
    } else {
      word.push(char)
    }
  }
  if word.length() > 0 {
    words.push(String::from_iter(word.iter()))
  }
  if words.length() > 0 {
    lines.push({ number: line, words: words.copy(), })
  }
  lines
}

///|
/// Reject overflow before arithmetic; Int::parse behavior on malformed proof
/// data is deliberately not part of the trusted boundary.
fn decimal(word : String, line : Int) -> Result[Int, CheckError] {
  let chars = word.to_array()
  if chars.length() == 0 {
    return Err(BadNumber(line))
  }
  let mut index = 0
  let mut negative = false
  if chars[0] == '-' {
    negative = true
    index = 1
  }
  if index == chars.length() {
    return Err(BadNumber(line))
  }
  let mut value = 0
  while index < chars.length() {
    let digit = chars[index].to_int() - '0'.to_int()
    if digit < 0 || digit > 9 || value > (2147483647 - digit) / 10 {
      return Err(BadNumber(line))
    }
    value = value * 10 + digit
    index += 1
  }
  if negative {
    Ok(-value)
  } else {
    Ok(value)
  }
}

///|
fn has_literal(clause : Array[Int], literal : Int) -> Bool {
  for current in clause {
    if current == literal {
      return true
    }
  }
  false
}
