require_relative "test_helper"

require "open3"
require "rbconfig"

class ApplicationRunCliBehaviorTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir("tachi-run-cli-tests")
    @root_path = File.join(@tmpdir, "context")
    FileUtils.mkdir_p(@root_path)
    @config_path = File.join(@tmpdir, "config.yml")
    @bin_path = File.expand_path("../../../bin/tachi", __dir__)

    File.write(
      @config_path,
      <<~YAML
        default_context: default
        contexts:
          - name: default
            root_path: #{@root_path}
      YAML
    )
  end

  def teardown
    FileUtils.remove_entry(@tmpdir) if @tmpdir && Dir.exist?(@tmpdir)
  end

  def test_run_exits_non_zero_when_child_command_fails
    write_command(
      "apps/bm/failing/cmd.bad.sh",
      <<~SH
        #!/usr/bin/env bash
        echo OOPS 1>&2
        exit 7
      SH
    )

    stdout, stderr, status = run_tachi("run", "apps.bm.failing.bad")

    assert_equal 1, status.exitstatus
    assert_match(/Completed 0\/1\/1/, stdout)
    assert_match(/FAILED apps\.bm\.failing\.bad exit-status=7/, stdout)
    assert_match(/OOPS/, stdout + stderr)
  end

  def test_noop_marks_commands_successful_without_running_script
    write_command(
      "apps/bm/ok/cmd.pass.sh",
      <<~SH
        #!/usr/bin/env bash
        echo SHOULD_NOT_RUN
        exit 99
      SH
    )

    stdout, _stderr, status = run_tachi("--noop", "run", "apps.bm.ok.pass")

    assert_equal 0, status.exitstatus
    assert_match(/Completed 1\/0\/1/, stdout)
    refute_match(/FAILED/, stdout)
    refute_match(/SHOULD_NOT_RUN/, stdout)
  end

  def test_jobs_zero_is_rejected_during_argument_parsing
    stdout, stderr, status = run_tachi("--jobs", "0", "run", "apps.bm.ok.pass")

    assert_equal 1, status.exitstatus
    assert_match(/jobs must be a positive integer/i, "#{stdout}\n#{stderr}")
  end

  def test_non_executable_script_is_reported_as_failed_command_without_thread_crash_trace
    script_path = write_command(
      "apps/bm/failing/cmd.noexec.sh",
      <<~SH
        #!/usr/bin/env bash
        echo SHOULD_NOT_RUN
      SH
    )
    FileUtils.chmod(0o644, script_path)

    stdout, stderr, status = run_tachi("run", "apps.bm.failing.noexec")
    combined = "#{stdout}\n#{stderr}"

    assert_equal 1, status.exitstatus
    assert_match(/Completed 0\/1\/1/, stdout)
    assert_match(/FAILED apps\.bm\.failing\.noexec exit-status=126/, stdout)
    assert_match(/Permission denied/i, combined)
    refute_match(/terminated with exception/i, combined)
  end

  private

  def run_tachi(*args)
    Open3.capture3(RbConfig.ruby, @bin_path, "-c", @config_path, *args)
  end

  def write_command(relative_path, body)
    full_path = File.join(@root_path, relative_path)
    FileUtils.mkdir_p(File.dirname(full_path))
    File.write(full_path, body)
    FileUtils.chmod(0o755, full_path)
    full_path
  end
end
