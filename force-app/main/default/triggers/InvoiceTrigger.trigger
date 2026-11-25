/**
 * InvoiceTrigger
 * Thin trigger on Invoice__c. All logic lives in InvoiceTriggerHandler so it
 * stays bulkified, testable, and out of the trigger body.
 */
trigger InvoiceTrigger on Invoice__c (before update, after update) {
    InvoiceTriggerHandler handler = new InvoiceTriggerHandler();

    if (Trigger.isBefore && Trigger.isUpdate) {
        handler.beforeUpdate(Trigger.new, Trigger.oldMap);
    }
    if (Trigger.isAfter && Trigger.isUpdate) {
        handler.afterUpdate(Trigger.new, Trigger.oldMap);
    }
}
