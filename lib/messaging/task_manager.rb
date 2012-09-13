module Mutual
  class Messaging
    class TaskManager

      def initialize(messaging)
        @messaging = messaging
        @client = @messaging.create_redis_client
      end


      def create(options)
        options[:task_id] = @messaging.generate_id
        if options.delete(:response)
          options[:return_address] = @messaging.id
        end
        Task.new(options)
      end

      def send(task)
        @messaging.push_queue(task.queue, task)
      end

    end

    class Task
      attr_reader :queue, :task_id, :return_address
      def initialize(options)
        properties = options.values_at(:task_id, :type, :name, :body)
        raise ArgumentError unless properties.all? {|p| p != nil }
        @task_id, @type, @name, @body = properties
        @return_address = options[:return_address]
        @queue = "tasks.#{@type}"
      end

      def marshal
        hash = {
          :task_id => @task_id,
          :name => @name,
          :body => @body
        }
        hash[:return_address] = @return_address if @return_address
        hash
      end

      def to_json(*args)
        marshal.to_json(*args)
      end

    end

  end
end
