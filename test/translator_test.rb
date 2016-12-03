require 'test_helper'

class Chelsy::TranslatorTest < Minitest::Test
  include Chelsy

  attr_reader :translator

  def setup
    @translator = Translator.new
  end

  def test_indent
    b = Block.new << EmptyStmt.new

    translator.indent_string = ' '
    translator.indent_level = 1
    assert_equal <<PROG, translator.translate(b) + "\n"
{
  ;
 }
PROG

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

  def test_pointer_types
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

  def test_struct_types
    ty = Type::Struct.new(:tnode)
    assert_equal 'struct tnode', translator.translate(ty)

    ty = Type::Struct.new(:s, [
        Declaration.new(:n, Type::Int.new),
      ])
    assert_equal <<PROG, translator.translate(ty) + "\n"
struct s {
    int n;
}
PROG

    ty = Type::Struct.new(:s, [
        Declaration.new(:n, Type::Int.new),
        Declaration.new(:d, Type::Array.new(Type::Double.new)),
      ])
    assert_equal <<PROG, translator.translate(ty) + "\n"
struct s {
    int n;
    double d[];
}
PROG

    # bit-field
    ty = Type::Struct.new(:s, [
        BitField.new(
          Constant::Int.new(3),
          Declaration.new(:b1, Type::Char.new(unsigned: true))),
        BitField.new(
          Constant::Int.new(2)),
        BitField.new(
          Constant::Int.new(6),
          Declaration.new(:b2, Type::Char.new(unsigned: true))),
      ])
    assert_equal <<PROG, translator.translate(ty) + "\n"
struct s {
    unsigned char b1 : 3;
    : 2;
    unsigned char b2 : 6;
}
PROG
  end

  def test_union_types
    ty = Type::Union.new(:U)
    assert_equal 'union U', translator.translate(ty)

    ty = Type::Union.new(:U, [
        Declaration.new(:i, Type::Int.new),
        BitField.new(
          Constant::Int.new(3),
          Declaration.new(:c, Type::Char.new(unsigned: true))),
        Declaration.new(:s, Type::Struct.new(:S)),
      ])
    assert_equal <<PROG, translator.translate(ty) + "\n"
union U {
    int i;
    unsigned char c : 3;
    struct S s;
}
PROG
  end

  def test_enum_types
    ty = Type::Enum.new(:E)
    assert_equal 'enum E', translator.translate(ty)

    ty = Type::Enum.new(:hue, [
      :chartreuse,
      :burgundy,
      EnumMember.new(:claret, Constant::Int.new(20)),
      :winedark,
    ])
    assert_equal <<PROG, translator.translate(ty) + "\n"
enum hue {
    chartreuse,
    burgundy,
    claret = 20,
    winedark
}
PROG
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

    node = Operator::PostfixIncrement.new(Operator::Dereference.new(:p))
    assert_equal '(*p)++', translator.translate(node)
  end

  def test_prefix_incr_decr
    node = Operator::PrefixIncrement.new(:x)
    assert_equal '++x', translator.translate(node)

    node = Operator::PrefixDecrement.new(:x)
    assert_equal '--x', translator.translate(node)

    node = Operator::Sub.new(
        Operator::PostfixDecrement.new(:x),
        Operator::PrefixDecrement.new(:x))
    assert_equal 'x-- - --x', translator.translate(node)
  end

  def test_type_cast
    node = Operator::Cast.new(:x, Type::Pointer.new(Type::Int.new()))
    assert_equal '(int *)x', translator.translate(node)
  end

  def test_sizeof
    node = Operator::SizeOf.new(Type::Int.new())
    assert_equal 'sizeof(int)', translator.translate(node)
    node = Operator::SizeOf.new(Operator::Subscription.new(:x, Constant::Int.new(0)))
    assert_equal 'sizeof(x[0])', translator.translate(node)
    node = Operator::SizeOf.new(Operator::Add.new(:x, :y))
    assert_equal 'sizeof(x + y)', translator.translate(node)
  end

  def test_binary_ops
    node = Operator::Mul.new(:x, :y)
    assert_equal 'x * y', translator.translate(node)

    node = Operator::Add.new(node, :z)
    assert_equal 'x * y + z', translator.translate(node)

    node = Operator::Add.new(:x, :y)
    node = Operator::Mul.new(node, :z)
    assert_equal '(x + y) * z', translator.translate(node)

    node = Operator::Comma.new(
      Operator::Add.new(:x, :y),
      Operator::Mul.new(:x, :y))
    assert_equal 'x + y, x * y', translator.translate(node)
  end

  def test_ternary_conditional
    node = Operator::Conditional.new(
      Operator::Not.new(Operator::Not.new(:b)),
      Operator::BitwiseAnd.new(:x, Constant::Int.new(7, base: 16)),
      :x)
    assert_equal '!!b ? (x & 0x7) : x', translator.translate(node)
  end

  def test_macro
    node = Macro.new(:F, [Constant::Int.new(1), Constant::Int.new(2)])
    assert_equal 'F(1, 2)', translator.translate(node)

    node = Macro.new(:in_between, [Raw.new('c hash_hash d')])
    assert_equal 'in_between(c hash_hash d)', translator.translate(node)

    node = Macro.new(:UPPER)
    assert_equal 'UPPER', translator.translate(node)
  end

  # = Statements and blocks

  def test_null_stmt
    stmt = EmptyStmt.new
    assert_equal '', translator.translate(stmt)
  end

  def test_if_stmt
    stmt = If.new(
      Operator::LessThan.new(:x, Constant::Int.new(0)),
      Return.new(Constant::Int.new(1)))
    assert_equal <<PROG, translator.translate(stmt) + "\n"
if (x < 0) return 1
PROG

    stmt = If.new(
      Operator::LessThan.new(:x, Constant::Int.new(0)),
      Block.new([Return.new(Constant::Int.new(1))])
    )
    assert_equal <<PROG, translator.translate(stmt) + "\n"
if (x < 0) {
    return 1;
}
PROG

    stmt = If.new(
      Operator::LessThan.new(:x, Constant::Int.new(0)),
      Block.new([Return.new(Constant::Int.new(1))]),
      Block.new([Return.new(Constant::Int.new(2))])
    )
    assert_equal <<PROG, translator.translate(stmt) + "\n"
if (x < 0) {
    return 1;
} else {
    return 2;
}
PROG
  end

  def test_switch_stmt
    stmt = Switch.new(
      :x,
      Block.new([
        Case.new(Constant::Int.new(1), Operator::PostfixIncrement.new(:x)),
        Break.new,
        Labeled.new(:default, Operator::PostfixDecrement.new(:x)),
        Break.new,
      ])
    )
    assert_equal <<PROG, translator.translate(stmt) + "\n"
switch (x) {
case 1:
    x++;
    break;
default:
    x--;
    break;
}
PROG
  end

  def test_goto
    stmt = While.new(:loop1, Block.new([
      While.new(:loop2, Block.new([
        If.new(:want_out, Goto.new(:end_loop1))
      ])),
      Labeled.new(:end_loop1, EmptyStmt.new),
    ]))
    assert_equal <<PROG, translator.translate(stmt) + "\n"
while (loop1) {
    while (loop2) {
        if (want_out) goto end_loop1;
    }
end_loop1:
    ;
}
PROG
  end

  def test_while_stmt
    stmt = While.new(
      Operator::LessThan.new(:x, Constant::Int.new(0)),
      Operator::AssignAdd.new(:x, Constant::Int.new(1)))
    assert_equal <<PROG, translator.translate(stmt) + "\n"
while (x < 0) x += 1
PROG

    stmt = While.new(
      Operator::LessThan.new(:x, Constant::Int.new(0)),
      Block.new([Operator::AssignAdd.new(:x, Constant::Int.new(1))])
    )
    assert_equal <<PROG, translator.translate(stmt) + "\n"
while (x < 0) {
    x += 1;
}
PROG
  end

  def test_do_while_stmt
    stmt = DoWhile.new(
      Operator::LessThan.new(:x, Constant::Int.new(0)),
      Operator::AssignAdd.new(:x, Constant::Int.new(1)))
    assert_equal <<PROG, translator.translate(stmt) + "\n"
do x += 1 while (x < 0)
PROG

    stmt = DoWhile.new(
      Operator::LessThan.new(:x, Constant::Int.new(0)),
      Block.new([Operator::AssignAdd.new(:x, Constant::Int.new(1))])
    )
    assert_equal <<PROG, translator.translate(stmt) + "\n"
do {
    x += 1;
} while (x < 0)
PROG
  end

  def test_for_stmt
    stmt = For.new do |b|
      b << Break.new
      b << Continue.new
    end
    assert_equal <<PROG, translator.translate(stmt) + "\n"
for (;;) {
    break;
    continue;
}
PROG

    stmt = For.new(
      Declaration.new(:i, Type::Int.new, Constant::Int.new(0)),
      Operator::LessThan.new(:i, Constant::Int.new(10)),
      Operator::PostfixIncrement.new(:i),
      Block.new([Operator::AssignAdd.new(:x, Constant::Int.new(1))]))
    assert_equal <<PROG, translator.translate(stmt) + "\n"
for (int i = 0; i < 10; i++) {
    x += 1;
}
PROG
  end

  # = Declaration

  def test_initializer
    d = Declaration.new(:a, Type::Int.new, Constant::Int.new(3))
    assert_equal 'int a = 3', translator.translate(d)

    d = Declaration.new(:m, Type::Array.new(Type::Int.new), [
        Constant::Int.new(1),
        Constant::Int.new(2),
        Constant::Int.new(3),
      ])
    assert_equal 'int m[] = { 1, 2, 3 }', translator.translate(d)

    d = Declaration.new(:m, Type::Array.new(Type::Int.new), [
        Initializer.new(Constant::Int.new(1)),
        Initializer.new(Constant::Int.new(2), IndexDesignator.new(:member_two))
      ])
    assert_equal 'int m[] = { 1, [member_two] = 2 }', translator.translate(d)

    d = Declaration.new(:w, Type::Struct.new(:s), [
        Initializer.new(Constant::Int.new(1), MemberDesignator.new(:a))
      ])
    assert_equal 'struct s w = { .a = 1 }', translator.translate(d)
  end

  def test_declaration
    d = Declaration.new(:a, Type::Int.new)
    assert_equal 'int a', translator.translate(d)
    d = Declaration.new(:b, Type::Int.new(unsigned: true, const: true), storage: :static)
    assert_equal 'static const unsigned int b', translator.translate(d)
    d = Declaration.new(:C, Type::Array.new(Type::Array.new(Type::Int.new, :m), :m))
    assert_equal 'int C[m][m]', translator.translate(d)

    t = Typedef.new(:cui, Type::Int.new(unsigned: true, const: true))
    assert_equal 'typedef const unsigned int cui', translator.translate(t)
  end

  def test_array_type_declaration
    ty = Type::Array.new(Type::Int.new)
    d = Declaration.new(:x, ty)
    assert_equal 'int x[]', translator.translate(d)

    # variable length array type of unspecified size
    ty = Type::Array.new(Type::Int.new, :*)
    d = Declaration.new(:x, ty)
    assert_equal 'int x[*]', translator.translate(d)

    ty = Type::Array.new(Type::Int.new, Constant::Int.new(5))
    d = Declaration.new(:x, ty)
    assert_equal 'int x[5]', translator.translate(d)

    # `static` in parameter array declarator
    ty = Type::Array.new(Type::Int.new, Constant::Int.new(5), static: true)
    d = Declaration.new(:x, ty)
    assert_equal 'int x[static 5]', translator.translate(d)

    # type qualifiers in parameter array declarator
    ty = Type::Array.new(Type::Int.new, Constant::Int.new(5), const: true, static: true)
    d = Declaration.new(:x, ty)
    assert_equal 'int x[const static 5]', translator.translate(d)
  end

  def test_function_declaration
    d = Declaration.new(:f, Type::Function.new(Type::Int.new, [:void]))
    assert_equal 'int f(void)', translator.translate(d)
    d = Declaration.new(:f, Type::Function.new(Type::Pointer.new(Type::Int.new), [:void]))
    assert_equal 'int *f(void)', translator.translate(d)
    d = Declaration.new(:pfi, Type::Pointer.new(Type::Function.new(Type::Int.new, [])))
    assert_equal 'int (*pfi)()', translator.translate(d)

    # Function pointers
    ty = Type::Function.new(Type::Int.new, [:void])
    f = Type::Function.new(:void, [ty])
    d = Declaration.new(:f, f)
    assert_equal 'void f(int (*)(void))', translator.translate(d)

    f = Type::Function.new(Type::Int.new, [
        Param.new(:x, Type::Int.new),
        Param.new(:y, Type::Int.new),
      ])
    d = Declaration.new(:apfi, Type::Array.new(f, Constant::Int.new(3)))
    assert_equal 'int (*apfi[3])(int x, int y)', translator.translate(d)

    f = Type::Function.new(Type::Int.new, [
        Type::Int.new(),
        :"...",
      ])
    f = Type::Function.new(Type::Pointer.new(f), [
        Type::Function.new(Type::Int.new, [Type::Long.new]),
        Type::Int.new,
      ])
    d = Declaration.new(:fpfi, f)
    assert_equal 'int (*fpfi(int (*)(long), int))(int, ...)', translator.translate(d)

    f = Type::Function.new(Type::Int.new, [:void])
    fp = Type::Pointer.new(Type::Pointer.new(f))
    f = Type::Function.new(fp, [Type::Int.new])
    d = Declaration.new(:fpp, f)
    assert_equal 'int (**fpp(int))(void)', translator.translate(d)

    # atexit
    f = Type::Function.new(Type::Int.new, [
        Param.new(:func, Type::Function.new(:void, [:void])),
      ])
    d = Declaration.new(:atexit, f)
    assert_equal 'int atexit(void (*func)(void))', translator.translate(d)

    # x is function returning pointer to array[] of pointer to function returning char
    a = Type::Function.new(Type::Char.new, [])
    a = Type::Array.new(Type::Pointer.new(a))
    f = Type::Function.new(Type::Pointer.new(a), [])
    d = Declaration.new(:x, f)
    assert_equal 'char (*(*x())[])()', translator.translate(d)
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

  def test_define
    doc = Document.new
    doc.fragments << Directive::Define.new(:hash_hash, Raw.new('# ## #'))
    doc.fragments << Directive::Define.new(:mkstr, [:a], Raw.new('# a'))
    doc.fragments << Directive::Define.new(:in_between, [:a], Raw.new('mkstr(a)'))
    doc.fragments << Directive::Define.new(:join, [:c, :d], Raw.new('in_between(c hash_hash d)'))

    assert_equal <<PROG, translator.translate(doc)
#define hash_hash # ## #
#define mkstr(a) # a
#define in_between(a) mkstr(a)
#define join(c, d) in_between(c hash_hash d)
PROG
  end

  def test_if_directive
    doc = Document.new
    doc.fragments << Directive::If.new(Operator::Equal.new(:VERSION, Constant::Int.new(1)))
    doc.fragments << Directive::Define.new(:INCFILE, Constant::String.new("vers1.h"))
    doc.fragments << Directive::ElseIf.new(Operator::Equal.new(:VERSION, Constant::Int.new(2)))
    doc.fragments << Directive::Define.new(:INCFILE, Constant::String.new("vers2.h"))
    doc.fragments << Directive::EndIf.new()

    assert_equal <<PROG, translator.translate(doc)
#if VERSION == 1
#define INCFILE "vers1.h"
#elif VERSION == 2
#define INCFILE "vers2.h"
#endif
PROG

    doc = Document.new
    doc.fragments << Directive::If.new(Operator::Defined.new(:VERSION))
    assert_equal <<PROG, translator.translate(doc)
#if defined VERSION
PROG
  end

  def test_undef
    doc = Document.new
    doc.fragments << Directive::Undef.new(:INCFILE)

    assert_equal <<PROG, translator.translate(doc)
#undef INCFILE
PROG
  end

  def test_line
    doc = Document.new
    doc.fragments << Directive::Line.new(14)
    doc.fragments << Directive::Line.new(15, "copy.c")

    assert_equal <<PROG, translator.translate(doc)
#line 14
#line 15 "copy.c"
PROG
  end

  def test_pragma
    doc = Document.new
    doc.fragments << Directive::Pragma.new("GCC poison printf sprintf fprintf")
    doc.fragments << Directive::StdcPragma.new(:FP_CONTRACT, :ON)

    assert_equal <<PROG, translator.translate(doc)
#pragma GCC poison printf sprintf fprintf
#pragma STDC FP_CONTRACT ON
PROG
  end

  def test_comment
    # single line comment
    f = Function.new(:foo, Type::Int.new, []) do |b|
      b << Return.new(Constant::Int.new(0))
    end

    f.fragments << Comment::Single.new("comment")

    assert_equal <<PROG, translator.translate(f) + "\n"
// comment
int foo() {
    return 0;
}
PROG

    # multi comment with single line
    f = Function.new(:foo, Type::Int.new, []) do |b|
      b << Return.new(Constant::Int.new(0))
    end

    f.fragments << Comment::Multi.new("Line 1")

    assert_equal <<PROG, translator.translate(f) + "\n"
/* Line 1 */
int foo() {
    return 0;
}
PROG

    # multiline
    f = Function.new(:foo, Type::Int.new, []) do |b|
      b << Return.new(Constant::Int.new(0))
    end

    f.fragments << Comment::Multi.new("Line 1\nLine 2")

    assert_equal <<PROG, translator.translate(f) + "\n"
/*
 * Line 1
 * Line 2
 */
int foo() {
    return 0;
}
PROG
  end

  # document
  def test_document
    # empty
    doc = Document.new
    assert_equal '', translator.translate(doc)

    # stmts
    doc = Document.new
    doc.fragments << Directive::Include.new("stdio.h", system: true)

    doc << Function.new(:f1, Type::Int.new, [:void]) do |b|
      b << Return.new(Constant::Int.new(1))
    end
    doc << Function.new(:f2, Type::Int.new, [:void]) do |b|
      b << Return.new(Constant::Int.new(2))
    end

    assert_equal <<PROG, translator.translate(doc) + "\n"
#include <stdio.h>

int f1(void) {
    return 1;
}

int f2(void) {
    return 2;
}
PROG

  end

  ## Coerces Ruby objects to Node objects

  def test_coerce_integer
    # expression
    expr = Operator::Add.new(:x, 1)
    assert_equal 'x + 1', translator.translate(expr)

    # bit-field
    ty = Type::Struct.new(:s, [
        BitField.new(3, Declaration.new(:b1, Type::Char.new(unsigned: true))),
      ])
    assert_equal <<PROG, translator.translate(ty) + "\n"
struct s {
    unsigned char b1 : 3;
}
PROG
  end

  def test_coerce_string
    # declaration
    d = Declaration.new(:greeting, Type::Pointer.new(Type::Char.new), "Hi")

    assert_equal 'char *greeting = "Hi"', translator.translate(d)
  end

end
