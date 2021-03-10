# frozen_string_literal: true
require 'webmock/rspec'

RSpec.configure do |c|
  c.mock_with :rspec
end

require 'puppetlabs_spec_helper/module_spec_helper'
require 'rspec-puppet-facts'

require 'spec_helper_local' if File.file?(File.join(File.dirname(__FILE__), 'spec_helper_local.rb'))

include RspecPuppetFacts

default_facts = {
  puppetversion: Puppet.version,
  facterversion: Facter.version,
}

default_fact_files = [
  File.expand_path(File.join(File.dirname(__FILE__), 'default_facts.yml')),
  File.expand_path(File.join(File.dirname(__FILE__), 'default_module_facts.yml')),
]

default_fact_files.each do |f|
  next unless File.exist?(f) && File.readable?(f) && File.size?(f)

  begin
    default_facts.merge!(YAML.safe_load(File.read(f), [], [], true))
  rescue => e
    RSpec.configuration.reporter.message "WARNING: Unable to load #{f}: #{e}"
  end
end

# read default_facts and merge them over what is provided by facterdb
default_facts.each do |fact, value|
  add_custom_fact fact, value
end

RSpec.configure do |c|
  c.default_facts = default_facts
  c.before :each do
    # set to strictest setting for testing
    # by default Puppet runs at warning level
    Puppet.settings[:strict] = :warning
    Puppet.settings[:strict_variables] = true
  end
  c.filter_run_excluding(bolt: true) unless ENV['GEM_BOLT']
  c.after(:suite) do
  end
end

# Ensures that a module is defined
# @param module_name Name of the module
def ensure_module_defined(module_name)
  module_name.split('::').reduce(Object) do |last_module, next_module|
    last_module.const_set(next_module, Module.new) unless last_module.const_defined?(next_module, false)
    last_module.const_get(next_module, false)
  end
end

# 'spec_overrides' from sync.yml will appear below this line

def stub_default_config
  default_config = {
    nexus_base_url: 'http://example.com',
    nexus_script_api_path: '/service/rest/v1/script/',
    admin_username: 'foobar',
    admin_password: 'secret',
    health_check_retries: 1,
    health_check_timeout: 10,
    can_delete_repositories: true,
  }
  allow(Nexus3::Config).to receive(:read_config).and_return(default_config)
  allow(Nexus3::API).to receive(:nexus3_server_version).and_return('< 3.20')
end

def stub_default_config_and_healthcheck
  stub_default_config
  # healthcheck
  stub_request(:get, 'http://example.com/service/rest/v1/script/')
    .with(headers: { 'Accept' => 'application/json', 'Authorization' => 'Basic Zm9vYmFyOnNlY3JldA==', 'Content-Type' => 'application/json' })
    .to_return(status: 403)
end
