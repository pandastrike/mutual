module Mutual

  module Incrementable
    def increment!
      @incrementable_counter ||= 0
      @incrementable_counter += 1
    end
  end

end
