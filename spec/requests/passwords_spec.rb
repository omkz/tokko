require "rails_helper"

RSpec.describe "Passwords", type: :request do
  let(:old_password) { "old-password" }
  let(:user) { create(:user, password: old_password) }
  let(:token) { user.password_reset_token }

  def reset_password(password:, password_confirmation:)
    put password_path(token), params: {
      password: password,
      password_confirmation: password_confirmation
    }
  end

  it "resets the password when password and confirmation match" do
    reset_password(password: "new-password", password_confirmation: "new-password")

    expect(response).to redirect_to(new_session_path)
    expect(flash[:notice]).to eq("Password has been reset.")
    expect(user.reload.authenticate("new-password")).to eq(user)
  end

  it "destroys existing sessions after a successful reset" do
    user.sessions.create!(user_agent: "RSpec", ip_address: "127.0.0.1")

    expect {
      reset_password(password: "new-password", password_confirmation: "new-password")
    }.to change(user.sessions, :count).from(1).to(0)
  end

  it "rejects a mismatched confirmation without changing the password or destroying sessions" do
    existing_session = user.sessions.create!(user_agent: "RSpec", ip_address: "127.0.0.1")
    original_digest = user.password_digest

    reset_password(password: "new-password", password_confirmation: "different-password")

    expect(response).to redirect_to(edit_password_path(token))
    expect(flash[:alert]).to include("Password confirmation doesn't match Password")
    expect(user.reload.password_digest).to eq(original_digest)
    expect(user.authenticate(old_password)).to eq(user)
    expect(existing_session.reload).to be_persisted
  end

  it "rejects a missing password confirmation" do
    put password_path(token), params: { password: "new-password" }

    expect(response).to redirect_to(edit_password_path(token))
    expect(flash[:alert]).to include("Password confirmation can't be blank")
    expect(user.reload.authenticate(old_password)).to eq(user)
  end

  it "rejects a blank password" do
    reset_password(password: "", password_confirmation: "")

    expect(response).to redirect_to(edit_password_path(token))
    expect(flash[:alert]).to include("Password can't be blank")
    expect(user.reload.authenticate(old_password)).to eq(user)
  end

  it "rejects a password longer than bcrypt's 72-byte maximum" do
    password = "é" * 37

    reset_password(password: password, password_confirmation: password)

    expect(response).to redirect_to(edit_password_path(token))
    expect(flash[:alert]).to include("Password is too long")
    expect(user.reload.authenticate(old_password)).to eq(user)
  end
end
