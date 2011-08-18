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

  describe "#capture" do
    it "starts ffmpeg" do
      CliUtil.should_receive(:fork_process).with(/ffmpeg -y -r 30 -g 600 -s 1024x768x32 -f x11grab -i :99 -vcodec qtrle/, "/tmp/.recorder_99-lock")

      recorder = VideoRecorder.new(99, "1024x768x32")
      recorder.capture
    end
  end

  context "stopping video recording" do
    before do
      @recorder = VideoRecorder.new(99, "1024x768x32", :pid_file_path => "/tmp/pid", :tmp_file_path => "/tmp/ci.mov")
      @recorder.capture
    end

    describe "using #stop_and_save" do
      it "stops video recording and saves file" do
        CliUtil.should_receive(:kill_process).with("/tmp/pid")
        FileUtils.should_receive(:cp).with("/tmp/ci.mov", "/tmp/test.mov")

        @recorder.stop_and_save("/tmp/test.mov")
      end
    end

    describe "using #stop_and_discard" do
      it "stops video recording and deletes temporary file" do
        CliUtil.should_receive(:kill_process).with("/tmp/pid")
        FileUtils.should_receive(:rm).with("/tmp/ci.mov")

        @recorder.stop_and_discard
      end
    end
  end

private

  def stub_environment
    CliUtil.stub!(:application_exists?).and_return(true)
    CliUtil.stub!(:fork_process).and_return(true)
  end
end
