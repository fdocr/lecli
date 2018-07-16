require 'thor'
require 'acme-client'
require 'uri'
require 'fileutils'

module LECLI
  # Helper class to generate certs and access the default options
  class CertificateBuilder
    attr_accessor :production

    YAML_FILENAME = '.lecli.yml'.freeze

    def initialize
      @challenges = []
      @production = false

      # Pass a block to edit the new object for prod/staging or other options
      yield self if block_given?

      prod_url = 'https://acme-v02.api.letsencrypt.org/directory'
      staging_url = 'https://acme-staging-v02.api.letsencrypt.org/directory'
      @endpoint = @production ? prod_url : staging_url
    end

    def self.default_options
      {
        'port' => 3333,
        'domains' => ['example.com'],
        'common_name' => 'Let\'s Encrypt',
        'account_email' => 'test@account.com',
        'request_key' => 'request.pem',
        'certificate_key' => 'certificate.pem',
        'challenges_relative_path' => 'challenges',
        'success_callback_script' => 'deploy.sh'
      }
    end

    def self.persist_defaults_file(override:)
      opts = LECLI::CertificateBuilder.default_options
      if !File.file?(YAML_FILENAME) || override
        File.write(YAML_FILENAME, opts.to_yaml)
        puts YAML_FILENAME
      else
        puts "#{YAML_FILENAME} already exists. Try `lecli help yaml`"
      end
    end

    def self.load_options
      opts = LECLI::CertificateBuilder.default_options
      if File.file?(YAML_FILENAME)
        opts.merge(YAML.load_file(YAML_FILENAME))
      else
        opts
      end
    end

    def generate_certs(options)
      request_challenges(options: options)
      sleep(3) # We are unaware of challenge hosting, better give them some time

      request_challenge_validation
      request_key = finalize_order(
        domains: options['domains'],
        title: options['common_name']
      )

      write_certificate(
        cert: @order.certificate, relative_path: options['certificate_key']
      )
      write_certificate(
        cert: request_key, relative_path: options['request_key']
      )
    end

    private

    def request_challenges(options:)
      create_order(email: options['account_email'], domains: options['domains'])
      setup_challenges_dir(relative_path: options['challenges_relative_path'])
      persist_challenge_tokens
    end

    def write_certificate(cert:, relative_path:)
      full_path = File.expand_path(relative_path)
      File.write(full_path, cert)
    end

    def finalize_order(domains:, title:)
      request_key = OpenSSL::PKey::RSA.new(4096)
      csr = Acme::Client::CertificateRequest.new(
        private_key: request_key,
        names: domains.values,
        subject: { common_name: title }
      )
      @order.finalize(csr: csr)
      sleep(1) while @order.status == 'processing'
      request_key
    end

    def create_order(email:, domains:)
      pkey = OpenSSL::PKey::RSA.new(4096)
      client = Acme::Client.new(private_key: pkey, directory: @endpoint)
      client.new_account(
        contact: "mailto:#{email}",
        terms_of_service_agreed: true
      )
      @order = client.new_order(identifiers: domains)
    end

    def setup_challenges_dir(relative_path:)
      @challenges_dir = File.expand_path(relative_path)
      FileUtils.mkdir_p(@challenges_dir)
      FileUtils.rm(Dir[File.join(@challenges_dir, '*')])
    end

    def request_challenge_validation
      wait_time = 5
      pending = true
      while pending
        @challenges.each do |challenge|
          begin
            challenge.request_validation
          rescue Acme::Client::Error::Malformed
            print '.'
          end
        end

        status = @challenges.map(&:status)
        pending = status.include?('pending')

        next unless pending
        puts "At least one challenge still pending, waiting #{wait_time}s ..."
        sleep(wait_time)
        wait_time *= 2 if wait_time < 640 # Gradually increment retry max ~10min
      end
      puts 'Challenges are all valid now!'
    end

    def persist_challenge_tokens
      @order.authorizations.each do |authorization|
        challenge = authorization.http
        token_path = File.join(@challenges_dir, challenge.token)
        File.write(token_path, challenge.file_content)
        @challenges << challenge
      end
    end
  end
end
