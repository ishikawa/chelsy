require "chelsy/syntax"

module Chelsy

  class Node
    def initialize(**opts)
    end
  end

  # The class must provide a method `items` and `validate_node`
  module NodeList
    include Enumerable

    def each(&block)
      items.each(&block)
      self
    end

    def size; items.size end
    def empty?; items.empty? end

    def <<(node)
      items << validate_node(node)
      self
    end
  end

  class Fragment < Node
  end

  module Syntax
    Fragment = Any.new('Fragment', [Fragment, String])
  end

  class FragmentList < Node
    include NodeList

    def initialize(**rest)
      @fragments = []
      super(**rest)
    end

    private
    def items; @fragments end
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

  class Declaration < Element
  end

  class Definition < Element
    def initialize(extern: false, static: false, **rest)
      @extern = !!extern
      @static = !!static

      super(**rest)
    end

    def extern?; @extern end
    def static?; @static end
  end

  class Expr < Element
  end

  class Stmt < Element
  end

  module Syntax
    Ident    = Any.new('Identifier', [Symbol])
    Expr     = Any.new('Expression', [Expr, Symbol])
    TopLevel = Any.new('TopLevel', [Definition, Declaration])
  end

  # `Document` represents a _translation unit_ (file).
  class Document < Element
    include NodeList

    def initialize(**rest)
      @items = []
      super(**rest)
    end

    private
    def items; @items end
    def validate_node(node); Syntax::TopLevel.ensure(node) end
  end

  # = 6.2.5 Types
  module Type
    class Base < Element
      def initialize(const: false, restrict: false, volatile: false, **rest)
        @const = !!const
        @restrict = !!restrict
        @volatile = !!volatile

        super(**rest)
      end

      def const?;    @const end
      def restrict?; @restrict end
      def volatile?; @volatile end

      def qualified?
        @const || @restrict || @volatile
      end
    end

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

      def initialize(pointee, **rest)
        @pointee = Syntax::Type.ensure(pointee)
        super(**rest)
      end
    end

    class Array < Derived
      attr_reader :element_type, :size

      def initialize(element_type, size = nil, **rest)
        @element_type = element_type
        @size = size

        super(**rest)
      end

      # An array type of unknown size is an incomplete type.
      def incomplete?; @size.nil? end
    end

    # TODO Function
    # TODO Struct
    # TODO Union
  end

  module Syntax
    Type = Any.new('TypeSpecifier', [Chelsy::Type::Base, :void])
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

  # == 6.5.2 Array subscripting

  # === 6.5.2.1 Array subscripting
  class Subscription < Expr
    attr_reader :subscriptee, :index

    def initialize(subscriptee, index, **rest)
      @subscriptee = Syntax::Expr.ensure(subscriptee)
      @index = Syntax::Expr.ensure(index)

      super(**rest)
    end
  end

  # === 6.5.2.2 Function calls
  class FunctionCall < Expr
    attr_reader :callee, :args

    def initialize(callee, args, **rest)
      @callee = Syntax::Expr.ensure(callee)
      @args = args.map {|a| Syntax::Expr.ensure(a) }

      super(**rest)
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
  module Syntax
    BlockItem = Any.new('BlockItem', [Stmt, Declaration])
  end

  class Block < Stmt
    include NodeList

    def initialize(**rest)
      @items = []
      super(**rest)
    end

    private
    def items; @items end

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

  # = 6.9 External definitions

  # == 6.9.1 Function definition

  # Param-List ::
  #     [] |
  #     [:void] |
  #     [Param] |
  #     [Param, ..., :"..."]
  class Param < Element
    attr_reader :name, :type

    def initialize(name, type, register: false, **rest)
      @name = Syntax::Ident.ensure(name)
      @type = Syntax::Type.ensure(type)

      super(**rest)
    end
  end

  module Syntax
    Param = Any.new('Parameter', [Param, :void, :"..."])
  end

  class ParamList < Element
    include NodeList

    def initialize(**rest)
      @params = []
      super(**rest)
    end

    private
    def items; @params end
    def validate_node(node); Syntax::Param.ensure(node) end
  end

  class Function < Definition
    attr_reader :name, :return_type, :params, :body

    def initialize(name, return_type, params, inline: false, **rest, &block)
      @name = Syntax::Ident.ensure(name)
      @return_type = Syntax::Type.ensure(return_type)

      @params = ParamList.new.tap do |list|
        params.map {|p| list << p }
      end

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
