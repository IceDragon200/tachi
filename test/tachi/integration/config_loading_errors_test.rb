require_relative "test_helper"

require "open3"
require "rbconfig"

class ApplicationConfigLoadingErrorsTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir("tachi-config-errors-tests")
    @bin_path = File.expand_path("../../../bin/tachi", __dir__)
  end

  def teardown
    FileUtils.remove_entry(@tmpdir) if @tmpdir && Dir.exist?(@tmpdir)
  end

  def test_malformed_yaml_config_exits_non_zero_with_psych_syntax_error
    stdout, stderr, status = run_tachi_with_config(
      <<~YAML,
        contexts:
          - name: default
            root_path: /tmp
            env:
              BROKEN: [
      YAML
      "env"
    )

    combined = "#{stdout}\n#{stderr}"

    assert_equal 1, status.exitstatus
    assert_match(/Psych::SyntaxError/, combined)
    assert_match(/did not find expected|while parsing|syntax/i, combined)
  end

  def test_invalid_env_type_exits_non_zero_with_validation_message
    stdout, stderr, status = run_tachi_with_config(
      <<~YAML,
        contexts:
          - name: default
            root_path: /tmp
            env: []
      YAML
      "env"
    )

    combined = "#{stdout}\n#{stderr}"

    assert_equal 1, status.exitstatus
    assert_match(/env must be an object\/hash of KEY=VALUE pairs/i, combined)
  end

  def test_invalid_calc_env_type_exits_non_zero_with_validation_message
    stdout, stderr, status = run_tachi_with_config(
      <<~YAML,
        contexts:
          - name: default
            root_path: /tmp
            calc_env: []
      YAML
      "env"
    )

    combined = "#{stdout}\n#{stderr}"

    assert_equal 1, status.exitstatus
    assert_match(/calc_env must be an object\/hash of KEY=VALUE pairs/i, combined)
  end

  private

  def run_tachi_with_config(config_body, *args)
    config_path = File.join(@tmpdir, "config.yml")
    File.write(config_path, config_body)
    Open3.capture3(RbConfig.ruby, @bin_path, "-c", config_path, *args)
  end
end
