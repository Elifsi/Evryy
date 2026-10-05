/**
 * Daily Settlement / Payout Statement Email Template for evrry Super App (Supabase Edge Function)
 * Elifsi Technologies Private Limited
 */

export interface PayoutEmailData {
  tradeName: string;
  settlementDate: string;
  netNpr: number;
  bankRef: string;
  accountNumberMasked?: string;
  bankName?: string;
}

export function renderPayoutStatementHtml(data: PayoutEmailData): { subject: string; html: string } {
  const subject = `evrry Daily Settlement: NPR ${data.netNpr.toFixed(2)} Transferred [${data.settlementDate}]`;

  const html = `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${escapeHtml(subject)}</title>
</head>
<body style="margin: 0; padding: 0; background-color: #f3f4f6; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;">
  <table width="100%" border="0" cellspacing="0" cellpadding="0" style="background-color: #f3f4f6; padding: 40px 16px;">
    <tr>
      <td align="center">
        <table width="100%" border="0" cellspacing="0" cellpadding="0" style="max-width: 550px; background-color: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.05);">
          <!-- Header -->
          <tr>
            <td style="background: linear-gradient(135deg, #059669 0%, #047857 100%); padding: 28px 32px; text-align: center;">
              <h1 style="margin: 0; color: #ffffff; font-size: 24px; font-weight: 800;">evrry Financial Clearing</h1>
              <div style="color: #d1fae5; font-size: 13px; margin-top: 4px;">Automated Partner Settlement Disbursement</div>
            </td>
          </tr>

          <!-- Content -->
          <tr>
            <td style="padding: 32px 32px 24px 32px;">
              <h2 style="margin-top: 0; color: #059669; font-size: 20px;">Daily Settlement Statement</h2>
              <p style="color: #374151; font-size: 15px;">Dear <strong>${escapeHtml(data.tradeName)}</strong>,</p>
              <p style="color: #374151; line-height: 1.6;">
                Your daily net merchant earnings have been audited, balanced against the double-entry general ledger, and disbursed to your registered bank account via corporate interbank clearing.
              </p>

              <div style="background-color: #f9fafb; border: 1px solid #e5e7eb; border-radius: 8px; padding: 18px 20px; margin: 24px 0;">
                <table width="100%" style="font-size: 14px; border-collapse: collapse;">
                  <tr>
                    <td style="color: #6b7280; padding: 6px 0;">Settlement Date:</td>
                    <td style="font-weight: 600; text-align: right; color: #111827;">${escapeHtml(data.settlementDate)}</td>
                  </tr>
                  <tr>
                    <td style="color: #6b7280; padding: 6px 0;">Disbursed Amount:</td>
                    <td style="font-weight: 800; color: #059669; font-size: 17px; text-align: right;">NPR ${data.netNpr.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</td>
                  </tr>
                  ${
                    data.bankName
                      ? `<tr>
                          <td style="color: #6b7280; padding: 6px 0;">Destination Bank:</td>
                          <td style="font-weight: 500; text-align: right; color: #111827;">${escapeHtml(data.bankName)}</td>
                        </tr>`
                      : ''
                  }
                  ${
                    data.accountNumberMasked
                      ? `<tr>
                          <td style="color: #6b7280; padding: 6px 0;">Account:</td>
                          <td style="font-family: monospace; font-weight: 600; text-align: right; color: #111827;">${escapeHtml(data.accountNumberMasked)}</td>
                        </tr>`
                      : ''
                  }
                  <tr style="border-top: 1px dashed #d1d5db;">
                    <td style="color: #6b7280; padding: 8px 0 0 0;">Bank UTR / Reference:</td>
                    <td style="font-family: monospace; font-weight: 700; text-align: right; color: #111827; padding-top: 8px;">${escapeHtml(data.bankRef)}</td>
                  </tr>
                </table>
              </div>

              <p style="font-size: 13px; color: #6b7280; line-height: 1.5;">
                Detailed transaction-by-transaction breakdown with zero-VAT itemization and order commissions can be exported anytime via the <strong>evrry Partner Web Dashboard</strong>.
              </p>

              <hr style="border: none; border-top: 1px solid #e5e7eb; margin: 28px 0 20px 0;" />
              <div style="font-size: 12px; color: #9ca3af; text-align: center; line-height: 1.5;">
                Elifsi Technologies Private Limited • Financial Operations Division<br/>
                Kathmandu, Nepal
              </div>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
`;

  return { subject, html };
}

function escapeHtml(str: string): string {
  if (!str) return '';
  return str
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}
