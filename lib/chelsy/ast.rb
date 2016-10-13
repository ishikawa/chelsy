module Chelsy

  class Node
  end

  class Element < Node
  end

  class Expr < Element
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

    class String < Element
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
      @callee = callee
      @args = args.dup
    end
  end

  # = 6.8 Statements and blocks

  class Stmt < Element
  end

  # == 6.8.3 Expression and null statements

  # A null statement (consisting of just a semicolon) performs no operations.
  class EmptyStmt < Stmt
  end

  class ExprStmt < Stmt
    attr_reader :expr

    def initialize(expr)
      @expr = expr
    end
  end

end
