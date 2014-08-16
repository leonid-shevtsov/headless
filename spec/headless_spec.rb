require 'headless'

describe Headless do
  before do
    ENV['DISPLAY'] = ":31337"
    stub_environment
  end

  context "instantiation" do
    context "when Xvfb is not installed" do
      before do
        Headless::CliUtil.stub(:application_exists?).and_return(false)
      end

      it "raises an error" do
        lambda { Headless.new }.should raise_error(Headless::Exception)
      end
    end

    context "when Xvfb is not started yet" do
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
        Headless::CliUtil.stub(:read_pid).with('/tmp/.X99-lock').and_return(31337)
        Headless::CliUtil.stub(:read_pid).with('/tmp/.X100-lock').and_return(nil)
      end

      context "and display reuse is allowed" do
        let(:options) { {:reuse => true} }

        it "should reuse the existing Xvfb" do
          Headless.new(options).display.should == 99
        end
      end

      context "and display reuse is not allowed" do
        let(:options) { {:reuse => false} }

        it "should pick the next available display number" do
          Headless.new(options).display.should == 100
        end

        context "and display number is explicitly set" do
          let(:options) { {:reuse => false, :display => 99} }

          it "should fail with an exception" do
            lambda { Headless.new(options) }.should raise_error(Headless::Exception)
          end

          context "and autopicking is allowed" do
            let(:options) { {:reuse => false, :display => 99, :autopick => true} }

            it "should pick the next available display number" do
              Headless.new(options).display.should == 100
            end
          end
        end
      end
    end

    context 'when Xvfb is started, but by another user' do
      before do
        Headless::CliUtil.stub(:read_pid).with('/tmp/.X99-lock') { raise Errno::EPERM }
        Headless::CliUtil.stub(:read_pid).with('/tmp/.X100-lock').and_return(nil)
      end

      context "and display autopicking is not allowed" do
        let(:options) { {:autopick => false} }

        it "should fail with and exception" do
          lambda { Headless.new(options) }.should raise_error(Headless::Exception)
        end
      end

      context "and display autopicking is allowed" do
        let(:options) { {:autopick => true} }

        it "should pick the next display number" do
          Headless.new(options).display.should == 100
        end
      end
    end
  end

  context "lifecycle" do
    let(:headless) { Headless.new }
    describe "#start" do
      it "switches to the headless server" do
        ENV['DISPLAY'].should == ":31337"
        headless.start
        ENV['DISPLAY'].should == ":99"
      end
    end

    describe "#stop" do
      it "switches back from the headless server" do
        ENV['DISPLAY'].should == ":31337"
        headless.start
        ENV['DISPLAY'].should == ":99"
        headless.stop
        ENV['DISPLAY'].should == ":31337"
      end
    end

    describe "#destroy" do
      before do
        Headless::CliUtil.stub(:read_pid).and_return(4444)
      end

      it "switches back from the headless server and terminates the headless session" do
        Process.should_receive(:kill).with('TERM', 4444)

        ENV['DISPLAY'].should == ":31337"
        headless.start
        ENV['DISPLAY'].should == ":99"
        headless.destroy
        ENV['DISPLAY'].should == ":31337"
      end
    end
  end

  context "#video" do
    let(:headless) { Headless.new }

    it "returns video recorder" do
      headless.video.should be_a_kind_of(Headless::VideoRecorder)
    end

    it "returns the same instance" do
      recorder = headless.video
      headless.video.should be_eql(recorder)
    end
  end

  context "#take_screenshot" do
    let(:headless) { Headless.new }

    it "raises an error if unknown value for option :using is used" do
      expect { headless.take_screenshot('a.png', using: :teleportation) }.to raise_error(Headless::Exception)
    end

    it "raises an error if imagemagick is not installed, with default options" do
      Headless::CliUtil.stub(:application_exists?).with('import').and_return(false)

      expect { headless.take_screenshot('a.png') }.to raise_error(Headless::Exception)
    end

    it "raises an error if imagemagick is not installed, with using: :import" do
      Headless::CliUtil.stub(:application_exists?).with('import').and_return(false)

      expect { headless.take_screenshot('a.png', using: :import) }.to raise_error(Headless::Exception)
    end

    it "raises an error if xwd is not installed, with using: :xwd" do
      Headless::CliUtil.stub(:application_exists?).with('xwd').and_return(false)

      expect { headless.take_screenshot('a.png', using: :xwd) }.to raise_error(Headless::Exception)
    end

    it "issues command to take screenshot, with default options" do
      allow(Headless::CliUtil).to receive(:path_to).with('import').and_return('path/import')
      expect(headless).to receive(:system).with("path/import -display localhost:99 -window root /tmp/image.png")
      headless.take_screenshot("/tmp/image.png")
    end

    it "issues command to take screenshot, with using: :import" do
      allow(Headless::CliUtil).to receive(:path_to).with('import').and_return('path/import')
      expect(headless).to receive(:system).with("path/import -display localhost:99 -window root /tmp/image.png")
      headless.take_screenshot("/tmp/image.png", using: :import)
    end

    it "issues command to take screenshot, with using: :xwd" do
      allow(Headless::CliUtil).to receive(:path_to).with('xwd').and_return('path/xwd')
      expect(headless).to receive(:system).with("path/xwd -display localhost:99 -silent -root -out /tmp/image.png")
      headless.take_screenshot("/tmp/image.png", using: :xwd)
    end
  end

private

  def stub_environment
    Headless::CliUtil.stub(:application_exists?).and_return(true)
    Headless::CliUtil.stub(:read_pid).and_return(nil)
    Headless::CliUtil.stub(:path_to).and_return("/usr/bin/Xvfb")

    # TODO this is wrong. But, as long as Xvfb is started inside the constructor (which is also wrong), I don't see another option to make tests pass
    Headless.any_instance.stub(:ensure_xvfb_is_running).and_return(true)
  end
end
