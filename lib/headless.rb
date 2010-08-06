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
# TODO maybe write a command-line wrapper like
#   headlessly firefox
#++
class Headless

  class Exception < ::Exception
  end

  # The display number
  attr_reader :display

  # Creates a new headless server, but NOT switches to it immediately. Call #start for that
  def initialize(options = {})
    @xvfb = `which Xvfb`.strip
    raise Exception.new('Xvfb not found on your system') if @xvfb == ''

    # TODO more options, like display dimensions and depth; set up default dimensions and depth
    @display = options.fetch(:display, 99).to_i
    @reuse_display = options.fetch(:reuse, true)

    #TODO more logic here, autopicking the display number
    if @reuse_display
      launch_xvfb unless read_pid
    elsif read_pid
      raise Exception.neW("Display :#{display} is already taken and reuse=false")
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
  def destroy
    stop
    Process.kill('TERM', xvfb_pid) if read_pid
  end

  # Block syntax:
  #
  #   Headless.run do
  #     # perform operations in headless mode
  #   end
  # 
  # Alias: #ly (Headless.ly)
  def self.run(options={}, &block)
    headless = Headless.new(options)
    headless.start
    yield headless
    headless.destroy
  end

  class <<self; alias_method :ly, :run; end

private
  attr_reader :xvfb_pid

  def launch_xvfb
    system "#{@xvfb} :#{display} -ac >/dev/null 2>&1 &"
    sleep 1
  end

  def read_pid
    @xvfb_pid=(File.read("/tmp/.X#{display}-lock") rescue "").strip.to_i
    @xvfb_pid=nil if @xvfb_pid==0
    @xvfb_pid
    #TODO maybe check that the process still exists
  end
end
