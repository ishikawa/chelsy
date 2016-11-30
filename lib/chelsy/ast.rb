require "chelsy/syntax"
require "forwardable"

module Chelsy

  class Node
    def initialize(**opts)
    end

    protected

    # Returns an object as an immutable string.
    #
    # @param [Object] obj an Object
    # @return [String] The string representation of `obj`. It's frozen (unmodifiable).
    def immutable_stringify(obj)
      str = obj.to_s
      if str.frozen?
        str
      else
        str.dup.freeze
      end
    end
  end

  # The class must provide a method validate_node`
  module NodeList
    include Enumerable
    extend Forwardable

    def_delegators :@items, :size, :empty?, :[]

    def initialize(items=[], **rest)
      @items = items.map {|element| validate_node(element) }
      super(**rest)
    end

    def each(&block)
      @items.each(&block)
      self
    end

    def <<(node)
      @items << validate_node(node)
      self
    end

    def concat(enumerable)
      enumerable.each {|it| @items << validate_node(it) }
      self
    end

    def []=(*args)
      value = args[-1]
      value = case value
              when Enumerable
                value.map {|v| validate_node(v) }
              else
                validate_node(value)
              end
      args[-1] = value
      @items.send(:[]=, *args)
    end
  end

  class Fragment < Node
  end

  module Comment
    class Base < Fragment
    end

    # `// ...`
    class Single < Base
      attr_reader :body

      def initialize(body, **rest)
        @body = body.dup
        super **rest
      end
    end

    # `/* ... */`
    class Multi < Base
      attr_reader :lines

      def initialize(body, **rest)
        @lines = case body
                 when String
                   body.split(/\n/)
                 else
                   body.to_a
                 end
        super **rest
      end
    end

  end

  module Syntax
  end

  class FragmentList < Node
    include NodeList

    private
    def validate_node(node); Syntax::Fragment.ensure(node) end
  end

  # `Element` can have multiple `Fragment`s
  #
  # - `fragments` is an instace of `FragmentList` holds `Fragment`s which stands above `Element`.
  # - `post_fragments` holds `Fragment`s which stands below `Element`.
  class Element < Node
    attr_reader :fragments, :post_fragments

    def initialize(**rest)
      @fragments = FragmentList.new
      @post_fragments = FragmentList.new

      super(**rest)
    end
  end

  # This node represents arbitrary C code snippet. It can be an decsendant of any node.
  # However it is used mainly in macro definition.
  class Raw < Element
    # @!attribute [r] code
    #   @return [String] C code snippet
    attr_reader :code

    # Initialize instance.
    # @param [#to_s] code C code snippet
    def initialize(code, **rest)
      @code = immutable_stringify(code)
      super **rest
    end

    def to_s
      @code
    end
  end

  class Declarative < Element
    attr_reader :storage

    def initialize(storage: nil, **rest)
      @storage = Syntax::Storage.ensure(storage) if storage

      super(**rest)
    end

    def extern?; @storage == :extern end
    def static?; @storage == :static end
    def init; nil end
  end

  # Struct or Union member with bit-field
  #
  # Unnamed bit-field ::
  #     A bit-field declaration with no declarator, but only a colon and a width
  class BitField < Element
    attr_reader :declaration, :bits

    def initialize(bits, declaration=nil, **rest)
      @declaration = Syntax::Declaration.ensure(declaration) if declaration
      @bits = bits && Syntax::BitField.ensure(bits)

      super **rest
    end
  end

  class EnumMember < Element
    attr_reader :name, :init

    def initialize(name, init=nil, **rest)
      @name = name.to_sym
      @init = init
      super **rest
    end
  end

  class StructOrUnionMemberList < Element
    include NodeList

    private
    def validate_node(node); Syntax::StructOrUnionMember.ensure(node) end
  end

  class EnumMemberList < Element
    include NodeList

    private
    def validate_node(node); Syntax::EnumMember.ensure(node) end
  end

  # === 6.7.8 Initialization
  class Designator < Element
  end

  # { [1] = 10, [2] = 20, ...}
  class IndexDesignator < Designator
    attr_reader :index

    def initialize(index, **rest)
      @index = Syntax::Expr.ensure(index)
      super **rest
    end
  end

  # { .a = 10, .b = 20, ...}
  class MemberDesignator < Designator
    attr_reader :name

    def initialize(name, **rest)
      @name = Syntax::Ident.ensure(name)
      super **rest
    end
  end

  class Initializer < Element
    attr_reader :designator, :value

    def initialize(value, designator=nil, **rest)
      @value = value
      @designator = designator
      super **rest
    end
  end

  class InitializerList < Element
    include NodeList

    private
    def validate_node(node); Syntax::Initializer.ensure(node) end
  end

  class Expr < Element
  end

  class Stmt < Element
  end

  module Syntax
  end

  # `Document` represents a _translation unit_ (file).
  class Document < Element
    include NodeList

    private
    def validate_node(node); Syntax::TopLevel.ensure(node) end
  end

  # = 6.2.5 Types
  module Type
    class Base < Element
      def initialize(const: false, volatile: false, **rest)
        @const = !!const
        @volatile = !!volatile

        super(**rest)
      end

      def const?;    @const end
      def volatile?; @volatile end

      def qualified?
        @const || @volatile
      end
    end

  end

  module Syntax
  end

  # Function and prototype params
  class Param < Element
    attr_reader :name, :type

    def initialize(name, type, register: false, **rest)
      @name = Syntax::Ident.ensure(name)
      @type = Syntax::Type.ensure(type)

      super(**rest)
    end
  end

  module Syntax
  end

  class IdentList < Element
    include NodeList

    private
    def validate_node(node); Syntax::Ident.ensure(node) end
  end

  class ParamList < Element
    include NodeList

    private
    def validate_node(node); Syntax::Param.ensure(node) end
  end

  class ProtoParamList < Element
    include NodeList

    private
    def validate_node(node); Syntax::ProtoParam.ensure(node) end
  end

  module Type
    class Numeric < Base
    end

    # == _Bool
    class Bool < Numeric
    end

    # == Integer types
    class Integral < Numeric
      def initialize(unsigned: false, **rest)
        @unsigned = !!unsigned
        super(**rest)
      end

      def unsigned?; @unsigned end
    end

    class Char < Integral
    end

    class Short < Integral
    end

    class Int < Integral
    end

    class Long < Integral
    end

    class LongLong < Integral
    end

    # == Real floating types
    class Real < Numeric
    end

    class Float < Real
    end

    class Double < Real
    end

    class LongDouble < Real
    end

    # == Complex types
    class Complex < Numeric
    end

    class FloatComplex < Complex
    end

    class DoubleComplex < Complex
    end

    class LongDoubleComplex < Complex
    end

    # == Derived types
    class Derived < Base
    end

    class Pointer < Derived
      attr_reader :pointee

      def initialize(pointee, restrict: false, **rest)
        @pointee = Syntax::Type.ensure(pointee)
        @restrict = !!restrict

        super(**rest)
      end

      def restrict?; @restrict end

      def qualified?
        @restrict || super
      end

      def termination_type
        pointee = self.pointee
        while pointee.is_a?(Type::Pointer)
          pointee = pointee.pointee
        end
        pointee
      end
    end

    # From: 6.7.5.3 Function declarators (including prototypes)
    #
    # qualifier in parameter array declarator
    #
    # > A declaration of a parameter as ‘‘array of type’’ shall be adjusted to
    # > ‘‘qualified pointer to type’’, where the type qualifiers (if any) are
    # > those specified within the [ and ] of the array type derivation.
    #
    # `static` in parameter array declarator
    #
    # > If the keyword static also appears within the [ and ] of the array type derivation,
    # > then for each call to the function, the value of the corresponding actual argument shall
    # > provide access to the first element of an array with at least as many elements as
    # > specified by the size expression.
    class Array < Derived
      attr_reader :element_type, :size

      def initialize(element_type, size = nil, static: false, **rest)
        @element_type = element_type
        @size = size && Syntax::ArraySize.ensure(size)
        @static = !!static

        super(**rest)
      end

      # An array type of unknown size is an incomplete type.
      def incomplete?; @size.nil? end
      def variable?; @size == :* end

      def static?; @static end
    end

    class Function < Derived
      attr_reader :return_type, :params

      def initialize(return_type, params, **rest)
        @return_type = Syntax::Type.ensure(return_type)
        @params = ProtoParamList.new(params)

        super(**rest)
      end
    end

    # Struct, Unicon, Enum

    class Taggable < Derived
      attr_reader :tag

      def initialize(tag, **rest)
        @tag = tag.to_sym
        super **rest
      end
    end

    module StructOrUnion
      attr_reader :members

      def initialize(tag, members=nil, **rest)
        @members = StructOrUnionMemberList.new(members) if members
        super tag, **rest
      end
    end

    class Struct < Taggable
      include StructOrUnion
    end

    class Union < Taggable
      include StructOrUnion
    end

    class Enum < Taggable
      attr_reader :members

      def initialize(tag, members=nil, **rest)
        @members = EnumMemberList.new(members) if members
        super tag, **rest
      end
    end

  end

  # 6.4.4.1 Integer constants
  module Constant
    class Base < Expr
    end

    class Integral < Base
      attr_reader :value, :base

      def initialize(value, unsigned: false, base: 10, **rest)
        @value = value
        @unsigned = !!unsigned
        @base = base

        super(**rest)
      end

      def unsigned?
        @unsigned
      end
    end

    class Int < Integral
    end

    class Long < Integral
    end

    class LongLong < Integral
    end

  end

  module Syntax
  end

  # 6.4.5 String literals
  module Constant

    class String < Base
      attr_reader :value

      def initialize(str, wide: false, **rest)
        @value = str.dup.freeze
        @wide = !!wide

        super(**rest)
      end

      def wide?
        @wide
      end
    end

  end

  module Operator
    class Base < Expr
      def self.operator; nil end
    end

    class Unary < Base
      attr_reader :operand

      def initialize(operand, **rest)
        # `sizeof` operator accepts expr or type as its operand.
        @operand = operand
        super **rest
      end
    end

    class Postfix < Unary
      def initialize(operand, **rest)
        super Syntax::Expr.ensure(operand), **rest
      end
    end

    class Prefix < Unary
      def initialize(operand, **rest)
        super Syntax::Expr.ensure(operand), **rest
      end
    end

    class Binary < Base
      attr_reader :lhs, :rhs

      def initialize(lhs, rhs, **rest)
        @lhs = Syntax::Expr.ensure(lhs)
        @rhs = Syntax::Expr.ensure(rhs)
        super **rest
      end
    end

    # Ternary conditional
    class Conditional < Base
      attr_reader :condition, :then, :else

      def self.operator; :"?:" end

      def initialize(condition, then_expr, else_expr, **rest)
        @condition = Syntax::Expr.ensure(condition)
        @then = Syntax::Expr.ensure(then_expr)
        @else = Syntax::Expr.ensure(else_expr)

        super **rest
      end
    end

    # === 6.5.2.1 Array subscripting
    class Subscription < Postfix
      attr_reader :index

      def self.operator; :"[]" end

      def initialize(subscriptee, index, **rest)
        @index = Syntax::Expr.ensure(index)
        super subscriptee, **rest
      end

      def subscriptee; operand end
    end

    # === 6.5.2.2 Function calls
    class Call < Postfix
      attr_reader :args

      def self.operator; :"()" end

      def initialize(callee, args, **rest)
        @args = args.map {|a| Syntax::Expr.ensure(a) }

        super callee, **rest
      end

      def callee; operand end
    end

    # === 6.5.2.3 Structure and union members
    class Access < Postfix
      attr_reader :name

      def self.operator; :"." end

      def initialize(object, name, **rest)
        @name = Syntax::Ident.ensure(name)
        super object, **rest
      end

      def object; operand end
    end

    class IndirectAccess < Access
      def self.operator; :"->" end
    end

    # === 6.5.2.4 Postfix increment and decrement operators
    class PostfixIncrement < Postfix
      def self.operator; :"++" end
    end

    class PostfixDecrement < Postfix
      def self.operator; :"--" end
    end

    # === 6.5.3 Unary operators
    class PrefixIncrement < Prefix
      def self.operator; :"++" end
    end

    class PrefixDecrement < Prefix
      def self.operator; :"--" end
    end

    # Unary plus
    class Plus < Prefix
      def self.operator; :"+" end
    end

    # Unary minus
    class Minus < Prefix
      def self.operator; :"-" end
    end

    # Logical NOT
    class Not < Prefix
      def self.operator; :"!" end
    end

    # Bitwise NOT
    class BitwiseNot < Prefix
      def self.operator; :"~" end
    end

    # Indirection (dereference)
    class Dereference < Prefix
      def self.operator; :"*" end
    end

    # Address-of
    class Address < Prefix
      def self.operator; :"&" end
    end

    # Type cast
    class Cast < Prefix
      attr_reader :type

      def self.operator; :"()" end

      def initialize(operand, type, **rest)
        @type = Syntax::Type.ensure(type)
        super operand, **rest
      end
    end

    # Size-of
    class SizeOf < Unary
      def self.operator; :"sizeof" end

      def initialize(operand, **rest)
        super Syntax::ExprOrType.ensure(operand), **rest
      end
    end

    # `defined` unary operator in conditional macro.
    class Defined < Unary
      def self.operator; :"defined" end

      def initialize(operand, **rest)
        super Syntax::Ident.ensure(operand), **rest
      end
    end

    # == 6.5.5 Multiplicative operators

    # Multiplication
    class Mul < Binary
      def self.operator; :* end
    end

    # Division
    class Div < Binary
      def self.operator; :/ end
    end

    # Remainder
    class Rem < Binary
      def self.operator; :% end
    end

    # Addition
    class Add < Binary
      def self.operator; :+ end
    end

    # Subtraction
    class Sub < Binary
      def self.operator; :- end
    end

    # Bitwise left shift and right shift
    class BitwiseLeftShift < Binary
      def self.operator; :<< end
    end

    class BitwiseRightShift < Binary
      def self.operator; :>> end
    end

    # For relational operators < and ≤ respectively
    class LessThan < Binary
      def self.operator; :< end
    end

    class LessThanOrEqual < Binary
      def self.operator; :<= end
    end

    # For relational operators > and ≥ respectively
    class GreaterThan < Binary
      def self.operator; :> end
    end

    class GreaterThanOrEqual < Binary
      def self.operator; :>= end
    end

    # For relational = and ≠ respectively
    class Equal < Binary
      def self.operator; :== end
    end

    class NotEqual < Binary
      def self.operator; :"!=" end
    end

    # Bitwise AND, XOR, OR
    class BitwiseAnd < Binary
      def self.operator; :& end
    end

    class BitwiseXor < Binary
      def self.operator; :"^" end
    end

    class BitwiseOr < Binary
      def self.operator; :"|" end
    end

    # Logical AND, OR
    class And < Binary
      def self.operator; :"&&" end
    end

    class Or < Binary
      def self.operator; :"||" end
    end

    # === 6.5.16 Assignment operators

    class Assign < Binary
      def self.operator; :"=" end
    end

    class AssignAdd < Binary
      def self.operator; :"+=" end
    end

    class AssignSub < Binary
      def self.operator; :"-=" end
    end

    class AssignMul < Binary
      def self.operator; :"*=" end
    end

    class AssignDiv < Binary
      def self.operator; :"/=" end
    end

    class AssignRem < Binary
      def self.operator; :"%=" end
    end

    class AssignBitwiseLeftShift < Binary
      def self.operator; :"<<=" end
    end

    class AssignBitwiseLeftRight < Binary
      def self.operator; :">>=" end
    end

    class AssignBitwiseAnd < Binary
      def self.operator; :"&=" end
    end

    class AssignBitwiseXor < Binary
      def self.operator; :"^=" end
    end

    class AssignBitwiseOr < Binary
      def self.operator; :"|=" end
    end

    class Comma < Binary
      def self.operator; :"," end
    end

  end

  module Operator
    # --- Operator precedence
    # The following table lists the precedence of operators.
    # Operators are listed top to bottom, in descending precedence.

    PRECEDENCE_TABLE = [
      # -- highest
      [
        PostfixIncrement, PostfixDecrement,
        Call,
        Subscription,
        Access,
        # Compound Literal
      ],
      [
        PrefixIncrement, PrefixDecrement,
        Plus, Minus,
        Not, BitwiseNot,
        Cast,
        Dereference,
        Address,
        SizeOf,
        Defined,
      ],
      [
        Mul, Div, Rem,
      ],
      [
        Add, Sub,
      ],
      [
        BitwiseLeftShift, BitwiseRightShift,
      ],
      [
        LessThan, LessThanOrEqual,
        GreaterThan, GreaterThanOrEqual,
      ],
      [
        Equal, NotEqual,
      ],
      [
        BitwiseAnd,
      ],
      [
        BitwiseXor,
      ],
      [
        BitwiseOr,
      ],
      [
        And,
      ],
      [
        Or,
      ],
      [
        Conditional,
      ],
      [
        Assign,
        AssignAdd, AssignSub,
        AssignMul, AssignDiv, AssignRem,
        AssignBitwiseLeftShift, AssignBitwiseLeftRight,
        AssignBitwiseAnd, AssignBitwiseXor, AssignBitwiseOr,
      ],
      [
        Comma,
      ],
    ]

    # This hash contains precedence value (Fixnum) by Operator::Base classes.
    # Higher precedence has higher value.
    OPERATOR_PRECEDENCE = {}.tap do |table|
      PRECEDENCE_TABLE.reverse.each_with_index do |op_classes, precedence|
        op_classes.each do |klass|
          table[klass] = precedence
        end
      end
    end

    class Base
      def self.precedence
        OPERATOR_PRECEDENCE[self] or raise NotImplementedError
      end
    end
  end

  # = 6.8 Statements and blocks

  # == 6.8.1 Labeled statements
  class Labeled < Stmt
    attr_reader :label, :stmt

    def initialize(label, stmt, **rest)
      @label = Syntax::Ident.ensure(label)
      @stmt = Syntax::Stmt.ensure(stmt)
      super **rest
    end
  end

  # == 6.8.3 Expression and null statements

  # A null statement (consisting of just a semicolon) performs no operations.
  class EmptyStmt < Stmt
  end

  # == 6.8.2 Compound statement

  class Block < Stmt
    include NodeList

    private

    def validate_node(node)
      Syntax::BlockItem.ensure(node)
    end
  end

  # === 6.8.4.1 The if statement
  class If < Stmt
    attr_reader :condition, :then, :else

    def initialize(condition_expr, then_stmt, else_stmt=nil, **rest)
      @condition = Syntax::Expr.ensure(condition_expr)
      @then = Syntax::Stmt::ensure(then_stmt)
      @else = Syntax::Stmt::ensure(else_stmt) if else_stmt

      super **rest
    end
  end

  # === 6.8.4.2 Theswitchstatement
  class Switch < Stmt
    attr_reader :expr, :stmt

    def initialize(expr, stmt, **rest)
      @expr = Syntax::Expr.ensure(expr)
      @stmt = Syntax::Stmt.ensure(stmt)
      super **rest
    end
  end

  class Case < Labeled
    attr_reader :expr

    def initialize(expr, stmt, **rest)
      @expr = Syntax::Expr.ensure(expr)
      super :case, stmt, **rest
    end
  end

  # == 6.8.5 Iteration statements

  # @abstract Subclass to implement a custom iteration class.
  class Iteration < Stmt
    attr_reader :condition, :body

    # Initialize iteration statement with its condition and iteration body statement.
    # You can pass an optional code block which takes {Chelsy::Block} instance can be
    # used to construct iteration body statements.
    #
    # @param condition_expr an expression which express condition
    # @param body_stmt iteration body statement
    # @yield [Chelsy::Block] If given, this method yields {Chelsy::Block} instance
    # @raise [ArgumentError] Given neither `body_stmt` nor code block
    def initialize(condition_expr=nil, body_stmt=nil, **rest)
      @condition = Syntax::Expr.ensure(condition_expr) if condition_expr

      if block_given?
        @body = Block.new
        yield @body
      elsif body_stmt
        @body = Syntax::Stmt.ensure(body_stmt)
      else
        raise ArgumentError, "missing body statement"
      end

      super **rest
    end
  end

  # This class represents `while` iteration statement.
  class While < Iteration
    # (see Chelsy::Iteration#initialize)
    # @raise [ArgumentError] `condition_expr` is nil
    def initialize(condition_expr, body_stmt=nil, **rest)
      raise ArgumentError, "missing condition expr" unless condition_expr
      super condition_expr, body_stmt, **rest
    end
  end

  # This class represents `do ... while (...)` iteration statement.
  class DoWhile < Iteration
    # (see Chelsy::Iteration#initialize)
    # @raise [ArgumentError] `condition_expr` is nil
    def initialize(condition_expr, body_stmt=nil, **rest)
      raise ArgumentError, "missing condition expr" unless condition_expr
      super condition_expr, body_stmt, **rest
    end
  end

  # This class represents `for` iteration statement.
  class For < Iteration
    attr_reader :init, :loop

    # (see Chelsy::Iteration#initialize)
    # @param init_stmt initialization statement
    # @param loop_expr loop expression is performed each iteration
    def initialize(init_stmt=nil, condition_expr=nil, loop_expr=nil, body_stmt=nil, **rest)
      @init = Syntax::BlockItem::ensure(init_stmt) if init_stmt
      @loop = Syntax::Expr.ensure(loop_expr) if loop_expr

      super condition_expr, body_stmt, **rest
    end
  end

  class Goto < Stmt
    attr_reader :label

    def initialize(label, **rest)
      @label = Syntax::Ident.ensure(label)
      super **rest
    end
  end

  class Continue < Stmt
  end

  class Break < Stmt
  end

  # === 6.8.6.4 The return statement
  class Return < Stmt
    attr_reader :expr

    def initialize(expr=nil, **rest)
      @expr = Syntax::Expr.ensure(expr) if expr

      super(**rest)
    end
  end

  # 6.7 Declarations
  class Declaration < Declarative
    attr_reader :name, :type

    def initialize(name, type, init=nil, **rest)
      @name = Syntax::Ident.ensure(name)
      @type = Syntax::Type.ensure(type)
      @init = case init
              when nil
                nil
              when Enumerable
                InitializerList.new(init)
              else
                Syntax::Expr.ensure(init)
              end

      super(**rest)
    end

    def init; @init end
  end

  class Typedef < Declarative
    attr_reader :name, :type

    def initialize(name, type, **rest)
      @name = Syntax::Ident.ensure(name)
      @type = Syntax::Type.ensure(type)

      rest[:storage] = :typedef
      super(**rest)
    end
  end

  # = 6.9 External definitions

  # == 6.9.1 Function definition

  class Function < Declarative
    attr_reader :name, :return_type, :params, :body

    def initialize(name, return_type, params, inline: false, **rest, &block)
      @name = Syntax::Ident.ensure(name)
      @return_type = Syntax::Type.ensure(return_type)
      @params = ParamList.new(params)

      @body = Block.new
      block.call(@body)

      super(**rest)
    end
  end

  # AST node represents a macro invocation with or without arguments.
  class Macro < Expr
    attr_reader :name, :args

    # @!attribute [r] name
    #   @return [Symbol] Macro name
    # @!attribute [r] args
    #   @return [Enumerable] Arguments

    # initialize instance.
    #
    # @param [Symbol] name Macro name
    # @param [Enumerable] args Arguments. `nil` if no arguments supplied.
    def initialize(name, args=nil, **rest)
      @name = Syntax::Ident.ensure(name)
      @args = args.map {|a| Syntax::Expr.ensure(a) } if args

      super **rest
    end
  end

  # = 6.10 Preprocessing directives
  module Directive
    class Base < Fragment
    end

    class Include < Base
      attr_reader :location

      def initialize(location, system: false, **rest)
        @location = immutable_stringify(location)
        @system = !!system

        super **rest
      end

      # If `true`, this fragment forms `#include <...>`.
      # otherwise, this fragment forms `#include "..."`.
      def system?; @system end
    end

    # `#define`
    #
    # - `params` - [symbol]
    # - `replacement` - string
    class Define < Base
      attr_reader :name, :params, :replacement

      def initialize(name, params=nil, replacement, **rest)
        @name = Syntax::Ident.ensure(name)
        @params = IdentList.new(params) if params
        @replacement = Syntax::MacroDefinition.ensure(replacement)

        super **rest
      end
    end

    # `#undef`
    class Undef < Base
      attr_reader :name

      def initialize(name, **rest)
        @name = Syntax::Ident.ensure(name)
        super **rest
      end
    end

    # `#if`
    class If < Base
      attr_reader :condition

      def initialize(condition_expr, **rest)
        @condition = Syntax::Expr.ensure(condition_expr)
        super **rest
      end
    end

    # `#elif`
    class ElseIf < Base
      attr_reader :condition

      def initialize(condition_expr, **rest)
        @condition = Syntax::Expr.ensure(condition_expr)
        super **rest
      end
    end

    # `#else`
    class Else < Base
    end

    # `#endif`
    class EndIf < Base
    end

    # `#line`
    #
    #     #line digits ["filename"]
    #
    class Line < Base
      attr_reader :lineno, :filename

      def initialize(lineno, filename=nil, **rest)
        @lineno = Syntax::Int.ensure(lineno)
        @filename = immutable_stringify(filename) if filename

        super **rest
      end
    end

    # `#pragma`
    class Pragma < Base
      attr_reader :pragma

      def initialize(pragma, **rest)
        @pragma = immutable_stringify(pragma)
        super **rest
      end
    end

    # `STDC` pragma
    #
    #     #pragma STDC FP_CONTRACT on-off-switch
    #     #pragma STDC FENV_ACCESS on-off-switch
    #     #pragma STDC CX_LIMITED_RANGE on-off-switch
    class StdcPragma < Pragma
      attr_reader :name, :state

      def initialize(name, state, **rest)
        @name = Syntax::StdcPragma.ensure(name)
        @state = Syntax::StdcPragmaState.ensure(state)

        super "STDC #{name} #{state}", **rest
      end
    end

  end

end

module Chelsy
  module Syntax
    TopLevel = Any.new('TopLevel', [Declarative])
    Type = Any.new('TypeSpecifier', [Chelsy::Type::Base, :void])
    Int = Any.new('Int', [::Integer])
    Ident = Any.new('Identifier', [Symbol])
    Expr = Any.new('Expression', [Chelsy::Expr, Syntax::Ident])
    ExprOrType = Any.new('Expression-Or-Type', [Syntax::Expr, Syntax::Type])
    Fragment = Any.new('Fragment', [Fragment, String])
    Storage = Any.new('Storage-class specifiers', [:typedef, :extern, :static])
    Param = Any.new('Parameter', [Chelsy::Param, :void, :"..."])
    ProtoParam = Any.new('Prototype Parameter', [Syntax::Param, Symbol, Chelsy::Type::Base])
    ArraySize = Any.new('ArraySize', [Syntax::Expr])
    BitField = Any.new('BitField', [Chelsy::Constant::Integral])
    StructOrUnionMember = Any.new('StructOrUnionMember', [Chelsy::Declaration, Chelsy::BitField])
    EnumMember = Any.new('EnumMember', [Chelsy::EnumMember, Symbol])
    Initializer = Any.new('Initializer', [Syntax::Expr, Chelsy::Initializer, Chelsy::InitializerList])
    Stmt = Any.new('Statement', [
                    Syntax::Expr, # Treats Expr as Expression Statement
                    Chelsy::Stmt])
    BlockItem   = Any.new('BlockItem', [
                    Syntax::Stmt,
                    Chelsy::Declarative])
    Declaration = Any.new('Declaration', [Chelsy::Declaration])
    StdcPragma = Any.new('STDC Pragma', [:FP_CONTRACT, :FENV_ACCESS, :CX_LIMITED_RANGE])
    StdcPragmaState = Any.new('STDC Pragma State', [:ON, :OFF, :DEFAULT])
    MacroDefinition = Any.new('Raw', [
                        Chelsy::Raw,
                        Syntax::BlockItem])
  end
end
