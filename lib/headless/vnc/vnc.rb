require 'tempfile'

class Headless
  class Vnc
    attr_accessor :pid_file_path, :log_file_path

    def vnc_running?
      !!read_vnc_pid
    end

    def read_vnc_pid
      CliUtil.read_pid(@pid_file_path)
    end

    def initialize(display, options = {})
      CliUtil.ensure_application_exists!('x11vnc', 'x11vnc not found on your system. Install it with sudo apt-get install x11vnc')

      @display = display

      @pid_file_path = options.fetch(:pid_file_path, "/tmp/.headless_vnc_#{@display}.pid")
      @log_file_path = options.fetch(:log_file_path, "/dev/null")
    end

    def start
      unless vnc_running?
        CliUtil.fork_process("#{CliUtil.path_to('x11vnc')} -display :#{@display} -N -nopw -viewonly -shared -forever", @pid_file_path, @log_file_path)
        at_exit do
          exit_status = $!.status if $!.is_a?(SystemExit)
          stop
          exit exit_status if exit_status
        end
      end
    end

    def stop
      CliUtil.kill_process(@pid_file_path, :wait => true)
    end
  end
end
