require_relative '../spec_helper'
require 'openssl'

describe Angelo::Server do

  describe 'serving static files' do

    let(:test_css_etag) do
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
      expect(last_response.status).to be(200)
      expect(last_response.headers['Content-Type']).to eq('text/css')
      expect(last_response.headers['Content-Disposition']).to eq('attachment; filename=test.css')
      expect(last_response.headers['Content-Length']).to eq('116')
      expect(last_response.headers['Etag']).to eq(test_css_etag)
      expect(last_response.body.length).to be(116)
      expect(last_response.body).to eq(File.read(File.join TEST_APP_ROOT, 'public', 'test.css'))
    end

    it 'serves headers for static files on head' do
      head '/test.css'
      expect(last_response.status).to be(200)
      expect(last_response.headers['Content-Type']).to eq('text/css')
      expect(last_response.headers['Content-Disposition']).to eq('attachment; filename=test.css')
      expect(last_response.headers['Content-Length']).to eq('116')
      expect(last_response.headers['Etag']).to eq(test_css_etag)
      expect(last_response.body.length).to be(0)
    end

    it 'serves static file over route' do
      get '/test.html'
      expect(last_response.status).to be(200)
      expect(last_response.headers['Content-Type']).to eq('text/html')
      expect(last_response.headers['Content-Disposition']).to eq('attachment; filename=test.html')
      expect(last_response.body).to eq(File.read(File.join TEST_APP_ROOT, 'public', 'test.html'))
    end

    it 'not modifieds when if-none-match matched etag' do
      get '/test.css', {}, {'If-None-Match' => test_css_etag}
      expect(last_response.status).to be(304)
    end

    it 'serves proper content-types' do
      { 'test.js' => 'application/javascript',
        'test.html' => 'text/html',
        'test.css' => 'text/css',
        'what.png' => 'image/png' }.each do |k,v|

        get "/#{k}"
        expect(last_response.status).to be(200)
        expect(last_response.headers['Content-Type']).to eq(v)

      end
    end

  end

end
