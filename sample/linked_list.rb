require 'chelsy'

include Chelsy

doc = Document.new

doc.fragments << Directive::Include.new("stdio.h", system: true)
doc.fragments << Directive::Include.new("stdlib.h", system: true)

node_t =
  Typedef.new(:node_t,
    Type::Struct.new(:node, [
      Declaration.new(:value, Type::Int.new),
      Declaration.new(:next, Type::Pointer.new(Type::Struct.new(:node)))]))
node_t.fragments << Comment::Multi.new("A linked list node")
doc << node_t

puts Translator.new(indent_string: '  ').translate(doc)
