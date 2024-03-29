require './schedule.rb'
require 'fox16'
include Fox

# Window in which the GUI is displayed in
class Main < FXMainWindow
  attr_accessor :dateToday, :objTasksCurrent, :templates

  def initialize(app)
    super(app, "_Routine", :width => 1024, :height => 768)
    @@font = FXFont.new(app, "segoe ui", 9) # Font used in the text
    @@font.create

    @dateToday = Time.new()
    check_existing_tasks
    check_existing_templates
    check_date

    MenuBar.new(self)
    TasksDisplayMain.new(self, @objTasksCurrent)
  end

  def self.font
    @@font
  end

  def create
    super
    show(PLACEMENT_SCREEN)
  end

  # Checks for an existing current_tasks.dump, and creates a new one if it does not exist
  def check_existing_tasks
    begin
      @objTasksCurrent = load_file(FILE_CURRENT_TASKS)
    rescue
      @objTasksCurrent = Tasks.new
      dump_file(FILE_CURRENT_TASKS, @objTasksCurrent)
    end
  end

  # Checks for an existing templates.dump, and creates a new one if it does not exist
  def check_existing_templates
    begin
      @templates = load_file(FILE_TEMPLATES)
    rescue
      @templates = Templates.new
      dump_file(FILE_TEMPLATES, @templates)
    end
  end

  # Checks the date within current_tasks.dump, and resets the file if it is different to today's date
  def check_date
    dateFile = @objTasksCurrent.date

    isSameDay = dateFile.year == @dateToday.year && dateFile.month == @dateToday.month && dateFile.day == @dateToday.day
    if (!isSameDay)
      if (@templates.routine[@dateToday.wday.to_s] == nil) # Checks if there is a templte associated with the day
        @objTasksCurrent = Tasks.new
      else
        @objTasksCurrent = @templates.routine[@dateToday.wday.to_s].tasks
        @objTasksCurrent.date = Time.new
      end

      dump_file(FILE_CURRENT_TASKS, @objTasksCurrent)
    end
  end

  # A method to update current_tasks.dump during program runtime
  def update_tasks(newTasks)
    @objTasksCurrent = newTasks

    dump_file(FILE_CURRENT_TASKS, @objTasksCurrent)
  end
end



# Menubar that contains various commands
class MenuBar < FXMenuBar
  attr_accessor :parent

  def initialize(parent)
    super(parent, :opts => LAYOUT_FILL_X | FRAME_RAISED)
    @parent = parent

    menuFilesPane = FXMenuPane.new(self)
    menuFilesTitle = FXMenuTitle.new(self, "Files", :popupMenu => menuFilesPane)

    menuFilesClear = FXMenuCommand.new(menuFilesPane, "Clear current tasks")
    menuFilesClear.connect(SEL_COMMAND) do
      # Replaces current_tasks.dump with a new Tasks instance
      @parent.update_tasks(Tasks.new)

      gui_recalc(@parent.objTasksCurrent)
    end

    menuTemplatesPane = FXMenuPane.new(self)
    menuTemplatesTitle = FXMenuTitle.new(self, "Templates", :popupMenu => menuTemplatesPane)

    listTemplates = TemplatesList.new(self, @parent.templates.templates)
    listRoutine = RoutineList.new(self, @parent.templates)

    menuTemplatesUse = FXMenuCommand.new(menuTemplatesPane, "Use template for today")
    menuTemplatesUse.connect(SEL_COMMAND) do
      i = listTemplates.execute

      # Replaces current_tasks.dump with the tasks within the selected template
      if (i >= 0 && i < @parent.templates.templates.length)
        chosenTasks = @parent.templates.templates[i].tasks
        chosenTasks.date = Time.new
        @parent.update_tasks(chosenTasks)

        gui_recalc(chosenTasks)
      end
    end

    menuTemplatesRoutine = FXMenuCommand.new(menuTemplatesPane, "Set routine templates")
    menuTemplatesRoutine.connect(SEL_COMMAND) do
      listRoutine.execute
    end

    menuTemplatesDelete = FXMenuCommand.new(menuTemplatesPane, "Delete templates")
    menuTemplatesDelete.connect(SEL_COMMAND) do
      i = listTemplates.execute

      # Deletes the selected task and updates the current_tasks.dump
      if (i >= 0 && i < @parent.templates.templates.length)
        @parent.templates.templates.delete_at(i)
        dump_file(FILE_TEMPLATES, @parent.templates)

        gui_recalc(@parent.objTasksCurrent)
      end
    end
  end

  # Redraws the GUI with the updated list of tasks
  def gui_recalc(objTasks)
    @parent.children.each do |child|
      @parent.removeChild(child)
    end

    MenuBar.new(@parent).create
    TasksDisplayMain.new(@parent, objTasks).create
    @parent.recalc
  end
end



# A seperate window for choosing a template, which will be returned to the caller
class TemplatesList < FXChoiceBox
  def initialize(parent, arrTemplates)
    templateNames = []
    for i in 0..arrTemplates.length-1
      templateNames << arrTemplates[i].name
    end

    super(parent, "Choose template", "", nil, templateNames)
  end
end



# A window containing listboxes for choosing templates for specific days
class RoutineList < FXDialogBox
  def initialize(parent, objTemplates)
    super(parent, "Set Routine", :width => 300, :height => 300)
    @parent = parent
    weekdays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

    templateNames = ["None"]
    objTemplates.templates.each do |template|
      templateNames << template.name
    end

    hfrInputZone = FXVerticalFrame.new(self, :opts => LAYOUT_FILL)

    listboxes = []
    # Creating the listboxes
    weekdays.each do |day|
      vfrRow = FXHorizontalFrame.new(hfrInputZone, :opts => LAYOUT_FILL_X)
      FXLabel.new(vfrRow, day + ": ", :opts => LAYOUT_FIX_WIDTH | JUSTIFY_RIGHT, :width => 100)

      listbox = FXListBox.new(vfrRow, :opts => LAYOUT_FILL_X | FRAME_LINE)
      listbox.numVisible = 5
      listbox.fillItems(templateNames)
      listboxes << listbox
    end

    # Assigns the template to the routine hash in Templates in the templates.dump
    btnApply = FXButton.new(hfrInputZone, "Apply templates", :opts => LAYOUT_CENTER_X | FRAME_LINE)
    btnApply.connect(SEL_COMMAND) do |sender, selector, data|
      for i in 0..listboxes.length-1
        if (listboxes[i].currentItem > 0)
          templateIndex = listboxes[i].currentItem - 1
          objTemplates.routine[(i+1).to_s] = objTemplates.templates[templateIndex]
        else
          objTemplates.routine[(i+1).to_s] = nil
        end
      end

      dump_file(FILE_TEMPLATES, objTemplates)

      puts "RUNNING"
      getApp().stopModal(self)
      self.hide
    end
  end
end



# Displays the tasks in donut form and in a list
class TasksDisplay < FXHorizontalFrame
  def initialize(parent, objTasks)
    super(parent, :opts => LAYOUT_FILL)
    @parent = parent
    @objTasks = objTasks

    # Large vertical frame pies
    @vfrScheduled = FXVerticalFrame.new(self, :opts => LAYOUT_FILL)
    TaskPie.new(@vfrScheduled, @objTasks.tasks)

    # Skinny vertical frame for listing tasks and buttons
    @vfrList = FXVerticalFrame.new(self, :opts => LAYOUT_FIX_HEIGHT | LAYOUT_FIX_WIDTH, :width => 300, :height => @parent.height - 50)

    hfrScrollWindowBorder = FXHorizontalFrame.new(@vfrList, :opts => LAYOUT_FILL | FRAME_LINE)
    scrWindow = FXScrollWindow.new(hfrScrollWindowBorder, :opts => LAYOUT_FILL)
    vfrTasks = FXVerticalFrame.new(scrWindow, :opts => LAYOUT_FILL)

    @objTasks.tasks.each do |task|
      TaskBlock.new(vfrTasks, task, self)
    end
  end
end



# Main task display menu, displaying tasks from the current_tasks.dump
class TasksDisplayMain < TasksDisplay
  def initialize(parent, objTasks)
    super(parent, objTasks)
    @parent = parent
    @objTasks = objTasks

    btnAddTask = FXButton.new(@vfrList, "Add New Task", :opts => LAYOUT_CENTER_X | FRAME_RAISED)
    btnAddTask.connect(SEL_COMMAND) do
      @parent.removeChild(self)
      TaskCreateMenu.new(@parent, @objTasks, TasksDisplayMain, true).create
      @parent.recalc
    end

    btnAddTemplate = FXButton.new(@vfrList, "Add New Template", :opts => LAYOUT_CENTER_X | FRAME_RAISED)
    btnAddTemplate.connect(SEL_COMMAND) do
      @parent.children.each do |child|
        @parent.removeChild(child)
      end

      newTemplateTasks = Tasks.new()
      MenuBar.new(@parent).create
      TasksDisplayTemplate.new(@parent, newTemplateTasks).create
      @parent.recalc
    end
  end
end



# Display menu for new template creation
class TasksDisplayTemplate < TasksDisplay
  def initialize(parent, objTasks)
    super(parent, objTasks)
    @parent = parent
    @objTasks = objTasks

    btnAddTask = FXButton.new(@vfrList, "Add New Task", :opts => LAYOUT_CENTER_X | FRAME_RAISED)
    btnAddTask.connect(SEL_COMMAND) do
      @parent.removeChild(self)
      TaskCreateMenu.new(@parent, @objTasks, TasksDisplayTemplate, false).create
      @parent.recalc
    end

    lbTemplateName = FXLabel.new(@vfrScheduled, "Template Name:", :opts => LAYOUT_CENTER_X)
    @inTemplateName = FXTextField.new(@vfrScheduled, 25, :opts => LAYOUT_CENTER_X | FRAME_LINE)

    btnAddTemplate = FXButton.new(@vfrScheduled, "Add Template", :opts => LAYOUT_CENTER_X | FRAME_LINE)
    btnAddTemplate.connect(SEL_COMMAND) do
      if (@inTemplateName.text != "")
        @parent.templates.generate_template(@inTemplateName.text, @objTasks)
        dump_file(FILE_TEMPLATES, @parent.templates)

        to_TasksDisplayMain
      end
    end

    btnCancel = FXButton.new(@vfrScheduled, "Cancel", :opts => LAYOUT_CENTER_X | FRAME_LINE)
    btnCancel.connect(SEL_COMMAND) do
      to_TasksDisplayMain
    end
  end

  # Return to the main task display menu
  def to_TasksDisplayMain
    @parent.children.each do |child|
      @parent.removeChild(child)
    end

    current_tasks = load_file(FILE_CURRENT_TASKS)
    MenuBar.new(@parent).create
    TasksDisplayMain.new(@parent, current_tasks).create
    @parent.recalc
  end
end



# Formatting task information to be displayed in the display menus
class TaskBlock < FXVerticalFrame
  def initialize(parent, task, owner)
    super(parent, :opts => LAYOUT_FILL_X | FRAME_THICK)
    @task = task
    @main = owner.parent

    hfrTitle = FXHorizontalFrame.new(self, :opts => LAYOUT_FILL_X)
    btnDelete = FXButton.new(hfrTitle, "DEL")
    btnDelete.connect(SEL_COMMAND) do
      tasksCurrent =  @main.objTasksCurrent
      tasksCurrent.tasks.delete(@task)

      @main.update_tasks(tasksCurrent)

      @main.children.each do |child|
        @main.removeChild(child)
      end

      MenuBar.new(@main).create
      TasksDisplayMain.new(@main, tasksCurrent).create
      @main.recalc
    end

    lbTitle = FXLabel.new(hfrTitle, @task.title)

    lbDesc = FXLabel.new(self, @task.desc)

    if (@task.isScheduled)
      timeStart = format_time(@task.timeStart)
      timeEnd = format_time(@task.timeEnd)
      timeRange = timeStart + " - " + timeEnd
    else
      timeRange = "--:-- - --:--"
    end

    lbTime = FXLabel.new(self, timeRange)
  end

  # Formats the time into a readable format
  def format_time(time)
    timeString = time.hour.to_s + ":" + time.min.to_s

    timeHour = (time.hour.to_s.length == 1) ? "0" + time.hour.to_s : time.hour.to_s
    timeMinute = (time.min.to_s.length == 1) ? "0" + time.min.to_s : time.min.to_s

    timeStr = timeHour + ":" + timeMinute

    return timeStr
  end
end



# Donut chart for displaying tasks
class TaskPie < FXCanvas
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

      dc.foreground = @parent.backColor
      dc.fillRectangle(0, 0, self.width, self.height)

      dc.foreground = FXRGB(0, 0, 0)
      diaRing = @dia + 15
      dc.drawArc((self.width / 2) - (diaRing / 2), (self.height / 2) - (diaRing / 2), diaRing, diaRing, 0, 23040)

      # Draws the arc based on the overlap index of the task
      if @tasks.length > 0
        for targetIndex in 0..(@listIndexOverlap).max
          for i in 0..@tasks.length - 1
            if (@listIndexOverlap[i] == targetIndex)
              task = @tasks[i]
              draw_arc(dc, task.timeStart, task.timeEnd, @listIndexOverlap[i])
            end
          end
        end
      end

      dc.font = Main.font
      draw_hours(dc)

      dc.end
    end
  end

  # Loops through all the tasks to calculate the overlap index of the tasks
  def calc_overlap
    @listIndexOverlap = Array.new(@tasks.length, 0)

    for iTarget in 0..@tasks.length-1
      targetTask = @tasks[iTarget]

      if (targetTask.isScheduled)
        check_overlap(iTarget)
      end
    end

    return @listIndexOverlap
  end

  # Logic to calculate the "overlap-ness" of the tasks
  def check_overlap(iTarget)
    targetTask = @tasks[iTarget]

    for iRef in 0..@tasks.length-1
      refTask = @tasks[iRef]

      if (refTask != targetTask && refTask.isScheduled)
        # If the task overlaps with other tasks on the same index, index + 1 and then run the function again until it does not overlap
        if (((targetTask.timeStart >= refTask.timeStart && targetTask.timeStart <= refTask.timeEnd) || (targetTask.timeEnd >= refTask.timeStart && targetTask.timeEnd <= refTask.timeEnd) || (targetTask.timeStart <= refTask.timeStart && targetTask.timeEnd >= refTask.timeEnd)) && (@listIndexOverlap[iTarget] == @listIndexOverlap[iRef]))
          @listIndexOverlap[iTarget] += 1

          check_overlap(iTarget)
        end
      end
    end
  end

  # Draws the arc based on the start time, end time and overlap index of the task
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

  # Draws the clock hour
  def draw_hours(dc)
    centerX = self.width / 2
    centerY = self.height / 2

    hour = 1
    angle = -75
    angleEnd = angle + 360
    radius = @dia / 2 + 20

    dc.foreground = FXRGB(0, 0, 0)

    # Draws the hour numbers
    while (angle < angleEnd)
      radians = angle * Math::PI / 180

      offsetX = Math.cos(radians) * radius
      offsetY = Math.sin(radians) * radius

      dc.drawText(centerX + offsetX - 4, centerY + offsetY + (dc.font.fontHeight / 2), hour.to_s)

      hour += 1
      angle += 15
    end

    # Draws the 30 minute mark
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



# Displays text fields to enter information about the new task
class TaskCreateMenu < FXVerticalFrame
	def initialize(parent, objTasks, tasksDisplay, isSave)
		super(parent, :opts => LAYOUT_CENTER_X | LAYOUT_CENTER_Y)
    @parent = parent
    @objTasks = objTasks
    @tasksDisplay = tasksDisplay
    @isSave = isSave

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

      # Formats the time inputs and creates a new task then saves it
      if valid
        taskStart = taskEnd = nil

        isFilled = @inTaskStartH.text != "" && @inTaskStartM.text != "" && @inTaskEndH.text != "" && @inTaskEndM.text != ""
        if (isFilled)
          taskStart = generate_time(@inTaskStartH.text.to_i, @inTaskStartM.text.to_i)
          taskEnd = generate_time(@inTaskEndH.text.to_i, @inTaskEndM.text.to_i)
        end

        @objTasks.generate_task(@inTaskTitle.text, @inTaskDesc.text, taskStart, taskEnd)

        if (@isSave)
          dump_file(FILE_CURRENT_TASKS, @objTasks)
        end

        removeChild(self)
        @tasksDisplay.new(@parent, @objTasks).create
        @parent.recalc
      end
		end

		btCancel = FXButton.new(hfrButtons, "Cancel")
		btCancel.connect(SEL_COMMAND) do
      removeChild(self)
      @tasksDisplay.new(@parent, @objTasks).create
      @parent.recalc
		end
	end

  # Validation of the text fields
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

    # Checks if a valid number is given for the hours and minutes
    invalidHours = @inTaskStartH.text.to_i < 0 || @inTaskStartH.text.to_i > 24 || @inTaskEndH.text.to_i < 0 || @inTaskEndH.text.to_i > 24
    invalidMinutes = @inTaskStartM.text.to_i < 0 || @inTaskStartM.text.to_i > 59 || @inTaskEndM.text.to_i < 0 || @inTaskEndM.text.to_i > 59
    if (isFilled)
      if (invalidHours || invalidMinutes)
        return false
      end
    end

    taskStart = generate_time(@inTaskStartH.text.to_i, @inTaskStartM.text.to_i)
    taskEnd = generate_time(@inTaskEndH.text.to_i, @inTaskEndM.text.to_i)
    if (taskStart > taskEnd)
      return false
    end

    return true
	end

  def generate_time(h, m)
    dateToday = @parent.dateToday

    return Time.new(dateToday.year, dateToday.month, dateToday.day, h, m)
  end
end



if __FILE__ == $0
  FXApp.new do |app|
    Main.new(app)
    app.create
    app.run
  end
end
