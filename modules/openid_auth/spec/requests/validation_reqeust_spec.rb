# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Validated Token API endpoint', type: :request, skip_emis: true do
  include SchemaMatchers

  let(:token) { 'token' }
  let(:jwt) do
    [{
      'ver' => 1,
      'jti' => 'AT.04f_GBSkMkWYbLgG5joGNlApqUthsZnYXhiyPc_5KZ0',
      'iss' => 'https://example.com/oauth2/default',
      'aud' => 'api://default',
      'iat' => Time.current.utc.to_i,
      'exp' => Time.current.utc.to_i + 3600,
      'cid' => '0oa1c01m77heEXUZt2p7',
      'uid' => '00u1zlqhuo3yLa2Xs2p7',
      'scp' => %w[profile email openid veteran_status.read],
      'sub' => 'ae9ff5f4e4b741389904087d94cd19b2'
    }, {
      'kid' => '1Z0tNc4Hxs_n7ySgwb6YT8JgWpq0wezqupEg136FZHU',
      'alg' => 'RS256'
    }]
  end
  let(:json_api_response) do
    {
        "data" => {
            "id" => "AT.04f_GBSkMkWYbLgG5joGNlApqUthsZnYXhiyPc_5KZ0",
            "type" => "validated_token",
            "attributes" => {
                "ver" => 1,
                "jti" => "AT.04f_GBSkMkWYbLgG5joGNlApqUthsZnYXhiyPc_5KZ0",
                "iss" => "https://example.com/oauth2/default",
                "aud" => "api://default",
                "iat" => 1541453784,
                "exp" => 1541457384,
                "cid" => "0oa1c01m77heEXUZt2p7",
                "uid" => "00u1zlqhuo3yLa2Xs2p7",
                "scp" => [
                    "profile",
                    "email",
                    "openid",
                    "veteran_status.read"
                ],
                "sub" => "ae9ff5f4e4b741389904087d94cd19b2",
                "va_identifiers" => {
                    "icn" => "73806470379396828"
                }
            }
        }
    }
  end
  let(:auth_header) { { 'Authorization' => "Bearer #{token}" } }
  let(:user) { build(:user, :loa3) }

  before(:each) do
    allow(JWT).to receive(:decode).and_return(jwt)
    Session.create(uuid: user.uuid, token: token)
    User.create(user)
  end

  context 'with valid responses' do
    it 'should return true if the user is a veteran' do
      with_okta_configured do
        get '/internal/auth/v0/validation', nil, auth_header
        expect(response).to have_http_status(:ok)
        expect(response.body).to be_a(String)
        expect(JSON.parse(response.body)['data']['attributes'].keys).to eq(json_api_response['data']['attributes'].keys)
      end
    end
  end

#   context 'when a response is invalid' do
#     it 'should match the errors schema', :aggregate_failures do
#       with_okta_configured do
#         get '/internal/auth/v0/validation', nil, auth_header

#         expect(response).to have_http_status(:bad_gateway)
#         expect(response).to match_response_schema('errors')
#         expect(JSON.parse(response.body)['errors'].first['code']).to eq 'AUTH_STATUS502'
#       end
#     end
#   end
end