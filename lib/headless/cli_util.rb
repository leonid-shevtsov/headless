class Headless
  class CliUtil
    def self.application_exists?(app)
      !!path_to(app)
    end

    def self.ensure_application_exists!(app, error_message)
      if !self.application_exists?(app)
        raise Headless::Exception.new(error_message)
      end
    end

    # Credit: http://stackoverflow.com/a/5471032/6678
    def self.path_to(app)
      exts = ENV['PATHEXT'] ? ENV['PATHEXT'].split(';') : ['']
      ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
        exts.each { |ext|
          exe = File.join(path, "#{app}#{ext}")
          return exe if File.executable?(exe) && !File.directory?(exe)
        }
      end
      return nil
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
      pid = Process.spawn(command, err: log_filename)
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
