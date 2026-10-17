require File.join(File.dirname(__FILE__), '..', 'nexus3_base')
require 'digest'

Puppet::Type.type(:nexus3_smtp_settings).provide(:ruby, parent: Puppet::Provider::Nexus3Base) do
  desc 'Ruby-based management of the Nexus 3 SMTP settings.'

  def self.templates_folder
    File.join(File.dirname(__FILE__), 'templates')
  end

  def self.max_instances_allowed
    1
  end

  mk_resource_methods

  # Derive the change-detection digest from the password Nexus returns, then
  # drop the cleartext so it is not retained on the discovered instance. The
  # password_hash property is what the transaction compares; the password
  # itself stays a parameter and never reaches a report.
  def self.map_config_to_resource(config)
    resource_hash = super
    resource_hash[:password_hash] = Digest::SHA256.hexdigest(config['password'].to_s)
    resource_hash[:password] = ''
    resource_hash
  end

  # As the base update_config, but the debug-logged script has the password
  # stripped so the secret cannot surface even at --debug. The script actually
  # sent to Nexus is unchanged.
  def update_config
    script = write_config_script
    Puppet.debug("UPDATE SCRIPT:\n" + redact_password(script))
    Nexus3::API.execute_script(script)
  rescue => e
    raise Puppet::Error, "Error while updating #{resource.class.name} #{resource[:name]}: #{e}"
  end

  def redact_password(script)
    script.gsub(/config\.password = '.*';/, "config.password = '[redacted]';")
  end
end
