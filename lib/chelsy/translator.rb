module Chelsy

  class Translator
    def translate(node)
      case node

      # Expressions
      when Symbol
        translate_ident(node)
      when Constant::Integral
        translate_integral(node)
      when Constant::String
        translate_string(node)
      when FunctionCall
        translate_function_call(node)

      # Statements
      when EmptyStmt
        translate_empty_stmt(node)
      when ExprStmt
        translate_expr_stmt(node)

      else
        raise ArgumentError, "Unrecognized AST node: #{node.inspect}"
      end
    end

    protected

    def translate_ident(node)
      node.to_s
    end

    # = Expressions

    def translate_integral(node)
      integer_prefix(node) + node.value.to_s(node.base) + integer_suffix(node)
    end

    def translate_string(node)
      if node.wide?
        'L' + node.value.dump
      else
        node.value.dump
      end
    end

    def translate_function_call(node)
      callee = expr(node.callee)
      args = node.args.map {|a| expr(a) }.join(', ')

      "#{callee}(#{args})"
    end

    # = Statements

    def translate_empty_stmt(node)
      ';'
    end

    def translate_expr_stmt(node)
      translate(node.expr) + ';'
    end

    private

    # Expression: parenthesize if needed
    def expr(node)
      # TODO Pointer expression should be parenthesized.
      translate(node)
    end

    def integer_prefix(node)
      case node.base
      when 8
        "0"
      when 10
        ""
      when 16
        "0x"
      else
        raise ArgumentError, "Unsupported radix: #{node.base}"
      end
    end

    def integer_suffix(node)
      suffix = case node
      when Constant::Long
        "l"
      when Constant::LongLong
        "ll"
      else
        ""
      end

      if node.unsigned?
        "#{suffix}u"
      else
        suffix
      end
    end
  end

end
