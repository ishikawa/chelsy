module Chelsy

  class Node
  end

  class Element < Node
  end

  # 6.4.4.1 Integer constants
  module Constant

    class Integral < Element
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

end
