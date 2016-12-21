require 'spot_build/buildkite_agent'
require 'spot_build/spot_instance'
require 'spot_build/sqs_event'
require 'optparse'

module SpotBuild
  DEFAULT_TIMEOUT = 300

  def self.run
    options = parse_options
    options[:timeout] ||= DEFAULT_TIMEOUT

    checks = [SpotInstance.new]
    if options[:queue_url]
      checks.push(SqsEvent.new(url: options[:queue_url], timeout: options[:timeout], region: options[:aws_region]))
    end

    agent = BuildkiteAgent.new(options[:token], options[:org_slug])
    loop do
      checks.each do |check|
        terminating = check.shutdown_if_required do
          timeout = SpotInstance.scheduled_for_termination? ? (SpotInstance.time_until_termination - 30) : options[:timeout]

          agent.stop
          Timeout::timeout(timeout) do
            while agent.agent_running?
              sleep 5
            end
          end rescue Timeout::Error
          agent.the_end_is_nigh
        end
        %x(shutdown -h now) if terminating
      end
      sleep 2
    end
  end

  def self.parse_options
    options = {}
    parser = OptionParser.new do |opts|
      opts.banner = "Usage: #{__FILE__} [options]"
      opts.on("-t", "--token TOKEN", "Buildkite API token") { |v| options[:token] = v }
      opts.on("-o", "--org-slug ORGANISATION-SLUG", "The Buildkite Organisation Slug") { |v| options[:org_slug] = v }
      opts.on("-s", "--sqs-queue SQS-QUEUE-URL", "The SQS Queue URL we should monitor for events that tell us to shutdown") { |v| options[:queue_url] = v }
      opts.on("--timeout TIMEOUT", "The amount of time to wait for the buildkite agent to stop before shutting down. Only used if --sqs-queue is specified") { |v| options[:timeout] = v.to_i }
      opts.on("-r", "--aws-region REGION", "The AWS Region the SQS queue resides in")  { |v| options[:aws_region] = v }
    end
    parser.parse!

    if options[:token].nil? || options[:org_slug].nil?
      raise OptionParser::MissingArgument, "You must specify Token and Organisational Slug.\n#{parser.help}"
    end

    options
  end
end
