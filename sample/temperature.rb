require 'chelsy'

include Chelsy

doc = Document.new

doc.fragments << Directive::Include.new("stdio.h", system: true)
doc.fragments << ''
doc.fragments << Comment::Multi.new([
  "Print Fahrenheit to Celsius table",
  "(fahr = 0, 20, ..., 300)"
])
doc.fragments << Directive::Define.new(:LOWER, '0')
doc.fragments << Directive::Define.new(:UPPER, '300')
doc.fragments << Directive::Define.new(:STEP,  '20')

doc << Function.new(:main,
                    Type::Int.new, [
                      Param.new(:argc, Type::Int.new),
                      Param.new(:argv, Type::Pointer.new(Type::Pointer.new(Type::Char.new(const: true)))),
                    ]) do |b|
  init = Declaration.new(:fahr, Type::Int.new, 'LOWER')
  cond = Operator::LessThanOrEqual.new(:fahr, 'UPPER')
  step = Operator::AssignAdd.new(:fahr, 'STEP')

  stmt = Block.new.tap do |b|
    celsius = Operator::Sub.new(:fahr, Constant::Int.new(32))
    celsius = Operator::Mul.new(Constant::Int.new(5), celsius)
    celsius = Operator::Div.new(celsius, Constant::Int.new(9))

    b << Declaration.new(:celsius, Type::Int.new, celsius)
    b << Operator::Call.new(:printf, [Constant::String.new("%d\t%d\n"), :fahr, :celsius])
  end

  b << For.new(init, cond, step, stmt)
  b << Return.new(Constant::Int.new(0))
end

puts Translator.new(indent_string: '  ').translate(doc)
