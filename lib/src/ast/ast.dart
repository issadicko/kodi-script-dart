/// KodiScript Abstract Syntax Tree (AST) node definitions.
library;

import '../token/token.dart';

/// Base class for all AST nodes.
sealed class Node {
  String tokenLiteral();
}

/// Represents a statement node.
sealed class Statement extends Node {}

/// Represents an expression node.
sealed class Expression extends Node {}

/// Function declaration: function name(params) { body }
class FunctionDeclaration extends Statement {
  final Token token;
  final Identifier name;
  final List<Identifier> parameters;
  final BlockStatement body;

  FunctionDeclaration(this.token, this.name, this.parameters, this.body);

  @override
  String tokenLiteral() => token.literal;
}

/// Program is the root node of every AST.
class Program extends Node {
  final List<Statement> statements;

  Program([List<Statement>? statements]) : statements = statements ?? [];

  @override
  String tokenLiteral() => statements.isNotEmpty ? statements.first.tokenLiteral() : '';
}

/// Variable declaration: let x = expr
class VarDecl extends Statement {
  final Token token;
  final Identifier name;
  final Expression value;

  VarDecl(this.token, this.name, this.value);

  @override
  String tokenLiteral() => token.literal;
}

/// Assignment: x = expr
class Assignment extends Statement {
  final Token token;
  final Identifier name;
  final Expression value;

  Assignment(this.token, this.name, this.value);

  @override
  String tokenLiteral() => token.literal;
}

/// Expression statement wraps an expression.
class ExpressionStatement extends Statement {
  final Token token;
  final Expression expression;

  ExpressionStatement(this.token, this.expression);

  @override
  String tokenLiteral() => token.literal;
}

/// If statement: if (condition) { consequence } else { alternative }
class IfStatement extends Statement {
  final Token token;
  final Expression condition;
  final BlockStatement consequence;
  final BlockStatement? alternative;

  IfStatement(this.token, this.condition, this.consequence, [this.alternative]);

  @override
  String tokenLiteral() => token.literal;
}

/// Block of statements: { ... }
class BlockStatement extends Statement {
  final Token token;
  final List<Statement> statements;

  BlockStatement(this.token, [List<Statement>? statements])
      : statements = statements ?? [];

  @override
  String tokenLiteral() => token.literal;
}

/// Return statement: return [expr]
class ReturnStatement extends Statement {
  final Token token;
  final Expression? value;

  ReturnStatement(this.token, [this.value]);

  @override
  String tokenLiteral() => token.literal;
}

/// For statement: for (variable in iterable) { body }
class ForStatement extends Statement {
  final Token token;
  final Identifier variable;
  final Expression iterable;
  final BlockStatement body;

  ForStatement(this.token, this.variable, this.iterable, this.body);

  @override
  String tokenLiteral() => token.literal;
}

/// While statement: while (condition) { body }
class WhileStatement extends Statement {
  final Token token;
  final Expression condition;
  final BlockStatement body;

  WhileStatement(this.token, this.condition, this.body);

  @override
  String tokenLiteral() => token.literal;
}

/// Break statement: break
class BreakStatement extends Statement {
  final Token token;

  BreakStatement(this.token);

  @override
  String tokenLiteral() => token.literal;
}

/// Continue statement: continue
class ContinueStatement extends Statement {
  final Token token;

  ContinueStatement(this.token);

  @override
  String tokenLiteral() => token.literal;
}

/// Try/catch statement: try { body } catch (e) { catchBlock }
class TryStatement extends Statement {
  final Token token;
  final BlockStatement body;
  final Identifier? catchVar;
  final BlockStatement catchBlock;

  TryStatement(this.token, this.body, this.catchVar, this.catchBlock);

  @override
  String tokenLiteral() => token.literal;
}

/// Array destructuring: let [a, b] = expr
class ArrayDestructure extends Statement {
  final Token token;
  final List<Identifier> names;
  final Expression value;

  ArrayDestructure(this.token, this.names, this.value);

  @override
  String tokenLiteral() => token.literal;
}

/// Object destructuring: let {a, b} = expr
class ObjectDestructure extends Statement {
  final Token token;
  final List<Identifier> names;
  final Expression value;

  ObjectDestructure(this.token, this.names, this.value);

  @override
  String tokenLiteral() => token.literal;
}

/// Variable identifier.
class Identifier extends Expression {
  final Token token;
  final String value;

  Identifier(this.token, this.value);

  @override
  String tokenLiteral() => token.literal;
}

/// Numeric literal.
class NumberLiteral extends Expression {
  final Token token;
  final double value;

  NumberLiteral(this.token, this.value);

  @override
  String tokenLiteral() => token.literal;
}

/// String literal.
class StringLiteral extends Expression {
  final Token token;
  final String value;

  StringLiteral(this.token, this.value);

  @override
  String tokenLiteral() => token.literal;
}

/// String template: "Hello ${name}!"
class StringTemplate extends Expression {
  final Token token;
  final List<Expression> parts;

  StringTemplate(this.token, this.parts);

  @override
  String tokenLiteral() => token.literal;
}

/// Boolean literal (true/false).
class BooleanLiteral extends Expression {
  final Token token;
  final bool value;

  BooleanLiteral(this.token, this.value);

  @override
  String tokenLiteral() => token.literal;
}

/// Null literal.
class NullLiteral extends Expression {
  final Token token;

  NullLiteral(this.token);

  @override
  String tokenLiteral() => token.literal;
}

/// Array literal: [elem1, elem2, ...]
class ArrayLiteral extends Expression {
  final Token token;
  final List<Expression> elements;

  ArrayLiteral(this.token, this.elements);

  @override
  String tokenLiteral() => token.literal;
}

/// Object literal: {key: value, ...}
class ObjectLiteral extends Expression {
  final Token token;
  final Map<String, Expression> pairs;

  ObjectLiteral(this.token, this.pairs);

  @override
  String tokenLiteral() => token.literal;
}

/// Index expression: left[index]
class IndexExpr extends Expression {
  final Token token;
  final Expression left;
  final Expression index;

  IndexExpr(this.token, this.left, this.index);

  @override
  String tokenLiteral() => token.literal;
}

/// Binary expression: left op right
class BinaryExpr extends Expression {
  final Token token;
  final Expression left;
  final String operator;
  final Expression right;

  BinaryExpr(this.token, this.left, this.operator, this.right);

  @override
  String tokenLiteral() => token.literal;
}

/// Unary expression: op expr
class UnaryExpr extends Expression {
  final Token token;
  final String operator;
  final Expression right;

  UnaryExpr(this.token, this.operator, this.right);

  @override
  String tokenLiteral() => token.literal;
}

/// Safe access: obj?.property
class SafeAccessExpr extends Expression {
  final Token token;
  final Expression obj;
  final Identifier property;

  SafeAccessExpr(this.token, this.obj, this.property);

  @override
  String tokenLiteral() => token.literal;
}

/// Elvis expression: expr ?: default
class ElvisExpr extends Expression {
  final Token token;
  final Expression left;
  final Expression defaultValue;

  ElvisExpr(this.token, this.left, this.defaultValue);

  @override
  String tokenLiteral() => token.literal;
}

/// Ternary expression: condition ? consequent : alternative
class TernaryExpr extends Expression {
  final Token token;
  final Expression condition;
  final Expression consequent;
  final Expression alternative;

  TernaryExpr(this.token, this.condition, this.consequent, this.alternative);

  @override
  String tokenLiteral() => token.literal;
}

/// Spread expression: ...expr (used in array literals and call arguments)
class SpreadExpr extends Expression {
  final Token token;
  final Expression value;

  SpreadExpr(this.token, this.value);

  @override
  String tokenLiteral() => token.literal;
}

/// Property access: obj.property
class PropertyAccessExpr extends Expression {
  final Token token;
  final Expression obj;
  final Identifier property;

  PropertyAccessExpr(this.token, this.obj, this.property);

  @override
  String tokenLiteral() => token.literal;
}

/// Function literal: fn(x, y) { ... }
class FunctionLiteral extends Expression {
  final Token token;
  final List<Identifier> parameters;
  final BlockStatement body;

  FunctionLiteral(this.token, this.parameters, this.body);

  @override
  String tokenLiteral() => token.literal;
}

/// Function call: func(args...)
class CallExpr extends Expression {
  final Token token;
  final Expression function;
  final List<Expression> arguments;

  CallExpr(this.token, this.function, this.arguments);

  @override
  String tokenLiteral() => token.literal;
}
