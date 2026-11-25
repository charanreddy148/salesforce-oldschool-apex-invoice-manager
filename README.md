# Oldschool Apex + Visualforce — Invoice Manager

A Salesforce DX project built the "pre-LWC" way on purpose: custom objects, a
trigger with a handler framework, a SOQL service layer, a Visualforce page
rendered as a PDF invoice, and a scheduled batch job — all covered by Apex
unit tests. It demonstrates the core platform fundamentals that everything
else (LWC, Flows, Agentforce) is built on top of.

**Author:** Ravicharan (Charan) Reddy Buthukuri

---

## What it does

Manage invoices for Accounts end to end:

- Create an **Invoice**, add **Invoice Lines** (product, quantity, unit
  price) — the invoice total rolls up automatically.
- Move the invoice through its lifecycle: **Draft → Sent → Paid**, with
  **Overdue** applied automatically when a sent invoice passes its due date,
  and **Cancelled** available at any point.
- Download a clean, print-ready **PDF invoice** from a Visualforce page.
- A **nightly batch job** flips past-due Sent invoices to Overdue and emails
  a summary count to the user who ran it.

## Data model

| Object | Key fields |
| --- | --- |
| `Invoice__c` | `Account__c` (Lookup → Account), `Status__c` (Picklist: Draft, Sent, Paid, Overdue, Cancelled), `Issue_Date__c` (Date), `Due_Date__c` (Date), `Total_Amount__c` (**Roll-Up Summary** of line amounts), `Notes__c` (Long Text Area). Name is an Auto Number (`INV-0000`). |
| `Invoice_Line__c` | `Invoice__c` (**Master-Detail** → Invoice), `Product_Name__c` (Text), `Quantity__c` (Number), `Unit_Price__c` (Currency), `Amount__c` (**Formula**: `Quantity__c * Unit_Price__c`, Currency). |

## Features

- **Status automation (trigger):** the first time an invoice becomes *Sent*,
  `Issue_Date__c` is stamped with today's date. An invoice with a total of 0
  cannot be saved as *Paid* — the trigger blocks it with an inline error.
- **PDF invoice (Visualforce):** styled invoice with company header, bill-to
  account, invoice number, dates, status, a line-item table, and a grand
  total, rendered with `renderAs="pdf"`.
- **Overdue processing (Batch Apex):** `OverdueInvoiceBatch` finds Sent
  invoices with `Due_Date__c < TODAY`, sets them to Overdue, and emails a
  summary. `OverdueInvoiceScheduler` runs it nightly at 1 AM.
- **Classic app:** an *Invoice Manager* Custom Application with tabs for
  Invoices and Invoice Lines.

## Design patterns

- **Trigger handler framework** — `InvoiceTrigger` contains no logic; it
  delegates to `InvoiceTriggerHandler` (`beforeUpdate` / `afterUpdate`), so
  the logic is bulkified, ordered, and unit-testable.
- **Service layer** — all SOQL lives in `InvoiceService`
  (`getInvoiceWithLines`, `getOverdueInvoices`, `getInvoicesByAccount`),
  using `WITH SECURITY_ENFORCED` and returning an `InvoiceWithLines`
  wrapper. Controllers and batch classes never write their own queries.
- **Batch + Scheduler** — `Database.Batchable` with `Database.Stateful` for
  the cross-chunk count, wrapped by a `Schedulable` class that also exposes
  the nightly CRON expression and a `scheduleNightly()` helper.
- **Thin controller** — `InvoicePDFController` reads the `invoiceId` page
  parameter, loads data through the service layer, and exposes only what
  the page binds to (`invoice`, `lines`, `grandTotal`).

## Project structure

```
force-app/main/default/
├── applications/   Invoice_Manager (Classic app)
├── classes/        Handler, service, PDF controller, batch, scheduler + tests
├── objects/        Invoice__c, Invoice_Line__c (+ all fields)
├── pages/          InvoicePDF (renderAs="pdf")
├── tabs/           Invoice__c, Invoice_Line__c
└── triggers/       InvoiceTrigger
```

## Deploy to a Developer Edition org

Prerequisites: [Salesforce CLI](https://developer.salesforce.com/tools/salesforcecli)
and a free [Developer Edition org](https://developer.salesforce.com/signup).

```bash
# 1. Log in to your org
sf org login web --alias InvoiceDev

# 2. Deploy the project
sf project deploy start --target-org InvoiceDev

# 3. Assign the permission set to your user. Fields deployed from source
#    carry no field-level security grants, and InvoiceService queries run
#    WITH SECURITY_ENFORCED, so this step is required.
sf org assign permset --name Invoice_Manager_Access --target-org InvoiceDev

# 4. Run the tests
sf apex run test --target-org InvoiceDev --wait 10 --code-coverage
```

Then open the org, switch to the **Invoice Manager** app (App Launcher), and
you're ready to try it.

## Try it out

1. **Create data:** Invoices tab → New. Pick an Account, leave the status as
   *Draft*, set a Due Date. Save, then add Invoice Lines from the related
   list (e.g. Quantity 2 × Unit Price 100). Watch **Total Amount** roll up.
2. **Send it:** edit the invoice and set Status = *Sent* — the Issue Date is
   stamped automatically. Try setting a zero-total invoice to *Paid* and
   watch it get blocked.
3. **Open the PDF:** in your browser go to
   `/apex/InvoicePDF?invoiceId=<your invoice Id>` — a formatted PDF invoice
   downloads/renders.
4. **Run the batch:** make a Sent invoice with a Due Date in the past, then
   in Developer Console → Execute Anonymous:

   ```apex
   Database.executeBatch(new OverdueInvoiceBatch(), 200);
   ```

   The invoice flips to **Overdue** and you get a summary email. To schedule
   it nightly instead:

   ```apex
   OverdueInvoiceScheduler.scheduleNightly();
   ```

## Tests

| Test class | Covers |
| --- | --- |
| `InvoiceTriggerHandlerTest` | Issue-date stamping on first send (and not overwriting an existing date), Paid blocked at zero total, Paid allowed with a positive total |
| `InvoiceServiceTest` | Invoice + lines + grand total wrapper, null for unknown Id, overdue-only query, per-account scoping |
| `OverdueInvoiceBatchTest` | Batch flips only past-due Sent invoices (Paid and not-yet-due untouched), summary email sent, scheduler executes the batch, nightly CRON scheduling |
| `InvoicePDFControllerTest` | Controller loads invoice, account name, lines and grand total from the `invoiceId` parameter; graceful error when the parameter is missing |

Tests use `@testSetup` data and real assertions on outcomes — no
coverage-padding call-throughs.

**Live test (November 2026):** the whole project was deployed to a
Developer Edition org and all 17 tests pass there. The live run caught and
fixed real issues: an unescaped quote in the batch class's SOQL string, a
wrong element name on the roll-up summary field, tab/app properties that
API 62 no longer accepts, the batch test's email assertion (emails sent
from a batch `finish()` run outside the test's `Limits` context, so the
test now invokes `finish()` directly), and field-level security — fields
deployed from source have no FLS grants, which the `WITH SECURITY_ENFORCED`
queries in `InvoiceService` correctly rejected until the
`Invoice_Manager_Access` permission set (now included in this repo) was
assigned.

## Skills demonstrated

Apex triggers & trigger handler framework · Visualforce (PDF rendering) ·
Batch Apex & Schedulable Apex · SOQL & roll-up summary / formula fields ·
Master-detail & lookup relationships · Salesforce DX (SFDX) project
structure · Apex unit testing · Classic apps & tabs · Security-enforced
queries (`WITH SECURITY_ENFORCED`)

---

*Part of a Salesforce portfolio series — see also the OmniStudio and
Agentforce projects on this profile.*
