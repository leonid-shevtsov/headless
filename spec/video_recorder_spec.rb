require 'spec_helper'

describe Headless::VideoRecorder do
  before do
    stub_environment
  end

  describe "instaniation" do
    before do
      Headless::CliUtil.stub!(:application_exists?).and_return(false)
    end

    it "throws an error if ffmpeg is not installed" do
        lambda { Headless::VideoRecorder.new(99, "1024x768x32") }.should raise_error(Headless::Exception)
    end
  end

  describe "#capture" do
    it "starts ffmpeg" do
      Headless::CliUtil.stub(:path_to, 'ffmpeg').and_return('ffmpeg')
      Headless::CliUtil.should_receive(:fork_process).with(/ffmpeg -y -r 30 -g 600 -s 1024x768x32 -f x11grab -i :99 -vcodec qtrle/, "/tmp/.headless_ffmpeg_99.pid", '/dev/null')

      recorder = Headless::VideoRecorder.new(99, "1024x768x32")
      recorder.start_capture
    end

    it "starts ffmpeg with specified codec" do
      Headless::CliUtil.stub(:path_to, 'ffmpeg').and_return('ffmpeg')
      Headless::CliUtil.should_receive(:fork_process).with(/ffmpeg -y -r 30 -g 600 -s 1024x768x32 -f x11grab -i :99 -vcodec libvpx/, "/tmp/.headless_ffmpeg_99.pid", '/dev/null')

      recorder = Headless::VideoRecorder.new(99, "1024x768x32", {:codec => 'libvpx'})
      recorder.start_capture
    end
  end

  context "stopping video recording" do
    subject do
      recorder = Headless::VideoRecorder.new(99, "1024x768x32", :pid_file_path => "/tmp/pid", :tmp_file_path => "/tmp/ci.mov")
      recorder.start_capture
      recorder
    end

    describe "using #stop_and_save" do
      it "stops video recording and saves file" do
        Headless::CliUtil.should_receive(:kill_process).with("/tmp/pid", :wait => true)
        FileUtils.should_receive(:mv).with("/tmp/ci.mov", "/tmp/test.mov")

        subject.stop_and_save("/tmp/test.mov")
      end
    end

    describe "using #stop_and_discard" do
      it "stops video recording and deletes temporary file" do
        Headless::CliUtil.should_receive(:kill_process).with("/tmp/pid", :wait => true)
        FileUtils.should_receive(:rm).with("/tmp/ci.mov")

        subject.stop_and_discard
      end
    end
  end

private

  def stub_environment
    Headless::CliUtil.stub!(:application_exists?).and_return(true)
    Headless::CliUtil.stub!(:fork_process).and_return(true)
  end
end
