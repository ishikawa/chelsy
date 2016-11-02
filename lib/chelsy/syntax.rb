module Chelsy; module Syntax

  class Rule
    attr_reader :name

    def initialize(name)
      @name = name.dup
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

  class Any < Rule
    def initialize(name, constraints)
      @constraints = constraints.dup
      super name
    end

    def accept?(node)
      @constraints.any? do |constraint|
        case constraint
        when Chelsy::Syntax::Rule
          constraint.accept?(node)
        else
          constraint === node
        end
      end
    end

  end

end; end
