require "headless"

require "tempfile"

describe Headless::VideoRecorder do
  before do
    stub_environment
  end

  describe "instantiation" do
    it "throws an error if ffmpeg_path is not installed" do
      allow(Headless::CliUtil).to receive(:application_exists?).and_return(false)
      expect { Headless::VideoRecorder.new(99, "1024x768x32") }.to raise_error(Headless::Exception)
    end

    it "allows ffmpeg_path to be specified" do
      Tempfile.open("ffmpeg") do |f|
        v = Headless::VideoRecorder.new(99, "1024x768x32", ffmpeg_path: f.path)
        expect(v.ffmpeg_path).to eq(f.path)
      end
    end

    it "supports provider_binary_path for backward compatibility" do
      Tempfile.open("ffmpeg") do |f|
        v = Headless::VideoRecorder.new(99, "1024x768x32", provider_binary_path: f.path)
        expect(v.ffmpeg_path).to eq(f.path)
      end
    end
  end

  describe "#capture" do
    before do
      allow(Headless::CliUtil).to receive(:path_to).and_return("ffmpeg")
    end

    it "starts ffmpeg" do
      expect(Headless::CliUtil).to receive(:fork_process).with(
        /^ffmpeg -y -r 30 -s 1024x768 -f x11grab -i :99 -vcodec qtrle [^ ]+$/,
        "/tmp/.headless_ffmpeg_99.pid",
        File::NULL
      )

      recorder = Headless::VideoRecorder.new(99, "1024x768x32")
      recorder.start_capture
    end

    it "starts ffmpeg with specified codec" do
      expect(Headless::CliUtil).to receive(:fork_process).with(
        /^ffmpeg -y -r 30 -s 1024x768 -f x11grab -i :99 -vcodec libvpx [^ ]+$/,
        "/tmp/.headless_ffmpeg_99.pid",
        File::NULL
      )

      recorder = Headless::VideoRecorder.new(99, "1024x768x32", {codec: "libvpx"})
      recorder.start_capture
    end

    it "starts ffmpeg with specified extra device options" do
      expect(Headless::CliUtil).to receive(:fork_process).with(
        /^ffmpeg -y -r 30 -s 1024x768 -f x11grab -i :99 -draw_mouse 0 -vcodec qtrle [^ ]+$/,
        "/tmp/.headless_ffmpeg_99.pid", File::NULL
      )

      recorder = Headless::VideoRecorder.new(99, "1024x768x32", {devices: ["-draw_mouse 0"]})
      recorder.start_capture
    end
  end

  context "stopping video recording" do
    let(:tmpfile) { "/tmp/ci.mov" }
    let(:filename) { "/tmp/test.mov" }
    let(:pidfile) { "/tmp/pid" }

    subject do
      recorder = Headless::VideoRecorder.new(99, "1024x768x32", pid_file_path: pidfile, tmp_file_path: tmpfile)
      recorder.start_capture
      recorder
    end

    describe "using #stop_and_save" do
      it "stops video recording and saves file" do
        expect(Headless::CliUtil).to receive(:kill_process).with(pidfile, wait: true)
        expect(File).to receive(:exist?).with(tmpfile).and_return(true)
        expect(FileUtils).to receive(:mv).with(tmpfile, filename)

        subject.stop_and_save(filename)
      end
    end

    describe "using #stop_and_discard" do
      it "stops video recording and deletes temporary file" do
        expect(Headless::CliUtil).to receive(:kill_process).with(pidfile, wait: true)
        expect(FileUtils).to receive(:rm).with(tmpfile)

        subject.stop_and_discard
      end
    end
  end

  private

  def stub_environment
    allow(Headless::CliUtil).to receive(:application_exists?).and_return(true)
    allow(Headless::CliUtil).to receive(:fork_process).and_return(true)
  end
end
