require_relative "test_helper"

class TestVersion < Minitest::Test
  def test_version_is_defined
    refute_nil Zvec::VERSION
  end

  def test_version_is_a_string
    assert_kind_of String, Zvec::VERSION
  end

  def test_version_format
    assert_match(/\A\d+\.\d+\.\d+/, Zvec::VERSION)
  end

  def test_version_value
    assert_equal "0.2.0", Zvec::VERSION
  end
end
