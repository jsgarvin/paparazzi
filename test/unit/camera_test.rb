require File.expand_path('../../../lib/paparazzi',  __FILE__)
require 'test/unit'

class CameraTest < Test::Unit::TestCase
  
  def test_trigger_camera
    assert Paparazzi::Camera.trigger
  end
  
end