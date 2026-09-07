require "rails_helper"

RSpec.describe "ApplicationController error context", type: :request do
  it "sets privacy-minimal request context before each request" do
    captured_context = nil
    allow(Rails.error).to receive(:set_context) { |context| captured_context = context }

    get root_path

    expect(captured_context).to include(controller_name: "home", action_name: "index")
    expect(captured_context[:request_id]).to be_present
    expect(captured_context.keys).to contain_exactly(:request_id, :controller_name, :action_name)
  end
end
