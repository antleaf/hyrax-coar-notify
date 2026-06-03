require 'rails_helper'

RSpec.describe "notify_inboxes/index", type: :view do
  before(:each) do
    assign(:notify_inboxes, [
      NotifyInbox.create!(
        title: "Title",
        service_url: "Service Url",
        api_key: "API Key",
        target_urls: "MyText",
        status: false
      ),
      NotifyInbox.create!(
        title: "Title",
        service_url: "Service Url",
        api_key: "API Key",
        target_urls: "MyText",
        status: false
      )
    ])
  end

  it "renders a list of notify_inboxes" do
    render
    cell_selector = 'div>p'
    assert_select cell_selector, text: Regexp.new("Title".to_s), count: 2
    assert_select cell_selector, text: Regexp.new("Service Url".to_s), count: 2
    assert_select cell_selector, text: Regexp.new("API Key".to_s), count: 2
    assert_select cell_selector, text: Regexp.new("MyText".to_s), count: 2
    assert_select cell_selector, text: Regexp.new(false.to_s), count: 2
  end
end
