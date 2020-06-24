# frozen_string_literal: true

require 'spec_helper'

describe DMDK::Config do
  let(:auto_devops_enabled) { false }
  let(:nginx_enabled) { false }
  let(:protected_config_files) { [] }
  let(:overwrite_changes) { false }
  let(:yaml) do
    {
      'auto_devops' => { 'enabled' => auto_devops_enabled },
      'dmdk' => { 'protected_config_files' => protected_config_files, 'overwrite_changes' => overwrite_changes },
      'nginx' => { 'enabled' => nginx_enabled },
      'hostname' => 'dmdk.example.com'
    }
  end
  let(:default_config) { described_class.new }

  subject(:config) { described_class.new(yaml: yaml) }

  before do
    # Ensure a developer's local dmdk.yml does not affect tests
    allow_any_instance_of(DMDK::ConfigSettings).to receive(:read!).and_return(nil)
  end

  describe '__uri' do
    context 'for defaults' do
      it 'returns http://dmdk.example.com:3000' do
        expect(config.__uri.to_s).to eq('http://dmdk.example.com:3000')
      end
    end

    context 'when port is set to 1234' do
      it 'returns http://dmdk.example.com:1234' do
        yaml['port'] = '1234'

        expect(config.__uri.to_s).to eq('http://dmdk.example.com:1234')
      end
    end

    context 'when a relative_url_root is set' do
      it 'returns http://dmdk.example.com:3000/documodel' do
        yaml['relative_url_root'] = '/documodel/'

        expect(config.__uri.to_s).to eq('http://dmdk.example.com:3000/documodel')
      end
    end

    context 'when https is enabled' do
      before do
        yaml['https'] = { 'enabled' => true }
      end

      it 'returns https://dmdk.example.com:3000' do
        expect(config.__uri.to_s).to eq('https://dmdk.example.com:3000')
      end

      context 'and port is set to 443' do
        it 'returns https://dmdk.example.com/' do
          yaml['port'] = '443'

          expect(config.__uri.to_s).to eq('https://dmdk.example.com')
        end
      end
    end
  end

  describe 'container registry' do
    describe 'image' do
      context 'when no image is specified' do
        it 'returns the default image' do
          expect(config.registry.image).to eq('registry.documodel.com/documodel-org/build/cng/documodel-container-registry:v2.9.1-documodel')
        end
      end
    end
  end

  describe '#dump_config!' do
    it 'successfully dumps the config' do
      expect do
        expect(config.dump!).to be_a_kind_of(Hash)
      end.not_to raise_error
    end

    it 'does not dump options intended for internal use only' do
      expect(config).to respond_to(:__uri)
      expect(config.dump!).not_to include('__uri')
    end

    it 'does not dump options based on question mark convenience methods' do
      expect(config.dmdk).to respond_to(:debug?)
      expect(config.dmdk.dump!).not_to include('debug?')
    end
  end

  describe '#username' do
    before do
      allow(Etc).to receive_message_chain(:getpwuid, :name) { 'iamfoo' }
    end

    it 'returns the short login name of the current process uid' do
      expect(config.username).to eq('iamfoo')
    end
  end

  describe '#postgresql' do
    let(:yaml) do
      {
        'postgresql' => {
          'host' => 'localhost',
          'port' => 1234
        }
      }
    end

    describe '#host' do
      it { expect(default_config.postgresql.host).to eq(default_config.postgresql.dir.to_s) }

      it 'returns configured value' do
        expect(config.postgresql.host).to eq('localhost')
      end
    end

    describe '#port' do
      it { expect(default_config.postgresql.port).to eq(5432) }

      it 'returns configured value' do
        expect(config.postgresql.port).to eq(1234)
      end
    end
  end

  describe '#config_file_protected?' do
    subject { config.config_file_protected?('foobar') }

    context 'with full wildcard protected_config_files' do
      let(:protected_config_files) { ['*'] }

      it 'returns true' do
        expect(config.config_file_protected?('foobar')).to eq(true)
      end

      context 'but legacy overwrite_changes set to true' do
        let(:overwrite_changes) { true }

        it 'returns false' do
          expect(config.config_file_protected?('foobar')).to eq(false)
        end
      end
    end
  end

  describe '#listen_address' do
    it 'returns 127.0.0.1 by default' do
      expect(config.listen_address).to eq('127.0.0.1')
    end
  end

  describe 'documodel' do
    describe '#dir' do
      it 'returns the DocuModel directory' do
        expect(config.documodel.dir).to eq(Pathname.new('/home/git/dmdk/documodel'))
      end
    end

    describe '#__socket_file' do
      it 'returns the DocuModel socket path' do
        expect(config.documodel.__socket_file).to eq(Pathname.new('/home/git/dmdk/documodel.socket'))
      end
    end

    describe '#__socket_file_escaped' do
      it 'returns the DocuModel socket path CGI escaped' do
        expect(config.documodel.__socket_file_escaped.to_s).to eq('%2Fhome%2Fgit%2Fdmdk%2Fdocumodel.socket')
      end
    end

    describe 'actioncable' do
      describe '#__socket_file' do
        it 'returns the DocuModel ActionCable socket path' do
          expect(config.documodel.actioncable.__socket_file).to eq(Pathname.new('/home/git/dmdk/documodel.actioncable.socket'))
        end
      end
    end
  end

  describe 'webpack' do
    describe '#vendor_dll' do
      it 'is false by default' do
        expect(config.webpack.vendor_dll).to be false
      end
    end

    describe '#static' do
      it 'is false by default' do
        expect(config.webpack.static).to be false
      end
    end

    describe '#sourcemaps' do
      it 'is true by default' do
        expect(config.webpack.sourcemaps).to be true
      end
    end
  end

  describe 'registry' do
    describe '#external_port' do
      it 'returns 5000' do
        expect(config.registry.external_port).to eq(5000)
      end
    end

    describe '#api_host' do
      context 'when AutoDevOps is not enabled' do
        let(:auto_devops_enabled) { false }

        it 'returns the default hostname' do
          expect(config.registry.api_host).to eq('dmdk.example.com')
        end
      end

      context 'when AutoDevOps is enabled' do
        let(:auto_devops_enabled) { true }

        it 'returns the default local hostname' do
          expect(config.registry.api_host).to eq('127.0.0.1')
        end
      end
    end

    describe '#tunnel_host' do
      it 'returns the default hostname' do
        expect(config.registry.tunnel_host).to eq('dmdk.example.com')
      end
    end

    describe '#tunnel_port' do
      it 'returns 5000' do
        expect(config.registry.tunnel_port).to eq(5000)
      end
    end
  end

  describe 'object_store' do
    describe '#host' do
      it 'returns the default hostname' do
        expect(config.object_store.host).to eq('127.0.0.1')
      end
    end
  end
end
