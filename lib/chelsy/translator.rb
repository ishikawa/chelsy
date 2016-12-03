module Chelsy

  class Translator
    attr_accessor :indent_string, :indent_level

    DEFAULT_INDENT_STRING = '    '.freeze

    def initialize(indent_string: DEFAULT_INDENT_STRING, indent_level: 0)
      @indent_string = indent_string
      @indent_level = indent_level
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
      when Comment::Multi
        translate_comment_multi(node)
      when Comment::Single
        translate_comment_single(node)
      when Directive::Include
        translate_include(node)
      when Directive::Define
        translate_define(node)
      when Directive::Undef
        translate_undef(node)
      when Directive::If
        translate_if_directive(node)
      when Directive::ElseIf
        translate_elif_directive(node)
      when Directive::Else
        translate_else_directive(node)
      when Directive::EndIf
        translate_endif_directive(node)
      when Directive::Line
        translate_line_directive(node)
      when Directive::Pragma
        translate_pragma_directive(node)
      else
        raise ArgumentError, "Unrecognized AST fragment: #{node.inspect}"
      end
    end

    def translate_element(node)
      case node
      when Raw
        node.code

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
      when Operator::Conditional
        translate_ternary_conditional(node)
      when Macro
        translate_macro(node)

      # Statements
      when EmptyStmt
        translate_empty_stmt(node)
      when If
        translate_if(node)
      when Switch
        translate_switch(node)
      when While
        translate_while(node)
      when DoWhile
        translate_do_while(node)
      when For
        translate_for(node)
      when Break
        translate_break(node)
      when Continue
        translate_continue(node)
      when Case
        translate_case(node)
      when Labeled
        translate_labeled(node)
      when Goto
        translate_goto(node)
      when Return
        translate_return(node)
      when Block
        translate_block(node)

      # Definition
      when Declaration, Typedef
        translate_declaration(node)
      when BitField
        translate_bit_field(node)
      when Function
        translate_function(node)
      when Param
        translate_param(node)
      when Initializer
        translate_initializer(node)
      when InitializerList
        translate_initializer_list(node)
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
      node.map {|nd| translate(nd) }
      .join("\n\n")
      .tap do |src|
        # Document's fragments and body should be separated by empty line for
        # source code readability.
        src.insert(0, "\n") unless src.empty? || node.fragments.empty?
      end
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
      when Type::Struct
        translate_struct_type(ty, name)
      when Type::Union
        translate_union_type(ty, name)
      when Type::Enum
        translate_enum_type(ty, name)
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
      # qualifiers
      src = ''.tap do |qualifier|
        qualifier << '*'
        qualifier << 'const '    if ty.const?
        qualifier << 'volatile ' if ty.volatile?
        qualifier << 'restrict ' if ty.restrict?
      end

      # name
      src << name.to_s

      # parenthesize if needed
      case ty.pointee
      when Type::Function, Type::Array
        translate_typed_name(ty.pointee, "(#{src})")
      else
        translate_typed_name(ty.pointee, src)
      end
    end

    def translate_array_type(ty, name=nil)
      src = name.to_s.tap do |subscript|
        subscript << '['
        subscript << 'const ' if ty.const?
        subscript << 'volatile ' if ty.volatile?
        subscript << 'static ' if ty.static?
        subscript << translate(ty.size) if ty.size
        subscript << ']'
      end

      translate_typed_name(coerce_func_ptr(ty.element_type), src)
    end

    def translate_function_type(ty, name=nil)
      src = name.to_s.tap do |params|
        params << '('
        params << ty.params.map {|p| translate(coerce_func_ptr(p)) }.join(', ')
        params << ')'
      end

      translate_typed_name(coerce_func_ptr(ty.return_type), src)
    end

    def translate_struct_type(ty, name=nil)
      translate_taggable_type_members(ty, name)
    end

    def translate_union_type(ty, name=nil)
      translate_taggable_type_members(ty, name)
    end

    def translate_enum_type(ty, name=nil)
      translate_taggable_type_members(ty, name)
    end

    def translate_primitive_type(ty, name=nil)
      src = case ty
            when :void; 'void'
            when Type::Integral
              translate_integral_type(ty)
            else
              translate_numeric_type(ty)
            end
      case ty
      when Type::Base;
        src.insert(0, 'const ') if ty.const?
        src.insert(0, 'volatile ') if ty.volatile?
      end

      src.tap do |src|
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

    def translate_numeric_type(ty)
      case ty
      when Type::Bool;              '_Bool'
      when Type::Float;             'float'
      when Type::Double;            'double'
      when Type::LongDouble;        'long double'
      when Type::Complex;           '_Complex'
      when Type::FloatComplex;      'float _Complex'
      when Type::DoubleComplex;     'double _Complex'
      when Type::LongDoubleComplex; 'long double _Complex'
      else
        raise NotImplementedError
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
      when Operator::Cast
        translate_type_cast(node)
      when Operator::SizeOf
        translate_size_of(node)
      when Operator::Postfix
        translate_postfix_operator(node)
      when Operator::Prefix
        translate_prefix_operator(node)
      when Operator::Defined
        translate_defined_operator(node)
      else
        raise NotImplementedError, "Unrecognized unary operator: #{node.inspect}"
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

    def translate_type_cast(node)
      operand = expr(node.operand, node)
      "(#{translate node.type})#{operand}"
    end

    def translate_size_of(node)
      operand = translate(node.operand)
      "sizeof(#{operand})"
    end

    def translate_defined_operator(node)
      operand = translate(node.operand)
      "defined #{operand}"
    end

    def translate_binary_operator(node)
      lhs = expr(node.lhs, node)
      rhs = expr(node.rhs, node)

      case node
      when Operator::Comma
        "#{lhs}#{node.class.operator} #{rhs}"
      else
        "#{lhs} #{node.class.operator} #{rhs}"
      end
    end

    def translate_ternary_conditional(node)
      condition_expr = expr(node.condition, node)

      # Expression between `?` and `:` must be parenthesized.
      then_expr = case node.then
                  when Operator::Binary, Operator::Conditional
                    "(#{translate(node.then)})"
                  else
                    expr(node.then, node)
                  end
      else_expr = expr(node.else, node)

      "#{condition_expr} ? #{then_expr} : #{else_expr}"
    end

    def translate_macro(node)
      if node.args.nil?
        node.name.to_s
      else
        node.name.to_s.tap do |src|
          src << '('
          src << node.args.map(&method(:translate)).join(', ')
          src << ')'
        end
      end
    end

    # = Statements

    def translate_empty_stmt(node)
      ''
    end

    def translate_expr_stmt(node)
      translate(node.expr)
    end

    def translate_if(node)
      "if (#{translate node.condition}) #{translate node.then}".tap do |src|
        src << " else #{translate node.else}" if node.else
      end
    end

    def translate_switch(node)
      "switch (#{translate node.expr}) #{translate node.stmt}"
    end

    def translate_while(node)
      "while (#{translate node.condition}) #{translate node.body}"
    end

    def translate_do_while(node)
      "do #{translate node.body} while (#{translate node.condition})"
    end

    def translate_for(node)
      init = node.init ? translate(node.init) : ''
      cond = node.condition ? ' ' + translate(node.condition) : ''
      loop_expr = node.loop ? ' ' + translate(node.loop) : ''

      "for (#{init};#{cond};#{loop_expr}) #{translate node.body}"
    end

    def translate_break(node); 'break' end
    def translate_continue(node); 'continue' end

    def translate_goto(node)
      "goto #{node.label}"
    end

    # We need labeled statement to indent differently.
    def translate_case(node)
      [
        "case #{translate(node.expr)}",
        translate(node.stmt),
      ]
    end

    def translate_labeled(node)
      [
        node.label.to_s,
        translate(node.stmt),
      ]
    end

    def translate_return(node)
      if node.expr
        'return ' << translate(node.expr)
      else
        'return'
      end
    end

    def translate_block(node)
      translate_stmts_with_indent(node)
    end

    # = Declaration
    def translate_declaration(node)
      [
        node.storage.to_s,
        translate_typed_name(node.type, node.name),
      ]
      .tap {|src|
        unless node.init.nil?
          src << '='
          src << translate(node.init)
        end
      }
      .join(' ')
      .strip
    end

    def translate_designator(node)
      case node
      when IndexDesignator
        "[#{node.index}]"
      when MemberDesignator
        ".#{node.name}"
      else
        raise NotImplementedError, 'designator must be Index or Member'
      end
    end

    def translate_initializer(node)
      if node.designator
        [
          translate_designator(node.designator),
          '=',
          translate(node.value),
        ]
        .join(' ')
      else
        translate(node.value)
      end
    end

    def translate_initializer_list(node)
      node
      .map {|m| translate(m)}
      .join(', ')
      .insert( 0, '{ ')
      .insert(-1, ' }')
    end

    def translate_bit_field(node)
      if node.declaration
        "#{translate node.declaration} : #{translate node.bits}"
      else
        ": #{translate node.bits}"
      end
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

    # = Comment
    def translate_comment_multi(node)
      case node.lines.size
      when 0
        ""
      when 1
        "/* #{node.lines[0]} */"
      else
        src =
          node
            .lines
            .map {|line| "#{indent} * #{line}"}
            .join("\n")
        "/*\n#{src}\n#{indent} */"
      end
    end

    def translate_comment_single(node)
      "// #{node.body}"
    end

    # = Directives
    def translate_include(node)
      if node.system?
        "#include <#{node.location}>"
      else
        %Q{#include "#{node.location}"}
      end
    end

    def translate_define(node)
      "#define #{node.name}".tap do |src|
        if node.params
          src << '('
          src << node.params.map(&:to_s).join(", ")
          src << ')'
        end

        replacement = translate(node.replacement)
        unless replacement.empty?
          src << ' '
          src << replacement
        end
      end
    end

    def translate_undef(node)
      "#undef #{node.name}"
    end

    def translate_if_directive(node)
      "#if #{translate node.condition}"
    end

    def translate_elif_directive(node)
      "#elif #{translate node.condition}"
    end

    def translate_else_directive(node); "#else" end

    def translate_endif_directive(node); "#endif" end

    def translate_line_directive(node)
      "#line #{translate node.lineno}".tap do |src|
        src << " \"#{translate node.filename}\"" if node.filename
      end
    end

    def translate_pragma_directive(node)
      "#pragma #{translate node.pragma}"
    end

    private

    def indent(indent_level=nil)
      indent_level = @indent_level if indent_level.nil?
      @indent_string * indent_level
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

    def translate_taggable_type_members(ty, name=nil)
      [].tap do |buffer|
        buffer << 'const ' if ty.const?
        buffer << 'volatile ' if ty.volatile?
        buffer << case ty
                  when Type::Struct; 'struct'
                  when Type::Union;  'union'
                  when Type::Enum;   'enum'
                  end
        buffer << ty.tag if ty.tag
        buffer << name if name
      end
      .join(' ')
      .tap do |src|
        if ty.members
          src << ' ' << translate_taggable_members(ty.members)
        end
      end
    end

    def translate_taggable_members(members)
      case members
      when StructOrUnionMemberList
        translate_stmts_with_indent(members)
      when EnumMemberList
        translate_enum_members(members)
      else
        raise "Unrecognized members: #{members.inspect}"
      end
    end

    def translate_enum_members(members)
      @indent_level += 1

      lines = members.map do |item|
        case item
        when EnumMember
          if item.init
            "#{translate item.name} = #{translate item.init}"
          else
            "#{translate item.name}"
          end
        when Symbol
          "#{translate item}"
        else
          raise "Unrecognized enum member: #{item.inspect}"
        end
      end

      body = lines.map {|line| indent << line }.join(",\n")
      @indent_level -= 1

      "{\n#{body}\n#{indent}}"
    end

    def should_terminate_with_semicolon(node)
      case node
      when If
        if node.else
          should_terminate_with_semicolon(node.else)
        else
          should_terminate_with_semicolon(node.then)
        end
      when While, For
        should_terminate_with_semicolon(node.body)
      when Block
        false
      else
        true
      end
    end

    def translate_stmts_with_indent(node)
      @indent_level += 1

      lines = node.map do |item|
        src = translate(item)

        if Array === src && src.size == 2
          (label, stmt) = *src

          src = "#{indent(@indent_level-1)}#{label}:\n"
          src << "#{indent}#{stmt}"
        else
          src.insert 0, indent
        end

        # terminate ';' if needed
        src << ';' if should_terminate_with_semicolon(item)
        src
      end

      @indent_level -= 1

      body = lines.join("\n")

      "{\n#{body}\n#{indent}}"
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
