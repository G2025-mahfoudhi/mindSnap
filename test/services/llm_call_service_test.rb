require "test_helper"

class LlmCallServiceTest < ActiveSupport::TestCase
  def stub_post(response)
    original = LlmCallService.method(:post)
    LlmCallService.define_singleton_method(:post) do |_model, _prompt|
      begin
        response.respond_to?(:call) ? response.call : response
      rescue Faraday::Error => e
        Rails.logger.error "LlmCallService Faraday error: #{e.message}"
        nil
      end
    end
    yield
  ensure
    LlmCallService.define_singleton_method(:post, original)
  end

  def response(body:, status: 200)
    r = Faraday::Response.new
    r.define_singleton_method(:body) { body.is_a?(String) ? body : body.to_json }
    r.define_singleton_method(:status) { status }
    r
  end

  test "oneshot retourne le contenu quand le premier modèle réussit" do
    stub_post(response(body: { choices: [{ message: { content: "Un résumé de test." } }] })) do
      assert_equal "Un résumé de test.", LlmCallService.oneshot("Résume ceci.")
    end
  end

  test "oneshot fait du fallback si le premier modèle échoue" do
    calls = 0
    fallback = proc do
      calls += 1
      if calls == 1
        response(body: { error: { message: "rate limited" } }, status: 429)
      else
        response(body: { choices: [{ message: { content: "Fallback OK" } }] })
      end
    end

    stub_post(fallback) do
      assert_equal "Fallback OK", LlmCallService.oneshot("Résume ceci.", model: "custom/model")
    end
  end

  test "oneshot retourne nil si tous les modèles échouent" do
    stub_post(response(body: { error: { message: "rate limited" } }, status: 429)) do
      assert_nil LlmCallService.oneshot("Résume ceci.")
    end
  end

  test "oneshot retourne nil en cas d'erreur réseau" do
    stub_post(proc { raise Faraday::ConnectionFailed, "timeout" }) do
      assert_nil LlmCallService.oneshot("Résume ceci.")
    end
  end

  test "FALLBACK_MODELS contient le modèle payant deepseek" do
    assert_kind_of Array, LlmCallService::FALLBACK_MODELS
    assert_includes LlmCallService::FALLBACK_MODELS, "deepseek/deepseek-v4-flash"
  end
end
