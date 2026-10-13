require "test_helper"

class Provider::AnthropicTest < ActiveSupport::TestCase
  setup do
    @provider = Provider::Anthropic.new("test-key")
    @messages = mock
    Anthropic::Client.any_instance.stubs(:beta).returns(OpenStruct.new(messages: @messages))
  end

  test "research resumes paused web searches and collects text and sources" do
    paused = api_message(:pause_turn, [ search_result("Apple IR", "https://investor.apple.com"), text("Part one. ") ])
    finished = api_message(:end_turn, [ search_result("Apple IR", "https://investor.apple.com"), text("Part two.") ])

    @messages.expects(:create).twice.returns(paused).then.returns(finished)

    response = @provider.research(prompt: "AAPL", instructions: "Research")

    assert response.success?
    assert_equal "Part one. Part two.", response.data.text
    assert_equal [ "https://investor.apple.com" ], response.data.sources.map(&:url)
  end

  test "structured response parses JSON" do
    @messages.expects(:create).with do |params|
      params[:output_config][:format][:type] == "json_schema" && params[:fallbacks] == "default"
    end.returns(api_message(:end_turn, [ text('{"summary":"ok"}') ]))

    response = @provider.structured_response(prompt: "p", instructions: "i", schema: {})

    assert_equal({ "summary" => "ok" }, response.data)
  end

  test "refusals are errors" do
    @messages.stubs(:create).returns(api_message(:refusal, []))

    response = @provider.structured_response(prompt: "p", instructions: "i", schema: {})

    refute response.success?
    assert_instance_of Provider::Anthropic::Error, response.error
  end

  private
    def api_message(stop_reason, content)
      OpenStruct.new(stop_reason: stop_reason, content: content)
    end

    def text(value)
      OpenStruct.new(type: :text, text: value, to_h: { type: "text", text: value })
    end

    def search_result(title, url)
      OpenStruct.new(type: :web_search_tool_result, content: [ OpenStruct.new(title: title, url: url) ], to_h: {})
    end
end
