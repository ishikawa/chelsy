require 'test_helper'

class Chelsy::ASTTest < Minitest::Test
  include Chelsy

  def test_function_definitions
    f = Function.new(:f, :void, []) do |b|
      b << Operator::Call.new(:printf, [Constant::String.new("Hello, World!\n")])
    end

    assert f
    assert_equal :f, f.name
    assert_equal :void, f.return_type
    assert Expr === f.body.first
  end

  def test_block
    b = Block.new()

    assert b.empty?
    assert_equal 0, b.size

    b << Return.new(Constant::Int.new(10))
    refute b.empty?
    assert_equal 1, b.size
    assert_equal 10, b[0].expr.value

    b[0, 1] = Return.new(Constant::Int.new(11))
    assert_equal 11, b[0].expr.value
    b[0] = Return.new(Constant::Int.new(12))
    assert_equal 12, b[0].expr.value
  end

  def test_struct
    s = Type::Struct.new(:s)

    assert_equal :s, s.tag
    assert_nil s.members
  end

  def test_while_stmt
    assert_raises(ArgumentError) do
      While.new(:loop1)
    end

    # body statement
    stmt = While.new(:loop1, Operator::PostfixIncrement.new(:x))
    assert_instance_of Operator::PostfixIncrement, stmt.body

    # Use code block
    stmt = While.new(:loop1) do |b|
      b << Operator::PostfixIncrement.new(:x)
    end
    assert 1 == stmt.body.size
    assert_instance_of Operator::PostfixIncrement, stmt.body[0]
  end

  def test_do_while_stmt
    assert_raises(ArgumentError) do
      DoWhile.new(:loop1)
    end

    # body statement
    stmt = DoWhile.new(:loop1, Operator::PostfixIncrement.new(:x))
    assert_instance_of Operator::PostfixIncrement, stmt.body

    # Use code block
    stmt = DoWhile.new(:loop1) do |b|
      b << Operator::PostfixIncrement.new(:x)
    end
    assert 1 == stmt.body.size
    assert_instance_of Operator::PostfixIncrement, stmt.body[0]
  end

  def test_for_stmt
    assert_raises(ArgumentError) do
      For.new()
    end

    stmt = For.new(nil, nil, nil, EmptyStmt.new)
    assert_instance_of EmptyStmt, stmt.body
  end

  def test_return
    ret = Return.new
    assert_nil ret.expr

    ret = Return.new(Constant::Int.new(1))
    assert ret.expr
  end

  def test_comment
    c = Comment::Multi.new("A\nB")
    assert ["A", "B"], c.lines

    c = Comment::Multi.new(['A', 'B'])
    assert ["A", "B"], c.lines
  end

  # == Fragment
  def test_expr_with_fragment
    node = Constant::Int.new(1)
    node.fragments << "test!"

    assert_equal ["test!"], node.fragments.to_a
  end

  # == Precedence
  def test_precedence
    assert_equal Operator::Mul.precedence, Operator::Div.precedence
    assert_operator Operator::PostfixIncrement.precedence, :>, Operator::Mul.precedence
    assert_operator Operator::Add.precedence, :<, Operator::Mul.precedence
  end

  # == Bad arguments

  def test_function_call
    assert_raises(ArgumentError) do
      Operator::Call.new(EmptyStmt.new, [])
    end

    assert_raises(ArgumentError) do
      Operator::Call.new(:f, [EmptyStmt.new])
    end
  end

  def test_function_param
    assert_raises(ArgumentError) do
      Param.new(EmptyStmt.new, Type::Int.new)
    end

    assert_raises(ArgumentError) do
      Param.new(:a, 1000)
    end
  end

end
