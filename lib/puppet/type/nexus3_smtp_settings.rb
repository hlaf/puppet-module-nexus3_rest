require 'puppet/property/boolean'
require 'digest'

Puppet::Type.newtype(:nexus3_smtp_settings) do
  @doc = 'Manages Nexus 3 SMTP settings.'

  newparam(:name, namevar: true) do
    desc 'Name of the configuration.'
  end

  newproperty(:hostname) do
    desc 'The host name of the SMTP server.'
    validate do |value|
      raise ArgumentError, 'Hostname must not be empty' if value.to_s.empty?
    end
  end

  newproperty(:port) do
    desc 'The port number the SMTP server is listening on. Must be within 1 and 65535.'
    defaultto 25
    validate do |value|
      raise ArgumentError, "Port must be a non-negative integer, got #{value}" unless value.to_s =~ %r{\d+}
      raise ArgumentError, "Port must within [1, 65535], got #{value}" unless (1..65_535).cover?(value.to_i)
    end
    munge { |value| Integer(value) }
  end

  newproperty(:enabled, parent: Puppet::Property::Boolean) do
    desc 'When SMTP settings is enabled or not.'
    newvalues(:true, :false)
    defaultto :false
    munge { |value| super(value).to_s.to_sym }
  end

  newproperty(:username) do
    desc 'The username used to access the SMTP server.'
  end

  newparam(:password) do
    desc 'The expected value of the password.'
  end

  # Change-detection digest for the password. The password stays a PARAMETER
  # (never synchronised) on purpose: a property records its raw previous and
  # desired values in the agent run report, and this Puppet version has no
  # Sensitive redaction for those structured fields, so a password property
  # would copy the secret into every report sink. Synchronising a one-way
  # SHA-256 of the password instead makes a change detectable -- the provider
  # then flushes and pushes the real (parameter) password -- while only the
  # digest, never the secret, can reach a report. The *_to_s overrides keep
  # even the digest out of the human-readable change message. Internal: it
  # defaults from `password` and must not be set in a manifest.
  newproperty(:password_hash) do
    desc 'Internal change-detection digest of the password. Do not set manually.'
    defaultto { Digest::SHA256.hexdigest(@resource[:password].to_s) }

    def is_to_s(_currentvalue)
      '[redacted]'
    end

    def should_to_s(_newvalue)
      '[redacted]'
    end

    def change_to_s(_currentvalue, _newvalue)
      'password change detected'
    end
  end

  newproperty(:sender_email) do
    desc 'Email address used in the `From:` field.'
    validate do |value|
      raise ArgumentError, 'Sender email must not be empty' if value.to_s.empty?
      raise ArgumentError, "Invalid email address '#{value}'." unless value.to_s =~ %r{@}
    end
  end

  newproperty(:subject_prefix) do
    desc 'Email subject prefix.'
  end

  newproperty(:nexus_trust_store_enabled, parent: Puppet::Property::Boolean) do
    desc 'When Nexus Repository truststore should be used or not.'
    newvalues(:true, :false)
    defaultto :false
    munge { |value| super(value).to_s.to_sym }
  end

  newproperty(:start_tls_enabled, parent: Puppet::Property::Boolean) do
    desc 'When STARTTLS support is enabled or not.'
    newvalues(:true, :false)
    defaultto :false
    munge { |value| super(value).to_s.to_sym }
  end

  newproperty(:start_tls_required, parent: Puppet::Property::Boolean) do
    desc 'When STARTTLS support is required or not.'
    newvalues(:true, :false)
    defaultto :false
    munge { |value| super(value).to_s.to_sym }
  end

  newproperty(:ssl_on_connect_enabled, parent: Puppet::Property::Boolean) do
    desc 'When SSL/TLS encryption is enabled upon connection or not.'
    newvalues(:true, :false)
    defaultto :false
    munge { |value| super(value).to_s.to_sym }
  end

  newproperty(:ssl_check_server_identity_enabled, parent: Puppet::Property::Boolean) do
    desc 'When server identity check is enabled or not.'
    newvalues(:true, :false)
    defaultto :false
    munge { |value| super(value).to_s.to_sym }
  end

  autorequire(:file) do
    Nexus3::Config.file_path
  end
end
