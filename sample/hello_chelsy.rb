require 'chelsy'

include Chelsy

doc = Document.new

doc.fragments << Directive::Include.new("stdio.h", system: true)

doc << Function.new(:main, Type::Int.new, [:void]) do |b|
  b << Operator::Call.new(:printf, ["Hello, Chelsy!\n"])
  b << Return.new(0)
end

puts Translator.new.translate(doc)
