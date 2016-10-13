require 'test_helper'

class Chelsy::ASTTest < Minitest::Test
  include Chelsy

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

end
