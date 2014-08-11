require 'angelo'
class Casc < Angelo::Base

  post '/' do
    sses.each {|sse| sse.write sse_message(params[:msg])}
  end

  get '/' do
    eventsource do |es|
      sses << es
    end
  end

end
Casc.run
