/**
 * Resend Email Service for evrry Super App
 * Elifsi Technologies Private Limited
 */

import { Resend } from 'resend';
import { InvoiceData, renderInvoiceHtml } from './templates/invoice';
import { VerificationEmailData, renderVerificationEmailHtml } from './templates/verification';

const RESEND_API_KEY = process.env.RESEND_API_KEY;
const FROM_EMAIL = process.env.RESEND_FROM_EMAIL || 'evrry <noreply@evrry.com>';

// Initialize client if API key is present
const resend = RESEND_API_KEY ? new Resend(RESEND_API_KEY) : null;

export interface SendEmailResult {
  success: boolean;
  id?: string;
  error?: string;
  mock?: boolean;
}

/**
 * 1. Send Digital Order / Tax Invoice to Customer
 */
export async function sendOrderInvoiceEmail(data: InvoiceData): Promise<SendEmailResult> {
  if (!resend) {
    console.log(`[Email Mock] Order Invoice #${data.orderNo} for ${data.customerEmail} (Total: NPR ${data.totalPaisa / 100})`);
    return { success: true, id: `mock_inv_${Date.now()}`, mock: true };
  }

  try {
    const html = renderInvoiceHtml(data);
    const { data: response, error } = await resend.emails.send({
      from: FROM_EMAIL,
      to: data.customerEmail,
      subject: `Your evrry Order Invoice #${data.orderNo} (NPR ${(data.totalPaisa / 100).toFixed(2)})`,
      html,
    });

    if (error) {
      console.error('[Resend Error] Failed to send order invoice:', error);
      return { success: false, error: error.message };
    }

    return { success: true, id: response?.id };
  } catch (err: any) {
    console.error('[Resend Exception] Error sending invoice email:', err);
    return { success: false, error: err.message || 'Unknown email error' };
  }
}

/**
 * 2. Send 6-Digit Email Verification Code / OTP
 */
export async function sendVerificationEmail(
  toEmail: string,
  otpCode: string,
  recipientName?: string,
  purpose?: string
): Promise<SendEmailResult> {
  if (!resend) {
    console.log(`[Email Mock] Verification Code for ${toEmail}: [${otpCode}]`);
    return { success: true, id: `mock_otp_${Date.now()}`, mock: true };
  }

  try {
    const html = renderVerificationEmailHtml({
      recipientName,
      otpCode,
      validMinutes: 10,
      purpose,
    });

    const { data: response, error } = await resend.emails.send({
      from: FROM_EMAIL,
      to: toEmail,
      subject: `evrry Verification Code: ${otpCode}`,
      html,
    });

    if (error) {
      console.error('[Resend Error] Failed to send verification code:', error);
      return { success: false, error: error.message };
    }

    return { success: true, id: response?.id };
  } catch (err: any) {
    console.error('[Resend Exception] Error sending verification email:', err);
    return { success: false, error: err.message || 'Unknown email error' };
  }
}

/**
 * 3. Send Partner KYC Status Notice (Approval or Rejection with Action)
 */
export async function sendPartnerKycStatusEmail(
  toEmail: string,
  tradeName: string,
  status: 'approved' | 'rejected',
  rejectionReason?: string
): Promise<SendEmailResult> {
  if (!resend) {
    console.log(`[Email Mock] KYC Status for ${tradeName} (${toEmail}): ${status.toUpperCase()} ${rejectionReason ? `Reason: ${rejectionReason}` : ''}`);
    return { success: true, id: `mock_kyc_${Date.now()}`, mock: true };
  }

  const isApproved = status === 'approved';
  const subject = isApproved
    ? `🎉 Your Partner Account [${tradeName}] is Now LIVE on evrry!`
    : `⚠️ Action Required on Your evrry Partner Application [${tradeName}]`;

  const html = `
    <div style="font-family: sans-serif; max-width: 550px; margin: 0 auto; padding: 24px; border: 1px solid #e5e7eb; border-radius: 8px;">
      <h2 style="color: ${isApproved ? '#059669' : '#dc2626'};">${isApproved ? 'Welcome to the evrry Partner Network!' : 'Action Required on Your Application'}</h2>
      <p style="color: #374151; font-size: 15px;">Dear Partner <strong>${tradeName}</strong>,</p>
      ${
        isApproved
          ? `<p style="color: #374151; line-height: 1.5;">Congratulations! Your KYC verification has been officially approved by the Elifsi Operations team. Your store / services are now <strong>ACTIVE</strong> and visible to customers across Nepal.</p>
             <p style="color: #374151;">Log into the partner app to start accepting incoming orders!</p>`
          : `<p style="color: #374151; line-height: 1.5;">Thank you for your partner application. Our verification team reviewed your submitted documents and noticed the following issue:</p>
             <div style="background-color: #fef2f2; border-left: 4px solid #dc2626; padding: 12px; margin: 16px 0; color: #991b1b; font-size: 14px;">
               <strong>Reason:</strong> ${rejectionReason || 'Document illegible or expired.'}
             </div>
             <p style="color: #374151;">Please open the EVRRY Partner app to re-upload the requested document so we can activate your account immediately.</p>`
      }
      <hr style="border: none; border-top: 1px solid #e5e7eb; margin: 24px 0;" />
      <div style="font-size: 12px; color: #9ca3af; text-align: center;">
        Elifsi Technologies Private Limited • Kathmandu, Nepal
      </div>
    </div>
  `;

  try {
    const { data: response, error } = await resend.emails.send({
      from: FROM_EMAIL,
      to: toEmail,
      subject,
      html,
    });

    if (error) return { success: false, error: error.message };
    return { success: true, id: response?.id };
  } catch (err: any) {
    return { success: false, error: err.message };
  }
}

/**
 * 4. Send Midnight Payout Statement to Partner
 */
export async function sendPayoutStatementEmail(
  toEmail: string,
  tradeName: string,
  date: string,
  netNpr: number,
  bankRef: string
): Promise<SendEmailResult> {
  if (!resend) {
    console.log(`[Email Mock] Midnight Payout Statement for ${tradeName}: NPR ${netNpr} (Ref: ${bankRef})`);
    return { success: true, id: `mock_payout_${Date.now()}`, mock: true };
  }

  const html = `
    <div style="font-family: sans-serif; max-width: 550px; margin: 0 auto; padding: 24px; border: 1px solid #e5e7eb; border-radius: 8px;">
      <h2 style="color: #059669;">Daily Settlement Statement — ${date}</h2>
      <p style="color: #374151;">Dear <strong>${tradeName}</strong>,</p>
      <p style="color: #374151; line-height: 1.5;">Your daily earnings settlement has been approved and processed to your verified bank account via corporate clearing.</p>
      
      <div style="background-color: #f9fafb; padding: 16px; border-radius: 8px; margin: 20px 0;">
        <table width="100%" style="font-size: 14px;">
          <tr>
            <td style="color: #6b7280; padding: 4px 0;">Settlement Date:</td>
            <td style="font-weight: 600; text-align: right;">${date}</td>
          </tr>
          <tr>
            <td style="color: #6b7280; padding: 4px 0;">Net Paid to Bank:</td>
            <td style="font-weight: 800; color: #059669; font-size: 16px; text-align: right;">NPR ${netNpr.toFixed(2)}</td>
          </tr>
          <tr>
            <td style="color: #6b7280; padding: 4px 0;">Transfer UTR / Ref:</td>
            <td style="font-family: monospace; font-weight: 600; text-align: right;">${bankRef}</td>
          </tr>
        </table>
      </div>

      <p style="font-size: 13px; color: #6b7280;">You can download detailed item-by-item commission reports anytime on the <strong>EVRRY Partner Web Portal</strong>.</p>
      <hr style="border: none; border-top: 1px solid #e5e7eb; margin: 24px 0;" />
      <div style="font-size: 12px; color: #9ca3af; text-align: center;">
        Elifsi Technologies Private Limited • Financial Clearing Division
      </div>
    </div>
  `;

  try {
    const { data: response, error } = await resend.emails.send({
      from: FROM_EMAIL,
      to: toEmail,
      subject: `evrry Daily Settlement: NPR ${netNpr.toFixed(2)} Transferred [${date}]`,
      html,
    });

    if (error) return { success: false, error: error.message };
    return { success: true, id: response?.id };
  } catch (err: any) {
    return { success: false, error: err.message };
  }
}
