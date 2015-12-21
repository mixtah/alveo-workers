$LOAD_PATH.unshift("#{File.dirname(__FILE__)}/../lib")

require 'yaml'
require 'optparse'
require 'ostruct'
require 'upload_worker'
require 'solr_worker'
require 'sesame_worker'
require 'postgres_worker'

def main(options)
  processes = options.processes
  worker_classes = options.worker_classes
  config = options.config
  workers = []
  begin
    p 'Starting workers...'
    worker_classes.each { |worker_class|
      processes.times {
        fork {
          config_key = worker_class.name.underscore.to_sym
          Process.setproctitle(worker_class.name)
          worker = worker_class.new(config[config_key])
          Signal.trap('INT') {
            worker.stop
            worker.close
          }
          worker.connect
          worker.start
          workers << worker
          loop {
            sleep 1
          }
        }
      }
    }
  p Process.waitall
  rescue SignalException
    p 'Stopping workers...'
    workers.each { |worker|
      Process.kill('INT', Worker)
    }
  end
end

class String
  def underscore
    self.gsub(/::/, '/').
    gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
    gsub(/([a-z\d])([A-Z])/,'\1_\2').
    tr("-", "_").
    downcase
  end
end

def parse_options(args)
  parsed_options = OpenStruct.new
  parsed_options.processes = 1
  parsed_options.worker_classes = [UploadWorker, SolrWorker, SesameWorker, PostgresWorker]
  parsed_options.config = YAML.load_file("#{File.dirname(__FILE__)}/../spec/files/config.yml")
  #TODO: Add option for specifying a config files
  option_parser = OptionParser.new do |options|
    options.banner = "Usage: launch_workers.rb [options]"
    options.separator ""
    options.separator "Specific options:"
    options.on('-p', '--processes [INT]', Integer, 'Number of processes per worker (default=1)') do |processes|
      parsed_options.processes = processes
    end
    options.on('-w', '--workers (upload|solr|sesame|postgres)+', 'Comma separated list of workers to launch (default=all)') do |workers|
      worker_classes = []
      workers.split(',').each { |worker|
        worker_classes << Module.const_get("#{worker.capitalize}Worker")
      }
      parsed_options.worker_classes = worker_classes
    end
    options.on('-h', '--help', 'Show this help message') do
      puts option_parser  
      exit
    end
  end
  begin
    option_parser.parse!(args)  
  rescue
    puts option_parser
  end
  parsed_options
end

if __FILE__ == $PROGRAM_NAME
  options = parse_options(ARGV)
  main(options)
end