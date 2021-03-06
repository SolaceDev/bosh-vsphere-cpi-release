require 'httpclient'

module VSphereCloud
  class CpiHttpClient

    attr_reader :backing_client

    def initialize(http_log = nil)
      @backing_client = HTTPClient.new
      @backing_client.send_timeout = 14400 # 4 hours, for stemcell uploads
      @backing_client.receive_timeout = 14400
      @backing_client.connect_timeout = 30

      if ENV.has_key?('BOSH_CA_CERT_FILE')
        @backing_client.ssl_config.add_trust_ca(ENV['BOSH_CA_CERT_FILE'])
      else
        @backing_client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end

      case http_log
        when String
          log_file = File.open(http_log, 'w')
          log_file.sync = true
          @log_writer = log_file
        when IO, StringIO
          @log_writer = http_log
        else
          @log_writer = File.open(File::NULL, 'w')
      end
    end

    def get(url, additional_headers = {})
      do_request(url, 'GET', nil, additional_headers)
    end

    def put(url, content, additional_headers = {})
      do_request(url, 'PUT', content, additional_headers)
    end

    def post(url, content, additional_headers = {})
      do_request(url, 'POST', content, additional_headers)
    end

    private

    def do_request(url, method, content, additional_headers)
      @log_writer << "= Request\n\n"
      @log_writer << "#{method} #{url}\n\n"
      @log_writer << "Date: #{Time.now}\n"
      @log_writer << "Additional Request Headers:\n"
      log_headers(additional_headers)

      if content
        @log_writer << "Request Body:\n"

        if content.is_a?(String) && content.force_encoding('utf-8').valid_encoding?
          @log_writer << content + "\n"
        else
          @log_writer << "REQUEST BODY IS BINARY DATA\n"
        end
      end

      case method
      when 'GET'
        resp = @backing_client.get(url, additional_headers)
      when 'PUT'
        resp = @backing_client.put(url, content, additional_headers)
      when 'POST'
        resp = @backing_client.post(url, content, additional_headers)
      else
        raise "Invalid HTTP method '#{method}'"
      end

      log_response(resp)

      resp
    end

    def log_headers(headers)
      headers.each do |key, value|
        @log_writer << "#{key}: #{value}\n"
      end
      @log_writer << "None\n" if headers.empty?
    end

    def log_response(resp)
      @log_writer << "= Response\n\n"
      @log_writer << "Status: #{resp.code} #{resp.reason}\n"
      @log_writer << "Response Headers:\n"
      log_headers(resp.headers)

      if resp.content
        @log_writer << "Response Body:\n"

        if resp.content.is_a?(String) && resp.content.force_encoding('utf-8').valid_encoding?
          @log_writer << resp.content + "\n"
        else
          @log_writer << "RESPONSE BODY IS BINARY DATA\n"
        end
      end
    end
  end
end
