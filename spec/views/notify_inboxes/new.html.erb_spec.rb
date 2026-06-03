require 'rails_helper'

RSpec.describe "notify_inboxes/new", type: :view do
  before(:each) do
    assign(:notify_inbox, NotifyInbox.new(
      title: "MyString",
      service_url: "MyString",
      api_key: "MyString",
      target_urls: "MyText",
      status: false
    ))
  end

  it "renders new notify_inbox form" do
    render

    assert_select "form[action=?][method=?]", notify_inboxes_path, "post" do

      assert_select "input[name=?]", "notify_inbox[title]"

      assert_select "input[name=?]", "notify_inbox[service_url]"

      assert_select "input[name=?]", "notify_inbox[api_key]"

      assert_select "textarea[name=?]", "notify_inbox[target_urls]"

      assert_select "input[name=?]", "notify_inbox[status]"
    end
  end
end
