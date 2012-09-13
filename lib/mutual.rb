require "rubygems"
gem "redis", ">= 3.0.1"
gem "json"
require "redis"
require "json"

require "incrementable"
require "messaging/task_manager"
require "messaging/result_manager"

Thread.abort_on_exception = true
module Mutual

  class Messaging
    # we need both class and instance counters
    extend Incrementable
    include Incrementable

    attr_reader :configuration, :id, :result_manager, :task_manager

    def initialize(process_name, configuration)
      @process_name = process_name
      @configuration = configuration
      @id = "#{@process_name}-#{self.class.increment!}"

      @pop_timeout = 8
      @task_manager = TaskManager.new(self)
      @result_manager = ResultManager.new(self)
      @client = create_redis_client
      @clients = {}

    end

    def generate_id
      "#{@id}-#{increment!}"
    end

    def create_redis_client
      Redis.new(:host => @configuration[:host], :port => @configuration[:port])
    end

    def send_task(options, &block)
      task = @task_manager.create(options)
      if block
        @result_manager.listen(task, &block)
      end
      @task_manager.send(task)
    end

    def multi_task(*args)
      raise "unimplemented"
    end

    def send_result(*args)
      raise "unimplemented"
    end

    def push_queue(queue, object)
      message = object.to_json
      @client.lpush(queue, message)
    end

    # WARNING: blocking call.
    def pop_queue(queue)
      @clients[queue] ||= create_redis_client
      if result = @clients[queue].brpop(queue, :timeout => @pop_timeout)
        _channel, message = result
        JSON.parse(message, :symbolize_names => true)
      end
    end


  end


end
