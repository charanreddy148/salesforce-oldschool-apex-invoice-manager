/**
 * InvoicePDFController
 * Controller for the InvoicePDF Visualforce page (renderAs="pdf").
 * Reads the target invoice from the "invoiceId" page parameter and exposes
 * the invoice, its line items, and the grand total to the page.
 *
 * Usage: /apex/InvoicePDF?invoiceId=<Invoice Id>
 */
public with sharing class InvoicePDFController {

    public Invoice__c invoice { get; private set; }
    public List<Invoice_Line__c> lines { get; private set; }
    public Decimal grandTotal { get; private set; }

    public InvoicePDFController() {
        this.lines = new List<Invoice_Line__c>();
        this.grandTotal = 0;

        Id invoiceId = ApexPages.currentPage().getParameters().get('invoiceId');
        if (invoiceId == null) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'No invoice specified. Pass an invoiceId page parameter.'
            ));
            return;
        }

        InvoiceService.InvoiceWithLines result =
            InvoiceService.getInvoiceWithLines(invoiceId);
        if (result == null) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'Invoice not found.'
            ));
            return;
        }

        this.invoice = result.invoice;
        this.lines = result.lines;
        this.grandTotal = result.grandTotal;
    }
}
