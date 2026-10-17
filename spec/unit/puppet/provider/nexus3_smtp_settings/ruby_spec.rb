require 'spec_helper'

type_class = Puppet::Type.type(:nexus3_smtp_settings)

describe type_class.provider(:ruby) do
  before(:each) { stub_default_config_and_healthcheck }

  let(:values) do
    {
      enabled: true,
      hostname: 'my.server.com',
      port: 1234,
      username: 'user',
      password: 'pass',
      sender_email: 'admin@my.server.com',
      subject_prefix: 'prefix of email subject',
    }
  end

  let(:instance) do
    resource = type_class.new(values.merge(name: 'example'))
    instance = described_class.new(values.merge(name: 'example'))
    resource.provider = instance
    instance
  end

  describe 'define getters and setters to each type properties or params' do
    let(:instance) { described_class.new }

    [:hostname, :port, :enabled, :username, :password, :sender_email, :subject_prefix].each do |method|
      specify { expect(instance.respond_to?(method)).to be_truthy }
      specify { expect(instance.respond_to?("#{method}=")).to be_truthy }
    end
  end

  describe 'prefetch' do
    it 'raise error if more than one resource of this type is configured' do
      expect {
        described_class.prefetch({ example1: type_class.new(values.merge(name: 'example1')), example2: type_class.new(values.merge(name: 'example2')) })
      }.to raise_error(Puppet::Error, %r{There are more then 1 instance\(s\) of 'nexus3_smtp_settings': example1, example2})
    end

    it 'not raise error if just one resource of this type is configured' do
      expect(Nexus3::API).to receive(:execute_script).and_return(values.to_json)

      expect {
        described_class.prefetch({ example1: type_class.new(values.merge(name: 'example1')) })
      }.not_to raise_error
    end

    it 'set the provider no matter if the names matches' do
      expect(Nexus3::API).to receive(:execute_script).and_return('{"name": "example2", "hostname": "from_service" }')

      resources = { example1: type_class.new(values.merge(name: 'example1')) }
      described_class.prefetch(resources)
      expect(resources[:example1].provider.hostname).to eq('from_service')
      expect(resources[:example1][:hostname]).to eq 'my.server.com'
    end
  end

  describe 'instances' do
    specify 'should execute a script to get SMTP settings' do
      script = <<~EOS
        def emailManager = container.lookup(org.sonatype.nexus.email.EmailManager.class.name);
        def config = emailManager.getConfiguration();
        return groovy.json.JsonOutput.toJson([
          enabled : config.enabled,
          hostname : config.host,
          port : config.port,
          username : config.username,
          password : config.password,
          sender_email : config.fromAddress,
          subject_prefix : config.subjectPrefix,
        ]);
      EOS
      expect(Nexus3::API).to receive(:execute_script).with(script).and_return('{}')
      described_class.instances
    end

    specify 'should use default values to non set properties' do
      allow(Nexus3::API).to receive(:execute_script).and_return('{}')
      instances = described_class.instances
      expect(instances.length).to eq 1
      expect(instances[0].enabled).to eq('')
      expect(instances[0].hostname).to eq('')
      expect(instances[0].port).to eq('')
      expect(instances[0].username).to eq('')
      expect(instances[0].password).to eq('')
      expect(instances[0].sender_email).to eq('')
      expect(instances[0].subject_prefix).to eq('')
    end

    specify 'should map each returned values to the correspondent property' do
      allow(Nexus3::API).to receive(:execute_script).and_return(values.to_json)
      instances = described_class.instances
      expect(instances.length).to eq 1
      expect(instances[0].enabled).to eq :true
      expect(instances[0].hostname).to eq('my.server.com')
      expect(instances[0].port).to eq(1234)
      expect(instances[0].username).to eq('user')
      # The cleartext password is replaced by a one-way digest and blanked, so
      # the secret never rides a synchronised property into a report.
      expect(instances[0].password).to eq('')
      expect(instances[0].password_hash).to eq(Digest::SHA256.hexdigest('pass'))
      expect(instances[0].sender_email).to eq('admin@my.server.com')
      expect(instances[0].subject_prefix).to eq('prefix of email subject')
    end
  end

  describe 'flush' do
    it 'execute a script to update the changes' do
      script = <<~EOS
        def emailManager = container.lookup(org.sonatype.nexus.email.EmailManager.class.name);
        def config = emailManager.getConfiguration();
        config.enabled = true;
        config.host = 'my.server.com';
        config.port = 1234;
        config.username = 'user';
        config.password = 'pass';
        config.fromAddress = 'admin@my.server.com';
        config.subjectPrefix = 'prefix of email subject';
        emailManager.setConfiguration(config);
      EOS
      expect(Nexus3::API).to receive(:execute_script).with(script).and_return(nil)
      instance.mark_config_dirty
      instance.flush
    end

    describe 'when some value has changed' do
      before(:each) { instance.port = 4321 }

      specify { expect(instance.instance_variable_get(:@update_required)).to be_truthy }
    end

    describe 'when only the password changed' do
      before(:each) { instance.password_hash = Digest::SHA256.hexdigest('a different password') }

      specify { expect(instance.instance_variable_get(:@update_required)).to be_truthy }
    end
  end

  describe 'password change detection and redaction' do
    specify 'maps the service password to a SHA-256 and blanks the cleartext' do
      allow(Nexus3::API).to receive(:execute_script).and_return(values.to_json)
      inst = described_class.instances[0]
      expect(inst.password_hash).to eq(Digest::SHA256.hexdigest('pass'))
      expect(inst.password).to eq('')
    end

    specify 'redact_password strips the password from a script before it is logged' do
      inst = described_class.new
      raw = "config.username = 'user';\nconfig.password = 'sup3r secret';\nconfig.port = 25;"
      red = inst.redact_password(raw)
      expect(red).to include("config.password = '[redacted]';")
      expect(red).not_to include('sup3r secret')
      expect(red).to include("config.username = 'user';")
    end
  end
end
