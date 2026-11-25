/**
 * InvoiceTriggerHandler
 * All trigger logic for Invoice__c, kept out of the trigger itself.
 *
 * Rules implemented in before update:
 *  1. The first time an invoice's status becomes Sent, stamp Issue_Date__c
 *     with today's date (only if it is not already set).
 *  2. An invoice whose Total_Amount__c is null or 0 cannot be moved to Paid;
 *     the save is blocked with addError so the user sees the message inline.
 */
public with sharing class InvoiceTriggerHandler {

    public void beforeUpdate(List<Invoice__c> newInvoices, Map<Id, Invoice__c> oldMap) {
        for (Invoice__c inv : newInvoices) {
            Invoice__c oldInv = oldMap.get(inv.Id);

            // Rule 1: stamp the issue date on first send.
            if (inv.Status__c == 'Sent'
                    && oldInv != null
                    && oldInv.Status__c != 'Sent'
                    && inv.Issue_Date__c == null) {
                inv.Issue_Date__c = Date.today();
            }

            // Rule 2: nothing billed = nothing to pay.
            if (inv.Status__c == 'Paid'
                    && (inv.Total_Amount__c == null || inv.Total_Amount__c == 0)) {
                inv.addError(
                    'An invoice with a total of 0 cannot be marked as Paid. ' +
                    'Add line items before recording payment.'
                );
            }
        }
    }

    /**
     * Extension point for future after-update automation (status-change
     * notifications, integrations). Intentionally empty today so the
     * framework shape is in place without speculative logic.
     */
    public void afterUpdate(List<Invoice__c> newInvoices, Map<Id, Invoice__c> oldMap) {
        // No after-update logic yet.
    }
}
