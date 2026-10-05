import { describe, it, expect } from 'vitest';
import { renderInvoiceHtml, formatNpr } from './templates/invoice';
import { renderVerificationEmailHtml } from './templates/verification';
import { sendOrderInvoiceEmail, sendVerificationEmail } from './resend';

describe('Email Templates & Service', () => {
  it('formats NPR currency accurately', () => {
    expect(formatNpr(15000)).toContain('150.00');
    expect(formatNpr(125050)).toContain('1,250.50');
  });

  it('renders a complete tax invoice HTML with order items and zero VAT', () => {
    const html = renderInvoiceHtml({
      orderNo: 10492,
      placedAt: '2026-10-05T12:00:00Z',
      customerName: 'Aarav Sharma',
      customerEmail: 'aarav@example.com',
      merchantName: 'Himalayan Momo House',
      merchantAddress: 'Thamel, Kathmandu',
      merchantPan: '601234567',
      paymentMethod: 'fonepay_qr',
      items: [
        { name: 'Buff Momo (Steamed)', quantity: 2, unitPricePaisa: 18000, itemNote: 'Extra spicy achar' },
        { name: 'Mountain Dew Can', quantity: 1, unitPricePaisa: 8000, packagingUnit: '250 ml' },
      ],
      subtotalPaisa: 44000,
      deliveryFeePaisa: 4000,
      platformFeePaisa: 500,
      taxPaisa: 0,
      totalPaisa: 48500,
    });

    expect(html).toContain('TAX INVOICE');
    expect(html).toContain('Invoice #');
    expect(html).toContain('10492');
    expect(html).toContain('Himalayan Momo House');
    expect(html).toContain('Buff Momo (Steamed)');
    expect(html).toContain('Fonepay Dynamic QR (Paid)');
    expect(html).toContain('NPR 485.00');
  });

  it('renders a 6-digit OTP verification email', () => {
    const html = renderVerificationEmailHtml({
      recipientName: 'Bikash Adhikari',
      otpCode: '849201',
      validMinutes: 10,
    });

    expect(html).toContain('849201');
    expect(html).toContain('Bikash Adhikari');
    expect(html).toContain('10 minutes');
  });

  it('runs mock send gracefully when RESEND_API_KEY is not set', async () => {
    const result = await sendOrderInvoiceEmail({
      orderNo: 10001,
      placedAt: new Date(),
      customerName: 'Test User',
      customerEmail: 'test@example.com',
      merchantName: 'Test Cafe',
      paymentMethod: 'cod',
      items: [{ name: 'Chiya', quantity: 1, unitPricePaisa: 3000 }],
      subtotalPaisa: 3000,
      deliveryFeePaisa: 4000,
      platformFeePaisa: 500,
      taxPaisa: 0,
      totalPaisa: 7500,
    });

    expect(result.success).toBe(true);
    expect(result.mock).toBe(true);
  });
});
