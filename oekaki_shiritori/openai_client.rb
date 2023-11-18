require 'net/http'
require 'net/https'
require 'uri'
require 'json'

class Client
  class Error < Exception
  end

  protected
  def post(*args)
    request(:post, *args)
  end

  def get(*args)
    request(:get, *args)
  end

  def request(method, *args)
    retry_count = 5
    begin
      res = @http.send(method, *args)
      case res
      when Net::HTTPTooManyRequests
        STDERR.puts 'too many requests... sleep'
        sleep (res['retry-after']&.to_i || 1)
        request(method, *args)
      else
        return res
      end
    rescue EOFError => e
      STDERR.puts e
      sleep(1)
      retry_count -= 1
      retry if retry_count > 0
    rescue SocketError => e
      STDERR.puts e
      sleep(1)
      retry_count -= 1
      retry if retry_count > 0
    end
  end
end

class OpenAiClient < Client
  def initialize(api_key, org_key = nil)
    @api_key = api_key
    @org_key = org_key
    @endpoint = 'https://api.openai.com/'
    @uri = URI.parse(@endpoint)
    @http = Net::HTTP.new(@uri.host, @uri.port)
    @http.use_ssl = (@uri.scheme == 'https')
    retry_count = 5
    begin
      @http.start
    rescue SocketError => e
      STDERR.puts "Connection error: error=#{e}"
      retry_count -= 1
      retry if retry_count > 0
    end

    @base_headers = {
      'Content-Type' => 'application/json',
      'Authorization' =>  "Bearer #{@api_key}"
    }
    @base_headers['OpenAI-Organization'] = @org_key if @org_key
  end

  def models
    path = '/v1/models'
    JSON.parse(get(path, @base_headers).body)
  end

  def chat_completions(history, options = {})
    path = '/v1/chat/completions'
    req = options.merge({
      messages: history,
    })
    res = JSON.parse(post(path, req.to_json, @base_headers).body)
    # puts JSON.pretty_generate(res)
    res
  end

  def image_generations(prompt, options = {})
    path = '/v1/images/generations'
    req = options.merge({
      model: 'dall-e-2',
      prompt: prompt,
    })
    res = JSON.parse(post(path, req.to_json, @base_headers).body)
    res.dig('data', 0, 'url') or raise Error.new("Failed to generate image: res = #{res}")
  end
end

class AzureClient < Client
  def initialize(endpoint, api_key, deployments, api_version = '2023-09-01-preview')
    @endpoint = endpoint
    @api_key = api_key
    @deployments = deployments
    @api_version = api_version

    @uri = URI.parse(@endpoint)
    @http = Net::HTTP.new(@uri.host, @uri.port)
    @http.use_ssl = (@uri.scheme == 'https')
    retry_count = 5
    begin
      @http.start
    rescue SocketError => e
      STDERR.puts "Connection error: error=#{e}"
      retry_count -= 1
      retry if retry_count > 0
    end

    @base_headers = {
      'Content-Type' => 'application/json',
      'api-key' => @api_key,
    }
  end

  def chat_completions(history, options = {})
    path = @uri.path + "/openai/deployments/#{@deployments}/chat/completions?api-version=#{@api_version}"
    req = options.merge({
      messages: history,
    })
    res = JSON.parse(post(path, req.to_json, @base_headers).body)
    # puts JSON.pretty_generate(res)
    res
  end

  WAITING_STATUS = %w[notRunning running]
  def image_generations(prompt, options = {})
    path = @uri.path + "/openai/images/generations:submit?api-version=#{@api_version}"
    req = options.merge({
      prompt: prompt,
    })
    res = JSON.parse(post(path, req.to_json, @base_headers).body)
    operation_id = res.dig('id')
    raise Error.new("Failed to submit to generate image: res = #{res}") unless operation_id

    while WAITING_STATUS.include?(res['status']) do
      sleep(1)
      path = @uri.path + "/openai/operations/images/#{operation_id}?api-version=#{@api_version}"
      res = JSON.parse(get(path, @base_headers).body)
      return res.dig('result', 'data', 0, 'url') if res['status'] == 'succeeded'
    end
    raise Error.new("Failed to generate image: res = #{res}")
  end
end
