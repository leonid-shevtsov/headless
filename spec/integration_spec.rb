require 'headless'
require 'selenium-webdriver'

describe 'Integration test' do
  let!(:headless) { Headless.new }
  before { headless.start }

  after { headless.destroy_sync }

  it 'should use xvfb' do
    work_with_browser
  end

  it 'should record screenshots' do
    headless.take_screenshot("test.jpg")
    expect(File.exist?("test.jpg")).to eq true
  end

  it 'should record video with ffmpeg' do
    headless.video.start_capture
    work_with_browser
    headless.video.stop_and_save("test.mov")
    expect(File.exist?("test.mov")).to eq true
  end

  it 'should raise an error when trying to create the same display' do
    expect {
      FileUtils.mv("/tmp/.X#{headless.display}-lock", "/tmp/headless-test-tmp")
      Headless.new(display: headless.display, reuse: false)
    }.to raise_error(Headless::Exception, /troubleshooting guide/)
    FileUtils.mv("/tmp/headless-test-tmp", "/tmp/.X#{headless.display}-lock")
  end

  private

  def work_with_browser
    driver = Selenium::WebDriver.for :firefox
    driver.navigate.to 'http://google.com'
    expect(driver.title).to match(/Google/)
    driver.close
  end
end
