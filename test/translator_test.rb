require 'test_helper'

class Chelsy::TranslatorTest < Minitest::Test
  include Chelsy

  def test_integer
    translator = Translator.new

    i = Constant::Int.new(1)
    assert_equal "1", translator.translate(i)

    i = Constant::Int.new(2, unsigned: true)
    assert_equal "2u", translator.translate(i)

    # Hexadecimal
    i = Constant::Int.new(3, unsigned: false, base: 16)
    assert_equal "0x3", translator.translate(i)

    i = Constant::Long.new(1_000, unsigned: true, base: 16)
    assert_equal "0x3e8lu", translator.translate(i)

    # Octadecimal
    i = Constant::Int.new(3, unsigned: false, base: 8)
    assert_equal "03", translator.translate(i)

    i = Constant::Long.new(1_000, unsigned: true, base: 8)
    assert_equal "01750lu", translator.translate(i)

    # Unsupported radix
    i = Constant::Long.new(1, base: 7)
    assert_raises(ArgumentError) do
      translator.translate(i)
    end
  end
end
