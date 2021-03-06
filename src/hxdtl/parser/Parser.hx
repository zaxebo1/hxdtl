package hxdtl.parser;

import hxdtl.parser.Tokens;
import hxdtl.parser.Ast;

class Parser extends hxparse.Parser<Lexer.CustomTokenSource, Token> implements hxparse.ParserBuilder
{
	public function new()
	{
		super(null);
	}

	public function parse(input: String)
	{
		var lexer = new Lexer(byte.ByteData.ofString(input));
		var tokenSource = new Lexer.CustomTokenSource(lexer, Lexer.tok);

		lexer.lexerStream = tokenSource;
		stream = tokenSource;

		return loop(parseElement);
	}

	function any<T>(functions: Array<Void->T>): T
	{
		for(f in functions)
		{
			var expr = switch stream
			{
				case [e = f()]: e;
				case _: null;
			}

			if (expr != null)
				return expr;
		}

		return null;
	}

	function collect<T>(acc: Array<T>, item: T)
	{
		acc.push(item);
		return acc;
	}

	function loop<T>(f:Void->T): Array<T>
	{
		return loopAndFill(f, []);
	}

	function loopAndFill<T>(f:Void->T, acc:Array<T>): Array<T>
	{
		return switch stream
		{
			case [item = f(), list = loopAndFill(f, collect(acc, item))]:
				list;
			case _: acc;
		}
	}

	function inVar<T>(f: Void->T): Null<T>
	{
		return switch stream
		{
			case [{tok: VarOpen}, expr = f(), {tok: VarClose}]:
				expr;
		}
	}

	function parseElement() return switch stream
	{
		case [{tok: Text(t)}]: Expr.Text(t);
		case [value = inVar(parseValue)]: value;
		case [ifExpr = parseIfBlock()]: ifExpr;
		case [forExpr = parseForBlock()]: forExpr;
		case [commentExpr = parseCommentBlock()]: commentExpr;
		case [filterExpr = parseFilterBlock()]: filterExpr;
	}

	function parseValue()
	{
		var value = switch stream
		{
			case [variable = parseVariable()]: variable;
			case [literal = parseLiteral()]: literal;
		};

		return switch stream
		{
			case [{tok: Pipe}, filter = parseFilter()]: Expr.ApplyFilter([value], filter);
			case _: value;
		};
	}

	function parseFilter() return switch stream
	{
		case [{tok: Identifier(filterName)}]: switch stream
		{
			case [{tok: DoubleDot}, arg = any([parseLiteral, parseVariable])]:
				Ast.Filter.Arg(filterName, arg);
			case _: Ast.Filter.NoArgs(filterName);
		}
	}

	function parseLiteral() return switch stream
	{
		case [{tok: NumberLiteral(n)}]: Expr.NumberLiteral(n);
		case [{tok: StringLiteral(s)}]: Expr.StringLiteral(s);
	}

	function parseVariable() return switch stream
	{
		case [{tok: Identifier(id)}]: return switch stream
		{
			case [{tok: Dot}, v = parseVariable()]: Expr.Attribute(id, v);
			case _: Expr.Variable(id);
		}
	}

	function parseIfBlock() return switch stream
	{
		case [{tok: Kwd(If)}]: parseIfBlockBody();
	}

	function parseIfBlockBody() return switch stream
	{
		case [ifCond = parseIfCondition(), ifBody = loop(parseElement)]: switch stream
		{
			case [{tok: Kwd(Endif)}]:
				Expr.If(ifCond, ifBody);
			case [{tok: Kwd(Else)}, elseBody = loop(parseElement), {tok: Kwd(Endif)}]:
				Expr.IfElse(ifCond, ifBody, elseBody);
			case [{tok: Kwd(Elif)}]:
				Expr.IfElse(ifCond, ifBody, [parseIfBlockBody()]);
		}
	}

	function parseIfCondition() return switch stream
	{
		case [part = parseIfConditionPart()]: switch stream
		{
			case [op1 = parseBinOp1()]: Expr.BinOp(op1, part, parseIfCondition());
			case _: part;
		}
	}

	function parseIfConditionPart() return switch stream
	{
		case [v1 = parseValue()]: switch stream
		{
			case [op2 = parseBinOp2(), v2 = parseValue()]: Expr.BinOp(op2, v1, v2);
			case _: Expr.NullOp(v1);
		}
		case [op = parseUnOp(), v = parseValue()]: Expr.UnOp(op, v);
	}

	function parseForBlock() return switch stream
	{
		case [{tok: Kwd(For)}, {tok: Identifier(id)}, {tok: Kwd(In)}, {tok: Identifier(idList)},
			body = loop(parseElement)]: switch stream
		{
			case [{tok: Kwd(Endfor)}]:
				Expr.For(id, idList, body);
			case [{tok: Kwd(Empty)}, emptyBody = loop(parseElement), {tok: Kwd(Endfor)}]:
				Expr.ForEmpty(id, idList, body, emptyBody);
		}
	}

	function parseCommentBlock() return switch stream
	{
		case [{tok: Comment(text)}]: Comment(text);
		case [{tok: Kwd(Comment)}, {tok: Text(text)}, {tok: Kwd(Endcomment)}]: Comment(text);
	}

	function parseFilterBlock() return switch stream
	{
		case [{tok: Kwd(Filter)}, filter = parseFilter(), filterBody = loop(parseElement), {tok: Kwd(Endfilter)}]:
			Expr.ApplyFilter(filterBody, filter);
	}

	function parseUnOp() return switch stream
	{
		case [{tok: Kwd(Not)}]: Not;
	}

	function parseBinOp1() return switch stream
	{
		case [{tok: Kwd(And)}]: And;
		case [{tok: Kwd(Or)}]: Or;
	}

	function parseBinOp2() return switch stream
	{
		case [{tok: Op(">")}]: Greater;
		case [{tok: Op(">=")}]: GreaterOrEqual;
		case [{tok: Op("<")}]: Less;
		case [{tok: Op("<=")}]: LessOrEqual;
		case [{tok: Op("==")}]: Equal;
		case [{tok: Op("!=")}]: NotEqual;
	}
}