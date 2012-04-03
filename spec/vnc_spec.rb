require 'spec_helper'

describe Headless::Vnc do
  before do
    stub_environment
  end

  describe "instaniation" do
    before do
      Headless::CliUtil.stub!(:application_exists?).and_return(false)
    end

    it "throws an error if x11vnc is not installed" do
      lambda { Headless::Vnc.new(99, 5900) }.should raise_error(Headless::Exception)
    end
  end

  describe "start" do
    it "starts x11vnc" do
      Headless::CliUtil.stub(:path_to, 'x11vnc').and_return('x11vnc')
      Headless::CliUtil.should_receive(:fork_process).with(/x11vnc -display :99 -N -nopw -viewonly -shared -forever -listen localhost/, "/tmp/.headless_vnc_99.pid", '/dev/null')

      recorder = Headless::Vnc.new(99)
      recorder.start
    end

    it "should not start x11vnc if it's already running" do
      Headless::CliUtil.stub(:path_to, 'x11vnc').and_return('x11vnc')
      Headless::CliUtil.stub(:read_pid).and_return('123')
      Headless::CliUtil.should_not_receive(:fork_process)

      recorder = Headless::Vnc.new(99)
      recorder.start
    end
  end

  context "stop" do
    subject do
      recorder = Headless::Vnc.new(99, :pid_file_path => "/tmp/pid")
      recorder.start
      recorder
    end

    it "stops kills the server" do
      Headless::CliUtil.should_receive(:kill_process).with("/tmp/pid", :wait => true)

      subject.stop()
    end
  end

  private

  def stub_environment
    Headless::CliUtil.stub!(:application_exists?).and_return(true)
    Headless::CliUtil.stub!(:fork_process).and_return(true)
  end
end
