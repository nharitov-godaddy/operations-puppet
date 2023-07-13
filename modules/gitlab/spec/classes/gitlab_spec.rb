# SPDX-License-Identifier: Apache-2.0
require_relative '../../../../rake_modules/spec_helper'

describe 'gitlab' do
  on_supported_os(WMFConfig.test_on(10)).each do |os, facts|
    context "on #{os}" do
      let(:facts) { facts }
      describe 'default run' do
        it { is_expected.to compile.with_all_deps }
      end
      describe 'with cas provider' do
        let(:params) {{ omniauth_providers: {'cas' => {'url' => 'https://cas.example.org/cas'}} }}
        it { is_expected.to compile.with_all_deps }
      end
      describe 'with cas provider' do
        let(:params) do
          {
            omniauth_providers: {
              'oidc' => {
                'issuer' => 'https://cas.example.org/cas',
                'client_options' => {
                  'identifier' => 'Gitlab',
                  'redirect_uri' => 'https://gitlab.example.org/users/auth/openid_connect/callback',
                  'secret' => 'SECRET'
                }
              }
            }
          }
        end
        it { is_expected.to compile.with_all_deps }
      end
    end
  end
end
