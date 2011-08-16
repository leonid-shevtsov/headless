require 'lib/headless'

describe Headless do
  before do
    ENV['DISPLAY'] = ":31337"
  end

  context "instaniation" do
    context "when Xvfb is not installed" do
      before do
        CliUtil.stub!(:application_exists?).and_return(false)
      end

      it "raises an error" do
        lambda { Headless.new }.should raise_error(Headless::Exception)
      end
    end

    context "when Xvfb not started yet" do
      before do
        stub_environment
      end

      it "starts Xvfb" do
        Headless.any_instance.should_receive(:system).with("/usr/bin/Xvfb :99 -screen 0 1280x1024x24 -ac >/dev/null 2>&1 &").and_return(true)

        headless = Headless.new
      end

      it "allows setting screen dimensions" do
        Headless.any_instance.should_receive(:system).with("/usr/bin/Xvfb :99 -screen 0 1024x768x16 -ac >/dev/null 2>&1 &").and_return(true)

        headless = Headless.new(:dimensions => "1024x768x16")
      end
    end

    context "when Xvfb is already running" do
      before do
        stub_environment
        CliUtil.stub!(:read_pid).and_return(31337)
      end

      it "raises an error if reuse display is not allowed" do
        lambda { Headless.new(:reuse => false) }.should raise_error(Headless::Exception)
      end

      it "doesn't raise an error if reuse display is allowed" do
        lambda { Headless.new(:reuse => true) }.should_not raise_error(Headless::Exception)
        lambda { Headless.new }.should_not raise_error(Headless::Exception)
      end
    end
  end

  describe "#start" do
    before do
      stub_environment

      @headless = Headless.new
    end

    it "switches to the headless server" do
      ENV['DISPLAY'].should == ":31337"
      @headless.start
      ENV['DISPLAY'].should == ":99"
    end
  end

  describe "#stop" do
    before do
      stub_environment

      @headless = Headless.new
    end

    it "switches back from the headless server" do
      ENV['DISPLAY'].should == ":31337"
      @headless.start
      ENV['DISPLAY'].should == ":99"
      @headless.stop
      ENV['DISPLAY'].should == ":31337"
    end
  end

  describe "#destroy" do
    before do
      stub_environment
      @headless = Headless.new

      CliUtil.stub!(:read_pid).and_return(4444)
    end

    it "switches back from the headless server and terminates the headless session" do
      Process.should_receive(:kill).with('TERM', 4444)

      ENV['DISPLAY'].should == ":31337"
      @headless.start
      ENV['DISPLAY'].should == ":99"
      @headless.destroy
      ENV['DISPLAY'].should == ":31337"
    end
  end

private

  def stub_environment
    CliUtil.stub!(:application_exists?).and_return(true)
    CliUtil.stub!(:read_pid).and_return(nil)
    CliUtil.stub!(:path_to).and_return("/usr/bin/Xvfb")
  end
end