require './schedule.rb'
require 'fox16'
include Fox

class Main < FXMainWindow
  def initialize(app)
    super(app, "_Routine", :width => 800, :height => 600)

    # Main horizontal frame
    hfrMain = FXHorizontalFrame.new(self, :opts => LAYOUT_FILL)

    # Large vertical frame for title and pies
    vfrListed = FXVerticalFrame.new(hfrMain, :opts => LAYOUT_FILL)
    lbListedTitle = FXLabel.new(vfrListed, "Scheduled Tasks", :opts => LAYOUT_CENTER_X)

    hfrListedTasks = FXVerticalFrame.new(vfrListed, :opts => LAYOUT_FILL)

    # Skinny vertical frame for unlisted tasks and button
    vfrUnlisted = FXVerticalFrame.new(hfrMain, :opts => LAYOUT_SIDE_RIGHT)
    lbUnlistedTitle = FXLabel.new(vfrUnlisted, "Unscheduled Tasks", :opts => LAYOUT_CENTER_X)

    vfrUnlistedTasks = FXVerticalFrame.new(vfrUnlisted, :opts => LAYOUT_FILL)

    btAddTask = FXButton.new(vfrUnlisted, "+")

    btAddTask.connect(SEL_COMMAND) do
      task = generate_new_task
    end

  end

  def create
    super
    show(PLACEMENT_SCREEN)
  end
end

class UnlistedTasks
end

class Pie
end

class AddTask
end

if __FILE__ == $0
  FXApp.new do |app|
    Main.new(app)
    app.create
    app.run
  end
end
