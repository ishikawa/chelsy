module Chelsy; end

# Syntax rules
module Chelsy::Syntax

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
    def initialize(name, classes)
      @classes = classes
      super name
    end

    def accept?(node)
      @classes.any? {|klass| klass === node }
    end
  end

end
