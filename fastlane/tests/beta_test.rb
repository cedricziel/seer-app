require "minitest/autorun"

module FastlaneCore
  class DeviceManager
    def self.simulators(*)
      []
    end
  end
end
$LOADED_FEATURES << "fastlane_core/device_manager.rb"

class LaneRunner
  attr_reader :calls

  def initialize
    @lanes = {}
    @calls = []
    instance_eval(File.read(File.expand_path("../Fastfile", __dir__)), "Fastfile")
    define_singleton_method(:load_app_store_connect_api_key) { { key_id: "test-key" } }
  end

  def lane(name, &block)
    @lanes[name] = block
  end
  alias private_lane lane

  def run(name, options = {})
    instance_exec(options, &@lanes.fetch(name))
  end

  def is_ci
    true
  end

  def sh(*)
    "123"
  end

  def method_missing(name, *args, **kwargs, &block)
    return if [:default_platform, :desc, :before_all, :error, :opt_out_usage].include?(name)
    @calls << [name, kwargs]
    name == :build_app ? "/tmp/test-build" : nil
  end

  def respond_to_missing?(*); true; end
end

class BetaTest < Minitest::Test
  def setup
    @runner = LaneRunner.new
  end

  def test_existing_beta_command_still_uploads_ios
    @runner.run(:beta, allow_dirty: true)
    assert_equal "generic/platform=iOS", action(:build_app).fetch(:destination)
    assert_equal "ios", action(:upload_to_testflight).fetch(:app_platform)
  end

  def test_tv_beta_uses_tv_signing_and_uploads_its_own_archive
    @runner.run(:beta, target: "tvos", allow_dirty: true)
    assert_equal "generic/platform=tvOS", action(:build_app).fetch(:destination)
    assert_equal ["tvos", "tvos"], signing.map { |args| args.fetch(:platform) }
    assert_equal true, signing.first.fetch(:skip_provisioning_profiles)
    assert_equal "appletvos", action(:upload_to_testflight).fetch(:app_platform)
    assert_equal "/tmp/test-build", action(:upload_to_testflight).fetch(:ipa)
  end

  def test_mac_beta_exports_and_uploads_a_signed_installer
    @runner.run(:beta, target: "macos", allow_dirty: true)
    assert_equal "generic/platform=macOS", action(:build_app).fetch(:destination)
    assert_equal "SeerApp.pkg", action(:build_app).fetch(:output_name)
    assert_equal "macosx", action(:build_app).fetch(:sdk)
    assert_equal "Mac Installer Distribution", action(:build_app).fetch(:export_options).fetch(:installerSigningCertificate)
    assert_equal ["macos", "macos"], signing.map { |args| args.fetch(:platform) }
    assert_equal ["mac_installer_distribution"], signing.last.fetch(:additional_cert_types)
    assert_equal "osx", action(:upload_to_testflight).fetch(:app_platform)
    assert_equal "/tmp/test-build", action(:upload_to_testflight).fetch(:pkg)
    refute action(:upload_to_testflight).key?(:ipa)
  end

  def test_beta_validates_archive_libraries_before_upload
    @runner.run(:beta, target: "macos", allow_dirty: true)
    validation = @runner.calls.index { |name, _| name == :validate_archive_libraries }
    upload = @runner.calls.index { |name, _| name == :upload_to_testflight }
    refute_nil validation
    assert_operator validation, :<, upload
    assert_equal "build/macos/SeerApp.xcarchive", action(:validate_archive_libraries).fetch(:archive)
  end

  def test_archive_validation_resolves_paths_from_repository_root
    command = nil
    @runner.define_singleton_method(:sh) { |*args| command = args }
    Dir.chdir(File.expand_path("..", __dir__)) do
      @runner.run(:validate_archive_libraries, archive: "build/ios/SeerApp.xcarchive")
    end
    assert_equal File.expand_path("../../build/ios/SeerApp.xcarchive", __dir__), command.last
  end

  def test_invalid_archive_stops_testflight_upload
    @runner.define_singleton_method(:validate_archive_libraries) { |**| raise "Library missing" }
    assert_raises(RuntimeError) { @runner.run(:beta, allow_dirty: true) }
    refute @runner.calls.any? { |name, _| name == :upload_to_testflight }
  end

  def test_invalid_archive_stops_app_store_upload
    @runner.define_singleton_method(:validate_archive_libraries) { |**| raise "Library missing" }
    assert_raises(RuntimeError) { @runner.run(:release, allow_dirty: true) }
    refute @runner.calls.any? { |name, _| name == :upload_to_app_store }
  end

  def test_unknown_target_fails_before_signing_or_building
    assert_raises(ArgumentError) { @runner.run(:beta, target: "watchos") }
    assert_empty signing
    refute @runner.calls.any? { |name, _| name == :build_app }
  end

  def test_ci_signing_remains_read_only
    @runner.run(:beta, target: "macos", allow_dirty: true)
    assert_equal [true, true], signing.map { |args| args.fetch(:readonly) }
  end

  def test_mac_bootstrap_creates_the_profiles_and_installer_certificate
    @runner.run(:bootstrap_signing, target: "macos")
    assert_equal [false, false], signing.map { |args| args.fetch(:readonly) }
    assert_equal ["development", "appstore"], signing.map { |args| args.fetch(:type) }
    assert_equal ["mac_installer_distribution"], signing.last.fetch(:additional_cert_types)
  end

  def test_existing_mac_build_is_submitted_without_rebuilding
    @runner.run(:submit_to_app_store, target: "macos", build: "123", version: "0.8.0")
    assert_equal "osx", action(:upload_to_app_store).fetch(:platform)
    assert_equal "123", action(:upload_to_app_store).fetch(:build_number)
    assert_equal "0.8.0", action(:upload_to_app_store).fetch(:app_version)
    assert_equal true, action(:upload_to_app_store).fetch(:skip_binary_upload)
    refute @runner.calls.any? { |name, _| name == :build_app }
  end

  def test_existing_tv_build_is_submitted_to_the_tv_platform
    @runner.run(:submit_to_app_store, target: "tvos", build: "123")
    assert_equal "appletvos", action(:upload_to_app_store).fetch(:platform)
  end

  private

  def action(name)
    @runner.calls.find { |called, _| called == name }.last
  end

  def signing
    @runner.calls.select { |name, _| name == :sync_code_signing }.map(&:last)
  end
end
