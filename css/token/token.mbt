///|
/// CSS Token types based on CSS Syntax Level 3
/// https://www.w3.org/TR/css-syntax-3/#tokenization
pub enum Token {
  // Identifiers and functions
  Ident(String)
  Function(String) // ident followed by '('
  AtKeyword(String) // @ followed by ident
  Hash(String, HashType) // # followed by name
  String(String)
  BadString
  Url(String)
  BadUrl

  // Numbers
  Number(Double, NumType)
  Percentage(Double)
  Dimension(Double, String) // value + unit

  // Delimiters and punctuation
  Delim(Char)
  Whitespace
  Colon
  Semicolon
  Comma
  LeftBracket // [
  RightBracket // ]
  LeftParen // (
  RightParen // )
  LeftBrace // {
  RightBrace // }

  // Special
  CDO // <!--
  CDC // -->
  EOF
}

///|
/// Hash token type flag
pub enum HashType {
  Id // starts with ident-like character
  Unrestricted // otherwise
}

///|
/// Number type flag
pub enum NumType {
  Integer
  Number
}

///|
pub fn Token::to_string(self : Token) -> String {
  match self {
    Ident(s) => "Ident(\{s})"
    Function(s) => "Function(\{s})"
    AtKeyword(s) => "AtKeyword(\{s})"
    Hash(s, _) => "Hash(\{s})"
    String(s) => "String(\{s})"
    BadString => "BadString"
    Url(s) => "Url(\{s})"
    BadUrl => "BadUrl"
    Number(n, t) => {
      let typ = match t {
        Integer => "int"
        NumType::Number => "num"
      }
      "Number(\{n}, \{typ})"
    }
    Percentage(n) => "Percentage(\{n})"
    Dimension(n, u) => "Dimension(\{n}, \{u})"
    Delim(c) => "Delim(\{c})"
    Whitespace => "Whitespace"
    Colon => "Colon"
    Semicolon => "Semicolon"
    Comma => "Comma"
    LeftBracket => "LeftBracket"
    RightBracket => "RightBracket"
    LeftParen => "LeftParen"
    RightParen => "RightParen"
    LeftBrace => "LeftBrace"
    RightBrace => "RightBrace"
    CDO => "CDO"
    CDC => "CDC"
    EOF => "EOF"
  }
}
