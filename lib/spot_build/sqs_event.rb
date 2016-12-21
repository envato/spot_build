require 'aws-sdk'
require 'timeout'

module SpotBuild
  class SqsEvent
    def initialize(url:, timeout:, region: ENV['AWS_REGION'])
      @queue = Aws::SQS::Queue.new(url: url, region: region)
      @timeout = timeout
    end

    def shutdown_if_required(&block)
      # Any message to this queue is treated as a "I should shutdown"
      message = @queue.receive_messages(
        attribute_names: ["All"],
        max_number_of_messages: 1,
        visibility_timeout: (@timeout - 5),
      ).first
      return false if message.nil?
      yield
      message.delete
      true
    end
  end
end
