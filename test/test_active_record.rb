require_relative "test_helper"

# Unit tests for the ActiveRecord::Vectorize concern (pure Ruby logic only).
# These test the module structure and configuration without requiring Rails
# or a real database.
class TestActiveRecordVectorize < Minitest::Test
  def setup
    @ar_available = begin
      require "zvec/active_record"
      true
    rescue LoadError
      false
    end
  end

  def test_module_defined
    skip "active_record deps not available" unless @ar_available
    assert defined?(Zvec::ActiveRecord::Vectorize)
  end

  def test_instance_methods_module_defined
    skip "active_record deps not available" unless @ar_available
    assert defined?(Zvec::ActiveRecord::Vectorize::InstanceMethods)
  end

  def test_search_methods_module_defined
    skip "active_record deps not available" unless @ar_available
    assert defined?(Zvec::ActiveRecord::Vectorize::SearchMethods)
  end

  def test_instance_methods_has_zvec_update_embedding
    skip "active_record deps not available" unless @ar_available
    assert Zvec::ActiveRecord::Vectorize::InstanceMethods.instance_methods.include?(:zvec_update_embedding!)
  end

  def test_instance_methods_has_zvec_remove_embedding
    skip "active_record deps not available" unless @ar_available
    assert Zvec::ActiveRecord::Vectorize::InstanceMethods.instance_methods.include?(:zvec_remove_embedding!)
  end

  def test_instance_methods_has_zvec_embedding
    skip "active_record deps not available" unless @ar_available
    assert Zvec::ActiveRecord::Vectorize::InstanceMethods.instance_methods.include?(:zvec_embedding)
  end

  def test_search_methods_has_zvec_store
    skip "active_record deps not available" unless @ar_available
    assert Zvec::ActiveRecord::Vectorize::SearchMethods.instance_methods.include?(:zvec_store)
  end

  def test_search_methods_has_vector_search
    skip "active_record deps not available" unless @ar_available
    assert Zvec::ActiveRecord::Vectorize::SearchMethods.instance_methods.include?(:vector_search)
  end
end
