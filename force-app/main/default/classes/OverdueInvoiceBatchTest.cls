/**
 * Tests for OverdueInvoiceBatch and OverdueInvoiceScheduler.
 */
@isTest
private class OverdueInvoiceBatchTest {

    @testSetup
    static void setupData() {
        Account acct = new Account(Name = 'Umbrella Corp');
        insert acct;

        insert new List<Invoice__c>{
            // Sent and past due -> should flip to Overdue.
            new Invoice__c(
                Account__c = acct.Id,
                Status__c = 'Sent',
                Issue_Date__c = Date.today().addDays(-35),
                Due_Date__c = Date.today().addDays(-5)
            ),
            // Sent but not yet due -> should stay Sent.
            new Invoice__c(
                Account__c = acct.Id,
                Status__c = 'Sent',
                Issue_Date__c = Date.today().addDays(-5),
                Due_Date__c = Date.today().addDays(10)
            ),
            // Past due but already Paid -> should stay Paid.
            new Invoice__c(
                Account__c = acct.Id,
                Status__c = 'Paid',
                Issue_Date__c = Date.today().addDays(-60),
                Due_Date__c = Date.today().addDays(-30)
            )
        };
    }

    @isTest
    static void batchFlipsOnlyPastDueSentInvoices() {
        Test.startTest();
        Database.executeBatch(new OverdueInvoiceBatch(), 200);
        Test.stopTest();

        List<Invoice__c> invoices = [
            SELECT Status__c, Due_Date__c FROM Invoice__c ORDER BY Due_Date__c ASC
        ];
        // Ordered by due date: Paid (-30) first, flipped (-5), still Sent (+10).
        Assert.areEqual('Paid', invoices[0].Status__c,
            'Paid invoices must not be touched.');
        Assert.areEqual('Overdue', invoices[1].Status__c,
            'Past-due Sent invoice should become Overdue.');
        Assert.areEqual('Sent', invoices[2].Status__c,
            'Not-yet-due Sent invoice should stay Sent.');

        // finish() ran inside the batch's own async context during stopTest(),
        // whose email invocations are not visible to this test's Limits.
        // Invoke finish() directly here (it ignores its context argument) to
        // verify the summary email in this context.
        Integer emailsBefore = Limits.getEmailInvocations();
        new OverdueInvoiceBatch().finish(null);
        Assert.areEqual(emailsBefore + 1, Limits.getEmailInvocations(),
            'finish() should send exactly one summary email.');
    }

    @isTest
    static void schedulerExecutesBatch() {
        Test.startTest();
        new OverdueInvoiceScheduler().execute(null);
        Test.stopTest();

        Integer overdueCount = [
            SELECT COUNT() FROM Invoice__c WHERE Status__c = 'Overdue'
        ];
        Assert.areEqual(1, overdueCount,
            'Scheduler should run the batch and flip the past-due invoice.');
    }

    @isTest
    static void schedulerCanBeScheduledWithNightlyCron() {
        Test.startTest();
        Id jobId = System.schedule(
            'Test Overdue Invoice Job',
            OverdueInvoiceScheduler.getNightlyCronExpression(),
            new OverdueInvoiceScheduler()
        );
        Test.stopTest();

        Assert.isNotNull(jobId);
        CronTrigger ct = [
            SELECT Id, CronExpression FROM CronTrigger WHERE Id = :jobId
        ];
        Assert.areEqual('0 0 1 * * ?', ct.CronExpression);
    }
}
