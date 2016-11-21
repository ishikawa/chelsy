require 'test_helper'

class Chelsy::SampleTest < Minitest::Test
  SAMPLE_DIR = File.expand_path('../../sample/', __FILE__)

  def test_hello
    validate_generate_sample 'hello_chelsy'
  end

  private

  def validate_generate_sample(name)
    path = File.join(SAMPLE_DIR, "#{name}.rb")
    csrc = File.read(File.join(SAMPLE_DIR, "#{name}.c"))

    assert_output(csrc) do
      load path
    end
  end

end
