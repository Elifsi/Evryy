/**
 * Web Email Client Helper for evrry Super App (Next.js / TypeScript)
 * Elifsi Technologies Private Limited
 *
 * Dispatches emails through the centralized Supabase Edge Function (`send-email`).
 * Used across:
 * - apps/web/admin (KYC approval/rejection notices, settlement statements)
 * - apps/web/partner (Staff invite emails, order receipts)
 * - apps/web/consumer (Web checkout invoices, web login OTPs)
 */

import { createClient, SupabaseClient } from '@supabase/supabase-js';

export interface WebInvoiceItem {
  name: string;
  quantity: number;
  unitPricePaisa: number;
  packagingUnit?: string;
  itemNote?: string;
}

export interface WebInvoiceData {
  orderNo: string | number;
  placedAt: string | Date;
  customerName: string;
  customerEmail: string;
  customerPhone?: string;
  deliveryAddress?: string;
  merchantName: string;
  merchantAddress?: string;
  merchantPan?: string;
  paymentMethod: string;
  items: WebInvoiceItem[];
  subtotalPaisa: number;
  deliveryFeePaisa: number;
  platformFeePaisa: number;
  taxPaisa: number;
  discountPaisa?: number;
  totalPaisa: number;
}

export interface SendEmailResult {
  success: boolean;
  id?: string;
  error?: string;
  mock?: boolean;
}

export class EvrryWebEmailClient {
  private supabase: SupabaseClient;

  constructor(supabaseClient?: SupabaseClient) {
    if (supabaseClient) {
      this.supabase = supabaseClient;
    } else {
      const url = process.env.NEXT_PUBLIC_SUPABASE_URL || 'http://localhost:54321';
      const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || 'public-anon-key';
      this.supabase = createClient(url, anonKey);
    }
  }

  /**
   * 1. Send Order Tax Invoice to Customer
   */
  async sendOrderInvoice(data: WebInvoiceData): Promise<SendEmailResult> {
    try {
      const { data: response, error } = await this.supabase.functions.invoke('send-email', {
        body: {
          action: 'order_invoice',
          to: data.customerEmail,
          invoiceData: data,
        },
      });

      if (error) {
        return { success: false, error: error.message };
      }
      return response;
    } catch (err: any) {
      return { success: false, error: err.message || 'Unknown network error' };
    }
  }

  /**
   * 2. Send 6-Digit Email Verification Code / OTP
   */
  async sendVerificationOtp(toEmail: string, otpCode: string, recipientName?: string): Promise<SendEmailResult> {
    try {
      const { data: response, error } = await this.supabase.functions.invoke('send-email', {
        body: {
          action: 'verification_otp',
          to: toEmail,
          otpData: {
            recipientName,
            otpCode,
            validMinutes: 10,
            purpose: 'verify your account and login securely',
          },
        },
      });

      if (error) {
        return { success: false, error: error.message };
      }
      return response;
    } catch (err: any) {
      return { success: false, error: err.message || 'Unknown network error' };
    }
  }

  /**
   * 3. Send Partner KYC Approval or Rejection Email (Admin Portal)
   */
  async sendPartnerKycStatus(
    partnerEmail: string,
    tradeName: string,
    isApproved: boolean,
    rejectionReason?: string
  ): Promise<SendEmailResult> {
    try {
      const { data: response, error } = await this.supabase.functions.invoke('send-email', {
        body: {
          action: 'partner_kyc_status',
          to: partnerEmail,
          kycData: {
            tradeName,
            status: isApproved ? 'approved' : 'rejected',
            rejectionReason,
          },
        },
      });

      if (error) {
        return { success: false, error: error.message };
      }
      return response;
    } catch (err: any) {
      return { success: false, error: err.message || 'Unknown network error' };
    }
  }

  /**
   * 4. Send Midnight Payout Statement (Financial Clearing Console)
   */
  async sendPayoutStatement(
    partnerEmail: string,
    tradeName: string,
    settlementDate: string,
    netNpr: number,
    bankRef: string,
    bankName?: string,
    accountNumberMasked?: string
  ): Promise<SendEmailResult> {
    try {
      const { data: response, error } = await this.supabase.functions.invoke('send-email', {
        body: {
          action: 'payout_statement',
          to: partnerEmail,
          payoutData: {
            tradeName,
            settlementDate,
            netNpr,
            bankRef,
            bankName,
            accountNumberMasked,
          },
        },
      });

      if (error) {
        return { success: false, error: error.message };
      }
      return response;
    } catch (err: any) {
      return { success: false, error: err.message || 'Unknown network error' };
    }
  }
}
