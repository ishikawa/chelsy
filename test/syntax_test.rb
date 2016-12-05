require 'test_helper'

class Chelsy::SyntaxTest < Minitest::Test
  include Chelsy
end

class Chelsy::Syntax::ExprTest < Chelsy::SyntaxTest

  def test_accept
    constraint = Syntax::Expr

    refute constraint.accept?(nil)
    refute constraint.accept?(1)
    assert constraint.accept?(Constant::Int.new(1))
  end

  def test_ensure
    constraint = Syntax::Expr

    assert_instance_of Constant::Int, constraint.ensure(1)
    assert_raises ArgumentError do
      constraint.ensure(nil)
    end
  end

end

class Chelsy::Syntax::Coercers::IntTest < Chelsy::SyntaxTest
  def test_accept
    coercer = Syntax::Coercers::Int

    refute coercer.accept?(nil)
    refute coercer.accept?(1)
    assert coercer.accept?(Constant::Int.new(1))
  end

  def test_coerce
    coercer = Syntax::Coercers::Int

    refute coercer.coerce(nil)
    refute coercer.coerce("")
    assert_instance_of Constant::Int, coercer.coerce(1)
  end
end
