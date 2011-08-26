require 'tempfile'

class Headless
  class VideoRecorder
    attr_accessor :pid_file_path, :tmp_file_path, :log_file_path

    def initialize(display, dimensions, options = {})
      CliUtil.ensure_application_exists!('ffmpeg', 'Ffmpeg not found on your system. Install it with sudo apt-get install ffmpeg')

      @display = display
      @dimensions = dimensions

      @pid_file_path = options.fetch(:pid_file_path, "/tmp/.headless_ffmpeg_#{@display}.pid")
      @tmp_file_path = options.fetch(:tmp_file_path, "/tmp/.headless_ffmpeg_#{@display}.mov")
      @log_file_path = options.fetch(:log_file_path, "/dev/null")
    end

    def capture_running?
      !!@capture_running
    end

    def start_capture
      CliUtil.fork_process("#{CliUtil.path_to('ffmpeg')} -y -r 30 -g 600 -s #{@dimensions} -f x11grab -i :#{@display} -vcodec qtrle #{@tmp_file_path}", @pid_file_path, @log_file_path)
      @capture_running = true
      at_exit do
        stop_and_discard if capture_running?
      end
    end

    def stop_and_save(path)
      @capture_running = false
      CliUtil.kill_process(@pid_file_path, :wait => true)
      FileUtils.mv(@tmp_file_path, path)
    end

    def stop_and_discard
      @capture_running = false
      CliUtil.kill_process(@pid_file_path, :wait => true)
      begin
        FileUtils.rm(@tmp_file_path)
      rescue Errno::ENOENT
        # that's ok if the file doesn't exist
      end
    end
  end
end
