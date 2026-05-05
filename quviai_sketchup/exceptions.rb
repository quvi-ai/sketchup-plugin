module QUVIAI
  class QuviError < StandardError; end

  class AuthError < QuviError
    attr_reader :status_code
    def initialize(msg = "Authentication failed", status_code: nil)
      super(msg)
      @status_code = status_code
    end
  end

  class LoginError < AuthError; end

  class TaskFailedError < QuviError
    attr_reader :task_id
    def initialize(msg = "Task failed", task_id: nil)
      super(msg)
      @task_id = task_id
    end
  end

  class TaskTimeoutError < QuviError
    attr_reader :task_id, :timeout
    def initialize(task_id: nil, timeout: nil)
      super("Task #{task_id} timed out after #{timeout}s")
      @task_id = task_id
      @timeout = timeout
    end
  end

  class TaskNotFoundError < QuviError
    attr_reader :task_id
    def initialize(task_id: nil)
      super("Task #{task_id} not found (404)")
      @task_id = task_id
    end
  end
end
