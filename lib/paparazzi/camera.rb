require 'admit_one'

module Paparazzi
  class Camera
    class << self
      def trigger
        return true
      end
    end
  end
end