require "pp"
require "mutual"

describe "Messaging" do

  before(:all) do
    @messaging = Mutual::Messaging.new("integration_test", { :host => "localhost", :port => 6380 })
    @redis = @messaging.create_redis_client
  end

  specify "#send_task" do
    @messaging.send_task(
      :type => "foo",
      :name => "bar",
      :body => {:arbitrary => :content}
    )

    task = @messaging.pop_queue("tasks.foo")
    task.keys.sort.should == [ :body, :name, :task_id ]
    task[:name].should == "bar"
    task[:body].should == {:arbitrary => "content"}
  end

  specify "send task and listen for result" do
    task_manager = @messaging.task_manager
    result_manager = @messaging.result_manager

    outgoing_task = task_manager.create(
      :type => "foo",
      :name => "bar",
      :body => {:arbitrary => :content},
      :response => true
    )

    # manually handle task and result
    Thread.new do
      # send a result for some other task
      @messaging.push_queue(
        @messaging.id,
        :task_id => "some other task",
        :body => {:result => true}
      )
      incoming_task = @messaging.pop_queue("tasks.foo")
      incoming_task[:return_address].should == @messaging.id
      @messaging.push_queue(
        @messaging.id,
        :task_id => incoming_task[:task_id],
        :body => {:result => true}
      )
    end

    task_manager.send(outgoing_task)

    result_manager.run

    incoming_result = nil
    result_manager.listen(outgoing_task) do |result|
      incoming_result = result
      result.keys.sort.should == [ :body, :task_id ]
      result[:task_id].should == outgoing_task.task_id
    end
    sleep 0.2
    raise "Did not receive a result" unless incoming_result

  end

  specify "messaging.send" do
    @messaging.result_manager.run

    incoming_result = nil
    @messaging.send_task(
      :type => "foo",
      :name => "bar",
      :body => {:arbitrary => :content},
      :response => true
    ) do |result|
      incoming_result = result
      result.keys.sort.should == [ :body, :task_id ]
    end


    # manually handle task and result
    Thread.new do
      # send a result for some other task
      @messaging.push_queue(
        @messaging.id,
        :task_id => "some other task",
        :body => {:result => true}
      )
      incoming_task = @messaging.pop_queue("tasks.foo")
      incoming_task[:return_address].should == @messaging.id
      @messaging.push_queue(
        @messaging.id,
        :task_id => incoming_task[:task_id],
        :body => {:result => true}
      )
    end

    sleep 0.2
    raise "Did not receive a result" unless incoming_result

  end


  specify "timeouts" do
    task_manager = @messaging.task_manager
    result_manager = @messaging.result_manager

    outgoing_task = task_manager.create(
      :type => "foo",
      :name => "bazbat",
      :body => {:arbitrary => :content},
      :response => true
    )
    task_manager.send(outgoing_task)

    incoming_result = nil
    result_manager.listen(outgoing_task, :timeout => 2) do |result|
      incoming_result = result
      result.keys.sort.should == [:timeout]
    end
    sleep 3
    raise "Did not receive a result" unless incoming_result
    result_manager.tasks.should be_empty
  end



end

