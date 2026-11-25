/**
 * InvoiceService
 * Service layer for all Invoice__c / Invoice_Line__c queries. Centralising
 * SOQL here keeps controllers and batch classes free of query strings and
 * makes the field lists consistent.
 *
 * Queries use WITH SECURITY_ENFORCED so object/field-level security of the
 * running user is respected and the query fails fast if access is missing.
 */
public with sharing class InvoiceService {

    /** Wrapper pairing an invoice with its line items and grand total. */
    public class InvoiceWithLines {
        public Invoice__c invoice { get; set; }
        public List<Invoice_Line__c> lines { get; set; }
        public Decimal grandTotal { get; set; }

        public InvoiceWithLines(Invoice__c invoice, List<Invoice_Line__c> lines) {
            this.invoice = invoice;
            this.lines = lines;
            this.grandTotal = (invoice.Total_Amount__c == null)
                ? 0
                : invoice.Total_Amount__c;
        }
    }

    /**
     * Loads one invoice together with its line items.
     * Returns null when no invoice exists for the given Id.
     */
    public static InvoiceWithLines getInvoiceWithLines(Id invoiceId) {
        List<Invoice__c> invoices = [
            SELECT Id, Name, Account__c, Account__r.Name, Status__c,
                   Issue_Date__c, Due_Date__c, Total_Amount__c, Notes__c,
                   CreatedDate
            FROM Invoice__c
            WHERE Id = :invoiceId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        if (invoices.isEmpty()) {
            return null;
        }
        Invoice__c invoice = invoices[0];

        List<Invoice_Line__c> lines = [
            SELECT Id, Name, Invoice__c, Product_Name__c, Quantity__c,
                   Unit_Price__c, Amount__c
            FROM Invoice_Line__c
            WHERE Invoice__c = :invoiceId
            WITH SECURITY_ENFORCED
            ORDER BY CreatedDate ASC
        ];
        return new InvoiceWithLines(invoice, lines);
    }

    /** All invoices currently flagged Overdue, oldest due date first. */
    public static List<Invoice__c> getOverdueInvoices() {
        return [
            SELECT Id, Name, Account__c, Account__r.Name, Status__c,
                   Issue_Date__c, Due_Date__c, Total_Amount__c, Notes__c,
                   CreatedDate
            FROM Invoice__c
            WHERE Status__c = 'Overdue'
            WITH SECURITY_ENFORCED
            ORDER BY Due_Date__c ASC
        ];
    }

    /** Every invoice billed to one account, newest first. */
    public static List<Invoice__c> getInvoicesByAccount(Id accountId) {
        return [
            SELECT Id, Name, Account__c, Account__r.Name, Status__c,
                   Issue_Date__c, Due_Date__c, Total_Amount__c, Notes__c,
                   CreatedDate
            FROM Invoice__c
            WHERE Account__c = :accountId
            WITH SECURITY_ENFORCED
            ORDER BY CreatedDate DESC
        ];
    }
}
