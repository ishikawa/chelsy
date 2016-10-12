module Chelsy

  class Translator
    def translate(node)
      case node
      when Constant::Integral
        translate_integral(node)
      when Constant::String
        translate_string(node)
      else
        raise ArgumentError, "Unrecognized AST node: #{node}"
      end
    end

    protected

    def translate_integral(node)
      integer_prefix(node) + node.value.to_s(node.base) + integer_suffix(node)
    end

    def translate_string(node)
      if node.wide?
        'L' + node.value.dump
      else
        node.value.dump
      end
    end

    private

    def integer_prefix(node)
      case node.base
      when 8
        "0"
      when 10
        ""
      when 16
        "0x"
      else
        raise ArgumentError, "Unsupported radix: #{node.base}"
      end
    end

    def integer_suffix(node)
      suffix = case node
      when Constant::Long
        "l"
      when Constant::LongLong
        "ll"
      else
        ""
      end

      if node.unsigned?
        "#{suffix}u"
      else
        suffix
      end
    end
  end

end
