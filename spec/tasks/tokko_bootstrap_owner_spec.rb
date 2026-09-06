require "rails_helper"
require "rake"

RSpec.describe "tokko:bootstrap_owner" do
  before(:all) do
    Rails.application.load_tasks unless Rake::Task.task_defined?("tokko:bootstrap_owner")
  end

  let(:task) { Rake::Task["tokko:bootstrap_owner"] }

  before { task.reenable }

  around do |example|
    original_email = ENV["TOKKO_OWNER_EMAIL"]
    original_password = ENV["TOKKO_OWNER_PASSWORD"]
    example.run
  ensure
    ENV["TOKKO_OWNER_EMAIL"] = original_email
    ENV["TOKKO_OWNER_PASSWORD"] = original_password
  end

  let(:valid_password) { "a-very-long-password" }

  def run_task
    task.invoke
  end

  def capture(stream)
    original = stream == :stdout ? $stdout : $stderr
    replacement = StringIO.new
    stream == :stdout ? ($stdout = replacement) : ($stderr = replacement)
    yield
    replacement.string
  ensure
    stream == :stdout ? ($stdout = original) : ($stderr = original)
  end

  it "fails when TOKKO_OWNER_EMAIL is missing" do
    ENV.delete("TOKKO_OWNER_EMAIL")
    ENV["TOKKO_OWNER_PASSWORD"] = valid_password

    expect { run_task }.to raise_error(SystemExit)
    expect(User.exists?).to be(false)
  end

  it "fails when TOKKO_OWNER_PASSWORD is missing" do
    ENV["TOKKO_OWNER_EMAIL"] = "owner@example.com"
    ENV.delete("TOKKO_OWNER_PASSWORD")

    expect { run_task }.to raise_error(SystemExit)
    expect(User.exists?).to be(false)
  end

  it "fails when the password is shorter than 12 characters" do
    ENV["TOKKO_OWNER_EMAIL"] = "owner@example.com"
    ENV["TOKKO_OWNER_PASSWORD"] = "short1234567"[0, 11]

    expect { run_task }.to raise_error(SystemExit)
    expect(User.exists?).to be(false)
  end

  it "does not modify existing users when it fails" do
    existing = create(:user, role: :customer)
    ENV["TOKKO_OWNER_EMAIL"] = "owner@example.com"
    ENV.delete("TOKKO_OWNER_PASSWORD")

    expect { run_task }.to raise_error(SystemExit)
    expect(existing.reload.role).to eq("customer")
  end

  it "creates an owner with the given email and role on valid input" do
    ENV["TOKKO_OWNER_EMAIL"] = "owner@example.com"
    ENV["TOKKO_OWNER_PASSWORD"] = valid_password

    run_task

    owner = User.find_by(email_address: "owner@example.com")
    expect(owner).to be_present
    expect(owner).to be_owner
    expect(owner.authenticate(valid_password)).to eq(owner)
  end

  it "is safe to rerun for the same email and can update the password" do
    ENV["TOKKO_OWNER_EMAIL"] = "owner@example.com"
    ENV["TOKKO_OWNER_PASSWORD"] = valid_password
    run_task

    task.reenable
    new_password = "a-different-long-password"
    ENV["TOKKO_OWNER_PASSWORD"] = new_password

    expect { run_task }.not_to change(User, :count)

    owner = User.find_by(email_address: "owner@example.com")
    expect(owner).to be_owner
    expect(owner.authenticate(new_password)).to eq(owner)
  end

  it "refuses to create a second owner under a different email" do
    create(:user, role: :owner, email_address: "existing-owner@example.com")

    ENV["TOKKO_OWNER_EMAIL"] = "new-owner@example.com"
    ENV["TOKKO_OWNER_PASSWORD"] = valid_password

    expect { run_task }.to raise_error(SystemExit)
    expect(User.exists?(email_address: "new-owner@example.com")).to be(false)
  end

  it "never prints the password" do
    ENV["TOKKO_OWNER_EMAIL"] = "owner@example.com"
    ENV["TOKKO_OWNER_PASSWORD"] = valid_password

    stdout = capture(:stdout) { run_task }

    expect(stdout).not_to include(valid_password)
    expect(stdout).to include("Owner ready: owner@example.com")
  end

  it "never prints the password in failure output" do
    ENV["TOKKO_OWNER_EMAIL"] = "owner@example.com"
    ENV["TOKKO_OWNER_PASSWORD"] = "short1234567"[0, 11]

    stderr = capture(:stderr) do
      expect { run_task }.to raise_error(SystemExit)
    end

    expect(stderr).not_to include(ENV["TOKKO_OWNER_PASSWORD"])
  end
end
