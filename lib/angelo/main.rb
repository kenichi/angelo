require "angelo"

module Angelo
  class Base
    def self.parse_options(argv)
      require "optparse"

      optparse = OptionParser.new do |op|
        op.banner = "Usage: #{$0} [options]"

        op.on('-p port', OptionParser::DecimalInteger, "set the port (default is #{port})") {|val| port val}
        op.on('-o addr', "set the host (default is #{addr})") {|val| addr val}

        op.on('-h', '--help', "Show this help") do
          puts op
          exit
        end
      end

      begin
        optparse.parse(argv)
      rescue OptionParser::ParseError => ex
        $stderr.puts ex
        $stderr.puts optparse
        exit 1
      end
    end
  end
end
