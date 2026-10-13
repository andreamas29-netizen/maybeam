class Provider::Anthropic < Provider
  include InvestmentAdvisorConcept

  # Subclass so errors caught in this provider are raised as Provider::Anthropic::Error
  Error = Class.new(Provider::Error)

  DEFAULT_MODEL = "claude-opus-5-5"

  # Web search runs in a server-side loop that can pause; we resume it a bounded number of times
  MAX_CONTINUATIONS = 5
  MAX_SEARCHES_PER_REQUEST = 8

  attr_reader :model

  def initialize(api_key, model: DEFAULT_MODEL)
    @client = ::Anthropic::Client.new(api_key: api_key)
    @model = model
  end

  def research(prompt:, instructions:)
    with_provider_response do
      messages = [ { role: "user", content: prompt } ]
      responses = []

      MAX_CONTINUATIONS.times do
        response = create_message(
          instructions: instructions,
          messages: messages,
          tools: [ web_search_tool ],
          output_config: { effort: "medium" }
        )

        responses << response
        break unless response.stop_reason == :pause_turn

        # The server resumes its search loop when it sees its own paused turn at the end
        messages += [ { role: "assistant", content: response.content.map(&:to_h) } ]
      end

      ResearchReport.new(
        text: responses.flat_map { |r| text_blocks(r) }.join.strip,
        sources: responses.flat_map { |r| sources(r) }.uniq(&:url)
      )
    end
  end

  def structured_response(prompt:, instructions:, schema:)
    with_provider_response do
      response = create_message(
        instructions: instructions,
        messages: [ { role: "user", content: prompt } ],
        output_config: {
          effort: "high",
          format: { type: "json_schema", schema: schema }
        }
      )

      JSON.parse(text_blocks(response).join)
    end
  end

  private
    attr_reader :client

    def create_message(instructions:, messages:, output_config:, tools: [])
      response = client.beta.messages.create(
        model: model,
        max_tokens: 16_000,
        system_: instructions,
        messages: messages,
        tools: tools,
        output_config: output_config,
        # On a safety decline, the API re-runs the request on a fallback model it picks
        fallbacks: "default",
        betas: [ "server-side-fallback-2026-07-01" ]
      )

      raise Error, "The model declined to answer this request" if response.stop_reason == :refusal
      raise Error, "The model ran out of output tokens" if response.stop_reason == :max_tokens

      response
    end

    def web_search_tool
      { type: "web_search_20260209", name: "web_search", max_uses: MAX_SEARCHES_PER_REQUEST }
    end

    def text_blocks(response)
      response.content.select { |block| block.type == :text }.map(&:text)
    end

    def sources(response)
      response.content
        .select { |block| block.type == :web_search_tool_result }
        .flat_map do |block|
          # On error, content is a single error object instead of a list of results
          next [] unless block.content.is_a?(Array)

          block.content.map { |result| Source.new(title: result.title, url: result.url) }
        end
    end
end
