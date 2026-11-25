/**
 * Tests for the InvoicePDF Visualforce controller.
 */
@isTest
private class InvoicePDFControllerTest {

    @testSetup
    static void setupData() {
        Account acct = new Account(Name = 'Stark Industries');
        insert acct;

        Invoice__c inv = new Invoice__c(
            Account__c = acct.Id,
            Status__c = 'Sent',
            Issue_Date__c = Date.today(),
            Due_Date__c = Date.today().addDays(30)
        );
        insert inv;

        insert new List<Invoice_Line__c>{
            new Invoice_Line__c(
                Invoice__c = inv.Id,
                Product_Name__c = 'Hardware',
                Quantity__c = 3,
                Unit_Price__c = 75
            ),
            new Invoice_Line__c(
                Invoice__c = inv.Id,
                Product_Name__c = 'Warranty',
                Quantity__c = 1,
                Unit_Price__c = 25
            )
        };
    }

    @isTest
    static void controllerLoadsInvoiceLinesAndTotal() {
        Invoice__c inv = [SELECT Id FROM Invoice__c LIMIT 1];

        PageReference pageRef = Page.InvoicePDF;
        pageRef.getParameters().put('invoiceId', inv.Id);
        Test.setCurrentPage(pageRef);

        Test.startTest();
        InvoicePDFController controller = new InvoicePDFController();
        Test.stopTest();

        Assert.isNotNull(controller.invoice, 'Invoice should be loaded.');
        Assert.areEqual(inv.Id, controller.invoice.Id);
        Assert.areEqual('Stark Industries', controller.invoice.Account__r.Name);
        Assert.areEqual(2, controller.lines.size(),
            'Both line items should be exposed to the page.');
        Assert.areEqual(250, controller.grandTotal,
            'Grand total should equal 3x75 + 1x25.');
    }

    @isTest
    static void controllerHandlesMissingParameter() {
        Test.setCurrentPage(Page.InvoicePDF);

        InvoicePDFController controller = new InvoicePDFController();

        Assert.isNull(controller.invoice);
        Assert.areEqual(0, controller.lines.size());
        Assert.isTrue(ApexPages.hasMessages(ApexPages.Severity.ERROR),
            'An error message should be shown when invoiceId is missing.');
    }
}
