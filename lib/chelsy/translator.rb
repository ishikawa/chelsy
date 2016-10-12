module Chelsy

  class Translator
    def translate(node)
      case node
      when Constant::Integral
        translate_integral(node)
      else
        raise "Unrecognized AST node: #{node}"
      end
    end

    protected

    def translate_integral(node)
      integer_prefix(node) + node.value.to_s(node.base) + integer_suffix(node)
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
