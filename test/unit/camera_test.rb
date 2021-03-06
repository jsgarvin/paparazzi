require File.expand_path('../../../lib/paparazzi',  __FILE__)
require 'test/unit'
require 'fileutils'

class CameraTest < Test::Unit::TestCase
  FREQUENCIES = [:hourly,:daily,:weekly,:monthly,:yearly]

  def setup
    FREQUENCIES.each do |frequency|
      FileUtils.rm_rf("#{destination}/#{frequency}")
    end
    FileUtils.rm_rf("#{destination}/.paparazzi.yml")
  end

  def test_should_raise_exception_on_missing_required_settings
    assert_raise(Paparazzi::MissingSettingError) { Paparazzi::Camera.trigger({}) }
  end

  def test_should_store_valid_settings_in_attr_accessors
    Paparazzi::Camera.trigger(default_test_settings)
    [:source,:destination].each do |setting_name|
      assert_equal(default_test_settings[setting_name],Paparazzi::Camera.send(setting_name),setting_name)
    end
  end

  def test_should_raise_exception_on_missing_source_or_destination_folder
    my_test_settings = default_test_settings.merge(:source => File.expand_path('../../missing_folder',  __FILE__))
    assert_raise(Paparazzi::MissingFolderError) { Paparazzi::Camera.trigger(my_test_settings) }

    my_test_settings = default_test_settings.merge(:destination => File.expand_path('../../missing_folder',  __FILE__))
    assert_raise(Paparazzi::MissingFolderError) { Paparazzi::Camera.trigger(my_test_settings) }
  end

  def test_should_create_frequency_folders_on_initialization
    FREQUENCIES.each do |frequency|
      assert(!File.exists?("#{destination}/#{frequency}"))
    end
    Paparazzi::Camera.trigger(default_test_settings)
    FREQUENCIES.each do |frequency|
      assert(File.exists?("#{destination}/#{frequency}"))
    end
  end

  def test_should_make_all_first_snapshots_of_source
    Paparazzi::Camera.trigger(default_test_settings)
    FREQUENCIES.each do |frequency|
      assert(Dir["#{destination}/#{frequency}/*"].size > 0,"#{destination}/#{frequency}/ is empty")
      file = File.open(%Q{#{Dir["#{destination}/#{frequency}/*"].first}/test.txt})
      assert_equal('This is a test, this is only a test.',file.gets)
    end
  end

  def test_should_write_last_successful_snapshot_to_cached_values_file
    Paparazzi::Camera.trigger(default_test_settings)
    assert(YAML.load_file("#{destination}/.paparazzi.yml")[:last_successful_snapshot].match(/\d{4}-\d{2}-\d{2}\.\d{2}/))
  end

  def test_should_purge_out_expired_snapshots
    Dir.mkdir("#{destination}/weekly")
    Dir.mkdir("#{destination}/weekly/1")
    sleep 1;
    (2..5).each do |x|
      Dir.mkdir("#{destination}/weekly/#{x}")
    end
    assert_equal(5,Dir["#{destination}/weekly/*"].size)
    previous_folder_contents = Dir["#{destination}/weekly/*"]
    Paparazzi::Camera.trigger(default_test_settings)
    assert_equal(5,Dir["#{destination}/weekly/*"].size)
    assert(!File.exists?("#{destination}/weekly/1"))
    assert_not_equal(previous_folder_contents,Dir["#{destination}/weekly/*"])
  end

  def test_should_gracefully_recover_if_last_hourly_snapshot_ended_prematurely
    Paparazzi::Camera.instance_variable_set('@start_time',Time.now - 7200)
    Paparazzi::Camera.trigger(default_test_settings)
    successful_snapshot_name = Paparazzi::Camera.send(:current_snapshot_name,:hourly)

    #slow test down to compensate for OSs (eg. Mac) that don't track ctime to nsec precision
    sleep 1 unless File.ctime(Paparazzi::Camera.send(:destination,:hourly)).nsec > 0

    Paparazzi::Camera.instance_variable_set('@start_time',Time.now - 3600)
    Paparazzi::Camera.trigger(default_test_settings)
    failed_snapshot_name = Paparazzi::Camera.send(:current_snapshot_name,:hourly)

    #slow test down to compensate for OSs (eg. Mac) that don't track ctime to nsec precision
    sleep 1 unless File.ctime(Paparazzi::Camera.send(:destination,:hourly)).nsec > 0

    Paparazzi::Camera.send(:last_successful_snapshot=,successful_snapshot_name)
    assert_equal(2,Dir["#{destination}/hourly/*"].size)
    assert_equal(successful_snapshot_name,YAML.load_file("#{destination}/.paparazzi.yml")[:last_successful_snapshot])

    Paparazzi::Camera.instance_variable_set('@start_time',Time.now)
    Paparazzi::Camera.trigger(default_test_settings)

    assert_equal(2,Dir["#{destination}/hourly/*"].size)
    assert(Dir["#{destination}/hourly/*"].include?("#{destination}/hourly/#{successful_snapshot_name}"))
    assert(!Dir["#{destination}/hourly/*"].include?("#{destination}/hourly/#{failed_snapshot_name}"))
  end

  def test_should_create_hard_links_to_multiple_snapshots_of_same_file
    Paparazzi::Camera.trigger(default_test_settings)
    inode = File.stat("#{destination}/hourly/#{Paparazzi::Camera.send(:current_snapshot_name,:hourly)}/test.txt").ino
    FREQUENCIES.each do |frequency|
      assert_equal(5,File.stat("#{destination}/#{frequency}/#{Paparazzi::Camera.send(:current_snapshot_name,frequency)}/test.txt").nlink)
      assert_equal(inode,File.stat("#{destination}/#{frequency}/#{Paparazzi::Camera.send(:current_snapshot_name,frequency)}/test.txt").ino)
    end
  end

  def test_should_not_backup_excluded_files
    Paparazzi::Camera.trigger(default_test_settings)
    assert(!File.exists?("#{destination}/hourly/#{Paparazzi::Camera.send(:current_snapshot_name,:hourly)}/test.exclude"))
  end

  def test_should_not_make_un_requested_frequency_snapshots
    my_settings = default_test_settings
    my_settings[:intervals][:hourly] = 0
    Paparazzi::Camera.trigger(my_settings)
    assert(!File.exists?("#{destination}/hourly"))
  end

  def test_should_be_backwards_compatible_with_deprecated_config_option
    original_stderr, $stderr = $stderr, StringIO.new
    my_settings = default_test_settings
    my_settings[:reserves] = my_settings[:intervals]
    my_settings[:reserves][:hourly] = 1
    my_settings.delete(:intervals)
    Paparazzi::Camera.trigger(my_settings)
    assert_equal(my_settings[:reserves],Paparazzi::Camera.instance_variable_get('@intervals'))
    assert_equal(':reserves is deprecated. Please use :intervals instead.',$stderr.string.chomp)
  ensure
    $stderr = original_stderr
  end

  #######
  private
  #######

  def destination
    @destination ||= File.expand_path('../../destination',  __FILE__)
  end

  def default_test_settings
    {
      :source => "#{File.expand_path('../../source',  __FILE__)}/",
      :destination => destination,
      :intervals => {:hourly => 24, :daily => 7, :weekly => 5, :monthly => 12, :yearly => 9999},
      :rsync_flags => '-L --exclude test.exclude'

    }
  end
end