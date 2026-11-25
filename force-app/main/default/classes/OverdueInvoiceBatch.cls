/**
 * OverdueInvoiceBatch
 * Nightly batch that moves Sent invoices past their due date to Overdue.
 *
 * start()  - Sent invoices with Due_Date__c before today.
 * execute()- flips Status__c to Overdue and counts them (Database.Stateful
 *            keeps the running total across chunks).
 * finish() - emails a one-line summary to the running user.
 */
public with sharing class OverdueInvoiceBatch
        implements Database.Batchable<sObject>, Database.Stateful {

    /** Running total of invoices flipped to Overdue, kept across chunks. */
    public Integer recordsProcessed = 0;

    public Database.QueryLocator start(Database.BatchableContext bc) {
        String query =
            'SELECT Id, Status__c, Due_Date__c ' +
            'FROM Invoice__c ' +
            'WHERE Status__c = \'Sent\' AND Due_Date__c < TODAY';
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext bc, List<Invoice__c> scope) {
        for (Invoice__c inv : scope) {
            inv.Status__c = 'Overdue';
        }
        update scope;
        recordsProcessed += scope.size();
    }

    public void finish(Database.BatchableContext bc) {
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new String[]{ UserInfo.getUserEmail() });
        mail.setSubject('Overdue Invoice Batch Complete');
        mail.setPlainTextBody(
            'The overdue invoice batch has finished. ' +
            recordsProcessed +
            ' invoice(s) were moved from Sent to Overdue.'
        );
        mail.setSaveAsActivity(false);
        Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ mail });
    }
}
