/**
 * OverdueInvoiceScheduler
 * Schedulable wrapper that launches OverdueInvoiceBatch.
 *
 * Schedule it nightly with:
 *   System.schedule('Overdue Invoices Nightly',
 *                   OverdueInvoiceScheduler.getNightlyCronExpression(),
 *                   new OverdueInvoiceScheduler());
 * or simply call OverdueInvoiceScheduler.scheduleNightly().
 */
public with sharing class OverdueInvoiceScheduler implements Schedulable {

    /** Batch chunk size used when the job runs. */
    public static final Integer BATCH_SIZE = 200;

    public void execute(SchedulableContext ctx) {
        Database.executeBatch(new OverdueInvoiceBatch(), BATCH_SIZE);
    }

    /** CRON expression for 1:00 AM every day (seconds min hour ...). */
    public static String getNightlyCronExpression() {
        return '0 0 1 * * ?';
    }

    /** Convenience: schedule the nightly job and return its job Id. */
    public static Id scheduleNightly() {
        return System.schedule(
            'Overdue Invoice Batch - Nightly 1 AM',
            getNightlyCronExpression(),
            new OverdueInvoiceScheduler()
        );
    }
}
