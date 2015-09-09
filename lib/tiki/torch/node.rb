require 'socket'

module Tiki
  module Torch
    class Node < Consumer

      class << self

        attr_writer :node_host, :node_name, :node_topic_name

        def node_host
          Socket.gethostname
        end

        def node_topic_name
          @node_topic_name ||= random_node_name
        end

        def random_node_name(syllables = 4, sep = 4)
          consonants = %w{ b c d f g j k l m n p r s t z }
          vowels     = %w{ a e i o u }
          list       = syllables.times.map { consonants.sample + vowels.sample }.join.split('')
          list.each_slice(sep).map { |x| x.join }.join('-')
        end

        def responses
          @responses ||= Concurrent::Hash.new
        end

      end

      consumes node_topic_name, channel: 'node_events'

      def process
        parent_id = event.properties[:request_message_id]
        raise 'Missing request_message_id property' if parent_id.nil?

        self.class.responses[parent_id] = payload
      end

    end

    extend self

    def node
      Node
    end

    class RequestTimedOutError < RuntimeError

      attr_reader :timeout, :message_id, :topic_name, :payload, :properties

      def initialize(timeout, message_id, topic_name, payload, properties)
        @timeout    = timeout
        @message_id = message_id
        @topic_name = topic_name
        @payload    = payload
        @properties = properties
      end

    end

    def request(topic_name, payload = {}, properties = {})
      raise RuntimeError, 'The consumer broker is not polling' unless Tiki::Torch.consumer_broker.running?

      message_id = properties[:request_message_id] || SecureRandom.hex
      timeout    = properties.delete(:timeout) || 60

      properties[:request_message_id] ||= message_id
      properties[:respond_to]         = node.topic
      publisher.publish topic_name, payload, properties

      Concurrent::Future.execute do
        timeout_time = Time.now + timeout
        received     = false

        while Time.now < timeout_time
          if node.responses.key?(message_id)
            value    = node.responses.delete message_id
            received = true
            break
          end
          sleep 0.1
        end

        raise RequestTimedOutError.new(timeout, message_id, topic_name, payload, properties) unless received
        value
      end
    end

    node.responses

  end
end