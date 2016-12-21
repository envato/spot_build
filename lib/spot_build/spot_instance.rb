require 'net/http'
require 'time'

module SpotBuild
  class SpotInstance
    def shutdown_if_required(&block)
      return false unless self.class.scheduled_for_termination?
      yield
      true
    end

    def self.scheduled_for_termination?
      !time_until_termination.nil?
    end

    def self.time_until_termination
      uri = URI('http://169.254.169.254/latest/meta-data/spot/termination-time')
      response = Net::HTTP.get_response(uri)
      return nil if response.code == "404"
      Time.parse(response.body) - Time.now
    rescue ArgumentError
      nil
    end
  end
end
