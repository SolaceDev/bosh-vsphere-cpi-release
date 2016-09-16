require 'rspec'
require 'ruby_vim_sdk'

describe 'RetryJudge' do
  subject(:retry_judge) { VimSdk::Soap::RetryJudge.new }

  it 'should allow unfamiliar calls to be retryable' do
    expect(retry_judge.retryable?('some-class', 'some-method')).to be(true), "Expected 'some-klass.some-method' to be retryable, but it's not."
  end

  it 'should not let blacklisted calls be retryable' do
    expect(VimSdk::Soap::RetryJudge::NON_RETRYABLE_METHODS).to_not be_empty
    VimSdk::Soap::RetryJudge::NON_RETRYABLE_METHODS.each do |class_string, methods|
      expect(methods).to_not be_empty
      methods.each do |method|
        expect(retry_judge.retryable?(class_string, method)).to be(false), "Expected '#{class_string}.#{method}' to not be retryable, but it was."
      end
    end
  end

  it 'should blacklist methods that actually exist' do
    VimSdk::Soap::RetryJudge::NON_RETRYABLE_METHODS.each do |class_string, methods|
      klass = Object.const_get(class_string)
      expect(klass).to_not be_nil

      methods.each do |method_name|
        wsdl_method_names = klass.managed_methods.map { |m| m.wsdl_name }
        expect(wsdl_method_names).to include(method_name)
      end
    end
  end
end
