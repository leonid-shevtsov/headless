require 'headless'

describe Headless do
  before do
    ENV['DISPLAY'] = ":31337"
    stub_environment
  end

  describe 'launch options' do
    before do
      allow_any_instance_of(Headless).to receive(:ensure_xvfb_launched).and_return(true)
    end

    it "starts Xvfb" do
      expect(Process).to receive(:spawn).with(*(%w(/usr/bin/Xvfb :99 -screen 0 1280x1024x24 -ac)+[hash_including(:err)])).and_return(123)
      headless = Headless.new
    end

    it "allows setting screen dimensions" do
      expect(Process).to receive(:spawn).with(*(%w(/usr/bin/Xvfb :99 -screen 0 1024x768x16 -ac)+[hash_including(:err)])).and_return(123)
      headless = Headless.new(:dimensions => "1024x768x16")
    end
  end

  context 'with stubbed launch_xvfb' do
    before do
      allow_any_instance_of(Headless).to receive(:launch_xvfb).and_return(true)
    end

    context "instantiation" do
      context "when Xvfb is not installed" do
        before do
          allow(Headless::CliUtil).to receive(:application_exists?).and_return(false)
        end

        it "raises an error" do
          expect { Headless.new }.to raise_error(Headless::Exception)
        end
      end

      context "when Xvfb is already running and was started by this user" do
        before do
          allow(Headless::CliUtil).to receive(:read_pid).with('/tmp/.X99-lock').and_return(31337)
          allow(Headless::CliUtil).to receive(:process_running?).with(31337).and_return(true)
          allow(Headless::CliUtil).to receive(:process_mine?).with(31337).and_return(true)

          allow(Headless::CliUtil).to receive(:read_pid).with('/tmp/.X100-lock').and_return(nil)
        end

        context "and display reuse is allowed" do
          let(:options) { {:reuse => true} }

          it "should reuse the existing Xvfb" do
            expect(Headless.new(options).display).to eq 99
          end

          it "should not be destroyed at exit by default" do
            expect(Headless.new(options).destroy_at_exit?).to eq false
          end
        end

        context "and display reuse is not allowed" do
          let(:options) { {:reuse => false} }

          it "should pick the next available display number" do
            expect(Headless.new(options).display).to eq 100
          end

          context "and display number is explicitly set" do
            let(:options) { {:reuse => false, :display => 99} }

            it "should fail with an exception" do
              expect { Headless.new(options) }.to raise_error(Headless::Exception)
            end

            context "and autopicking is allowed" do
              let(:options) { {:reuse => false, :display => 99, :autopick => true} }

              it "should pick the next available display number" do
                expect(Headless.new(options).display).to eq 100
              end
            end
          end
        end
      end

      context 'when Xvfb is started, but by another user' do
        before do
          allow(Headless::CliUtil).to receive(:read_pid).with('/tmp/.X99-lock').and_return(31337)
          allow(Headless::CliUtil).to receive(:process_running?).with(31337).and_return(true)
          allow(Headless::CliUtil).to receive(:process_mine?).with(31337).and_return(false)

          allow(Headless::CliUtil).to receive(:read_pid).with('/tmp/.X100-lock').and_return(nil)
        end

        context "and display autopicking is not allowed" do
          let(:options) { {:autopick => false} }

          it "should reuse the display" do
            expect(Headless.new(options).display).to eq 99
          end
        end

        context "and display autopicking is allowed" do
          let(:options) { {:autopick => true} }

          it "should pick the next display number" do
            expect(Headless.new(options).display).to eq 100
          end
        end
      end
    end

    context "lifecycle" do
      let(:headless) { Headless.new }
      describe "#start" do
        it "switches to the headless server" do
          expect(ENV['DISPLAY']).to eq ":31337"
          headless.start
          expect(ENV['DISPLAY']).to eq ":99"
        end
      end

      describe "#stop" do
        it "switches back from the headless server" do
          expect(ENV['DISPLAY']).to eq ":31337"
          headless.start
          expect(ENV['DISPLAY']).to eq ":99"
          headless.stop
          expect(ENV['DISPLAY']).to eq ":31337"
        end
      end

      describe "#destroy" do
        before do
          allow(Headless::CliUtil).to receive(:read_pid).and_return(4444)
        end

        it "switches back from the headless server and terminates the headless session" do
          expect(Process).to receive(:kill).with('TERM', 4444)

          expect(ENV['DISPLAY']).to eq ":31337"
          headless.start
          expect(ENV['DISPLAY']).to eq ":99"
          headless.destroy
          expect(ENV['DISPLAY']).to eq ":31337"
        end
      end
    end

    context "#video" do
      let(:headless) { Headless.new }

      it "returns video recorder" do
        expect(headless.video).to be_a_kind_of(Headless::VideoRecorder)
      end

      it "returns the same instance" do
        recorder = headless.video
        expect(headless.video).to eq recorder
      end
    end

    context "#take_screenshot" do
      let(:headless) { Headless.new }

      it "raises an error if unknown value for option :using is used" do
        expect { headless.take_screenshot('a.png', :using => :teleportation) }.to raise_error(Headless::Exception)
      end

      it "raises an error if imagemagick is not installed, with default options" do
        allow(Headless::CliUtil).to receive(:application_exists?).with('import').and_return(false)

        expect { headless.take_screenshot('a.png') }.to raise_error(Headless::Exception)
      end

      it "raises an error if imagemagick is not installed, with using: :imagemagick" do
        allow(Headless::CliUtil).to receive(:application_exists?).with('import').and_return(false)

        expect { headless.take_screenshot('a.png', :using => :imagemagick) }.to raise_error(Headless::Exception)
      end

      it "raises an error if xwd is not installed, with using: :xwd" do
        allow(Headless::CliUtil).to receive(:application_exists?).with('xwd').and_return(false)

        expect { headless.take_screenshot('a.png', :using => :xwd) }.to raise_error(Headless::Exception)
      end

      it "raises an error if gm is not installed with using: :graphicsmagick" do
        allow(Headless::CliUtil).to receive(:application_exists?).with('gm').and_return(false)

        expect { headless.take_screenshot('a.png', :using => :graphicsmagick) }.to raise_error(Headless::Exception)
      end

      it "raises an error if gm is not installed with using: :gm" do
        allow(Headless::CliUtil).to receive(:application_exists?).with('gm').and_return(false)

        expect { headless.take_screenshot('a.png', :using => :gm) }.to raise_error(Headless::Exception)
      end

      it "issues command to take screenshot, with default options" do
        allow(Headless::CliUtil).to receive(:path_to).with('import').and_return('path/import')
        expect(headless).to receive(:system).with("path/import -display localhost:99 -window root /tmp/image.png")
        headless.take_screenshot("/tmp/image.png")
      end

      it "issues command to take screenshot, with using: :imagemagick" do
        allow(Headless::CliUtil).to receive(:path_to).with('import').and_return('path/import')
        expect(headless).to receive(:system).with("path/import -display localhost:99 -window root /tmp/image.png")
        headless.take_screenshot("/tmp/image.png", :using => :imagemagick)
      end

      it "issues command to take screenshot, with using: :xwd" do
        allow(Headless::CliUtil).to receive(:path_to).with('xwd').and_return('path/xwd')
        expect(headless).to receive(:system).with("path/xwd -display localhost:99 -silent -root -out /tmp/image.png")
        headless.take_screenshot("/tmp/image.png", :using => :xwd)
      end

      it "issues command to take screenshot, with using: :graphicsmagick" do
        allow(Headless::CliUtil).to receive(:path_to).with('gm').and_return('path/gm')
        expect(headless).to receive(:system).with("path/gm import -display localhost:99 -window root /tmp/image.png")
        headless.take_screenshot("/tmp/image.png", :using => :graphicsmagick)
      end

      it "issues command to take screenshot, with using: :gm" do
        allow(Headless::CliUtil).to receive(:path_to).with('gm').and_return('path/gm')
        expect(headless).to receive(:system).with("path/gm import -display localhost:99 -window root /tmp/image.png")
        headless.take_screenshot("/tmp/image.png", :using => :gm)
      end
    end
  end

private

  def stub_environment
    allow(Headless::CliUtil).to receive(:application_exists?).and_return(true)
    allow(Headless::CliUtil).to receive(:read_pid).and_return(nil)
    allow(Headless::CliUtil).to receive(:path_to).and_return("/usr/bin/Xvfb")
  end
end
