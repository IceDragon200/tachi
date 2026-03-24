require "minitest/autorun"
require "tmpdir"
require "fileutils"

$LOAD_PATH.unshift(File.expand_path("../../lib", __dir__))

require "tachi/application"
require "tachi/config"
