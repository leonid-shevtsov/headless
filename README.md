= Headless

Headless is a Ruby interface for Xvfb. It allows you to create a headless display straight from Ruby code, hiding some low-level action.

I created it so I can run Selenium tests in Cucumber without any shell scripting, so that, for instance, you can go headless only when you run tests
against Selenium.

== Prerequisites

* X Window System
* Xvfb[http://en.wikipedia.org/wiki/Xvfb]

== Usage

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

== Cucumber
