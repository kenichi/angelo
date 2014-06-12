require_relative '../spec_helper'
require 'openssl'

describe Angelo::Server do

  describe 'serving static files' do

    let(:css_etag) do
      fs = File::Stat.new File.join(TEST_APP_ROOT, 'public', 'test.css')
      OpenSSL::Digest::SHA.hexdigest fs.ino.to_s + fs.size.to_s + fs.mtime.to_s
    end

    define_app do

      @root = TEST_APP_ROOT

      get '/test.html' do
        'you should not see this'
      end

    end

    it 'serves static files for gets' do
      get '/test.css'
      last_response.status.must_equal 200
      last_response.headers['Content-Type'].must_equal 'text/css'
      last_response.headers['Content-Disposition'].must_equal 'attachment; filename=test.css'
      last_response.headers['Content-Length'].must_equal '116'
      last_response.headers['Etag'].must_equal css_etag
      last_response.body.to_s.length.must_equal 116
      last_response.body.to_s.must_equal File.read(File.join TEST_APP_ROOT, 'public', 'test.css')
    end

    it 'serves headers for static files on head' do
      head '/test.css'
      last_response.status.must_equal 200
      last_response.headers['Content-Type'].must_equal 'text/css'
      last_response.headers['Content-Disposition'].must_equal 'attachment; filename=test.css'
      last_response.headers['Content-Length'].must_equal '116'
      last_response.headers['Etag'].must_equal css_etag
      last_response.body.to_s.length.must_equal 0
    end

    it 'serves static file over route' do
      get '/test.html'
      last_response.status.must_equal 200
      last_response.headers['Content-Type'].must_equal 'text/html'
      last_response.headers['Content-Disposition'].must_equal 'attachment; filename=test.html'
      last_response.body.to_s.must_equal File.read(File.join TEST_APP_ROOT, 'public', 'test.html')
    end

    it 'not modifieds when if-none-match matched etag' do
      get '/test.css', {}, {'If-None-Match' => css_etag}
      last_response.status.must_equal 304
    end

    it 'serves proper content-types' do
      { 'test.js' => 'application/javascript',
        'test.html' => 'text/html',
        'test.css' => 'text/css',
        'what.png' => 'image/png' }.each do |k,v|

        get "/#{k}"
        last_response.status.must_equal 200
        last_response.headers['Content-Type'].must_equal v

      end
    end

  end

end
