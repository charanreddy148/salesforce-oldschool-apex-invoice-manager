/**
 * Tests for the Invoice__c status automation in InvoiceTriggerHandler.
 */
@isTest
private class InvoiceTriggerHandlerTest {

    @testSetup
    static void setupData() {
        Account acct = new Account(Name = 'Acme Corp');
        insert acct;

        // Invoice WITH line items -> Total_Amount__c rolls up to 250.
        Invoice__c withLines = new Invoice__c(
            Account__c = acct.Id,
            Status__c = 'Draft',
            Due_Date__c = Date.today().addDays(30)
        );
        // Invoice with NO line items -> Total_Amount__c rolls up to 0.
        Invoice__c empty = new Invoice__c(
            Account__c = acct.Id,
            Status__c = 'Draft',
            Due_Date__c = Date.today().addDays(30)
        );
        insert new List<Invoice__c>{ withLines, empty };

        insert new List<Invoice_Line__c>{
            new Invoice_Line__c(
                Invoice__c = withLines.Id,
                Product_Name__c = 'Consulting (hours)',
                Quantity__c = 2,
                Unit_Price__c = 100
            ),
            new Invoice_Line__c(
                Invoice__c = withLines.Id,
                Product_Name__c = 'Support plan',
                Quantity__c = 1,
                Unit_Price__c = 50
            )
        };
    }

    private static Invoice__c getInvoiceWithLines() {
        return [
            SELECT Id, Status__c, Issue_Date__c, Total_Amount__c
            FROM Invoice__c
            WHERE Total_Amount__c > 0
            LIMIT 1
        ];
    }

    private static Invoice__c getEmptyInvoice() {
        return [
            SELECT Id, Status__c, Issue_Date__c, Total_Amount__c
            FROM Invoice__c
            WHERE Total_Amount__c = 0
            LIMIT 1
        ];
    }

    @isTest
    static void issueDateIsStampedFirstTimeInvoiceIsSent() {
        Invoice__c inv = getInvoiceWithLines();
        Assert.isNull(inv.Issue_Date__c, 'Issue date should start blank.');

        inv.Status__c = 'Sent';
        update inv;

        Invoice__c after = [
            SELECT Status__c, Issue_Date__c FROM Invoice__c WHERE Id = :inv.Id
        ];
        Assert.areEqual('Sent', after.Status__c);
        Assert.areEqual(Date.today(), after.Issue_Date__c,
            'Issue date should be stamped with today when first sent.');
    }

    @isTest
    static void existingIssueDateIsNotOverwritten() {
        Invoice__c inv = getInvoiceWithLines();
        Date original = Date.today().addDays(-10);
        inv.Issue_Date__c = original;
        inv.Status__c = 'Sent';
        update inv;

        Invoice__c after = [
            SELECT Issue_Date__c FROM Invoice__c WHERE Id = :inv.Id
        ];
        Assert.areEqual(original, after.Issue_Date__c,
            'A pre-set issue date must be left alone.');
    }

    @isTest
    static void paidIsBlockedWhenTotalIsZero() {
        Invoice__c inv = getEmptyInvoice();
        inv.Status__c = 'Paid';

        Boolean blocked = false;
        try {
            update inv;
        } catch (DmlException e) {
            blocked = true;
            Assert.isTrue(
                e.getMessage().contains('cannot be marked as Paid'),
                'Expected the zero-total validation message, got: ' + e.getMessage()
            );
        }
        Assert.isTrue(blocked, 'Updating a zero-total invoice to Paid must fail.');

        Invoice__c after = [
            SELECT Status__c FROM Invoice__c WHERE Id = :inv.Id
        ];
        Assert.areEqual('Draft', after.Status__c, 'Status must be unchanged.');
    }

    @isTest
    static void paidIsAllowedWhenTotalIsPositive() {
        Invoice__c inv = getInvoiceWithLines();
        inv.Status__c = 'Paid';
        update inv;

        Invoice__c after = [
            SELECT Status__c FROM Invoice__c WHERE Id = :inv.Id
        ];
        Assert.areEqual('Paid', after.Status__c);
    }
}
