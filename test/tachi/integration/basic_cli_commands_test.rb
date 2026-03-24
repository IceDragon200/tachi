require_relative "test_helper"

require "open3"
require "psych"
require "rbconfig"

class ApplicationBasicCliCommandsTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir("tachi-basic-cli-tests")
    @root_path = File.join(@tmpdir, "context")
    @config_path = File.join(@tmpdir, "config.yml")
    @bin_path = File.expand_path("../../../bin/tachi", __dir__)

    FileUtils.mkdir_p(File.join(@root_path, "apps", "demo"))
    write_script(
      File.join(@root_path, "apps", "demo", "cmd.ok.sh"),
      <<~SH
        #!/usr/bin/env bash
        echo RUN_OK
      SH
    )
    write_script(
      File.join(@root_path, "apps", "demo", "cmd.plain"),
      <<~SH
        #!/usr/bin/env bash
        echo RUN_PLAIN
      SH
    )

    File.write(
      @config_path,
      <<~YAML
        default_context: smoke
        contexts:
          - name: smoke
            root_path: #{@root_path}
            env:
              BASE_ENV: base
            calc_env:
              FROM_WD: '${WD}'
              FROM_ROOT: '${ROOT_PATH}'
      YAML
    )
  end

  def teardown
    FileUtils.remove_entry(@tmpdir) if @tmpdir && Dir.exist?(@tmpdir)
  end

  def test_no_args_and_help_list_available_commands
    stdout, _stderr, status = run_tachi
    assert_equal 0, status.exitstatus
    assert_match(/HELP/, stdout)
    assert_match(/apps\.demo\.ok/, stdout)
    assert_match(/apps\.demo\.plain/, stdout)

    stdout, _stderr, status = run_tachi("help")
    assert_equal 0, status.exitstatus
    assert_match(/HELP/, stdout)
    assert_match(/apps\.demo\.ok/, stdout)
  end

  def test_version_and_flag_version_work
    stdout, _stderr, status = run_tachi("version")
    assert_equal 0, status.exitstatus
    assert_match(/Tachi v0\.5\.0/, stdout)

    stdout, _stderr, status = run_tachi("--version")
    assert_equal 0, status.exitstatus
    assert_match(/Tachi 0\.5\.0/, stdout)
  end

  def test_find_view_and_describe_work
    stdout, _stderr, status = run_tachi("find", "apps.demo.*")
    assert_equal 0, status.exitstatus
    assert_match(/apps\.demo\.ok/, stdout)
    assert_match(/apps\.demo\.plain/, stdout)

    stdout, _stderr, status = run_tachi("view", "apps.demo.ok")
    assert_equal 0, status.exitstatus
    assert_match(/RUN_OK/, stdout)

    stdout, _stderr, status = run_tachi("describe", "apps.demo.ok")
    assert_equal 0, status.exitstatus
    assert_match(/Command apps\.demo\.ok/, stdout)
    assert_match(/BASE_ENV=base/, stdout)
    assert_match(/FROM_ROOT=#{Regexp.escape(@root_path)}/, stdout)
  end

  def test_env_outputs_resolved_yaml_environment
    cwd = Dir.pwd
    stdout, _stderr, status = run_tachi("env")
    assert_equal 0, status.exitstatus

    env = Psych.safe_load(stdout)
    assert_equal "base", env["BASE_ENV"]
    assert_equal cwd, env["FROM_WD"]
    assert_equal @root_path, env["FROM_ROOT"]
  end

  private

  def run_tachi(*args, chdir: nil)
    command = [
      RbConfig.ruby,
      @bin_path,
      "-c",
      @config_path,
      *args,
    ]

    if chdir
      Open3.capture3(*command, chdir: chdir)
    else
      Open3.capture3(*command)
    end
  end

  def write_script(path, body)
    File.write(path, body)
    FileUtils.chmod(0o755, path)
  end
end
