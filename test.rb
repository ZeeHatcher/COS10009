#!/usr/bin/env ruby

require 'fox16'

include Fox

class Test < FXMainWindow
   def initialize(app)
     super(app, "Test", nil, nil, DECOR_ALL, 0, 0, 640, 480, 0, 0)


    body =
FXVerticalFrame.new(self,LAYOUT_SIDE_TOP|FRAME_RAISED|LAYOUT_FILL_X|LAYOUT_FILL_Y|PACK_UNIFORM_WIDTH
)



topbuttons=FXHorizontalFrame.new(body,LAYOUT_SIDE_TOP|FRAME_RAISED|LAYOUT_FILL_X|PACK_UNIFORM_WIDTH,
0, 0, 0, 0,20, 20, 20, 20)



     FXButton.new(topbuttons, "Add").connect(SEL_COMMAND) {add(body) }

     FXButton.new(topbuttons, "&Quit", nil, app, FXApp::ID_QUIT)

     end

   def add(body)

     lbl=FXLabel.new(body,"text 1")

     tf=FXTextField.new(body,numcolumns=20)

     lbl.create
     tf.create
     body.recalc
   end



   def create
     super
     show(PLACEMENT_SCREEN)
   end
end


application = FXApp.new("Test", "FoxTest")
Test.new(application)
application.create
application.run
