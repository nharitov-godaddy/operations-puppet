require_relative '../../../../rake_modules/spec_helper'

describe 'systemd::unit' do
  on_supported_os(WMFConfig.test_on).each do |os, facts|
    context "On #{os}" do
      let(:title) { 'dummyservice' }
      let(:facts) { facts }
      let(:params) do
        {
          ensure: 'present',
          content: 'dummy'
        }
      end

      context 'when the corresponding service is defined (implicit name)' do
        let(:pre_condition) { "service { 'foobar': ensure => running, provider => 'systemd'}" }
        let(:title) { 'foobar' }
        it { is_expected.to compile }
        it do
          is_expected.to contain_exec('systemd daemon-reload for foobar.service (foobar)')
                           .that_comes_before('Service[foobar]')
        end
        context 'when managing the service restarts' do
          let(:params) { super().merge(restart: true) }

          it { is_expected.to compile }
          it do
            is_expected.to contain_exec('systemd daemon-reload for foobar.service (foobar)')
                             .that_notifies('Service[foobar]')
          end
        end
      end

      context 'when using dummy parameters and a name without type' do
        it { is_expected.to compile }

        describe 'then the systemd service' do
          it 'should define a unit file in the system directory' do
            is_expected.to contain_file('/lib/systemd/system/dummyservice.service')
                             .with_content('dummy')
                             .that_notifies(
                               "Exec[systemd daemon-reload for dummyservice.service (dummyservice)]"
                             )
          end

          it 'should contain a systemctl-reload exec' do
            is_expected.to contain_exec('systemd daemon-reload for dummyservice.service (dummyservice)')
                             .with_refreshonly(true)
          end
        end
      end

      context 'when the title includes the unit type and is an override' do
        let(:params) { super().merge(override: true) }
        let(:title) { 'usbstick.device' }

        it { is_expected.to compile }
        it 'should define the parent directory of the override file' do
          is_expected.to contain_file('/etc/systemd/system/usbstick.device.d')
                           .with_ensure('directory')
                           .with_owner('root')
                           .with_group('root')
                           .with_mode('0555')
        end
        it 'should define the systemd override file' do
          is_expected.to contain_file('/etc/systemd/system/usbstick.device.d/puppet-override.conf')
                           .with_ensure('present')
                           .with_mode('0444')
                           .with_owner('root')
                           .with_group('root')
        end
        it 'should contain a systemctl-reload exec' do
          is_expected.to contain_exec('systemd daemon-reload for usbstick.device (usbstick.device)')
                           .with_refreshonly(true)
        end
      end
      context 'when using override filename' do
        let(:params) { super().merge(override: true, override_filename: 'myoverride.conf') }
        let(:title) { 'withcustomoverridefilename.service' }

        it { is_expected.to compile }
        it 'should be able to change the override filename' do
          is_expected.to contain_file('/etc/systemd/system/withcustomoverridefilename.service.d/myoverride.conf')
        end
      end
      context 'when given an override filename without .conf' do
        let(:params) { super().merge(override: true, override_filename: 'overridefile') }
        let(:title) { 'extensionless.service' }
        it { is_expected.to compile }
        it 'appends .conf to the override filename' do
          is_expected.to contain_file('/etc/systemd/system/extensionless.service.d/overridefile.conf')
        end
      end
      context 'when passed a unit name and override' do
        let(:params) { super().merge(override: true, unit: 'bar') }
        let(:title) { 'foo' }
        it { is_expected.to compile }
        it 'appends .conf to the override filename' do
          is_expected.to contain_file('/etc/systemd/system/bar.service.d/puppet-override.conf')
        end
      end
      context 'when passed a unit name, override and override_filename' do
        let(:params) { super().merge(override: true, unit: 'bar', override_filename: 'foobar') }
        let(:title) { 'foo' }
        it { is_expected.to compile }
        it 'appends .conf to the override filename' do
          is_expected.to contain_file('/etc/systemd/system/bar.service.d/foobar.conf')
        end
      end
      context 'when a team' do
        let(:params) { super().merge(team: 'Infrastructure Foundations') }
        it { is_expected.to compile.with_all_deps }
        it do
          is_expected.to contain_file(
            '/var/lib/prometheus/node.d/systemd_unit_dummyservice.service_owner.prom'
          )
            .with_content(
              /systemd_unit_owner\{team="infrastructure-foundations", name="dummyservice\.service"\} 1\.0/
            )
        end
      end
      context 'supports multiple overrides' do
        let(:pre_condition) do
          "systemd::unit { 'first-myservice-override':
            unit => 'myservice',
            content => 'dummy_first',
            override => true,
            override_filename => 'first.conf',
          }"
        end
        context 'when a second override is requested' do
          let(:params) { super().merge(
            override: true, unit: 'myservice', override_filename: 'second.conf')
          }
          let(:title) { 'second-myservice-override' }
          it { is_expected.to compile.with_all_deps }
          it 'has multiple overrides files' do
            is_expected.to contain_exec('systemd daemon-reload for myservice.service (first-myservice-override)')
            is_expected.to contain_exec('systemd daemon-reload for myservice.service (second-myservice-override)')
            is_expected.to contain_file('/etc/systemd/system/myservice.service.d/first.conf')
              .with_content('dummy_first')
              .that_notifies('Exec[systemd daemon-reload for myservice.service (first-myservice-override)]')
            is_expected.to contain_file('/etc/systemd/system/myservice.service.d/second.conf')
              .with_content('dummy')
              .that_notifies('Exec[systemd daemon-reload for myservice.service (second-myservice-override)]')
          end
        end
        context 'when a second override is absented' do
          let(:params) { super().merge(
            override: true, unit: 'myservice', override_filename: 'second.conf', ensure: 'absent')
          }
          it { is_expected.to compile.with_all_deps }
          it 'has a single override file' do
            is_expected.to contain_exec('systemd daemon-reload for myservice.service (first-myservice-override)')
            is_expected.to contain_file('/etc/systemd/system/myservice.service.d/first.conf')
              .with_content('dummy_first')
              .that_notifies('Exec[systemd daemon-reload for myservice.service (first-myservice-override)]')
            is_expected.to contain_file('/etc/systemd/system/myservice.service.d/second.conf')
              .with_ensure('absent')
          end
        end
      end
    end
  end
end
