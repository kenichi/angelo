require 'angelo'

class Casc < Angelo::Base

  websocket '/' do |ws|
    websockets << ws
    ws.on_message do |msg|
      websockets.each {|s| s << msg}
    end
  end

end

Casc.run
