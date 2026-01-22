/// KodiScript Parser - Parses tokens into an AST.
library;

import '../token/token.dart';
import '../lexer/lexer.dart';
import '../ast/ast.dart';

/// Operator precedence levels.
const int _lowest = 1;
const int _elvis = 2;
const int _or = 3;
const int _and = 4;
const int _equals = 5;
const int _lessGreater = 6;
const int _sum = 7;
const int _product = 8;
const int _prefix = 9;
const int _call = 10;
const int _access = 11;

final Map<TokenType, int> _precedences = {
  TokenType.elvis: _elvis,
  TokenType.or: _or,
  TokenType.and: _and,
  TokenType.eq: _equals,
  TokenType.notEq: _equals,
  TokenType.lt: _lessGreater,
  TokenType.gt: _lessGreater,
  TokenType.ltEq: _lessGreater,
  TokenType.gtEq: _lessGreater,
  TokenType.plus: _sum,
  TokenType.minus: _sum,
  TokenType.asterisk: _product,
  TokenType.slash: _product,
  TokenType.percent: _product,
  TokenType.lparen: _call,
  TokenType.lbracket: _access,
  TokenType.dot: _access,
  TokenType.safeAccess: _access,
};

/// Parser parses tokens from a Lexer into an AST.
class Parser {
  final Lexer _lexer;
  Token _curToken = const Token(TokenType.eof, '');
  Token _peekToken = const Token(TokenType.eof, '');
  final List<String> _errors = [];

  final Map<TokenType, Expression? Function()> _prefixParseFns = {};
  final Map<TokenType, Expression? Function(Expression)> _infixParseFns = {};

  Parser(this._lexer) {
    // Register prefix parse functions
    _prefixParseFns[TokenType.ident] = _parseIdentifier;
    _prefixParseFns[TokenType.number] = _parseNumberLiteral;
    _prefixParseFns[TokenType.string] = _parseStringLiteral;
    _prefixParseFns[TokenType.stringTemplate] = _parseStringTemplate;
    _prefixParseFns[TokenType.trueKeyword] = _parseBooleanLiteral;
    _prefixParseFns[TokenType.falseKeyword] = _parseBooleanLiteral;
    _prefixParseFns[TokenType.nullKeyword] = _parseNullLiteral;
    _prefixParseFns[TokenType.minus] = _parsePrefixExpression;
    _prefixParseFns[TokenType.not] = _parsePrefixExpression;
    _prefixParseFns[TokenType.lparen] = _parseGroupedExpression;
    _prefixParseFns[TokenType.lbracket] = _parseArrayLiteral;
    _prefixParseFns[TokenType.lbrace] = _parseObjectLiteral;
    _prefixParseFns[TokenType.fn] = _parseFunctionLiteral;

    // Register infix parse functions
    _infixParseFns[TokenType.plus] = _parseInfixExpression;
    _infixParseFns[TokenType.minus] = _parseInfixExpression;
    _infixParseFns[TokenType.asterisk] = _parseInfixExpression;
    _infixParseFns[TokenType.slash] = _parseInfixExpression;
    _infixParseFns[TokenType.percent] = _parseInfixExpression;
    _infixParseFns[TokenType.eq] = _parseInfixExpression;
    _infixParseFns[TokenType.notEq] = _parseInfixExpression;
    _infixParseFns[TokenType.lt] = _parseInfixExpression;
    _infixParseFns[TokenType.gt] = _parseInfixExpression;
    _infixParseFns[TokenType.ltEq] = _parseInfixExpression;
    _infixParseFns[TokenType.gtEq] = _parseInfixExpression;
    _infixParseFns[TokenType.and] = _parseInfixExpression;
    _infixParseFns[TokenType.or] = _parseInfixExpression;
    _infixParseFns[TokenType.elvis] = _parseElvisExpression;
    _infixParseFns[TokenType.dot] = _parsePropertyAccess;
    _infixParseFns[TokenType.safeAccess] = _parseSafeAccess;
    _infixParseFns[TokenType.lparen] = _parseCallExpression;
    _infixParseFns[TokenType.lbracket] = _parseIndexExpression;

    // Initialize tokens
    _nextToken();
    _nextToken();
  }

  List<String> errors() => List.unmodifiable(_errors);

  void _addError(String message) {
    _errors.add('line ${_curToken.line}, col ${_curToken.column}: $message');
  }

  void _nextToken() {
    _curToken = _peekToken;
    _peekToken = _lexer.nextToken();
  }

  bool _curTokenIs(TokenType type) => _curToken.type == type;
  bool _peekTokenIs(TokenType type) => _peekToken.type == type;

  bool _expectPeek(TokenType type) {
    if (_peekTokenIs(type)) {
      _nextToken();
      return true;
    }
    _addError('expected $type, got ${_peekToken.type}');
    return false;
  }

  int _peekPrecedence() => _precedences[_peekToken.type] ?? _lowest;
  int _curPrecedence() => _precedences[_curToken.type] ?? _lowest;

  void _consumeEndOfStatement() {
    while (_curTokenIs(TokenType.semicolon) || _curTokenIs(TokenType.newline)) {
      _nextToken();
    }
  }

  /// Skips newline tokens in peek position.
  /// Used inside arrays and objects to allow multi-line definitions.
  void _skipNewlines() {
    while (_peekTokenIs(TokenType.newline)) {
      _nextToken();
    }
  }

  /// Skips newline tokens in current position.
  void _skipCurrentNewlines() {
    while (_curTokenIs(TokenType.newline)) {
      _nextToken();
    }
  }

  Program parseProgram() {
    final program = Program();

    while (!_curTokenIs(TokenType.eof)) {
      _consumeEndOfStatement();
      if (_curTokenIs(TokenType.eof)) break;

      final stmt = _parseStatement();
      if (stmt != null) {
        program.statements.add(stmt);
      }

      if (!_curTokenIs(TokenType.eof) &&
          !_curTokenIs(TokenType.semicolon) &&
          !_curTokenIs(TokenType.newline)) {
        _nextToken();
      }
      _consumeEndOfStatement();
    }

    return program;
  }

  Statement? _parseStatement() {
    switch (_curToken.type) {
      case TokenType.let:
        return _parseVarDecl();
      case TokenType.ifKeyword:
        return _parseIfStatement();
      case TokenType.returnKeyword:
        return _parseReturnStatement();
      case TokenType.forKeyword:
        return _parseForStatement();
      case TokenType.whileKeyword:
        return _parseWhileStatement();
      case TokenType.ident:
        if (_peekTokenIs(TokenType.assign)) {
          return _parseAssignment();
        }
        return _parseExpressionStatement();
      default:
        return _parseExpressionStatement();
    }
  }

  VarDecl? _parseVarDecl() {
    final token = _curToken;

    if (!_expectPeek(TokenType.ident)) return null;
    final name = Identifier(_curToken, _curToken.literal);

    if (!_expectPeek(TokenType.assign)) return null;
    _nextToken();

    final value = _parseExpression(_lowest);
    if (value == null) return null;

    return VarDecl(token, name, value);
  }

  Assignment? _parseAssignment() {
    final token = _curToken;
    final name = Identifier(_curToken, _curToken.literal);

    _nextToken(); // consume ASSIGN
    _nextToken(); // move to expression

    final value = _parseExpression(_lowest);
    if (value == null) return null;

    return Assignment(token, name, value);
  }

  IfStatement? _parseIfStatement() {
    final token = _curToken;

    if (!_expectPeek(TokenType.lparen)) return null;
    _nextToken();

    final condition = _parseExpression(_lowest);
    if (condition == null) return null;

    if (!_expectPeek(TokenType.rparen)) return null;
    if (!_expectPeek(TokenType.lbrace)) return null;

    final consequence = _parseBlockStatement();

    BlockStatement? alternative;
    if (_peekTokenIs(TokenType.elseKeyword)) {
      _nextToken();
      if (!_expectPeek(TokenType.lbrace)) return null;
      alternative = _parseBlockStatement();
    }

    return IfStatement(token, condition, consequence, alternative);
  }

  BlockStatement _parseBlockStatement() {
    final block = BlockStatement(_curToken);
    _nextToken(); // consume opening brace

    while (!_curTokenIs(TokenType.rbrace) && !_curTokenIs(TokenType.eof)) {
      _consumeEndOfStatement();
      if (_curTokenIs(TokenType.rbrace)) break;

      final stmt = _parseStatement();
      if (stmt != null) {
        block.statements.add(stmt);
      }
      _nextToken();
      _consumeEndOfStatement();
    }

    return block;
  }

  ReturnStatement _parseReturnStatement() {
    final token = _curToken;

    if (_peekTokenIs(TokenType.semicolon) ||
        _peekTokenIs(TokenType.newline) ||
        _peekTokenIs(TokenType.eof) ||
        _peekTokenIs(TokenType.rbrace)) {
      return ReturnStatement(token, null);
    }

    _nextToken();
    final value = _parseExpression(_lowest);
    return ReturnStatement(token, value);
  }

  ForStatement? _parseForStatement() {
    final token = _curToken;

    if (!_expectPeek(TokenType.lparen)) return null;
    if (!_expectPeek(TokenType.ident)) return null;
    final variable = Identifier(_curToken, _curToken.literal);

    if (!_expectPeek(TokenType.inKeyword)) return null;

    _nextToken();
    final iterable = _parseExpression(_lowest);
    if (iterable == null) return null;

    if (!_expectPeek(TokenType.rparen)) return null;
    if (!_expectPeek(TokenType.lbrace)) return null;

    final body = _parseBlockStatement();

    return ForStatement(token, variable, iterable, body);
  }

  WhileStatement? _parseWhileStatement() {
    final token = _curToken;

    if (!_expectPeek(TokenType.lparen)) return null;

    _nextToken();
    final condition = _parseExpression(_lowest);
    if (condition == null) return null;

    if (!_expectPeek(TokenType.rparen)) return null;
    if (!_expectPeek(TokenType.lbrace)) return null;

    final body = _parseBlockStatement();

    return WhileStatement(token, condition, body);
  }

  ExpressionStatement? _parseExpressionStatement() {
    final token = _curToken;
    final expression = _parseExpression(_lowest);
    if (expression == null) return null;
    return ExpressionStatement(token, expression);
  }

  Expression? _parseExpression(int precedence) {
    final prefix = _prefixParseFns[_curToken.type];
    if (prefix == null) {
      _addError('no prefix parse function for ${_curToken.type}');
      return null;
    }

    var leftExp = prefix();
    if (leftExp == null) return null;

    while (!_peekTokenIs(TokenType.semicolon) &&
        !_peekTokenIs(TokenType.newline) &&
        !_peekTokenIs(TokenType.eof) &&
        precedence < _peekPrecedence()) {
      final infix = _infixParseFns[_peekToken.type];
      if (infix == null) return leftExp;

      _nextToken();
      leftExp = infix(leftExp!);
      if (leftExp == null) return null;
    }

    return leftExp;
  }

  Expression _parseIdentifier() => Identifier(_curToken, _curToken.literal);

  Expression? _parseNumberLiteral() {
    final value = double.tryParse(_curToken.literal);
    if (value == null) {
      _addError("could not parse '${_curToken.literal}' as number");
      return null;
    }
    return NumberLiteral(_curToken, value);
  }

  Expression _parseStringLiteral() => StringLiteral(_curToken, _curToken.literal);

  Expression? _parseStringTemplate() {
    final token = _curToken;
    final parts = <Expression>[];
    final literal = _curToken.literal;
    var i = 0;

    while (i < literal.length) {
      // Find next ${
      final start = i;
      while (i < literal.length &&
          !(i + 1 < literal.length && literal[i] == '\$' && literal[i + 1] == '{')) {
        i++;
      }

      // Add string part if non-empty
      if (i > start) {
        final strToken = Token(TokenType.string, literal.substring(start, i));
        parts.add(StringLiteral(strToken, literal.substring(start, i)));
      }

      // If we found ${, parse the expression
      if (i + 1 < literal.length && literal[i] == '\$' && literal[i + 1] == '{') {
        i += 2; // skip ${

        // Find matching }
        var braceCount = 1;
        final exprStart = i;
        final openBrace = '{'.codeUnitAt(0);
        final closeBrace = '}'.codeUnitAt(0);
        while (i < literal.length && braceCount > 0) {
          if (literal.codeUnitAt(i) == openBrace) braceCount++;
          else if (literal.codeUnitAt(i) == closeBrace) braceCount--;
          if (braceCount > 0) i++;
        }

        // Extract and parse the expression
        final exprStr = literal.substring(exprStart, i);
        if (i < literal.length) i++; // skip closing }

        // Create a new lexer and parser for the expression
        final exprLexer = Lexer(exprStr);
        final exprParser = Parser(exprLexer);
        final expr = exprParser._parseExpression(_lowest);

        if (exprParser.errors().isNotEmpty) {
          _errors.addAll(exprParser.errors());
        }

        if (expr != null) {
          parts.add(expr);
        }
      }
    }

    return StringTemplate(token, parts);
  }

  Expression _parseBooleanLiteral() =>
      BooleanLiteral(_curToken, _curTokenIs(TokenType.trueKeyword));

  Expression _parseNullLiteral() => NullLiteral(_curToken);

  Expression? _parsePrefixExpression() {
    final token = _curToken;
    final operator = _curToken.literal;
    _nextToken();
    final right = _parseExpression(_prefix);
    if (right == null) return null;
    return UnaryExpr(token, operator, right);
  }

  Expression? _parseGroupedExpression() {
    _nextToken();
    final exp = _parseExpression(_lowest);
    if (!_expectPeek(TokenType.rparen)) return null;
    return exp;
  }

  Expression? _parseArrayLiteral() {
    final token = _curToken;
    final elements = _parseExpressionList(TokenType.rbracket);
    return ArrayLiteral(token, elements);
  }

  List<Expression> _parseExpressionList(TokenType end) {
    final list = <Expression>[];

    // Skip leading newlines
    _skipNewlines();

    if (_peekTokenIs(end)) {
      _nextToken();
      return list;
    }

    _nextToken();
    _skipCurrentNewlines();
    final exp = _parseExpression(_lowest);
    if (exp != null) list.add(exp);

    // Skip trailing newlines after each element
    _skipNewlines();

    while (_peekTokenIs(TokenType.comma)) {
      _nextToken(); // consume comma
      _skipNewlines(); // skip newlines after comma
      _nextToken();
      _skipCurrentNewlines();
      final exp = _parseExpression(_lowest);
      if (exp != null) list.add(exp);
      _skipNewlines();
    }

    // Skip newlines before closing bracket
    _skipNewlines();

    if (!_expectPeek(end)) {
      return [];
    }

    return list;
  }

  Expression? _parseObjectLiteral() {
    final token = _curToken;
    final pairs = <String, Expression>{};

    // Skip leading newlines
    _skipNewlines();

    if (_peekTokenIs(TokenType.rbrace)) {
      _nextToken();
      return ObjectLiteral(token, pairs);
    }

    while (!_peekTokenIs(TokenType.rbrace)) {
      _skipNewlines();
      _nextToken();
      _skipCurrentNewlines();

      String key;
      if (_curTokenIs(TokenType.string) || _curTokenIs(TokenType.ident)) {
        key = _curToken.literal;
      } else {
        _addError('expected string or identifier as object key');
        return null;
      }

      _skipNewlines();
      if (!_expectPeek(TokenType.colon)) return null;

      _skipNewlines();
      _nextToken();
      _skipCurrentNewlines();
      final value = _parseExpression(_lowest);
      if (value == null) return null;
      pairs[key] = value;

      _skipNewlines();
      if (!_peekTokenIs(TokenType.rbrace) && !_peekTokenIs(TokenType.comma)) {
        // Allow newline as implicit separator
        if (_peekTokenIs(TokenType.newline)) {
          _skipNewlines();
        } else if (!_peekTokenIs(TokenType.rbrace)) {
          _addError('expected , or } in object literal');
          return null;
        }
      } else if (_peekTokenIs(TokenType.comma)) {
        _nextToken(); // consume comma
        _skipNewlines();
      }
    }

    _skipNewlines();
    if (!_expectPeek(TokenType.rbrace)) return null;

    return ObjectLiteral(token, pairs);
  }

  Expression? _parseFunctionLiteral() {
    final token = _curToken;
    if (!_expectPeek(TokenType.lparen)) return null;
    final parameters = _parseFunctionParameters();
    if (parameters == null) return null;
    if (!_expectPeek(TokenType.lbrace)) return null;
    final body = _parseBlockStatement();
    return FunctionLiteral(token, parameters, body);
  }

  List<Identifier>? _parseFunctionParameters() {
    final identifiers = <Identifier>[];

    if (_peekTokenIs(TokenType.rparen)) {
      _nextToken();
      return identifiers;
    }

    _nextToken();
    identifiers.add(Identifier(_curToken, _curToken.literal));

    while (_peekTokenIs(TokenType.comma)) {
      _nextToken();
      _nextToken();
      identifiers.add(Identifier(_curToken, _curToken.literal));
    }

    if (!_expectPeek(TokenType.rparen)) return null;

    return identifiers;
  }

  Expression? _parseInfixExpression(Expression left) {
    final token = _curToken;
    final operator = _curToken.literal;
    final precedence = _curPrecedence();
    _nextToken();
    final right = _parseExpression(precedence);
    if (right == null) return null;
    return BinaryExpr(token, left, operator, right);
  }

  Expression? _parseElvisExpression(Expression left) {
    final token = _curToken;
    _nextToken();
    final defaultValue = _parseExpression(_elvis);
    if (defaultValue == null) return null;
    return ElvisExpr(token, left, defaultValue);
  }

  Expression? _parsePropertyAccess(Expression left) {
    final token = _curToken;
    if (!_expectPeek(TokenType.ident)) return null;
    final property = Identifier(_curToken, _curToken.literal);
    return PropertyAccessExpr(token, left, property);
  }

  Expression? _parseSafeAccess(Expression left) {
    final token = _curToken;
    if (!_expectPeek(TokenType.ident)) return null;
    final property = Identifier(_curToken, _curToken.literal);
    return SafeAccessExpr(token, left, property);
  }

  Expression? _parseCallExpression(Expression function) {
    final token = _curToken;
    final arguments = _parseCallArguments();
    if (arguments == null) return null;
    return CallExpr(token, function, arguments);
  }

  List<Expression>? _parseCallArguments() {
    final args = <Expression>[];

    if (_peekTokenIs(TokenType.rparen)) {
      _nextToken();
      return args;
    }

    _nextToken();
    final exp = _parseExpression(_lowest);
    if (exp == null) return null;
    args.add(exp);

    while (_peekTokenIs(TokenType.comma)) {
      _nextToken();
      _nextToken();
      final exp = _parseExpression(_lowest);
      if (exp == null) return null;
      args.add(exp);
    }

    if (!_expectPeek(TokenType.rparen)) return null;

    return args;
  }

  Expression? _parseIndexExpression(Expression left) {
    final token = _curToken;
    _nextToken();
    final index = _parseExpression(_lowest);
    if (index == null) return null;

    if (!_expectPeek(TokenType.rbracket)) return null;

    return IndexExpr(token, left, index);
  }
}
