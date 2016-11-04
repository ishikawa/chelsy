require "chelsy/syntax"

module Chelsy

  class Node
    def initialize(**opts)
    end
  end

  # The class must provide a method validate_node`
  module NodeList
    include Enumerable

    def initialize(items=[], **rest)
      @items = items.map {|element| validate_node(element) }
      super(**rest)
    end

    def each(&block)
      @items.each(&block)
      self
    end

    def size; @items.size end
    def empty?; @items.empty? end

    def <<(node)
      @items << validate_node(node)
      self
    end
  end

  class Fragment < Node
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

  class Declarative < Element
    attr_reader :storage

    def initialize(storage: nil, **rest)
      @storage = Syntax::Storage.ensure(storage)

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

    # TODO 6.5.17 Comma operator
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

  # == 6.8.3 Expression and null statements

  # A null statement (consisting of just a semicolon) performs no operations.
  class EmptyStmt < Stmt
  end

  class ExprStmt < Stmt
    attr_reader :expr

    def initialize(expr, **rest)
      @expr = Syntax::Expr.ensure(expr)

      super(**rest)
    end
  end

  # == 6.8.2 Compound statement

  class Block < Stmt
    include NodeList

    private

    # Implicit convertion from Expr to ExprStmt
    def validate_node(node)
      item = node
      item = ExprStmt.new(node) if Syntax::Expr.accept?(node)

      Syntax::BlockItem.ensure(item)
    end
  end

  # == 6.8.6.4 Thereturnstatement
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
              when Enumerable
                InitializerList.new(init)
              else
                init
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

  # = 6.10 Preprocessing directives
  module Directive
    class Base < Fragment
    end

    class Include < Base
      attr_reader :location

      def initialize(location, system: false, **rest)
        @location = location.to_s.dup
        @system = !!system
      end

      # If `true`, this fragment forms `#include <...>`.
      # otherwise, this fragment forms `#include "..."`.
      def system?; @system end
    end
  end

end

module Chelsy
  module Syntax
    TopLevel = Any.new('TopLevel', [Declarative])
    Type = Any.new('TypeSpecifier', [Chelsy::Type::Base, :void])
    Ident = Any.new('Identifier', [Symbol])
    Expr = Any.new('Expression', [Chelsy::Expr, Syntax::Ident])
    ExprOrType = Any.new('Expression-Or-Type', [Syntax::Expr, Syntax::Type])
    Fragment = Any.new('Fragment', [Fragment, String])
    Storage = Any.new('Storage-class specifiers', [:typedef, :extern, :static, nil])
    Param = Any.new('Parameter', [Chelsy::Param, :void, :"..."])
    ProtoParam = Any.new('Prototype Parameter', [Syntax::Param, Symbol, Chelsy::Type::Base])
    ArraySize = Any.new('ArraySize', [Syntax::Expr])
    BitField = Any.new('BitField', [Chelsy::Constant::Integral])
    StructOrUnionMember = Any.new('StructOrUnionMember', [Chelsy::Declaration, Chelsy::BitField])
    EnumMember = Any.new('EnumMember', [Chelsy::EnumMember, Symbol])
    Initializer = Any.new('Initializer', [Syntax::Expr, Chelsy::Initializer, Chelsy::InitializerList])
    Stmt = Any.new('BlockItem', [Chelsy::Stmt])
    BlockItem   = Any.new('BlockItem', [Syntax::Stmt, Chelsy::Declarative])
    Declaration = Any.new('Declaration', [Chelsy::Declaration])
  end
end
