require File.expand_path('../../../lib/paparazzi',  __FILE__)
require 'test/unit'

class CameraTest < Test::Unit::TestCase
  
  def test_should_raise_exception_on_missing_required_settings
    assert_raise(Paparazzi::MissingSettingError) { Paparazzi::Camera.trigger({}) }
  end
  
  def test_should_store_valid_settings_in_attr_accessors
    test_settings = {
      :source => File.expand_path('../../source',  __FILE__),
      :destination => File.expand_path('../../destination',  __FILE__),
      :rsync_flags => '-L'
    }
    Paparazzi::Camera.trigger(test_settings)
    [:source,:destination,:rsync_flags].each do |setting_name|
      assert_equal(test_settings[setting_name],Paparazzi::Camera.send(setting_name),setting_name)
    end
  end
  
  def test_should_raise_exception_on_missing_source_or_destination_folder
    test_settings = {
      :source => File.expand_path('../../missing_source',  __FILE__),
      :destination => File.expand_path('../../destination',  __FILE__),
      :rsync_flags => '-L'
    }
    assert_raise(Paparazzi::MissingFolderError) { Paparazzi::Camera.trigger(test_settings) }
    
    test_settings = {
      :source => File.expand_path('../../source',  __FILE__),
      :destination => File.expand_path('../../missing_destination',  __FILE__),
      :rsync_flags => '-L'
    }
    assert_raise(Paparazzi::MissingFolderError) { Paparazzi::Camera.trigger(test_settings) }
  end
  
end