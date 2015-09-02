class Headless
  class CliUtil
    def self.application_exists?(app)
      !path_to(app).nil?
    end

    def self.ensure_application_exists!(app, error_message)
      if !self.application_exists?(app)
        raise Headless::Exception.new(error_message)
      end
    end

    def self.path_to(app)
      ENV['PATH'].split(':').each do |path|
        which = File.join(path, app)
        return which if File.executable?(which)
      end
    end

    def self.process_mine?(pid)
      Process.kill(0, pid) && true
    rescue Errno::EPERM, Errno::ESRCH
      false
    end

    def self.process_running?(pid)
      Process.getpgid(pid) && true
    rescue Errno::ESRCH
      false
    end

    def self.read_pid(pid_filename)
      pid = (File.read(pid_filename) rescue "").strip
      pid.empty? ? nil : pid.to_i
    end

    def self.fork_process(command, pid_filename, log_filename='/dev/null')
      pid = fork do
        STDERR.reopen(log_filename)
        exec command
        exit! 127 # safeguard in case exec fails
      end

      File.open pid_filename, 'w' do |f|
        f.puts pid
      end
    end

    def self.kill_process(pid_filename, options={})
      if pid = read_pid(pid_filename)
        begin
          Process.kill 'TERM', pid
          Process.wait pid if options[:wait]
        rescue Errno::ESRCH
          # no such process; assume it's already killed
        rescue Errno::ECHILD
          # Process.wait tried to wait on a dead process
        end
      end

      unless options[:preserve_pid_file]
        begin
          FileUtils.rm pid_filename
        rescue Errno::ENOENT
          # pid file already removed
        end
      end
    end
  end
end
