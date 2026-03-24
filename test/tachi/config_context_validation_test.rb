require_relative "test_helper"

class ConfigContextValidationTest < Minitest::Test
  def test_resolve_env_treats_nil_calc_env_value_as_empty_string
    ctx = build_context
    ctx.calc_env = {"MAYBE_EMPTY" => nil}

    resolved = ctx.resolve_env(wd: "/tmp/wd")

    assert_equal "", resolved["MAYBE_EMPTY"]
  end

  def test_resolve_env_expands_root_path_and_wd
    ctx = build_context
    ctx.calc_env = {
      "ROOTED" => "${ROOT_PATH}/config",
      "WORKDIR" => "${WD}/tmp",
    }

    resolved = ctx.resolve_env(wd: "/tmp/wd")

    assert_equal "/tmp/root/config", resolved["ROOTED"]
    assert_equal "/tmp/wd/tmp", resolved["WORKDIR"]
  end

  def test_resolve_env_raises_for_unknown_template_variable
    ctx = build_context
    ctx.calc_env = {"BAD" => "${NOPE}"}

    error = assert_raises(Tachi::ConfigError) do
      ctx.resolve_env(wd: "/tmp/wd")
    end

    assert_match(/could not resolve environment value: NOPE/i, error.message)
  end

  def test_validate_rejects_non_hash_env
    ctx = build_context
    ctx.env = []

    error = assert_raises(RuntimeError) do
      ctx.validate!
    end

    assert_match(/env must be an object\/hash/i, error.message)
  end

  def test_validate_rejects_non_hash_calc_env
    ctx = build_context
    ctx.calc_env = []

    error = assert_raises(RuntimeError) do
      ctx.validate!
    end

    assert_match(/calc_env must be an object\/hash/i, error.message)
  end

  def test_validate_rejects_empty_key_in_env
    ctx = build_context
    ctx.env = {"" => "bad"}

    error = assert_raises(RuntimeError) do
      ctx.validate!
    end

    assert_match(/key cannot be empty in env/i, error.message)
  end

  def test_validate_rejects_non_string_key_in_env
    ctx = build_context
    ctx.env = {nil => "bad"}

    error = assert_raises(RuntimeError) do
      ctx.validate!
    end

    assert_match(/key must be a string in env/i, error.message)
  end

  def test_validate_rejects_empty_key_in_calc_env
    ctx = build_context
    ctx.calc_env = {"" => "bad"}

    error = assert_raises(RuntimeError) do
      ctx.validate!
    end

    assert_match(/key cannot be empty in calc_env/i, error.message)
  end

  def test_validate_rejects_non_string_key_in_calc_env
    ctx = build_context
    ctx.calc_env = {123 => "bad"}

    error = assert_raises(RuntimeError) do
      ctx.validate!
    end

    assert_match(/key must be a string in calc_env/i, error.message)
  end

  private

  def build_context
    ctx = Tachi::Config::Context.new
    ctx.name = "default"
    ctx.root_path = "/tmp/root"
    ctx
  end
end
