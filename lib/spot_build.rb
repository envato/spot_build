require 'spot_build/buildkite_agent'
require 'spot_build/spot_instance'
require 'spot_build/sqs_event'
require 'optparse'

module SpotBuild
  def self.run
    options = parse_options
    while !SpotInstance.scheduled_for_termination?
      sleep 5
    end

    agent = BuildkiteAgent.new(options[:token], options[:org_slug])
    agent.stop

    # Delay the inevitable
    sleep SpotInstance.time_until_termination - 30

    agent.the_end_is_nigh
  end

  def self.parse_options
    options = {}
    parser = OptionParser.new do |opts|
      opts.banner = "Usage: #{__FILE__} [options]"
      opts.on("-t", "--token TOKEN", "Buildkite API token") { |v| options[:token] = v }
      opts.on("-o", "--org-slug ORGANISATION-SLUG", "The Buildkite Organisation Slug") { |v| options[:org_slug] = v }
    end
    parser.parse!

    if options[:token].nil? || options[:org_slug].nil?
      raise OptionParser::MissingArgument, "You must specify Token and Organisational Slug.\n#{parser.help}"
    end

    options
  end
end
