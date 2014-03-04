require_relative '../spec_helper'

describe Angelo::Server do

  describe 'serving static files' do

    define_app do

      @root = APP_ROOT

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
      expect(last_response.body.length).to be(116)
      expect(last_response.body).to eq(File.read(File.join APP_ROOT, 'public', 'test.css'))
    end

    it 'serves headers for static files on head' do
      head '/test.css'
      expect(last_response.status).to be(200)
      expect(last_response.headers['Content-Type']).to eq('text/css')
      expect(last_response.headers['Content-Disposition']).to eq('attachment; filename=test.css')
      expect(last_response.headers['Content-Length']).to eq('116')
      expect(last_response.body.length).to be(0)
    end

    it 'serves static file over route' do
      get '/test.html'
      expect(last_response.status).to be(200)
      expect(last_response.headers['Content-Type']).to eq('text/html')
      expect(last_response.headers['Content-Disposition']).to eq('attachment; filename=test.html')
      expect(last_response.body).to eq(File.read(File.join APP_ROOT, 'public', 'test.html'))
    end

  end

end
