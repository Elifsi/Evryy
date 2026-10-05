/**
 * Responsive HTML Tax / Order Invoice Template for evrry Super App
 * Elifsi Technologies Private Limited
 */

export interface InvoiceLineItem {
  name: string;
  quantity: number;
  unitPricePaisa: number;
  packagingUnit?: string;
  itemNote?: string;
}

export interface InvoiceData {
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
  items: InvoiceLineItem[];
  subtotalPaisa: number;
  deliveryFeePaisa: number;
  platformFeePaisa: number;
  taxPaisa: number;
  discountPaisa?: number;
  totalPaisa: number;
}

export function formatNpr(paisa: number): string {
  const npr = (paisa / 100);
  const formatted = npr.toLocaleString('en-US', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
  return `NPR ${formatted}`;
}

export function renderInvoiceHtml(data: InvoiceData): string {
  const formattedDate = new Date(data.placedAt).toLocaleString('en-US', {
    timeZone: 'Asia/Kathmandu',
    dateStyle: 'medium',
    timeStyle: 'short',
  });

  const itemsHtml = data.items
    .map(
      (item) => `
      <tr>
        <td style="padding: 12px 0; border-bottom: 1px solid #e5e7eb;">
          <div style="font-weight: 600; color: #111827; font-size: 14px;">${escapeHtml(item.name)}</div>
          ${item.packagingUnit ? `<div style="font-size: 12px; color: #6b7280;">Packaging: ${escapeHtml(item.packagingUnit)}</div>` : ''}
          ${item.itemNote ? `<div style="font-size: 12px; color: #9ca3af; font-style: italic;">Note: ${escapeHtml(item.itemNote)}</div>` : ''}
        </td>
        <td style="padding: 12px 8px; border-bottom: 1px solid #e5e7eb; text-align: center; color: #374151; font-size: 14px;">
          ${item.quantity}
        </td>
        <td style="padding: 12px 8px; border-bottom: 1px solid #e5e7eb; text-align: right; color: #374151; font-size: 14px;">
          ${formatNpr(item.unitPricePaisa)}
        </td>
        <td style="padding: 12px 0; border-bottom: 1px solid #e5e7eb; text-align: right; font-weight: 600; color: #111827; font-size: 14px;">
          ${formatNpr(item.unitPricePaisa * item.quantity)}
        </td>
      </tr>
    `
    )
    .join('');

  const paymentLabel = formatPaymentMethod(data.paymentMethod);

  return `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Invoice #${data.orderNo} — evrry</title>
</head>
<body style="margin: 0; padding: 0; background-color: #f3f4f6; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;">
  <table width="100%" border="0" cellspacing="0" cellpadding="0" style="background-color: #f3f4f6; padding: 32px 16px;">
    <tr>
      <td align="center">
        <table width="100%" border="0" cellspacing="0" cellpadding="0" style="max-width: 600px; background-color: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.05);">
          <!-- Header -->
          <tr>
            <td style="background: linear-gradient(135deg, #059669 0%, #047857 100%); padding: 32px 32px 24px 32px;">
              <table width="100%" border="0" cellspacing="0" cellpadding="0">
                <tr>
                  <td>
                    <h1 style="margin: 0; color: #ffffff; font-size: 28px; font-weight: 800; letter-spacing: -0.5px;">evrry</h1>
                    <div style="color: #d1fae5; font-size: 13px; margin-top: 4px;">Super App • Elifsi Technologies Pvt. Ltd.</div>
                  </td>
                  <td align="right">
                    <div style="background-color: rgba(255, 255, 255, 0.2); color: #ffffff; padding: 6px 14px; border-radius: 20px; font-size: 12px; font-weight: 600; display: inline-block;">
                      TAX INVOICE
                    </div>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Order Summary Meta -->
          <tr>
            <td style="padding: 24px 32px 16px 32px; border-bottom: 1px solid #f3f4f6;">
              <table width="100%" border="0" cellspacing="0" cellpadding="0">
                <tr>
                  <td width="50%" valign="top">
                    <div style="font-size: 11px; text-transform: uppercase; color: #9ca3af; font-weight: 700; letter-spacing: 0.5px;">INVOICE TO</div>
                    <div style="font-size: 15px; font-weight: 700; color: #111827; margin-top: 4px;">${escapeHtml(data.customerName)}</div>
                    ${data.customerPhone ? `<div style="font-size: 13px; color: #6b7280; margin-top: 2px;">Phone: ${escapeHtml(data.customerPhone)}</div>` : ''}
                    ${data.deliveryAddress ? `<div style="font-size: 13px; color: #6b7280; margin-top: 2px;">Delivery: ${escapeHtml(data.deliveryAddress)}</div>` : ''}
                  </td>
                  <td width="50%" valign="top" align="right">
                    <div style="font-size: 11px; text-transform: uppercase; color: #9ca3af; font-weight: 700; letter-spacing: 0.5px;">INVOICE DETAILS</div>
                    <div style="font-size: 14px; color: #111827; margin-top: 4px;"><span style="color: #6b7280;">Invoice #:</span> <strong>#${data.orderNo}</strong></div>
                    <div style="font-size: 13px; color: #6b7280; margin-top: 2px;">Date: ${formattedDate}</div>
                    <div style="font-size: 13px; color: #059669; font-weight: 600; margin-top: 4px;">Payment: ${paymentLabel}</div>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Merchant Info -->
          <tr>
            <td style="padding: 16px 32px; background-color: #f9fafb; border-bottom: 1px solid #f3f4f6;">
              <table width="100%" border="0" cellspacing="0" cellpadding="0">
                <tr>
                  <td>
                    <div style="font-size: 11px; text-transform: uppercase; color: #9ca3af; font-weight: 700; letter-spacing: 0.5px;">FULFILLED BY</div>
                    <div style="font-size: 14px; font-weight: 600; color: #1f2937; margin-top: 2px;">${escapeHtml(data.merchantName)}</div>
                    ${data.merchantAddress ? `<div style="font-size: 12px; color: #6b7280;">${escapeHtml(data.merchantAddress)}</div>` : ''}
                  </td>
                  ${
                    data.merchantPan
                      ? `<td align="right" valign="top">
                          <div style="font-size: 12px; color: #4b5563; font-weight: 600;">PAN: ${escapeHtml(data.merchantPan)}</div>
                        </td>`
                      : ''
                  }
                </tr>
              </table>
            </td>
          </tr>

          <!-- Items Table -->
          <tr>
            <td style="padding: 24px 32px 16px 32px;">
              <table width="100%" border="0" cellspacing="0" cellpadding="0">
                <thead>
                  <tr style="border-bottom: 2px solid #e5e7eb;">
                    <th align="left" style="padding-bottom: 10px; font-size: 12px; font-weight: 700; color: #6b7280; text-transform: uppercase; letter-spacing: 0.5px;">ITEM</th>
                    <th align="center" style="padding-bottom: 10px; font-size: 12px; font-weight: 700; color: #6b7280; text-transform: uppercase; letter-spacing: 0.5px;">QTY</th>
                    <th align="right" style="padding-bottom: 10px; font-size: 12px; font-weight: 700; color: #6b7280; text-transform: uppercase; letter-spacing: 0.5px;">PRICE</th>
                    <th align="right" style="padding-bottom: 10px; font-size: 12px; font-weight: 700; color: #6b7280; text-transform: uppercase; letter-spacing: 0.5px;">TOTAL</th>
                  </tr>
                </thead>
                <tbody>
                  ${itemsHtml}
                </tbody>
              </table>
            </td>
          </tr>

          <!-- Financial Breakdown -->
          <tr>
            <td style="padding: 0 32px 28px 32px;">
              <table width="100%" border="0" cellspacing="0" cellpadding="0">
                <tr>
                  <td width="55%"></td>
                  <td width="45%">
                    <table width="100%" border="0" cellspacing="0" cellpadding="0">
                      <tr>
                        <td style="padding: 6px 0; font-size: 13px; color: #6b7280;">Subtotal</td>
                        <td style="padding: 6px 0; font-size: 13px; color: #111827; text-align: right; font-weight: 500;">${formatNpr(data.subtotalPaisa)}</td>
                      </tr>
                      <tr>
                        <td style="padding: 6px 0; font-size: 13px; color: #6b7280;">Delivery Fee</td>
                        <td style="padding: 6px 0; font-size: 13px; color: #111827; text-align: right; font-weight: 500;">${formatNpr(data.deliveryFeePaisa)}</td>
                      </tr>
                      <tr>
                        <td style="padding: 6px 0; font-size: 13px; color: #6b7280;">Platform Service Fee</td>
                        <td style="padding: 6px 0; font-size: 13px; color: #111827; text-align: right; font-weight: 500;">${formatNpr(data.platformFeePaisa)}</td>
                      </tr>
                      <tr>
                        <td style="padding: 6px 0; font-size: 13px; color: #6b7280;">VAT (0% Pre-Reg)</td>
                        <td style="padding: 6px 0; font-size: 13px; color: #111827; text-align: right; font-weight: 500;">${formatNpr(data.taxPaisa)}</td>
                      </tr>
                      ${
                        data.discountPaisa && data.discountPaisa > 0
                          ? `<tr>
                              <td style="padding: 6px 0; font-size: 13px; color: #059669; font-weight: 500;">Discount Voucher</td>
                              <td style="padding: 6px 0; font-size: 13px; color: #059669; text-align: right; font-weight: 600;">-${formatNpr(data.discountPaisa)}</td>
                            </tr>`
                          : ''
                      }
                      <tr>
                        <td style="padding: 14px 0 0 0; font-size: 16px; font-weight: 800; color: #111827; border-top: 2px solid #e5e7eb;">Total Paid</td>
                        <td style="padding: 14px 0 0 0; font-size: 18px; font-weight: 800; color: #059669; text-align: right; border-top: 2px solid #e5e7eb;">${formatNpr(data.totalPaisa)}</td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="background-color: #f9fafb; padding: 24px 32px; border-top: 1px solid #e5e7eb; text-align: center;">
              <div style="font-size: 13px; font-weight: 600; color: #374151;">Need help with this order?</div>
              <div style="font-size: 12px; color: #6b7280; margin-top: 4px;">Open the <strong>evrry app</strong> and tap "Help & Support" or reply directly to this email.</div>
              <div style="font-size: 11px; color: #9ca3af; margin-top: 16px; line-height: 1.5;">
                This is an official system-generated tax invoice issued by <strong>Elifsi Technologies Private Limited</strong>, Kathmandu, Nepal.<br/>
                All payments are processed through NRB-licensed direct payment rails.
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

function formatPaymentMethod(method: string): string {
  switch (method?.toLowerCase()) {
    case 'fonepay_qr':
      return 'Fonepay Dynamic QR (Paid)';
    case 'esewa':
      return 'eSewa Mobile Wallet (Paid)';
    case 'khalti':
      return 'Khalti Digital Wallet (Paid)';
    case 'card':
      return 'Card / 3D-Secure (Paid)';
    case 'cod':
      return 'Cash on Delivery (COD)';
    default:
      return method || 'Direct Rail';
  }
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
