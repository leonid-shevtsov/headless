require 'headless/cli_util'
require 'headless/video/video_recorder'

# A class incapsulating the creation and usage of a headless X server
#
# == Prerequisites
#
# * X Window System
# * Xvfb[http://en.wikipedia.org/wiki/Xvfb]
#
# == Usage
#
# Block mode:
#
#   require 'rubygems'
#   require 'headless'
#   require 'selenium-webdriver'
# 
#   Headless.ly do
#     driver = Selenium::WebDriver.for :firefox
#     driver.navigate.to 'http://google.com'
#     puts driver.title 
#   end
#
# Object mode:
#
#   require 'rubygems'
#   require 'headless'
#   require 'selenium-webdriver'
#
#   headless = Headless.new
#   headless.start
#
#   driver = Selenium::WebDriver.for :firefox
#   driver.navigate.to 'http://google.com'
#   puts driver.title 
#
#   headless.destroy
#--
# TODO test that reuse actually works with an existing xvfb session
#++
class Headless

  DEFAULT_DISPLAY_NUMBER = 99
  DEFAULT_DISPLAY_DIMENSIONS = '1280x1024x24'

  class Exception < RuntimeError
  end

  # The display number
  attr_reader :display

  # The display dimensions
  attr_reader :dimensions

  # Creates a new headless server, but does NOT switch to it immediately. Call #start for that
  #
  # List of available options:
  # * +display+ (default 99) - what display number to listen to;
  # * +reuse+ (default true) - if given display server already exists, should we use it or try another?
  # * +autopick+ (default true is display number isn't explicitly set) - if Headless should automatically pick a display, or fail if the given one is not available.
  # * +dimensions+ (default 1280x1024x24) - display dimensions and depth. Not all combinations are possible, refer to +man Xvfb+.
  # * +destroy_at_exit+ (default true) - if a display is started but not stopped, should it be destroyed when the script finishes?
  def initialize(options = {})
    CliUtil.ensure_application_exists!('Xvfb', 'Xvfb not found on your system')

    @display = options.fetch(:display, DEFAULT_DISPLAY_NUMBER).to_i
    @autopick_display = options.fetch(:autopick, !options.key?(:display))
    @reuse_display = options.fetch(:reuse, true)
    @dimensions = options.fetch(:dimensions, DEFAULT_DISPLAY_DIMENSIONS)
    @video_capture_options = options.fetch(:video, {})
    @destroy_at_exit = options.fetch(:destroy_at_exit, true)

    attach_xvfb
  end

  # Switches to the headless server
  def start
    @old_display = ENV['DISPLAY']
    ENV['DISPLAY'] = ":#{display}"
    hook_at_exit
  end

  # Switches back from the headless server
  def stop
    ENV['DISPLAY'] = @old_display
  end

  # Switches back from the headless server and terminates the headless session
  def destroy
    stop
    CliUtil.kill_process(pid_filename)
  end

  # Block syntax:
  #
  #   Headless.run do
  #     # perform operations in headless mode
  #   end
  # See #new for options
  def self.run(options={}, &block)
    headless = Headless.new(options)
    headless.start
    yield headless
  ensure
    headless.destroy
  end
  class <<self; alias_method :ly, :run; end

  def video
    @video_recorder ||= VideoRecorder.new(display, dimensions, @video_capture_options)
  end

  def take_screenshot(file_path)
    CliUtil.ensure_application_exists!('import', "imagemagick not found on your system. Please install it using sudo apt-get install imagemagick")

    system "#{CliUtil.path_to('import')} -display localhost:#{display} -window root #{file_path}"
  end

private

  def attach_xvfb
    # TODO this loop isn't elegant enough
    success = false
    while !success && @display<10000
      begin
        if !xvfb_running?
          launch_xvfb
          success=true
        else
          success = @reuse_display
        end
      rescue Errno::EPERM
        # No permission to read pid file
        success = false
      end

      # TODO this is crufty
      if @autopick_display
        @display += 1 unless success
      else
        break
      end
    end

    unless success
      raise Headless::Exception.new("Display :#{display} is already taken and reuse=false")
    end
  end

  def launch_xvfb
    #TODO error reporting
    result = system "#{CliUtil.path_to("Xvfb")} :#{display} -screen 0 #{dimensions} -ac >/dev/null 2>&1 &"
    raise Headless::Exception.new("Xvfb did not launch - something's wrong") unless result
  end

  def xvfb_running?
    !!read_xvfb_pid
  end

  def pid_filename
    "/tmp/.X#{display}-lock"
  end

  def read_xvfb_pid
    CliUtil.read_pid(pid_filename)
  end
    
  def hook_at_exit
    unless @at_exit_hook_installed
      @at_exit_hook_installed = true
      at_exit do
        exit_status = $!.status if $!.is_a?(SystemExit)
        destroy if @destroy_at_exit
        exit exit_status if exit_status
      end
    end
  end
end
