/**
 * Verification & Security OTP Email Template for evrry Super App (Supabase Edge Function)
 * Elifsi Technologies Private Limited
 */

export interface VerificationEmailData {
  recipientName?: string;
  otpCode: string;
  validMinutes?: number;
  purpose?: string;
}

export function renderVerificationEmailHtml(data: VerificationEmailData): string {
  const minutes = data.validMinutes || 10;
  const purpose = data.purpose || 'verify your email address and secure your evrry account';

  return `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Your Verification Code — evrry</title>
</head>
<body style="margin: 0; padding: 0; background-color: #f3f4f6; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;">
  <table width="100%" border="0" cellspacing="0" cellpadding="0" style="background-color: #f3f4f6; padding: 40px 16px;">
    <tr>
      <td align="center">
        <table width="100%" border="0" cellspacing="0" cellpadding="0" style="max-width: 500px; background-color: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.05);">
          <!-- Header -->
          <tr>
            <td style="background: linear-gradient(135deg, #059669 0%, #047857 100%); padding: 28px 32px; text-align: center;">
              <h1 style="margin: 0; color: #ffffff; font-size: 26px; font-weight: 800; letter-spacing: -0.5px;">evrry</h1>
              <div style="color: #d1fae5; font-size: 13px; margin-top: 4px;">Super App • Security Verification</div>
            </td>
          </tr>

          <!-- Content -->
          <tr>
            <td style="padding: 32px 32px 24px 32px; text-align: center;">
              <div style="font-size: 18px; font-weight: 700; color: #111827;">Verification Code</div>
              <div style="font-size: 14px; color: #4b5563; margin-top: 8px; line-height: 1.5;">
                ${data.recipientName ? `Hello <strong>${escapeHtml(data.recipientName)}</strong>,<br/>` : ''}
                Please use the following 6-digit code to ${escapeHtml(purpose)}:
              </div>

              <!-- OTP Code Display -->
              <div style="margin: 28px 0; display: inline-block; background-color: #f0fdf4; border: 2px dashed #059669; border-radius: 12px; padding: 16px 36px;">
                <span style="font-family: monospace; font-size: 32px; font-weight: 800; letter-spacing: 8px; color: #047857;">
                  ${data.otpCode}
                </span>
              </div>

              <div style="font-size: 13px; color: #6b7280; margin-bottom: 8px;">
                ⏱️ This code will expire in <strong>${minutes} minutes</strong>.
              </div>
              <div style="font-size: 12px; color: #9ca3af; line-height: 1.4;">
                If you did not request this verification code, please ignore this email or contact support if you suspect unauthorized access.
              </div>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="background-color: #f9fafb; padding: 20px 32px; border-top: 1px solid #e5e7eb; text-align: center;">
              <div style="font-size: 11px; color: #9ca3af; line-height: 1.5;">
                © ${new Date().getFullYear()} Elifsi Technologies Private Limited. All rights reserved.<br/>
                Kathmandu, Nepal • Official Security Dispatch
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
