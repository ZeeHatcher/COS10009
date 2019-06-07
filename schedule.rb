FILE_CURRENT_TASKS = "current_tasks.dump"
FILE_TEMPLATES = "templates.dump"

# Stores the date of creation and a list of tasks
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



# Stores the information about the task
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



# Stores a list of templates and templates associated with each day
class Templates
  attr_accessor :routine, :templates

  def initialize
    @routine = {"1" => nil, "2" => nil, "3" => nil, "4" => nil, "5" => nil, "6" => nil, "7" => nil}
    @templates = []
  end

  def generate_template(name, tasks)
    template = Template.new(name, tasks)

    @templates.push(template)
  end
end



# Stores the name of the template and the list of tasks associated with this template
class Template
  attr_accessor :name, :tasks

  def initialize(name, tasks)
    @name = name
    @tasks = tasks
  end
end



# Serializes and stores the data in a text file
def dump_file(file, content)
  data = Marshal.dump(content)

  File.open(file, "w") do |f|
    f.write(data)
  end
end

# Reads the file and deserializes the data from the text file
def load_file(file)
  File.open(file, "r") do |f|
    data = f.read()
    content = Marshal.load(data)
  end
end
