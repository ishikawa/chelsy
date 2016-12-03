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
      # Most C program uses C preprocessor, so we must accept any C code snippet.
      case node
      when Chelsy::Raw
        true
      else
        false
      end
    end

    # Try to coerce `obj` to acceptable node.
    #
    # @param obj Any object to coerce
    # @return [Node] A node or `nil` if it can't be coerced.
    def coerce(obj)
      nil
    end

    def ensure(node)
      if accept?(node)
        node
      else
        coerce(node).tap do |coerced|
          raise ArgumentError, "#{node.class.name} is not one of #{@name}" unless coerced
        end
      end
    end
  end

  # This constraint accepts an instance of specific type of node, or
  # can coerce some other type of objects to such a node.
  class Coercer < Constraint
    # Initialize an instance.
    #
    # @param [Class] klass type of acceptable node.
    # @yieldparam value the value will be coerced.
    # @yieldreturn [Node, nil] the coerced value of `nil`
    def initialize(klass, &block)
      @class = klass
      @coercer_block = block

      super klass.name
    end

    def accept?(node)
      @class === node || super(node)
    end

    def coerce(node)
      @coercer_block.call(node)
    end
  end

  # This constraint instance is composed of multiple constraints.
  class Any < Constraint

    # Initialize an instance with constraints.
    #
    # @param [String] name the name of this constraint
    # @param [Array<Constraint>] constraints constraints
    def initialize(name, constraints)
      @constraints = constraints.dup
      super name
    end

    def coerce(node)
      @constraints
      .lazy
      .find_all {|c| c.respond_to?(:coerce) }
      .map {|c| c.coerce(node) }
      .reject(&:nil?)
      .first
    end

    def accept?(node)
      @constraints.any? {|constraint| constraint === node} || super(node)
    end
  end

end; end
