require "thor"
require "acme-client"
require "uri"
require "fileutils"

module LECLI
  class CertificateBuilder

    def self.default_options_yaml
      {
        "port" => 3333,
        "domains" => [ "example.com" ],
        "common_name" => "Let's Encrypt",
        "account_email" => "test@account.com",
        "request_key" => "request.pem",
        "certificate_key" => "certificate.pem",
        "challenges_relative_path" => "challenges",
        "success_callback_script" => "deploy.sh"
      }
    end

    def self.generate_certs(options)
      if options["production"]
        endpoint = "https://acme-v02.api.letsencrypt.org/directory"
      else
        endpoint = "https://acme-staging-v02.api.letsencrypt.org/directory"
      end

      account_pkey = OpenSSL::PKey::RSA.new(4096)
      client = Acme::Client.new(private_key: account_pkey, directory: endpoint)
      client.new_account(
          contact: "mailto:#{options["account_email"]}",
          terms_of_service_agreed: true
        )
      order = client.new_order(identifiers: options["domains"])

      # Setup if necessary & clear challenges directory
      challenges_dir = File.expand_path(options["challenges_relative_path"])
      FileUtils.mkdir_p(challenges_dir)
      FileUtils.rm(Dir[File.join(challenges_dir, "*")])

      challenges = []
      order.authorizations.each do |authorization|
        challenge = authorization.http
        token_path = File.join(challenges_dir, challenge.token)
        File.write(token_path, challenge.file_content)
        challenges << challenge
      end

      sleep(1)

      wait_time = 5
      pending = true
      while pending
        challenges.each do |challenge|
          begin
            challenge.request_validation
          rescue Acme::Client::Error::Malformed
            print "."
          end
        end

        status = challenges.map(&:status)
        pending = status.include?("pending")

        if pending
          puts "At least one challenge still pending, waiting #{wait_time}s ..."
          sleep(wait_time)

          # Gradually increment wait times before retrying (max ~10min)
          wait_time *= 2 if wait_time < 640
        end
      end
      puts "Challenges are all valid now!"

      request_key = OpenSSL::PKey::RSA.new(4096)
      csr = Acme::Client::CertificateRequest.new(
              private_key: request_key,
              names: domains.values,
              subject: { common_name: options["common_name"] }
            )
      order.finalize(csr: csr)
      sleep(1) while order.status == "processing"

      certificate_path = File.expand_path(options["certificate_key"])
      File.write(certificate_path, order.certificate)
      request_path = File.expand_path(options["request_key"])
      File.write(request_path, request_key)
    end

  end
end
