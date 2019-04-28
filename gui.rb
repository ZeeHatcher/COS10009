require './schedule.rb'
require 'fox16'
include Fox

class Main < FXMainWindow
  attr_reader :dateRef, :tasksCurrent

  def initialize(app)
    super(app, "_Routine", :width => 800, :height => 600)

    @dateRef = Time.new()
    check_existing_tasks
    check_date

    disp = DisplayTaskMenu.new(self)
  end

  def create
    super
    show(PLACEMENT_SCREEN)
  end

  def check_existing_tasks
    begin
      @tasksCurrent = load_file("test.dump")
    rescue
      @tasksCurrent = Tasks.new
      dump_file("test.dump", @tasksCurrent)
    end
  end

  def check_date
    dateFile = @tasksCurrent.date

    isSameDay = dateFile.year == @dateRef.year && dateFile.month == @dateRef.month && dateFile.day == @dateRef.day
    if (!isSameDay)
      @tasksCurrent = Tasks.new
      dump_file("test.dump", @tasksCurrent)
    end
  end
end

class UnlistedTasks
end

class Pie < FXCanvas
  def initialize(parent, tasks)
    super(parent, :opts => LAYOUT_FILL)
    @tasks = tasks

    self.connect(SEL_PAINT) do
      dc = FXDCWindow.new(self)
      dc.foreground = FXRGB(0,0,0)

      @tasks.each do |task|
        startPos = ((task.timeStart.hour * 60) + task.timeStart.min) * 32
        extent = task.timeDuration * 32

        if (task.timeStart.hour <= 12 && task.timeEnd.hour <= 12)
          dc.drawArc(0, 0, 250, 250, 5760-startPos, -extent)
        elsif (task.timeStart.hour >= 12 && task.timeEnd.hour >= 12)
          startPos -= 23040
          dc.drawArc(300, 0, 250, 250, 5760-startPos, -extent)
        else
          timeMid = Time.new(task.timeStart.year, task.timeStart.month, task.timeStart.day, 12, 0)
          extentPre = ((timeMid - task.timeStart) / 60) * 32
          extentPost = ((task.timeEnd - timeMid) / 60) * 32

          dc.drawArc(0, 0, 250, 250, 5760-startPos, -extentPre)
          dc.drawArc(300, 0, 250, 250, 5760, -extentPost)
        end
      end

      dc.end
    end
  end
end

class DisplayTaskMenu < FXHorizontalFrame
	def initialize(parent)
		super(parent, :opts => LAYOUT_FILL)
    @parent = parent

    @parent.tasksCurrent.tasks.each do |task|
      puts "Task: " + task.title
      puts "Description: " + task.desc
      puts "Start Time: " + task.timeStart.to_s
      puts "End Time: " + task.timeEnd.to_s
      puts "Duration: " + task.timeDuration.to_s
      puts ""
    end

    # Large vertical frame for title and pies
    vfrListed = FXVerticalFrame.new(self, :opts => LAYOUT_FILL)
    lbListedTitle = FXLabel.new(vfrListed, "Scheduled Tasks", :opts => LAYOUT_CENTER_X)

    hfrListedTasks = FXVerticalFrame.new(vfrListed, :opts => LAYOUT_FILL, :width => 100, :height => 100)

    test = Pie.new(hfrListedTasks, @parent.tasksCurrent.tasks)

    # Skinny vertical frame for unlisted tasks and button
    vfrUnlisted = FXVerticalFrame.new(self, :opts => LAYOUT_SIDE_RIGHT)
    lbUnlistedTitle = FXLabel.new(vfrUnlisted, "Unscheduled Tasks", :opts => LAYOUT_CENTER_X)

    vfrUnlistedTasks = FXVerticalFrame.new(vfrUnlisted, :opts => LAYOUT_FILL)

    btAddTask = FXButton.new(vfrUnlisted, "+")
    btAddTask.connect(SEL_COMMAND) do
      removeChild(self)
      AddTaskMenu.new(@parent).create
      @parent.recalc
    end
	end
end

class AddTaskMenu < FXVerticalFrame
	def initialize(parent)
		super(parent, :opts => LAYOUT_CENTER_X | LAYOUT_CENTER_Y)
    @parent = parent

		FXLabel.new(self, "Add New Task", :opts => LAYOUT_CENTER_X | LAYOUT_TOP)

		hfrInputZone = FXHorizontalFrame.new(self, :opts => LAYOUT_FILL)

		vfrLabels = FXVerticalFrame.new(hfrInputZone, :vSpacing => 8)
		FXLabel.new(vfrLabels, "Title: ")
		FXLabel.new(vfrLabels, "Description: ")
		FXLabel.new(vfrLabels, "Start Time: ")
		FXLabel.new(vfrLabels, "End Time: ")

		vfrInputs = FXVerticalFrame.new(hfrInputZone)
		@inTaskTitle = FXTextField.new(vfrInputs, 50, :opts => FRAME_LINE)
		@inTaskDesc = FXTextField.new(vfrInputs, 50, :opts => FRAME_LINE)

		hfrTaskStart = FXHorizontalFrame.new(vfrInputs)
		@inTaskStartH = FXTextField.new(hfrTaskStart, 2, :opts => TEXTFIELD_INTEGER | TEXTFIELD_LIMITED | FRAME_LINE)
		FXLabel.new(hfrTaskStart, ":")
		@inTaskStartM = FXTextField.new(hfrTaskStart, 2, :opts => TEXTFIELD_INTEGER | TEXTFIELD_LIMITED | FRAME_LINE)

		hfrTaskEnd = FXHorizontalFrame.new(vfrInputs)
		@inTaskEndH = FXTextField.new(hfrTaskEnd, 2, :opts => TEXTFIELD_INTEGER | TEXTFIELD_LIMITED | FRAME_LINE)
		FXLabel.new(hfrTaskEnd, ":")
		@inTaskEndM = FXTextField.new(hfrTaskEnd, 2, :opts => TEXTFIELD_INTEGER | TEXTFIELD_LIMITED | FRAME_LINE)

		hfrButtons = FXHorizontalFrame.new(self, :opts => LAYOUT_CENTER_X)
		btAdd = FXButton.new(hfrButtons, "Add Task")
		btAdd.connect(SEL_COMMAND) do
			valid = check_input

      if valid
        taskStart = taskEnd = nil

        isFilled = @inTaskStartH.text != "" && @inTaskStartM.text != "" && @inTaskEndH.text != "" && @inTaskEndM.text != ""
        if (isFilled)
          taskStart = generate_time(@inTaskStartH.text.to_i, @inTaskStartM.text.to_i)
          taskEnd = generate_time(@inTaskEndH.text.to_i, @inTaskEndM.text.to_i)
        end

        @parent.tasksCurrent.generate_task(@inTaskTitle.text, @inTaskDesc.text, taskStart, taskEnd)
        dump_file("test.dump", @parent.tasksCurrent)

        removeChild(self)
        DisplayTaskMenu.new(@parent).create
        @parent.recalc
      end
		end

		btCancel = FXButton.new(hfrButtons, "Cancel")
		btCancel.connect(SEL_COMMAND) do
      removeChild(self)
      DisplayTaskMenu.new(@parent).create
      @parent.recalc
		end
	end

	def check_input
		# Checks for an empty task title
		if (@inTaskTitle.text == "")
			return false
		end

		# Checks if task time is given, and if given, checks all inputs are given
    isEmpty = @inTaskStartH.text == "" && @inTaskStartM.text == "" && @inTaskEndH.text == "" && @inTaskEndM.text == ""
    isFilled = @inTaskStartH.text != "" && @inTaskStartM.text != "" && @inTaskEndH.text != "" && @inTaskEndM.text != ""

		if !(isEmpty || isFilled)
      return false
		end

    return true
	end

  def generate_time(h, m)
    dateRef = @parent.dateRef

    return Time.new(dateRef.year, dateRef.month, dateRef.day, h, m)
  end
end

if __FILE__ == $0
  FXApp.new do |app|
    Main.new(app)
    app.create
    app.run
  end
end
