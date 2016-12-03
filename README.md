# Chelsy

[![API References](https://img.shields.io/badge/doc-api-blue.svg)](http://www.rubydoc.info/gems/chelsy)
[![Build Status](https://travis-ci.org/ishikawa/chelsy.svg?branch=master)](https://travis-ci.org/ishikawa/chelsy)
[![Gem](https://img.shields.io/gem/v/chelsy.svg)](https://rubygems.org/gems/chelsy)

> C code generator library written in Ruby

**Chelsy** is C code generator library written in Ruby. You can construct AST objects and then transform it to C code.

**This library heavily under development. Anything may change at any time. The public API should not be considered stable.**

## Table of Contents

- [Installation](#installation)
- [Usage](#usage)
- [License](#license)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'chelsy'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install chelsy

## Usage

```ruby
require 'chelsy'

include Chelsy

doc = Document.new

doc.fragments << Directive::Include.new("stdio.h", system: true)

doc << Function.new(:main, Type::Int.new, [:void]) do |b|
  b << Operator::Call.new(:printf, ["Hello, Chelsy!\n"])
  b << Return.new(0)
end

puts Translator.new.translate(doc)
```

This script generates famous "Hello, World!" C program.

```c
#include <stdio.h>

int main(void) {
    printf("Hello, Chelsy!\n");
    return 0;
}
```

See [sample](https://github.com/ishikawa/chelsy/tree/master/sample) directory to find more samples.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
