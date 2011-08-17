require 'tempfile'

class VideoRecorder
  def initialize(display, dimensions, options = {})
    raise Exception.new("ffmpeg not found on your system") unless CliUtil.application_exists?("Xvfb")

    @display = display
    @dimensions = dimensions

    @pid_file = "/var/run/recorder_#{@display}.pid"
  end

  def start
    @output_file = Tempfile.new("video_recorder")
    @output_file.close
    CliUtil.fork_process("ffmpeg -y -r 30 -g 600 -s #{@dimensions} -f x11grab -i :#{@display} -vcodec qtrle #{@output_file.path}", @pid_file)
  end

  def stop_and_save(path)
    CliUtil.kill_process(@pid_file)
    FileUtils.cp @output_file.path, path
    @output_file.unlink
  end

  def stop_and_clear
    CliUtil.kill_process(@pid_file)
    @output_file.unlink
  end
end