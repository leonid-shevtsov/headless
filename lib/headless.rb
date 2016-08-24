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
  # * +autopick+ (default true if display number isn't explicitly set) - if
  #   Headless should automatically pick a display, or fail if the given one is
  #   not available.
  # * +dimensions+ (default 1280x1024x24) - display dimensions and depth. Not
  #   all combinations are possible, refer to +man Xvfb+.
  # * +destroy_at_exit+  - if a display is started but not stopped, should it
  #   be destroyed when the script finishes?
  #   (default true unless reuse is true and a server is already running)
  # * +xvfb_launch_timeout+ - how long should we wait for Xvfb to open a
  #   display, before assuming that it is frozen (in seconds, default is 10)
  # * +video+ - options to be passed to the ffmpeg video recorder. See Headless::VideoRecorder#initialize for documentation
  def initialize(options = {})
    CliUtil.ensure_application_exists!('Xvfb', 'Xvfb not found on your system')

    @display = options.fetch(:display, DEFAULT_DISPLAY_NUMBER).to_i
    @xvfb_launch_timeout = options.fetch(:xvfb_launch_timeout, DEFAULT_XVFB_LAUNCH_TIMEOUT).to_i
    @autopick_display = options.fetch(:autopick, !options.key?(:display))
    @reuse_display = options.fetch(:reuse, true)
    @dimensions = options.fetch(:dimensions, DEFAULT_DISPLAY_DIMENSIONS)
    @video_capture_options = options.fetch(:video, {})

    already_running = xvfb_running? rescue false
    @destroy_at_exit = options.fetch(:destroy_at_exit, !(@reuse_display && already_running))

    @pid = nil # the pid of the running Xvfb process

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
  # while waiting for Xvfb process to terminate.
  def destroy
    stop
    CliUtil.kill_process(pid_filename, preserve_pid_file: true, wait: true)
  end

  # Deprecated.
  # Same as destroy.
  # Kept for backward compatibility in June 2015.
  def destroy_sync
    destroy
  end

  # Same as the old destroy function -- doesn't wait for Xvfb to die.
  # Can cause zombies: http://stackoverflow.com/a/31003621/1651458
  def destroy_without_sync
    stop
    CliUtil.kill_process(pid_filename, preserve_pid_file: true)
  end

  # Whether the headless display will be destroyed when the script finishes.
  def destroy_at_exit?
    @destroy_at_exit
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
    case using
    when :imagemagick
      CliUtil.ensure_application_exists!('import', "imagemagick is not found on your system. Please install it using sudo apt-get install imagemagick")
      system "#{CliUtil.path_to('import')} -display localhost:#{display} -window root #{file_path}"
    when :xwd
      CliUtil.ensure_application_exists!('xwd', "xwd is not found on your system. Please install it using sudo apt-get install X11-apps")
      system "#{CliUtil.path_to('xwd')} -display localhost:#{display} -silent -root -out #{file_path}"
    when :graphicsmagick, :gm
      CliUtil.ensure_application_exists!('gm', "graphicsmagick is not found on your system. Please install it.")
      system "#{CliUtil.path_to('gm')} import -display localhost:#{display} -window root #{file_path}"
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

      return true if xvfb_running? && can_reuse && (xvfb_mine? || !@autopick_display)
      return true if !xvfb_running? && launch_xvfb
    end
    raise Headless::Exception.new("Could not find an available display")
  end

  def launch_xvfb
    out_pipe, in_pipe = IO.pipe
    @pid = Process.spawn(
      CliUtil.path_to("Xvfb"), ":#{display}", "-screen", "0", dimensions, "-ac",
      err: in_pipe)
    raise Headless::Exception.new("Xvfb did not launch - something's wrong") unless @pid
    # According to docs, you should either wait or detach on spawned procs:
    Process.detach @pid
    return ensure_xvfb_launched(out_pipe)
    ensure
      in_pipe.close
  end

  def ensure_xvfb_launched(out_pipe)
    start_time = Time.now
    errors = ""
    begin
      begin
        errors += out_pipe.read_nonblock(10000)
        if errors.include? "Cannot establish any listening sockets"
          raise Headless::Exception.new("Display socket is taken but lock file is missing - check the Headless troubleshooting guide")
        end
        if errors.include? "Server is already active for display #{display}"
          # This can happen if there is a race to grab the lock file.
          # Not an exception, just return false to let pick_available_display choose another:
          return false
        end
      rescue IO::WaitReadable
        # will retry next cycle
      end
      sleep 0.01 # to avoid cpu hogging
      raise Headless::Exception.new("Xvfb launched but did not complete initialization") if (Time.now-start_time)>=@xvfb_launch_timeout
    # Continue looping until Xvfb has written its pidfile:
    end while !xvfb_running?

    # If for any reason the pid file doesn't match ours, we lost the race to
    # get the file lock:
    return @pid == read_xvfb_pid
  end

  def xvfb_mine?
    CliUtil.process_mine?(read_xvfb_pid)
  end

  # Check whether an Xvfb process is running on @display.
  # NOTE: This might be a process started by someone else!
  def xvfb_running?
    (pid = read_xvfb_pid) && CliUtil.process_running?(pid)
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
        destroy if destroy_at_exit?
        exit exit_status if exit_status
      end
    end
  end
end
