module Chelsy; module Syntax

  class Constraint
    attr_reader :name

    # Initialize instance. You must suply its `name` to debugging purpose.
    #
    # @param name [String] the name of this constraint
    def initialize(name)
      @name = name.dup
    end

    def ===(node)
      accept?(node)
    end

    def accept?(node)
      false
    end

    def ensure(node)
      if accept?(node)
        node
      else
        raise ArgumentError, "#{node.class.name} is not one of #{@name}"
      end
    end
  end

  class Any < Constraint
    def initialize(name, constraints)
      @constraints = constraints.dup
      super name
    end

    def accept?(node)
      # Most C program uses C preprocessor, so we must accept any C code snippet.
      case node
      when Chelsy::Raw
        true
      else
        @constraints.any? do |constraint|
          constraint === node
        end
      end
    end

  end

end; end
