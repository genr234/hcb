# frozen_string_literal: true

require "rails_helper"

RSpec.describe Maintenance::FreezeDemoModeEventsTask do
  include ActiveJob::TestHelper

  it "freezes demo organizations when run" do
    demo = create(:event, demo_mode: true)
    deleted_demo = create(:event, demo_mode: true)
    deleted_demo.destroy!
    regular = create(:event)

    perform_enqueued_jobs do
      MaintenanceTasks::Runner.run(name: described_class.name)
    end

    expect(MaintenanceTasks::Run.last.status).to eq("succeeded")
    expect(demo.reload).to be_financially_frozen
    expect(Event.with_deleted.find(deleted_demo.id)).to be_financially_frozen
    expect(regular.reload).not_to be_financially_frozen
  end
end
