require 'rails_helper'

RSpec.describe "notify_inboxes/show", type: :view do
  before(:each) do
    assign(:notify_inbox, NotifyInbox.create!(
      title: "Title",
      service_url: "Service Url",
      api_key: "API Key",
      target_urls: "MyText",
      status: false
    ))
  end

  it "renders attributes in <p>" do
    render
    expect(rendered).to match(/Title/)
    expect(rendered).to match(/Service Url/)
    expect(rendered).to match(/API Key/)
    expect(rendered).to match(/MyText/)
    expect(rendered).to match(/false/)
  end
end
