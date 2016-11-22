require 'spot_build/buildkite_agent'
require 'spot_build/spot_instance'

module SpotBuild
  def self.run
    options = parse_options
    while !SpotInstance.scheduled_for_termination?
      sleep 5
    end

    # Delay the inevitable
    while SpotInstance.time_until_termination > 30
      sleep 1
    end

    BuildkiteAgent.new(options[:token], options[:org_slug]).the_end_is_nigh
  end

  def self.parse_options
    options = {}
    OptionParser.new do |opts|
      opts.banner = "Usage: #{__FILE__} [options]"
      opts.on("--token TOKEN", "Buildkite API token") { |v| options[:token] = v }
      opts.on("--org-slug ORGANISATION-SLUG", "The Buildkite Organisation Slug") { |v| options[:org_slug] = v }
    end.parse!
    options
  end
end
