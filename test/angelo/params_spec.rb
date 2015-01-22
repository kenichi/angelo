require_relative '../spec_helper'

class ParamsTester
  include Angelo::ParamsParser

  attr_accessor :body, :form_encoded, :json, :query_string

  def request
    if @request.nil?
      @request = OpenStruct.new
      @request.body = @body
      @request.query_string = @query_string
    end
    @request
  end

  def form_encoded?; @form_encoded; end
  def json?; @json; end

end

describe Angelo::ParamsParser do

  let(:get_params) {
    'foo=bar&bar=123456.78901234567&bat=true&array%5B%5D=wat&array%5B%5D=none'
  }

  let(:post_params) {
    {
      'foo' => 'bar',
      'bar' => 123456.78901234567,
      'bat' => true,
      'array[]' => 'none'
    }
  }

  let(:json_params) { post_params.to_json }

  let(:params_s) {
    post_params.keys.reduce({}){|h,k| h[k] = post_params[k].to_s; h}
  }

  let(:parser) { ParamsTester.new }

  it 'parses query string params in the normal, non-racked-up, way' do
    parser.parse_formencoded(get_params).must_equal params_s
  end

  it 'parses formencoded POST bodies in the normal, non-racked-up, way' do
    parser.form_encoded = true
    parser.json = false
    parser.body = get_params
    parser.parse_post_body.must_equal params_s
  end

  it 'parses JSON POST bodies params' do
    parser.form_encoded = false
    parser.json = true
    parser.body = json_params
    parser.parse_post_body.must_equal post_params
  end

  it "doesn't choke on empty JSON POST bodies" do
    parser.form_encoded = false
    parser.json = true
    parser.body = ""
    parser.parse_post_body.must_equal({})
  end

  it 'recursively symhashes JSON POST bodies params' do
    nested = {
      foo: {
        bar: 'baz',
        that: {
          holmes: true
        }
      }
    }
    parser.form_encoded = false
    parser.json = true
    parser.body = nested.to_json
    parsed = parser.parse_post_body
    parsed['foo']['bar'].must_equal 'baz'
    parsed[:foo][:bar].must_equal 'baz'
    assert parsed['foo']['that']['holmes']
    assert parsed[:foo][:that][:holmes]
  end

  it 'should override query string with JSON POST bodies params' do
    parser.form_encoded = false
    parser.json = true
    parser.query_string = get_params
    parser.body = json_params
    parser.parse_query_string_and_post_body.must_equal post_params
  end

  it 'does not parse POST bodies if no Content-Type' do
    parser.form_encoded = false
    parser.json = false
    parser.query_string = get_params
    parser.body = nil
    parser.parse_query_string.must_equal params_s
    parser.parse_post_body.must_equal({})
    parser.parse_query_string_and_post_body.must_equal params_s
  end

end

describe Angelo::SymHash do

  describe ".new" do
    it "returns a Hash" do
      Angelo::SymHash.new.must_be_kind_of Hash
    end
  end

  it "fetches values for Symbols that were inserted with Strings" do
    symhash = Angelo::SymHash.new
    symhash["x"] = "y"
    symhash["x"].must_equal "y"
    symhash[:x].must_equal "y"
  end

end
