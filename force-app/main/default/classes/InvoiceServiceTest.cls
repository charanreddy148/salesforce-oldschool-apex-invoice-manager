/**
 * Tests for the InvoiceService SOQL layer.
 */
@isTest
private class InvoiceServiceTest {

    @testSetup
    static void setupData() {
        Account acct = new Account(Name = 'Globex');
        Account other = new Account(Name = 'Initech');
        insert new List<Account>{ acct, other };

        Invoice__c overdue = new Invoice__c(
            Account__c = acct.Id,
            Status__c = 'Overdue',
            Issue_Date__c = Date.today().addDays(-40),
            Due_Date__c = Date.today().addDays(-10)
        );
        Invoice__c draft = new Invoice__c(
            Account__c = acct.Id,
            Status__c = 'Draft',
            Due_Date__c = Date.today().addDays(15)
        );
        insert new List<Invoice__c>{ overdue, draft };

        insert new List<Invoice_Line__c>{
            new Invoice_Line__c(
                Invoice__c = overdue.Id,
                Product_Name__c = 'Implementation',
                Quantity__c = 2,
                Unit_Price__c = 100
            ),
            new Invoice_Line__c(
                Invoice__c = overdue.Id,
                Product_Name__c = 'Training',
                Quantity__c = 1,
                Unit_Price__c = 50
            )
        };
    }

    @isTest
    static void getInvoiceWithLinesReturnsInvoiceLinesAndTotal() {
        Invoice__c overdue = [
            SELECT Id FROM Invoice__c WHERE Status__c = 'Overdue' LIMIT 1
        ];

        Test.startTest();
        InvoiceService.InvoiceWithLines result =
            InvoiceService.getInvoiceWithLines(overdue.Id);
        Test.stopTest();

        Assert.isNotNull(result, 'Wrapper should be returned.');
        Assert.areEqual(overdue.Id, result.invoice.Id);
        Assert.areEqual(2, result.lines.size(), 'Both line items expected.');
        Assert.areEqual(250, result.grandTotal,
            'Grand total should equal 2x100 + 1x50.');
    }

    @isTest
    static void getInvoiceWithLinesReturnsNullForUnknownId() {
        Id fakeId = Id.valueOf('a00000000000000AAA');
        InvoiceService.InvoiceWithLines result =
            InvoiceService.getInvoiceWithLines(fakeId);
        Assert.isNull(result);
    }

    @isTest
    static void getOverdueInvoicesReturnsOnlyOverdue() {
        List<Invoice__c> overdue = InvoiceService.getOverdueInvoices();
        Assert.areEqual(1, overdue.size());
        Assert.areEqual('Overdue', overdue[0].Status__c);
    }

    @isTest
    static void getInvoicesByAccountScopesToAccount() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Globex' LIMIT 1];
        Account other = [SELECT Id FROM Account WHERE Name = 'Initech' LIMIT 1];

        Assert.areEqual(2, InvoiceService.getInvoicesByAccount(acct.Id).size());
        Assert.areEqual(0, InvoiceService.getInvoicesByAccount(other.Id).size());
    }
}
