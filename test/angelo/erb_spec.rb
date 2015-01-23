require_relative '../spec_helper'

describe Angelo::Base do
  describe Angelo::Tilt::ERB do

    expected_html = <<HTML
<!doctype html>
<html>
  <head>
    <title>test</title>
  </head>
  <body>
    foo - asdf
locals :bar - bat

  </body>
</html>
HTML

    expected_xml = <<XML
<foo bar="bat">asdf</foo>
XML

    expected_json = <<JSON
{"foo": "asdf", "bar": ["bat"]}
JSON

    expected_javascript = <<JS
(function() {
  var foo = "asdf";
var bar = "bat";

})();
JS

    expected_html_nl = <<HTML
foo - asdf
locals :bar - bat
HTML

    expected_xml_nl = <<XML
<foo bar="bat">asdf</foo>
XML

    expected_json_nl = <<JSON
{"foo": "asdf", "bar": ["bat"]}
JSON

    expected_javascript_nl = <<JS
var foo = "asdf";
var bar = "bat";
JS

    define_app do

      @root = TEST_APP_ROOT

      def set_vars
        @title = 'test'
        @foo = params[:foo]
      end

      get '/' do
        set_vars
        erb :index, locals: {bar: 'bat'}
      end

      get '/no_layout' do
        set_vars
        erb :index, layout: false, locals: {bar: 'bat'}
      end

      get '/index.html' do
        set_vars
        content_type :html
        erb :index, locals: {bar: 'bat'}, layout: !!params[:layout]
      end

      get '/index.json' do
        set_vars
        content_type :json
        erb :index, locals: {bar: 'bat'}, layout: !!params[:layout]
      end

      get '/index.js' do
        set_vars
        content_type :js
        erb :index, locals: {bar: 'bat'}, layout: !!params[:layout]
      end

      get '/index.xml' do
        set_vars
        content_type :xml
        erb :index, locals: {bar: 'bat'}, layout: !!params[:layout]
      end

      get '/by_type' do
        set_vars
        erb :index, locals: {bar: 'bat'}, type: params[:type].to_sym
      end

    end

    it 'renders templates with layout' do
      get '/', foo: 'asdf'
      last_response_must_be_html expected_html
    end

    it 'renders templates without layout' do
      get '/no_layout', foo: 'asdf'
      expected = <<HTML
foo - asdf
locals :bar - bat
HTML
      last_response_must_be_html expected
    end

    it 'renders templates by Accept header html' do
      get '/', {foo: 'asdf'}, {'Accept' => 'text/html'}
      last_response_must_be_html expected_html
    end

    it 'renders templates by Accept header xml' do
      get '/', {foo: 'asdf'}, {'Accept' => 'application/xml'}
      last_response.body.must_equal expected_xml
      last_response.headers['Content-Type'].must_equal 'application/xml'
    end

    it 'renders templates by Accept header javascript' do
      get '/', {foo: 'asdf'}, {'Accept' => 'application/javascript'}
      last_response.body.must_equal expected_javascript
      last_response.headers['Content-Type'].must_equal 'application/javascript'
    end

    it 'renders templates by Accept header json' do
      get '/', {foo: 'asdf'}, {'Accept' => 'application/json'}
      last_response.body.must_equal expected_json
      last_response.headers['Content-Type'].must_equal 'application/json'
    end

    it 'renders html template when unknown Accept header type' do
      get '/', {foo: 'asdf'}, {'Accept' => 'forget/about/it'}
      last_response_must_be_html expected_html
    end

    # content_type

    it 'renders templates by content_type :html' do
      get '/index.html', foo: 'asdf', layout: true
      last_response_must_be_html expected_html
    end

    it 'renders templates by content_type :xml' do
      get '/index.xml', foo: 'asdf', layout: true
      last_response.body.must_equal expected_xml
      last_response.headers['Content-Type'].must_equal 'application/xml'
    end

    it 'renders templates by content_type :javascript' do
      get '/index.js', foo: 'asdf', layout: true
      last_response.body.must_equal expected_javascript
      last_response.headers['Content-Type'].must_equal 'application/javascript'
    end

    it 'renders templates by content_type :json' do
      get '/index.json', foo: 'asdf', layout: true
      last_response.body.must_equal expected_json
      last_response.headers['Content-Type'].must_equal 'application/json'
    end

    it 'renders templates by content_type :html' do
      get '/index.html', foo: 'asdf'
      last_response_must_be_html expected_html_nl
    end

    it 'renders templates by content_type :xml' do
      get '/index.xml', foo: 'asdf'
      last_response.body.must_equal expected_xml_nl
      last_response.headers['Content-Type'].must_equal 'application/xml'
    end

    it 'renders templates by content_type :javascript' do
      get '/index.js', foo: 'asdf'
      last_response.body.must_equal expected_javascript_nl
      last_response.headers['Content-Type'].must_equal 'application/javascript'
    end

    it 'renders templates by content_type :json' do
      get '/index.json', foo: 'asdf'
      last_response.body.must_equal expected_json_nl
      last_response.headers['Content-Type'].must_equal 'application/json'
    end

    # opts[:type]

    it 'renders templates by opts[:type] :html' do
      get '/by_type', foo: 'asdf', type: 'html'
      last_response_must_be_html expected_html
    end

    it 'renders templates by opts[:type] :xml' do
      get '/by_type', foo: 'asdf', type: 'xml'
      last_response.body.must_equal expected_xml
      last_response.headers['Content-Type'].must_equal 'application/xml'
    end

    it 'renders templates by opts[:type] :javascript' do
      get '/by_type', foo: 'asdf', type: 'js'
      last_response.body.must_equal expected_javascript
      last_response.headers['Content-Type'].must_equal 'application/javascript'
    end

    it 'renders templates by opts[:type] :json' do
      get '/by_type', foo: 'asdf', type: 'json'
      last_response.body.must_equal expected_json
      last_response.headers['Content-Type'].must_equal 'application/json'
    end
  end

  describe 'reload_templates!' do

    expected_html = <<HTML
<!doctype html>
<html>
  <head>
    <title>test</title>
  </head>
  <body>
    foo - asdf
locals :bar - bat

  </body>
</html>
HTML

    reloaded_expected_html = <<HTML
<!doctype html>
<html>
  <head>
    <title>test</title>
  </head>
  <body>
    foo - asdf
locals :bar - bat
hi

  </body>
</html>
HTML

    define_app do
      @root = TEST_APP_ROOT

      def set_vars
        @title = 'test'
        @foo = params[:foo]
      end

      reload_templates!

      get '/' do
        set_vars
        erb :index, locals: {bar: 'bat'}
      end
    end

    it 'reloads templates' do
      original_index = File.read TEST_APP_ROOT + '/views/index.html.erb'
      begin
        get '/', foo: 'asdf'
        last_response_must_be_html expected_html
        File.open TEST_APP_ROOT + '/views/index.html.erb', 'a' do |f|
          f.puts 'hi'
        end
        get '/', foo: 'asdf'
        last_response_must_be_html reloaded_expected_html
      ensure
        File.open TEST_APP_ROOT + '/views/index.html.erb', 'w' do |f|
          f.write original_index
        end
      end
    end

  end
end
