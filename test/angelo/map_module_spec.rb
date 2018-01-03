
require_relative '../spec_helper'

def simple_page body
    "<!DOCTYPE html>\n" +
    "<html><head><title>Angelo</title></head><body>\n" +
    "<h2>#{body}</h2>\n" +
    "</body></html>\n"
end

class SubMod1 < Angelo::Base
  get '/' do
    simple_page 'SubMod1 root'
  end
  get '/route1' do
    simple_page 'SubMod1 route1'
  end
end
class SubMod2 < Angelo::Base
  get '/route1' do
    simple_page 'SubMod2 route1'
  end
end
class SubMod3 < Angelo::Base
  get '/route1' do
    simple_page 'SubMod3 route1'
  end
end
class SubMod4 < Angelo::Base
  get '/route1' do
    simple_page 'SubMod4 route1'
  end

  map '/sub3', SubMod3
end
class RecurMod < Angelo::Base
  get '/' do
    simple_page 'very very messy'
  end
  get '/messy' do
    simple_page('very ' * (request.path.count('/')-2) + 'messy')
  end

  map '/very', self
end

class MainMod < Angelo::Base
 get '/route1' do
   simple_page('route1')
 end
 get '/route2/' do
   simple_page('route2')
 end

 map '/sub1', SubMod1
 map '/sub2', SubMod2
 map '/sub4', SubMod4
 map '/sub1extra', SubMod1
 map '/recur', RecurMod

 get '/sub1/ungettable' do
   simple_page("Can't get this")
 end
 get '/sub1route3' do
   simple_page('sub1route3')
 end
end


def last_response_must_fail_with code
  last_response.status.must_equal code
end


describe Angelo::Base do
  describe '#map' do

    define_app MainMod

    it 'still supports normal routes' do
      get '/route1'
      last_response_must_be_html simple_page('route1')
    end

    it 'still supports multiple routes' do
      get '/route2/'
      last_response_must_be_html simple_page('route2')
    end

    it 'can map other modules to a path' do
      # /sub1 mapped SubMod1, which contains /route1
      get '/sub1/route1'
      last_response_must_be_html simple_page('SubMod1 route1')
    end

    it 'can map multiple modules to different paths' do
      # /sub2 mapped SubMod2, which contains /route1
      get '/sub2/route1'
      last_response_must_be_html simple_page('SubMod2 route1')
    end

    it 'first looks up mapped modules, then routing' do
      # since modules are looked up before routes,
      # that means that routes exactly matching a module's path are unreachble
      # as they will be routed to the sub module, not handled by this module
      get '/sub1/ungettable' # this is overshadowed by map '/sub1'
      last_response_must_fail_with 404
      # the 404 response will be by SubMod1, not by MainMod
    end

    it 'does route for paths which don\'t match the subroute, but match it in part' do
      # this path doesn't overlap with /sub1, as Mustermann doesn't match
      # /sub1 to /sub1route3 or vice versa
      get '/sub1route3' # this is not overshadowed by /sub1
      last_response_must_be_html simple_page('sub1route3')
    end

    it 'supports modules mapping other modules, as deep as you want' do
      # /sub4 mapped SubMod4, which mapped SubMod3 at /sub3, which has /route1
      get '/sub4/sub3/route1'
      last_response_must_be_html simple_page('SubMod3 route1')
    end

    it 'supports mapping the same module on different places' do
      # SubMod1 is mapped at /sub1 and at /sub1extra
      get '/sub1extra/route1'
      last_response_must_be_html simple_page('SubMod1 route1')
    end

    it 'supports mapping modules in folder style, forcing URL to end with slash' do
      # SubMod1 is mapped as /folder1/, which causes get /folder1 to cause 404, while get /folder1/ works
      MainMod.map '/folder1/', SubMod1
      get '/folder1' # this URL is not available, because the map started with a slash
      last_response_must_fail_with 404

      get '/folder1/' # this URL is available
      last_response_must_be_html simple_page('SubMod1 root')
    end

    it 'maps for String or Mustermann' do
      mm = Mustermann.new('/testing/*')
      MainMod.map mm, SubMod1
      get '/testing/route1'
      last_response_must_be_html simple_page('SubMod1 route1')
    end

    it 'supports recursive modules.' do
      # But that is more by accident or design flaw
      # seriously, don't use this.
      get '/recur/'
      last_response_must_be_html simple_page('very very messy')
    end
    it 'supports recursive modules. Well, that escalated quickly.' do
      # like, seriously.
      get '/recur/very/very/very/very/very/messy'
      last_response_must_be_html simple_page('very very very very very messy')
    end

    it 'does not allow maps for nil' do
      assert_raises(ArgumentError) do
        MainMod.map nil, SubMod1
      end
    end
    it 'does not allow maps for empty string' do
      assert_raises(ArgumentError) do
        MainMod.map '', SubMod1
      end
    end
    it 'does not allow maps for "/"' do
      assert_raises(ArgumentError) do
        MainMod.map '/', SubMod1
      end
    end
    it 'expects an Angelo::Base class (or subclass thereof) as second parameter' do
      assert_raises(ArgumentError) do
        MainMod.map '/test', Object
      end
    end
  end
end
