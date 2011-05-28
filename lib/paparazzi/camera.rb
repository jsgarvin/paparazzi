require 'admit_one'
require 'yaml'
require 'fileutils'
require 'digest/md5'

module Paparazzi
  class Camera
    REQUIRED_SETTINGS = [:source,:destination]
      
    class << self
      attr_accessor :source, :destination, :rsync_flags, :intervals
      
      def trigger(settings = {})
        validate_and_cache_settings(settings)
        AdmitOne::LockFile.new("paparazzi-#{Digest::MD5.hexdigest(destination)}") do
          setup
          purge_old_snapshots
          make_snapshots
        end
        
      end
      
      #######
      private
      #######
      
      def validate_and_cache_settings(settings)
        [:source,:destination,:rsync_flags,:intervals,:reserves].each do |setting_name|
          if REQUIRED_SETTINGS.include?(setting_name) and settings[setting_name].nil?
            raise MissingSettingError, "#{setting_name} is required"
          else
            if setting_name == :rsync_flags
              settings[setting_name] = settings[setting_name].split(/\s/)
            end
            self.send("#{setting_name}=",settings[setting_name])
          end
        end
        
        raise MissingFolderError, source unless File.exist?(source) and File.directory?(source)
        raise MissingFolderError, destination unless File.exist?(destination) and File.directory?(destination)
      end
      
      def setup
        @previous_snapshot_name = {}
        frequencies.each do |frequency|
          Dir.mkdir(destination(frequency)) unless File.exists?(destination(frequency)) && File.directory?(destination(frequency))
        
          full_path = Dir[destination(frequency)+'/*'].sort{|a,b| File.ctime(b) <=> File.ctime(a) }.first
          @previous_snapshot_name[frequency] = full_path ? File.basename(full_path) : ''
        end
        
        if @previous_snapshot_name[frequencies.first] != last_successful_snapshot and !last_successful_snapshot.nil? and File.exists?(destination(frequencies.first) + '/' + last_successful_snapshot)
          File.rename(previous_snapshot(frequencies.first), current_snapshot(frequencies.first))
          @previous_snapshot_name[frequencies.first] = last_successful_snapshot
        end
      end
      
      def destination(frequency = nil)
        frequency.nil? ? @destination : "#{@destination}/#{frequency}"
      end
      
      def last_successful_snapshot
        @last_successful_snapshot ||= File.exists?("#{destination}/.paparazzi.yml") ? YAML.load_file("#{destination}/.paparazzi.yml")[:last_successful_snapshot] : nil
      end
      
      def last_successful_snapshot=(string)
        cached_data ||= File.exists?("#{destination}/.paparazzi.yml") ? YAML.load_file("#{destination}/.paparazzi.yml") : {}
        cached_data[:last_successful_snapshot] = string
        File.open("#{destination}/.paparazzi.yml", 'w') {|file| file.write(cached_data.to_yaml) }
      end
    
      def purge_old_snapshots
        frequencies.each do |frequency|
          while Dir[destination(frequency)+'/*'].size > (intervals[frequency]-1)
            full_path = Dir[destination(frequency)+'/*'].sort{|a,b| File.ctime(a) <=> File.ctime(b) }.first
            FileUtils.rm_rf(full_path)
          end
        end
      end

      def make_snapshots
        frequencies.each do |frequency|
          Dir.mkdir(current_snapshot(frequency)) unless File.exists?(current_snapshot(frequency))
          if frequency == frequencies.first and previous_snapshot_name(frequency) == ''
            system 'rsync', *(['-aq', '--delete'] + rsync_flags + [source, current_snapshot(frequency)])
            self.last_successful_snapshot = current_snapshot_name(frequency)
          elsif previous_snapshot_name(frequency) != current_snapshot_name(frequency)
            system 'rsync', *(['-aq', '--delete', "--link-dest=#{link_destination(frequency)}"] + rsync_flags + [source, current_snapshot(frequency)])
            self.last_successful_snapshot = current_snapshot_name(frequencies.first)
          end
        end
      end
      
      def current_snapshot(frequency)
        destination(frequency) + '/' + current_snapshot_name(frequency)
      end
      
      def current_snapshot_name(frequency)
        @start_time ||= Time.now #lock in time so that all results stay consistent over long runs
        case frequency
          when :hourly  then @start_time.strftime('%Y-%m-%d.%H')
          when :daily   then @start_time.strftime('%Y-%m-%d')
          when :weekly  then sprintf("%04d-%02d-week-%02d", @start_time.year, @start_time.month, (@start_time.day/7))
          when :monthly then @start_time.strftime("%Y-%m")
          when :yearly  then @start_time.strftime("%Y")
        end
      end
      
      def previous_snapshot(frequency)
        destination(frequency) + '/' + previous_snapshot_name(frequency)
      end
      
      def previous_snapshot_name(frequency)
        @previous_snapshot_name[frequency]
      end
      
      def link_destination(frequency)
        frequency == frequencies.first ? "../#{previous_snapshot_name(frequencies.first)}" : "../../#{frequencies.first}/#{current_snapshot_name(frequencies.first)}"
      end
      
      def intervals
        @intervals ||= {:hourly => 24, :daily => 7, :weekly => 5, :monthly => 12, :yearly => 9999}
      end
      
      def frequencies
        intervals.keys.select{ |key| intervals[key] > 0 }.sort{ |a,b| 
          [:hourly,:daily,:weekly,:monthly,:yearly].find_index(a) <=> [:hourly,:daily,:weekly,:monthly,:yearly].find_index(b)
        }  
      end
      
      # provide backwards compatability with silly setting name
      def reserves=(x)
        if x.is_a?(Hash)
          $stderr.puts ':reserves is deprecated. Please use :intervals instead.'
          self.intervals=x 
        end
      end
    end
  end
  
  class MissingSettingError < StandardError; end
  class MissingFolderError < StandardError; end
end