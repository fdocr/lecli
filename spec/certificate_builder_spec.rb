require 'yaml'

RSpec.describe LECLI::CertificateBuilder do
  let!(:test_name) { 'Test' }
  let!(:bad_opts_hash) { { 'common_name' => test_name } }
  let!(:custom_opts_hash) do
    {
      'domains' => ['a.com', 'x.com'],
      'common_name' => test_name,
      'account_email' => 'elon@x.com'
    }
  end

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

  it 'should have a list of required options' do
    opts = LECLI::CertificateBuilder.required_options
    required_options = ['domains', 'common_name', 'account_email']
    expect(opts).to eq(required_options)
  end

  it 'should provide a sample options hash' do
    opts = LECLI::CertificateBuilder.sample_options
    options_available = [
      'domains', 'common_name', 'account_email', 'request_key',
      'certificate_key', 'challenges_relative_path', 'success_callback_script'
    ]
    expect(opts.keys).to eq(options_available)
  end

  it 'should provide a runtime default options hash' do
    opts = LECLI::CertificateBuilder.runtime_defaults
    options_available = [
      'request_key', 'certificate_key', 'challenges_relative_path'
    ]
    expect(opts.keys).to eq(options_available)
  end

  it 'should load options including config from lecli.yml' do
    filename = LECLI::CertificateBuilder::YAML_FILENAME
    File.write(filename, custom_opts_hash.to_yaml)

    opts = LECLI::CertificateBuilder.load_options(config_file: filename)
    options_available = [
      'domains', 'common_name', 'account_email', 'request_key',
      'certificate_key', 'challenges_relative_path'
    ]
    expect(opts.keys.sort).to eq(options_available.sort)
    expect(opts['common_name']).to eq(test_name)
    FileUtils.rm(filename) # Cleanup
  end

  it 'should fail if required fields not present in lecli.yml' do
    filename = LECLI::CertificateBuilder::YAML_FILENAME
    File.write(filename, bad_opts_hash.to_yaml)

    opts = LECLI::CertificateBuilder.load_options(config_file: filename)
    expect(opts).to be_nil
    FileUtils.rm(filename) # Cleanup
  end

  it 'creates an order' do
    builder = LECLI::CertificateBuilder.new
    opts = { email: 'tester@gmail.com', domains: ['example.com'] }
    builder.send(:create_order, opts)
    order = builder.instance_variable_get(:@order)
    expect(order.class).to eq(Acme::Client::Resources::Order)
  end
end
