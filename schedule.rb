class Tasks
  attr_accessor :date, :tasks

  def initialize
    @date = Time.new
    @tasks = []
  end

  def generate_task(title, desc, timeStart, timeEnd)
    taskNew = Task.new(title, desc, timeStart, timeEnd)

    @tasks.push(taskNew)
  end
end

class Task
  attr_accessor :title, :desc, :timeStart, :timeEnd, :timeDuration, :isScheduled

  def initialize(title, desc, timeStart, timeEnd)
    @title = title
    @desc = desc
    @timeStart = timeStart
    @timeEnd = timeEnd
    @isScheduled = false

    if (@timeStart != nil && @timeEnd != nil)
      @isScheduled = true
      @timeDuration = (timeEnd - timeStart) / 60
    end
  end
end

class Template
  def initialize(name, tasks)
    @name = name
    @tasks = tasks
  end
end

def dump_file(file, content)
  data = Marshal.dump(content)

  File.open(file, "w") do |f|
    f.write(data)
  end
end

def load_file(file)
  File.open(file, "r") do |f|
    data = f.read()
    content = Marshal.load(data)
  end
end
