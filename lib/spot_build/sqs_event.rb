require 'aws-sdk'
require 'timeout'

module SpotBuild
  class SqsEvent
    def initialize(queue_url, timeout)
      @queue = Aws::SQS::Queue.new(url: queue_url)
      @timeout = timeout
    end

    def poll(&block)
      # Any message to this queue is treated as a "I should shutdown"
      message = @queue.receive_message(
        attribute_names: ["All"],
        max_number_of_messages: 1,
        visibility_timeout: (@timeout - 5),
      ).first
      return if message.nil?
      yield
      message.delete
    end
  end
end
