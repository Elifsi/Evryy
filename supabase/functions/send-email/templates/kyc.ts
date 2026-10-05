/**
 * Partner KYC Verification Status Email Template for evrry Super App (Supabase Edge Function)
 * Elifsi Technologies Private Limited
 */

export interface KycEmailData {
  tradeName: string;
  status: 'approved' | 'rejected';
  rejectionReason?: string;
}

export function renderKycStatusHtml(data: KycEmailData): { subject: string; html: string } {
  const isApproved = data.status === 'approved';
  const subject = isApproved
    ? `🎉 Your Partner Account [${data.tradeName}] is Now LIVE on evrry!`
    : `⚠️ Action Required on Your evrry Partner Application [${data.tradeName}]`;

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
            <td style="background: linear-gradient(135deg, ${isApproved ? '#059669 0%, #047857 100%' : '#dc2626 0%, #b91c1c 100%'}); padding: 28px 32px; text-align: center;">
              <h1 style="margin: 0; color: #ffffff; font-size: 24px; font-weight: 800;">evrry Partner Network</h1>
              <div style="color: rgba(255, 255, 255, 0.85); font-size: 13px; margin-top: 4px;">Merchant & Host KYC Verification</div>
            </td>
          </tr>

          <!-- Content -->
          <tr>
            <td style="padding: 32px 32px 24px 32px;">
              <h2 style="margin-top: 0; color: ${isApproved ? '#059669' : '#dc2626'}; font-size: 20px;">
                ${isApproved ? 'Welcome to the evrry Partner Network!' : 'Action Required on Your Application'}
              </h2>
              <p style="color: #374151; font-size: 15px;">Dear Partner <strong>${escapeHtml(data.tradeName)}</strong>,</p>
              
              ${
                isApproved
                  ? `<p style="color: #374151; line-height: 1.6;">
                      Congratulations! Your KYC verification has been officially approved by the Elifsi Operations team.
                      Your business and catalog are now <strong>ACTIVE</strong> and visible to customers across Nepal.
                    </p>
                    <p style="color: #374151; line-height: 1.6;">
                      You can now log into the <strong>evrry Partner App</strong> or the <strong>Partner Web Dashboard</strong> to accept live orders and manage your listings!
                    </p>`
                  : `<p style="color: #374151; line-height: 1.6;">
                      Thank you for applying to the evrry Partner Network. Our compliance team reviewed your submitted registration documents and noticed an issue that needs correction:
                    </p>
                    <div style="background-color: #fef2f2; border-left: 4px solid #dc2626; padding: 14px; margin: 18px 0; color: #991b1b; font-size: 14px; border-radius: 0 6px 6px 0;">
                      <strong>Reason:</strong> ${escapeHtml(data.rejectionReason || 'Document illegible, expired, or PAN details mismatched.')}
                    </div>
                    <p style="color: #374151; line-height: 1.6;">
                      Please open the <strong>evrry Partner App</strong> to re-upload the requested document so we can review and activate your account right away.
                    </p>`
              }

              <hr style="border: none; border-top: 1px solid #e5e7eb; margin: 28px 0 20px 0;" />
              <div style="font-size: 12px; color: #9ca3af; text-align: center; line-height: 1.5;">
                Elifsi Technologies Private Limited • Partner Compliance Division<br/>
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
