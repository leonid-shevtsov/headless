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

  class Exception < ::Exception
  end

  # The display number
  attr_reader :display

  # The display dimensions
  attr_reader :dimensions

  # Creates a new headless server, but does NOT switch to it immediately. Call #start for that
  #
  # List of available options:
  # * +display+ (default 99) - what display number to listen to;
  # * +reuse+ (default true) - if given display server already exists, should we use it or fail miserably?
  # * +dimensions+ (default 1280x1024x24) - display dimensions and depth. Not all combinations are possible, refer to +man Xvfb+.
  def initialize(options = {})
    find_xvfb

    @display = options.fetch(:display, 99).to_i
    @reuse_display = options.fetch(:reuse, true)
    @dimensions = options.fetch(:dimensions, '1280x1024x24')
    @destroy_at_exit = options.fetch(:destroy_at_exit, true)

    #TODO more logic here, autopicking the display number
    if @reuse_display
      launch_xvfb unless read_pid
    elsif read_pid
      raise Exception.new("Display :#{display} is already taken and reuse=false")
    else
      launch_xvfb
    end

    raise Exception.new("Xvfb did not launch - something's wrong") unless read_pid
  end

  # Switches to the headless server
  def start
    @old_display = ENV['DISPLAY']
    ENV['DISPLAY'] = ":#{display}"
  end

  # Switches back from the headless server
  def stop
    ENV['DISPLAY'] = @old_display
  end

  # Switches back from the headless server and terminates the headless session
  def kill_xvfb
    Process.kill('TERM', xvfb_pid) if read_pid
  end

  def destroy
    stop
    kill_xvfb if @destroy_at_exit
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
    headless.destroy
  end

  class <<self; alias_method :ly, :run; end

private
  attr_reader :xvfb_pid

  def find_xvfb
    @xvfb = `which Xvfb`.strip
    raise Exception.new('Xvfb not found on your system') if @xvfb == ''
  end

  def launch_xvfb
    #TODO error reporting
    system "#{@xvfb} :#{display} -screen 0 #{dimensions} -ac >/dev/null 2>&1 &"
    sleep 1
  end

  def read_pid
    @xvfb_pid=(File.read("/tmp/.X#{display}-lock") rescue "").strip.to_i
    @xvfb_pid=nil if @xvfb_pid==0
    @xvfb_pid
    #TODO maybe check that the process still exists
  end
end
