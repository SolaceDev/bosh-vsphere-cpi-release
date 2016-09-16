module VimSdk
  module Soap

    class RetryableStubAdapter
      PC = Vmodl::Query::PropertyCollector

      MAX_RETRIES = 5
      RETRY_INTERVAL_CAP_SEC = 32

      def initialize(stub_adapter, retry_judge=nil)
        @stub_adapter = stub_adapter
        @retry_judge = retry_judge || RetryJudge.new
      end

      def invoke_method(managed_object, method_info, arguments)
        result = nil
        MAX_RETRIES.times do |i|
          status, object = @stub_adapter.invoke_method(managed_object, method_info, arguments, self)

          err = nil
          if status.between?(200, 299)
            result = object
          elsif object.kind_of?(Vmodl::MethodFault)
            err = SoapError.new(object.msg, object)
          else
            err = SoapError.new('Unknown SOAP fault', object)
          end

          if err
            if i < (MAX_RETRIES - 1) && @retry_judge.retryable?(managed_object, method_info.wsdl_name)
              sleep([(2**i), RETRY_INTERVAL_CAP_SEC].min)
            else
              raise err
            end
          else
            break
          end
        end
        result
      end

      def invoke_property(managed_object, property_info)
        @stub_adapter.invoke_property(managed_object, property_info, self)
      end

      def version
        @stub_adapter.version
      end
    end
  end
end
