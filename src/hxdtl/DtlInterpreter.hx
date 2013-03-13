package hxdtl;

import haxe.ds.StringMap;
import hxdtl.Ast;

class DtlInterpreter
{
	public function new()
	{
	}

	public function run(ast: Ast, context: Map<String, Dynamic>): String
	{
		return evalExpressions(ast.body, context);
	}

	function evalExpressions(expressions: Array<AstExpr>, context)
	{
		var result = new StringBuf();
		for(expr in expressions)
		{
			var s = evalExpression(expr, context);
			if (s != null)
				result.add(s);
		}

		return result.toString();
	}

	function evalExpression<T>(expr, context): T
	{
		return switch expr
		{
			case NumberLiteral(n): Std.parseInt(n);
			case StringLiteral(s): s;
			case Text(text): text;
			case Variable(key): context.get(key);
			case attrExpr = Attribute(_, _): evalAttribute(attrExpr, context);
			case If(eCond, eBody): evalIf(eCond, eBody, [], context);
			case IfElse(eCond, eBodyIf, eBodyElse): evalIf(eCond, eBodyIf, eBodyElse, context);
			case BinOp(op, e1, e2): evalBinOp(op, e1, e2, context);
			case _: null;
		}
	}

	function evalAttribute(expr, context)
	{
		return switch expr
		{
			case Attribute(Variable(key1), key2):
				cast(context.get(key1), StringMap<Dynamic>).get(key2);
			case Attribute(attr = Attribute(_, _), key):
				cast(evalAttribute(attr, context), StringMap<Dynamic>).get(key);
			case _:
				null;
		}
	}

	function evalIf(eCond, eBodyIf, eBodyElse, context)
	{
		return evalExpressions(
				(evalExpression(eCond, context)) ? eBodyIf : eBodyElse,
				context);
	}

	function evalBinOp(op, e1, e2, context)
	{
		return switch op
		{
			case Equal: evalExpression(e1, context) == evalExpression(e2, context);
			case NotEqual: evalExpression(e1, context) != evalExpression(e2, context);
			case Greater: evalExpression(e1, context) > evalExpression(e2, context);
			case GreaterOrEqual: evalExpression(e1, context) >= evalExpression(e2, context);
			case Less: evalExpression(e1, context) < evalExpression(e2, context);
			case LessOrEqual: evalExpression(e1, context) <= evalExpression(e2, context);
		}
	}
}