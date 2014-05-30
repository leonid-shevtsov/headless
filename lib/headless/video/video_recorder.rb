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
      @codec = options.fetch(:codec, "qtrle")
      @frame_rate = options.fetch(:frame_rate, 30)
      @provider = options.fetch(:provider, :libav)  # or :ffmpeg
    end

    def capture_running?
      CliUtil.read_pid @pid_file_path
    end

    def start_capture
      if @provider == :libav
        group_of_pic_size_option = '-g 600'
        dimensions = @dimensions
      else
        group_of_pic_size_option = ''
        dimensions = @dimensions.match(/^(\d+x\d+)/)[0]
      end

      CliUtil.fork_process("#{CliUtil.path_to('ffmpeg')} -y -r #{@frame_rate} #{group_of_pic_size_option} -s #{dimensions} -f x11grab -i :#{@display} -vcodec #{@codec} #{@tmp_file_path}", @pid_file_path, @log_file_path)
      at_exit do
        exit_status = $!.status if $!.is_a?(SystemExit)
        stop_and_discard
        exit exit_status if exit_status
      end
    end

    def stop_and_save(path)
      CliUtil.kill_process(@pid_file_path, :wait => true)
      if File.exists? @tmp_file_path
        begin
          FileUtils.mv(@tmp_file_path, path)
        rescue Errno::EINVAL
          nil
        end
      end
    end

    def stop_and_discard
      CliUtil.kill_process(@pid_file_path, :wait => true)
      begin
        FileUtils.rm(@tmp_file_path)
      rescue Errno::ENOENT
        # that's ok if the file doesn't exist
      end
    end
  end
end
