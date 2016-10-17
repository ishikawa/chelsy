module Chelsy

  class Translator
    attr_accessor :indent_string, :indent_level

    DEFAULT_INDENT_STRING = '    '.freeze

    def initialize()
      @indent_string = DEFAULT_INDENT_STRING
      @indent_level = 0
    end

    def translate(node)
      case node
      when Element
        translate_element(node)
      when Node
        translate_node(node)
      when Symbol
        translate_ident(node)
      when String
        translate_fragment(node)
      else
        raise ArgumentError, "Unrecognized AST node: #{node.inspect}"
      end
    end

    protected

    def translate_node(node)
      case node
      # Fragment
      when Fragment
        translate_fragment(node)
      else
        raise ArgumentError, "Unrecognized AST node: #{node.inspect}"
      end
    end

    def translate_fragment(node)
      case node
      when String
        node.to_s
      when Directive::Include
        translate_include(node)
      else
        raise ArgumentError, "Unrecognized AST fragment: #{node.inspect}"
      end
    end

    def translate_element(node)
      case node
      # Document
      when Document
        translate_document(node)

      # Types
      when Type::Base
        translate_type(node)

      # Expressions
      when Constant::Integral
        translate_integral(node)
      when Constant::String
        translate_string(node)
      when Subscription
        translate_subscription(node)
      when FunctionCall
        translate_function_call(node)
      when MemberAccess
        translate_member_access(node)
      when PostfixIncrement
        translate_postfix_increment(node)
      when PostfixDecrement
        translate_postfix_decrement(node)

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
        raise ArgumentError, "Unrecognized AST element: #{node.inspect}"
      end
      .tap do |src|
        # Fragments
        unless node.fragments.empty?
          src.insert 0, "\n"
          src.insert 0, node.fragments.map {|f| translate_fragment(f) }.join("\n")
        end
        unless node.post_fragments.empty?
          src << "\n"
          src << node.post_fragments.map {|f| translate_fragment(f) }.join("\n")
        end
      end
    end

    def translate_document(node)
      node.map {|nd| translate(nd) }.join('')
    end

    def translate_ident(node)
      node.to_s
    end

    # = Types

    def translate_type(ty)
      translate_typed_name(ty)
    end

    def translate_typed_name(ty, name=nil)
      case ty
      when Type::Derived
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
      when Type::Char; 'char'
      when Type::Short; 'short'
      when Type::Integral
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
      when Type::Char;     'char'
      when Type::Short;    'short'
      when Type::Int;      'int'
      when Type::Long;     'long'
      when Type::LongLong; 'long long'
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

    def translate_subscription(node)
      subscriptee = expr(node.subscriptee)
      index = translate(node.index)

      "#{subscriptee}[#{index}]"
    end

    def translate_function_call(node)
      callee = expr(node.callee)
      args = node.args.map {|a| expr(a) }.join(', ')

      "#{callee}(#{args})"
    end

    def translate_member_access(node)
      object = expr(node.object)
      name = translate(node.name)

      if node.indirect?
        "#{object}->#{name}"
      else
        "#{object}.#{name}"
      end
    end

    def translate_postfix_increment(node)
      "#{expr(node.expr)}++"
    end

    def translate_postfix_decrement(node)
      "#{expr(node.expr)}--"
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

    # = Directives
    def translate_include(node)
      if node.system?
        "#include <#{node.location}>"
      else
        %Q{#include "#{node.location}"}
      end
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

    # Parenthesize if needed.
    def expr(node)
      # TODO Parenthesize if `node` has lower precedence.
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
