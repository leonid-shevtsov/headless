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
  MAX_DISPLAY_NUMBER = 10_000
  DEFAULT_DISPLAY_DIMENSIONS = '1280x1024x24'
  DEFAULT_XVFB_LAUNCH_TIMEOUT = 10

  class Exception < RuntimeError
  end

  # The display number
  attr_reader :display

  # The display dimensions
  attr_reader :dimensions
  attr_reader :xvfb_launch_timeout

  # Creates a new headless server, but does NOT switch to it immediately.
  # Call #start for that
  #
  # List of available options:
  # * +display+ (default 99) - what display number to listen to;
  # * +reuse+ (default true) - if given display server already exists,
  #   should we use it or try another?
  # * +autopick+ (default true is display number isn't explicitly set) - if
  #   Headless should automatically pick a display, or fail if the given one is
  #   not available.
  # * +dimensions+ (default 1280x1024x24) - display dimensions and depth. Not
  #   all combinations are possible, refer to +man Xvfb+.
  # * +destroy_at_exit+ (default true) - if a display is started but not
  #   stopped, should it be destroyed when the script finishes?
  # * +xvfb_launch_timeout+ - how long should we wait for Xvfb to open a
  #   display, before assuming that it is frozen (in seconds, default is 10)
  # * +video+ - options to be passed to the ffmpeg video recorder
  def initialize(options = {})
    CliUtil.ensure_application_exists!('Xvfb', 'Xvfb not found on your system')

    @display = options.fetch(:display, DEFAULT_DISPLAY_NUMBER).to_i
    @xvfb_launch_timeout = options.fetch(:xvfb_launch_timeout, DEFAULT_XVFB_LAUNCH_TIMEOUT).to_i
    @autopick_display = options.fetch(:autopick, !options.key?(:display))
    @reuse_display = options.fetch(:reuse, true)
    @dimensions = options.fetch(:dimensions, DEFAULT_DISPLAY_DIMENSIONS)
    @video_capture_options = options.fetch(:video, {})
    @destroy_at_exit = options.fetch(:destroy_at_exit, true)

    # FIXME Xvfb launch should not happen inside the constructor
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
    CliUtil.kill_process(pid_filename, preserve_pid_file: true)
  end

  # Same as destroy, but waits for Xvfb process to terminate
  def destroy_sync
    stop
    CliUtil.kill_process(pid_filename, preserve_pid_file: true, wait: true)
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
    headless && headless.destroy
  end
  class <<self; alias_method :ly, :run; end

  def video
    @video_recorder ||= VideoRecorder.new(display, dimensions, @video_capture_options)
  end

  def take_screenshot(file_path, options={})
    using = options.fetch(:using, :imagemagick)
    if using == :imagemagick
      CliUtil.ensure_application_exists!('import', "imagemagick is not found on your system. Please install it using sudo apt-get install imagemagick")
      system "#{CliUtil.path_to('import')} -display localhost:#{display} -window root #{file_path}"
    elsif using == :xwd
      CliUtil.ensure_application_exists!('xwd', "xwd is not found on your system. Please install it using sudo apt-get install X11-apps")
      system "#{CliUtil.path_to('xwd')} -display localhost:#{display} -silent -root -out #{file_path}"
    else
      raise Headless::Exception.new('Unknown :using option value')
    end
  end

private

  def attach_xvfb
    possible_display_set = @autopick_display ? @display..MAX_DISPLAY_NUMBER : Array(@display)
    pick_available_display(possible_display_set, @reuse_display)
  end

  def pick_available_display(display_set, can_reuse)
    display_set.each do |display_number|
      @display = display_number
      begin
        return true if xvfb_running? && can_reuse
        return true if !xvfb_running? && launch_xvfb
      rescue Errno::EPERM # display not accessible
        next
      end
    end
    raise Headless::Exception.new("Could not find an available display")
  end

  def launch_xvfb
    out_pipe, in_pipe = IO.pipe
    pid = Process.spawn(
      CliUtil.path_to("Xvfb"), ":#{display}", "-screen", "0", dimensions, "-ac",
      err: in_pipe)
    in_pipe.close
    raise Headless::Exception.new("Xvfb did not launch - something's wrong") unless pid
    ensure_xvfb_is_running(out_pipe)
    return true
  end

  def ensure_xvfb_is_running(out_pipe)
    start_time = Time.now
    errors = ""
    begin
      begin
        errors += out_pipe.read_nonblock(10000)
        if errors.include? "Cannot establish any listening sockets"
          raise Headless::Exception.new("Display socket is taken but lock file is missing - check the Headless troubleshooting guide")
        end
      rescue IO::WaitReadable
        # will retry next cycle
      end
      sleep 0.01 # to avoid cpu hogging
      raise Headless::Exception.new("Xvfb launched but did not complete initialization") if (Time.now-start_time)>=@xvfb_launch_timeout
    end while !xvfb_running?
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
