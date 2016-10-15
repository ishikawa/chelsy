require "chelsy/syntax"
require 'forwardable'

module Chelsy

  class Node
  end

  class Element < Node
  end

  class Type < Element
    def initialize(const: false, restrict: false, volatile: false)
      @const = !!const
      @restrict = !!restrict
      @volatile = !!volatile
    end

    def const?;    @const end
    def restrict?; @restrict end
    def volatile?; @volatile end
  end

  class Declaration < Element
  end

  class Definition < Element
    def initialize(extern: false, static: false)
      @extern = !!extern
      @static = !!static
    end

    def extern?; @extern end
    def static?; @static end
  end

  class Expr < Element
  end

  class Stmt < Element
  end

  module Syntax
    Ident = Any.new('Identifier', [Symbol])
    Expr  = Any.new('Expression', [Expr, Symbol])
    Type  = Any.new('TypeSpecifier', [Type, :void])
  end

  # = Type specifiers
  module Types
    class Int < Type
    end

    class Short < Type
    end

    class Char < Type
    end

    class Float < Type
    end

    class Double < Type
    end

    # _Bool
    class Bool < Type
    end

    # _Complex
    class Complex < Type
    end

    class Pointer < Type
      attr_reader :pointee

      def initialize(pointee)
        @pointee = Syntax::Type.ensure(pointee)
      end
    end
  end

  # 6.4.4.1 Integer constants
  module Constant

    class Integral < Expr
      attr_reader :value, :base

      def initialize(value, unsigned: false, base: 10)
        @value = value
        @unsigned = !!unsigned
        @base = base
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

    class String < Expr
      attr_reader :value

      def initialize(str, wide: false)
        @value = str.dup.freeze
        @wide = !!wide
      end

      def wide?
        @wide
      end
    end

  end

  # 6.5.2.2 Function calls
  class FunctionCall < Expr
    attr_reader :callee, :args

    def initialize(callee, args)
      @callee = Syntax::Expr.ensure(callee)
      @args = args.map {|a| Syntax::Expr.ensure(a) }
    end
  end

  # = 6.8 Statements and blocks

  # == 6.8.3 Expression and null statements

  # A null statement (consisting of just a semicolon) performs no operations.
  class EmptyStmt < Stmt
  end

  class ExprStmt < Stmt
    attr_reader :expr

    def initialize(expr)
      @expr = Syntax::Expr.ensure(expr)
    end
  end

  # == 6.8.2 Compound statement
  module Syntax
    BlockItem = Any.new('BlockItem', [Stmt, Declaration])
  end

  class Block < Stmt
    include Enumerable

    extend Forwardable
    def_delegators :@items, :size, :each

    def initialize()
      @items = []
    end

    # Append `node` to block item list
    #
    #   - Implicit convertion from Expr to ExprStmt
    def <<(node)
      item = case node
             when Expr
               ExprStmt.new(node)
             else
               node
             end
      @items << Syntax::BlockItem.ensure(item)
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

    def initialize(name, type, register: false)
      @name = Syntax::Ident.ensure(name)
      @type = Syntax::Type.ensure(type)

      super
    end
  end

  module Syntax
    Param = Any.new('Parameter', [Param, :void, :"..."])
  end

  class Function < Definition
    attr_reader :name, :return_type, :params, :body

    def initialize(name, return_type, params, inline: false, **rest, &block)
      @name = Syntax::Ident.ensure(name)
      @return_type = Syntax::Type.ensure(return_type)
      @params = params.map {|p| Syntax::Param.ensure(p) }

      @body = Block.new
      block.call(@body)

      super(**rest)
    end
  end

end
