require File.expand_path('../../../lib/paparazzi',  __FILE__)
require 'test/unit'
require 'fileutils'

class CameraTest < Test::Unit::TestCase
  
  def setup
    Paparazzi::Camera::FREQUENCIES.each do |frequency|
      FileUtils.rm_rf("#{destination}/#{frequency}")
    end
    FileUtils.rm_rf("#{destination}/.paparazzi.yml")
  end
  
  def test_should_raise_exception_on_missing_required_settings
    assert_raise(Paparazzi::MissingSettingError) { Paparazzi::Camera.trigger({}) }
  end
  
  def test_should_store_valid_settings_in_attr_accessors
    Paparazzi::Camera.trigger(default_test_settings)
    [:source,:destination,:rsync_flags].each do |setting_name|
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
    Paparazzi::Camera::FREQUENCIES.each do |frequency|
      assert(!File.exists?("#{destination}/#{frequency}"))
    end
    Paparazzi::Camera.trigger(default_test_settings)
    Paparazzi::Camera::FREQUENCIES.each do |frequency|
      assert(File.exists?("#{destination}/#{frequency}"))
    end
  end
  
  def test_should_make_all_first_snapshots_of_source
    Paparazzi::Camera.trigger(default_test_settings)
    Paparazzi::Camera::FREQUENCIES.each do |frequency|
      assert(Dir["#{destination}/#{frequency}/*"].size > 0,"#{destination}/#{frequency}/ is empty")
      file = File.open(%Q{#{Dir["#{destination}/#{frequency}/*"].first}/test.txt})
      assert_equal('This is a test, this is only a test.',file.gets)
    end
  end
  
  def test_should_write_last_successful_snapshot_to_cached_values_file
    Paparazzi::Camera.trigger(default_test_settings)
    assert(YAML.load_file("#{destination}/.paparazzi.yml")[:last_successful_snapshot].match(/\d{4}-\d{2}-\d{2}\.\d{2}/))
  end
  
  def test_purges_out_expired_snapshots
    Dir.mkdir("#{destination}/weekly")
    (1..5).each do |x|
      Dir.mkdir("#{destination}/weekly/#{x}")
      sleep 1;
    end
    assert_equal(5,Dir["#{destination}/weekly/*"].size)
    previous_folder_contents = Dir["#{destination}/weekly/*"]
    Paparazzi::Camera.trigger(default_test_settings)
    assert_equal(5,Dir["#{destination}/weekly/*"].size)
    assert_not_equal(previous_folder_contents,Dir["#{destination}/weekly/*"])
  end
  
  #######
  private
  #######
  
  def destination
    @destination ||= File.expand_path('../../destination',  __FILE__)
  end
  
  def default_test_settings
    @default_test_settings ||= {
      :source => "#{File.expand_path('../../source',  __FILE__)}/",
      :destination => File.expand_path('../../destination',  __FILE__),
      :rsync_flags => '-L'
    }
  end
end