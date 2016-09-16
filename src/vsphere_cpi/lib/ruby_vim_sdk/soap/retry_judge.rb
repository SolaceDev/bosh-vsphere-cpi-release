module VimSdk
  module Soap
    class RetryJudge
      NON_RETRYABLE_METHODS = {
        'VimSdk::Vim::VirtualDiskManager' => [
          'MoveVirtualDisk_Task', # moving persistent data would be dangerous to retry
        ],
        'VimSdk::Vim::VirtualMachine' => [
          'ReconfigVM_Task', # this call is involved in many sensitive operations: attach_disk, detach_disk, modify vApp props
          'RelocateVM_Task', # only call by tests, not by CPI; leave in blacklist as it moves disks
        ],
        'VimSdk::Vim::CustomFieldsManager' => [
          'AddCustomFieldDef', # CPI always calls add_field_definition even if it exists to avoid race condition
          'SetField', # used in set_vm_metadata, failure is only cosmetic, don't retry
        ],
      }

      def retryable?(class_name, method_name)
        if NON_RETRYABLE_METHODS.key?(class_name)
          ( NON_RETRYABLE_METHODS[class_name].include?(method_name) == false )
        else
          true
        end
      end
    end
  end
end
