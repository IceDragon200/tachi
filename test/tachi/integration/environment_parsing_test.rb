require_relative "test_helper"

class ApplicationEnvironmentParsingTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir("tachi-env-tests")
    @root_path = File.join(@tmpdir, "context")
    FileUtils.mkdir_p(@root_path)

    @app = Tachi::Application.new
    ctx = Tachi::Config::Context.new
    ctx.root_path = @root_path
    @app.instance_variable_set(:@context, ctx)
  end

  def teardown
    FileUtils.remove_entry(@tmpdir) if @tmpdir && Dir.exist?(@tmpdir)
  end

  def test_raises_parse_error_for_malformed_environment_line
    service_dir = File.join(@root_path, "apps", "bm", "my_cool_app")
    write_environment(service_dir, <<~ENV)
      GOOD=value
      MALFORMED_LINE
    ENV

    error = assert_raises(Tachi::EnvironmentFile::InvalidEnvironmentVariableError) do
      @app.get_environment_for_path(service_dir)
    end

    assert_match(/value cannot be nil/i, error.message)
  end

  def test_preserves_equals_signs_in_values
    service_dir = File.join(@root_path, "apps", "bm", "my_cool_app")
    write_environment(service_dir, "TOKEN=abc=def\n")

    env = @app.get_environment_for_path(service_dir)

    assert_equal "abc=def", env["TOKEN"]
  end

  def test_ignores_empty_blank_lines
    service_dir = File.join(@root_path, "apps", "bm", "my_cool_app")
    write_environment(service_dir, "A=1\n\nB=2\n")

    env = @app.get_environment_for_path(service_dir)

    assert_equal "1", env["A"]
    assert_equal "2", env["B"]
  end

  def test_child_directory_environment_overrides_parent_directory
    apps_dir = File.join(@root_path, "apps")
    service_dir = File.join(@root_path, "apps", "bm", "my_cool_app")
    write_environment(apps_dir, "LEVEL=apps\n")
    write_environment(service_dir, "LEVEL=service\n")

    env = @app.get_environment_for_path(service_dir)

    assert_equal "service", env["LEVEL"]
  end

  def test_includes_root_environment_file
    service_dir = File.join(@root_path, "apps", "bm", "my_cool_app")
    write_environment(@root_path, "ROOT_ONLY=enabled\n")
    FileUtils.mkdir_p(service_dir)

    env = @app.get_environment_for_path(service_dir)

    assert_equal "enabled", env["ROOT_ONLY"]
  end

  private

  def write_environment(path, contents)
    FileUtils.mkdir_p(path)
    File.write(File.join(path, "environment"), contents)
  end
end
