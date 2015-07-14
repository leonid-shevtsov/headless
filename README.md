# Headless [![Travis CI status](https://secure.travis-ci.org/leonid-shevtsov/headless.png)](http://travis-ci.org/leonid-shevtsov/headless)

Headless is *the* Ruby interface for Xvfb. It allows you to create a headless display straight from Ruby code, hiding the low-level action.
It can also capture images and video from the virtual framebuffer. For example, you can record screenshots and screencasts of your failing integration specs.

I created it so I can run Selenium tests in Cucumber without any shell scripting. Even more, you can go headless only when you run tests against Selenium.
Other possible uses include pdf generation with `wkhtmltopdf`, or screenshotting.

Documentation is available at [rubydoc.info](http://www.rubydoc.info/gems/headless)

[Changelog](https://github.com/leonid-shevtsov/headless/blob/master/CHANGELOG)

**Note: Headless will NOT hide most applications on OS X. [Here is a detailed explanation](https://github.com/leonid-shevtsov/headless/issues/31#issuecomment-8933108)**

## Installation

On Debian/Ubuntu:

```sh
sudo apt-get install xvfb
gem install headless
```

## Usage

Block mode:

```ruby
require 'rubygems'
require 'headless'
require 'selenium-webdriver'

Headless.ly do
  driver = Selenium::WebDriver.for :firefox
  driver.navigate.to 'http://google.com'
  puts driver.title 
end
```

Object mode:

```ruby
require 'rubygems'
require 'headless'
require 'selenium-webdriver'

headless = Headless.new
headless.start

driver = Selenium::WebDriver.for :firefox
driver.navigate.to 'http://google.com'
puts driver.title

headless.destroy
```

## Cucumber

Running cucumber headless is now as simple as adding a before and after hook in `features/support/env.rb`:

```ruby
# change the condition to fit your setup
if Capybara.current_driver == :selenium
  require 'headless'

  headless = Headless.new
  headless.start
end
```

## Running tests in parallel

If you have multiple threads running acceptance tests in parallel, you want to spawn Headless before forking, and then reuse that instance with `destroy_at_exit: false`.
You can even spawn a Headless instance in one ruby script, and then reuse the same instance in other scripts by specifying the same display number and `reuse: true`.

```ruby
# spawn_headless.rb
Headless.new(display: 100, destroy_at_exit: false).start

# test_suite_that_could_be_ran_multiple_times.rb
Headless.new(display: 100, reuse: true, destroy_at_exit: false).start

# reap_headless.rb 
headless = Headless.new(display: 100, reuse: true)
headless.destroy

# kill_headless_without_waiting.rb 
headless = Headless.new
headless.destroy_without_sync
```

There's also a different approach that creates a new virtual display for every parallel test process - see [this implementation](https://gist.github.com/rosskevin/5937888) by @rosskevin.

## Cucumber with wkhtmltopdf

_Note: this is true for other programs which may use headless at the same time as cucumber is running_

When wkhtmltopdf is using Headless, and cucumber is invoking a block of code which uses a headless session, make sure to override the default display of cucumber to retain browser focus. Assuming wkhtmltopdf is using the default display of 99, make sure to set the display to a value != 99 in `features/support/env.rb` file. This may be the cause of `Connection refused - connect(2) (Errno::ECONNREFUSED)`.

```ruby
headless = Headless.new(:display => '100')
headless.start
```

## Capturing video

Video is captured using `ffmpeg`. You can install it on Debian/Ubuntu via `sudo apt-get install ffmpeg` or on OS X via `brew install ffmpeg`. You can capture video continuously or capture scenarios separately. Here is typical use case:

```ruby
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
```

### Video options

When initiating Headless you may pass a hash with video options.

```ruby
headless = Headless.new(:video => { :frame_rate => 12, :codec => 'libx264' })
```

Available options:

* :codec - codec to be used by ffmpeg
* :frame_rate      - frame rate of video capture
* :provider        - ffmpeg provider - either :libav (default) or :ffmpeg
* :provider_binary_path - Explicit path to avconv or ffmpeg.  Only required when the binary cannot be discovered on the system $PATH.
* :pid_file_path   - path to ffmpeg pid file, default: "/tmp/.headless_ffmpeg_#{@display}.pid"
* :tmp_file_path   - path to tmp video file,  default: "/tmp/.headless_ffmpeg_#{@display}.mov"
* :log_file_path   - ffmpeg log file,         default: "/dev/null"
* :extra           - array of extra ffmpeg options, default: [] 

## Taking screenshots

Call `headless.take_screenshot` to take a screenshot. It needs two arguments:

- file_path - path where the image should be stored
- options - options, that can be:
    :using - :imagemagick or :xwd, :imagemagick is default, if :imagemagick is used, image format is determined by file_path extension

Screenshots can be taken by either using `import` (part of `imagemagick` library) or `xwd` utility.

`import` captures a screenshot and saves it in the format of the specified file. It is convenient but not too fast as 
it has to do the encoding synchronously.

`xwd` will capture a screenshot very fast and store it in its own format, which can then be converted to one 
of other picture formats using, for example, netpbm utilities - `xwdtopnm <xwd_file> | pnmtopng > capture.png`.

To install the necessary libraries on ubuntu:

`import` - run `sudo apt-get install imagemagick`
`xwd` - run `sudo apt-get install X11-apps` and if you are going to use netpbm utilities for image conversion - `sudo apt-get install netpbm`
 
## Troubleshooting

### Display socket is taken but lock file is missing

This means that there is an X server that is taking up the chosen display number, but its lock file is missing. This is an exceptional situation. Please stop the server process manually (`pkill Xvfb`) and open an issue.

### Video not recording

If video is not recording, and there are no visible exceptions, try passing the following option to Headless to figure out the reason: `Headless.new(video: {log_file_path: STDERR})`. In particular, there are some issues with the version of avconv packaged with Ubuntu 12.04 - an outdated release, but still in use on Travis.


##[Contributors](https://github.com/leonid-shevtsov/headless/graphs/contributors)

---

&copy; 2011-2015 Leonid Shevtsov, released under the MIT license
