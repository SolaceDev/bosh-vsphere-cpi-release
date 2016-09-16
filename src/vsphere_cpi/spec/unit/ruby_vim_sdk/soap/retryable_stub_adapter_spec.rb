require 'rspec'
require 'ruby_vim_sdk'

describe 'RetryableStubAdapter' do
  subject(:retryable_stub_adapter) do
    VimSdk::Soap::RetryableStubAdapter.new(stub_adapter, retry_judge)
  end

  let(:stub_adapter) { instance_double(VimSdk::Soap::StubAdapter) }
  let(:soap_result) { double('some-soap-object') }
  let(:managed_object) { double('some-managed-object') }
  let(:method_info) { double('some-method-info', wsdl_name: 'some-wsdl-name') }
  let(:method_args) { nil }
  let(:retry_judge) { instance_double(VimSdk::Soap::RetryJudge) }

  describe '#invoke_method' do
    context 'When the status is "2xx"' do
      let(:soap_status) { 200 + rand(100) }

      it 'should return the SOAP object result' do
        expect(stub_adapter).to receive(:invoke_method)
                                  .once
                                  .with(managed_object, method_info, method_args, retryable_stub_adapter)
                                  .and_return([soap_status, soap_result])
        expect(retryable_stub_adapter.invoke_method(managed_object, method_info, method_args)).to be soap_result
      end
    end

    context 'When the status is "5xx" and the call is retryable' do
      let(:soap_status) { 500 + rand(100) }
      let(:soap_result) { double('fake-soap-error') }

      before(:each) do
        allow(retry_judge).to receive(:retryable?)
                                .with(managed_object, method_info.wsdl_name)
                                .and_return(true)
      end

      it 'should try the SOAP operation 5 times' do
        expect(retryable_stub_adapter).to receive(:sleep).with(1).once
        expect(retryable_stub_adapter).to receive(:sleep).with(2).once
        expect(retryable_stub_adapter).to receive(:sleep).with(4).once
        expect(retryable_stub_adapter).to receive(:sleep).with(8).once

        expect(stub_adapter).to receive(:invoke_method)
                                  .exactly(VimSdk::Soap::RetryableStubAdapter::MAX_RETRIES).times
                                  .with(managed_object, method_info, method_args, retryable_stub_adapter)
                                  .and_return([soap_status, soap_result])
        expect {
          retryable_stub_adapter.invoke_method(managed_object, method_info, method_args)
        }.to raise_error(VimSdk::SoapError, 'Unknown SOAP fault')
      end
    end

    context 'When the status is "5xx" and the call is NOT retryable' do
      let(:soap_status) { 500 + rand(100) }
      let(:soap_result) { double('fake-soap-error') }

      before(:each) do
        allow(retry_judge).to receive(:retryable?)
                                .with(managed_object, method_info.wsdl_name)
                                .and_return(false)
      end

      it 'should not retry the SOAP operation' do
        expect(stub_adapter).to receive(:invoke_method)
                                  .once
                                  .with(managed_object, method_info, method_args, retryable_stub_adapter)
                                  .and_return([soap_status, soap_result])
        expect {
          retryable_stub_adapter.invoke_method(managed_object, method_info, method_args)
        }.to raise_error(VimSdk::SoapError, 'Unknown SOAP fault')
      end
    end

    context 'When the status is initially "5xx", but changes to "2xx"' do
      let(:initial_soap_status) { 500 + rand(100) }
      let(:final_soap_status) { 200 + rand(100) }
      let(:initial_soap_result) { double('fake-soap-error') }
      let(:final_soap_result) { double('some-soap-object') }

      before(:each) do
        allow(retry_judge).to receive(:retryable?)
                                .with(managed_object, method_info.wsdl_name)
                                .and_return(true)
      end

      it 'should retry the SOAP operation until it succeeds' do
        expect(retryable_stub_adapter).to receive(:sleep).with(1).once
        call_count = 0
        expect(stub_adapter).to receive(:invoke_method)
                                  .twice
                                  .with(managed_object, method_info, method_args, retryable_stub_adapter) do
          if call_count == 0
            call_count += 1
            [initial_soap_status, initial_soap_result]
          else
            [final_soap_status, final_soap_result]
          end
        end

        expect(retryable_stub_adapter.invoke_method(managed_object, method_info, method_args)).to be(final_soap_result)
      end
    end
  end

  describe '#invoke_property' do
    let(:property_info) { double('some-property-info') }

    it 'delegates to the wrapped stub_adapter' do
      expect(stub_adapter).to receive(:invoke_property)
        .with(managed_object, property_info, retryable_stub_adapter)
        .once.and_return('some-property')
      expect(retryable_stub_adapter.invoke_property(managed_object, property_info)).to eq('some-property')
    end
  end

  describe '#version' do
    it 'delegates to the wrapped stub_adapter' do
      expect(stub_adapter).to receive(:version).once.and_return('some-version')

      expect(retryable_stub_adapter.version).to eq('some-version')
    end
  end
end
