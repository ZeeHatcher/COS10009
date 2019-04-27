class Task
  attr_accessor :title, :desc, :timeStart, :timeEnd, :isScheduled

  def initialize(title, desc, timeStart, timeEnd)
    @title = title
    @desc = desc
    @timeStart = timeStart
    @timeEnd = timeEnd
    @isScheduled = false

    if (@timeStart != nil && @timeEnd != nil)
      @isScheduled = true
    end
  end
end

class Template
  def initialize(name, tasks)
    @name = name
    @tasks = tasks
  end
end

def generate_new_task
  repeat = true

  begin
    print "Enter a task name: "
    title = gets.chomp

    if (title != "")
      repeat = false
    end
  end while repeat

  print "Enter task description: "
  desc = gets.chomp

  print "Enter start time: "
  timeStart = gets.chomp

  print "Enter end time: "
  timeEnd = gets.chomp

  task = Task.new(title, desc, timeStart, timeEnd)
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
