module Chelsy

  class Node
  end

  class Element < Node
  end

  module Constant

    class Integral < Element
      attr_reader :value, :base

      def initialize(value, unsigned: false, base: 10)
        @value = value
        @unsigned = unsigned
        @base = base
      end

      def unsigned?
        !!@unsigned
      end
    end

    class Int < Integral
    end

    class Long < Integral
    end

    class LongLong < Integral
    end

  end

end
