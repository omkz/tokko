require "rails_helper"
require "open3"

# Runs two real `bin/rails tokko:bootstrap_owner` processes concurrently
# (as two operators would) to exercise the PostgreSQL table lock that
# serializes bootstrap attempts. Uses separate OS processes rather than
# threads sharing one Rake::Task/ENV so each attempt gets its own untouched
# environment and connection, genuinely racing at the database level.
RSpec.describe "tokko:bootstrap_owner concurrency" do
  self.use_transactional_tests = false

  OWNER_A_EMAIL = "owner-a@example.com".freeze
  OWNER_B_EMAIL = "owner-b@example.com".freeze

  let(:valid_password) { "a-very-long-password" }

  around do |example|
    User.where(email_address: [ OWNER_A_EMAIL, OWNER_B_EMAIL ]).delete_all
    example.run
  ensure
    User.where(email_address: [ OWNER_A_EMAIL, OWNER_B_EMAIL ]).delete_all
  end

  def run_bootstrap(email:, password:)
    env = { "TOKKO_OWNER_EMAIL" => email, "TOKKO_OWNER_PASSWORD" => password }
    stdout_str, stderr_str, status = Open3.capture3(
      env, "bin/rails", "tokko:bootstrap_owner", chdir: Rails.root.to_s
    )
    { stdout: stdout_str, stderr: stderr_str, success: status.success? }
  end

  it "lets exactly one of two concurrent bootstrap attempts (different emails) create the owner" do
    password = valid_password
    results = [
      Thread.new { run_bootstrap(email: OWNER_A_EMAIL, password: password) },
      Thread.new { run_bootstrap(email: OWNER_B_EMAIL, password: password) }
    ].map(&:value)

    successes = results.select { |result| result[:success] }
    failures  = results.reject { |result| result[:success] }

    expect(successes.size).to eq(1)
    expect(failures.size).to eq(1)
    expect(failures.first[:stderr]).to include("An owner already exists")

    expect(User.where(role: :owner, email_address: [ OWNER_A_EMAIL, OWNER_B_EMAIL ]).count).to eq(1)
  end
end
