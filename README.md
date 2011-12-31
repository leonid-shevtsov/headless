# Headless

Headless is a Ruby interface for Xvfb. It allows you to create a headless display straight from Ruby code, hiding some low-level action.
It can also capture images and video from the virtual framebuffer.

I created it so I can run Selenium tests in Cucumber without any shell scripting. Even more, you can go headless only when you run tests against Selenium.
Other possible uses include pdf generation with `wkhtmltopdf`, or screenshotting.

Documentation is available at [rdoc.info](http://rdoc.info/projects/leonid-shevtsov/headless)

## Installation

On Debian/Ubuntu:

    sudo apt-get install xvfb
    gem install headless

## Usage

Block mode:

    require 'rubygems'
    require 'headless'
    require 'selenium-webdriver'

    Headless.ly do
      driver = Selenium::WebDriver.for :firefox
      driver.navigate.to 'http://google.com'
      puts driver.title 
    end

Object mode:

    require 'rubygems'
    require 'headless'
    require 'selenium-webdriver'

    headless = Headless.new
    headless.start

    driver = Selenium::WebDriver.for :firefox
    driver.navigate.to 'http://google.com'
    puts driver.title

    headless.destroy

## Cucumber

Running cucumber headless is now as simple as adding a before and after hook in `features/support/env.rb`:


    # change the condition to fit your setup
    if Capybara.current_driver == :selenium
      require 'headless'

      headless = Headless.new
      headless.start
    end

## Cucumber with wkhtmltopdf

_Note: this is true for other programs which may use headless at the same time as cucumber is running_

When wkhtmltopdf is using Headless, and cucumber is invoking a block of code which uses a headless session, make sure to override the default display of cucumber to retain browser focus. Assuming wkhtmltopdf is using the default display of 99, make sure to set the display to a value != 99 in `features/support/env.rb` file. This may be the cause of `Connection refused - connect(2) (Errno::ECONNREFUSED)`.

    headless = Headless.new(:display => '100')
    headless.start

## Capturing video

Video is captured using `ffmpeg`. You can install it on Debian/Ubuntu via `sudo apt-get install ffmpeg` or on OS X via `brew install ffmpeg`. You can capture video continuously or capture scenarios separately. Here is typical use case:

    require 'headless'

    headless = Headless.new
    headless.start

    Before do
      headless.video.start_capture
    end

    After do |scenario|
      if scenario.failed?
        headless.video.stop_and_save("/tmp/#{BUILD_ID}/#{scenario.name.split.join("_")}.mov")
      else
        headless.video.stop_and_discard
      end
    end

## Taking screenshots

Images are captured using `import` utility which is part of `imagemagick` library. You can install it on Ubuntu via `sudo apt-get install imagemagick`. You can call `headless.take_screenshot` at any time. You have to supply full path to target file. File format is determined by supplied file extension.

## Contributors

* [Igor Afonov](http://iafonov.github.com) - video and screenshot capturing functionality.

---

&copy; 2011 Leonid Shevtsov, released under the MIT license
