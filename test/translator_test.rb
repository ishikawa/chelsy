require 'test_helper'

class Chelsy::TranslatorTest < Minitest::Test
  include Chelsy

  attr_reader :translator

  def setup
    @translator = Translator.new
  end

  def test_integer
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

  def test_string
    s = Constant::String.new("")
    assert_equal %q{""}, translator.translate(s)

    s = Constant::String.new("Hello, World!\n")
    assert_equal %q{"Hello, World!\n"}, translator.translate(s)

    s = Constant::String.new(%q{"''"})
    assert_equal %q{"\"''\""}, translator.translate(s)

    s = Constant::String.new(%q{Wide string literal}, wide: true)
    assert_equal %q{L"Wide string literal"}, translator.translate(s)
  end

  def test_function_call
    # identifier ( args )
    fc = FunctionCall.new(:abort, [])
    assert_equal %q{abort()}, translator.translate(fc)

    fc = FunctionCall.new(:printf, [Constant::String.new("Hello, World!\n")])
    assert_equal %q{printf("Hello, World!\n")}, translator.translate(fc)

    fc = FunctionCall.new(:exit, [Constant::Int.new(0)])
    assert_equal %q{exit(0)}, translator.translate(fc)

    # postfix-expr ( args )
    f1 = FunctionCall.new(:f1, [])
    f2 = FunctionCall.new(:f2, [])
    f3 = FunctionCall.new(:f3, [])
    fc = FunctionCall.new(f1, [f2, f3])
    assert_equal %q{f1()(f2(), f3())}, translator.translate(fc)
  end

  # = Statements and blocks

  def test_null_stmt
    stmt = EmptyStmt.new
    assert_equal ';', translator.translate(stmt)
  end

end
