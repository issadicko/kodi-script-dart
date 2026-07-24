/// KodiScript Token Types and Token class.
library;

/// Represents token types in KodiScript.
enum TokenType {
  // Special
  illegal,
  eof,
  newline,

  // Identifiers and literals
  ident,
  number,
  string,
  stringTemplate,

  // Operators
  assign, // =
  plus, // +
  minus, // -
  asterisk, // *
  slash, // /
  percent, // %

  // Compound assignment and increment/decrement
  plusEq, // +=
  minusEq, // -=
  asteriskEq, // *=
  slashEq, // /=
  plusPlus, // ++
  minusMinus, // --

  // Comparison
  eq, // ==
  notEq, // !=
  lt, // <
  gt, // >
  ltEq, // <=
  gtEq, // >=

  // Logical
  and, // &&
  or, // ||
  not, // !

  // Null-safety
  safeAccess, // ?.
  elvis, // ?:
  question, // ?

  // Delimiters
  comma, // ,
  semicolon, // ;
  colon, // :
  lparen, // (
  rparen, // )
  lbrace, // {
  rbrace, // }
  lbracket, // [
  rbracket, // ]
  dot, // .
  ellipsis, // ...

  // Keywords
  let,
  ifKeyword,
  elseKeyword,
  trueKeyword,
  falseKeyword,
  nullKeyword,
  returnKeyword,
  forKeyword,
  inKeyword,
  fn,
  function,
  whileKeyword,
  breakKeyword,
  continueKeyword,
  tryKeyword,
  catchKeyword;

  /// Returns true if this token type can end a statement (for ASI).
  bool get canEndStatement => {
        TokenType.ident,
        TokenType.number,
        TokenType.string,
        TokenType.stringTemplate,
        TokenType.trueKeyword,
        TokenType.falseKeyword,
        TokenType.nullKeyword,
        TokenType.rparen,
        TokenType.rbrace,
        TokenType.rbracket,
        TokenType.plusPlus,
        TokenType.minusMinus,
        TokenType.breakKeyword,
        TokenType.continueKeyword,
      }.contains(this);

  /// Returns true if this token type indicates statement continuation.
  bool get isOperatorContinuation => {
        TokenType.plus,
        TokenType.minus,
        TokenType.asterisk,
        TokenType.slash,
        TokenType.percent,
        TokenType.and,
        TokenType.or,
        TokenType.eq,
        TokenType.notEq,
        TokenType.lt,
        TokenType.gt,
        TokenType.ltEq,
        TokenType.gtEq,
        TokenType.safeAccess,
        TokenType.elvis,
        TokenType.dot,
        TokenType.comma,
      }.contains(this);
}

/// Represents a single token with type, value, and position.
class Token {
  final TokenType type;
  final String literal;
  final int line;
  final int column;

  const Token(this.type, this.literal, {this.line = 1, this.column = 1});

  static final Map<String, TokenType> _keywords = {
    'let': TokenType.let,
    'if': TokenType.ifKeyword,
    'else': TokenType.elseKeyword,
    'true': TokenType.trueKeyword,
    'false': TokenType.falseKeyword,
    'null': TokenType.nullKeyword,
    'return': TokenType.returnKeyword,
    'for': TokenType.forKeyword,
    'in': TokenType.inKeyword,
    'fn': TokenType.fn,
    'function': TokenType.function,
    'while': TokenType.whileKeyword,
    'break': TokenType.breakKeyword,
    'continue': TokenType.continueKeyword,
    'try': TokenType.tryKeyword,
    'catch': TokenType.catchKeyword,
  };

  /// Looks up an identifier to check if it's a keyword.
  static TokenType lookupIdent(String ident) {
    return _keywords[ident] ?? TokenType.ident;
  }

  @override
  String toString() => 'Token($type, "$literal", $line:$column)';
}
