require "tempfile"

class Headless
  class VideoRecorder
    attr_accessor :pid_file_path, :tmp_file_path, :log_file_path, :ffmpeg_path

    # Construct a new Video Recorder instance. Typically done from inside Headless, but can be also created manually,
    # and even used separately from Headless' Xvfb features.
    # * display - display number to capture
    # * dimensions - dimensions of the captured video
    # * options - available options:
    #   * ffmpeg_path - override path to ffmpeg binary
    #   * pid_file_path - override path to PID file, default is placed in /tmp
    #   * tmp_file_path - override path to temp file, default is placed in /tmp
    #   * log_file_path - set log file path, default is /dev/null
    #   * codec - change ffmpeg codec, default is qtrle
    #   * frame_rate - change frame rate, default is 30
    #   * devices - array of device options - see https://www.ffmpeg.org/ffmpeg-devices.html
    #   * extra - array of extra options to append to the FFMpeg command line
    def initialize(display, dimensions, options = {})
      @display = display
      @dimensions = dimensions[/.+(?=x)/]

      @pid_file_path = options.fetch(:pid_file_path, "/tmp/.headless_ffmpeg_#{@display}.pid")
      @tmp_file_path = options.fetch(:tmp_file_path, "/tmp/.headless_ffmpeg_#{@display}.mov")
      @log_file_path = options.fetch(:log_file_path, File::NULL)
      @codec = options.fetch(:codec, "qtrle")
      @frame_rate = options.fetch(:frame_rate, 30)

      # If no ffmpeg_path was specified, use the default
      @ffmpeg_path = options.fetch(:ffmpeg_path, options.fetch(:provider_binary_path, "ffmpeg"))

      @extra = Array(options.fetch(:extra, []))
      @devices = Array(options.fetch(:devices, []))

      CliUtil.ensure_application_exists!(ffmpeg_path,
        "#{ffmpeg_path} not found on your system. " \
        "Install it or change video recorder provider")
    end

    def capture_running?
      CliUtil.read_pid @pid_file_path
    end

    def start_capture
      CliUtil.fork_process(command_line_for_capture,
        @pid_file_path, @log_file_path)
      at_exit do
        exit_status = $!.status if $!.is_a?(SystemExit)
        stop_and_discard
        exit exit_status if exit_status
      end
    end

    def stop_and_save(path)
      CliUtil.kill_process(@pid_file_path, wait: true)
      if File.exist? @tmp_file_path
        begin
          FileUtils.mkdir_p(File.dirname(path))
          FileUtils.mv(@tmp_file_path, path)
        rescue Errno::EINVAL
          nil
        end
      end
    end

    def stop_and_discard
      CliUtil.kill_process(@pid_file_path, wait: true)
      begin
        FileUtils.rm(@tmp_file_path)
      rescue Errno::ENOENT
        # that's ok if the file doesn't exist
      end
    end

    private

    def command_line_for_capture
      dimensions = @dimensions.match(/^(\d+x\d+)/)[0]

      [
        CliUtil.path_to(ffmpeg_path),
        "-y",
        "-r #{@frame_rate}",
        "-s #{dimensions}",
        "-f x11grab",
        "-i :#{@display}",
        @devices,
        "-vcodec #{@codec}",
        @extra,
        @tmp_file_path
      ].flatten.compact.join(" ")
    end
  end
end
