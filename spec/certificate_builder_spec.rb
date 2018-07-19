require 'yaml'

RSpec.describe LECLI::CertificateBuilder do
  it 'should differentiate staging from production' do
    prod_url = 'https://acme-v02.api.letsencrypt.org/directory'
    staging_url = 'https://acme-staging-v02.api.letsencrypt.org/directory'

    prod_builder = LECLI::CertificateBuilder.new do |builder|
      builder.production = true
    end
    extracted_prod = prod_builder.instance_variable_get(:@endpoint)
    expect(extracted_prod).to eq(prod_url)

    staging_builder = LECLI::CertificateBuilder.new
    extracted_staging = staging_builder.instance_variable_get(:@endpoint)
    expect(extracted_staging).to eq(staging_url)
  end

  it 'should provide a defaults hash' do
    opts = LECLI::CertificateBuilder.default_options
    options_available = [
      'domains', 'common_name', 'account_email', 'request_key',
      'certificate_key', 'challenges_relative_path', 'success_callback_script'
    ]
    expect(opts.keys).to eq(options_available)
  end

  it 'should load options including config from `.lecli.yml`' do
    # Setup custom port
    test_name = 'Test'
    filename = LECLI::CertificateBuilder::YAML_FILENAME
    File.write(filename, { 'common_name' => test_name }.to_yaml)

    opts = LECLI::CertificateBuilder.load_options(config_file: filename)
    options_available = [
      'domains', 'common_name', 'account_email', 'request_key',
      'certificate_key', 'challenges_relative_path', 'success_callback_script'
    ]
    expect(opts.keys).to eq(options_available)
    expect(opts['common_name']).to eq(test_name)

    # Cleanup
    FileUtils.rm(filename)
  end

  it 'creates an order' do
    builder = LECLI::CertificateBuilder.new
    opts = { email: 'tester@gmail.com', domains: ['example.com'] }
    builder.send(:create_order, opts)
    order = builder.instance_variable_get(:@order)
    expect(order.class).to eq(Acme::Client::Resources::Order)
  end
end
