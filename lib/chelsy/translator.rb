module Chelsy

  class Translator
    attr_accessor :indent_string, :indent_level

    def initialize()
      @indent_string = "    "
      @indent_level = 0
    end

    def translate(node)
      case node

      # Types
      when Type
        translate_type(node)

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
      when Return
        translate_return(node)
      when Block
        translate_block(node)

      # Definition
      when Function
        translate_function(node)
      when Param
        translate_function_param(node)

      else
        raise ArgumentError, "Unrecognized AST node: #{node.inspect}"
      end
    end

    protected

    def translate_ident(node)
      node.to_s
    end

    # = Types

    def translate_type(ty)
      translate_typed_name(ty)
    end

    def translate_typed_name(ty, name=nil)
      case ty
      when Types::Derived
        # TODO
        raise NotImplementedError
      else
        translate_primitive_type(ty).tap do |src|
          src << " #{name}" if name
        end
      end
    end

    def translate_primitive_type(ty)
      case ty
      when :void; 'void'
      when Types::Char; 'char'
      when Types::Short; 'short'
      when Types::Integral
        translate_integral_type(ty)
      end.tap do |src|
        # qualifiers
        src.insert(0, 'const ') if ty.const?
        src.insert(0, 'volatile ') if ty.volatile?
        src.insert(0, 'restrict ') if ty.restrict?
      end
    end

    def translate_integral_type(ty)
      case ty
      when Types::Char;     'char'
      when Types::Short;    'short'
      when Types::Int;      'int'
      when Types::Long;     'long'
      when Types::LongLong; 'long long'
      end.tap do |src|
        src.insert(0, 'unsigned ') if ty.unsigned?
      end
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
      indent << ';'
    end

    def translate_expr_stmt(node)
      indent << translate(node.expr) << ';'
    end

    def translate_return(node)
      if node.expr
        indent << 'return ' << translate(node.expr) << ';'
      else
        indent << 'return;'
      end
    end

    def translate_block(node)
      @indent_level += 1
      body = node.map {|item| translate(item) }.join("\n")
      @indent_level -= 1

      "#{indent}{\n#{body}\n#{indent}}"
    end

    # = Statements

    def translate_function(node)
      params = node.params.map {|p| translate(p) }.join(', ')
      "#{translate node.return_type} #{translate node.name}(#{params}) #{translate(node.body)}"
    end

    def translate_function_param(node)
      translate_typed_name(node.type, node.name)
    end

    private

    def indent
      @indent_string * @indent_level
    end

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
