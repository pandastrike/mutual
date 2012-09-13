module Mutual
  class Messaging

    class ResultManager

      attr_reader :tasks
      def initialize(messaging, configuration={})
        @messaging = messaging
        @timeout = configuration[:timeout] || 8 # seconds

        # will be used as a blocking client
        @client = @messaging.create_redis_client
        @timeouts = []
        @tasks = {}
      end

      # BLOCKING!
      def wait
        @messaging.pop_queue(@messaging.id)
      end

      def listen(task, options={}, &block)
        now = Time.now
        ttl = options[:timeout] || 8
        expire = (now + ttl).to_i
        @timeouts << [expire, task.task_id]
        @tasks[task.task_id] = block
      end

      def match(result)
        @tasks.delete(result[:task_id])
      end

      def handle_timeouts
        now = Time.now.to_i
        while @timeouts[0] && @timeouts[0][0] > now
          expire, task_id = @timeouts.shift
          if listener = @tasks.delete(task_id)
            listener.call :timeout => true
          end
        end
      end

      def run
        Thread.new do
          thread = Thread.current
          thread[:run] = true
          while thread[:run]
            sleep 0.5
            handle_timeouts
          end
        end
        read do |result|
          if listener = match(result)
            listener.call(result)
          else
            #print "\ngot result no one was expecting: #{result.inspect}"
          end
        end
      end

      def read(&block)
        @thread = Thread.new do
          thread = Thread.current
          thread[:run] = true
          while thread[:run]
            if result = @messaging.pop_queue(@messaging.id)
              yield(result)
            end
          end
        end
      end

    end

  end
end

