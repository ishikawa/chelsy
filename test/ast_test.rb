require 'test_helper'

class Chelsy::ASTTest < Minitest::Test
  include Chelsy

  def test_function_definitions
    f = Function.new(:f, :void, []) do |b|
      b << FunctionCall.new(:printf, [Constant::String.new("Hello, World!\n")])
    end

    assert f
    assert_equal :f, f.name
    assert_equal :void, f.return_type
    assert ExprStmt === f.body.first
  end

  def test_return
    ret = Return.new
    assert_nil ret.expr

    ret = Return.new(Constant::Int.new(1))
    assert ret.expr
  end

  # == Fragment
  def test_expr_with_fragment
    node = Constant::Int.new(1)
    node.fragments << "test!"

    assert_equal ["test!"], node.fragments.to_a
  end

  # == Bad arguments

  def test_function_call
    assert_raises(ArgumentError) do
      FunctionCall.new(EmptyStmt.new, [])
    end

    assert_raises(ArgumentError) do
      FunctionCall.new(:f, [EmptyStmt.new])
    end
  end

  def test_expr_stmt
    assert_raises(ArgumentError) do
      ExprStmt.new(EmptyStmt.new)
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
