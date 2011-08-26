require 'tempfile'

class VideoRecorder
  def initialize(display, dimensions, options = {})
    raise Exception.new("Ffmpeg not found on your system. Install it with sudo apt-get install ffmpeg") unless CliUtil.application_exists?("Xvfb")

    @display = display
    @dimensions = dimensions

    @pid_file = options.fetch(:pid_file_path, "/tmp/.recorder_#{@display}-lock")
    @tmp_file_path = options.fetch(:tmp_file_path, "/tmp/ci.mov")
  end

  def capture
    CliUtil.fork_process("ffmpeg -y -r 30 -g 600 -s #{@dimensions} -f x11grab -i :#{@display} -vcodec qtrle /tmp/ci.mov", @pid_file)
  end

  def stop_and_save(path)
    CliUtil.kill_process(@pid_file)
    sleep 1 #TODO: invent something smarter, TERM message is async and we have to wait until ffmpeg flush its buffer.
    FileUtils.cp(@tmp_file_path, path)
  end

  def stop_and_discard
    CliUtil.kill_process(@pid_file)
    FileUtils.rm(@tmp_file_path)
  end
end