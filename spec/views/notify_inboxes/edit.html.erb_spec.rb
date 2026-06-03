require 'rails_helper'

RSpec.describe "notify_inboxes/edit", type: :view do
  let(:notify_inbox) {
    NotifyInbox.create!(
      title: "MyString",
      service_url: "MyString",
      api_key: "MyString",
      target_urls: "MyText",
      status: false
    )
  }

  before(:each) do
    assign(:notify_inbox, notify_inbox)
  end

  it "renders the edit notify_inbox form" do
    render

    assert_select "form[action=?][method=?]", notify_inbox_path(notify_inbox), "post" do

      assert_select "input[name=?]", "notify_inbox[title]"

      assert_select "input[name=?]", "notify_inbox[service_url]"

      assert_select "input[name=?]", "notify_inbox[api_key]"

      assert_select "textarea[name=?]", "notify_inbox[target_urls]"

      assert_select "input[name=?]", "notify_inbox[status]"
    end
  end
end
