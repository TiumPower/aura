ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    include FactoryBot::Syntax::Methods

    # Run a block with a tenant set (acts_as_tenant).
    def with_tenant(ws, &blk) = ActsAsTenant.with_tenant(ws, &blk)

    # Đọc mã ngay trên challenge mà luồng vừa phát ra, thay vì để từng test tự
    # biết cột nào giữ identifier.
    def otp_code_for(identifier, workspace: nil, purpose: "login", scope: "customer")
      otp_challenge_for(identifier, workspace: workspace, purpose: purpose, scope: scope)&.code
    end

    def otp_challenge_for(identifier, workspace: nil, purpose: "login", scope: "customer")
      OtpChallenge.unscoped
                  .where(workspace_id: workspace&.id, scope: scope, purpose: purpose,
                         identifier: OtpChallenge.normalize(identifier))
                  .order(:id).last
    end
  end
end

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  # The landlord app resolves its workspace from the subdomain.
  def host_workspace!(ws) = host! "#{ws.subdomain}.example.com"
end
