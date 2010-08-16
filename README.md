# Headless

Headless is a Ruby interface for Xvfb. It allows you to create a headless display straight from Ruby code, hiding some low-level action.

I created it so I can run Selenium tests in Cucumber without any shell scripting. Even more, you can go headless only when you run tests against Selenium.
Other possible uses include pdf generation with `wkhtmltopdf`, or screenshotting.

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

      at_exit do
        headless.destroy
      end
    end

---

&copy; 2010 Leonid Shevtsov, released under the MIT license
