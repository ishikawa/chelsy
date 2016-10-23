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
      when Operator::Unary
        translate_unary_operator(node)
      when Operator::Binary
        translate_binary_operator(node)

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
      when Declaration, Typedef
        translate_declaration(node)
      when Function
        translate_function(node)
      when Param
        translate_param(node)

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
      when Type::Pointer
        translate_pointer_type(ty, name)
      when Type::Array
        translate_array_type(ty, name)
      when Type::Function
        translate_function_type(ty, name)
      when Type::Derived
        raise NotImplementedError
      else
        translate_primitive_type(ty, name)
      end
      .tap do |src|
        src.strip!
      end
    end

    def translate_pointer_type(ty, name=nil)
      pointee = ty
      src = ''

      while pointee.is_a?(Type::Pointer)
        qualifier = '*'
        qualifier << 'const '    if pointee.const?
        qualifier << 'volatile ' if pointee.volatile?
        qualifier << 'restrict ' if pointee.restrict?

        pointee = pointee.pointee
        src.insert 0, qualifier
      end

      src.strip!
      src << name.to_s if name

      case pointee
      when Type::Function
        translate_function_type(pointee, "(#{src})")
      when Type::Array
        translate_array_type(pointee, "(#{src})")
      else
        translate_typed_name(pointee, src)
      end
    end

    def translate_array_type(ty, name=nil)
      element_type = ty
      src = ''

      while element_type.is_a?(Type::Array)
        subscription = '['
        subscription << 'const ' if element_type.const?
        subscription << 'volatile ' if element_type.volatile?
        subscription << 'static ' if element_type.static?
        subscription << translate(element_type.size) if element_type.size
        subscription << ']'

        element_type = element_type.element_type
        src.insert 0, subscription
      end

      src.insert 0, name.to_s if name

      element_type = coerce_func_ptr(element_type)
      translate_typed_name(element_type, src)
        .gsub(/\s+\[/, "[") # "a []" --> "a[]"
    end

    def translate_function_type(ty, name=nil)
      params = ''.tap do |src|
        src << '('
        src << ty.params.map {|p| translate(coerce_func_ptr(p)) }.join(', ')
        src << ')'
      end

      return_type = ty.return_type
      return_type = coerce_func_ptr(return_type)

      ret_src = translate(return_type)

      if return_type.is_a?(Type::Pointer) && return_type.termination_type.is_a?(Type::Function)
        ret_src.gsub(/\*(.*?)\)/) do
          "*#{$1}#{name}#{params})"
        end
      else
        ret_src << ' ' unless pointer_asterisk?(return_type)
        if name
          ret_src << name.to_s
        else
          ret_src << '(*)'
        end
        ret_src << params
      end
    end

    def translate_primitive_type(ty, name=nil)
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
      end
      .tap do |src|
        src << " #{name}" if name
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

    def translate_unary_operator(node)
      case node
      when Operator::Subscription
        translate_subscription(node)
      when Operator::Call
        translate_function_call(node)
      when Operator::Access
        translate_member_access(node)
      else
        if node.class.postfix?
          translate_postfix_operator(node)
        else
          translate_prefix_operator(node)
        end
      end
    end

    def translate_subscription(node)
      subscriptee = expr(node.subscriptee, node)
      index = translate(node.index)

      "#{subscriptee}[#{index}]"
    end

    def translate_function_call(node)
      callee = expr(node.callee, node)
      args = node.args.map {|a| translate(a) }.join(', ')

      "#{callee}(#{args})"
    end

    def translate_member_access(node)
      object = expr(node.object, node)
      name = translate(node.name)

      "#{object}#{node.class.operator}#{name}"
    end

    def translate_prefix_operator(node)
      operand = expr(node.operand, node)
      "#{node.class.operator}#{operand}"
    end

    def translate_postfix_operator(node)
      operand = expr(node.operand, node)
      "#{operand}#{node.class.operator}"
    end

    def translate_binary_operator(node)
      lhs = expr(node.lhs, node)
      rhs = expr(node.rhs, node)
      "#{lhs} #{node.class.operator} #{rhs}"
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

    # = Declaration
    def translate_declaration(node)
      [
        node.storage.to_s,
        translate_typed_name(node.type, node.name),
      ]
      .join(' ')
      .strip << ';'
    end

    # = Function
    def translate_function(node)
      params = node.params.map {|p| translate(p) }.join(', ')

      [
        node.storage.to_s,
        translate(node.return_type),
        "#{translate node.name}(#{params})",
        translate(node.body),
      ]
      .join(' ')
      .strip
    end

    def translate_param(node)
      ty = coerce_func_ptr(node.type)
      translate_typed_name(ty, node.name)
    end

    # = Directives
    def translate_include(node)
      if node.system?
        "#include <#{node.location}>"
      else
        %Q{#include "#{node.location}"}
      end
    end

    private

    def indent
      @indent_string * @indent_level
    end

    # Parenthesize if `node` has lower precedence than `parent` node.
    def expr(node, parent)
      expr = translate(node)

      if node.is_a?(Operator::Base) && node.class.precedence < parent.class.precedence
        "(#{expr})"
      else
        expr
      end
    end

    def pointer_asterisk?(ty)
      case ty
      when Type::Pointer
        !ty.qualified?
      else
        false
      end
    end

    # In some situation, function type shall be pointer to function type
    def coerce_func_ptr(node)
      case node
      when Type::Function
        Type::Pointer.new(node)
      else
        node
      end
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
