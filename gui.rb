require './schedule.rb'
require 'fox16'
include Fox

class Main < FXMainWindow
  attr_reader :dateRef, :tasksCurrent

  def initialize(app)
    super(app, "_Routine", :width => 1024, :height => 768)
    @@font = FXFont.new(app, "segoe ui", 9)
    @@font.create


    @dateRef = Time.new()
    check_existing_tasks
    check_date

    disp = DisplayTaskMenu.new(self)
  end

  def self.font
    @@font
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



class DisplayTaskMenu < FXHorizontalFrame
	def initialize(parent)
		super(parent, :opts => LAYOUT_FILL)
    @parent = parent
    @tasks = @parent.tasksCurrent.tasks

    @tasks.each do |task|
      puts "Task: " + task.title
      puts "Description: " + task.desc
      puts "Start Time: " + task.timeStart.to_s
      puts "End Time: " + task.timeEnd.to_s
      puts "Duration: " + task.timeDuration.to_s
      puts ""
    end

    # Large vertical frame for title and pies
    vfrScheduled = FXVerticalFrame.new(self, :opts => LAYOUT_FILL)
    lbScheduledTitle = FXLabel.new(vfrScheduled, "Scheduled Tasks", :opts => LAYOUT_CENTER_X)

    if (@tasks.length > 0)
      Pie.new(vfrScheduled, @parent.tasksCurrent.tasks)
    end

    # Skinny vertical frame for unlisted tasks and button
    vfrList = FXVerticalFrame.new(self, :opts => LAYOUT_SIDE_RIGHT)
    lbListTitle = FXLabel.new(vfrList, "Unscheduled Tasks", :opts => LAYOUT_CENTER_X)

    scrArea = FXScrollArea.new(vfrList, :width => 100, :height => self.height)
    vfrTasks = FXVerticalFrame.new(scrArea, :opts => LAYOUT_FILL | FRAME_LINE)

    @tasks.each do |task|
      DisplayTask.new(vfrTasks, task)
    end

    btAddTask = FXButton.new(vfrList, "+")
    btAddTask.connect(SEL_COMMAND) do
      removeChild(self)
      AddTaskMenu.new(@parent).create
      @parent.recalc
    end
	end
end



class DisplayTask < FXVerticalFrame
  def initialize(parent, task)
    super(parent, :opts => LAYOUT_FILL_X | FRAME_THICK)
    @task = task

    lbTitle = FXLabel.new(self, @task.title)
    lbDesc = FXLabel.new(self, @task.desc)

    timeStart = format_time(@task.timeStart)
    timeEnd = format_time(@task.timeEnd)
    timeRange = timeStart + " - " + timeEnd

    lbTime = FXLabel.new(self, timeRange)
  end

  def format_time(time)
    timeString = time.hour.to_s + ":" + time.min.to_s

    timeHour = (time.hour.to_s.length == 1) ? "0" + time.hour.to_s : time.hour.to_s
    timeMinute = (time.min.to_s.length == 1) ? "0" + time.min.to_s : time.min.to_s

    timeStr = timeHour + ":" + timeMinute

    return timeStr
  end
end



class Pie < FXCanvas
  def initialize(parent, tasks)
    super(parent, :opts => LAYOUT_FILL)
    @parent = parent

    @tasks = []
    tasks.each do |task|
      if (task.isScheduled)
        @tasks.push(task)
      end
    end

    @listIndexOverlap = calc_overlap
    @dia = 500

    self.connect(SEL_PAINT) do
      dc = FXDCWindow.new(self)

      # Color background
      dc.foreground = @parent.backColor
      dc.fillRectangle(0, 0, self.width, self.height)

      dc.foreground = FXRGB(0, 0, 0)
      diaRing = @dia + 15
      dc.drawArc((self.width / 2) - (diaRing / 2), (self.height / 2) - (diaRing / 2), diaRing, diaRing, 0, 23040)

      for targetIndex in 0..(@listIndexOverlap).max
        for i in 0..@tasks.length - 1
          if (@listIndexOverlap[i] == targetIndex)
            task = @tasks[i]
            draw_arc(dc, task.timeStart, task.timeEnd, @listIndexOverlap[i])
          end
        end
      end

      dc.font = Main.font
      draw_hours(dc)

      dc.end
    end
  end

  def calc_overlap
    listIndexOverlap = []

    @tasks.each do |targetTask|
      if (targetTask.isScheduled)
        indexOverlap = 0

        for i in 0..@tasks.index(targetTask)
          refTask = @tasks[i]

          if (refTask != targetTask)
            if ((targetTask.timeStart >= refTask.timeStart && targetTask.timeStart < refTask.timeEnd) || (targetTask.timeEnd >= refTask.timeStart && targetTask.timeEnd < refTask.timeEnd)) && indexOverlap == listIndexOverlap[i]
              indexOverlap += 1
            end
          end
        end

        listIndexOverlap.push(indexOverlap)
      end
    end

    return listIndexOverlap
  end

  def draw_arc(dc, timeStart, timeEnd, indexOverlap)
    weight = 10
    diameter = @dia - (weight * indexOverlap * 2)
    x = (self.width / 2) - (diameter / 2)
    y = (self.height / 2) - (diameter / 2)
    start = ((timeStart.hour * 60) + timeStart.min) * 16
    extent = ((timeEnd - timeStart) / 60) * 16

    dc.foreground = FXRGB(rand(210), rand(210), rand(210))
    dc.fillArc(x, y, diameter, diameter, 5760 - start, -extent)

    dc.foreground = @parent.backColor
    dc.fillArc(x + weight, y + weight, diameter - (weight * 2), diameter - (weight * 2), 0, 23040)
  end

  def draw_hours(dc)
    centerX = self.width / 2
    centerY = self.height / 2

    hour = 1
    angle = -75
    angleEnd = angle + 360
    radius = @dia / 2 + 20

    dc.foreground = FXRGB(0, 0, 0)

    while (angle < angleEnd)
      radians = angle * Math::PI / 180

      offsetX = Math.cos(radians) * radius
      offsetY = Math.sin(radians) * radius

      dc.drawText(centerX + offsetX - 4, centerY + offsetY + (dc.font.fontHeight / 2), hour.to_s)

      hour += 1
      angle += 15
    end

    angle = -82.5
    angleEnd = angle + 360

    while (angle < angleEnd)
      radians = angle * Math::PI / 180

      offsetX = Math.cos(radians) * radius
      offsetY = Math.sin(radians) * radius

      dc.fillArc(centerX + offsetX, centerY + offsetY, 5, 5, 0, 23040)

      angle += 15
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
