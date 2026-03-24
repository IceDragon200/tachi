require_relative "test_helper"

class ApplicationCommandScanningTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir("tachi-command-tests")
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

  def test_root_level_command_is_named_without_leading_dots
    write_command("cmd.upgrade.sh")

    commands = @app.scan_for_commands
    names = commands.map { |row| row[:command] }

    assert_includes names, "upgrade"
  end

  def test_find_commands_supports_wildcards_and_selectors
    write_command("apps/bm/alpha/app1/cmd.upgrade.sh")
    write_command("apps/bm/alpha/app2/cmd.upgrade.sh")
    write_command("apps/bm/bravo/app1/db/cmd.migrate.sh")
    write_command("apps/bm/bravo/app3/cmd.upgrade.sh")
    write_command("apps/other/alpha/app1/cmd.upgrade.sh")

    @app.instance_variable_set(:@commands, @app.scan_for_commands)
    matches = @app.find_commands("apps.bm.*.{app1,app2}.*")
    names = matches.map { |row| row[:command] }.sort

    assert_equal(
      [
        "apps.bm.alpha.app1.upgrade",
        "apps.bm.alpha.app2.upgrade",
        "apps.bm.bravo.app1.db.migrate",
      ],
      names
    )
  end

  def test_scan_supports_extensionless_commands
    write_command("apps/demo/cmd.plain")

    commands = @app.scan_for_commands
    names = commands.map { |row| row[:command] }

    assert_includes names, "apps.demo.plain"
  end

  private

  def write_command(relative_path)
    full_path = File.join(@root_path, relative_path)
    FileUtils.mkdir_p(File.dirname(full_path))
    File.write(full_path, "#!/usr/bin/env bash\necho ok\n")
  end
end
