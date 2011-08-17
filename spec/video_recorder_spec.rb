require 'lib/headless'

describe VideoRecorder do
  before do
    stub_environment
  end

  describe "instaniation" do
    before do
      CliUtil.stub!(:application_exists?).and_return(false)
    end

    it "throws an error if ffmpeg is not installed" do
        lambda { VideoRecorder.new(99, "1024x768x32") }.should raise_error(Exception)
    end
  end

  describe "#start" do
    it "starts ffmpeg" do
      CliUtil.should_receive(:fork_process).with(/ffmpeg -y -r 30 -g 600 -s 1024x768x32 -f x11grab -i :99 -vcodec qtrle/, "/var/run/recorder_99.pid")

      recorder = VideoRecorder.new(99, "1024x768x32")
      recorder.start
    end
  end

private

  def stub_environment
    CliUtil.stub!(:application_exists?).and_return(true)
  end
end
