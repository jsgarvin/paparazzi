require 'admit_one'
require 'yaml'

module Paparazzi
  class Camera
    class << self
      FREQUENCIES = [:hourly,:daily,:weekly,:monthly,:yearly]
      REQUIRED_SETTINGS = [:source,:destination]
      attr_accessor :source, :destination, :rsync_flags
      
      def trigger(settings = {})
        validate_and_cache_settings(settings)
        AdmitOne::LockFile.new(:paparazzi) do
          initialize
        end
        
      end
      
      #######
      private
      #######
      
      def validate_and_cache_settings(settings)
        [:source,:destination,:rsync_flags].each do |setting_name|
          if REQUIRED_SETTINGS.include?(setting_name) and settings[setting_name].nil?
            raise MissingSettingError, "#{setting_name} is required"
          else
            self.send("#{setting_name}=",settings[setting_name])
          end
        end
        
        raise MissingFolderError, source unless File.exist?(source) and File.directory?(source)
        raise MissingFolderError, destination unless File.exist?(destination) and File.directory?(destination)
      end
      
      def initialize
        @previous_target_name = {}
        FREQUENCIES.each do |frequency|
          Dir.mkdir(destination(frequency)) unless File.exists?(destination(frequency)) && File.directory?(destination(frequency))
        
          full_path = Dir[destination(frequency)+'/*'].sort{|a,b| File.ctime(b) <=> File.ctime(a) }.first
          @previous_target_name[frequency] = full_path ? File.basename(full_path) : ''
        end
        
        if @previous_target_name[:hourly] != last_successful_hourly_target and !last_successful_hourly_target.nil? and File.exists?(destination(:hourly) + '/' + last_successful_hourly_target)
          File.rename(previous_target(:hourly), current_target(:hourly))
          @previous_target_name[:hourly] = last_successful_hourly_target
        end
      end
      
      def destination(frequency = nil)
        frequency.nil? ? @destination : "#{@destination}/#{frequency}"
      end
      
      def last_successful_hourly_target
        @last_successful_hourly_target ||= File.exists?("#{destination}/.paparazzi.yml") ? YAML.load_file("#{destination}/.paparazzi.yml")[:last_successful_snapshot] : nil
      end
    end
  end
  
  class MissingSettingError < StandardError; end
  class MissingFolderError < StandardError; end
end