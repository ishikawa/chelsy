require 'test_helper'

class Chelsy::TranslatorTest < Minitest::Test
  include Chelsy

  attr_reader :translator

  def setup
    @translator = Translator.new
  end

  def test_indent
    translator.indent_string = ' '
    translator.indent_level = 1
    assert_equal ' ;', translator.translate(EmptyStmt.new)

    # blocks
    b = Block.new << (Block.new << :x)

    translator.indent_string = "  "
    translator.indent_level = 0
    assert_equal <<PROG, translator.translate(b) + "\n"
{
  {
    x;
  }
}
PROG
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

  # = Types

  def test_types
    ty = Type::Int.new
    assert_equal 'int', translator.translate(ty)
    ty = Type::Int.new(unsigned: true)
    assert_equal 'unsigned int', translator.translate(ty)
    ty = Type::Int.new(unsigned: true, const: true)
    assert_equal 'const unsigned int', translator.translate(ty)
    ty = Type::Int.new(unsigned: true, const: true, volatile: true)
    assert_equal 'volatile const unsigned int', translator.translate(ty)
  end

  def test_derived_types
    ty = Type::Pointer.new(Type::Int.new)
    assert_equal 'int *', translator.translate(ty)
    ty = Type::Pointer.new(Type::Int.new, const: true)
    assert_equal 'int *const', translator.translate(ty)
    ty = Type::Pointer.new(Type::Int.new(const: true), const: true)
    assert_equal 'const int *const', translator.translate(ty)
    ty = Type::Pointer.new(Type::Int.new, const: true, volatile: true, restrict: true)
    assert_equal 'int *const volatile restrict', translator.translate(ty)

    ty = Type::Pointer.new(Type::Pointer.new(Type::Int.new))
    assert_equal 'int **', translator.translate(ty)
    ty = Type::Pointer.new(Type::Pointer.new(Type::Int.new, const: true))
    assert_equal 'int *const *', translator.translate(ty)
  end

  # = Expressions

  def test_array_subscption
    sub = Operator::Subscription.new(:x, Constant::Int.new(3))
    assert_equal 'x[3]', translator.translate(sub)

    sub = Operator::Subscription.new(sub, Constant::Int.new(5))
    assert_equal 'x[3][5]', translator.translate(sub)
  end

  def test_function_call
    # identifier ( args )
    fc = Operator::Call.new(:abort, [])
    assert_equal %q{abort()}, translator.translate(fc)

    fc = Operator::Call.new(:printf, [Constant::String.new("Hello, World!\n")])
    assert_equal %q{printf("Hello, World!\n")}, translator.translate(fc)

    fc = Operator::Call.new(:exit, [Constant::Int.new(0)])
    assert_equal %q{exit(0)}, translator.translate(fc)

    # postfix-expr ( args )
    f1 = Operator::Call.new(:f1, [])
    f2 = Operator::Call.new(:f2, [])
    f3 = Operator::Call.new(:f3, [])
    fc = Operator::Call.new(f1, [f2, f3])
    assert_equal %q{f1()(f2(), f3())}, translator.translate(fc)
  end

  def test_member_access
    ma = Operator::Access.new(:s, :i)
    assert_equal 's.i', translator.translate(ma)

    ma = Operator::IndirectAccess.new(:s, :i)
    assert_equal 's->i', translator.translate(ma)

    ma = Operator::Access.new(:u, :nf)
    ma = Operator::Access.new(ma, :type)
    assert_equal 'u.nf.type', translator.translate(ma)
  end

  def test_postfix_incr_decr
    node = Operator::PostfixIncrement.new(:x)
    assert_equal 'x++', translator.translate(node)

    node = Operator::PostfixDecrement.new(:x)
    assert_equal 'x--', translator.translate(node)

    # TODO incr/decr pointer expression should be `(*p)++`
  end

  def test_binary_ops
    node = Operator::Mul.new(:x, :y)
    assert_equal 'x * y', translator.translate(node)

    node = Operator::Add.new(node, :z)
    assert_equal 'x * y + z', translator.translate(node)

    node = Operator::Add.new(:x, :y)
    node = Operator::Mul.new(node, :z)
    assert_equal '(x + y) * z', translator.translate(node)
  end

  # = Statements and blocks

  def test_null_stmt
    stmt = EmptyStmt.new
    assert_equal ';', translator.translate(stmt)
  end

  def test_expr_stmt
    stmt = ExprStmt.new(Constant::Int.new(1))
    assert_equal '1;', translator.translate(stmt)
  end

  # = Declaration

  def test_declaration
    d = Declaration.new(:a, Type::Int.new)
    assert_equal 'int a;', translator.translate(d)
    d = Declaration.new(:b, Type::Int.new(unsigned: true, const: true), storage: :static)
    assert_equal 'static const unsigned int b;', translator.translate(d)

    t = Typedef.new(:cui, Type::Int.new(unsigned: true, const: true))
    assert_equal 'typedef const unsigned int cui;', translator.translate(t)
  end

  # = Function definition

  def test_function_definitions
    f = Function.new(:main, Type::Int.new, [:void]) do |b|
      b << Operator::Call.new(:printf, [Constant::String.new("Hello, World!\n")])
      b << Return.new(Constant::Int.new(0))
    end

    assert_equal <<PROG, translator.translate(f) + "\n"
int main(void) {
    printf("Hello, World!\\n");
    return 0;
}
PROG
  end

  # = Source file inclusion

  def test_source_file_inclusion
    doc = Document.new
    doc.fragments << Directive::Include.new("stdio.h", system: true)

    assert_equal <<PROG, translator.translate(doc)
#include <stdio.h>
PROG
  end

end
