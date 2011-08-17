class CliUtil
  def self.application_exists?(app)
    `which #{app}`.strip != ""
  end

  def self.path_to(app)
    `which #{app}`.strip
  end

  def self.read_pid(file)
    pid = (File.read("/tmp/.X#{display}-lock") rescue "").strip.to_i
    pid == 0 ? nil : pid
  end

  def self.fork_process(command, pid_file)
    pid = fork do
      exec command
      exit! 127
    end

    File.open pid_file, 'w' do |f|
      f.puts pid
    end
  end

  def self.kill_process(pid_file)
    if File.exist? pid_file
      pid = File.read(pid_file).strip.to_i
      Process.kill 'TERM', pid
      FileUtils.rm pid_file
    else
      puts "#{pid_file} not found"
    end
  end
  
end