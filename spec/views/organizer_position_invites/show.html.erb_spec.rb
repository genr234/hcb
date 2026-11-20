# frozen_string_literal: true

require "rails_helper"

RSpec.describe "organizer_position_invites/show" do
  let(:event) { create(:event) }
  let(:signee) { create(:user) }
  let(:invite) { create(:organizer_position_invite, event:, user: signee) }

  before do
    allow(User).to receive(:system_user).and_return(create(:user, email: User::SYSTEM_USER_EMAIL))
  end

  # Parties can only be added while a contract is pending, so build the
  # contract, add its parties, and only then move it to sent.
  def send_contract(cosigner: false)
    contract = Contract::FiscalSponsorship.create!(contractable: invite, include_videos: false)
    contract.parties.create!(user: signee, role: :signee)
    contract.parties.create!(role: :cosigner, external_email: "parent@example.com") if cosigner
    contract.update_column(:aasm_state, "sent")
    contract
  end

  def sign(party)
    party.update_column(:aasm_state, "signed")
  end

  def render_page
    assign(:invite, invite)
    assign(:organizers, event.organizer_positions.includes(:user))
    render template: "organizer_position_invites/show"
  end

  it "asks the signee to sign the agreement" do
    contract = send_contract
    render_page

    expect(rendered).to include("Sign the fiscal sponsorship agreement to join")
    expect(rendered).to include(contract_party_path(contract.party(:signee)))
  end

  it "tells the signee that their parent or legal guardian signs next" do
    contract = send_contract(cosigner: true)
    sign(contract.party(:signee))
    render_page

    expect(rendered).to include("Waiting for your parent or legal guardian to sign")
    expect(rendered).to include("parent@example.com")
    expect(rendered).not_to include("Sign agreement")
  end

  it "tells the signee that the agreement is under review once only HCB has left to sign" do
    contract = send_contract(cosigner: true)
    sign(contract.party(:signee))
    sign(contract.party(:cosigner))
    render_page

    expect(rendered).to include("Your agreement is under review")
    expect(rendered).to include("View signed agreement")
    expect(rendered).not_to include("Sign the fiscal sponsorship agreement")
    expect(rendered).not_to include("Waiting for your parent")
  end
end
